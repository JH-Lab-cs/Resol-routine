"""Add auth and family link indexes/constraints

Revision ID: 20260301_0002
Revises: 20260301_0001
Create Date: 2026-03-01 00:30:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260301_0002"
down_revision: str | None = "20260301_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "ix_refresh_tokens_family_active_lookup",
        "refresh_tokens",
        ["family_id", "revoked_at", "expires_at"],
        unique=False,
    )
    op.create_index(
        "ix_invite_codes_parent_active_lookup",
        "invite_codes",
        ["parent_id", "consumed_at", "expires_at"],
        unique=False,
    )
    op.create_check_constraint(
        "ck_parent_child_links_parent_child_link_distinct_users",
        "parent_child_links",
        sa.text("parent_id <> child_id"),
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_parent_child_links_parent_child_link_distinct_users",
        "parent_child_links",
        type_="check",
    )
    op.drop_index("ix_invite_codes_parent_active_lookup", table_name="invite_codes")
    op.drop_index("ix_refresh_tokens_family_active_lookup", table_name="refresh_tokens")
