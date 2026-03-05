from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.content_enums import ContentLifecycleStatus


class MockExamRevision(Base):
    __tablename__ = "mock_exam_revisions"
    __table_args__ = (
        UniqueConstraint(
            "mock_exam_id",
            "revision_no",
            name="uq_mock_exam_revisions_exam_revision_no",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    mock_exam_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("mock_exams.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    revision_no: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    generator_version: Mapped[str] = mapped_column(String(128), nullable=False)
    validator_version: Mapped[str | None] = mapped_column(String(128), nullable=True)
    validated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewer_identity: Mapped[str | None] = mapped_column(String(128), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON_TYPE, nullable=False, default=dict)
    lifecycle_status: Mapped[ContentLifecycleStatus] = mapped_column(
        Enum(ContentLifecycleStatus, name="content_lifecycle_status"),
        nullable=False,
        default=ContentLifecycleStatus.DRAFT,
        index=True,
    )
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
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
