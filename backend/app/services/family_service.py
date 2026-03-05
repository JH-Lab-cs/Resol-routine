from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import Select, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.policies import (
    INVITE_CODE_TTL_SECONDS,
    MAX_CHILDREN_PER_PARENT,
    MAX_PARENTS_PER_CHILD,
)
from app.core.security import generate_invite_code, hash_invite_code
from app.models.enums import UserRole
from app.models.invite_code import InviteCode
from app.models.parent_child_link import ParentChildLink
from app.models.user import User
from app.services.audit_service import append_audit_log


@dataclass(slots=True)
class InviteIssueResult:
    code: str
    expires_at: datetime


@dataclass(slots=True)
class InviteVerifyResult:
    valid: bool
    expires_at: datetime


@dataclass(slots=True)
class InviteConsumeResult:
    parent_id: UUID
    child_id: UUID
    linked_at: datetime


@dataclass(slots=True)
class UnlinkResult:
    parent_id: UUID
    child_id: UUID
    unlinked_at: datetime


def issue_invite_code(
    db: Session,
    *,
    parent_id: UUID,
    ip: str | None,
    user_agent: str | None,
) -> InviteIssueResult:
    now = datetime.now(UTC)
    expires_at = now + timedelta(seconds=INVITE_CODE_TTL_SECONDS)

    parent = db.execute(
        select(User).where(User.id == parent_id).with_for_update()
    ).scalar_one_or_none()
    if parent is None or parent.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="parent_role_required")

    parent_links = db.execute(_active_parent_links_query(parent_id).with_for_update()).scalars().all()
    if len(parent_links) >= MAX_CHILDREN_PER_PARENT:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="parent_child_limit_reached")

    code, code_hash = _generate_unique_invite_code(db)
    invite = InviteCode(
        parent_id=parent_id,
        code_hash=code_hash,
        expires_at=expires_at,
    )
    db.add(invite)
    db.flush()

    append_audit_log(
        db,
        action="invite_issued",
        actor_user_id=parent_id,
        target_user_id=parent_id,
        details={"expires_at": expires_at.isoformat(), "ip": ip, "user_agent": user_agent},
    )

    return InviteIssueResult(code=code, expires_at=expires_at)


def verify_invite_code(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
    code: str,
    ip: str | None,
) -> InviteVerifyResult:
    now = datetime.now(UTC)
    parent = db.get(User, parent_id)
    child = db.get(User, child_id)

    if parent is None or parent.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_invite_code")
    if child is None or child.role != UserRole.STUDENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="student_role_required")

    code_hash = hash_invite_code(code)
    invite = db.execute(
        select(InviteCode)
        .where(InviteCode.parent_id == parent_id, InviteCode.code_hash == code_hash)
        .with_for_update()
    ).scalar_one_or_none()

    if invite is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_invite_code")
    if invite.consumed_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="invite_code_already_consumed")
    if _normalize_utc(invite.expires_at) <= now:
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="invite_code_expired")

    append_audit_log(
        db,
        action="invite_verified",
        actor_user_id=child_id,
        target_user_id=parent_id,
        details={"ip": ip},
    )

    return InviteVerifyResult(valid=True, expires_at=_normalize_utc(invite.expires_at))


def consume_invite_code(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
    code: str,
    ip: str | None,
) -> InviteConsumeResult:
    now = datetime.now(UTC)
    link: ParentChildLink | None = None

    try:
        parent = db.execute(
            select(User).where(User.id == parent_id).with_for_update()
        ).scalar_one_or_none()
        child = db.execute(
            select(User).where(User.id == child_id).with_for_update()
        ).scalar_one_or_none()

        if parent is None or parent.role != UserRole.PARENT:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_invite_code")
        if child is None or child.role != UserRole.STUDENT:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="student_role_required")

        code_hash = hash_invite_code(code)
        invite = db.execute(
            select(InviteCode)
            .where(InviteCode.parent_id == parent_id, InviteCode.code_hash == code_hash)
            .with_for_update()
        ).scalar_one_or_none()

        if invite is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_invite_code")
        if invite.consumed_at is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="invite_code_already_consumed",
            )
        if _normalize_utc(invite.expires_at) <= now:
            raise HTTPException(status_code=status.HTTP_410_GONE, detail="invite_code_expired")

        parent_links = db.execute(_active_parent_links_query(parent_id).with_for_update()).scalars().all()
        child_links = db.execute(_active_child_links_query(child_id).with_for_update()).scalars().all()

        if any(active_link.child_id == child_id for active_link in parent_links):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="duplicate_active_link",
            )
        if len(parent_links) >= MAX_CHILDREN_PER_PARENT:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="parent_child_limit_reached",
            )
        if len(child_links) >= MAX_PARENTS_PER_CHILD:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="child_parent_limit_reached",
            )

        link = ParentChildLink(parent_id=parent_id, child_id=child_id)
        db.add(link)
        db.flush()

        invite.consumed_at = now
        invite.consumed_by_user_id = child_id

        append_audit_log(
            db,
            action="invite_consumed",
            actor_user_id=child_id,
            target_user_id=parent_id,
            details={"ip": ip},
        )
        append_audit_log(
            db,
            action="parent_child_linked",
            actor_user_id=child_id,
            target_user_id=parent_id,
            details={"link_id": str(link.id)},
        )

    except IntegrityError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="duplicate_active_link") from exc

    if link is None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="link_creation_failed")

    return InviteConsumeResult(parent_id=parent_id, child_id=child_id, linked_at=link.linked_at)


def unlink_parent_child(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
    ip: str | None,
    user_agent: str | None,
) -> UnlinkResult:
    now = datetime.now(UTC)
    active_link = db.execute(
        select(ParentChildLink)
        .where(
            ParentChildLink.parent_id == parent_id,
            ParentChildLink.child_id == child_id,
            ParentChildLink.unlinked_at.is_(None),
        )
        .with_for_update()
    ).scalar_one_or_none()

    if active_link is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="active_link_not_found")

    active_link.unlinked_at = now

    append_audit_log(
        db,
        action="parent_child_unlinked",
        actor_user_id=parent_id,
        target_user_id=child_id,
        details={"link_id": str(active_link.id), "ip": ip, "user_agent": user_agent},
    )

    return UnlinkResult(
        parent_id=parent_id,
        child_id=child_id,
        unlinked_at=now,
    )


def _generate_unique_invite_code(db: Session) -> tuple[str, str]:
    for _ in range(10):
        code = generate_invite_code()
        code_hash = hash_invite_code(code)
        existing = db.execute(select(InviteCode.id).where(InviteCode.code_hash == code_hash)).scalar_one_or_none()
        if existing is None:
            return code, code_hash

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="invite_code_generation_failed",
    )


def _active_parent_links_query(parent_id: UUID) -> Select[tuple[ParentChildLink]]:
    return select(ParentChildLink).where(
        ParentChildLink.parent_id == parent_id,
        ParentChildLink.unlinked_at.is_(None),
    )


def _active_child_links_query(child_id: UUID) -> Select[tuple[ParentChildLink]]:
    return select(ParentChildLink).where(
        ParentChildLink.child_id == child_id,
        ParentChildLink.unlinked_at.is_(None),
    )


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
