"""Add AI content generation jobs and candidates

Revision ID: 20260303_0009
Revises: 20260303_0008
Create Date: 2026-03-03 11:30:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260303_0009"
down_revision: str | None = "20260303_0008"
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
track_enum = postgresql.ENUM("M3", "H1", "H2", "H3", name="track", create_type=False)
skill_enum = postgresql.ENUM("LISTENING", "READING", name="skill", create_type=False)
content_type_tag_enum = postgresql.ENUM(
    "L_GIST",
    "L_DETAIL",
    "L_INTENT",
    "L_RESPONSE",
    "L_SITUATION",
    "L_LONG_TALK",
    "R_MAIN_IDEA",
    "R_DETAIL",
    "R_INFERENCE",
    "R_BLANK",
    "R_ORDER",
    "R_INSERTION",
    "R_SUMMARY",
    "R_VOCAB",
    name="content_type_tag",
    create_type=False,
)
content_source_policy_enum = postgresql.ENUM(
    "AI_ORIGINAL",
    name="content_source_policy",
    create_type=False,
)
ai_content_generation_candidate_status_enum = postgresql.ENUM(
    "VALID",
    "INVALID",
    "MATERIALIZED",
    name="ai_content_generation_candidate_status",
    create_type=False,
)


def _json_type():
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        return postgresql.JSONB(astext_type=sa.Text())
    return sa.JSON()


def upgrade() -> None:
    bind = op.get_bind()
    dialect_name = bind.dialect.name

    if dialect_name == "postgresql":
        content_type_tag_enum.create(bind, checkfirst=True)
        content_source_policy_enum.create(bind, checkfirst=True)
        ai_content_generation_candidate_status_enum.create(bind, checkfirst=True)

    op.create_table(
        "ai_content_generation_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("request_id", sa.String(length=128), nullable=False),
        sa.Column("status", ai_generation_job_status_enum, nullable=False),
        sa.Column("content_unit_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("dry_run", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("candidate_count_per_target", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("target_matrix_json", _json_type(), nullable=False),
        sa.Column("metadata_json", _json_type(), nullable=False),
        sa.Column("provider_override", sa.String(length=64), nullable=True),
        sa.Column("provider_name", sa.String(length=64), nullable=True),
        sa.Column("model_name", sa.String(length=128), nullable=True),
        sa.Column("prompt_template_version", sa.String(length=64), nullable=True),
        sa.Column("input_artifact_object_key", sa.String(length=512), nullable=True),
        sa.Column("output_artifact_object_key", sa.String(length=512), nullable=True),
        sa.Column("candidate_snapshot_object_key", sa.String(length=512), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("last_error_code", sa.String(length=64), nullable=True),
        sa.Column("last_error_message", sa.Text(), nullable=True),
        sa.Column("last_error_transient", sa.Boolean(), nullable=True),
        sa.Column("next_retry_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dead_lettered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("queued_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["content_unit_id"],
            ["content_units.id"],
            name=op.f("fk_ai_content_generation_jobs_content_unit_id_content_units"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_content_generation_jobs")),
        sa.UniqueConstraint("request_id", name="uq_ai_content_generation_jobs_request_id"),
    )
    op.create_index(
        op.f("ix_ai_content_generation_jobs_status"),
        "ai_content_generation_jobs",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_jobs_content_unit_id"),
        "ai_content_generation_jobs",
        ["content_unit_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_jobs_next_retry_at"),
        "ai_content_generation_jobs",
        ["next_retry_at"],
        unique=False,
    )

    op.create_table(
        "ai_content_generation_candidates",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("job_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("candidate_index", sa.Integer(), nullable=False),
        sa.Column("status", ai_content_generation_candidate_status_enum, nullable=False),
        sa.Column("failure_code", sa.String(length=64), nullable=True),
        sa.Column("failure_message", sa.Text(), nullable=True),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("skill", skill_enum, nullable=False),
        sa.Column("type_tag", content_type_tag_enum, nullable=False),
        sa.Column("difficulty", sa.Integer(), nullable=False),
        sa.Column("source_policy", content_source_policy_enum, nullable=False),
        sa.Column("title", sa.String(length=255), nullable=True),
        sa.Column("passage_text", sa.Text(), nullable=True),
        sa.Column("transcript_text", sa.Text(), nullable=True),
        sa.Column("sentences_json", _json_type(), nullable=False),
        sa.Column("turns_json", _json_type(), nullable=False),
        sa.Column("tts_plan_json", _json_type(), nullable=False),
        sa.Column("question_stem", sa.Text(), nullable=False),
        sa.Column("choice_a", sa.Text(), nullable=False),
        sa.Column("choice_b", sa.Text(), nullable=False),
        sa.Column("choice_c", sa.Text(), nullable=False),
        sa.Column("choice_d", sa.Text(), nullable=False),
        sa.Column("choice_e", sa.Text(), nullable=False),
        sa.Column("answer_key", sa.String(length=1), nullable=False),
        sa.Column("explanation_text", sa.Text(), nullable=False),
        sa.Column("evidence_sentence_ids_json", _json_type(), nullable=False),
        sa.Column("why_correct_ko", sa.Text(), nullable=False),
        sa.Column("why_wrong_ko_by_option_json", _json_type(), nullable=False),
        sa.Column("vocab_notes_ko", sa.Text(), nullable=True),
        sa.Column("structure_notes_ko", sa.Text(), nullable=True),
        sa.Column("review_flags_json", _json_type(), nullable=False),
        sa.Column("artifact_prompt_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_response_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_candidate_json_key", sa.String(length=512), nullable=True),
        sa.Column("artifact_validation_report_key", sa.String(length=512), nullable=True),
        sa.Column("materialized_content_unit_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("materialized_revision_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("materialized_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint(
            "difficulty >= 1 AND difficulty <= 5",
            name="ai_cg_cand_diff_range",
        ),
        sa.CheckConstraint(
            "answer_key IN ('A', 'B', 'C', 'D', 'E')",
            name="ai_cg_cand_answer_key",
        ),
        sa.ForeignKeyConstraint(
            ["job_id"],
            ["ai_content_generation_jobs.id"],
            name=op.f("fk_ai_content_generation_candidates_job_id_ai_content_generation_jobs"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["materialized_content_unit_id"],
            ["content_units.id"],
            name=op.f("fk_ai_content_generation_candidates_materialized_content_unit_id_content_units"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["materialized_revision_id"],
            ["content_unit_revisions.id"],
            name=op.f("fk_ai_content_generation_candidates_materialized_revision_id_content_unit_revisions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_content_generation_candidates")),
        sa.UniqueConstraint("job_id", "candidate_index", name="uq_ai_content_generation_candidates_job_index"),
    )
    op.create_index(
        op.f("ix_ai_content_generation_candidates_job_id"),
        "ai_content_generation_candidates",
        ["job_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_candidates_status"),
        "ai_content_generation_candidates",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_candidates_type_tag"),
        "ai_content_generation_candidates",
        ["type_tag"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_candidates_materialized_content_unit_id"),
        "ai_content_generation_candidates",
        ["materialized_content_unit_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_ai_content_generation_candidates_materialized_revision_id"),
        "ai_content_generation_candidates",
        ["materialized_revision_id"],
        unique=False,
    )


def downgrade() -> None:
    bind = op.get_bind()
    dialect_name = bind.dialect.name

    op.drop_index(
        op.f("ix_ai_content_generation_candidates_materialized_revision_id"),
        table_name="ai_content_generation_candidates",
    )
    op.drop_index(
        op.f("ix_ai_content_generation_candidates_materialized_content_unit_id"),
        table_name="ai_content_generation_candidates",
    )
    op.drop_index(op.f("ix_ai_content_generation_candidates_type_tag"), table_name="ai_content_generation_candidates")
    op.drop_index(op.f("ix_ai_content_generation_candidates_status"), table_name="ai_content_generation_candidates")
    op.drop_index(op.f("ix_ai_content_generation_candidates_job_id"), table_name="ai_content_generation_candidates")
    op.drop_table("ai_content_generation_candidates")

    op.drop_index(op.f("ix_ai_content_generation_jobs_next_retry_at"), table_name="ai_content_generation_jobs")
    op.drop_index(op.f("ix_ai_content_generation_jobs_content_unit_id"), table_name="ai_content_generation_jobs")
    op.drop_index(op.f("ix_ai_content_generation_jobs_status"), table_name="ai_content_generation_jobs")
    op.drop_table("ai_content_generation_jobs")

    if dialect_name == "postgresql":
        ai_content_generation_candidate_status_enum.drop(bind, checkfirst=True)
        content_source_policy_enum.drop(bind, checkfirst=True)
        content_type_tag_enum.drop(bind, checkfirst=True)
