from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import update
from sqlalchemy.orm import Session

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Skill
from app.schemas.content import (
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
from app.services.content_ingest_service import _to_revision_response


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
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived")
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable")

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
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived")
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable")
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
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_revision_archived")

    previous_published_revision_id = unit.published_revision_id
    published_at = _publish_revision(
        db,
        unit=unit,
        revision=revision,
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
                str(previous_published_revision_id) if previous_published_revision_id is not None else None
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
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="no_active_published_revision")
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

    return ContentUnitArchiveResponse(
        unit_id=unit.id,
        lifecycle_status=unit.lifecycle_status,
        archived_at=archived_at,
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
    unit = (
        db.query(ContentUnit)
        .filter(ContentUnit.id == unit_id)
        .with_for_update()
        .one_or_none()
    )
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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_revision_not_found")
    return revision


def _validate_revision_for_publish(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    questions: list[ContentQuestion],
) -> None:
    if not questions:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="publish_requires_questions")

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
