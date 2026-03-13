from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import (
    ClientContext,
    get_client_context,
    get_current_parent_user,
    get_current_student_user,
    get_current_user,
    get_db,
    get_rate_limiter,
)
from app.core.policies import (
    INVITE_CONSUME_RATE_LIMIT_MAX_ATTEMPTS,
    INVITE_CONSUME_RATE_LIMIT_WINDOW_SECONDS,
    INVITE_VERIFY_RATE_LIMIT_MAX_ATTEMPTS,
    INVITE_VERIFY_RATE_LIMIT_WINDOW_SECONDS,
    MAX_CHILDREN_PER_PARENT,
    MAX_PARENTS_PER_CHILD,
)
from app.core.security import hash_invite_code
from app.models.user import User
from app.schemas.family import (
    FamilyLinksResponse,
    InviteConsumeRequest,
    InviteConsumeResponse,
    InviteIssueResponse,
    InviteVerifyRequest,
    InviteVerifyResponse,
    LinkCodeConsumeRequest,
    LinkCodeConsumeResponse,
    LinkCodeIssueResponse,
    LinkedFamilyMemberResponse,
    UnlinkRequest,
    UnlinkResponse,
)
from app.services.family_service import (
    consume_child_link_code,
    consume_invite_code,
    issue_child_link_code,
    issue_invite_code,
    list_family_links,
    unlink_parent_child,
    verify_invite_code,
)
from app.services.rate_limit_service import (
    RateLimiterUnavailableError,
    RateLimitExceededError,
    RedisRateLimiter,
)

router = APIRouter(prefix="/family", tags=["family"])


