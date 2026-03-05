from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import (
    AIContentGenerationCandidateStatus,
    ContentSourcePolicy,
    ContentTypeTag,
    Skill,
    Track,
)


class AIContentGenerationCandidate(Base):
    __tablename__ = "ai_content_generation_candidates"
    __table_args__ = (
        UniqueConstraint(
            "job_id",
            "candidate_index",
            name="uq_ai_content_generation_candidates_job_index",
        ),
        CheckConstraint(
            "difficulty >= 1 AND difficulty <= 5",
            name="diff_range",
        ),
        CheckConstraint(
            "answer_key IN ('A', 'B', 'C', 'D', 'E')",
            name="answer_key_allowed",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ai_content_generation_jobs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    candidate_index: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[AIContentGenerationCandidateStatus] = mapped_column(
        Enum(AIContentGenerationCandidateStatus, name="ai_content_generation_candidate_status"),
        nullable=False,
        default=AIContentGenerationCandidateStatus.VALID,
        index=True,
    )
    failure_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    failure_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    track: Mapped[Track] = mapped_column(Enum(Track, name="track"), nullable=False)
    skill: Mapped[Skill] = mapped_column(Enum(Skill, name="skill"), nullable=False)
    type_tag: Mapped[ContentTypeTag] = mapped_column(
        Enum(ContentTypeTag, name="content_type_tag"),
        nullable=False,
        index=True,
    )
    difficulty: Mapped[int] = mapped_column(Integer, nullable=False)
    source_policy: Mapped[ContentSourcePolicy] = mapped_column(
        Enum(ContentSourcePolicy, name="content_source_policy"),
        nullable=False,
        default=ContentSourcePolicy.AI_ORIGINAL,
    )

    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    passage_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    sentences_json: Mapped[list[dict[str, Any]]] = mapped_column(JSON_TYPE, nullable=False, default=list)
    turns_json: Mapped[list[dict[str, Any]]] = mapped_column(JSON_TYPE, nullable=False, default=list)
    tts_plan_json: Mapped[dict[str, Any]] = mapped_column(JSON_TYPE, nullable=False, default=dict)

    question_stem: Mapped[str] = mapped_column(Text, nullable=False)
    choice_a: Mapped[str] = mapped_column(Text, nullable=False)
    choice_b: Mapped[str] = mapped_column(Text, nullable=False)
    choice_c: Mapped[str] = mapped_column(Text, nullable=False)
    choice_d: Mapped[str] = mapped_column(Text, nullable=False)
    choice_e: Mapped[str] = mapped_column(Text, nullable=False)
    answer_key: Mapped[str] = mapped_column(String(1), nullable=False)
    explanation_text: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_sentence_ids_json: Mapped[list[str]] = mapped_column(JSON_TYPE, nullable=False, default=list)
    why_correct_ko: Mapped[str] = mapped_column(Text, nullable=False)
    why_wrong_ko_by_option_json: Mapped[dict[str, str]] = mapped_column(JSON_TYPE, nullable=False, default=dict)
    vocab_notes_ko: Mapped[str | None] = mapped_column(Text, nullable=True)
    structure_notes_ko: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_flags_json: Mapped[list[str]] = mapped_column(JSON_TYPE, nullable=False, default=list)

    artifact_prompt_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_response_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_candidate_json_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    artifact_validation_report_key: Mapped[str | None] = mapped_column(String(512), nullable=True)

    materialized_content_unit_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_units.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    materialized_revision_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    materialized_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
