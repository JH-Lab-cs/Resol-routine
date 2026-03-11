from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import JSON_TYPE
from app.models.enums import Track
from app.models.vocab_enums import VocabSourceTag


class VocabCatalogEntry(Base):
    __tablename__ = "vocab_catalog_entries"
    __table_args__ = (
        UniqueConstraint("catalog_key", name="uq_vocab_catalog_entries_catalog_key"),
        CheckConstraint(
            "difficulty_band >= 1 AND difficulty_band <= 5",
            name="vocab_catalog_entries_difficulty_band_range",
        ),
        CheckConstraint(
            "frequency_tier IS NULL OR (frequency_tier >= 1 AND frequency_tier <= 5)",
            name="vocab_catalog_entries_frequency_tier_range",
        ),
        Index("ix_vocab_catalog_entries_source_tag", "source_tag"),
        Index(
            "ix_vocab_catalog_entries_track_band",
            "target_min_track",
            "target_max_track",
        ),
        Index("ix_vocab_catalog_entries_difficulty_band", "difficulty_band"),
        Index("ix_vocab_catalog_entries_is_active", "is_active"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    catalog_key: Mapped[str] = mapped_column(String(64), nullable=False)
    lemma: Mapped[str] = mapped_column(String(255), nullable=False)
    pos: Mapped[str] = mapped_column(String(64), nullable=False)
    meaning: Mapped[str] = mapped_column(Text, nullable=False)
    example: Mapped[str] = mapped_column(Text, nullable=False)
    ipa: Mapped[str] = mapped_column(String(128), nullable=False)
    source_tag: Mapped[VocabSourceTag] = mapped_column(
        Enum(VocabSourceTag, name="vocab_source_tag"),
        nullable=False,
    )
    target_min_track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
    )
    target_max_track: Mapped[Track] = mapped_column(
        Enum(Track, name="track"),
        nullable=False,
    )
    difficulty_band: Mapped[int] = mapped_column(Integer, nullable=False)
    frequency_tier: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    source_metadata_json: Mapped[dict[str, Any] | None] = mapped_column(JSON_TYPE, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
