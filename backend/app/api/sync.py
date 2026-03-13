from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_student_user, get_db
from app.models.user import User
from app.schemas.sync import SyncEventsBatchResponse
from app.services.sync_service import ingest_events_batch

router = APIRouter(tags=["sync"])


@router.post("/sync/events", response_model=SyncEventsBatchResponse)
@router.post("/sync/events/batch", response_model=SyncEventsBatchResponse)
def ingest_sync_event_batch(
    payload: Annotated[dict[str, Any], Body(...)],
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> SyncEventsBatchResponse:
    return ingest_events_batch(
        db,
        student_id=current_student.id,
        raw_body=payload,
    )
