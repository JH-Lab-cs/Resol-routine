from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Literal, cast
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.policies import (
    SYNC_EVENT_TYPE_MOCK_EXAM_COMPLETED,
    SYNC_EVENT_TYPE_VOCAB_QUIZ_COMPLETED,
    WRONG_REASON_TAG_DB_VALUES,
)
from app.models.daily_report_aggregate import DailyReportAggregate
from app.models.monthly_report_aggregate import MonthlyReportAggregate
from app.models.parent_child_link import ParentChildLink
from app.models.study_event import StudyEvent
from app.models.user import User
from app.models.weekly_report_aggregate import WeeklyReportAggregate
from app.schemas.reports import (
    DailyReportResponse,
    MonthlyReportResponse,
    ParentReportActivityResponse,
    ParentReportChildResponse,
    ParentReportDetailResponse,
    ParentReportMockSummaryResponse,
    ParentReportSummaryResponse,
    ParentReportTrendPointResponse,
    ParentReportVocabSummaryResponse,
    WeeklyReportResponse,
    WrongReasonTagValue,
)
from app.schemas.sync import MockExamCompletedPayload, VocabQuizCompletedPayload

_MAX_RECENT_DAILY_POINTS = 7
_MAX_COMPLETED_EVENTS = 20
_MAX_RECENT_ACTIVITY_ITEMS = 6


