"""Add content sync events

Revision ID: 20260308_0013
Revises: 20260307_0012
Create Date: 2026-03-08 10:30:00.000000
"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260308_0013"
down_revision: str | None = "20260307_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

track_enum = postgresql.ENUM("M3", "H1", "H2", "H3", name="track", create_type=False)
content_sync_event_type_enum = postgresql.ENUM(
    "UPSERT",
    "DELETE",
    name="content_sync_event_type",
    create_type=False,
)
content_sync_event_reason_enum = postgresql.ENUM(
    "PUBLISHED",
    "ARCHIVED",
    "REPLACED",
    "UNPUBLISHED",
    name="content_sync_event_reason",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        content_sync_event_type_enum.create(bind, checkfirst=True)
        content_sync_event_reason_enum.create(bind, checkfirst=True)

    op.create_table(
        "content_sync_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track", track_enum, nullable=False),
        sa.Column("unit_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", content_sync_event_type_enum, nullable=False),
        sa.Column("reason", content_sync_event_reason_enum, nullable=False),
        sa.Column("cursor_published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("cursor_revision_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["unit_id"],
            ["content_units.id"],
            name=op.f("fk_content_sync_events_unit_id_content_units"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["revision_id"],
            ["content_unit_revisions.id"],
            name=op.f("fk_content_sync_events_revision_id_content_unit_revisions"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_sync_events")),
    )
    op.create_index(
        op.f("ix_content_sync_events_track"),
        "content_sync_events",
        ["track"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_sync_events_unit_id"),
        "content_sync_events",
        ["unit_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_sync_events_revision_id"),
        "content_sync_events",
        ["revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_content_sync_events_event_type"),
        "content_sync_events",
        ["event_type"],
        unique=False,
    )
    op.create_index(
        "ix_content_sync_events_track_cursor",
        "content_sync_events",
        ["track", "cursor_published_at", "cursor_revision_id"],
        unique=False,
    )

    content_sync_events_table = sa.table(
        "content_sync_events",
        sa.column("id", postgresql.UUID(as_uuid=True)),
        sa.column("track", track_enum),
        sa.column("unit_id", postgresql.UUID(as_uuid=True)),
        sa.column("revision_id", postgresql.UUID(as_uuid=True)),
        sa.column("event_type", content_sync_event_type_enum),
        sa.column("reason", content_sync_event_reason_enum),
        sa.column("cursor_published_at", sa.DateTime(timezone=True)),
        sa.column("cursor_revision_id", postgresql.UUID(as_uuid=True)),
        sa.column("created_at", sa.DateTime(timezone=True)),
    )

    published_rows = bind.execute(
        sa.text(
            """
            SELECT
              cu.track AS track,
              cu.id AS unit_id,
              cur.id AS revision_id,
              cur.published_at AS published_at
            FROM content_units AS cu
            JOIN content_unit_revisions AS cur
              ON cur.id = cu.published_revision_id
            WHERE cu.lifecycle_status = 'PUBLISHED'
              AND cur.lifecycle_status = 'PUBLISHED'
              AND cur.published_at IS NOT NULL
            ORDER BY cur.published_at ASC, cur.id ASC
            """
        )
    ).mappings().all()

    if published_rows:
        now = datetime.now(UTC)
        op.bulk_insert(
            content_sync_events_table,
            [
                {
                    "id": uuid.uuid4(),
                    "track": row["track"],
                    "unit_id": row["unit_id"],
                    "revision_id": row["revision_id"],
                    "event_type": "UPSERT",
                    "reason": "PUBLISHED",
                    "cursor_published_at": row["published_at"],
                    "cursor_revision_id": row["revision_id"],
                    "created_at": now,
                }
                for row in published_rows
            ],
        )


def downgrade() -> None:
    op.drop_index("ix_content_sync_events_track_cursor", table_name="content_sync_events")
    op.drop_index(op.f("ix_content_sync_events_event_type"), table_name="content_sync_events")
    op.drop_index(op.f("ix_content_sync_events_revision_id"), table_name="content_sync_events")
    op.drop_index(op.f("ix_content_sync_events_unit_id"), table_name="content_sync_events")
    op.drop_index(op.f("ix_content_sync_events_track"), table_name="content_sync_events")
    op.drop_table("content_sync_events")

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        content_sync_event_reason_enum.drop(bind, checkfirst=True)
        content_sync_event_type_enum.drop(bind, checkfirst=True)
