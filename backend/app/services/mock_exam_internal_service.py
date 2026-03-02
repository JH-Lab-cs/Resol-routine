from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.policies import (
    MOCK_EXAM_MONTHLY_LISTENING_COUNT,
    MOCK_EXAM_MONTHLY_READING_COUNT,
    MOCK_EXAM_WEEKLY_LISTENING_COUNT,
    MOCK_EXAM_WEEKLY_READING_COUNT,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import MockExamType, Skill
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.mock_exam_revision_item import MockExamRevisionItem
from app.schemas.mock_exam import (
    MockExamCreateRequest,
    MockExamListQuery,
    MockExamListResponse,
    MockExamPublishRequest,
    MockExamPublishResponse,
    MockExamResponse,
    MockExamRevisionCreateRequest,
    MockExamRevisionItemCreateRequest,
    MockExamRevisionItemResponse,
    MockExamRevisionListResponse,
    MockExamRevisionResponse,
    MockExamRevisionReviewRequest,
    MockExamRevisionValidateRequest,
    MockExamRollbackRequest,
    MockExamRollbackResponse,
)
from app.services.audit_service import append_audit_log


def create_mock_exam(db: Session, *, payload: MockExamCreateRequest) -> MockExamResponse:
    existing = db.execute(
        select(MockExam.id).where(
            MockExam.exam_type == payload.exam_type,
            MockExam.track == payload.track,
            MockExam.period_key == payload.period_key,
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_period_conflict")

    if payload.external_id is not None:
        external_conflict = db.execute(
            select(MockExam.id).where(MockExam.external_id == payload.external_id)
        ).scalar_one_or_none()
        if external_conflict is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_external_id_conflict")

    if payload.slug is not None:
        slug_conflict = db.execute(
            select(MockExam.id).where(MockExam.slug == payload.slug)
        ).scalar_one_or_none()
        if slug_conflict is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_slug_conflict")

    exam = MockExam(
        exam_type=payload.exam_type,
        track=payload.track,
        period_key=payload.period_key,
        external_id=payload.external_id,
        slug=payload.slug,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )
    db.add(exam)
    db.flush()
    return _to_exam_response(exam)


def list_mock_exams(db: Session, *, query: MockExamListQuery) -> MockExamListResponse:
    stmt = select(MockExam)

    if query.published_only:
        stmt = stmt.where(
            MockExam.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            MockExam.published_revision_id.is_not(None),
        )
    elif query.lifecycle_status is None:
        stmt = stmt.where(MockExam.lifecycle_status != ContentLifecycleStatus.ARCHIVED)

    if query.exam_type is not None:
        stmt = stmt.where(MockExam.exam_type == query.exam_type)
    if query.track is not None:
        stmt = stmt.where(MockExam.track == query.track)
    if query.period_key is not None:
        stmt = stmt.where(MockExam.period_key == query.period_key)
    if query.lifecycle_status is not None:
        stmt = stmt.where(MockExam.lifecycle_status == query.lifecycle_status)

    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    offset = (query.page - 1) * query.page_size
    rows = db.execute(
        stmt.order_by(
            MockExam.exam_type.asc(),
            MockExam.track.asc(),
            MockExam.period_key.asc(),
            MockExam.id.asc(),
        )
        .offset(offset)
        .limit(query.page_size)
    ).scalars().all()

    return MockExamListResponse(
        items=[_to_exam_response(row) for row in rows],
        total=int(total),
        page=query.page,
        page_size=query.page_size,
    )


def get_mock_exam(db: Session, *, exam_id: UUID) -> MockExamResponse:
    exam = db.get(MockExam, exam_id)
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_not_found")
    return _to_exam_response(exam)


def create_mock_exam_revision(
    db: Session,
    *,
    exam_id: UUID,
    payload: MockExamRevisionCreateRequest,
) -> MockExamRevisionResponse:
    exam = _get_exam_for_update(db, exam_id=exam_id)
    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_archived")

    max_revision_no = db.execute(
        select(func.max(MockExamRevision.revision_no)).where(
            MockExamRevision.mock_exam_id == exam_id
        )
    ).scalar_one()
    revision_no = (int(max_revision_no) if max_revision_no is not None else 0) + 1

    revision = MockExamRevision(
        mock_exam_id=exam_id,
        revision_no=revision_no,
        title=payload.title,
        instructions=payload.instructions,
        generator_version=payload.generator_version,
        validator_version=None,
        validated_at=None,
        reviewer_identity=None,
        reviewed_at=None,
        metadata_json=payload.metadata_json,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
        published_at=None,
    )
    db.add(revision)
    db.flush()

    created_items: list[MockExamRevisionItem] = []
    for item_payload in sorted(payload.items, key=lambda item: item.order_index):
        question, content_revision, content_unit = _resolve_content_reference(
            db,
            item_payload=item_payload,
        )
        _ensure_reference_is_publishable(
            exam=exam,
            content_revision=content_revision,
            content_unit=content_unit,
        )

        item = MockExamRevisionItem(
            mock_exam_revision_id=revision.id,
            order_index=item_payload.order_index,
            content_unit_revision_id=item_payload.content_unit_revision_id,
            content_question_id=item_payload.content_question_id,
            question_code_snapshot=question.question_code,
            skill_snapshot=content_unit.skill,
        )
        db.add(item)
        created_items.append(item)

    db.flush()
    return _to_revision_response(revision=revision, items=created_items)


def list_mock_exam_revisions(db: Session, *, exam_id: UUID) -> MockExamRevisionListResponse:
    exam = db.get(MockExam, exam_id)
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_not_found")

    revisions = db.execute(
        select(MockExamRevision)
        .where(MockExamRevision.mock_exam_id == exam_id)
        .order_by(
            MockExamRevision.revision_no.asc(),
            MockExamRevision.id.asc(),
        )
    ).scalars().all()

    revision_ids = [revision.id for revision in revisions]
    items_by_revision_id: dict[UUID, list[MockExamRevisionItem]] = {revision_id: [] for revision_id in revision_ids}
    if revision_ids:
        item_rows = db.execute(
            select(MockExamRevisionItem)
            .where(MockExamRevisionItem.mock_exam_revision_id.in_(revision_ids))
            .order_by(
                MockExamRevisionItem.mock_exam_revision_id.asc(),
                MockExamRevisionItem.order_index.asc(),
                MockExamRevisionItem.id.asc(),
            )
        ).scalars().all()
        for row in item_rows:
            items_by_revision_id.setdefault(row.mock_exam_revision_id, []).append(row)

    return MockExamRevisionListResponse(
        mock_exam_id=exam_id,
        items=[
            _to_revision_response(
                revision=revision,
                items=items_by_revision_id.get(revision.id, []),
            )
            for revision in revisions
        ],
    )


def validate_mock_exam_revision(
    db: Session,
    *,
    exam_id: UUID,
    revision_id: UUID,
    payload: MockExamRevisionValidateRequest,
) -> MockExamRevisionResponse:
    exam = _get_exam_for_update(db, exam_id=exam_id)
    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_archived")

    revision = _get_revision_for_update(
        db,
        exam_id=exam_id,
        revision_id=revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_revision_archived")
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable")

    items = _load_revision_items(db, revision_id=revision.id)
    _validate_revision_item_integrity(
        db,
        exam=exam,
        revision=revision,
        items=items,
    )

    revision.validator_version = payload.validator_version
    revision.validated_at = datetime.now(UTC)
    db.flush()

    append_audit_log(
        db,
        action="mock_exam_revision_validated",
        actor_user_id=None,
        target_user_id=None,
        details={
            "mock_exam_id": str(exam.id),
            "revision_id": str(revision.id),
            "validator_version": revision.validator_version,
        },
    )
    return _to_revision_response(revision=revision, items=items)


def review_mock_exam_revision(
    db: Session,
    *,
    exam_id: UUID,
    revision_id: UUID,
    payload: MockExamRevisionReviewRequest,
) -> MockExamRevisionResponse:
    exam = _get_exam_for_update(db, exam_id=exam_id)
    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_archived")

    revision = _get_revision_for_update(
        db,
        exam_id=exam_id,
        revision_id=revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_revision_archived")
    if revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="published_revision_immutable")
    if revision.validated_at is None or revision.validator_version is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_validated")

    revision.reviewer_identity = payload.reviewer_identity
    revision.reviewed_at = datetime.now(UTC)
    db.flush()

    append_audit_log(
        db,
        action="mock_exam_revision_reviewed",
        actor_user_id=None,
        target_user_id=None,
        details={
            "mock_exam_id": str(exam.id),
            "revision_id": str(revision.id),
            "reviewer_identity": revision.reviewer_identity,
        },
    )

    items = _load_revision_items(db, revision_id=revision.id)
    return _to_revision_response(revision=revision, items=items)


def publish_mock_exam_revision(
    db: Session,
    *,
    exam_id: UUID,
    payload: MockExamPublishRequest,
) -> MockExamPublishResponse:
    exam = _get_exam_for_update(db, exam_id=exam_id)
    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_archived")
    if exam.published_revision_id == payload.revision_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="published_revision_already_active",
        )

    revision = _get_revision_for_update(
        db,
        exam_id=exam_id,
        revision_id=payload.revision_id,
    )
    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_revision_archived")

    previous_published_revision_id = exam.published_revision_id
    published_at = _publish_revision(
        db,
        exam=exam,
        revision=revision,
    )

    append_audit_log(
        db,
        action="mock_exam_published",
        actor_user_id=None,
        target_user_id=None,
        details={
            "mock_exam_id": str(exam.id),
            "revision_id": str(revision.id),
            "previous_published_revision_id": (
                str(previous_published_revision_id) if previous_published_revision_id is not None else None
            ),
            "published_at": published_at.isoformat(),
        },
    )

    if revision.validator_version is None or revision.validated_at is None:
        raise RuntimeError("validated traceability fields are missing")
    if revision.reviewer_identity is None or revision.reviewed_at is None:
        raise RuntimeError("reviewed traceability fields are missing")

    return MockExamPublishResponse(
        mock_exam_id=exam.id,
        published_revision_id=revision.id,
        lifecycle_status=exam.lifecycle_status,
        generator_version=revision.generator_version,
        validator_version=revision.validator_version,
        validated_at=revision.validated_at,
        reviewer_identity=revision.reviewer_identity,
        reviewed_at=revision.reviewed_at,
        published_at=published_at,
    )


def rollback_mock_exam_revision(
    db: Session,
    *,
    exam_id: UUID,
    payload: MockExamRollbackRequest,
) -> MockExamRollbackResponse:
    exam = _get_exam_for_update(db, exam_id=exam_id)
    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_archived")
    if exam.published_revision_id is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="no_active_published_revision")
    if exam.published_revision_id == payload.target_revision_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="rollback_target_is_active_published",
        )

    target_revision = _get_revision_for_update(
        db,
        exam_id=exam_id,
        revision_id=payload.target_revision_id,
    )
    if target_revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="rollback_target_archived")
    if target_revision.published_at is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="rollback_target_not_previously_published")

    previous_published_revision_id = exam.published_revision_id
    published_at = _publish_revision(
        db,
        exam=exam,
        revision=target_revision,
    )

    append_audit_log(
        db,
        action="mock_exam_rolled_back",
        actor_user_id=None,
        target_user_id=None,
        details={
            "mock_exam_id": str(exam.id),
            "from_revision_id": str(previous_published_revision_id),
            "to_revision_id": str(target_revision.id),
            "rolled_back_at": published_at.isoformat(),
        },
    )

    return MockExamRollbackResponse(
        mock_exam_id=exam.id,
        previous_published_revision_id=previous_published_revision_id,
        rolled_back_to_revision_id=target_revision.id,
        lifecycle_status=exam.lifecycle_status,
        published_at=published_at,
    )


