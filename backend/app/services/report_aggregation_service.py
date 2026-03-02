from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.policies import (
    SYNC_EVENT_TYPE_MOCK_EXAM_ATTEMPT_SAVED,
    SYNC_EVENT_TYPE_TODAY_ATTEMPT_SAVED,
    WRONG_REASON_TAG_DB_VALUES,
)
from app.core.timekeys import day_key, to_kst, week_key
from app.models.daily_report_aggregate import DailyReportAggregate
from app.models.monthly_report_aggregate import MonthlyReportAggregate
from app.models.study_event import StudyEvent
from app.models.student_attempt_projection import StudentAttemptProjection
from app.models.weekly_report_aggregate import WeeklyReportAggregate
from app.schemas.sync import MockExamAttemptSavedPayload, TodayAttemptSavedPayload

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class ReportRecomputeResult:
    source_event_count: int
    projection_count: int
    daily_count: int
    weekly_count: int
    monthly_count: int


@dataclass(frozen=True, slots=True)
class _ProjectionSnapshot:
    student_id: UUID
    event_type: str
    session_id: int | None
    mock_session_id: int | None
    question_id: str
    selected_answer: str
    is_correct: bool
    wrong_reason_tag: str | None
    latest_event_id: int
    occurred_at_client: datetime
    day_key: str
    week_key: str
    period_key: str


@dataclass(slots=True)
class _AggregateAccumulator:
    answered_count: int
    correct_count: int
    wrong_count: int
    wrong_reason_counts: dict[str, int]
    first_occurred_at: datetime
    last_occurred_at: datetime

    @classmethod
    def from_snapshot(cls, snapshot: _ProjectionSnapshot) -> _AggregateAccumulator:
        counts = _zero_filled_wrong_reason_counts()
        answered_count = 1
        correct_count = 1 if snapshot.is_correct else 0
        wrong_count = 0 if snapshot.is_correct else 1
        if not snapshot.is_correct and snapshot.wrong_reason_tag in counts:
            counts[snapshot.wrong_reason_tag] += 1

        return cls(
            answered_count=answered_count,
            correct_count=correct_count,
            wrong_count=wrong_count,
            wrong_reason_counts=counts,
            first_occurred_at=snapshot.occurred_at_client,
            last_occurred_at=snapshot.occurred_at_client,
        )

    def consume(self, snapshot: _ProjectionSnapshot) -> None:
        self.answered_count += 1
        if snapshot.is_correct:
            self.correct_count += 1
        else:
            self.wrong_count += 1
            if snapshot.wrong_reason_tag in self.wrong_reason_counts:
                self.wrong_reason_counts[snapshot.wrong_reason_tag] += 1

        if snapshot.occurred_at_client < self.first_occurred_at:
            self.first_occurred_at = snapshot.occurred_at_client
        if snapshot.occurred_at_client > self.last_occurred_at:
            self.last_occurred_at = snapshot.occurred_at_client


def recompute_student_reports(db: Session, *, student_id: UUID) -> ReportRecomputeResult:
    with db.begin_nested():
        source_events = db.execute(
            select(StudyEvent)
            .where(
                StudyEvent.student_id == student_id,
                StudyEvent.event_type.in_(
                    (SYNC_EVENT_TYPE_TODAY_ATTEMPT_SAVED, SYNC_EVENT_TYPE_MOCK_EXAM_ATTEMPT_SAVED)
                ),
            )
            .order_by(StudyEvent.occurred_at_client.asc(), StudyEvent.id.asc())
        ).scalars().all()

        latest_snapshots = _build_latest_projection_snapshots(source_events)
        _replace_projection_rows(db, student_id=student_id, snapshots=latest_snapshots)
        daily_count, weekly_count, monthly_count = _replace_aggregate_rows(
            db,
            student_id=student_id,
            snapshots=latest_snapshots,
        )

    return ReportRecomputeResult(
        source_event_count=len(source_events),
        projection_count=len(latest_snapshots),
        daily_count=daily_count,
        weekly_count=weekly_count,
        monthly_count=monthly_count,
    )


