from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import (
    SubscriptionFeatureCode,
    SubscriptionPlanStatus,
    UserRole,
    UserSubscriptionStatus,
)
from app.models.subscription_plan import SubscriptionPlan
from app.models.subscription_plan_feature import SubscriptionPlanFeature
from app.models.user import User
from app.models.user_subscription import UserSubscription
from app.schemas.subscriptions import (
    SubscriptionMeParentActiveSubscription,
    SubscriptionMeParentResponse,
    SubscriptionMeResponse,
    SubscriptionMeStudentParentSource,
    SubscriptionMeStudentResponse,
    SubscriptionPlanCreateRequest,
    SubscriptionPlanListResponse,
    SubscriptionPlanResponse,
    SubscriptionStateChangeResponse,
    UserSubscriptionCreateRequest,
    UserSubscriptionListResponse,
    UserSubscriptionResponse,
)
from app.services.audit_service import append_audit_log
from app.services.entitlement_service import resolve_parent_entitlements, resolve_student_entitlements

_ACTIVE_WINDOW_STATUSES = {
    UserSubscriptionStatus.TRIALING,
    UserSubscriptionStatus.ACTIVE,
    UserSubscriptionStatus.GRACE,
}


def create_subscription_plan(
    db: Session,
    *,
    payload: SubscriptionPlanCreateRequest,
) -> SubscriptionPlanResponse:
    existing = db.execute(
        select(SubscriptionPlan.id).where(SubscriptionPlan.plan_code == payload.plan_code)
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_plan_code_conflict")

    plan = SubscriptionPlan(
        plan_code=payload.plan_code,
        display_name=payload.display_name,
        status=SubscriptionPlanStatus.ACTIVE,
        metadata_json=payload.metadata_json,
    )
    db.add(plan)
    db.flush()

    features: list[SubscriptionPlanFeature] = []
    for feature_code in payload.feature_codes:
        feature = SubscriptionPlanFeature(
            subscription_plan_id=plan.id,
            feature_code=feature_code,
        )
        db.add(feature)
        features.append(feature)
    db.flush()

    append_audit_log(
        db,
        action="subscription_plan_created",
        actor_user_id=None,
        target_user_id=None,
        details={
            "plan_code": plan.plan_code,
            "feature_codes": sorted(feature.feature_code.value for feature in features),
        },
    )

    return _to_plan_response(plan=plan, features=features)


def list_subscription_plans(db: Session) -> SubscriptionPlanListResponse:
    plans = db.execute(
        select(SubscriptionPlan)
        .order_by(SubscriptionPlan.plan_code.asc(), SubscriptionPlan.id.asc())
    ).scalars().all()

    plan_ids = [plan.id for plan in plans]
    features_by_plan: dict[UUID, list[SubscriptionPlanFeature]] = {plan_id: [] for plan_id in plan_ids}
    if plan_ids:
        features = db.execute(
            select(SubscriptionPlanFeature)
            .where(SubscriptionPlanFeature.subscription_plan_id.in_(plan_ids))
            .order_by(
                SubscriptionPlanFeature.subscription_plan_id.asc(),
                SubscriptionPlanFeature.feature_code.asc(),
                SubscriptionPlanFeature.id.asc(),
            )
        ).scalars().all()
        for feature in features:
            features_by_plan.setdefault(feature.subscription_plan_id, []).append(feature)

    return SubscriptionPlanListResponse(
        items=[
            _to_plan_response(plan=plan, features=features_by_plan.get(plan.id, []))
            for plan in plans
        ]
    )


def create_parent_subscription(
    db: Session,
    *,
    parent_id: UUID,
    payload: UserSubscriptionCreateRequest,
) -> UserSubscriptionResponse:
    parent_user = db.get(User, parent_id)
    if parent_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="parent_user_not_found")
    if parent_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_owner_must_be_parent")

    plan = db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.plan_code == payload.plan_code)
    ).scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="subscription_plan_not_found")
    if plan.status != SubscriptionPlanStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_plan_not_active")

    _assert_no_overlapping_active_window(
        db,
        owner_user_id=parent_id,
        incoming_status=payload.status,
        incoming_starts_at=payload.starts_at,
        incoming_ends_at=payload.ends_at,
        incoming_grace_ends_at=payload.grace_ends_at,
    )

    subscription = UserSubscription(
        owner_user_id=parent_id,
        subscription_plan_id=plan.id,
        status=payload.status,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        grace_ends_at=payload.grace_ends_at,
        canceled_at=None,
        external_billing_ref=payload.external_billing_ref,
        metadata_json=payload.metadata_json,
    )
    db.add(subscription)
    db.flush()

    append_audit_log(
        db,
        action="user_subscription_created",
        actor_user_id=None,
        target_user_id=parent_id,
        details={
            "subscription_id": str(subscription.id),
            "plan_code": plan.plan_code,
            "status": subscription.status.value,
            "starts_at": subscription.starts_at.isoformat(),
            "ends_at": subscription.ends_at.isoformat(),
            "grace_ends_at": (
                subscription.grace_ends_at.isoformat() if subscription.grace_ends_at is not None else None
            ),
        },
    )

    return _to_user_subscription_response(subscription=subscription, plan_code=plan.plan_code)