def build_parent_report_summary(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> ParentReportSummaryResponse:
    child = _load_child_summary(db, parent_id=parent_id, child_id=child_id)
    payloads = _load_parent_report_payloads(db, student_id=child_id)

    return ParentReportSummaryResponse(
        child=child,
        has_any_report_data=payloads.has_any_report_data,
        daily_summary=payloads.daily_summary,
        vocab_summary=payloads.vocab_summary,
        weekly_mock_summary=payloads.weekly_mock_summary,
        monthly_mock_summary=payloads.monthly_mock_summary,
        recent_activity=payloads.recent_activity,
    )


def build_parent_report_detail(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> ParentReportDetailResponse:
    child = _load_child_summary(db, parent_id=parent_id, child_id=child_id)
    payloads = _load_parent_report_payloads(db, student_id=child_id)

    return ParentReportDetailResponse(
        child=child,
        has_any_report_data=payloads.has_any_report_data,
        daily_summary=payloads.daily_summary,
        weekly_summary=payloads.weekly_summary,
        monthly_summary=payloads.monthly_summary,
        vocab_summary=payloads.vocab_summary,
        weekly_mock_summary=payloads.weekly_mock_summary,
        monthly_mock_summary=payloads.monthly_mock_summary,
        recent_trend=payloads.recent_trend,
        recent_activity=payloads.recent_activity,
    )


class _ParentReportPayloadBundle:
    def __init__(
        self,
        *,
        daily_summary: DailyReportResponse | None,
        weekly_summary: WeeklyReportResponse | None,
        monthly_summary: MonthlyReportResponse | None,
        vocab_summary: ParentReportVocabSummaryResponse | None,
        weekly_mock_summary: ParentReportMockSummaryResponse | None,
        monthly_mock_summary: ParentReportMockSummaryResponse | None,
        recent_trend: list[ParentReportTrendPointResponse],
        recent_activity: list[ParentReportActivityResponse],
    ) -> None:
        self.daily_summary = daily_summary
        self.weekly_summary = weekly_summary
        self.monthly_summary = monthly_summary
        self.vocab_summary = vocab_summary
        self.weekly_mock_summary = weekly_mock_summary
        self.monthly_mock_summary = monthly_mock_summary
        self.recent_trend = recent_trend
        self.recent_activity = recent_activity

    @property
    def has_any_report_data(self) -> bool:
        return any(
            value is not None
            for value in (
                self.daily_summary,
                self.weekly_summary,
                self.monthly_summary,
                self.vocab_summary,
                self.weekly_mock_summary,
                self.monthly_mock_summary,
            )
        ) or bool(self.recent_trend) or bool(self.recent_activity)


def _load_child_summary(
    db: Session,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> ParentReportChildResponse:
    row = db.execute(
        select(User.id, User.email, ParentChildLink.linked_at)
        .join(ParentChildLink, ParentChildLink.child_id == User.id)
        .where(
            ParentChildLink.parent_id == parent_id,
            ParentChildLink.child_id == child_id,
            ParentChildLink.unlinked_at.is_(None),
        )
    ).one()
    child_user_id, child_email, linked_at = row
    return ParentReportChildResponse(id=child_user_id, email=child_email, linked_at=linked_at)


def _load_parent_report_payloads(
    db: Session,
    *,
    student_id: UUID,
) -> _ParentReportPayloadBundle:
    latest_daily = db.execute(
        select(DailyReportAggregate)
        .where(DailyReportAggregate.student_id == student_id)
        .order_by(DailyReportAggregate.day_key.desc())
        .limit(1)
    ).scalar_one_or_none()
    latest_weekly = db.execute(
        select(WeeklyReportAggregate)
        .where(WeeklyReportAggregate.student_id == student_id)
        .order_by(WeeklyReportAggregate.week_key.desc())
        .limit(1)
    ).scalar_one_or_none()
    latest_monthly = db.execute(
        select(MonthlyReportAggregate)
        .where(MonthlyReportAggregate.student_id == student_id)
        .order_by(MonthlyReportAggregate.period_key.desc())
        .limit(1)
    ).scalar_one_or_none()
    recent_daily = db.execute(
        select(DailyReportAggregate)
        .where(DailyReportAggregate.student_id == student_id)
        .order_by(DailyReportAggregate.day_key.desc())
        .limit(_MAX_RECENT_DAILY_POINTS)
    ).scalars().all()
    completed_events = db.execute(
        select(StudyEvent)
        .where(
            StudyEvent.student_id == student_id,
            StudyEvent.event_type.in_(
                (SYNC_EVENT_TYPE_VOCAB_QUIZ_COMPLETED, SYNC_EVENT_TYPE_MOCK_EXAM_COMPLETED)
            ),
        )
        .order_by(StudyEvent.occurred_at_client.desc(), StudyEvent.id.desc())
        .limit(_MAX_COMPLETED_EVENTS)
    ).scalars().all()

    vocab_summary = _extract_latest_vocab_summary(completed_events)
    weekly_mock_summary = _extract_latest_mock_summary(completed_events, exam_type="WEEKLY")
    monthly_mock_summary = _extract_latest_mock_summary(completed_events, exam_type="MONTHLY")

    daily_summary = _to_daily_report_response(latest_daily)
    weekly_summary = _to_weekly_report_response(latest_weekly)
    monthly_summary = _to_monthly_report_response(latest_monthly)
    recent_trend = [
        ParentReportTrendPointResponse(
            day_key=aggregate.day_key,
            answered_count=aggregate.answered_count,
            correct_count=aggregate.correct_count,
            wrong_count=aggregate.wrong_count,
            aggregated_at=aggregate.aggregated_at,
        )
        for aggregate in reversed(recent_daily)
    ]
    recent_activity = _build_recent_activity(
        daily_summary=daily_summary,
        weekly_summary=weekly_summary,
        monthly_summary=monthly_summary,
        vocab_summary=vocab_summary,
        weekly_mock_summary=weekly_mock_summary,
        monthly_mock_summary=monthly_mock_summary,
    )

    return _ParentReportPayloadBundle(
        daily_summary=daily_summary,
        weekly_summary=weekly_summary,
        monthly_summary=monthly_summary,
        vocab_summary=vocab_summary,
        weekly_mock_summary=weekly_mock_summary,
        monthly_mock_summary=monthly_mock_summary,
        recent_trend=recent_trend,
        recent_activity=recent_activity,
    )


def _extract_latest_vocab_summary(
    events: Sequence[StudyEvent],
) -> ParentReportVocabSummaryResponse | None:
    for event in events:
        if event.event_type != SYNC_EVENT_TYPE_VOCAB_QUIZ_COMPLETED:
            continue
        try:
            payload = VocabQuizCompletedPayload.model_validate(event.payload)
        except ValidationError:
            continue
        return ParentReportVocabSummaryResponse(
            day_key=payload.day_key,
            track=payload.track,
            total_count=payload.total_count,
            correct_count=payload.correct_count,
            wrong_count=payload.total_count - payload.correct_count,
            wrong_vocab_count=len(payload.wrong_vocab_ids),
            occurred_at=_normalize_utc(event.occurred_at_client),
        )
    return None


def _extract_latest_mock_summary(
    events: Sequence[StudyEvent],
    *,
    exam_type: Literal["WEEKLY", "MONTHLY"],
) -> ParentReportMockSummaryResponse | None:
    for event in events:
        if event.event_type != SYNC_EVENT_TYPE_MOCK_EXAM_COMPLETED:
            continue
        try:
            payload = MockExamCompletedPayload.model_validate(event.payload)
        except ValidationError:
            continue
        if payload.exam_type != exam_type:
            continue
        return ParentReportMockSummaryResponse(
            exam_type=cast(Literal["WEEKLY", "MONTHLY"], payload.exam_type),
            period_key=payload.period_key,
            track=payload.track,
            planned_items=payload.planned_items,
            completed_items=payload.completed_items,
            listening_correct_count=payload.listening_correct_count,
            reading_correct_count=payload.reading_correct_count,
            wrong_count=payload.wrong_count,
            occurred_at=_normalize_utc(event.occurred_at_client),
        )
    return None


def _build_recent_activity(
    *,
    daily_summary: DailyReportResponse | None,
    weekly_summary: WeeklyReportResponse | None,
    monthly_summary: MonthlyReportResponse | None,
    vocab_summary: ParentReportVocabSummaryResponse | None,
    weekly_mock_summary: ParentReportMockSummaryResponse | None,
    monthly_mock_summary: ParentReportMockSummaryResponse | None,
) -> list[ParentReportActivityResponse]:
    items: list[ParentReportActivityResponse] = []

    if daily_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="DAILY",
                day_key=daily_summary.day_key,
                period_key=None,
                track=None,
                answered_count=daily_summary.answered_count,
                correct_count=daily_summary.correct_count,
                wrong_count=daily_summary.wrong_count,
                occurred_at=_normalize_optional_utc(
                    daily_summary.aggregated_at or daily_summary.last_occurred_at
                ),
            )
        )
    if weekly_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="WEEKLY_REPORT",
                day_key=None,
                period_key=weekly_summary.week_key,
                track=None,
                answered_count=weekly_summary.answered_count,
                correct_count=weekly_summary.correct_count,
                wrong_count=weekly_summary.wrong_count,
                occurred_at=_normalize_optional_utc(
                    weekly_summary.aggregated_at or weekly_summary.last_occurred_at
                ),
            )
        )
    if monthly_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="MONTHLY_REPORT",
                day_key=None,
                period_key=monthly_summary.period_key,
                track=None,
                answered_count=monthly_summary.answered_count,
                correct_count=monthly_summary.correct_count,
                wrong_count=monthly_summary.wrong_count,
                occurred_at=_normalize_optional_utc(
                    monthly_summary.aggregated_at or monthly_summary.last_occurred_at
                ),
            )
        )
    if vocab_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="VOCAB",
                day_key=vocab_summary.day_key,
                period_key=None,
                track=vocab_summary.track,
                answered_count=vocab_summary.total_count,
                correct_count=vocab_summary.correct_count,
                wrong_count=vocab_summary.wrong_count,
                occurred_at=vocab_summary.occurred_at,
            )
        )
    if weekly_mock_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="WEEKLY_MOCK",
                day_key=None,
                period_key=weekly_mock_summary.period_key,
                track=weekly_mock_summary.track,
                answered_count=weekly_mock_summary.completed_items,
                correct_count=(
                    weekly_mock_summary.listening_correct_count
                    + weekly_mock_summary.reading_correct_count
                ),
                wrong_count=weekly_mock_summary.wrong_count,
                occurred_at=weekly_mock_summary.occurred_at,
            )
        )
    if monthly_mock_summary is not None:
        items.append(
            ParentReportActivityResponse(
                activity_type="MONTHLY_MOCK",
                day_key=None,
                period_key=monthly_mock_summary.period_key,
                track=monthly_mock_summary.track,
                answered_count=monthly_mock_summary.completed_items,
                correct_count=(
                    monthly_mock_summary.listening_correct_count
                    + monthly_mock_summary.reading_correct_count
                ),
                wrong_count=monthly_mock_summary.wrong_count,
                occurred_at=monthly_mock_summary.occurred_at,
            )
        )

    items = [item for item in items if item.occurred_at is not None]
    items.sort(
        key=lambda item: _normalize_optional_utc(item.occurred_at)
        or datetime.min.replace(tzinfo=UTC),
        reverse=True,
    )
    return items[:_MAX_RECENT_ACTIVITY_ITEMS]


