from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.input_validation import validate_user_input_text
from app.core.policies import CONTENT_IDENTIFIER_MAX_LENGTH
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_sync_enums import ContentSyncEventReason
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Skill
from app.schemas.content import (
    ContentRevisionArchiveResponse,
    ContentRevisionReviewRequest,
    ContentRevisionValidateRequest,
    ContentUnitArchiveResponse,
    ContentUnitPublishRequest,
    ContentUnitPublishResponse,
    ContentUnitRevisionResponse,
    ContentUnitRollbackRequest,
    ContentUnitRollbackResponse,
)
from app.services.audit_service import append_audit_log
from app.services.content_calibration_service import (
    evaluate_content_calibration,
    is_calibration_publish_blocked,
    merge_content_calibration_metadata,
)
from app.services.content_ingest_service import _to_revision_response
from app.services.content_sync_service import (
    append_content_delete_event,
    append_content_upsert_event,
)

# Lifecycle contract:
# - Status enum remains minimal (DRAFT / PUBLISHED / ARCHIVED).
# - Validation and review are trace fields (validator_version/validated_at,
#   reviewer_identity/reviewed_at), not enum states.
# - Publish is allowed only when the traceability gate is satisfied.


def validate_content_unit_revision(
    db: Session,
    *,
    unit_id: UUID,
    revision_id: UUID,
    payload: ContentRevisionValidateRequest,
) -> ContentUnitRevisionResponse:
    unit = _get_unit_for_update(db, unit_id=unit_id)
    if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived")

    revision = _get_revision_for_update(
        db,
        unit_id=unit_id,
        revision_id=revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived"
        )
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable"
        )

    revision.validator_version = payload.validator_version
    revision.validated_at = datetime.now(UTC)
    db.flush()

    questions = _load_revision_questions(db, revision_id=revision.id)
    return _to_revision_response(revision, questions)


def review_content_unit_revision(
    db: Session,
    *,
    unit_id: UUID,
    revision_id: UUID,
    payload: ContentRevisionReviewRequest,
) -> ContentUnitRevisionResponse:
    unit = _get_unit_for_update(db, unit_id=unit_id)
    if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived")

    revision = _get_revision_for_update(
        db,
        unit_id=unit_id,
        revision_id=revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived"
        )
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable"
        )
    if revision.validated_at is None or revision.validator_version is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_validated")

    revision.reviewer_identity = payload.reviewer_identity
    revision.reviewed_at = datetime.now(UTC)
    db.flush()

    questions = _load_revision_questions(db, revision_id=revision.id)
    return _to_revision_response(revision, questions)


def publish_content_unit_revision(
    db: Session,
    *,
    unit_id: UUID,
    payload: ContentUnitPublishRequest,
) -> ContentUnitPublishResponse:
    unit = _get_unit_for_update(db, unit_id=unit_id)
    if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived")
    if unit.published_revision_id == payload.revision_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="published_revision_already_active",
        )

    revision = _get_revision_for_update(
        db,
        unit_id=unit_id,
        revision_id=payload.revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived"
        )

    previous_published_revision_id = unit.published_revision_id
    published_at = _publish_revision(
        db,
        unit=unit,
        revision=revision,
    )

    if previous_published_revision_id is not None:
        append_content_delete_event(
            db,
            unit=unit,
            revision_id=previous_published_revision_id,
            changed_at=published_at,
            reason=ContentSyncEventReason.REPLACED,
        )
    append_content_upsert_event(
        db,
        unit=unit,
        revision=revision,
        published_at=published_at,
        reason=ContentSyncEventReason.PUBLISHED,
    )

    append_audit_log(
        db,
        action="content_revision_published",
        actor_user_id=None,
        target_user_id=None,
        details={
            "unit_id": str(unit.id),
            "revision_id": str(revision.id),
            "previous_published_revision_id": (
                str(previous_published_revision_id)
                if previous_published_revision_id is not None
                else None
            ),
            "published_at": published_at.isoformat(),
        },
    )

    return _to_publish_response(unit=unit, revision=revision, published_at=published_at)