def _publish_revision(
    db: Session,
    *,
    exam: MockExam,
    revision: MockExamRevision,
) -> datetime:
    if revision.validated_at is None or revision.validator_version is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_validated")
    if revision.reviewed_at is None or revision.reviewer_identity is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_reviewed")

    items = _load_revision_items(db, revision_id=revision.id)
    _validate_revision_item_integrity(
        db,
        exam=exam,
        revision=revision,
        items=items,
    )

    now = datetime.now(UTC)
    db.execute(
        update(MockExamRevision)
        .where(
            MockExamRevision.mock_exam_id == exam.id,
            MockExamRevision.id != revision.id,
            MockExamRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
        )
        .values(lifecycle_status=ContentLifecycleStatus.DRAFT)
    )

    revision.lifecycle_status = ContentLifecycleStatus.PUBLISHED
    revision.published_at = now
    exam.published_revision_id = revision.id
    exam.lifecycle_status = ContentLifecycleStatus.PUBLISHED
    db.flush()
    return now


def _validate_revision_item_integrity(
    db: Session,
    *,
    exam: MockExam,
    revision: MockExamRevision,
    items: list[MockExamRevisionItem],
) -> None:
    if not items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="revision_items_must_not_be_empty")

    expected_order_indexes = list(range(1, len(items) + 1))
    actual_order_indexes = [item.order_index for item in sorted(items, key=lambda row: row.order_index)]
    if actual_order_indexes != expected_order_indexes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_order_sequence")

    listening_count = 0
    reading_count = 0
    for item in items:
        question, content_revision, content_unit = _resolve_content_reference(
            db,
            item_payload=MockExamRevisionItemCreateRequest(
                orderIndex=item.order_index,
                contentUnitRevisionId=item.content_unit_revision_id,
                contentQuestionId=item.content_question_id,
            ),
        )
        _ensure_reference_is_publishable(
            exam=exam,
            content_revision=content_revision,
            content_unit=content_unit,
        )

        if question.question_code != item.question_code_snapshot:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="mock_exam_snapshot_question_code_mismatch",
            )

        if item.skill_snapshot == Skill.LISTENING:
            listening_count += 1
        elif item.skill_snapshot == Skill.READING:
            reading_count += 1

    expected_listening, expected_reading = _expected_skill_counts(exam.exam_type)
    if listening_count != expected_listening or reading_count != expected_reading:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="mock_exam_skill_count_mismatch",
        )

    if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="mock_exam_revision_archived")


