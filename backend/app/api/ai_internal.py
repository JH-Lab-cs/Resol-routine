from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.ai_jobs import (
    AIArtifactDownloadUrlResponse,
    AIArtifactPurgeRequest,
    AIArtifactPurgeResponse,
    AIJobListQuery,
    AIJobListResponse,
    AIJobResponse,
    AIMockExamJobCreateRequest,
)
from app.services.ai_job_service import (
    create_mock_exam_draft_generation_job,
    get_ai_job,
    issue_ai_job_artifact_download_url,
    list_ai_jobs,
    purge_ai_job_artifacts,
    retry_ai_job,
)

router = APIRouter(
    prefix="/internal/ai/jobs",
    tags=["ai-jobs-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


def _build_list_query(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    job_type: str | None = Query(default=None, alias="jobType"),
    status_filter: str | None = Query(default=None, alias="status"),
    mock_exam_id: UUID | None = Query(default=None, alias="mockExamId"),
) -> AIJobListQuery:
    try:
        return AIJobListQuery(
            page=page,
            page_size=page_size,
            job_type=job_type,
            status=status_filter,
            mock_exam_id=mock_exam_id,
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=exc.errors(include_context=False, include_url=False),
        ) from exc


@router.post(
    "/mock-exams",
    response_model=AIJobResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_mock_exam_generation_job_endpoint(
    payload: AIMockExamJobCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AIJobResponse:
    return create_mock_exam_draft_generation_job(db, payload=payload)


@router.get(
    "",
    response_model=AIJobListResponse,
)
def list_ai_jobs_endpoint(
    query: Annotated[AIJobListQuery, Depends(_build_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> AIJobListResponse:
    return list_ai_jobs(db, query=query)


@router.get(
    "/{job_id}",
    response_model=AIJobResponse,
)
def get_ai_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIJobResponse:
    return get_ai_job(db, job_id=job_id)


@router.post(
    "/{job_id}/retry",
    response_model=AIJobResponse,
)
def retry_ai_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIJobResponse:
    return retry_ai_job(db, job_id=job_id)


@router.get(
    "/{job_id}/artifacts/{artifact_kind}/download-url",
    response_model=AIArtifactDownloadUrlResponse,
)
def get_ai_job_artifact_download_url_endpoint(
    job_id: UUID,
    artifact_kind: str,
    db: Annotated[Session, Depends(get_db)],
) -> AIArtifactDownloadUrlResponse:
    return issue_ai_job_artifact_download_url(
        db,
        job_id=job_id,
        artifact_kind=artifact_kind,
    )


@router.post(
    "/artifacts/purge",
    response_model=AIArtifactPurgeResponse,
)
def purge_ai_job_artifacts_endpoint(
    payload: AIArtifactPurgeRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AIArtifactPurgeResponse:
    return purge_ai_job_artifacts(db, payload=payload)
