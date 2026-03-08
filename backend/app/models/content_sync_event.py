from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Index, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.content_sync_enums import ContentSyncEventReason, ContentSyncEventType
from app.models.enums import Track


class ContentSyncEvent(Base):
    __tablename__ = "content_sync_events"
    __table_args__ = (
        Index(
            "ix_content_sync_events_track_cursor",
            "track",
            "cursor_published_at",
            "cursor_revision_id",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
        index=True,
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_units.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("content_unit_revisions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type: Mapped[ContentSyncEventType] = mapped_column(
        Enum(ContentSyncEventType, name="content_sync_event_type"),
        nullable=False,
        index=True,
    )
    reason: Mapped[ContentSyncEventReason] = mapped_column(
        Enum(ContentSyncEventReason, name="content_sync_event_reason"),
        nullable=False,
    )
    cursor_published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    cursor_revision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
