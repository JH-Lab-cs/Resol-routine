from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.schemas.content import (
    ContentQuestionListItem,
    ContentQuestionListQuery,
    ContentQuestionListResponse,
    ContentQuestionResponse,
    ContentUnitListQuery,
    ContentUnitListResponse,
    ContentUnitResponse,
    ContentUnitRevisionListResponse,
    ContentUnitRevisionResponse,
)


def get_content_unit(db: Session, *, unit_id: UUID) -> ContentUnitResponse:
    unit = db.get(ContentUnit, unit_id)
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found")
    return _to_content_unit_response(unit)


def list_content_units(db: Session, *, query: ContentUnitListQuery) -> ContentUnitListResponse:
    stmt = select(ContentUnit)

    if query.published_only:
        stmt = stmt.where(
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id.is_not(None),
        )
    elif query.lifecycle_status is None:
        stmt = stmt.where(ContentUnit.lifecycle_status != ContentLifecycleStatus.ARCHIVED)

    if query.lifecycle_status is not None:
        stmt = stmt.where(ContentUnit.lifecycle_status == query.lifecycle_status)
    if query.skill is not None:
        stmt = stmt.where(ContentUnit.skill == query.skill)
    if query.track is not None:
        stmt = stmt.where(ContentUnit.track == query.track)
    if query.external_id is not None:
        stmt = stmt.where(ContentUnit.external_id == query.external_id)
    if query.slug is not None:
        stmt = stmt.where(ContentUnit.slug == query.slug)

    total = db.execute(
        select(func.count()).select_from(stmt.subquery())
    ).scalar_one()

    offset = (query.page - 1) * query.page_size
    rows = db.execute(
        stmt.order_by(
            ContentUnit.external_id.asc(),
            ContentUnit.id.asc(),
        )
        .offset(offset)
        .limit(query.page_size)
    ).scalars().all()

    return ContentUnitListResponse(
        items=[_to_content_unit_response(row) for row in rows],
        total=int(total),
        page=query.page,
        page_size=query.page_size,
    )


def list_content_unit_revisions(db: Session, *, unit_id: UUID) -> ContentUnitRevisionListResponse:
    unit = db.get(ContentUnit, unit_id)
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found")

    revisions = db.execute(
        select(ContentUnitRevision)
        .where(ContentUnitRevision.content_unit_id == unit_id)
        .order_by(
            ContentUnitRevision.revision_no.asc(),
            ContentUnitRevision.id.asc(),
        )
    ).scalars().all()

    revision_ids = [revision.id for revision in revisions]
    questions_by_revision_id: dict[UUID, list[ContentQuestion]] = {revision_id: [] for revision_id in revision_ids}
    if revision_ids:
        questions = db.execute(
            select(ContentQuestion)
            .where(ContentQuestion.content_unit_revision_id.in_(revision_ids))
            .order_by(
                ContentQuestion.content_unit_revision_id.asc(),
                ContentQuestion.order_index.asc(),
                ContentQuestion.question_code.asc(),
                ContentQuestion.id.asc(),
            )
        ).scalars().all()
        for question in questions:
            questions_by_revision_id.setdefault(question.content_unit_revision_id, []).append(question)

    return ContentUnitRevisionListResponse(
        unit_id=unit_id,
        items=[
            _to_revision_response(
                revision=revision,
                questions=questions_by_revision_id.get(revision.id, []),
            )
            for revision in revisions
        ],
    )


def list_content_questions(db: Session, *, query: ContentQuestionListQuery) -> ContentQuestionListResponse:
    stmt = (
        select(ContentQuestion, ContentUnitRevision, ContentUnit)
        .join(
            ContentUnitRevision,
            ContentQuestion.content_unit_revision_id == ContentUnitRevision.id,
        )
        .join(
            ContentUnit,
            ContentUnitRevision.content_unit_id == ContentUnit.id,
        )
    )

    if query.published_only:
        stmt = stmt.where(
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
        )
    elif query.lifecycle_status is None:
        stmt = stmt.where(
            ContentUnit.lifecycle_status != ContentLifecycleStatus.ARCHIVED,
            ContentUnitRevision.lifecycle_status != ContentLifecycleStatus.ARCHIVED,
        )

    if query.lifecycle_status is not None:
        stmt = stmt.where(ContentUnitRevision.lifecycle_status == query.lifecycle_status)
    if query.skill is not None:
        stmt = stmt.where(ContentUnit.skill == query.skill)
    if query.track is not None:
        stmt = stmt.where(ContentUnit.track == query.track)
    if query.unit_id is not None:
        stmt = stmt.where(ContentUnit.id == query.unit_id)
    if query.revision_id is not None:
        stmt = stmt.where(ContentUnitRevision.id == query.revision_id)
    if query.question_code is not None:
        stmt = stmt.where(ContentQuestion.question_code == query.question_code)
    if query.unit_external_id is not None:
        stmt = stmt.where(ContentUnit.external_id == query.unit_external_id)

    total = db.execute(
        select(func.count()).select_from(stmt.subquery())
    ).scalar_one()

    offset = (query.page - 1) * query.page_size
    rows = db.execute(
        stmt.order_by(
            ContentUnit.external_id.asc(),
            ContentUnitRevision.revision_no.asc(),
            ContentQuestion.order_index.asc(),
            ContentQuestion.question_code.asc(),
            ContentQuestion.id.asc(),
        )
        .offset(offset)
        .limit(query.page_size)
    ).all()

    items = [
        ContentQuestionListItem(
            unit_id=unit.id,
            revision_id=revision.id,
            unit_external_id=unit.external_id,
            skill=unit.skill,
            track=unit.track,
            question=_to_question_response(question),
        )
        for question, revision, unit in rows
    ]

    return ContentQuestionListResponse(
        items=items,
        total=int(total),
        page=query.page,
        page_size=query.page_size,
    )


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
    *,
    revision: ContentUnitRevision,
    questions: list[ContentQuestion],
) -> ContentUnitRevisionResponse:
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
        lifecycle_status=revision.lifecycle_status,
        published_at=revision.published_at,
        created_at=revision.created_at,
        updated_at=revision.updated_at,
        questions=[_to_question_response(question) for question in questions],
    )