def _build_latest_projection_snapshots(source_events: list[StudyEvent]) -> list[_ProjectionSnapshot]:
    latest_by_logical_key: dict[tuple[str, int | None, int | None, str], _ProjectionSnapshot] = {}

    for source_event in source_events:
        snapshot = _parse_snapshot(source_event)
        if snapshot is None:
            continue

        logical_key = (
            snapshot.event_type,
            snapshot.session_id,
            snapshot.mock_session_id,
            snapshot.question_id,
        )
        previous = latest_by_logical_key.get(logical_key)
        if previous is None:
            latest_by_logical_key[logical_key] = snapshot
            continue

        previous_order = (previous.occurred_at_client, previous.latest_event_id)
        current_order = (snapshot.occurred_at_client, snapshot.latest_event_id)
        if current_order > previous_order:
            latest_by_logical_key[logical_key] = snapshot

    return sorted(
        latest_by_logical_key.values(),
        key=lambda snapshot: (
            snapshot.event_type,
            snapshot.session_id or -1,
            snapshot.mock_session_id or -1,
            snapshot.question_id,
            snapshot.latest_event_id,
        ),
    )


def _parse_snapshot(source_event: StudyEvent) -> _ProjectionSnapshot | None:
    occurred_at_client = _normalize_utc(source_event.occurred_at_client)
    day = day_key(occurred_at_client)
    week = week_key(occurred_at_client)
    period = to_kst(occurred_at_client).strftime("%Y%m")

    try:
        if source_event.event_type == SYNC_EVENT_TYPE_TODAY_ATTEMPT_SAVED:
            payload = TodayAttemptSavedPayload.model_validate(source_event.payload)
            return _ProjectionSnapshot(
                student_id=source_event.student_id,
                event_type=source_event.event_type,
                session_id=payload.session_id,
                mock_session_id=None,
                question_id=payload.question_id,
                selected_answer=payload.selected_answer,
                is_correct=payload.is_correct,
                wrong_reason_tag=payload.wrong_reason_tag,
                latest_event_id=source_event.id,
                occurred_at_client=occurred_at_client,
                day_key=day,
                week_key=week,
                period_key=period,
            )

        if source_event.event_type == SYNC_EVENT_TYPE_MOCK_EXAM_ATTEMPT_SAVED:
            payload = MockExamAttemptSavedPayload.model_validate(source_event.payload)
            return _ProjectionSnapshot(
                student_id=source_event.student_id,
                event_type=source_event.event_type,
                session_id=None,
                mock_session_id=payload.mock_session_id,
                question_id=payload.question_id,
                selected_answer=payload.selected_answer,
                is_correct=payload.is_correct,
                wrong_reason_tag=payload.wrong_reason_tag,
                latest_event_id=source_event.id,
                occurred_at_client=occurred_at_client,
                day_key=day,
                week_key=week,
                period_key=period,
            )
    except ValidationError:
        logger.warning(
            "Skipped invalid source event during report projection",
            extra={
                "student_id": str(source_event.student_id),
                "event_id": source_event.id,
                "event_type": source_event.event_type,
            },
        )
        return None

    return None


def _replace_projection_rows(
    db: Session,
    *,
    student_id: UUID,
    snapshots: list[_ProjectionSnapshot],
) -> None:
    db.execute(delete(StudentAttemptProjection).where(StudentAttemptProjection.student_id == student_id))
    db.flush()

    if not snapshots:
        return

    db.add_all(
        [
            StudentAttemptProjection(
                student_id=snapshot.student_id,
                event_type=snapshot.event_type,
                session_id=snapshot.session_id,
                mock_session_id=snapshot.mock_session_id,
                question_id=snapshot.question_id,
                selected_answer=snapshot.selected_answer,
                is_correct=snapshot.is_correct,
                wrong_reason_tag=snapshot.wrong_reason_tag,
                latest_event_id=snapshot.latest_event_id,
                occurred_at_client=snapshot.occurred_at_client,
                day_key=snapshot.day_key,
                week_key=snapshot.week_key,
                period_key=snapshot.period_key,
            )
            for snapshot in snapshots
        ]
    )
    db.flush()