def _to_daily_report_response(aggregate: DailyReportAggregate | None) -> DailyReportResponse | None:
    if aggregate is None:
        return None
    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    return DailyReportResponse(
        student_id=aggregate.student_id,
        day_key=aggregate.day_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=_resolve_top_wrong_reason_tag(
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=normalized_counts,
            persisted_top=aggregate.top_wrong_reason_tag,
        ),
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def _to_weekly_report_response(
    aggregate: WeeklyReportAggregate | None,
) -> WeeklyReportResponse | None:
    if aggregate is None:
        return None
    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    return WeeklyReportResponse(
        student_id=aggregate.student_id,
        week_key=aggregate.week_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=_resolve_top_wrong_reason_tag(
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=normalized_counts,
            persisted_top=aggregate.top_wrong_reason_tag,
        ),
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def _to_monthly_report_response(
    aggregate: MonthlyReportAggregate | None,
) -> MonthlyReportResponse | None:
    if aggregate is None:
        return None
    normalized_counts = _normalize_wrong_reason_counts(aggregate.wrong_reason_counts)
    return MonthlyReportResponse(
        student_id=aggregate.student_id,
        period_key=aggregate.period_key,
        answered_count=aggregate.answered_count,
        correct_count=aggregate.correct_count,
        wrong_count=aggregate.wrong_count,
        wrong_reason_counts=normalized_counts,
        top_wrong_reason_tag=_resolve_top_wrong_reason_tag(
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=normalized_counts,
            persisted_top=aggregate.top_wrong_reason_tag,
        ),
        first_occurred_at=aggregate.first_occurred_at,
        last_occurred_at=aggregate.last_occurred_at,
        aggregated_at=aggregate.aggregated_at,
    )


def _normalize_wrong_reason_counts(raw_counts: dict[str, int]) -> dict[WrongReasonTagValue, int]:
    normalized: dict[WrongReasonTagValue, int] = {
        cast(WrongReasonTagValue, tag): 0 for tag in WRONG_REASON_TAG_DB_VALUES
    }
    for tag in WRONG_REASON_TAG_DB_VALUES:
        normalized[cast(WrongReasonTagValue, tag)] = int(raw_counts.get(tag, 0))
    return normalized


def _resolve_top_wrong_reason_tag(
    *,
    wrong_count: int,
    wrong_reason_counts: dict[WrongReasonTagValue, int],
    persisted_top: str | None,
) -> WrongReasonTagValue | None:
    if wrong_count <= 0:
        return None
    if persisted_top in WRONG_REASON_TAG_DB_VALUES:
        return cast(WrongReasonTagValue, persisted_top)
    return cast(
        WrongReasonTagValue,
        sorted(
            WRONG_REASON_TAG_DB_VALUES,
            key=lambda tag: (
                -int(wrong_reason_counts.get(cast(WrongReasonTagValue, tag), 0)),
                tag,
            ),
        )[0],
    )


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _normalize_optional_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return _normalize_utc(value)
