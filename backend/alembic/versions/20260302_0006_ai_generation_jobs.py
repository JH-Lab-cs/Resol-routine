"""Add ai generation jobs table

Revision ID: 20260302_0006
Revises: 20260302_0005
Create Date: 2026-03-02 23:10:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260302_0006"
down_revision: str | None = "20260302_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ai_generation_job_type_enum = sa.Enum(
    "MOCK_EXAM_REVISION_DRAFT_GENERATION",
    name="ai_generation_job_type",
)
ai_generation_job_status_enum = sa.Enum(
    "QUEUED",
    "RUNNING",
    "SUCCEEDED",
    "FAILED",
    name="ai_generation_job_status",
)


def upgrade() -> None:
    op.create_table(
        "ai_generation_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("job_type", ai_generation_job_type_enum, nullable=False),
        sa.Column("request_id", sa.String(length=128), nullable=False),
        sa.Column("status", ai_generation_job_status_enum, nullable=False),
        sa.Column("target_mock_exam_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("generator_version", sa.String(length=128), nullable=False),
        sa.Column("candidate_limit", sa.Integer(), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("provider_name", sa.String(length=64), nullable=True),
        sa.Column("model_name", sa.String(length=128), nullable=True),
        sa.Column("prompt_template_version", sa.String(length=64), nullable=True),
        sa.Column("input_artifact_object_key", sa.String(length=512), nullable=True),
        sa.Column("output_artifact_object_key", sa.String(length=512), nullable=True),
        sa.Column("candidate_snapshot_object_key", sa.String(length=512), nullable=True),
        sa.Column("produced_mock_exam_revision_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("last_error_code", sa.String(length=64), nullable=True),
        sa.Column("last_error_message", sa.Text(), nullable=True),
        sa.Column("queued_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["produced_mock_exam_revision_id"],
            ["mock_exam_revisions.id"],
            name=op.f("fk_ai_generation_jobs_produced_mock_exam_revision_id_mock_exam_revisions"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["target_mock_exam_id"],
            ["mock_exams.id"],
            name=op.f("fk_ai_generation_jobs_target_mock_exam_id_mock_exams"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_generation_jobs")),
        sa.UniqueConstraint("job_type", "request_id", name="uq_ai_generation_jobs_type_request_id"),
    )
    op.create_index(op.f("ix_ai_generation_jobs_status"), "ai_generation_jobs", ["status"], unique=False)
    op.create_index(
        op.f("ix_ai_generation_jobs_target_mock_exam_id"),
        "ai_generation_jobs",
        ["target_mock_exam_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_generation_jobs_produced_mock_exam_revision_id"),
        "ai_generation_jobs",
        ["produced_mock_exam_revision_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_ai_generation_jobs_produced_mock_exam_revision_id"), table_name="ai_generation_jobs")
    op.drop_index(op.f("ix_ai_generation_jobs_target_mock_exam_id"), table_name="ai_generation_jobs")
    op.drop_index(op.f("ix_ai_generation_jobs_status"), table_name="ai_generation_jobs")
    op.drop_table("ai_generation_jobs")

    ai_generation_job_status_enum.drop(op.get_bind(), checkfirst=True)
    ai_generation_job_type_enum.drop(op.get_bind(), checkfirst=True)
