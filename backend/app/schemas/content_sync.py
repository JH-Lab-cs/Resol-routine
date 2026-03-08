from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.policies import (
    CONTENT_SYNC_CURSOR_MAX_LENGTH,
    CONTENT_SYNC_DEFAULT_PAGE_SIZE,
    CONTENT_SYNC_MAX_PAGE_SIZE,
)
from app.models.content_sync_enums import ContentSyncEventReason
from app.models.enums import ContentTypeTag, Skill, Track


class PublicContentSyncQuery(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    track: Track
    cursor: str | None = None
    page_size: int = Field(default=CONTENT_SYNC_DEFAULT_PAGE_SIZE, alias="pageSize")

    @field_validator("cursor")
    @classmethod
    def validate_cursor(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("invalid_sync_cursor")
        if len(normalized) > CONTENT_SYNC_CURSOR_MAX_LENGTH:
            raise ValueError("invalid_sync_cursor")
        return normalized

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, value: int) -> int:
        if value <= 0 or value > CONTENT_SYNC_MAX_PAGE_SIZE:
            raise ValueError("invalid_page_size")
        return value


class PublicContentSyncCursorPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    published_at: datetime = Field(alias="publishedAt")
    revision_id: UUID = Field(alias="revisionId")

    @field_validator("published_at")
    @classmethod
    def validate_published_at(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("invalid_sync_cursor")
        return value.astimezone(UTC)


class PublicContentSyncUpsertItem(BaseModel):
    unit_id: UUID = Field(serialization_alias="unitId")
    revision_id: UUID = Field(serialization_alias="revisionId")
    track: Track
    skill: Skill
    type_tag: ContentTypeTag = Field(serialization_alias="typeTag")
    difficulty: int
    published_at: datetime = Field(serialization_alias="publishedAt")
    has_audio: bool = Field(serialization_alias="hasAudio")


class PublicContentSyncDeleteItem(BaseModel):
    unit_id: UUID = Field(serialization_alias="unitId")
    revision_id: UUID = Field(serialization_alias="revisionId")
    reason: ContentSyncEventReason
    changed_at: datetime = Field(serialization_alias="changedAt")


class PublicContentSyncResponse(BaseModel):
    upserts: list[PublicContentSyncUpsertItem]
    deletes: list[PublicContentSyncDeleteItem]
    next_cursor: str | None = Field(serialization_alias="nextCursor")
    has_more: bool = Field(serialization_alias="hasMore")
