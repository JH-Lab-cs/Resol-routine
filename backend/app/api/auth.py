from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import ClientContext, get_client_context, get_current_user, get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    SessionTokensResponse,
)
from app.schemas.user import UserMeResponse
from app.services.auth_service import AuthResult, login_user, logout_session, refresh_session, register_user

router = APIRouter(tags=["auth"])


@router.post("/auth/register/student", response_model=SessionTokensResponse, status_code=status.HTTP_201_CREATED)
def register_student(
    payload: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> SessionTokensResponse:
    result = register_user(
        db,
        role=UserRole.STUDENT,
        email=payload.email,
        password=payload.password.get_secret_value(),
        device_id=payload.device_id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return _to_session_tokens_response(result)


@router.post("/auth/register/parent", response_model=SessionTokensResponse, status_code=status.HTTP_201_CREATED)
def register_parent(
    payload: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> SessionTokensResponse:
    result = register_user(
        db,
        role=UserRole.PARENT,
        email=payload.email,
        password=payload.password.get_secret_value(),
        device_id=payload.device_id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return _to_session_tokens_response(result)


@router.post("/auth/login", response_model=SessionTokensResponse)
def login(
    payload: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> SessionTokensResponse:
    result = login_user(
        db,
        email=payload.email,
        password=payload.password.get_secret_value(),
        device_id=payload.device_id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return _to_session_tokens_response(result)


@router.post("/auth/refresh", response_model=SessionTokensResponse)
def refresh(
    payload: RefreshRequest,
    db: Annotated[Session, Depends(get_db)],
    context: Annotated[ClientContext, Depends(get_client_context)],
) -> SessionTokensResponse:
    result = refresh_session(
        db,
        refresh_token=payload.refresh_token.get_secret_value(),
        device_id=payload.device_id,
        ip=context.ip,
        user_agent=context.user_agent,
    )
    return _to_session_tokens_response(result)


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    payload: LogoutRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    logout_session(
        db,
        user_id=current_user.id,
        refresh_token=payload.refresh_token.get_secret_value(),
        all_devices=payload.all_devices,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/users/me", response_model=UserMeResponse)
def get_me(current_user: Annotated[User, Depends(get_current_user)]) -> UserMeResponse:
    return _to_user_response(current_user)


def _to_session_tokens_response(result: AuthResult) -> SessionTokensResponse:
    return SessionTokensResponse(
        access_token=result.session.access_token,
        access_token_expires_at=result.session.access_token_expires_at,
        refresh_token=result.session.refresh_token,
        refresh_token_expires_at=result.session.refresh_token_expires_at,
        user=_to_user_response(result.user),
    )


def _to_user_response(user: User) -> UserMeResponse:
    return UserMeResponse(
        id=user.id,
        email=user.email,
        role=user.role,
        created_at=user.created_at,
    )
