from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE


class ContentQuestion(Base):
    __tablename__ = "content_questions"
    __table_args__ = (
        UniqueConstraint(
            "content_unit_revision_id",
            "question_code",
            name="uq_content_questions_revision_question_code",
        ),
        UniqueConstraint(
            "content_unit_revision_id",
            "order_index",
            name="uq_content_questions_revision_order_index",
        ),
        CheckConstraint(
            "correct_answer IN ('A', 'B', 'C', 'D', 'E')",
            name="content_question_correct_answer_allowed",
        ),
        CheckConstraint("order_index > 0", name="content_question_order_index_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content_unit_revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    question_code: Mapped[str] = mapped_column(String(128), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    stem: Mapped[str] = mapped_column(Text, nullable=False)
    choice_a: Mapped[str] = mapped_column(Text, nullable=False)
    choice_b: Mapped[str] = mapped_column(Text, nullable=False)
    choice_c: Mapped[str] = mapped_column(Text, nullable=False)
    choice_d: Mapped[str] = mapped_column(Text, nullable=False)
    choice_e: Mapped[str] = mapped_column(Text, nullable=False)
    correct_answer: Mapped[str] = mapped_column(String(1), nullable=False)
    explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
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
