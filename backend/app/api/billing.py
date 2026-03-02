from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_parent_user, get_db
from app.models.user import User
from app.schemas.billing import AppStoreReceiptVerifyRequest, AppStoreReceiptVerifyResponse
from app.services.billing_service import verify_app_store_receipt_for_parent

router = APIRouter(prefix="/billing", tags=["billing"])


@router.post(
    "/app-store/verify",
    response_model=AppStoreReceiptVerifyResponse,
)
def verify_app_store_receipt_endpoint(
    payload: AppStoreReceiptVerifyRequest,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
) -> AppStoreReceiptVerifyResponse:
    return verify_app_store_receipt_for_parent(
        db,
        parent_id=current_parent.id,
        payload=payload,
    )
