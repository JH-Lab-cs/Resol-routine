"""Add mock assembly jobs table

Revision ID: 20260305_0010
Revises: 20260303_0009
Create Date: 2026-03-05 22:40:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260305_0010"
down_revision: str | None = "20260303_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ai_generation_job_status_enum = postgresql.ENUM(
    "QUEUED",
    "RUNNING",
    "SUCCEEDED",
    "FAILED",
    "DEAD_LETTER",
    name="ai_generation_job_status",
    create_type=False,
)
mock_exam_type_enum = postgresql.ENUM(
    "WEEKLY",
    "MONTHLY",
    name="mock_exam_type",
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


def _json_type() -> sa.types.TypeEngine:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        return postgresql.JSONB(astext_type=sa.Text())
    return sa.JSON()


def upgrade() -> None:
    op.create_table(
        "mock_assembly_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", ai_generation_job_status_enum, nullable=False),
        sa.Column("exam_type", mock_exam_type_enum, nullable=False),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("period_key", sa.String(length=8), nullable=False),
        sa.Column("seed", sa.String(length=128), nullable=False),
        sa.Column("dry_run", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("force_rebuild", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("target_difficulty_profile_json", _json_type(), nullable=False),
        sa.Column("candidate_pool_counts_json", _json_type(), nullable=False),
        sa.Column("summary_json", _json_type(), nullable=False),
        sa.Column("constraint_summary_json", _json_type(), nullable=False),
        sa.Column("warnings_json", _json_type(), nullable=False),
        sa.Column("assembly_trace_json", _json_type(), nullable=False),
        sa.Column("failure_code", sa.String(length=64), nullable=True),
        sa.Column("failure_message", sa.Text(), nullable=True),
        sa.Column("produced_mock_exam_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("produced_mock_exam_revision_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["produced_mock_exam_id"],
            ["mock_exams.id"],
            name=op.f("fk_mock_assembly_jobs_produced_mock_exam_id_mock_exams"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["produced_mock_exam_revision_id"],
            ["mock_exam_revisions.id"],
            name=op.f("fk_mock_assembly_jobs_produced_mock_exam_revision_id_mock_exam_revisions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mock_assembly_jobs")),
    )
    op.create_index(
        op.f("ix_mock_assembly_jobs_status"),
        "mock_assembly_jobs",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_assembly_jobs_exam_type"),
        "mock_assembly_jobs",
        ["exam_type"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_assembly_jobs_track"),
        "mock_assembly_jobs",
        ["track"],
        unique=False,
    )
    op.create_index(
        "ix_mock_assembly_jobs_exam_target",
        "mock_assembly_jobs",
        ["exam_type", "track", "period_key"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_assembly_jobs_produced_mock_exam_id"),
        "mock_assembly_jobs",
        ["produced_mock_exam_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mock_assembly_jobs_produced_mock_exam_revision_id"),
        "mock_assembly_jobs",
        ["produced_mock_exam_revision_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_mock_assembly_jobs_produced_mock_exam_revision_id"),
        table_name="mock_assembly_jobs",
    )
    op.drop_index(
        op.f("ix_mock_assembly_jobs_produced_mock_exam_id"),
        table_name="mock_assembly_jobs",
    )
    op.drop_index("ix_mock_assembly_jobs_exam_target", table_name="mock_assembly_jobs")
    op.drop_index(op.f("ix_mock_assembly_jobs_track"), table_name="mock_assembly_jobs")
    op.drop_index(op.f("ix_mock_assembly_jobs_exam_type"), table_name="mock_assembly_jobs")
    op.drop_index(op.f("ix_mock_assembly_jobs_status"), table_name="mock_assembly_jobs")
    op.drop_table("mock_assembly_jobs")
