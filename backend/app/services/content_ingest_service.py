from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.content_asset import ContentAsset
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.schemas.content import (
    ContentQuestionResponse,
    ContentUnitCreateRequest,
    ContentUnitResponse,
    ContentUnitRevisionCreateRequest,
    ContentUnitRevisionResponse,
)
from app.services.content_calibration_service import extract_content_calibration_metadata


def create_content_unit(db: Session, *, payload: ContentUnitCreateRequest) -> ContentUnitResponse:
    existing = db.execute(
        select(ContentUnit.id).where(ContentUnit.external_id == payload.external_id)
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="content_unit_external_id_conflict"
        )

    if payload.slug is not None:
        slug_exists = db.execute(
            select(ContentUnit.id).where(ContentUnit.slug == payload.slug)
        ).scalar_one_or_none()
        if slug_exists is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="content_unit_slug_conflict"
            )

    unit = ContentUnit(
        external_id=payload.external_id,
        slug=payload.slug,
        skill=payload.skill,
        track=payload.track,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )
    db.add(unit)
    db.flush()

    return _to_content_unit_response(unit)


def create_content_unit_revision(
    db: Session,
    *,
    unit_id: UUID,
    payload: ContentUnitRevisionCreateRequest,
) -> ContentUnitRevisionResponse:
    unit = db.execute(
        select(ContentUnit).where(ContentUnit.id == unit_id).with_for_update()
    ).scalar_one_or_none()
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found")
    if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived")

    if payload.asset_id is not None:
        asset = db.get(ContentAsset, payload.asset_id)
        if asset is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="asset_not_found")

    existing_revision_code = db.execute(
        select(ContentUnitRevision.id).where(
            ContentUnitRevision.content_unit_id == unit_id,
            ContentUnitRevision.revision_code == payload.revision_code,
        )
    ).scalar_one_or_none()
    if existing_revision_code is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_code_conflict")

    max_revision_no = db.execute(
        select(func.max(ContentUnitRevision.revision_no)).where(
            ContentUnitRevision.content_unit_id == unit_id
        )
    ).scalar_one()
    revision_no = (int(max_revision_no) if max_revision_no is not None else 0) + 1

    revision = ContentUnitRevision(
        content_unit_id=unit_id,
        revision_no=revision_no,
        revision_code=payload.revision_code,
        generator_version=payload.generator_version,
        validator_version=None,
        validated_at=None,
        reviewer_identity=None,
        reviewed_at=None,
        title=payload.title,
        body_text=payload.body_text,
        transcript_text=payload.transcript_text,
        explanation_text=payload.explanation_text,
        asset_id=payload.asset_id,
        metadata_json=payload.metadata_json,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )
    db.add(revision)
    db.flush()

    question_rows: list[ContentQuestion] = []
    for item in payload.questions:
        question_row = ContentQuestion(
            content_unit_revision_id=revision.id,
            question_code=item.question_code,
            order_index=item.order_index,
            stem=item.stem,
            choice_a=item.choice_a,
            choice_b=item.choice_b,
            choice_c=item.choice_c,
            choice_d=item.choice_d,
            choice_e=item.choice_e,
            correct_answer=item.correct_answer,
            explanation=item.explanation,
            metadata_json=item.metadata_json,
        )
        db.add(question_row)
        question_rows.append(question_row)
    db.flush()

    ordered_questions = sorted(
        question_rows, key=lambda row: (row.order_index, row.question_code, str(row.id))
    )
    return _to_revision_response(revision, ordered_questions)


def _to_content_unit_response(unit: ContentUnit) -> ContentUnitResponse:
    return ContentUnitResponse(
        id=unit.id,
        external_id=unit.external_id,
        slug=unit.slug,
        skill=unit.skill,
        track=unit.track,
        lifecycle_status=unit.lifecycle_status,
        published_revision_id=unit.published_revision_id,
        created_at=unit.created_at,
        updated_at=unit.updated_at,
    )


def _to_question_response(question: ContentQuestion) -> ContentQuestionResponse:
    return ContentQuestionResponse(
        id=question.id,
        question_code=question.question_code,
        order_index=question.order_index,
        stem=question.stem,
        choice_a=question.choice_a,
        choice_b=question.choice_b,
        choice_c=question.choice_c,
        choice_d=question.choice_d,
        choice_e=question.choice_e,
        correct_answer=question.correct_answer,
        explanation=question.explanation,
        metadata_json=question.metadata_json,
        created_at=question.created_at,
        updated_at=question.updated_at,
    )


def _to_revision_response(
    revision: ContentUnitRevision,
    questions: list[ContentQuestion],
) -> ContentUnitRevisionResponse:
    calibration = extract_content_calibration_metadata(revision.metadata_json)
    can_publish = (
        revision.lifecycle_status == ContentLifecycleStatus.DRAFT
        and revision.validated_at is not None
        and revision.validator_version is not None
        and revision.reviewed_at is not None
        and revision.reviewer_identity is not None
    )
    return ContentUnitRevisionResponse(
        id=revision.id,
        content_unit_id=revision.content_unit_id,
        revision_no=revision.revision_no,
        revision_code=revision.revision_code,
        generator_version=revision.generator_version,
        validator_version=revision.validator_version,
        validated_at=revision.validated_at,
        reviewer_identity=revision.reviewer_identity,
        reviewed_at=revision.reviewed_at,
        title=revision.title,
        body_text=revision.body_text,
        transcript_text=revision.transcript_text,
        explanation_text=revision.explanation_text,
        asset_id=revision.asset_id,
        metadata_json=revision.metadata_json,
        calibration_score=_as_int_or_none(calibration, "calibrationScore"),
        calibrated_level=_as_str_or_none(calibration, "calibratedLevel"),
        calibration_pass=_as_bool_or_none(calibration, "calibrationPass"),
        calibration_warnings=_as_str_list(calibration, "calibrationWarnings"),
        calibration_fail_reasons=_as_str_list(calibration, "calibrationFailReasons"),
        calibration_rubric_version=_as_str_or_none(calibration, "calibrationRubricVersion"),
        lifecycle_status=revision.lifecycle_status,
        can_publish=can_publish,
        published_at=revision.published_at,
        created_at=revision.created_at,
        updated_at=revision.updated_at,
        questions=[_to_question_response(question) for question in questions],
    )


def _as_int_or_none(metadata: dict[str, object] | None, key: str) -> int | None:
    if not isinstance(metadata, dict):
        return None
    value = metadata.get(key)
    if isinstance(value, bool) or value is None:
        return None
    if not isinstance(value, (int, float, str)):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _as_str_or_none(metadata: dict[str, object] | None, key: str) -> str | None:
    if not isinstance(metadata, dict):
        return None
    value = metadata.get(key)
    return value if isinstance(value, str) and value.strip() else None


def _as_bool_or_none(metadata: dict[str, object] | None, key: str) -> bool | None:
    if not isinstance(metadata, dict):
        return None
    value = metadata.get(key)
    return value if isinstance(value, bool) else None


def _as_str_list(metadata: dict[str, object] | None, key: str) -> list[str]:
    if not isinstance(metadata, dict):
        return []
    value = metadata.get(key)
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str)]