def list_parent_subscriptions(
    db: Session,
    *,
    parent_id: UUID,
) -> UserSubscriptionListResponse:
    parent_user = db.get(User, parent_id)
    if parent_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="parent_user_not_found")
    if parent_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_owner_must_be_parent")

    rows = db.execute(
        select(UserSubscription, SubscriptionPlan)
        .join(SubscriptionPlan, SubscriptionPlan.id == UserSubscription.subscription_plan_id)
        .where(UserSubscription.owner_user_id == parent_id)
        .order_by(UserSubscription.starts_at.desc(), UserSubscription.created_at.desc(), UserSubscription.id.desc())
    ).all()

    return UserSubscriptionListResponse(
        owner_user_id=str(parent_id),
        items=[
            _to_user_subscription_response(subscription=subscription, plan_code=plan.plan_code)
            for subscription, plan in rows
        ],
    )


def cancel_user_subscription(
    db: Session,
    *,
    subscription_id: UUID,
) -> SubscriptionStateChangeResponse:
    row = db.execute(
        select(UserSubscription, SubscriptionPlan)
        .join(SubscriptionPlan, SubscriptionPlan.id == UserSubscription.subscription_plan_id)
        .where(UserSubscription.id == subscription_id)
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user_subscription_not_found")

    subscription, plan = row
    now = datetime.now(UTC)

    if subscription.status == UserSubscriptionStatus.EXPIRED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="invalid_subscription_transition")

    if subscription.status != UserSubscriptionStatus.CANCELED:
        subscription.status = UserSubscriptionStatus.CANCELED
        subscription.canceled_at = now
        subscription_ends_at = _to_utc_aware(subscription.ends_at)
        if subscription_ends_at > now:
            subscription.ends_at = now
        subscription.grace_ends_at = None
        db.flush()

        append_audit_log(
            db,
            action="user_subscription_canceled",
            actor_user_id=None,
            target_user_id=subscription.owner_user_id,
            details={
                "subscription_id": str(subscription.id),
                "plan_code": plan.plan_code,
                "canceled_at": subscription.canceled_at.isoformat() if subscription.canceled_at else None,
            },
        )

    return _to_subscription_state_change_response(subscription)


def expire_user_subscription(
    db: Session,
    *,
    subscription_id: UUID,
) -> SubscriptionStateChangeResponse:
    row = db.execute(
        select(UserSubscription, SubscriptionPlan)
        .join(SubscriptionPlan, SubscriptionPlan.id == UserSubscription.subscription_plan_id)
        .where(UserSubscription.id == subscription_id)
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user_subscription_not_found")

    subscription, plan = row
    now = datetime.now(UTC)

    if subscription.status == UserSubscriptionStatus.CANCELED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="invalid_subscription_transition")

    if subscription.status != UserSubscriptionStatus.EXPIRED:
        subscription.status = UserSubscriptionStatus.EXPIRED
        subscription_ends_at = _to_utc_aware(subscription.ends_at)
        if subscription_ends_at > now:
            subscription.ends_at = now
        subscription.grace_ends_at = None
        db.flush()

        append_audit_log(
            db,
            action="user_subscription_expired",
            actor_user_id=None,
            target_user_id=subscription.owner_user_id,
            details={
                "subscription_id": str(subscription.id),
                "plan_code": plan.plan_code,
                "expired_at": now.isoformat(),
            },
        )

    return _to_subscription_state_change_response(subscription)


