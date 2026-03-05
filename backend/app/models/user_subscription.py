from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import UserSubscriptionStatus


class UserSubscription(Base):
    __tablename__ = "user_subscriptions"
    __table_args__ = (
        CheckConstraint("starts_at < ends_at", name="user_subscription_starts_before_ends"),
        CheckConstraint(
            "grace_ends_at IS NULL OR grace_ends_at >= ends_at",
            name="user_subscription_grace_after_ends",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subscription_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("subscription_plans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    status: Mapped[UserSubscriptionStatus] = mapped_column(
        Enum(UserSubscriptionStatus, name="user_subscription_status"),
        nullable=False,
        index=True,
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    grace_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    canceled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    external_billing_ref: Mapped[str | None] = mapped_column(String(256), nullable=True)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON_TYPE, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