def rollback_content_unit_revision(
    db: Session,
    *,
    unit_id: UUID,
    payload: ContentUnitRollbackRequest,
) -> ContentUnitRollbackResponse:
    unit = _get_unit_for_update(db, unit_id=unit_id)
    if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived")
    if unit.published_revision_id is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="no_active_published_revision"
        )
    if unit.published_revision_id == payload.target_revision_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="rollback_target_is_active_published",
        )

    target_revision = _get_revision_for_update(
        db,
        unit_id=unit_id,
        revision_id=payload.target_revision_id,
    )
    if target_revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="rollback_target_archived")

    previous_published_revision_id = unit.published_revision_id
    published_at = _publish_revision(
        db,
        unit=unit,
        revision=target_revision,
    )

    append_content_delete_event(
        db,
        unit=unit,
        revision_id=previous_published_revision_id,
        changed_at=published_at,
        reason=ContentSyncEventReason.REPLACED,
    )
    append_content_upsert_event(
        db,
        unit=unit,
        revision=target_revision,
        published_at=published_at,
        reason=ContentSyncEventReason.PUBLISHED,
    )

    append_audit_log(
        db,
        action="content_revision_rolled_back",
        actor_user_id=None,
        target_user_id=None,
        details={
            "unit_id": str(unit.id),
            "from_revision_id": str(previous_published_revision_id),
            "to_revision_id": str(target_revision.id),
            "rolled_back_at": published_at.isoformat(),
        },
    )

    return ContentUnitRollbackResponse(
        unit_id=unit.id,
        previous_published_revision_id=previous_published_revision_id,
        rolled_back_to_revision_id=target_revision.id,
        lifecycle_status=unit.lifecycle_status,
        published_at=published_at,
    )


def archive_content_unit(db: Session, *, unit_id: UUID) -> ContentUnitArchiveResponse:
    unit = _get_unit_for_update(db, unit_id=unit_id)
    previous_published_revision_id = unit.published_revision_id

    db.execute(
        update(ContentUnitRevision)
        .where(
            ContentUnitRevision.content_unit_id == unit_id,
            ContentUnitRevision.lifecycle_status != ContentLifecycleStatus.ARCHIVED,
        )
        .values(lifecycle_status=ContentLifecycleStatus.ARCHIVED)
    )

    archived_at = datetime.now(UTC)
    unit.lifecycle_status = ContentLifecycleStatus.ARCHIVED
    unit.published_revision_id = None
    db.flush()

    if previous_published_revision_id is not None:
        append_content_delete_event(
            db,
            unit=unit,
            revision_id=previous_published_revision_id,
            changed_at=archived_at,
            reason=ContentSyncEventReason.UNPUBLISHED,
        )

    return ContentUnitArchiveResponse(
        unit_id=unit.id,
        lifecycle_status=unit.lifecycle_status,
        archived_at=archived_at,
    )


def archive_content_revision(
    db: Session,
    *,
    revision_id: UUID,
    reason: str,
    archived_by: str = "reviewer_ops_cli",
) -> ContentRevisionArchiveResponse:
    revision = (
        db.query(ContentUnitRevision)
        .filter(ContentUnitRevision.id == revision_id)
        .with_for_update()
        .one_or_none()
    )
    if revision is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="REVISION_NOT_FOUND")
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="REVISION_ALREADY_ARCHIVED"
        )

    unit = _get_unit_for_update(db, unit_id=revision.content_unit_id)
    was_published_revision = unit.published_revision_id == revision.id
    archived_reason = _validate_archive_reason(reason)
    archived_by_identity = _validate_archive_actor_identity(archived_by)
    archived_at = datetime.now(UTC)

    revision.lifecycle_status = ContentLifecycleStatus.ARCHIVED
    revision.metadata_json = _merge_archive_audit_metadata(
        metadata_json=revision.metadata_json,
        archived_at=archived_at,
        archived_by=archived_by_identity,
        archived_reason=archived_reason,
    )

    if unit.published_revision_id == revision.id:
        unit.published_revision_id = None

    remaining_non_archived_count = db.execute(
        select(func.count())
        .select_from(ContentUnitRevision)
        .where(
            ContentUnitRevision.content_unit_id == unit.id,
            ContentUnitRevision.id != revision.id,
            ContentUnitRevision.lifecycle_status != ContentLifecycleStatus.ARCHIVED,
        )
    ).scalar_one()
    if unit.published_revision_id is not None:
        unit.lifecycle_status = ContentLifecycleStatus.PUBLISHED
    elif int(remaining_non_archived_count) > 0:
        unit.lifecycle_status = ContentLifecycleStatus.DRAFT
    else:
        unit.lifecycle_status = ContentLifecycleStatus.ARCHIVED

    db.flush()

    if was_published_revision:
        append_content_delete_event(
            db,
            unit=unit,
            revision_id=revision.id,
            changed_at=archived_at,
            reason=ContentSyncEventReason.ARCHIVED,
        )

    return ContentRevisionArchiveResponse(
        revision_id=revision.id,
        unit_id=unit.id,
        lifecycle_status=revision.lifecycle_status,
        unit_lifecycle_status=unit.lifecycle_status,
        archived_at=archived_at,
        metadata_json=revision.metadata_json,
    )


