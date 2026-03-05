from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import BillingProvider, BillingReceiptVerificationStatus


class BillingReceiptVerification(Base):
    __tablename__ = "billing_receipt_verifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider: Mapped[BillingProvider] = mapped_column(
        Enum(BillingProvider, name="billing_provider"),
        nullable=False,
        index=True,
    )
    owner_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user_subscriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    status: Mapped[BillingReceiptVerificationStatus] = mapped_column(
        Enum(BillingReceiptVerificationStatus, name="billing_receipt_verification_status"),
        nullable=False,
        index=True,
    )
    plan_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    transaction_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    original_transaction_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    verification_request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    provider_response_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    details: Mapped[dict[str, Any]] = mapped_column(JSON_TYPE, nullable=False, default=dict)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
