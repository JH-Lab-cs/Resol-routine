from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import (
    MockExamType,
    SubscriptionFeatureCode,
    SubscriptionPlanStatus,
    UserSubscriptionStatus,
)
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.parent_child_link import ParentChildLink
from app.models.subscription_plan import SubscriptionPlan
from app.models.subscription_plan_feature import SubscriptionPlanFeature
from app.models.user_subscription import UserSubscription
from app.services.audit_service import append_audit_log

_ACTIVE_ENTITLEMENT_STATUSES = {
    UserSubscriptionStatus.TRIALING,
    UserSubscriptionStatus.ACTIVE,
    UserSubscriptionStatus.GRACE,
}


@dataclass(frozen=True, slots=True)
class ParentEntitlementSummary:
    parent_id: UUID
    feature_codes: set[SubscriptionFeatureCode]
    active_subscription: UserSubscription | None
    active_plan_code: str | None


@dataclass(frozen=True, slots=True)
class StudentParentEntitlementSource:
    parent_id: UUID
    status: UserSubscriptionStatus | None
    plan_code: str | None
    feature_codes: set[SubscriptionFeatureCode]


@dataclass(frozen=True, slots=True)
class StudentEntitlementSummary:
    student_id: UUID
    feature_codes: set[SubscriptionFeatureCode]
    parent_sources: list[StudentParentEntitlementSource]


def resolve_parent_entitlements(
    db: Session,
    *,
    parent_id: UUID,
    at: datetime | None = None,
) -> ParentEntitlementSummary:
    as_of = at or _now_utc()

    rows = db.execute(
        select(UserSubscription, SubscriptionPlan)
        .join(SubscriptionPlan, SubscriptionPlan.id == UserSubscription.subscription_plan_id)
        .where(
            UserSubscription.owner_user_id == parent_id,
            UserSubscription.status.in_(_ACTIVE_ENTITLEMENT_STATUSES),
            SubscriptionPlan.status == SubscriptionPlanStatus.ACTIVE,
        )
        .order_by(UserSubscription.starts_at.desc(), UserSubscription.created_at.desc(), UserSubscription.id.desc())
    ).all()

    active_subscription: UserSubscription | None = None
    active_plan_code: str | None = None
    feature_codes: set[SubscriptionFeatureCode] = set()

    for subscription, plan in rows:
        if _subscription_grants_entitlement(subscription=subscription, at=as_of):
            active_subscription = subscription
            active_plan_code = plan.plan_code
            feature_codes = _load_plan_feature_codes(db, subscription_plan_id=plan.id)
            break

    return ParentEntitlementSummary(
        parent_id=parent_id,
        feature_codes=feature_codes,
        active_subscription=active_subscription,
        active_plan_code=active_plan_code,
    )


def resolve_student_entitlements(
    db: Session,
    *,
    student_id: UUID,
    at: datetime | None = None,
) -> StudentEntitlementSummary:
    as_of = at or _now_utc()

    parent_ids = db.execute(
        select(ParentChildLink.parent_id)
        .where(
            ParentChildLink.child_id == student_id,
            ParentChildLink.unlinked_at.is_(None),
        )
        .order_by(ParentChildLink.parent_id.asc())
    ).scalars().all()

    parent_sources: list[StudentParentEntitlementSource] = []
    union_feature_codes: set[SubscriptionFeatureCode] = set()

    for parent_id in parent_ids:
        parent_summary = resolve_parent_entitlements(db, parent_id=parent_id, at=as_of)
        parent_sources.append(
            StudentParentEntitlementSource(
                parent_id=parent_id,
                status=(
                    parent_summary.active_subscription.status
                    if parent_summary.active_subscription is not None
                    else None
                ),
                plan_code=parent_summary.active_plan_code,
                feature_codes=set(parent_summary.feature_codes),
            )
        )
        union_feature_codes.update(parent_summary.feature_codes)

    return StudentEntitlementSummary(
        student_id=student_id,
        feature_codes=union_feature_codes,
        parent_sources=parent_sources,
    )


def ensure_parent_has_feature(
    db: Session,
    *,
    parent_id: UUID,
    feature_code: SubscriptionFeatureCode,
    denial_detail: str,
) -> None:
    summary = resolve_parent_entitlements(db, parent_id=parent_id)
    if feature_code in summary.feature_codes:
        return

    append_audit_log(
        db,
        action="subscription_access_denied",
        actor_user_id=parent_id,
        target_user_id=parent_id,
        details={
            "required_feature": feature_code.value,
            "detail": denial_detail,
            "scope": "parent",
        },
    )
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=denial_detail)


def ensure_student_has_feature(
    db: Session,
    *,
    student_id: UUID,
    feature_code: SubscriptionFeatureCode,
    denial_detail: str,
) -> None:
    summary = resolve_student_entitlements(db, student_id=student_id)
    if feature_code in summary.feature_codes:
        return

    append_audit_log(
        db,
        action="subscription_access_denied",
        actor_user_id=student_id,
        target_user_id=student_id,
        details={
            "required_feature": feature_code.value,
            "detail": denial_detail,
            "scope": "student",
        },
    )
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=denial_detail)


def ensure_student_can_start_mock_exam_session(
    db: Session,
    *,
    student_id: UUID,
    mock_exam_revision_id: UUID,
) -> None:
    row = db.execute(
        select(MockExamRevision.id, MockExam.exam_type)
        .join(MockExam, MockExam.id == MockExamRevision.mock_exam_id)
        .where(MockExamRevision.id == mock_exam_revision_id)
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_revision_not_found")

    _revision_id, exam_type = row
    if exam_type == MockExamType.WEEKLY:
        ensure_student_has_feature(
            db,
            student_id=student_id,
            feature_code=SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS,
            denial_detail="weekly_mock_exams_subscription_required",
        )
        return

    ensure_student_has_feature(
        db,
        student_id=student_id,
        feature_code=SubscriptionFeatureCode.MONTHLY_MOCK_EXAMS,
        denial_detail="monthly_mock_exams_subscription_required",
    )


def _subscription_grants_entitlement(*, subscription: UserSubscription, at: datetime) -> bool:
    as_of = _to_utc_aware(at)
    starts_at = _to_utc_aware(subscription.starts_at)
    ends_at = _to_utc_aware(subscription.ends_at)
    grace_ends_at = _to_utc_aware(subscription.grace_ends_at) if subscription.grace_ends_at is not None else None

    if as_of < starts_at:
        return False

    if subscription.status in {UserSubscriptionStatus.TRIALING, UserSubscriptionStatus.ACTIVE}:
        return as_of <= ends_at

    if subscription.status == UserSubscriptionStatus.GRACE:
        if grace_ends_at is None:
            return False
        return as_of <= grace_ends_at

    return False


def _load_plan_feature_codes(
    db: Session,
    *,
    subscription_plan_id: UUID,
) -> set[SubscriptionFeatureCode]:
    return set(
        db.execute(
            select(SubscriptionPlanFeature.feature_code)
            .where(SubscriptionPlanFeature.subscription_plan_id == subscription_plan_id)
        ).scalars().all()
    )


def _to_utc_aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _now_utc() -> datetime:
    return datetime.now(UTC)
