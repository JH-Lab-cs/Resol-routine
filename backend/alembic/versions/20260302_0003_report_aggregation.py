"""Add report projection and aggregate tables

Revision ID: 20260302_0003
Revises: 20260301_0002
Create Date: 2026-03-02 14:05:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260302_0003"
down_revision: str | None = "20260301_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "student_attempt_projections",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("session_id", sa.Integer(), nullable=True),
        sa.Column("mock_session_id", sa.Integer(), nullable=True),
        sa.Column("question_id", sa.String(length=128), nullable=False),
        sa.Column("selected_answer", sa.String(length=16), nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.Column("wrong_reason_tag", sa.String(length=32), nullable=True),
        sa.Column("latest_event_id", sa.Integer(), nullable=False),
        sa.Column("occurred_at_client", sa.DateTime(timezone=True), nullable=False),
        sa.Column("day_key", sa.String(length=8), nullable=False),
        sa.Column("week_key", sa.String(length=7), nullable=False),
        sa.Column("period_key", sa.String(length=6), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint(
            "("
            "(event_type = 'TODAY_ATTEMPT_SAVED' AND session_id IS NOT NULL AND mock_session_id IS NULL) "
            "OR "
            "(event_type = 'MOCK_EXAM_ATTEMPT_SAVED' AND mock_session_id IS NOT NULL AND session_id IS NULL)"
            ")",
            name=op.f("ck_student_attempt_projections_student_attempt_projection_session_selector"),
        ),
        sa.CheckConstraint(
            "wrong_reason_tag IS NULL OR wrong_reason_tag IN ('VOCAB', 'EVIDENCE', 'INFERENCE', 'CARELESS', 'TIME')",
            name=op.f("ck_student_attempt_projections_student_attempt_projection_wrong_reason_tag_allowed"),
        ),
        sa.ForeignKeyConstraint(
            ["latest_event_id"],
            ["study_events.id"],
            name=op.f("fk_student_attempt_projections_latest_event_id_study_events"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["student_id"],
            ["users.id"],
            name=op.f("fk_student_attempt_projections_student_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_student_attempt_projections")),
    )
    op.create_index(
        op.f("ix_student_attempt_projections_student_id"),
        "student_attempt_projections",
        ["student_id"],
        unique=False,
    )
    op.create_index(
        "uq_student_attempt_projections_today_logical",
        "student_attempt_projections",
        ["student_id", "session_id", "question_id"],
        unique=True,
        postgresql_where=sa.text("event_type = 'TODAY_ATTEMPT_SAVED'"),
        sqlite_where=sa.text("event_type = 'TODAY_ATTEMPT_SAVED'"),
    )
    op.create_index(
        "uq_student_attempt_projections_mock_logical",
        "student_attempt_projections",
        ["student_id", "mock_session_id", "question_id"],
        unique=True,
        postgresql_where=sa.text("event_type = 'MOCK_EXAM_ATTEMPT_SAVED'"),
        sqlite_where=sa.text("event_type = 'MOCK_EXAM_ATTEMPT_SAVED'"),
    )
    op.create_index(
        "ix_student_attempt_projections_student_day_key",
        "student_attempt_projections",
        ["student_id", "day_key"],
        unique=False,
    )
    op.create_index(
        "ix_student_attempt_projections_student_week_key",
        "student_attempt_projections",
        ["student_id", "week_key"],
        unique=False,
    )
    op.create_index(
        "ix_student_attempt_projections_student_period_key",
        "student_attempt_projections",
        ["student_id", "period_key"],
        unique=False,
    )

    op.create_table(
        "daily_report_aggregates",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("day_key", sa.String(length=8), nullable=False),
        sa.Column("answered_count", sa.Integer(), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("wrong_count", sa.Integer(), nullable=False),
        sa.Column("wrong_reason_counts", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("top_wrong_reason_tag", sa.String(length=32), nullable=True),
        sa.Column("first_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("aggregated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["student_id"],
            ["users.id"],
            name=op.f("fk_daily_report_aggregates_student_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_daily_report_aggregates")),
        sa.UniqueConstraint(
            "student_id",
            "day_key",
            name="uq_daily_report_aggregates_student_day_key",
        ),
    )
    op.create_index(
        op.f("ix_daily_report_aggregates_student_id"),
        "daily_report_aggregates",
        ["student_id"],
        unique=False,
    )

    op.create_table(
        "weekly_report_aggregates",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("week_key", sa.String(length=7), nullable=False),
        sa.Column("answered_count", sa.Integer(), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("wrong_count", sa.Integer(), nullable=False),
        sa.Column("wrong_reason_counts", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("top_wrong_reason_tag", sa.String(length=32), nullable=True),
        sa.Column("first_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("aggregated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["student_id"],
            ["users.id"],
            name=op.f("fk_weekly_report_aggregates_student_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_weekly_report_aggregates")),
        sa.UniqueConstraint(
            "student_id",
            "week_key",
            name="uq_weekly_report_aggregates_student_week_key",
        ),
    )
    op.create_index(
        op.f("ix_weekly_report_aggregates_student_id"),
        "weekly_report_aggregates",
        ["student_id"],
        unique=False,
    )

    op.create_table(
        "monthly_report_aggregates",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("period_key", sa.String(length=6), nullable=False),
        sa.Column("answered_count", sa.Integer(), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("wrong_count", sa.Integer(), nullable=False),
        sa.Column("wrong_reason_counts", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("top_wrong_reason_tag", sa.String(length=32), nullable=True),
        sa.Column("first_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("aggregated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["student_id"],
            ["users.id"],
            name=op.f("fk_monthly_report_aggregates_student_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_monthly_report_aggregates")),
        sa.UniqueConstraint(
            "student_id",
            "period_key",
            name="uq_monthly_report_aggregates_student_period_key",
        ),
    )
    op.create_index(
        op.f("ix_monthly_report_aggregates_student_id"),
        "monthly_report_aggregates",
        ["student_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_monthly_report_aggregates_student_id"), table_name="monthly_report_aggregates")
    op.drop_table("monthly_report_aggregates")

    op.drop_index(op.f("ix_weekly_report_aggregates_student_id"), table_name="weekly_report_aggregates")
    op.drop_table("weekly_report_aggregates")

    op.drop_index(op.f("ix_daily_report_aggregates_student_id"), table_name="daily_report_aggregates")
    op.drop_table("daily_report_aggregates")

    op.drop_index("ix_student_attempt_projections_student_period_key", table_name="student_attempt_projections")
    op.drop_index("ix_student_attempt_projections_student_week_key", table_name="student_attempt_projections")
    op.drop_index("ix_student_attempt_projections_student_day_key", table_name="student_attempt_projections")
    op.drop_index("uq_student_attempt_projections_mock_logical", table_name="student_attempt_projections")
    op.drop_index("uq_student_attempt_projections_today_logical", table_name="student_attempt_projections")
    op.drop_index(op.f("ix_student_attempt_projections_student_id"), table_name="student_attempt_projections")
    op.drop_table("student_attempt_projections")
