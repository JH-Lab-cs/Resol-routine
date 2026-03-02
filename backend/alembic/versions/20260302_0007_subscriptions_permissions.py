"""Add subscriptions and entitlements tables

Revision ID: 20260302_0007
Revises: 20260302_0006
Create Date: 2026-03-02 22:30:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260302_0007"
down_revision: str | None = "20260302_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

subscription_plan_status_enum = sa.Enum(
    "ACTIVE",
    "ARCHIVED",
    name="subscription_plan_status",
)
subscription_feature_code_enum = sa.Enum(
    "CHILD_REPORTS",
    "WEEKLY_MOCK_EXAMS",
    "MONTHLY_MOCK_EXAMS",
    name="subscription_feature_code",
)
user_subscription_status_enum = sa.Enum(
    "TRIALING",
    "ACTIVE",
    "GRACE",
    "CANCELED",
    "EXPIRED",
    name="user_subscription_status",
)


def upgrade() -> None:
    op.create_table(
        "subscription_plans",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan_code", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=128), nullable=False),
        sa.Column("status", subscription_plan_status_enum, nullable=False),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_subscription_plans")),
        sa.UniqueConstraint("plan_code", name=op.f("uq_subscription_plans_plan_code")),
    )
    op.create_index(op.f("ix_subscription_plans_plan_code"), "subscription_plans", ["plan_code"], unique=True)
    op.create_index(op.f("ix_subscription_plans_status"), "subscription_plans", ["status"], unique=False)

    op.create_table(
        "subscription_plan_features",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_plan_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("feature_code", subscription_feature_code_enum, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["subscription_plan_id"],
            ["subscription_plans.id"],
            name=op.f("fk_subscription_plan_features_subscription_plan_id_subscription_plans"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_subscription_plan_features")),
        sa.UniqueConstraint(
            "subscription_plan_id",
            "feature_code",
            name="uq_subscription_plan_features_plan_feature",
        ),
    )
    op.create_index(
        op.f("ix_subscription_plan_features_subscription_plan_id"),
        "subscription_plan_features",
        ["subscription_plan_id"],
        unique=False,
    )

    op.create_table(
        "user_subscriptions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("owner_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_plan_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", user_subscription_status_enum, nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("grace_ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("external_billing_ref", sa.String(length=256), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("starts_at < ends_at", name=op.f("ck_user_subscriptions_user_subscription_starts_before_ends")),
        sa.CheckConstraint(
            "grace_ends_at IS NULL OR grace_ends_at >= ends_at",
            name=op.f("ck_user_subscriptions_user_subscription_grace_after_ends"),
        ),
        sa.ForeignKeyConstraint(
            ["owner_user_id"],
            ["users.id"],
            name=op.f("fk_user_subscriptions_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["subscription_plan_id"],
            ["subscription_plans.id"],
            name=op.f("fk_user_subscriptions_subscription_plan_id_subscription_plans"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_user_subscriptions")),
    )
    op.create_index(op.f("ix_user_subscriptions_owner_user_id"), "user_subscriptions", ["owner_user_id"], unique=False)
    op.create_index(
        op.f("ix_user_subscriptions_subscription_plan_id"),
        "user_subscriptions",
        ["subscription_plan_id"],
        unique=False,
    )
    op.create_index(op.f("ix_user_subscriptions_status"), "user_subscriptions", ["status"], unique=False)
    op.create_index(
        "ix_user_subscriptions_owner_status_window",
        "user_subscriptions",
        ["owner_user_id", "status", "starts_at", "ends_at", "grace_ends_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_user_subscriptions_owner_status_window", table_name="user_subscriptions")
    op.drop_index(op.f("ix_user_subscriptions_status"), table_name="user_subscriptions")
    op.drop_index(op.f("ix_user_subscriptions_subscription_plan_id"), table_name="user_subscriptions")
    op.drop_index(op.f("ix_user_subscriptions_owner_user_id"), table_name="user_subscriptions")
    op.drop_table("user_subscriptions")

    op.drop_index(op.f("ix_subscription_plan_features_subscription_plan_id"), table_name="subscription_plan_features")
    op.drop_table("subscription_plan_features")

    op.drop_index(op.f("ix_subscription_plans_status"), table_name="subscription_plans")
    op.drop_index(op.f("ix_subscription_plans_plan_code"), table_name="subscription_plans")
    op.drop_table("subscription_plans")

    user_subscription_status_enum.drop(op.get_bind(), checkfirst=True)
    subscription_feature_code_enum.drop(op.get_bind(), checkfirst=True)
    subscription_plan_status_enum.drop(op.get_bind(), checkfirst=True)
