"""Add mock exam assembly tables

Revision ID: 20260302_0005
Revises: 20260302_0004
Create Date: 2026-03-02 21:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260302_0005"
down_revision: str | None = "20260302_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

mock_exam_type_enum = sa.Enum("WEEKLY", "MONTHLY", name="mock_exam_type")
content_lifecycle_status_enum = postgresql.ENUM(
    "DRAFT",
    "PUBLISHED",
    "ARCHIVED",
    name="content_lifecycle_status",
    create_type=False,
)
track_enum = postgresql.ENUM(
    "M3",
    "H1",
    "H2",
    "H3",
    name="track",
    create_type=False,
)
skill_enum = postgresql.ENUM(
    "LISTENING",
    "READING",
    name="skill",
    create_type=False,
)


def upgrade() -> None:
    op.create_table(
        "mock_exams",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("exam_type", mock_exam_type_enum, nullable=False),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("period_key", sa.String(length=8), nullable=False),
        sa.Column("external_id", sa.String(length=128), nullable=True),
        sa.Column("slug", sa.String(length=128), nullable=True),
        sa.Column("lifecycle_status", content_lifecycle_status_enum, nullable=False),
        sa.Column("published_revision_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mock_exams")),
        sa.UniqueConstraint("exam_type", "track", "period_key", name="uq_mock_exams_type_track_period_key"),
        sa.UniqueConstraint("external_id", name=op.f("uq_mock_exams_external_id")),
        sa.UniqueConstraint("slug", name=op.f("uq_mock_exams_slug")),
    )
    op.create_index(
        op.f("ix_mock_exams_published_revision_id"),
        "mock_exams",
        ["published_revision_id"],
        unique=False,
    )
    op.create_index(
        "ix_mock_exams_type_track_period_key",
        "mock_exams",
        ["exam_type", "track", "period_key"],
        unique=False,
    )

    op.create_table(
        "mock_exam_revisions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("mock_exam_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("revision_no", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("instructions", sa.Text(), nullable=True),
        sa.Column("generator_version", sa.String(length=128), nullable=False),
        sa.Column("validator_version", sa.String(length=128), nullable=True),
        sa.Column("validated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewer_identity", sa.String(length=128), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("lifecycle_status", content_lifecycle_status_enum, nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["mock_exam_id"],
            ["mock_exams.id"],
            name=op.f("fk_mock_exam_revisions_mock_exam_id_mock_exams"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mock_exam_revisions")),
        sa.UniqueConstraint("mock_exam_id", "revision_no", name="uq_mock_exam_revisions_exam_revision_no"),
    )
    op.create_index(
        op.f("ix_mock_exam_revisions_mock_exam_id"),
        "mock_exam_revisions",
        ["mock_exam_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_exam_revisions_lifecycle_status"),
        "mock_exam_revisions",
        ["lifecycle_status"],
        unique=False,
    )
    op.create_index(
        "uq_mock_exam_revisions_active_published",
        "mock_exam_revisions",
        ["mock_exam_id"],
        unique=True,
        postgresql_where=sa.text("lifecycle_status = 'PUBLISHED'"),
        sqlite_where=sa.text("lifecycle_status = 'PUBLISHED'"),
    )

    op.create_foreign_key(
        op.f("fk_mock_exams_published_revision_id_mock_exam_revisions"),
        "mock_exams",
        "mock_exam_revisions",
        ["published_revision_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "mock_exam_revision_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("mock_exam_revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("content_unit_revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("content_question_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("question_code_snapshot", sa.String(length=128), nullable=False),
        sa.Column("skill_snapshot", skill_enum, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("order_index > 0", name=op.f("ck_mock_exam_revision_items_mock_exam_revision_item_order_index_positive")),
        sa.ForeignKeyConstraint(
            ["mock_exam_revision_id"],
            ["mock_exam_revisions.id"],
            name=op.f("fk_mock_exam_revision_items_mock_exam_revision_id_mock_exam_revisions"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["content_unit_revision_id"],
            ["content_unit_revisions.id"],
            name=op.f("fk_mock_exam_revision_items_content_unit_revision_id_content_unit_revisions"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["content_question_id"],
            ["content_questions.id"],
            name=op.f("fk_mock_exam_revision_items_content_question_id_content_questions"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mock_exam_revision_items")),
        sa.UniqueConstraint(
            "mock_exam_revision_id",
            "order_index",
            name="uq_mock_exam_revision_items_revision_order_index",
        ),
        sa.UniqueConstraint(
            "mock_exam_revision_id",
            "content_question_id",
            name="uq_mock_exam_revision_items_revision_content_question",
        ),
    )
    op.create_index(
        op.f("ix_mock_exam_revision_items_mock_exam_revision_id"),
        "mock_exam_revision_items",
        ["mock_exam_revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_exam_revision_items_content_unit_revision_id"),
        "mock_exam_revision_items",
        ["content_unit_revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_exam_revision_items_content_question_id"),
        "mock_exam_revision_items",
        ["content_question_id"],
        unique=False,
    )

    op.create_table(
        "mock_exam_sessions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("mock_exam_revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_accessed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["student_id"],
            ["users.id"],
            name=op.f("fk_mock_exam_sessions_student_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["mock_exam_revision_id"],
            ["mock_exam_revisions.id"],
            name=op.f("fk_mock_exam_sessions_mock_exam_revision_id_mock_exam_revisions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mock_exam_sessions")),
        sa.UniqueConstraint(
            "student_id",
            "mock_exam_revision_id",
            name="uq_mock_exam_sessions_student_revision",
        ),
    )
    op.create_index(
        op.f("ix_mock_exam_sessions_student_id"),
        "mock_exam_sessions",
        ["student_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_exam_sessions_mock_exam_revision_id"),
        "mock_exam_sessions",
        ["mock_exam_revision_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_mock_exam_sessions_mock_exam_revision_id"), table_name="mock_exam_sessions")
    op.drop_index(op.f("ix_mock_exam_sessions_student_id"), table_name="mock_exam_sessions")
    op.drop_table("mock_exam_sessions")

    op.drop_index(op.f("ix_mock_exam_revision_items_content_question_id"), table_name="mock_exam_revision_items")
    op.drop_index(op.f("ix_mock_exam_revision_items_content_unit_revision_id"), table_name="mock_exam_revision_items")
    op.drop_index(op.f("ix_mock_exam_revision_items_mock_exam_revision_id"), table_name="mock_exam_revision_items")
    op.drop_table("mock_exam_revision_items")

    op.drop_constraint(
        op.f("fk_mock_exams_published_revision_id_mock_exam_revisions"),
        "mock_exams",
        type_="foreignkey",
    )

    op.drop_index("uq_mock_exam_revisions_active_published", table_name="mock_exam_revisions")
    op.drop_index(op.f("ix_mock_exam_revisions_lifecycle_status"), table_name="mock_exam_revisions")
    op.drop_index(op.f("ix_mock_exam_revisions_mock_exam_id"), table_name="mock_exam_revisions")
    op.drop_table("mock_exam_revisions")

    op.drop_index("ix_mock_exams_type_track_period_key", table_name="mock_exams")
    op.drop_index(op.f("ix_mock_exams_published_revision_id"), table_name="mock_exams")
    op.drop_table("mock_exams")

    mock_exam_type_enum.drop(op.get_bind(), checkfirst=True)
