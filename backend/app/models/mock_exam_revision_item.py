from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Skill


class MockExamRevisionItem(Base):
    __tablename__ = "mock_exam_revision_items"
    __table_args__ = (
        UniqueConstraint(
            "mock_exam_revision_id",
            "order_index",
            name="uq_mock_exam_revision_items_revision_order_index",
        ),
        UniqueConstraint(
            "mock_exam_revision_id",
            "content_question_id",
            name="uq_mock_exam_revision_items_revision_content_question",
        ),
        CheckConstraint(
            "order_index > 0",
            name="mock_exam_revision_item_order_index_positive",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    mock_exam_revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("mock_exam_revisions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content_unit_revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    content_question_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_questions.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    question_code_snapshot: Mapped[str] = mapped_column(String(128), nullable=False)
    skill_snapshot: Mapped[Skill] = mapped_column(Enum(Skill, name="skill"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
