from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import Skill, Track


class ContentUnit(Base):
    __tablename__ = "content_units"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    external_id: Mapped[str] = mapped_column(String(128), nullable=False, unique=True, index=True)
    slug: Mapped[str | None] = mapped_column(String(128), nullable=True, unique=True)
    skill: Mapped[Skill] = mapped_column(Enum(Skill, name="skill"), nullable=False)
    track: Mapped[Track] = mapped_column(Enum(Track, name="track"), nullable=False)
    lifecycle_status: Mapped[ContentLifecycleStatus] = mapped_column(
        Enum(ContentLifecycleStatus, name="content_lifecycle_status"),
        nullable=False,
        default=ContentLifecycleStatus.DRAFT,
    )
    published_revision_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
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