def _replace_aggregate_rows(
    db: Session,
    *,
    student_id: UUID,
    snapshots: list[_ProjectionSnapshot],
) -> tuple[int, int, int]:
    daily_accumulator: dict[str, _AggregateAccumulator] = {}
    weekly_accumulator: dict[str, _AggregateAccumulator] = {}
    monthly_accumulator: dict[str, _AggregateAccumulator] = {}

    for snapshot in snapshots:
        _consume_projection_by_key(daily_accumulator, snapshot.day_key, snapshot)
        _consume_projection_by_key(weekly_accumulator, snapshot.week_key, snapshot)
        _consume_projection_by_key(monthly_accumulator, snapshot.period_key, snapshot)

    db.execute(delete(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id))
    db.execute(delete(WeeklyReportAggregate).where(WeeklyReportAggregate.student_id == student_id))
    db.execute(delete(MonthlyReportAggregate).where(MonthlyReportAggregate.student_id == student_id))
    db.flush()

    daily_rows = [
        DailyReportAggregate(
            student_id=student_id,
            day_key=key,
            answered_count=aggregate.answered_count,
            correct_count=aggregate.correct_count,
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=_normalize_wrong_reason_counts(aggregate.wrong_reason_counts),
            top_wrong_reason_tag=_top_wrong_reason_tag(aggregate.wrong_reason_counts, aggregate.wrong_count),
            first_occurred_at=aggregate.first_occurred_at,
            last_occurred_at=aggregate.last_occurred_at,
            aggregated_at=aggregate.last_occurred_at,
        )
        for key, aggregate in sorted(daily_accumulator.items())
    ]
    weekly_rows = [
        WeeklyReportAggregate(
            student_id=student_id,
            week_key=key,
            answered_count=aggregate.answered_count,
            correct_count=aggregate.correct_count,
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=_normalize_wrong_reason_counts(aggregate.wrong_reason_counts),
            top_wrong_reason_tag=_top_wrong_reason_tag(aggregate.wrong_reason_counts, aggregate.wrong_count),
            first_occurred_at=aggregate.first_occurred_at,
            last_occurred_at=aggregate.last_occurred_at,
            aggregated_at=aggregate.last_occurred_at,
        )
        for key, aggregate in sorted(weekly_accumulator.items())
    ]
    monthly_rows = [
        MonthlyReportAggregate(
            student_id=student_id,
            period_key=key,
            answered_count=aggregate.answered_count,
            correct_count=aggregate.correct_count,
            wrong_count=aggregate.wrong_count,
            wrong_reason_counts=_normalize_wrong_reason_counts(aggregate.wrong_reason_counts),
            top_wrong_reason_tag=_top_wrong_reason_tag(aggregate.wrong_reason_counts, aggregate.wrong_count),
            first_occurred_at=aggregate.first_occurred_at,
            last_occurred_at=aggregate.last_occurred_at,
            aggregated_at=aggregate.last_occurred_at,
        )
        for key, aggregate in sorted(monthly_accumulator.items())
    ]

    if daily_rows:
        db.add_all(daily_rows)
    if weekly_rows:
        db.add_all(weekly_rows)
    if monthly_rows:
        db.add_all(monthly_rows)
    db.flush()

    return len(daily_rows), len(weekly_rows), len(monthly_rows)


def _consume_projection_by_key(
    accumulator_map: dict[str, _AggregateAccumulator],
    key: str,
    snapshot: _ProjectionSnapshot,
) -> None:
    current = accumulator_map.get(key)
    if current is None:
        accumulator_map[key] = _AggregateAccumulator.from_snapshot(snapshot)
        return
    current.consume(snapshot)


def _normalize_wrong_reason_counts(raw_counts: dict[str, int]) -> dict[str, int]:
    normalized = _zero_filled_wrong_reason_counts()
    for tag in WRONG_REASON_TAG_DB_VALUES:
        normalized[tag] = int(raw_counts.get(tag, 0))
    return normalized


def _zero_filled_wrong_reason_counts() -> dict[str, int]:
    return {tag: 0 for tag in WRONG_REASON_TAG_DB_VALUES}


def _top_wrong_reason_tag(reason_counts: dict[str, int], wrong_count: int) -> str | None:
    if wrong_count <= 0:
        return None
    return sorted(
        WRONG_REASON_TAG_DB_VALUES,
        key=lambda tag: (-int(reason_counts.get(tag, 0)), tag),
    )[0]


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
