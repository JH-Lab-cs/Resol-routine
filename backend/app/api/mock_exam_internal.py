from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.mock_exam import (
    MockExamCreateRequest,
    MockExamListQuery,
    MockExamListResponse,
    MockExamPublishRequest,
    MockExamPublishResponse,
    MockExamResponse,
    MockExamRevisionCreateRequest,
    MockExamRevisionListResponse,
    MockExamRevisionResponse,
    MockExamRevisionReviewRequest,
    MockExamRevisionValidateRequest,
    MockExamRollbackRequest,
    MockExamRollbackResponse,
)
from app.services.mock_exam_internal_service import (
    create_mock_exam,
    create_mock_exam_revision,
    get_mock_exam,
    list_mock_exam_revisions,
    list_mock_exams,
    publish_mock_exam_revision,
    review_mock_exam_revision,
    rollback_mock_exam_revision,
    validate_mock_exam_revision,
)

router = APIRouter(
    prefix="/internal/mock-exams",
    tags=["mock-exam-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


def _build_list_query(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    exam_type: str | None = None,
    track: str | None = None,
    period_key: str | None = None,
    lifecycle_status: str | None = None,
    published_only: bool = False,
) -> MockExamListQuery:
    try:
        return MockExamListQuery(
            page=page,
            page_size=page_size,
            exam_type=exam_type,
            track=track,
            period_key=period_key,
            lifecycle_status=lifecycle_status,
            published_only=published_only,
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=exc.errors(include_context=False, include_url=False),
        ) from exc


@router.post(
    "",
    response_model=MockExamResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_mock_exam_endpoint(
    payload: MockExamCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamResponse:
    return create_mock_exam(db, payload=payload)


@router.post(
    "/{exam_id}/revisions",
    response_model=MockExamRevisionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_mock_exam_revision_endpoint(
    exam_id: UUID,
    payload: MockExamRevisionCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamRevisionResponse:
    return create_mock_exam_revision(
        db,
        exam_id=exam_id,
        payload=payload,
    )


@router.post(
    "/{exam_id}/revisions/{revision_id}/validate",
    response_model=MockExamRevisionResponse,
)
def validate_mock_exam_revision_endpoint(
    exam_id: UUID,
    revision_id: UUID,
    payload: MockExamRevisionValidateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamRevisionResponse:
    return validate_mock_exam_revision(
        db,
        exam_id=exam_id,
        revision_id=revision_id,
        payload=payload,
    )


@router.post(
    "/{exam_id}/revisions/{revision_id}/review",
    response_model=MockExamRevisionResponse,
)
def review_mock_exam_revision_endpoint(
    exam_id: UUID,
    revision_id: UUID,
    payload: MockExamRevisionReviewRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamRevisionResponse:
    return review_mock_exam_revision(
        db,
        exam_id=exam_id,
        revision_id=revision_id,
        payload=payload,
    )


@router.post(
    "/{exam_id}/publish",
    response_model=MockExamPublishResponse,
)
def publish_mock_exam_endpoint(
    exam_id: UUID,
    payload: MockExamPublishRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamPublishResponse:
    return publish_mock_exam_revision(db, exam_id=exam_id, payload=payload)


@router.post(
    "/{exam_id}/rollback",
    response_model=MockExamRollbackResponse,
)
def rollback_mock_exam_endpoint(
    exam_id: UUID,
    payload: MockExamRollbackRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamRollbackResponse:
    return rollback_mock_exam_revision(db, exam_id=exam_id, payload=payload)


@router.get(
    "",
    response_model=MockExamListResponse,
)
def list_mock_exams_endpoint(
    query: Annotated[MockExamListQuery, Depends(_build_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> MockExamListResponse:
    return list_mock_exams(db, query=query)


@router.get(
    "/{exam_id}",
    response_model=MockExamResponse,
)
def get_mock_exam_endpoint(
    exam_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamResponse:
    return get_mock_exam(db, exam_id=exam_id)


@router.get(
    "/{exam_id}/revisions",
    response_model=MockExamRevisionListResponse,
)
def list_mock_exam_revisions_endpoint(
    exam_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> MockExamRevisionListResponse:
    return list_mock_exam_revisions(db, exam_id=exam_id)