def _expected_skill_counts(exam_type: MockExamType) -> tuple[int, int]:
    if exam_type == MockExamType.WEEKLY:
        return MOCK_EXAM_WEEKLY_LISTENING_COUNT, MOCK_EXAM_WEEKLY_READING_COUNT
    return MOCK_EXAM_MONTHLY_LISTENING_COUNT, MOCK_EXAM_MONTHLY_READING_COUNT


def _resolve_content_reference(
    db: Session,
    *,
    item_payload: MockExamRevisionItemCreateRequest,
) -> tuple[ContentQuestion, ContentUnitRevision, ContentUnit]:
    row = db.execute(
        select(ContentQuestion, ContentUnitRevision, ContentUnit)
        .join(
            ContentUnitRevision,
            ContentQuestion.content_unit_revision_id == ContentUnitRevision.id,
        )
        .join(
            ContentUnit,
            ContentUnitRevision.content_unit_id == ContentUnit.id,
        )
        .where(
            ContentQuestion.id == item_payload.content_question_id,
            ContentQuestion.content_unit_revision_id == item_payload.content_unit_revision_id,
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="content_question_not_found")
    return row


def _ensure_reference_is_publishable(
    *,
    exam: MockExam,
    content_revision: ContentUnitRevision,
    content_unit: ContentUnit,
) -> None:
    if content_revision.lifecycle_status != ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_revision_not_published")
    if content_unit.lifecycle_status != ContentLifecycleStatus.PUBLISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_unit_not_published")
    if content_unit.published_revision_id != content_revision.id:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_revision_not_active_published")
    if content_unit.track != exam.track:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="content_track_mismatch")


