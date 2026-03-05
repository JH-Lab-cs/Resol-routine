from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudentAttemptProjection(Base):
    __tablename__ = "student_attempt_projections"
    __table_args__ = (
        CheckConstraint(
            "("
            "(event_type = 'TODAY_ATTEMPT_SAVED' AND session_id IS NOT NULL AND mock_session_id IS NULL) "
            "OR "
            "(event_type = 'MOCK_EXAM_ATTEMPT_SAVED' AND mock_session_id IS NOT NULL AND session_id IS NULL)"
            ")",
            name="student_attempt_projection_session_selector",
        ),
        CheckConstraint(
            "wrong_reason_tag IS NULL OR wrong_reason_tag IN ('VOCAB', 'EVIDENCE', 'INFERENCE', 'CARELESS', 'TIME')",
            name="student_attempt_projection_wrong_reason_tag_allowed",
        ),
        Index(
            "uq_student_attempt_projections_today_logical",
            "student_id",
            "session_id",
            "question_id",
            unique=True,
            postgresql_where=text("event_type = 'TODAY_ATTEMPT_SAVED'"),
            sqlite_where=text("event_type = 'TODAY_ATTEMPT_SAVED'"),
        ),
        Index(
            "uq_student_attempt_projections_mock_logical",
            "student_id",
            "mock_session_id",
            "question_id",
            unique=True,
            postgresql_where=text("event_type = 'MOCK_EXAM_ATTEMPT_SAVED'"),
            sqlite_where=text("event_type = 'MOCK_EXAM_ATTEMPT_SAVED'"),
        ),
        Index("ix_student_attempt_projections_student_day_key", "student_id", "day_key"),
        Index("ix_student_attempt_projections_student_week_key", "student_id", "week_key"),
        Index("ix_student_attempt_projections_student_period_key", "student_id", "period_key"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    session_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    mock_session_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    question_id: Mapped[str] = mapped_column(String(128), nullable=False)
    selected_answer: Mapped[str] = mapped_column(String(16), nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=False)
    wrong_reason_tag: Mapped[str | None] = mapped_column(String(32), nullable=True)
    latest_event_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("study_events.id", ondelete="CASCADE"),
        nullable=False,
    )
    occurred_at_client: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    day_key: Mapped[str] = mapped_column(String(8), nullable=False)
    week_key: Mapped[str] = mapped_column(String(7), nullable=False)
    period_key: Mapped[str] = mapped_column(String(6), nullable=False)
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
