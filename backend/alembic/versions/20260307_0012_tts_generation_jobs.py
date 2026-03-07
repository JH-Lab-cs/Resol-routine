"""Add tts generation jobs

Revision ID: 20260307_0012
Revises: 20260306_0011
Create Date: 2026-03-07 15:40:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260307_0012"
down_revision: str | None = "20260306_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

track_enum = postgresql.ENUM("M3", "H1", "H2", "H3", name="track", create_type=False)
tts_generation_job_status_enum = postgresql.ENUM(
    "PENDING",
    "RUNNING",
    "SUCCEEDED",
    "FAILED",
    name="tts_generation_job_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        tts_generation_job_status_enum.create(bind, checkfirst=True)

    op.create_table(
        "tts_generation_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("provider", sa.String(length=64), nullable=False),
        sa.Column("model_name", sa.String(length=128), nullable=False),
        sa.Column("voice", sa.String(length=64), nullable=False),
        sa.Column("speed", sa.Float(), nullable=False),
        sa.Column("force_regen", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("input_text_sha256", sa.String(length=64), nullable=False),
        sa.Column("input_text_len", sa.Integer(), nullable=False),
        sa.Column("status", tts_generation_job_status_enum, nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("error_code", sa.String(length=64), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("artifact_request_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_response_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_candidate_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_validation_key", sa.String(length=512), nullable=True),
        sa.Column("output_asset_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("output_object_key", sa.String(length=512), nullable=True),
        sa.Column("output_bytes", sa.Integer(), nullable=True),
        sa.Column("output_sha256", sa.String(length=64), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["revision_id"],
            ["content_unit_revisions.id"],
            name=op.f("fk_tts_generation_jobs_revision_id_content_unit_revisions"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["output_asset_id"],
            ["content_assets.id"],
            name=op.f("fk_tts_generation_jobs_output_asset_id_content_assets"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_tts_generation_jobs")),
    )
    op.create_index(
        op.f("ix_tts_generation_jobs_revision_id"),
        "tts_generation_jobs",
        ["revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_tts_generation_jobs_track"),
        "tts_generation_jobs",
        ["track"],
        unique=False,
    )
    op.create_index(
        op.f("ix_tts_generation_jobs_status"),
        "tts_generation_jobs",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_tts_generation_jobs_input_text_sha256"),
        "tts_generation_jobs",
        ["input_text_sha256"],
        unique=False,
    )
    op.create_index(
        op.f("ix_tts_generation_jobs_output_asset_id"),
        "tts_generation_jobs",
        ["output_asset_id"],
        unique=False,
    )
    active_status_where = sa.text("status IN ('PENDING','RUNNING')")
    op.create_index(
        "uq_tts_generation_jobs_revision_active",
        "tts_generation_jobs",
        ["revision_id"],
        unique=True,
        postgresql_where=active_status_where,
        sqlite_where=active_status_where,
    )


def downgrade() -> None:
    op.drop_index("uq_tts_generation_jobs_revision_active", table_name="tts_generation_jobs")
    op.drop_index(
        op.f("ix_tts_generation_jobs_output_asset_id"),
        table_name="tts_generation_jobs",
    )
    op.drop_index(
        op.f("ix_tts_generation_jobs_input_text_sha256"),
        table_name="tts_generation_jobs",
    )
    op.drop_index(op.f("ix_tts_generation_jobs_status"), table_name="tts_generation_jobs")
    op.drop_index(op.f("ix_tts_generation_jobs_track"), table_name="tts_generation_jobs")
    op.drop_index(op.f("ix_tts_generation_jobs_revision_id"), table_name="tts_generation_jobs")
    op.drop_table("tts_generation_jobs")

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        tts_generation_job_status_enum.drop(bind, checkfirst=True)
