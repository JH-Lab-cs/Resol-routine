from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.orm import Session

from app.api.dependencies import get_db
from app.schemas.billing import StripeWebhookResponse
from app.services.billing_service import process_stripe_webhook

router = APIRouter(prefix="/billing/webhooks", tags=["billing-webhooks"])


@router.post(
    "/stripe",
    response_model=StripeWebhookResponse,
)
async def process_stripe_webhook_endpoint(
    request: Request,
    db: Annotated[Session, Depends(get_db)],
    stripe_signature: Annotated[str | None, Header(alias="Stripe-Signature")] = None,
    x_request_id: Annotated[str | None, Header(alias="X-Request-Id")] = None,
) -> StripeWebhookResponse:
    payload_bytes = await request.body()
    return process_stripe_webhook(
        db,
        payload_bytes=payload_bytes,
        stripe_signature=stripe_signature,
        request_id=x_request_id,
    )
