"""Add backend vocab catalog entries

Revision ID: 20260311_0014
Revises: 20260308_0013
Create Date: 2026-03-11 14:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260311_0014"
down_revision: str | None = "20260308_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

track_enum = postgresql.ENUM("M3", "H1", "H2", "H3", name="track", create_type=False)
vocab_source_tag_enum = postgresql.ENUM(
    "CSAT",
    "SCHOOL_CORE",
    "USER_CUSTOM",
    name="vocab_source_tag",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        vocab_source_tag_enum.create(bind, checkfirst=True)

    op.create_table(
        "vocab_catalog_entries",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("catalog_key", sa.String(length=64), nullable=False),
        sa.Column("lemma", sa.String(length=255), nullable=False),
        sa.Column("pos", sa.String(length=64), nullable=False),
        sa.Column("meaning", sa.Text(), nullable=False),
        sa.Column("example", sa.Text(), nullable=False),
        sa.Column("ipa", sa.String(length=128), nullable=False),
        sa.Column("source_tag", vocab_source_tag_enum, nullable=False),
        sa.Column("target_min_track", track_enum, nullable=False),
        sa.Column("target_max_track", track_enum, nullable=False),
        sa.Column("difficulty_band", sa.Integer(), nullable=False),
        sa.Column("frequency_tier", sa.Integer(), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column("source_metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "difficulty_band >= 1 AND difficulty_band <= 5",
            name=op.f("ck_vocab_catalog_entries_vocab_catalog_entries_difficulty_band_range"),
        ),
        sa.CheckConstraint(
            "frequency_tier IS NULL OR (frequency_tier >= 1 AND frequency_tier <= 5)",
            name=op.f("ck_vocab_catalog_entries_vocab_catalog_entries_frequency_tier_range"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_vocab_catalog_entries")),
        sa.UniqueConstraint("catalog_key", name=op.f("uq_vocab_catalog_entries_catalog_key")),
    )
    op.create_index(
        "ix_vocab_catalog_entries_source_tag",
        "vocab_catalog_entries",
        ["source_tag"],
        unique=False,
    )
    op.create_index(
        "ix_vocab_catalog_entries_track_band",
        "vocab_catalog_entries",
        ["target_min_track", "target_max_track"],
        unique=False,
    )
    op.create_index(
        "ix_vocab_catalog_entries_difficulty_band",
        "vocab_catalog_entries",
        ["difficulty_band"],
        unique=False,
    )
    op.create_index(
        "ix_vocab_catalog_entries_is_active",
        "vocab_catalog_entries",
        ["is_active"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_vocab_catalog_entries_is_active", table_name="vocab_catalog_entries")
    op.drop_index("ix_vocab_catalog_entries_difficulty_band", table_name="vocab_catalog_entries")
    op.drop_index("ix_vocab_catalog_entries_track_band", table_name="vocab_catalog_entries")
    op.drop_index("ix_vocab_catalog_entries_source_tag", table_name="vocab_catalog_entries")
    op.drop_table("vocab_catalog_entries")

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        vocab_source_tag_enum.drop(bind, checkfirst=True)
