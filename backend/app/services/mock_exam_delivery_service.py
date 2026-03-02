from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.timekeys import period_key
from app.models.content_question import ContentQuestion
from app.models.content_unit_revision import ContentUnitRevision
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import MockExamType, Track
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.mock_exam_revision_item import MockExamRevisionItem
from app.models.mock_exam_session import MockExamSession
from app.schemas.mock_exam import (
    MockExamSessionDetailResponse,
    MockExamSessionItemResponse,
    MockExamSessionStartResponse,
    StudentCurrentMockExamResponse,
)
from app.services.audit_service import append_audit_log
from app.services.content_asset_service import AssetDownloadUrlResult, issue_asset_download_url


def get_current_mock_exam_for_track(
    db: Session,
    *,
    exam_type: MockExamType,
    track: Track,
) -> StudentCurrentMockExamResponse:
    current_period_key = period_key(_now_utc(), exam_type.value)

    row = db.execute(
        select(MockExam, MockExamRevision)
        .join(MockExamRevision, MockExamRevision.id == MockExam.published_revision_id)
        .where(
            MockExam.exam_type == exam_type,
            MockExam.track == track,
            MockExam.period_key == current_period_key,
            MockExam.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            MockExamRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="current_mock_exam_not_found")

    exam, revision = row
    return StudentCurrentMockExamResponse(
        mock_exam_id=exam.id,
        mock_exam_revision_id=revision.id,
        exam_type=exam.exam_type,
        track=exam.track,
        period_key=exam.period_key,
        title=revision.title,
        instructions=revision.instructions,
    )


def start_mock_exam_session(
    db: Session,
    *,
    student_id: UUID,
    mock_exam_revision_id: UUID,
) -> MockExamSessionStartResponse:
    revision_row = db.execute(
        select(MockExamRevision, MockExam)
        .join(MockExam, MockExam.id == MockExamRevision.mock_exam_id)
        .where(MockExamRevision.id == mock_exam_revision_id)
        .with_for_update()
    ).first()
    if revision_row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_revision_not_found")

    revision, exam = revision_row
    if (
        revision.lifecycle_status != ContentLifecycleStatus.PUBLISHED
        or exam.lifecycle_status != ContentLifecycleStatus.PUBLISHED
        or exam.published_revision_id != revision.id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_revision_not_available")

    existing = db.execute(
        select(MockExamSession).where(
            MockExamSession.student_id == student_id,
            MockExamSession.mock_exam_revision_id == revision.id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return _to_session_start_response(session=existing, exam=exam)

    now = _now_utc()
    session = MockExamSession(
        student_id=student_id,
        mock_exam_revision_id=revision.id,
        started_at=now,
        last_accessed_at=now,
    )
    try:
        with db.begin_nested():
            db.add(session)
            db.flush()
    except IntegrityError:
        existing = db.execute(
            select(MockExamSession).where(
                MockExamSession.student_id == student_id,
                MockExamSession.mock_exam_revision_id == revision.id,
            )
        ).scalar_one_or_none()
        if existing is None:
            raise
        return _to_session_start_response(session=existing, exam=exam)

    append_audit_log(
        db,
        action="mock_exam_session_started",
        actor_user_id=student_id,
        target_user_id=student_id,
        details={
            "mock_session_id": session.id,
            "mock_exam_id": str(exam.id),
            "mock_exam_revision_id": str(revision.id),
        },
    )

    return _to_session_start_response(session=session, exam=exam)


def get_mock_exam_session_detail(
    db: Session,
    *,
    student_id: UUID,
    session_id: int,
) -> MockExamSessionDetailResponse:
    row = db.execute(
        select(MockExamSession, MockExamRevision, MockExam)
        .join(MockExamRevision, MockExamRevision.id == MockExamSession.mock_exam_revision_id)
        .join(MockExam, MockExam.id == MockExamRevision.mock_exam_id)
        .where(MockExamSession.id == session_id)
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_session_not_found")

    session, revision, exam = row
    if session.student_id != student_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="mock_exam_session_access_forbidden")

    session.last_accessed_at = _now_utc()
    db.flush()

    item_rows = db.execute(
        select(
            MockExamRevisionItem,
            ContentQuestion,
            ContentUnitRevision,
        )
        .join(ContentQuestion, ContentQuestion.id == MockExamRevisionItem.content_question_id)
        .join(
            ContentUnitRevision,
            ContentUnitRevision.id == MockExamRevisionItem.content_unit_revision_id,
        )
        .where(MockExamRevisionItem.mock_exam_revision_id == revision.id)
        .order_by(
            MockExamRevisionItem.order_index.asc(),
            MockExamRevisionItem.id.asc(),
        )
    ).all()

    asset_download_cache: dict[UUID, AssetDownloadUrlResult] = {}
    detail_items: list[MockExamSessionItemResponse] = []
    for item, content_question, content_revision in item_rows:
        asset_download = None
        if content_revision.asset_id is not None:
            cached = asset_download_cache.get(content_revision.asset_id)
            if cached is None:
                cached = issue_asset_download_url(db, asset_id=content_revision.asset_id)
                asset_download_cache[content_revision.asset_id] = cached
            asset_download = cached

        detail_items.append(
            MockExamSessionItemResponse(
                order_index=item.order_index,
                question_id=item.question_code_snapshot,
                skill=item.skill_snapshot,
                stem=content_question.stem,
                options=[
                    content_question.choice_a,
                    content_question.choice_b,
                    content_question.choice_c,
                    content_question.choice_d,
                    content_question.choice_e,
                ],
                body_text=content_revision.body_text,
                transcript_text=content_revision.transcript_text,
                asset_download_url=asset_download.download_url if asset_download is not None else None,
                asset_download_expires_at=asset_download.expires_at if asset_download is not None else None,
            )
        )

    return MockExamSessionDetailResponse(
        mock_session_id=session.id,
        mock_exam_revision_id=revision.id,
        exam_type=exam.exam_type,
        track=exam.track,
        period_key=exam.period_key,
        title=revision.title,
        instructions=revision.instructions,
        items=detail_items,
    )


def _to_session_start_response(*, session: MockExamSession, exam: MockExam) -> MockExamSessionStartResponse:
    return MockExamSessionStartResponse(
        mock_session_id=session.id,
        mock_exam_revision_id=session.mock_exam_revision_id,
        exam_type=exam.exam_type,
        track=exam.track,
        period_key=exam.period_key,
        started_at=session.started_at,
    )


def _now_utc() -> datetime:
    return datetime.now(UTC)
