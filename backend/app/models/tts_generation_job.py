from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Track
from app.models.tts_enums import TTSGenerationJobStatus


class TTSGenerationJob(Base):
    __tablename__ = "tts_generation_jobs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(String(64), nullable=False)
    model_name: Mapped[str] = mapped_column(String(128), nullable=False)
    voice: Mapped[str] = mapped_column(String(64), nullable=False)
    speed: Mapped[float] = mapped_column(Float, nullable=False)
    force_regen: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    input_text_sha256: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    input_text_len: Mapped[int] = mapped_column(Integer, nullable=False)

    status: Mapped[TTSGenerationJobStatus] = mapped_column(
        Enum(TTSGenerationJobStatus, name="tts_generation_job_status"),
        nullable=False,
        default=TTSGenerationJobStatus.PENDING,
        index=True,
    )
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    artifact_request_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_response_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_candidate_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_validation_key: Mapped[str | None] = mapped_column(String(512), nullable=True)

    output_asset_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_assets.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    output_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    output_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    output_sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
