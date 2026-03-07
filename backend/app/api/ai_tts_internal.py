from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.ai_tts import (
    TTSGenerationEnsureAudioRequest,
    TTSGenerationEnsureAudioResponse,
    TTSGenerationJobCreateRequest,
    TTSGenerationJobResponse,
)
from app.services.tts_generation_service import (
    create_tts_generation_job,
    ensure_tts_audio_for_revision,
    get_tts_generation_job,
    retry_tts_generation_job,
)

router = APIRouter(
    prefix="/internal/ai/tts",
    tags=["ai-tts-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


@router.post(
    "/jobs",
    response_model=TTSGenerationJobResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_tts_generation_job_endpoint(
    payload: TTSGenerationJobCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> TTSGenerationJobResponse:
    return create_tts_generation_job(db, payload=payload)


@router.get(
    "/jobs/{job_id}",
    response_model=TTSGenerationJobResponse,
)
def get_tts_generation_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> TTSGenerationJobResponse:
    return get_tts_generation_job(db, job_id=job_id)


@router.post(
    "/jobs/{job_id}/retry",
    response_model=TTSGenerationJobResponse,
)
def retry_tts_generation_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> TTSGenerationJobResponse:
    return retry_tts_generation_job(db, job_id=job_id)


@router.post(
    "/revisions/{revision_id}/ensure-audio",
    response_model=TTSGenerationEnsureAudioResponse,
)
def ensure_tts_audio_for_revision_endpoint(
    revision_id: UUID,
    payload: TTSGenerationEnsureAudioRequest,
    db: Annotated[Session, Depends(get_db)],
) -> TTSGenerationEnsureAudioResponse:
    return ensure_tts_audio_for_revision(db, revision_id=revision_id, payload=payload)
