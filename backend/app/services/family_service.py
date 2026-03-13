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
from app.models.family_link_code import FamilyLinkCode
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


@dataclass(slots=True)
class LinkCodeIssueResult:
    code: str
    expires_at: datetime
    active_parent_count: int


@dataclass(slots=True)
class LinkedFamilyMemberResult:
    id: UUID
    email: str
    linked_at: datetime


@dataclass(slots=True)
class FamilyLinksResult:
    role: UserRole
    linked_children: list[LinkedFamilyMemberResult]
    linked_parents: list[LinkedFamilyMemberResult]
    active_child_count: int
    active_parent_count: int


@dataclass(slots=True)
class LinkCodeConsumeResult:
    parent_id: UUID
    child_id: UUID
    linked_at: datetime


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
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="parent_role_required",
        )

    parent_links = db.execute(
        _active_parent_links_query(parent_id).with_for_update()
    ).scalars().all()
    if len(parent_links) >= MAX_CHILDREN_PER_PARENT:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="parent_child_limit_reached",
        )

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
        details={
            "expires_at": expires_at.isoformat(),
            "ip": ip,
            "user_agent": user_agent,
        },
    )

    return InviteIssueResult(code=code, expires_at=expires_at)


def issue_child_link_code(
    db: Session,
    *,
    child_id: UUID,
    ip: str | None,
    user_agent: str | None,
) -> LinkCodeIssueResult:
    now = datetime.now(UTC)
    expires_at = now + timedelta(seconds=INVITE_CODE_TTL_SECONDS)

    child = db.execute(
        select(User).where(User.id == child_id).with_for_update()
    ).scalar_one_or_none()
    if child is None or child.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="student_role_required",
        )

    child_links = db.execute(
        _active_child_links_query(child_id).with_for_update()
    ).scalars().all()
    if len(child_links) >= MAX_PARENTS_PER_CHILD:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="child_parent_limit_reached",
        )

    code, code_hash = _generate_unique_family_link_code(db)
    link_code = FamilyLinkCode(
        child_id=child_id,
        code_hash=code_hash,
        expires_at=expires_at,
    )
    db.add(link_code)
    db.flush()

    append_audit_log(
        db,
        action="child_link_code_issued",
        actor_user_id=child_id,
        target_user_id=child_id,
        details={
            "expires_at": expires_at.isoformat(),
            "ip": ip,
            "user_agent": user_agent,
        },
    )

    return LinkCodeIssueResult(
        code=code,
        expires_at=expires_at,
        active_parent_count=len(child_links),
    )


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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid_invite_code",
        )
    if child is None or child.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="student_role_required",
        )

    code_hash = hash_invite_code(code)
    invite = db.execute(
        select(InviteCode)
        .where(InviteCode.parent_id == parent_id, InviteCode.code_hash == code_hash)
        .with_for_update()
    ).scalar_one_or_none()

    if invite is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid_invite_code",
        )
    if invite.consumed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="invite_code_already_consumed",
        )
    if _normalize_utc(invite.expires_at) <= now:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="invite_code_expired",
        )

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
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="invalid_invite_code",
            )
        if child is None or child.role != UserRole.STUDENT:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="student_role_required",
            )

        code_hash = hash_invite_code(code)
        invite = db.execute(
            select(InviteCode)
            .where(InviteCode.parent_id == parent_id, InviteCode.code_hash == code_hash)
            .with_for_update()
        ).scalar_one_or_none()

        if invite is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="invalid_invite_code",
            )
        if invite.consumed_at is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="invite_code_already_consumed",
            )
        if _normalize_utc(invite.expires_at) <= now:
            raise HTTPException(
                status_code=status.HTTP_410_GONE,
                detail="invite_code_expired",
            )

        parent_links = db.execute(
            _active_parent_links_query(parent_id).with_for_update()
        ).scalars().all()
        child_links = db.execute(
            _active_child_links_query(child_id).with_for_update()
        ).scalars().all()

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
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="duplicate_active_link",
        ) from exc

    if link is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="link_creation_failed",
        )

    return InviteConsumeResult(
        parent_id=parent_id,
        child_id=child_id,
        linked_at=link.linked_at,
    )


