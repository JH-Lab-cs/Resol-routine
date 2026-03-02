from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.policies import (
    SYNC_EVENTS_BATCH_MAX_SIZE,
    SYNC_EVENT_TYPE_MOCK_EXAM_ATTEMPT_SAVED,
    SYNC_EVENT_TYPE_TODAY_ATTEMPT_SAVED,
)
from app.models.study_event import StudyEvent
from app.schemas.sync import (
    MockExamAttemptSavedPayload,
    SyncBatchSummary,
    SyncEventCommon,
    SyncEventItemResult,
    SyncEventsBatchEnvelope,
    SyncEventsBatchResponse,
    SyncItemStatus,
    TodayAttemptSavedPayload,
)
from app.workers.tasks import trigger_student_event_aggregation

logger = logging.getLogger(__name__)


def ingest_events_batch(
    db: Session,
    *,
    student_id: UUID,
    raw_body: dict[str, Any],
) -> SyncEventsBatchResponse:
    envelope = _parse_batch_envelope(raw_body)
    events = envelope.events

    if not events:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="events_must_not_be_empty",
        )

    if len(events) > SYNC_EVENTS_BATCH_MAX_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="batch_size_exceeded",
        )

    results: list[SyncEventItemResult] = []
    accepted_count = 0
    duplicate_count = 0
    invalid_count = 0
    should_trigger = False

    for index, raw_event in enumerate(events):
        result = _process_event_item(
            db,
            student_id=student_id,
            index=index,
            raw_event=raw_event,
        )
        results.append(result)

        if result.status == SyncItemStatus.ACCEPTED:
            accepted_count += 1
            should_trigger = True
        elif result.status == SyncItemStatus.DUPLICATE:
            duplicate_count += 1
        else:
            invalid_count += 1

    if should_trigger:
        try:
            trigger_student_event_aggregation(student_id=student_id)
        except Exception:
            logger.exception(
                "Failed to enqueue event aggregation trigger",
                extra={"student_id": str(student_id)},
            )

    summary = SyncBatchSummary(
        accepted=accepted_count,
        duplicate=duplicate_count,
        invalid=invalid_count,
        total=len(events),
    )

    logger.info(
        "Processed sync event batch",
        extra={
            "student_id": str(student_id),
            "accepted": accepted_count,
            "duplicate": duplicate_count,
            "invalid": invalid_count,
            "total": len(events),
        },
    )

    return SyncEventsBatchResponse(results=results, summary=summary)


def _parse_batch_envelope(raw_body: dict[str, Any]) -> SyncEventsBatchEnvelope:
    try:
        return SyncEventsBatchEnvelope.model_validate(raw_body)
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_extract_validation_detail_code(exc, default_code="invalid_batch_envelope"),
        ) from exc


def _process_event_item(
    db: Session,
    *,
    student_id: UUID,
    index: int,
    raw_event: Any,
) -> SyncEventItemResult:
    fallback_idempotency_key = _extract_idempotency_key(raw_event)

    try:
        common = SyncEventCommon.model_validate(raw_event)
    except ValidationError as exc:
        return SyncEventItemResult(
            index=index,
            idempotency_key=fallback_idempotency_key,
            status=SyncItemStatus.INVALID,
            detail_code=_extract_validation_detail_code(exc, default_code="invalid_event_item"),
        )

    try:
        normalized_payload = _validate_payload(common.event_type, common.payload)
    except ValidationError as exc:
        return SyncEventItemResult(
            index=index,
            idempotency_key=common.idempotency_key,
            status=SyncItemStatus.INVALID,
            detail_code=_extract_validation_detail_code(exc, default_code="invalid_payload"),
        )
    except ValueError as exc:
        return SyncEventItemResult(
            index=index,
            idempotency_key=common.idempotency_key,
            status=SyncItemStatus.INVALID,
            detail_code=str(exc),
        )

    try:
        with db.begin_nested():
            existing = db.execute(
                select(StudyEvent.id).where(
                    StudyEvent.student_id == student_id,
                    StudyEvent.idempotency_key == common.idempotency_key,
                )
            ).scalar_one_or_none()

            if existing is not None:
                return SyncEventItemResult(
                    index=index,
                    idempotency_key=common.idempotency_key,
                    status=SyncItemStatus.DUPLICATE,
                )

            db.add(
                StudyEvent(
                    student_id=student_id,
                    event_type=common.event_type,
                    schema_version=common.schema_version,
                    device_id=common.device_id,
                    occurred_at_client=_normalize_utc(common.occurred_at_client),
                    idempotency_key=common.idempotency_key,
                    payload=normalized_payload,
                )
            )
            db.flush()
    except IntegrityError:
        return SyncEventItemResult(
            index=index,
            idempotency_key=common.idempotency_key,
            status=SyncItemStatus.DUPLICATE,
        )

    return SyncEventItemResult(
        index=index,
        idempotency_key=common.idempotency_key,
        status=SyncItemStatus.ACCEPTED,
    )


def _validate_payload(event_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    if event_type == SYNC_EVENT_TYPE_TODAY_ATTEMPT_SAVED:
        validated = TodayAttemptSavedPayload.model_validate(payload)
        return validated.model_dump(by_alias=True)

    if event_type == SYNC_EVENT_TYPE_MOCK_EXAM_ATTEMPT_SAVED:
        validated = MockExamAttemptSavedPayload.model_validate(payload)
        return validated.model_dump(by_alias=True)

    raise ValueError("invalid_event_type")


def _extract_idempotency_key(raw_event: Any) -> str | None:
    if not isinstance(raw_event, dict):
        return None

    raw_key = raw_event.get("idempotency_key")
    if isinstance(raw_key, str):
        return raw_key
    return None


def _extract_validation_detail_code(error: ValidationError, *, default_code: str) -> str:
    errors = error.errors()
    if not errors:
        return default_code

    first_error = errors[0]
    message = first_error.get("msg")
    if isinstance(message, str):
        marker = "Value error, "
        if message.startswith(marker):
            return message[len(marker) :]

    error_type = first_error.get("type")
    if error_type in {"missing", "extra_forbidden"}:
        return default_code
    return default_code


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise ValueError("invalid_occurred_at_client")
    return value.astimezone(UTC)
