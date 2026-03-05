from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import AIGenerationJobStatus


class AIContentGenerationJob(Base):
    __tablename__ = "ai_content_generation_jobs"
    __table_args__ = (
        UniqueConstraint("request_id", name="uq_ai_content_generation_jobs_request_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    request_id: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[AIGenerationJobStatus] = mapped_column(
        Enum(AIGenerationJobStatus, name="ai_generation_job_status"),
        nullable=False,
        default=AIGenerationJobStatus.QUEUED,
        index=True,
    )
    content_unit_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_units.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    dry_run: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    candidate_count_per_target: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    target_matrix_json: Mapped[list[dict[str, Any]]] = mapped_column(JSON_TYPE, nullable=False, default=list)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON_TYPE, nullable=False, default=dict)

    provider_override: Mapped[str | None] = mapped_column(String(64), nullable=True)
    provider_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    model_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    prompt_template_version: Mapped[str | None] = mapped_column(String(64), nullable=True)

    input_artifact_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    output_artifact_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    candidate_snapshot_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)

    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    last_error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_error_transient: Mapped[bool | None] = mapped_column(nullable=True)
    next_retry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    dead_lettered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    queued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