def _get_exam_for_update(db: Session, *, exam_id: UUID) -> MockExam:
    exam = (
        db.query(MockExam)
        .filter(MockExam.id == exam_id)
        .with_for_update()
        .one_or_none()
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_not_found")
    return exam


def _get_revision_for_update(
    db: Session,
    *,
    exam_id: UUID,
    revision_id: UUID,
) -> MockExamRevision:
    revision = (
        db.query(MockExamRevision)
        .filter(
            MockExamRevision.id == revision_id,
            MockExamRevision.mock_exam_id == exam_id,
        )
        .with_for_update()
        .one_or_none()
    )
    if revision is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_revision_not_found")
    return revision


def _load_revision_items(db: Session, *, revision_id: UUID) -> list[MockExamRevisionItem]:
    return (
        db.query(MockExamRevisionItem)
        .filter(MockExamRevisionItem.mock_exam_revision_id == revision_id)
        .order_by(
            MockExamRevisionItem.order_index.asc(),
            MockExamRevisionItem.id.asc(),
        )
        .all()
    )


def _to_exam_response(exam: MockExam) -> MockExamResponse:
    return MockExamResponse(
        id=exam.id,
        exam_type=exam.exam_type,
        track=exam.track,
        period_key=exam.period_key,
        external_id=exam.external_id,
        slug=exam.slug,
        lifecycle_status=exam.lifecycle_status,
        published_revision_id=exam.published_revision_id,
        created_at=exam.created_at,
        updated_at=exam.updated_at,
    )


def _to_revision_item_response(item: MockExamRevisionItem) -> MockExamRevisionItemResponse:
    return MockExamRevisionItemResponse(
        id=item.id,
        order_index=item.order_index,
        content_unit_revision_id=item.content_unit_revision_id,
        content_question_id=item.content_question_id,
        question_code_snapshot=item.question_code_snapshot,
        skill_snapshot=item.skill_snapshot,
        created_at=item.created_at,
    )


def _to_revision_response(
    *,
    revision: MockExamRevision,
    items: list[MockExamRevisionItem],
) -> MockExamRevisionResponse:
    return MockExamRevisionResponse(
        id=revision.id,
        mock_exam_id=revision.mock_exam_id,
        revision_no=revision.revision_no,
        title=revision.title,
        instructions=revision.instructions,
        generator_version=revision.generator_version,
        validator_version=revision.validator_version,
        validated_at=revision.validated_at,
        reviewer_identity=revision.reviewer_identity,
        reviewed_at=revision.reviewed_at,
        metadata_json=revision.metadata_json,
        lifecycle_status=revision.lifecycle_status,
        published_at=revision.published_at,
        created_at=revision.created_at,
        updated_at=revision.updated_at,
        items=[_to_revision_item_response(item) for item in items],
    )
