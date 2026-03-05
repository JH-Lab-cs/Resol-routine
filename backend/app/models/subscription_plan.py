from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Enum, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import SubscriptionPlanStatus


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    plan_code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[SubscriptionPlanStatus] = mapped_column(
        Enum(SubscriptionPlanStatus, name="subscription_plan_status"),
        nullable=False,
        default=SubscriptionPlanStatus.ACTIVE,
        index=True,
    )
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
