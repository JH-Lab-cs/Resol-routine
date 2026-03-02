from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.subscriptions import (
    SubscriptionPlanCreateRequest,
    SubscriptionPlanListResponse,
    SubscriptionPlanResponse,
    SubscriptionStateChangeResponse,
    UserSubscriptionCreateRequest,
    UserSubscriptionListResponse,
    UserSubscriptionResponse,
)
from app.services.subscription_service import (
    cancel_user_subscription,
    create_parent_subscription,
    create_subscription_plan,
    expire_user_subscription,
    list_parent_subscriptions,
    list_subscription_plans,
)

router = APIRouter(
    prefix="/internal/subscriptions",
    tags=["subscriptions-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


@router.post("/plans", response_model=SubscriptionPlanResponse, status_code=status.HTTP_201_CREATED)
def create_subscription_plan_endpoint(
    payload: SubscriptionPlanCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> SubscriptionPlanResponse:
    return create_subscription_plan(db, payload=payload)


@router.get("/plans", response_model=SubscriptionPlanListResponse)
def list_subscription_plans_endpoint(
    db: Annotated[Session, Depends(get_db)],
) -> SubscriptionPlanListResponse:
    return list_subscription_plans(db)


@router.post(
    "/parents/{parent_id}",
    response_model=UserSubscriptionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_parent_subscription_endpoint(
    parent_id: UUID,
    payload: UserSubscriptionCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> UserSubscriptionResponse:
    return create_parent_subscription(db, parent_id=parent_id, payload=payload)


@router.get("/parents/{parent_id}", response_model=UserSubscriptionListResponse)
def list_parent_subscriptions_endpoint(
    parent_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> UserSubscriptionListResponse:
    return list_parent_subscriptions(db, parent_id=parent_id)


@router.post("/{subscription_id}/cancel", response_model=SubscriptionStateChangeResponse)
def cancel_subscription_endpoint(
    subscription_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> SubscriptionStateChangeResponse:
    return cancel_user_subscription(db, subscription_id=subscription_id)


@router.post("/{subscription_id}/expire", response_model=SubscriptionStateChangeResponse)
def expire_subscription_endpoint(
    subscription_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> SubscriptionStateChangeResponse:
    return expire_user_subscription(db, subscription_id=subscription_id)
