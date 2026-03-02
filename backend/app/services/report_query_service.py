from __future__ import annotations

import re
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.input_validation import validate_user_input_text
from app.core.policies import WRONG_REASON_TAG_DB_VALUES
from app.models.daily_report_aggregate import DailyReportAggregate
from app.models.monthly_report_aggregate import MonthlyReportAggregate
from app.models.parent_child_link import ParentChildLink
from app.models.weekly_report_aggregate import WeeklyReportAggregate
from app.schemas.reports import DailyReportResponse, MonthlyReportResponse, WeeklyReportResponse

_DAY_KEY_PATTERN = re.compile(r"^\d{8}$")
_WEEK_KEY_PATTERN = re.compile(r"^\d{4}W(0[1-9]|[1-4]\d|5[0-3])$")
_PERIOD_KEY_PATTERN = re.compile(r"^\d{4}(0[1-9]|1[0-2])$")


def ensure_parent_has_active_child_link(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> None:
    active_link = db.execute(
        select(ParentChildLink.id).where(
            ParentChildLink.parent_id == parent_id,
            ParentChildLink.child_id == child_id,
            ParentChildLink.unlinked_at.is_(None),
        )
    ).scalar_one_or_none()

    if active_link is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="child_report_access_forbidden")


def get_daily_report_for_student(
    db: Session,
    *,
    student_id: UUID,
    day_key_value: str,
) -> DailyReportResponse:
    day_key_value = validate_day_key(day_key_value)

    aggregate = db.execute(
        select(DailyReportAggregate).where(
            DailyReportAggregate.student_id == student_id,
            DailyReportAggregate.day_key == day_key_value,
        )
    ).scalar_one_or_none()

    if aggregate is None:
        return DailyReportResponse(
            student_id=student_id,
            day_key=day_key_value,
            answered_count=0,
            correct_count=0,
            wrong_count=0,
            wrong_reason_counts=_zero_filled_wrong_reason_counts(),
            top_wrong_reason_tag=None,
            first_occurred_at=None,
            last_occurred_at=None,
            aggregated_at=None,
        )

    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    top_wrong_reason_tag = _resolve_top_wrong_reason_tag(
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        persisted_top=aggregate.top_wrong_reason_tag,
    )

    return DailyReportResponse(
        student_id=aggregate.student_id,
        day_key=aggregate.day_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=top_wrong_reason_tag,
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def get_weekly_report_for_student(
    db: Session,
    *,
    student_id: UUID,
    week_key_value: str,
) -> WeeklyReportResponse:
    week_key_value = validate_week_key(week_key_value)

    aggregate = db.execute(
        select(WeeklyReportAggregate).where(
            WeeklyReportAggregate.student_id == student_id,
            WeeklyReportAggregate.week_key == week_key_value,
        )
    ).scalar_one_or_none()

    if aggregate is None:
        return WeeklyReportResponse(
            student_id=student_id,
            week_key=week_key_value,
            answered_count=0,
            correct_count=0,
            wrong_count=0,
            wrong_reason_counts=_zero_filled_wrong_reason_counts(),
            top_wrong_reason_tag=None,
            first_occurred_at=None,
            last_occurred_at=None,
            aggregated_at=None,
        )

    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    top_wrong_reason_tag = _resolve_top_wrong_reason_tag(
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        persisted_top=aggregate.top_wrong_reason_tag,
    )

    return WeeklyReportResponse(
        student_id=aggregate.student_id,
        week_key=aggregate.week_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=top_wrong_reason_tag,
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def get_monthly_report_for_student(
    db: Session,
    *,
    student_id: UUID,
    period_key_value: str,
) -> MonthlyReportResponse:
    period_key_value = validate_period_key(period_key_value)

    aggregate = db.execute(
        select(MonthlyReportAggregate).where(
            MonthlyReportAggregate.student_id == student_id,
            MonthlyReportAggregate.period_key == period_key_value,
        )
    ).scalar_one_or_none()

    if aggregate is None:
        return MonthlyReportResponse(
            student_id=student_id,
            period_key=period_key_value,
            answered_count=0,
            correct_count=0,
            wrong_count=0,
            wrong_reason_counts=_zero_filled_wrong_reason_counts(),
            top_wrong_reason_tag=None,
            first_occurred_at=None,
            last_occurred_at=None,
            aggregated_at=None,
        )

    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    top_wrong_reason_tag = _resolve_top_wrong_reason_tag(
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        persisted_top=aggregate.top_wrong_reason_tag,
    )

    return MonthlyReportResponse(
        student_id=aggregate.student_id,
        period_key=aggregate.period_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=top_wrong_reason_tag,
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def validate_day_key(value: str) -> str:
    return _validate_key(value=value, pattern=_DAY_KEY_PATTERN, detail="invalid_day_key")


def validate_week_key(value: str) -> str:
    return _validate_key(value=value, pattern=_WEEK_KEY_PATTERN, detail="invalid_week_key")


def validate_period_key(value: str) -> str:
    return _validate_key(value=value, pattern=_PERIOD_KEY_PATTERN, detail="invalid_period_key")


def _validate_key(*, value: str, pattern: re.Pattern[str], detail: str) -> str:
    try:
        normalized = validate_user_input_text(value, field_name="report_key")
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    if not pattern.fullmatch(normalized):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=detail)
    return normalized


def _resolve_top_wrong_reason_tag(
    *,
    wrong_count: int,
    wrong_reason_counts: dict[str, int],
    persisted_top: str | None,
) -> str | None:
    if wrong_count <= 0:
        return None
    if persisted_top in WRONG_REASON_TAG_DB_VALUES:
        return persisted_top
    return sorted(
        WRONG_REASON_TAG_DB_VALUES,
        key=lambda tag: (-int(wrong_reason_counts.get(tag, 0)), tag),
    )[0]


def _normalize_wrong_reason_counts(raw_counts: dict[str, int]) -> dict[str, int]:
    normalized = _zero_filled_wrong_reason_counts()
    for tag in WRONG_REASON_TAG_DB_VALUES:
        normalized[tag] = int(raw_counts.get(tag, 0))
    return normalized


def _zero_filled_wrong_reason_counts() -> dict[str, int]:
    return {tag: 0 for tag in WRONG_REASON_TAG_DB_VALUES}
