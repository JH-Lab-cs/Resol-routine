"""Add student-issued family link codes

Revision ID: 20260313_0015
Revises: 20260311_0014
Create Date: 2026-03-13 16:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260313_0015"
down_revision: str | None = "20260311_0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "family_link_codes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "expires_at > created_at",
            name="family_link_code_expiry_after_creation",
        ),
        sa.ForeignKeyConstraint(
            ["child_id"],
            ["users.id"],
            name=op.f("fk_family_link_codes_child_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["consumed_by_user_id"],
            ["users.id"],
            name=op.f("fk_family_link_codes_consumed_by_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_family_link_codes")),
        sa.UniqueConstraint("code_hash", name=op.f("uq_family_link_codes_code_hash")),
    )
    op.create_index(
        op.f("ix_family_link_codes_child_id"),
        "family_link_codes",
        ["child_id"],
        unique=False,
    )
    op.create_index(
        "ix_family_link_codes_child_active_lookup",
        "family_link_codes",
        ["child_id", "consumed_at", "expires_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_family_link_codes_child_active_lookup", table_name="family_link_codes")
    op.drop_index(op.f("ix_family_link_codes_child_id"), table_name="family_link_codes")
    op.drop_table("family_link_codes")
