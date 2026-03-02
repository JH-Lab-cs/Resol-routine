from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_student_user, get_db
from app.models.enums import MockExamType, Track
from app.models.user import User
from app.schemas.mock_exam import (
    MockExamSessionDetailResponse,
    MockExamSessionStartResponse,
    StudentCurrentMockExamResponse,
)
from app.services.mock_exam_delivery_service import (
    get_current_mock_exam_for_track,
    get_mock_exam_session_detail,
    start_mock_exam_session,
)

router = APIRouter(tags=["mock-exams"])


@router.get("/mock-exams/weekly/current", response_model=StudentCurrentMockExamResponse)
def get_current_weekly_mock_exam(
    track: Track,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> StudentCurrentMockExamResponse:
    _ = current_student
    return get_current_mock_exam_for_track(
        db,
        exam_type=MockExamType.WEEKLY,
        track=track,
    )


@router.get("/mock-exams/monthly/current", response_model=StudentCurrentMockExamResponse)
def get_current_monthly_mock_exam(
    track: Track,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> StudentCurrentMockExamResponse:
    _ = current_student
    return get_current_mock_exam_for_track(
        db,
        exam_type=MockExamType.MONTHLY,
        track=track,
    )


@router.post(
    "/mock-exams/{mock_exam_revision_id}/sessions",
    response_model=MockExamSessionStartResponse,
)
def start_session_for_mock_exam_revision(
    mock_exam_revision_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> MockExamSessionStartResponse:
    return start_mock_exam_session(
        db,
        student_id=current_student.id,
        mock_exam_revision_id=mock_exam_revision_id,
    )


@router.get("/mock-exam-sessions/{session_id}", response_model=MockExamSessionDetailResponse)
def get_mock_exam_session(
    session_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> MockExamSessionDetailResponse:
    return get_mock_exam_session_detail(
        db,
        student_id=current_student.id,
        session_id=session_id,
    )
