from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.ai_content_generation import (
    AIContentGenerationCandidateListResponse,
    AIContentGenerationJobCreateRequest,
    AIContentGenerationJobResponse,
    AIContentMaterializeDraftResponse,
)
from app.services.ai_content_generation_service import (
    create_ai_content_generation_job,
    get_ai_content_generation_job,
    list_ai_content_generation_candidates,
    materialize_ai_content_candidate_draft,
    retry_ai_content_generation_job,
)

router = APIRouter(
    prefix="/internal/ai/content-generation",
    tags=["ai-content-generation-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


@router.post(
    "/jobs",
    response_model=AIContentGenerationJobResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_ai_content_generation_job_endpoint(
    payload: AIContentGenerationJobCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AIContentGenerationJobResponse:
    return create_ai_content_generation_job(db, payload=payload)


@router.get(
    "/jobs/{job_id}",
    response_model=AIContentGenerationJobResponse,
)
def get_ai_content_generation_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIContentGenerationJobResponse:
    return get_ai_content_generation_job(db, job_id=job_id)


@router.get(
    "/jobs/{job_id}/candidates",
    response_model=AIContentGenerationCandidateListResponse,
)
def list_ai_content_generation_candidates_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIContentGenerationCandidateListResponse:
    return list_ai_content_generation_candidates(db, job_id=job_id)


@router.post(
    "/candidates/{candidate_id}/materialize-draft",
    response_model=AIContentMaterializeDraftResponse,
)
def materialize_ai_content_candidate_draft_endpoint(
    candidate_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIContentMaterializeDraftResponse:
    return materialize_ai_content_candidate_draft(db, candidate_id=candidate_id)


@router.post(
    "/jobs/{job_id}/retry",
    response_model=AIContentGenerationJobResponse,
)
def retry_ai_content_generation_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AIContentGenerationJobResponse:
    return retry_ai_content_generation_job(db, job_id=job_id)
