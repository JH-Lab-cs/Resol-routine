from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import (
    ClientContext,
    get_client_context,
    get_current_parent_user,
    get_current_student_user,
    get_db,
    get_rate_limiter,
)
from app.core.policies import (
    INVITE_CONSUME_RATE_LIMIT_MAX_ATTEMPTS,
    INVITE_CONSUME_RATE_LIMIT_WINDOW_SECONDS,
    INVITE_VERIFY_RATE_LIMIT_MAX_ATTEMPTS,
    INVITE_VERIFY_RATE_LIMIT_WINDOW_SECONDS,
)
from app.core.security import hash_invite_code
from app.models.user import User
from app.schemas.family import (
    InviteConsumeRequest,
    InviteConsumeResponse,
    InviteIssueResponse,
    InviteVerifyRequest,
    InviteVerifyResponse,
    UnlinkRequest,
    UnlinkResponse,
)
from app.services.family_service import (
    consume_invite_code,
    issue_invite_code,
    unlink_parent_child,
    verify_invite_code,
)
from app.services.rate_limit_service import (
    RateLimitExceededError,
    RateLimiterUnavailableError,
    RedisRateLimiter,
)

router = APIRouter(prefix="/family", tags=["family"])


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
        rate_limiter.enforce(keys=keys, max_attempts=max_attempts, window_seconds=window_seconds)
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="rate_limit_exceeded") from exc
    except RateLimiterUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="rate_limiter_unavailable") from exc