def consume_child_link_code(
    db: Session,
    *,
    parent_id: UUID,
    code: str,
    ip: str | None,
) -> LinkCodeConsumeResult:
    now = datetime.now(UTC)
    link: ParentChildLink | None = None

    try:
        parent = db.execute(
            select(User).where(User.id == parent_id).with_for_update()
        ).scalar_one_or_none()
        if parent is None or parent.role != UserRole.PARENT:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="parent_role_required",
            )

        code_hash = hash_invite_code(code)
        link_code = db.execute(
            select(FamilyLinkCode)
            .where(FamilyLinkCode.code_hash == code_hash)
            .with_for_update()
        ).scalar_one_or_none()

        if link_code is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="invalid_link_code",
            )
        if link_code.consumed_at is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="link_code_already_consumed",
            )
        if _normalize_utc(link_code.expires_at) <= now:
            raise HTTPException(
                status_code=status.HTTP_410_GONE,
                detail="link_code_expired",
            )

        child = db.execute(
            select(User).where(User.id == link_code.child_id).with_for_update()
        ).scalar_one_or_none()
        if child is None or child.role != UserRole.STUDENT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="invalid_link_code",
            )

        parent_links = db.execute(
            _active_parent_links_query(parent_id).with_for_update()
        ).scalars().all()
        child_links = db.execute(
            _active_child_links_query(child.id).with_for_update()
        ).scalars().all()

        if any(active_link.child_id == child.id for active_link in parent_links):
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

        link = ParentChildLink(parent_id=parent_id, child_id=child.id)
        db.add(link)
        db.flush()

        link_code.consumed_at = now
        link_code.consumed_by_user_id = parent_id

        append_audit_log(
            db,
            action="child_link_code_consumed",
            actor_user_id=parent_id,
            target_user_id=child.id,
            details={"ip": ip},
        )
        append_audit_log(
            db,
            action="parent_child_linked",
            actor_user_id=parent_id,
            target_user_id=child.id,
            details={"link_id": str(link.id), "source": "child_link_code"},
        )
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="duplicate_active_link",
        ) from exc

    if link is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="link_creation_failed",
        )

    return LinkCodeConsumeResult(
        parent_id=parent_id,
        child_id=link.child_id,
        linked_at=link.linked_at,
    )


def list_family_links(
    db: Session,
    *,
    user_id: UUID,
) -> FamilyLinksResult:
    current_user = db.get(User, user_id)
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_access_token",
        )

    if current_user.role == UserRole.PARENT:
        linked_children = _load_linked_children(db, parent_id=user_id)
        return FamilyLinksResult(
            role=current_user.role,
            linked_children=linked_children,
            linked_parents=[],
            active_child_count=len(linked_children),
            active_parent_count=0,
        )

    if current_user.role == UserRole.STUDENT:
        linked_parents = _load_linked_parents(db, child_id=user_id)
        return FamilyLinksResult(
            role=current_user.role,
            linked_children=[],
            linked_parents=linked_parents,
            active_child_count=0,
            active_parent_count=len(linked_parents),
        )

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="unsupported_user_role",
    )


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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="active_link_not_found",
        )

    active_link.unlinked_at = now

    append_audit_log(
        db,
        action="parent_child_unlinked",
        actor_user_id=parent_id,
        target_user_id=child_id,
        details={
            "link_id": str(active_link.id),
            "ip": ip,
            "user_agent": user_agent,
        },
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
        existing = db.execute(
            select(InviteCode.id).where(InviteCode.code_hash == code_hash)
        ).scalar_one_or_none()
        if existing is None:
            return code, code_hash

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="invite_code_generation_failed",
    )


def _generate_unique_family_link_code(db: Session) -> tuple[str, str]:
    for _ in range(10):
        code = generate_invite_code()
        code_hash = hash_invite_code(code)
        existing = db.execute(
            select(FamilyLinkCode.id).where(FamilyLinkCode.code_hash == code_hash)
        ).scalar_one_or_none()
        if existing is None:
            return code, code_hash

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="link_code_generation_failed",
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


def _load_linked_children(
    db: Session,
    *,
    parent_id: UUID,
) -> list[LinkedFamilyMemberResult]:
    rows = db.execute(
        select(ParentChildLink, User)
        .join(User, ParentChildLink.child_id == User.id)
        .where(
            ParentChildLink.parent_id == parent_id,
            ParentChildLink.unlinked_at.is_(None),
        )
        .order_by(ParentChildLink.linked_at.asc())
    ).all()
    return [
        LinkedFamilyMemberResult(
            id=user.id,
            email=user.email,
            linked_at=_normalize_utc(link.linked_at),
        )
        for link, user in rows
    ]


def _load_linked_parents(
    db: Session,
    *,
    child_id: UUID,
) -> list[LinkedFamilyMemberResult]:
    rows = db.execute(
        select(ParentChildLink, User)
        .join(User, ParentChildLink.parent_id == User.id)
        .where(
            ParentChildLink.child_id == child_id,
            ParentChildLink.unlinked_at.is_(None),
        )
        .order_by(ParentChildLink.linked_at.asc())
    ).all()
    return [
        LinkedFamilyMemberResult(
            id=user.id,
            email=user.email,
            linked_at=_normalize_utc(link.linked_at),
        )
        for link, user in rows
    ]


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
