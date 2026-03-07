from __future__ import annotations

import unicodedata
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.input_validation import INVALID_HIDDEN_UNICODE_DETAIL, validate_user_input_text
from app.core.policies import (
    CONTENT_IDENTIFIER_MAX_LENGTH,
    CONTENT_LIST_DEFAULT_PAGE_SIZE,
    CONTENT_LIST_MAX_PAGE_SIZE,
    CONTENT_OBJECT_KEY_MAX_LENGTH,
    CONTENT_QUESTION_CODE_MAX_LENGTH,
    CONTENT_REVISION_CODE_MAX_LENGTH,
    CONTENT_TEXT_MAX_LENGTH,
    CONTENT_TITLE_MAX_LENGTH,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import ContentTypeTag, Skill, Track


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


def _validate_multiline_text(
    value: str,
    *,
    field_name: str,
    max_length: int,
    allow_empty: bool = False,
) -> str:
    if not isinstance(value, str):
        raise TypeError(f"{field_name} must be a string.")
    normalized = value.strip()
    if not normalized and not allow_empty:
        raise ValueError(f"{field_name}_must_not_be_empty")
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    for char in normalized:
        category = unicodedata.category(char)
        if category == "Cf":
            raise ValueError(INVALID_HIDDEN_UNICODE_DETAIL)
        if category == "Cc" and char not in {"\n", "\r", "\t"}:
            raise ValueError(INVALID_HIDDEN_UNICODE_DETAIL)
    return normalized


class AssetUploadUrlRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    mime_type: str
    size_bytes: int
    sha256_hex: str

    @field_validator("request_id")
    @classmethod
    def validate_request_id(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="request_id",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )

    @field_validator("mime_type")
    @classmethod
    def validate_mime_type(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="mime_type").lower()
        if len(normalized) > 255:
            raise ValueError("mime_type_too_long")
        return normalized

    @field_validator("size_bytes")
    @classmethod
    def validate_size_bytes(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_size_bytes")
        return value

    @field_validator("sha256_hex")
    @classmethod
    def validate_sha256_hex(cls, value: str) -> str:
        normalized = _validate_identifier(
            value.lower(),
            field_name="sha256_hex",
            max_length=64,
        )
        if len(normalized) != 64 or any(char not in "0123456789abcdef" for char in normalized):
            raise ValueError("invalid_sha256_hex")
        return normalized


class AssetUploadUrlResponse(BaseModel):
    object_key: str
    upload_url: str
    expires_in_seconds: int
    expires_at: datetime


class AssetFinalizeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    object_key: str
    mime_type: str
    size_bytes: int
    sha256_hex: str
    etag: str | None = None
    bucket: str | None = None

    @field_validator("object_key")
    @classmethod
    def validate_object_key(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="object_key",
            max_length=CONTENT_OBJECT_KEY_MAX_LENGTH,
        )

    @field_validator("mime_type")
    @classmethod
    def validate_mime_type(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="mime_type").lower()
        if len(normalized) > 255:
            raise ValueError("mime_type_too_long")
        return normalized

    @field_validator("size_bytes")
    @classmethod
    def validate_size_bytes(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_size_bytes")
        return value

    @field_validator("sha256_hex")
    @classmethod
    def validate_sha256_hex(cls, value: str) -> str:
        normalized = _validate_identifier(
            value.lower(),
            field_name="sha256_hex",
            max_length=64,
        )
        if len(normalized) != 64 or any(char not in "0123456789abcdef" for char in normalized):
            raise ValueError("invalid_sha256_hex")
        return normalized

    @field_validator("etag", "bucket")
    @classmethod
    def validate_optional_identifier(cls, value: str | None, info) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name=info.field_name,
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentAssetResponse(BaseModel):
    id: UUID
    object_key: str
    mime_type: str
    size_bytes: int
    sha256_hex: str
    etag: str | None
    bucket: str
    created_at: datetime
    updated_at: datetime


class ContentAssetReferenceResponse(BaseModel):
    id: UUID
    object_key: str
    mime_type: str
    size_bytes: int
    bucket: str


class AssetDownloadUrlResponse(BaseModel):
    asset_id: UUID
    object_key: str
    download_url: str
    expires_in_seconds: int
    expires_at: datetime


class ContentUnitCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    external_id: str
    slug: str | None = None
    skill: Skill
    track: Track

    @field_validator("external_id")
    @classmethod
    def validate_external_id(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="external_id",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )

    @field_validator("slug")
    @classmethod
    def validate_slug(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name="slug",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentQuestionCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    question_code: str
    order_index: int
    stem: str
    choice_a: str
    choice_b: str
    choice_c: str
    choice_d: str
    choice_e: str
    correct_answer: str
    explanation: str | None = None
    metadata_json: dict[str, object] = Field(default_factory=dict)

    @field_validator("question_code")
    @classmethod
    def validate_question_code(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="question_code",
            max_length=CONTENT_QUESTION_CODE_MAX_LENGTH,
        )

    @field_validator("order_index")
    @classmethod
    def validate_order_index(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_order_index")
        return value

    @field_validator(
        "stem",
        "choice_a",
        "choice_b",
        "choice_c",
        "choice_d",
        "choice_e",
    )
    @classmethod
    def validate_required_text_fields(cls, value: str, info) -> str:
        return _validate_multiline_text(
            value,
            field_name=info.field_name,
            max_length=CONTENT_TEXT_MAX_LENGTH,
        )

    @field_validator("explanation")
    @classmethod
    def validate_optional_explanation(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_multiline_text(
            value,
            field_name="explanation",
            max_length=CONTENT_TEXT_MAX_LENGTH,
        )

    @field_validator("correct_answer")
    @classmethod
    def validate_correct_answer(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="correct_answer").upper()
        if normalized not in {"A", "B", "C", "D", "E"}:
            raise ValueError("invalid_correct_answer")
        return normalized


class ContentUnitRevisionCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    revision_code: str
    generator_version: str
    title: str | None = None
    body_text: str | None = None
    transcript_text: str | None = None
    explanation_text: str | None = None
    asset_id: UUID | None = None
    metadata_json: dict[str, object] = Field(default_factory=dict)
    questions: list[ContentQuestionCreateRequest]

    @field_validator("revision_code")
    @classmethod
    def validate_revision_code(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="revision_code",
            max_length=CONTENT_REVISION_CODE_MAX_LENGTH,
        )

    @field_validator("generator_version")
    @classmethod
    def validate_generator_version(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="generator_version",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )

    @field_validator("title")
    @classmethod
    def validate_optional_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_multiline_text(
            value,
            field_name="title",
            max_length=CONTENT_TITLE_MAX_LENGTH,
        )

    @field_validator("body_text", "transcript_text", "explanation_text")
    @classmethod
    def validate_optional_text(cls, value: str | None, info) -> str | None:
        if value is None:
            return None
        return _validate_multiline_text(
            value,
            field_name=info.field_name,
            max_length=CONTENT_TEXT_MAX_LENGTH,
        )

    @field_validator("questions")
    @classmethod
    def validate_questions_not_empty(
        cls, value: list[ContentQuestionCreateRequest]
    ) -> list[ContentQuestionCreateRequest]:
        if not value:
            raise ValueError("questions_must_not_be_empty")
        return value

    @model_validator(mode="after")
    def validate_question_order_and_codes(self) -> ContentUnitRevisionCreateRequest:
        order_indexes = [question.order_index for question in self.questions]
        question_codes = [question.question_code for question in self.questions]
        if len(set(order_indexes)) != len(order_indexes):
            raise ValueError("duplicate_question_order_index")
        if len(set(question_codes)) != len(question_codes):
            raise ValueError("duplicate_question_code")
        return self


class ContentUnitResponse(BaseModel):
    id: UUID
    external_id: str
    slug: str | None
    skill: Skill
    track: Track
    lifecycle_status: ContentLifecycleStatus
    published_revision_id: UUID | None
    created_at: datetime
    updated_at: datetime


class ContentQuestionResponse(BaseModel):
    id: UUID
    question_code: str
    order_index: int
    stem: str
    choice_a: str
    choice_b: str
    choice_c: str
    choice_d: str
    choice_e: str
    correct_answer: str
    explanation: str | None
    metadata_json: dict[str, object]
    created_at: datetime
    updated_at: datetime


class ContentUnitRevisionResponse(BaseModel):
    # Lifecycle is intentionally minimal: DRAFT / PUBLISHED / ARCHIVED.
    # Validation and review are modeled as trace fields, not enum states.
    id: UUID
    content_unit_id: UUID
    revision_no: int
    revision_code: str
    generator_version: str
    validator_version: str | None
    validated_at: datetime | None
    reviewer_identity: str | None
    reviewed_at: datetime | None
    title: str | None
    body_text: str | None
    transcript_text: str | None
    explanation_text: str | None
    asset_id: UUID | None
    metadata_json: dict[str, object]
    lifecycle_status: ContentLifecycleStatus
    can_publish: bool
    published_at: datetime | None
    created_at: datetime
    updated_at: datetime
    questions: list[ContentQuestionResponse]


class ContentRevisionSummaryResponse(BaseModel):
    id: UUID
    unit_id: UUID
    unit_external_id: str
    skill: Skill
    track: Track
    type_tag: ContentTypeTag | None
    difficulty: int | None
    revision_no: int
    revision_code: str
    generator_version: str
    validator_version: str | None
    validated_at: datetime | None
    reviewer_identity: str | None
    reviewed_at: datetime | None
    lifecycle_status: ContentLifecycleStatus
    can_publish: bool
    published_at: datetime | None
    asset_id: UUID | None
    created_at: datetime
    updated_at: datetime


class ContentRevisionDetailResponse(ContentRevisionSummaryResponse):
    title: str | None
    body_text: str | None
    transcript_text: str | None
    explanation_text: str | None
    metadata_json: dict[str, object]
    asset: ContentAssetReferenceResponse | None
    questions: list[ContentQuestionResponse]


class ContentUnitPublishRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    revision_id: UUID


class ContentRevisionValidateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    validator_version: str

    @field_validator("validator_version")
    @classmethod
    def validate_validator_version(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="validator_version",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentRevisionReviewRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reviewer_identity: str

    @field_validator("reviewer_identity")
    @classmethod
    def validate_reviewer_identity(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="reviewer_identity",
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentRevisionArchiveRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: str


class ContentUnitPublishResponse(BaseModel):
    unit_id: UUID
    published_revision_id: UUID
    lifecycle_status: ContentLifecycleStatus
    generator_version: str
    validator_version: str
    validated_at: datetime
    reviewer_identity: str
    reviewed_at: datetime
    published_at: datetime


class ContentUnitArchiveResponse(BaseModel):
    unit_id: UUID
    lifecycle_status: ContentLifecycleStatus
    archived_at: datetime


class ContentRevisionArchiveResponse(BaseModel):
    revision_id: UUID
    unit_id: UUID
    lifecycle_status: ContentLifecycleStatus
    unit_lifecycle_status: ContentLifecycleStatus
    archived_at: datetime
    metadata_json: dict[str, object]


class ContentUnitRollbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_revision_id: UUID


class ContentUnitRollbackResponse(BaseModel):
    unit_id: UUID
    previous_published_revision_id: UUID
    rolled_back_to_revision_id: UUID
    lifecycle_status: ContentLifecycleStatus
    published_at: datetime


class ContentPaginationParams(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = CONTENT_LIST_DEFAULT_PAGE_SIZE

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


class ContentUnitListResponse(BaseModel):
    items: list[ContentUnitResponse]
    total: int
    page: int
    page_size: int


class ContentUnitListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = CONTENT_LIST_DEFAULT_PAGE_SIZE
    published_only: bool = False
    skill: Skill | None = None
    track: Track | None = None
    lifecycle_status: ContentLifecycleStatus | None = None
    external_id: str | None = None
    slug: str | None = None

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

    @field_validator("external_id", "slug")
    @classmethod
    def validate_optional_identifier_field(cls, value: str | None, info) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name=info.field_name,
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentQuestionListItem(BaseModel):
    unit_id: UUID
    revision_id: UUID
    unit_external_id: str
    skill: Skill
    track: Track
    question: ContentQuestionResponse


class ContentQuestionListResponse(BaseModel):
    items: list[ContentQuestionListItem]
    total: int
    page: int
    page_size: int


class ContentQuestionListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = CONTENT_LIST_DEFAULT_PAGE_SIZE
    published_only: bool = False
    skill: Skill | None = None
    track: Track | None = None
    lifecycle_status: ContentLifecycleStatus | None = None
    unit_id: UUID | None = None
    revision_id: UUID | None = None
    question_code: str | None = None
    unit_external_id: str | None = None

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

    @field_validator("question_code", "unit_external_id")
    @classmethod
    def validate_optional_identifier_field(cls, value: str | None, info) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name=info.field_name,
            max_length=CONTENT_IDENTIFIER_MAX_LENGTH,
        )


class ContentUnitRevisionListResponse(BaseModel):
    unit_id: UUID
    items: list[ContentUnitRevisionResponse]


class ContentRevisionListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: ContentLifecycleStatus = ContentLifecycleStatus.DRAFT
    track: Track | None = None
    skill: Skill | None = None
    type_tag: ContentTypeTag | None = None
    page: int = 1
    page_size: int = CONTENT_LIST_DEFAULT_PAGE_SIZE
    created_after: datetime | None = None
    created_before: datetime | None = None

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


class ContentRevisionListResponse(BaseModel):
    items: list[ContentRevisionSummaryResponse]
    page: int
    page_size: int
    total: int
    has_next: bool
