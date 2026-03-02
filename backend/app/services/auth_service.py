from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.policies import ACCESS_TOKEN_TTL_MINUTES, REFRESH_TOKEN_TTL_DAYS
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_opaque_token,
    hash_password,
    normalize_email,
    verify_password,
)
from app.models.enums import UserRole
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.services.audit_service import append_audit_log


@dataclass(slots=True)
class IssuedSession:
    access_token: str
    access_token_expires_at: datetime
    refresh_token: str
    refresh_token_expires_at: datetime
    refresh_token_id: UUID


@dataclass(slots=True)
class AuthResult:
    user: User
    session: IssuedSession


def register_user(
    db: Session,
    *,
    role: UserRole,
    email: str,
    password: str,
    device_id: str | None,
    ip: str | None,
    user_agent: str | None,
) -> AuthResult:
    normalized_email = normalize_email(email)
    existing_user = db.execute(select(User).where(User.email == normalized_email)).scalar_one_or_none()
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="email_already_registered",
        )

    user = User(
        email=normalized_email,
        password_hash=hash_password(password),
        role=role,
    )
    db.add(user)
    db.flush()

    session = _issue_session(
        db,
        user_id=user.id,
        device_id=device_id,
        ip=ip,
        user_agent=user_agent,
        family_id=uuid4(),
    )
    append_audit_log(
        db,
        action="register",
        actor_user_id=user.id,
        target_user_id=user.id,
        details={"role": user.role.value},
    )

    return AuthResult(user=user, session=session)


def login_user(
    db: Session,
    *,
    email: str,
    password: str,
    device_id: str | None,
    ip: str | None,
    user_agent: str | None,
) -> AuthResult:
    normalized_email = normalize_email(email)
    user = db.execute(select(User).where(User.email == normalized_email)).scalar_one_or_none()
    if user is None or not verify_password(password, user.password_hash):
        append_audit_log(
            db,
            action="login_failure",
            actor_user_id=None,
            target_user_id=None,
            details={"email_hash": _hash_for_audit(normalized_email)},
        )
        db.flush()
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_credentials",
        )

    session = _issue_session(
        db,
        user_id=user.id,
        device_id=device_id,
        ip=ip,
        user_agent=user_agent,
        family_id=uuid4(),
    )
    append_audit_log(
        db,
        action="login_success",
        actor_user_id=user.id,
        target_user_id=user.id,
        details={"role": user.role.value},
    )

    return AuthResult(user=user, session=session)


def refresh_session(
    db: Session,
    *,
    refresh_token: str,
    device_id: str | None,
    ip: str | None,
    user_agent: str | None,
) -> AuthResult:
    now = datetime.now(UTC)
    token_hash = hash_opaque_token(refresh_token)

    current_token = db.execute(
        select(RefreshToken)
        .where(RefreshToken.token_hash == token_hash)
        .with_for_update()
    ).scalar_one_or_none()

    if current_token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_refresh_token",
        )

    user = db.get(User, current_token.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_refresh_token",
        )

    if device_id is not None and current_token.device_id not in {None, device_id}:
        append_audit_log(
            db,
            action="refresh_revoked",
            actor_user_id=user.id,
            target_user_id=user.id,
            details={"reason": "device_mismatch"},
        )
        db.flush()
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_refresh_token",
        )

    is_reuse_attempt = current_token.rotated_at is not None
    is_unusable = (
        current_token.revoked_at is not None
        or _normalize_utc(current_token.expires_at) <= now
        or current_token.reuse_detected_at is not None
    )

    if is_reuse_attempt:
        if current_token.reuse_detected_at is None:
            current_token.reuse_detected_at = now
        _revoke_token_family(db, family_id=current_token.family_id, now=now)
        append_audit_log(
            db,
            action="refresh_reuse_detected",
            actor_user_id=user.id,
            target_user_id=user.id,
            details={"family_id": str(current_token.family_id)},
        )
        db.flush()
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="refresh_token_reuse_detected",
        )

    if is_unusable:
        append_audit_log(
            db,
            action="refresh_revoked",
            actor_user_id=user.id,
            target_user_id=user.id,
            details={"reason": "expired_or_revoked"},
        )
        db.flush()
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_refresh_token",
        )

    new_session = _issue_session(
        db,
        user_id=user.id,
        device_id=device_id or current_token.device_id,
        ip=ip,
        user_agent=user_agent,
        family_id=current_token.family_id,
    )

    current_token.rotated_at = now
    current_token.replaced_by_token_id = new_session.refresh_token_id

    append_audit_log(
        db,
        action="refresh_success",
        actor_user_id=user.id,
        target_user_id=user.id,
        details={"family_id": str(current_token.family_id)},
    )

    return AuthResult(user=user, session=new_session)


def logout_session(
    db: Session,
    *,
    user_id: UUID,
    refresh_token: str,
    all_devices: bool,
) -> None:
    now = datetime.now(UTC)
    if all_devices:
        db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        append_audit_log(
            db,
            action="refresh_revoked",
            actor_user_id=user_id,
            target_user_id=user_id,
            details={"scope": "all_devices"},
        )
        return

    token_hash = hash_opaque_token(refresh_token)
    current_token = db.execute(
        select(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.token_hash == token_hash,
        )
        .with_for_update()
    ).scalar_one_or_none()

    if current_token is not None and current_token.revoked_at is None:
        current_token.revoked_at = now

    append_audit_log(
        db,
        action="refresh_revoked",
        actor_user_id=user_id,
        target_user_id=user_id,
        details={"scope": "single_device"},
    )


def _issue_session(
    db: Session,
    *,
    user_id: UUID,
    device_id: str | None,
    ip: str | None,
    user_agent: str | None,
    family_id: UUID,
) -> IssuedSession:
    now = datetime.now(UTC)
    refresh_token = generate_opaque_token()
    refresh_token_expires_at = now + timedelta(days=REFRESH_TOKEN_TTL_DAYS)

    token_row = RefreshToken(
        user_id=user_id,
        device_id=device_id,
        token_hash=hash_opaque_token(refresh_token),
        family_id=family_id,
        issued_at=now,
        expires_at=refresh_token_expires_at,
        ip=ip,
        user_agent=user_agent,
    )
    db.add(token_row)
    db.flush()

    access_token_expires_at = now + timedelta(minutes=ACCESS_TOKEN_TTL_MINUTES)
    access_token = create_access_token(subject=str(user_id))

    return IssuedSession(
        access_token=access_token,
        access_token_expires_at=access_token_expires_at,
        refresh_token=refresh_token,
        refresh_token_expires_at=refresh_token_expires_at,
        refresh_token_id=token_row.id,
    )


def _revoke_token_family(db: Session, *, family_id: UUID, now: datetime) -> None:
    db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.family_id == family_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )


def _hash_for_audit(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
