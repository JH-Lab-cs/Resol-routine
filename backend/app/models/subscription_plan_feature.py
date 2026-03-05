from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import SubscriptionFeatureCode


class SubscriptionPlanFeature(Base):
    __tablename__ = "subscription_plan_features"
    __table_args__ = (
        UniqueConstraint(
            "subscription_plan_id",
            "feature_code",
            name="uq_subscription_plan_features_plan_feature",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    subscription_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("subscription_plans.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    feature_code: Mapped[SubscriptionFeatureCode] = mapped_column(
        Enum(SubscriptionFeatureCode, name="subscription_feature_code"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
