"""Add content backend domain tables

Revision ID: 20260302_0004
Revises: 20260302_0003
Create Date: 2026-03-02 16:20:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260302_0004"
down_revision: str | None = "20260302_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

content_lifecycle_status_enum = sa.Enum(
    "DRAFT",
    "PUBLISHED",
    "ARCHIVED",
    name="content_lifecycle_status",
)
skill_enum = sa.Enum("LISTENING", "READING", name="skill")
track_enum = sa.Enum("M3", "H1", "H2", "H3", name="track")


def upgrade() -> None:
    op.create_table(
        "content_assets",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("object_key", sa.String(length=512), nullable=False),
        sa.Column("mime_type", sa.String(length=255), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("sha256_hex", sa.String(length=64), nullable=False),
        sa.Column("etag", sa.String(length=128), nullable=True),
        sa.Column("bucket", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("size_bytes > 0", name=op.f("ck_content_assets_content_asset_size_positive")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_assets")),
    )
    op.create_index(op.f("ix_content_assets_object_key"), "content_assets", ["object_key"], unique=True)

    op.create_table(
        "content_units",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("external_id", sa.String(length=128), nullable=False),
        sa.Column("slug", sa.String(length=128), nullable=True),
        sa.Column("skill", skill_enum, nullable=False),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("lifecycle_status", content_lifecycle_status_enum, nullable=False),
        sa.Column("published_revision_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_units")),
        sa.UniqueConstraint("external_id", name=op.f("uq_content_units_external_id")),
        sa.UniqueConstraint("slug", name=op.f("uq_content_units_slug")),
    )
    op.create_index(op.f("ix_content_units_external_id"), "content_units", ["external_id"], unique=False)
    op.create_index(
        "ix_content_units_skill_track_lifecycle_status",
        "content_units",
        ["skill", "track", "lifecycle_status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_units_published_revision_id"),
        "content_units",
        ["published_revision_id"],
        unique=False,
    )

    op.create_table(
        "content_unit_revisions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("content_unit_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("revision_no", sa.Integer(), nullable=False),
        sa.Column("revision_code", sa.String(length=32), nullable=False),
        sa.Column("generator_version", sa.String(length=128), nullable=False),
        sa.Column("validator_version", sa.String(length=128), nullable=True),
        sa.Column("validated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewer_identity", sa.String(length=128), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=True),
        sa.Column("body_text", sa.Text(), nullable=True),
        sa.Column("transcript_text", sa.Text(), nullable=True),
        sa.Column("explanation_text", sa.Text(), nullable=True),
        sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("lifecycle_status", content_lifecycle_status_enum, nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["asset_id"],
            ["content_assets.id"],
            name=op.f("fk_content_unit_revisions_asset_id_content_assets"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["content_unit_id"],
            ["content_units.id"],
            name=op.f("fk_content_unit_revisions_content_unit_id_content_units"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_unit_revisions")),
        sa.UniqueConstraint(
            "content_unit_id",
            "revision_no",
            name="uq_content_unit_revisions_unit_revision_no",
        ),
        sa.UniqueConstraint(
            "content_unit_id",
            "revision_code",
            name="uq_content_unit_revisions_unit_revision_code",
        ),
    )
    op.create_index(
        op.f("ix_content_unit_revisions_content_unit_id"),
        "content_unit_revisions",
        ["content_unit_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_unit_revisions_asset_id"),
        "content_unit_revisions",
        ["asset_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_unit_revisions_lifecycle_status"),
        "content_unit_revisions",
        ["lifecycle_status"],
        unique=False,
    )
    op.create_index(
        "uq_content_unit_revisions_active_published",
        "content_unit_revisions",
        ["content_unit_id"],
        unique=True,
        postgresql_where=sa.text("lifecycle_status = 'PUBLISHED'"),
        sqlite_where=sa.text("lifecycle_status = 'PUBLISHED'"),
    )
    op.create_foreign_key(
        op.f("fk_content_units_published_revision_id_content_unit_revisions"),
        "content_units",
        "content_unit_revisions",
        ["published_revision_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "content_questions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("content_unit_revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("question_code", sa.String(length=128), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("stem", sa.Text(), nullable=False),
        sa.Column("choice_a", sa.Text(), nullable=False),
        sa.Column("choice_b", sa.Text(), nullable=False),
        sa.Column("choice_c", sa.Text(), nullable=False),
        sa.Column("choice_d", sa.Text(), nullable=False),
        sa.Column("choice_e", sa.Text(), nullable=False),
        sa.Column("correct_answer", sa.String(length=1), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint(
            "correct_answer IN ('A', 'B', 'C', 'D', 'E')",
            name=op.f("ck_content_questions_content_question_correct_answer_allowed"),
        ),
        sa.CheckConstraint("order_index > 0", name=op.f("ck_content_questions_content_question_order_index_positive")),
        sa.ForeignKeyConstraint(
            ["content_unit_revision_id"],
            ["content_unit_revisions.id"],
            name=op.f("fk_content_questions_content_unit_revision_id_content_unit_revisions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_questions")),
        sa.UniqueConstraint(
            "content_unit_revision_id",
            "question_code",
            name="uq_content_questions_revision_question_code",
        ),
        sa.UniqueConstraint(
            "content_unit_revision_id",
            "order_index",
            name="uq_content_questions_revision_order_index",
        ),
    )
    op.create_index(
        op.f("ix_content_questions_content_unit_revision_id"),
        "content_questions",
        ["content_unit_revision_id"],
        unique=False,
    )
    op.create_index(
        "ix_content_questions_revision_order_code",
        "content_questions",
        ["content_unit_revision_id", "order_index", "question_code"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_content_questions_revision_order_code", table_name="content_questions")
    op.drop_index(op.f("ix_content_questions_content_unit_revision_id"), table_name="content_questions")
    op.drop_table("content_questions")

    op.drop_constraint(
        op.f("fk_content_units_published_revision_id_content_unit_revisions"),
        "content_units",
        type_="foreignkey",
    )
    op.drop_index("uq_content_unit_revisions_active_published", table_name="content_unit_revisions")
    op.drop_index(op.f("ix_content_unit_revisions_lifecycle_status"), table_name="content_unit_revisions")
    op.drop_index(op.f("ix_content_unit_revisions_asset_id"), table_name="content_unit_revisions")
    op.drop_index(op.f("ix_content_unit_revisions_content_unit_id"), table_name="content_unit_revisions")
    op.drop_table("content_unit_revisions")

    op.drop_index(op.f("ix_content_units_published_revision_id"), table_name="content_units")
    op.drop_index("ix_content_units_skill_track_lifecycle_status", table_name="content_units")
    op.drop_index(op.f("ix_content_units_external_id"), table_name="content_units")
    op.drop_table("content_units")

    op.drop_index(op.f("ix_content_assets_object_key"), table_name="content_assets")
    op.drop_table("content_assets")

    track_enum.drop(op.get_bind(), checkfirst=True)
    skill_enum.drop(op.get_bind(), checkfirst=True)
    content_lifecycle_status_enum.drop(op.get_bind(), checkfirst=True)
