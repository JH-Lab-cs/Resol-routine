from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import MockExamType, Track


class MockExam(Base):
    __tablename__ = "mock_exams"
    __table_args__ = (
        UniqueConstraint(
            "exam_type",
            "track",
            "period_key",
            name="uq_mock_exams_type_track_period_key",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    exam_type: Mapped[MockExamType] = mapped_column(
        Enum(MockExamType, name="mock_exam_type"),
        nullable=False,
    )
    track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
    )
    period_key: Mapped[str] = mapped_column(String(8), nullable=False)
    external_id: Mapped[str | None] = mapped_column(String(128), nullable=True, unique=True)
    slug: Mapped[str | None] = mapped_column(String(128), nullable=True, unique=True)
    lifecycle_status: Mapped[ContentLifecycleStatus] = mapped_column(
        Enum(ContentLifecycleStatus, name="content_lifecycle_status"),
        nullable=False,
        default=ContentLifecycleStatus.DRAFT,
    )
    published_revision_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("mock_exam_revisions.id", ondelete="SET NULL"),
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
