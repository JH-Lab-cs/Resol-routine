from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import AIGenerationJobStatus, MockExamType, Track


class MockAssemblyJob(Base):
    __tablename__ = "mock_assembly_jobs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    status: Mapped[AIGenerationJobStatus] = mapped_column(
        Enum(AIGenerationJobStatus, name="ai_generation_job_status"),
        nullable=False,
        default=AIGenerationJobStatus.RUNNING,
        index=True,
    )
    exam_type: Mapped[MockExamType] = mapped_column(
        Enum(MockExamType, name="mock_exam_type"),
        nullable=False,
        index=True,
    )
    track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
        index=True,
    )
    period_key: Mapped[str] = mapped_column(String(8), nullable=False, index=True)
    seed: Mapped[str] = mapped_column(String(128), nullable=False)
    dry_run: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    force_rebuild: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    target_difficulty_profile_json: Mapped[dict[str, Any]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=dict,
    )
    candidate_pool_counts_json: Mapped[dict[str, Any]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=dict,
    )
    summary_json: Mapped[dict[str, Any]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=dict,
    )
    constraint_summary_json: Mapped[dict[str, Any]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=dict,
    )
    warnings_json: Mapped[list[str]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=list,
    )
    assembly_trace_json: Mapped[dict[str, Any]] = mapped_column(
        JSON_TYPE,
        nullable=False,
        default=dict,
    )

    failure_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    failure_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    produced_mock_exam_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("mock_exams.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    produced_mock_exam_revision_id: Mapped[uuid.UUID | None] = mapped_column(
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
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