def get_subscription_me(
    db: Session,
    *,
    actor: User,
) -> SubscriptionMeResponse:
    if actor.role == UserRole.PARENT:
        summary = resolve_parent_entitlements(db, parent_id=actor.id)
        active_subscription = None
        if summary.active_subscription is not None and summary.active_plan_code is not None:
            active_subscription = SubscriptionMeParentActiveSubscription(
                status=summary.active_subscription.status,
                starts_at=summary.active_subscription.starts_at,
                ends_at=summary.active_subscription.ends_at,
                grace_ends_at=summary.active_subscription.grace_ends_at,
                plan_code=summary.active_plan_code,
                source="OWN",
            )

        return SubscriptionMeParentResponse(
            actor_role=actor.role,
            feature_codes=sorted(summary.feature_codes, key=lambda code: code.value),
            active_subscription=active_subscription,
        )

    summary = resolve_student_entitlements(db, student_id=actor.id)
    linked_sources = [
        SubscriptionMeStudentParentSource(
            parent_id=str(source.parent_id),
            status=source.status,
            plan_code=source.plan_code,
            feature_codes=sorted(source.feature_codes, key=lambda code: code.value),
        )
        for source in summary.parent_sources
    ]

    return SubscriptionMeStudentResponse(
        actor_role=actor.role,
        source="LINKED_PARENTS",
        feature_codes=sorted(summary.feature_codes, key=lambda code: code.value),
        linked_parent_sources=linked_sources,
        effective_status="ACTIVE" if summary.feature_codes else "INACTIVE",
    )


def upsert_parent_subscription_from_billing(
    db: Session,
    *,
    parent_id: UUID,
    plan_code: str,
    external_billing_ref: str,
    subscription_status: UserSubscriptionStatus,
    starts_at: datetime,
    ends_at: datetime,
    grace_ends_at: datetime | None,
    metadata_json: dict[str, object],
) -> UserSubscription:
    parent_user = db.get(User, parent_id)
    if parent_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="parent_user_not_found")
    if parent_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_owner_must_be_parent")

    plan = db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.plan_code == plan_code)
    ).scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="subscription_plan_not_found")
    if plan.status != SubscriptionPlanStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="subscription_plan_not_active")

    normalized_external_ref = external_billing_ref.strip()
    if not normalized_external_ref:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="external_billing_ref_required")

    existing = (
        db.query(UserSubscription)
        .filter(
            UserSubscription.owner_user_id == parent_id,
            UserSubscription.external_billing_ref == normalized_external_ref,
        )
        .with_for_update()
        .one_or_none()
    )

    if existing is None:
        existing = UserSubscription(
            owner_user_id=parent_id,
            subscription_plan_id=plan.id,
            status=subscription_status,
            starts_at=starts_at,
            ends_at=ends_at,
            grace_ends_at=grace_ends_at,
            canceled_at=None,
            external_billing_ref=normalized_external_ref,
            metadata_json=metadata_json,
        )
        db.add(existing)
        db.flush()

    active_window_end = _entitlement_window_end(
        status=subscription_status,
        ends_at=ends_at,
        grace_ends_at=grace_ends_at,
    )
    if active_window_end is not None:
        _close_overlapping_active_windows(
            db,
            owner_user_id=parent_id,
            excluded_subscription_id=existing.id,
            incoming_starts_at=starts_at,
            incoming_ends_at=active_window_end,
        )

    existing.subscription_plan_id = plan.id
    existing.status = subscription_status
    existing.starts_at = starts_at
    existing.ends_at = ends_at
    existing.grace_ends_at = grace_ends_at
    existing.external_billing_ref = normalized_external_ref
    existing.metadata_json = metadata_json

    if subscription_status == UserSubscriptionStatus.CANCELED:
        existing.canceled_at = datetime.now(UTC)
    elif subscription_status != UserSubscriptionStatus.EXPIRED:
        existing.canceled_at = None

    db.flush()
    return existing


def _to_plan_response(
    *,
    plan: SubscriptionPlan,
    features: list[SubscriptionPlanFeature],
) -> SubscriptionPlanResponse:
    return SubscriptionPlanResponse(
        id=str(plan.id),
        plan_code=plan.plan_code,
        display_name=plan.display_name,
        status=plan.status,
        feature_codes=sorted((item.feature_code for item in features), key=lambda code: code.value),
        metadata_json=plan.metadata_json,
        created_at=plan.created_at,
        updated_at=plan.updated_at,
    )


