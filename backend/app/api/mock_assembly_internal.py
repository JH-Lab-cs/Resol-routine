from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.schemas.mock_assembly import MockAssemblyJobCreateRequest, MockAssemblyJobResponse
from app.services.mock_assembly_service import create_mock_assembly_job, get_mock_assembly_job

router = APIRouter(
    prefix="/internal/mock-assembly",
    tags=["mock-assembly-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


@router.post(
    "/jobs",
    response_model=MockAssemblyJobResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_mock_assembly_job_endpoint(
    payload: MockAssemblyJobCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> MockAssemblyJobResponse:
    return create_mock_assembly_job(db, payload=payload)


@router.get(
    "/jobs/{job_id}",
    response_model=MockAssemblyJobResponse,
)
def get_mock_assembly_job_endpoint(
    job_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> MockAssemblyJobResponse:
    return get_mock_assembly_job(db, job_id=job_id)