@router.post("/link-codes", response_model=LinkCodeIssueResponse)
def issue_child_link_code_route(
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
    rate_limiter: Annotated[RedisRateLimiter, Depends(get_rate_limiter)],
) -> LinkCodeIssueResponse:
    _enforce_code_limit(
        action="issue",
        rate_limiter=rate_limiter,
        subject_kind="student",
        subject_id=str(current_student.id),
        code=None,
        ip=context.ip,
        device_id=None,
        max_attempts=INVITE_VERIFY_RATE_LIMIT_MAX_ATTEMPTS,
        window_seconds=INVITE_VERIFY_RATE_LIMIT_WINDOW_SECONDS,
    )

    result = issue_child_link_code(
        db,
        child_id=current_student.id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return LinkCodeIssueResponse(
        code=result.code,
        expires_at=result.expires_at,
        active_parent_count=result.active_parent_count,
        max_parents_per_child=MAX_PARENTS_PER_CHILD,
    )


@router.post("/link-codes/consume", response_model=LinkCodeConsumeResponse)
def consume_child_link_code_route(
    payload: LinkCodeConsumeRequest,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
    rate_limiter: Annotated[RedisRateLimiter, Depends(get_rate_limiter)],
) -> LinkCodeConsumeResponse:
    _enforce_code_limit(
        action="consume",
        rate_limiter=rate_limiter,
        subject_kind="parent",
        subject_id=str(current_parent.id),
        code=payload.code,
        ip=context.ip,
        device_id=payload.device_id,
        max_attempts=INVITE_CONSUME_RATE_LIMIT_MAX_ATTEMPTS,
        window_seconds=INVITE_CONSUME_RATE_LIMIT_WINDOW_SECONDS,
    )

    result = consume_child_link_code(
        db,
        parent_id=current_parent.id,
        code=payload.code,
        ip=context.ip,
    )
    return LinkCodeConsumeResponse(
        parent_id=result.parent_id,
        child_id=result.child_id,
        linked_at=result.linked_at,
    )


@router.get("/links", response_model=FamilyLinksResponse)
def get_family_links(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> FamilyLinksResponse:
    result = list_family_links(db, user_id=current_user.id)
    return FamilyLinksResponse(
        role=result.role,
        linked_children=[
            LinkedFamilyMemberResponse(
                id=member.id,
                email=member.email,
                linked_at=member.linked_at,
            )
            for member in result.linked_children
        ],
        linked_parents=[
            LinkedFamilyMemberResponse(
                id=member.id,
                email=member.email,
                linked_at=member.linked_at,
            )
            for member in result.linked_parents
        ],
        active_child_count=result.active_child_count,
        active_parent_count=result.active_parent_count,
        max_children_per_parent=MAX_CHILDREN_PER_PARENT,
        max_parents_per_child=MAX_PARENTS_PER_CHILD,
    )


@router.post("/invites/issue", response_model=InviteIssueResponse)
def issue_invite(
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> InviteIssueResponse:
    result = issue_invite_code(
        db,
        parent_id=current_parent.id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return InviteIssueResponse(code=result.code, expires_at=result.expires_at)


@router.post("/invites/verify", response_model=InviteVerifyResponse)
def verify_invite(
    payload: InviteVerifyRequest,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
    rate_limiter: Annotated[RedisRateLimiter, Depends(get_rate_limiter)],
) -> InviteVerifyResponse:
    _enforce_invite_limit(
        action="verify",
        rate_limiter=rate_limiter,
        parent_id=str(payload.parent_id),
        code=payload.code,
        ip=context.ip,
        device_id=payload.device_id,
        max_attempts=INVITE_VERIFY_RATE_LIMIT_MAX_ATTEMPTS,
        window_seconds=INVITE_VERIFY_RATE_LIMIT_WINDOW_SECONDS,
    )

    result = verify_invite_code(
        db,
        parent_id=payload.parent_id,
        child_id=current_student.id,
        code=payload.code,
        ip=context.ip,
    )
    return InviteVerifyResponse(valid=result.valid, expires_at=result.expires_at)


@router.post("/invites/consume", response_model=InviteConsumeResponse)
def consume_invite(
    payload: InviteConsumeRequest,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
    rate_limiter: Annotated[RedisRateLimiter, Depends(get_rate_limiter)],
) -> InviteConsumeResponse:
    _enforce_invite_limit(
        action="consume",
        rate_limiter=rate_limiter,
        parent_id=str(payload.parent_id),
        code=payload.code,
        ip=context.ip,
        device_id=payload.device_id,
        max_attempts=INVITE_CONSUME_RATE_LIMIT_MAX_ATTEMPTS,
        window_seconds=INVITE_CONSUME_RATE_LIMIT_WINDOW_SECONDS,
    )

    result = consume_invite_code(
        db,
        parent_id=payload.parent_id,
        child_id=current_student.id,
        code=payload.code,
        ip=context.ip,
    )
    return InviteConsumeResponse(
        parent_id=result.parent_id,
        child_id=result.child_id,
        linked_at=result.linked_at,
    )


@router.post("/unlink", response_model=UnlinkResponse)
def unlink_child(
    payload: UnlinkRequest,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> UnlinkResponse:
    result = unlink_parent_child(
        db,
        parent_id=current_parent.id,
        child_id=payload.child_id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return UnlinkResponse(
        parent_id=result.parent_id,
        child_id=result.child_id,
        unlinked_at=result.unlinked_at,
    )


def _enforce_invite_limit(
    *,
    action: str,
    rate_limiter: RedisRateLimiter,
    parent_id: str,
    code: str,
    ip: str | None,
    device_id: str | None,
    max_attempts: int,
    window_seconds: int,
) -> None:
    key_ip = ip or "unknown"
    code_hash = hash_invite_code(code)

    keys: list[str] = [
        f"invite:{action}:parent:{parent_id}:ip:{key_ip}",
        f"invite:{action}:code:{code_hash}:ip:{key_ip}",
    ]
    if device_id is not None:
        keys.append(f"invite:{action}:device:{device_id}")

    try:
        rate_limiter.enforce(
            keys=keys,
            max_attempts=max_attempts,
            window_seconds=window_seconds,
        )
    except RateLimitExceededError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="rate_limit_exceeded",
        ) from exc
    except RateLimiterUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="rate_limiter_unavailable",
        ) from exc


def _enforce_code_limit(
    *,
    action: str,
    rate_limiter: RedisRateLimiter,
    subject_kind: str,
    subject_id: str,
    code: str | None,
    ip: str | None,
    device_id: str | None,
    max_attempts: int,
    window_seconds: int,
) -> None:
    key_ip = ip or "unknown"
    keys: list[str] = [
        f"family:{action}:{subject_kind}:{subject_id}:ip:{key_ip}",
    ]
    if code is not None:
        keys.append(f"family:{action}:code:{hash_invite_code(code)}:ip:{key_ip}")
    if device_id is not None:
        keys.append(f"family:{action}:device:{device_id}")

    try:
        rate_limiter.enforce(
            keys=keys,
            max_attempts=max_attempts,
            window_seconds=window_seconds,
        )
    except RateLimitExceededError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="rate_limit_exceeded",
        ) from exc
    except RateLimiterUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="rate_limiter_unavailable",
        ) from exc
