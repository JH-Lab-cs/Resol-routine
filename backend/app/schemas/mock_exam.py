from __future__ import annotations

from datetime import datetime
import re
import unicodedata
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.input_validation import INVALID_HIDDEN_UNICODE_DETAIL, validate_user_input_text
from app.core.policies import (
    MOCK_EXAM_EXTERNAL_ID_MAX_LENGTH,
    MOCK_EXAM_INSTRUCTIONS_MAX_LENGTH,
    MOCK_EXAM_LIST_DEFAULT_PAGE_SIZE,
    MOCK_EXAM_LIST_MAX_PAGE_SIZE,
    MOCK_EXAM_SLUG_MAX_LENGTH,
    MOCK_EXAM_TITLE_MAX_LENGTH,
    MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import MockExamType, Skill, Track

_WEEK_KEY_PATTERN = re.compile(r"^\d{4}W(0[1-9]|[1-4]\d|5[0-3])$")
_PERIOD_KEY_PATTERN = re.compile(r"^\d{4}(0[1-9]|1[0-2])$")


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


def _validate_multiline_text(value: str, *, field_name: str, max_length: int) -> str:
    normalized = value.strip()
    if not normalized:
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


def _validate_period_key_for_exam_type(*, exam_type: MockExamType, period_key: str) -> str:
    normalized = validate_user_input_text(period_key, field_name="period_key")
    if exam_type == MockExamType.WEEKLY:
        if _WEEK_KEY_PATTERN.fullmatch(normalized) is None:
            raise ValueError("invalid_weekly_period_key")
        return normalized
    if _PERIOD_KEY_PATTERN.fullmatch(normalized) is None:
        raise ValueError("invalid_monthly_period_key")
    return normalized


class MockExamCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_type: MockExamType = Field(alias="examType")
    track: Track
    period_key: str = Field(alias="periodKey")
    external_id: str | None = Field(default=None, alias="externalId")
    slug: str | None = None

    @field_validator("external_id")
    @classmethod
    def validate_external_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name="external_id",
            max_length=MOCK_EXAM_EXTERNAL_ID_MAX_LENGTH,
        )

    @field_validator("slug")
    @classmethod
    def validate_slug(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name="slug",
            max_length=MOCK_EXAM_SLUG_MAX_LENGTH,
        )

    @model_validator(mode="after")
    def validate_period_key(self) -> MockExamCreateRequest:
        self.period_key = _validate_period_key_for_exam_type(
            exam_type=self.exam_type,
            period_key=self.period_key,
        )
        return self


class MockExamRevisionItemCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    order_index: int = Field(alias="orderIndex")
    content_unit_revision_id: UUID = Field(alias="contentUnitRevisionId")
    content_question_id: UUID = Field(alias="contentQuestionId")

    @field_validator("order_index")
    @classmethod
    def validate_order_index(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_order_index")
        return value


class MockExamRevisionCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    title: str
    instructions: str | None = None
    generator_version: str = Field(alias="generatorVersion")
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")
    items: list[MockExamRevisionItemCreateRequest]

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return _validate_multiline_text(
            value,
            field_name="title",
            max_length=MOCK_EXAM_TITLE_MAX_LENGTH,
        )

    @field_validator("instructions")
    @classmethod
    def validate_instructions(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_multiline_text(
            value,
            field_name="instructions",
            max_length=MOCK_EXAM_INSTRUCTIONS_MAX_LENGTH,
        )

    @field_validator("generator_version")
    @classmethod
    def validate_generator_version(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="generator_version",
            max_length=MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
        )

    @field_validator("items")
    @classmethod
    def validate_items_not_empty(
        cls,
        value: list[MockExamRevisionItemCreateRequest],
    ) -> list[MockExamRevisionItemCreateRequest]:
        if not value:
            raise ValueError("items_must_not_be_empty")
        return value

    @model_validator(mode="after")
    def validate_duplicate_items(self) -> MockExamRevisionCreateRequest:
        order_indexes = [item.order_index for item in self.items]
        if len(order_indexes) != len(set(order_indexes)):
            raise ValueError("duplicate_order_index")

        content_question_ids = [item.content_question_id for item in self.items]
        if len(content_question_ids) != len(set(content_question_ids)):
            raise ValueError("duplicate_content_question_id")
        return self


class MockExamRevisionValidateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    validator_version: str = Field(alias="validatorVersion")

    @field_validator("validator_version")
    @classmethod
    def validate_validator_version(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="validator_version",
            max_length=MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
        )


class MockExamRevisionReviewRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    reviewer_identity: str = Field(alias="reviewerIdentity")

    @field_validator("reviewer_identity")
    @classmethod
    def validate_reviewer_identity(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="reviewer_identity",
            max_length=MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
        )


class MockExamPublishRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    revision_id: UUID = Field(alias="revisionId")


class MockExamRollbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    target_revision_id: UUID = Field(alias="targetRevisionId")


class MockExamListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = MOCK_EXAM_LIST_DEFAULT_PAGE_SIZE
    exam_type: MockExamType | None = None
    track: Track | None = None
    period_key: str | None = None
    lifecycle_status: ContentLifecycleStatus | None = None
    published_only: bool = False

    @field_validator("page")
    @classmethod
    def validate_page(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_page")
        return value

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, value: int) -> int:
        if value <= 0 or value > MOCK_EXAM_LIST_MAX_PAGE_SIZE:
            raise ValueError("invalid_page_size")
        return value

    @field_validator("period_key")
    @classmethod
    def validate_period_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = validate_user_input_text(value, field_name="period_key")
        if _WEEK_KEY_PATTERN.fullmatch(normalized) is not None:
            return normalized
        if _PERIOD_KEY_PATTERN.fullmatch(normalized) is not None:
            return normalized
        raise ValueError("invalid_period_key")


class MockExamRevisionItemResponse(BaseModel):
    id: UUID
    order_index: int = Field(serialization_alias="orderIndex")
    content_unit_revision_id: UUID = Field(serialization_alias="contentUnitRevisionId")
    content_question_id: UUID = Field(serialization_alias="contentQuestionId")
    question_code_snapshot: str = Field(serialization_alias="questionCodeSnapshot")
    skill_snapshot: Skill = Field(serialization_alias="skillSnapshot")
    created_at: datetime = Field(serialization_alias="createdAt")


class MockExamRevisionResponse(BaseModel):
    id: UUID
    mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    revision_no: int = Field(serialization_alias="revisionNo")
    title: str
    instructions: str | None
    generator_version: str = Field(serialization_alias="generatorVersion")
    validator_version: str | None = Field(serialization_alias="validatorVersion")
    validated_at: datetime | None = Field(serialization_alias="validatedAt")
    reviewer_identity: str | None = Field(serialization_alias="reviewerIdentity")
    reviewed_at: datetime | None = Field(serialization_alias="reviewedAt")
    metadata_json: dict[str, object] = Field(serialization_alias="metadata")
    lifecycle_status: ContentLifecycleStatus = Field(serialization_alias="lifecycleStatus")
    published_at: datetime | None = Field(serialization_alias="publishedAt")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")
    items: list[MockExamRevisionItemResponse]


class MockExamResponse(BaseModel):
    id: UUID
    exam_type: MockExamType = Field(serialization_alias="examType")
    track: Track
    period_key: str = Field(serialization_alias="periodKey")
    external_id: str | None = Field(serialization_alias="externalId")
    slug: str | None
    lifecycle_status: ContentLifecycleStatus = Field(serialization_alias="lifecycleStatus")
    published_revision_id: UUID | None = Field(serialization_alias="publishedRevisionId")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class MockExamListResponse(BaseModel):
    items: list[MockExamResponse]
    total: int
    page: int
    page_size: int = Field(serialization_alias="pageSize")


class MockExamRevisionListResponse(BaseModel):
    mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    items: list[MockExamRevisionResponse]


class MockExamPublishResponse(BaseModel):
    mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    published_revision_id: UUID = Field(serialization_alias="publishedRevisionId")
    lifecycle_status: ContentLifecycleStatus = Field(serialization_alias="lifecycleStatus")
    generator_version: str = Field(serialization_alias="generatorVersion")
    validator_version: str = Field(serialization_alias="validatorVersion")
    validated_at: datetime = Field(serialization_alias="validatedAt")
    reviewer_identity: str = Field(serialization_alias="reviewerIdentity")
    reviewed_at: datetime = Field(serialization_alias="reviewedAt")
    published_at: datetime = Field(serialization_alias="publishedAt")


class MockExamRollbackResponse(BaseModel):
    mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    previous_published_revision_id: UUID = Field(serialization_alias="previousPublishedRevisionId")
    rolled_back_to_revision_id: UUID = Field(serialization_alias="rolledBackToRevisionId")
    lifecycle_status: ContentLifecycleStatus = Field(serialization_alias="lifecycleStatus")
    published_at: datetime = Field(serialization_alias="publishedAt")


class StudentCurrentMockExamResponse(BaseModel):
    mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    mock_exam_revision_id: UUID = Field(serialization_alias="mockExamRevisionId")
    exam_type: MockExamType = Field(serialization_alias="examType")
    track: Track
    period_key: str = Field(serialization_alias="periodKey")
    title: str
    instructions: str | None


class MockExamSessionStartResponse(BaseModel):
    mock_session_id: int = Field(serialization_alias="mockSessionId")
    mock_exam_revision_id: UUID = Field(serialization_alias="mockExamRevisionId")
    exam_type: MockExamType = Field(serialization_alias="examType")
    track: Track
    period_key: str = Field(serialization_alias="periodKey")
    started_at: datetime = Field(serialization_alias="startedAt")


class MockExamSessionItemResponse(BaseModel):
    order_index: int = Field(serialization_alias="orderIndex")
    question_id: str = Field(serialization_alias="questionId")
    skill: Skill
    stem: str
    options: list[str]
    body_text: str | None = Field(serialization_alias="bodyText")
    transcript_text: str | None = Field(serialization_alias="transcriptText")
    asset_download_url: str | None = Field(serialization_alias="assetDownloadUrl")
    asset_download_expires_at: datetime | None = Field(serialization_alias="assetDownloadExpiresAt")


class MockExamSessionDetailResponse(BaseModel):
    mock_session_id: int = Field(serialization_alias="mockSessionId")
    mock_exam_revision_id: UUID = Field(serialization_alias="mockExamRevisionId")
    exam_type: MockExamType = Field(serialization_alias="examType")
    track: Track
    period_key: str = Field(serialization_alias="periodKey")
    title: str
    instructions: str | None
    items: list[MockExamSessionItemResponse]