def _publish_revision(
    db: Session,
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
) -> datetime:
    _ensure_revision_traceability_gate(revision)

    questions = _load_revision_questions(db, revision_id=revision.id)
    _validate_revision_for_publish(unit=unit, revision=revision, questions=questions)
    calibration_result = evaluate_content_calibration(
        unit=unit,
        revision=revision,
        questions=questions,
    )
    revision.metadata_json = merge_content_calibration_metadata(
        metadata_json=revision.metadata_json,
        result=calibration_result,
    )
    if is_calibration_publish_blocked(track=unit.track, result=calibration_result):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "content_calibration_failed",
                "calibrationScore": calibration_result.calibration_score,
                "calibratedLevel": calibration_result.calibrated_level.value,
                "calibrationPass": calibration_result.passed,
                "calibrationWarnings": list(calibration_result.warnings),
                "calibrationFailReasons": list(calibration_result.fail_reasons),
                "calibrationRubricVersion": calibration_result.rubric_version,
            },
        )

    now = datetime.now(UTC)
    db.execute(
        update(ContentUnitRevision)
        .where(
            ContentUnitRevision.content_unit_id == unit.id,
            ContentUnitRevision.id != revision.id,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
        )
        .values(lifecycle_status=ContentLifecycleStatus.DRAFT)
    )

    revision.lifecycle_status = ContentLifecycleStatus.PUBLISHED
    revision.published_at = now
    unit.published_revision_id = revision.id
    unit.lifecycle_status = ContentLifecycleStatus.PUBLISHED
    db.flush()
    return now


def _ensure_revision_traceability_gate(revision: ContentUnitRevision) -> None:
    if revision.validated_at is None or revision.validator_version is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_validated")
    if revision.reviewed_at is None or revision.reviewer_identity is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_reviewed")


def _to_publish_response(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    published_at: datetime,
) -> ContentUnitPublishResponse:
    if revision.validator_version is None or revision.validated_at is None:
        raise RuntimeError("validated revision traceability fields are missing")
    if revision.reviewer_identity is None or revision.reviewed_at is None:
        raise RuntimeError("reviewed revision traceability fields are missing")

    return ContentUnitPublishResponse(
        unit_id=unit.id,
        published_revision_id=revision.id,
        lifecycle_status=unit.lifecycle_status,
        generator_version=revision.generator_version,
        validator_version=revision.validator_version,
        validated_at=revision.validated_at,
        reviewer_identity=revision.reviewer_identity,
        reviewed_at=revision.reviewed_at,
        published_at=published_at,
    )


def _load_revision_questions(db: Session, *, revision_id: UUID) -> list[ContentQuestion]:
    return (
        db.query(ContentQuestion)
        .filter(ContentQuestion.content_unit_revision_id == revision_id)
        .order_by(
            ContentQuestion.order_index.asc(),
            ContentQuestion.question_code.asc(),
            ContentQuestion.id.asc(),
        )
        .all()
    )


def _get_unit_for_update(db: Session, *, unit_id: UUID) -> ContentUnit:
    unit = db.query(ContentUnit).filter(ContentUnit.id == unit_id).with_for_update().one_or_none()
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found")
    return unit


def _get_revision_for_update(
    db: Session,
    *,
    unit_id: UUID,
    revision_id: UUID,
) -> ContentUnitRevision:
    revision = (
        db.query(ContentUnitRevision)
        .filter(
            ContentUnitRevision.id == revision_id,
            ContentUnitRevision.content_unit_id == unit_id,
        )
        .with_for_update()
        .one_or_none()
    )
    if revision is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="content_revision_not_found"
        )
    return revision


def _validate_archive_reason(value: str) -> str:
    try:
        normalized = validate_user_input_text(value, field_name="reason")
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="ARCHIVE_REASON_INVALID",
        ) from exc

    if len(normalized) > 200:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="ARCHIVE_REASON_INVALID",
        )
    return normalized


def _validate_archive_actor_identity(value: str) -> str:
    normalized = value.strip()
    if not normalized:
        return "reviewer_ops_cli"
    if len(normalized) > CONTENT_IDENTIFIER_MAX_LENGTH:
        return normalized[:CONTENT_IDENTIFIER_MAX_LENGTH]
    return normalized


def _merge_archive_audit_metadata(
    *,
    metadata_json: dict[str, object] | None,
    archived_at: datetime,
    archived_by: str,
    archived_reason: str,
) -> dict[str, object]:
    merged = dict(metadata_json) if isinstance(metadata_json, dict) else {}
    merged["archiveAudit"] = {
        "archivedAtUtc": archived_at.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "archivedBy": archived_by,
        "archivedReason": archived_reason,
    }
    return merged


def _validate_revision_for_publish(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    questions: list[ContentQuestion],
) -> None:
    if not questions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="publish_requires_questions"
        )

    if unit.skill == Skill.LISTENING and not revision.transcript_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="listening_revision_requires_transcript_text",
        )

    if unit.skill == Skill.READING and not revision.body_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="reading_revision_requires_body_text",
        )