def _to_user_subscription_response(
    *,
    subscription: UserSubscription,
    plan_code: str,
) -> UserSubscriptionResponse:
    return UserSubscriptionResponse(
        id=str(subscription.id),
        owner_user_id=str(subscription.owner_user_id),
        plan_code=plan_code,
        status=subscription.status,
        starts_at=subscription.starts_at,
        ends_at=subscription.ends_at,
        grace_ends_at=subscription.grace_ends_at,
        canceled_at=subscription.canceled_at,
        metadata_json=subscription.metadata_json,
        created_at=subscription.created_at,
        updated_at=subscription.updated_at,
    )


def _to_subscription_state_change_response(subscription: UserSubscription) -> SubscriptionStateChangeResponse:
    return SubscriptionStateChangeResponse(
        subscription_id=str(subscription.id),
        status=subscription.status,
        canceled_at=subscription.canceled_at,
        ends_at=subscription.ends_at,
        grace_ends_at=subscription.grace_ends_at,
        updated_at=subscription.updated_at,
    )


def _close_overlapping_active_windows(
    db: Session,
    *,
    owner_user_id: UUID,
    excluded_subscription_id: UUID,
    incoming_starts_at: datetime,
    incoming_ends_at: datetime,
) -> None:
    incoming_start = _to_utc_aware(incoming_starts_at)
    incoming_end = _to_utc_aware(incoming_ends_at)
    rows = db.execute(
        select(UserSubscription)
        .where(
            UserSubscription.owner_user_id == owner_user_id,
            UserSubscription.id != excluded_subscription_id,
            UserSubscription.status.in_(_ACTIVE_WINDOW_STATUSES),
        )
        .order_by(UserSubscription.starts_at.asc(), UserSubscription.id.asc())
    ).scalars().all()

    for item in rows:
        current_end = _entitlement_window_end(
            status=item.status,
            ends_at=item.ends_at,
            grace_ends_at=item.grace_ends_at,
        )
        if current_end is None:
            continue
        if not _windows_overlap(
            left_start=incoming_start,
            left_end=incoming_end,
            right_start=_to_utc_aware(item.starts_at),
            right_end=_to_utc_aware(current_end),
        ):
            continue

        item.status = UserSubscriptionStatus.EXPIRED
        item.grace_ends_at = None
        if _to_utc_aware(item.ends_at) > incoming_start:
            item.ends_at = incoming_start


def _assert_no_overlapping_active_window(
    db: Session,
    *,
    owner_user_id: UUID,
    incoming_status: UserSubscriptionStatus,
    incoming_starts_at: datetime,
    incoming_ends_at: datetime,
    incoming_grace_ends_at: datetime | None,
) -> None:
    incoming_start = _to_utc_aware(incoming_starts_at)
    incoming_window_end = _entitlement_window_end(
        status=incoming_status,
        ends_at=incoming_ends_at,
        grace_ends_at=incoming_grace_ends_at,
    )

    if incoming_window_end is None:
        return
    incoming_end = _to_utc_aware(incoming_window_end)

    existing_rows = db.execute(
        select(UserSubscription)
        .where(UserSubscription.owner_user_id == owner_user_id)
        .order_by(UserSubscription.starts_at.asc(), UserSubscription.id.asc())
    ).scalars().all()

    for existing in existing_rows:
        existing_window_end = _entitlement_window_end(
            status=existing.status,
            ends_at=existing.ends_at,
            grace_ends_at=existing.grace_ends_at,
        )
        if existing_window_end is None:
            continue
        existing_start = _to_utc_aware(existing.starts_at)
        existing_end = _to_utc_aware(existing_window_end)

        if _windows_overlap(
            left_start=incoming_start,
            left_end=incoming_end,
            right_start=existing_start,
            right_end=existing_end,
        ):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="overlapping_active_subscription")


def _entitlement_window_end(
    *,
    status: UserSubscriptionStatus,
    ends_at: datetime,
    grace_ends_at: datetime | None,
) -> datetime | None:
    if status in {UserSubscriptionStatus.TRIALING, UserSubscriptionStatus.ACTIVE}:
        return ends_at
    if status == UserSubscriptionStatus.GRACE:
        return grace_ends_at
    return None


def _windows_overlap(
    *,
    left_start: datetime,
    left_end: datetime,
    right_start: datetime,
    right_end: datetime,
) -> bool:
    return left_start <= right_end and right_start <= left_end


def _to_utc_aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
