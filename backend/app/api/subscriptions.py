from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.subscriptions import SubscriptionMeResponse
from app.services.subscription_service import get_subscription_me

router = APIRouter(prefix="/subscription", tags=["subscriptions"])


@router.get("/me", response_model=SubscriptionMeResponse)
def get_my_subscription(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SubscriptionMeResponse:
    return get_subscription_me(db, actor=current_user)
