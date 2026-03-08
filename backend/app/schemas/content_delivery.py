from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, ValidationInfo, field_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import CONTENT_LIST_DEFAULT_PAGE_SIZE, CONTENT_LIST_MAX_PAGE_SIZE
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill, Track


class PublicContentListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    track: Track
    skill: Skill | None = None
    type_tag: ContentTypeTag | None = Field(default=None, alias="typeTag")
    changed_since: datetime | None = Field(default=None, alias="changedSince")
    page: int = 1
    page_size: int = Field(default=CONTENT_LIST_DEFAULT_PAGE_SIZE, alias="pageSize")

    @field_validator("track", "skill", "type_tag", mode="before")
    @classmethod
    def validate_filter_identifiers(cls, value: object, info: ValidationInfo) -> object:
        if value is None:
            return None
        if isinstance(value, (Track, Skill, ContentTypeTag)):
            return value
        if isinstance(value, str):
            return validate_user_input_text(
                value,
                field_name=info.field_name or "content_filter",
            )
        return value

    @field_validator("changed_since")
    @classmethod
    def validate_changed_since(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("changed_since_must_be_timezone_aware")
        return value.astimezone(UTC)

    @field_validator("page")
    @classmethod
    def validate_page(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_page")
        return value

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, value: int) -> int:
        if value <= 0 or value > CONTENT_LIST_MAX_PAGE_SIZE:
            raise ValueError("invalid_page_size")
        return value


class PublishedContentListItem(BaseModel):
    unit_id: UUID = Field(serialization_alias="unitId")
    revision_id: UUID = Field(serialization_alias="revisionId")
    track: Track
    skill: Skill
    type_tag: ContentTypeTag = Field(serialization_alias="typeTag")
    difficulty: int
    published_at: datetime = Field(serialization_alias="publishedAt")
    has_audio: bool = Field(serialization_alias="hasAudio")


class PublishedContentListResponse(BaseModel):
    items: list[PublishedContentListItem]
    page: int
    page_size: int = Field(serialization_alias="pageSize")
    total: int
    next_changed_since: datetime | None = Field(serialization_alias="nextChangedSince")


class PublishedContentAssetPayload(BaseModel):
    asset_id: UUID = Field(serialization_alias="assetId")
    mime_type: str = Field(serialization_alias="mimeType")
    signed_url: str = Field(serialization_alias="signedUrl")
    expires_in_seconds: int = Field(serialization_alias="expiresInSeconds")


class PublishedContentQuestionPayload(BaseModel):
    stem: str
    options: dict[str, str]
    answer_key: str = Field(serialization_alias="answerKey")
    explanation: str
    evidence_sentence_ids: list[str] = Field(serialization_alias="evidenceSentenceIds")
    why_correct_ko: str = Field(serialization_alias="whyCorrectKo")
    why_wrong_ko_by_option: dict[str, str] = Field(serialization_alias="whyWrongKoByOption")
    vocab_notes_ko: str | None = Field(default=None, serialization_alias="vocabNotesKo")
    structure_notes_ko: str | None = Field(default=None, serialization_alias="structureNotesKo")


class PublishedContentDetailResponse(BaseModel):
    unit_id: UUID = Field(serialization_alias="unitId")
    revision_id: UUID = Field(serialization_alias="revisionId")
    track: Track
    skill: Skill
    type_tag: ContentTypeTag = Field(serialization_alias="typeTag")
    difficulty: int
    published_at: datetime = Field(serialization_alias="publishedAt")
    content_source_policy: ContentSourcePolicy = Field(serialization_alias="contentSourcePolicy")
    body_text: str | None = Field(default=None, serialization_alias="bodyText")
    transcript_text: str | None = Field(default=None, serialization_alias="transcriptText")
    tts_plan: dict[str, Any] | None = Field(default=None, serialization_alias="ttsPlan")
    asset: PublishedContentAssetPayload | None = None
    question: PublishedContentQuestionPayload
