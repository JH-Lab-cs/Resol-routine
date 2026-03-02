from __future__ import annotations

from dataclasses import dataclass
from collections.abc import Generator
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.policies import JWT_ALGORITHM
from app.db.session import get_db_session
from app.models.enums import UserRole
from app.models.user import User
from app.services.rate_limit_service import RedisRateLimiter

bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(slots=True)
class ClientContext:
    ip: str | None
    user_agent: str | None


def get_db() -> Generator[Session, None, None]:
    yield from get_db_session()


def get_client_context(request: Request) -> ClientContext:
    forwarded_for = request.headers.get("x-forwarded-for")
    client_ip = None
    if forwarded_for:
        client_ip = forwarded_for.split(",", maxsplit=1)[0].strip()
    elif request.client is not None:
        client_ip = request.client.host

    return ClientContext(
        ip=client_ip,
        user_agent=request.headers.get("user-agent"),
    )


def get_current_user(
    db: Annotated[Session, Depends(get_db)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing_access_token")

    if credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_access_token")

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret,
            algorithms=[JWT_ALGORITHM],
        )
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_access_token") from exc

    subject = payload.get("sub")
    if not isinstance(subject, str):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_access_token")

    try:
        user_id = UUID(subject)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_access_token") from exc

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_access_token")
    return user


def get_current_parent_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    if current_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="parent_role_required")
    return current_user


def get_current_student_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="student_role_required")
    return current_user


def get_rate_limiter() -> RedisRateLimiter:
    return RedisRateLimiter(settings.redis_url)
