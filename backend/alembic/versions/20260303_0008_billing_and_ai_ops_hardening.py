"""Add billing domain tables and AI operational hardening fields

Revision ID: 20260303_0008
Revises: 20260302_0007
Create Date: 2026-03-03 00:40:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260303_0008"
down_revision: str | None = "20260302_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

billing_provider_enum = postgresql.ENUM(
    "STRIPE",
    "APP_STORE",
    name="billing_provider",
    create_type=False,
)
billing_webhook_status_enum = postgresql.ENUM(
    "PROCESSED",
    "IGNORED",
    "FAILED",
    name="billing_webhook_status",
    create_type=False,
)
billing_receipt_verification_status_enum = postgresql.ENUM(
    "VERIFIED",
    "REJECTED",
    "ERROR",
    name="billing_receipt_verification_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    dialect_name = bind.dialect.name

    if dialect_name == "postgresql":
        op.execute("ALTER TYPE ai_generation_job_status ADD VALUE IF NOT EXISTS 'DEAD_LETTER'")

    op.add_column("ai_generation_jobs", sa.Column("last_error_transient", sa.Boolean(), nullable=True))
    op.add_column("ai_generation_jobs", sa.Column("next_retry_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("ai_generation_jobs", sa.Column("dead_lettered_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index(
        op.f("ix_ai_generation_jobs_next_retry_at"),
        "ai_generation_jobs",
        ["next_retry_at"],
        unique=False,
    )

    if dialect_name == "postgresql":
        op.execute(
            "DO $$ BEGIN CREATE TYPE billing_provider AS ENUM ('STRIPE', 'APP_STORE'); "
            "EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
        )
        op.execute(
            "DO $$ BEGIN CREATE TYPE billing_webhook_status AS ENUM ('PROCESSED', 'IGNORED', 'FAILED'); "
            "EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
        )
        op.execute(
            "DO $$ BEGIN CREATE TYPE billing_receipt_verification_status AS ENUM ('VERIFIED', 'REJECTED', 'ERROR'); "
            "EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
        )

    op.create_table(
        "billing_webhook_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider", billing_provider_enum, nullable=False),
        sa.Column("provider_event_id", sa.String(length=128), nullable=False),
        sa.Column("event_type", sa.String(length=128), nullable=False),
        sa.Column("status", billing_webhook_status_enum, nullable=False),
        sa.Column("owner_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("request_id", sa.String(length=128), nullable=True),
        sa.Column("payload_sha256", sa.String(length=64), nullable=False),
        sa.Column("error_code", sa.String(length=64), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_user_id"],
            ["users.id"],
            name=op.f("fk_billing_webhook_events_owner_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["subscription_id"],
            ["user_subscriptions.id"],
            name=op.f("fk_billing_webhook_events_subscription_id_user_subscriptions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_billing_webhook_events")),
        sa.UniqueConstraint(
            "provider",
            "provider_event_id",
            name="uq_billing_webhook_events_provider_event_id",
        ),
    )
    op.create_index(op.f("ix_billing_webhook_events_provider"), "billing_webhook_events", ["provider"], unique=False)
    op.create_index(
        op.f("ix_billing_webhook_events_owner_user_id"),
        "billing_webhook_events",
        ["owner_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_billing_webhook_events_subscription_id"),
        "billing_webhook_events",
        ["subscription_id"],
        unique=False,
    )
    op.create_index(op.f("ix_billing_webhook_events_status"), "billing_webhook_events", ["status"], unique=False)

    op.create_table(
        "billing_receipt_verifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider", billing_provider_enum, nullable=False),
        sa.Column("owner_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("status", billing_receipt_verification_status_enum, nullable=False),
        sa.Column("plan_code", sa.String(length=64), nullable=True),
        sa.Column("transaction_id", sa.String(length=128), nullable=True),
        sa.Column("original_transaction_id", sa.String(length=128), nullable=True),
        sa.Column("verification_request_hash", sa.String(length=64), nullable=False),
        sa.Column("provider_response_code", sa.String(length=64), nullable=True),
        sa.Column("error_code", sa.String(length=64), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_user_id"],
            ["users.id"],
            name=op.f("fk_billing_receipt_verifications_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["subscription_id"],
            ["user_subscriptions.id"],
            name=op.f("fk_billing_receipt_verifications_subscription_id_user_subscriptions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_billing_receipt_verifications")),
    )
    op.create_index(
        op.f("ix_billing_receipt_verifications_owner_user_id"),
        "billing_receipt_verifications",
        ["owner_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_billing_receipt_verifications_provider"),
        "billing_receipt_verifications",
        ["provider"],
        unique=False,
    )
    op.create_index(
        op.f("ix_billing_receipt_verifications_status"),
        "billing_receipt_verifications",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_billing_receipt_verifications_subscription_id"),
        "billing_receipt_verifications",
        ["subscription_id"],
        unique=False,
    )

    if dialect_name == "postgresql":
        op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
        op.execute(
            """
            ALTER TABLE user_subscriptions
            ADD CONSTRAINT ex_user_subscriptions_owner_entitlement_window
            EXCLUDE USING gist (
                owner_user_id WITH =,
                tstzrange(starts_at, COALESCE(grace_ends_at, ends_at), '[]') WITH &&
            )
            WHERE (status IN ('TRIALING', 'ACTIVE', 'GRACE'))
            """
        )


def downgrade() -> None:
    bind = op.get_bind()
    dialect_name = bind.dialect.name

    if dialect_name == "postgresql":
        op.execute(
            """
            ALTER TABLE user_subscriptions
            DROP CONSTRAINT IF EXISTS ex_user_subscriptions_owner_entitlement_window
            """
        )

    op.drop_index(op.f("ix_billing_receipt_verifications_subscription_id"), table_name="billing_receipt_verifications")
    op.drop_index(op.f("ix_billing_receipt_verifications_status"), table_name="billing_receipt_verifications")
    op.drop_index(op.f("ix_billing_receipt_verifications_provider"), table_name="billing_receipt_verifications")
    op.drop_index(op.f("ix_billing_receipt_verifications_owner_user_id"), table_name="billing_receipt_verifications")
    op.drop_table("billing_receipt_verifications")

    op.drop_index(op.f("ix_billing_webhook_events_status"), table_name="billing_webhook_events")
    op.drop_index(op.f("ix_billing_webhook_events_subscription_id"), table_name="billing_webhook_events")
    op.drop_index(op.f("ix_billing_webhook_events_owner_user_id"), table_name="billing_webhook_events")
    op.drop_index(op.f("ix_billing_webhook_events_provider"), table_name="billing_webhook_events")
    op.drop_table("billing_webhook_events")

    if dialect_name == "postgresql":
        op.execute("DROP TYPE IF EXISTS billing_receipt_verification_status")
        op.execute("DROP TYPE IF EXISTS billing_webhook_status")
        op.execute("DROP TYPE IF EXISTS billing_provider")

    op.drop_index(op.f("ix_ai_generation_jobs_next_retry_at"), table_name="ai_generation_jobs")
    op.drop_column("ai_generation_jobs", "dead_lettered_at")
    op.drop_column("ai_generation_jobs", "next_retry_at")
    op.drop_column("ai_generation_jobs", "last_error_transient")
