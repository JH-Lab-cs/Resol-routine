from __future__ import annotations

from datetime import datetime
from enum import Enum
import json
import unicodedata
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.input_validation import INVALID_HIDDEN_UNICODE_DETAIL, validate_user_input_text
from app.core.policies import (
    AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH,
    AI_JOB_LIST_DEFAULT_PAGE_SIZE,
    AI_JOB_LIST_MAX_PAGE_SIZE,
    AI_JOB_METADATA_MAX_LENGTH,
    AI_JOB_NOTES_MAX_LENGTH,
    AI_JOB_REQUEST_ID_MAX_LENGTH,
    AI_MOCK_EXAM_CANDIDATE_LIMIT_MAX,
    AI_MOCK_EXAM_CANDIDATE_LIMIT_DEFAULT,
    MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
)
from app.models.enums import AIGenerationJobStatus, AIGenerationJobType


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


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


class AIMockExamJobCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    request_id: str = Field(alias="requestId")
    mock_exam_id: UUID = Field(alias="mockExamId")
    notes: str | None = None
    generator_version: str = Field(alias="generatorVersion")
    candidate_limit: int = Field(default=AI_MOCK_EXAM_CANDIDATE_LIMIT_DEFAULT, alias="candidateLimit")
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")

    @field_validator("request_id")
    @classmethod
    def validate_request_id(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="request_id",
            max_length=AI_JOB_REQUEST_ID_MAX_LENGTH,
        )

    @field_validator("notes")
    @classmethod
    def validate_notes(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_multiline_text(
            value,
            field_name="notes",
            max_length=AI_JOB_NOTES_MAX_LENGTH,
        )

    @field_validator("generator_version")
    @classmethod
    def validate_generator_version(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="generator_version",
            max_length=MOCK_EXAM_TRACEABILITY_FIELD_MAX_LENGTH,
        )

    @field_validator("candidate_limit")
    @classmethod
    def validate_candidate_limit(cls, value: int) -> int:
        if value <= 0 or value > AI_MOCK_EXAM_CANDIDATE_LIMIT_MAX:
            raise ValueError("invalid_candidate_limit")
        return value

    @field_validator("metadata_json")
    @classmethod
    def validate_metadata_json(cls, value: dict[str, object]) -> dict[str, object]:
        serialized = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        if len(serialized) > AI_JOB_METADATA_MAX_LENGTH:
            raise ValueError("metadata_too_large")
        return value


class AIJobResponse(BaseModel):
    id: UUID
    job_type: AIGenerationJobType = Field(serialization_alias="jobType")
    request_id: str = Field(serialization_alias="requestId")
    status: AIGenerationJobStatus
    target_mock_exam_id: UUID = Field(serialization_alias="mockExamId")
    notes: str | None
    generator_version: str = Field(serialization_alias="generatorVersion")
    candidate_limit: int | None = Field(serialization_alias="candidateLimit")
    metadata_json: dict[str, object] = Field(serialization_alias="metadata")
    provider_name: str | None = Field(serialization_alias="providerName")
    model_name: str | None = Field(serialization_alias="modelName")
    prompt_template_version: str | None = Field(serialization_alias="promptTemplateVersion")
    input_artifact_object_key: str | None = Field(serialization_alias="inputArtifactObjectKey")
    output_artifact_object_key: str | None = Field(serialization_alias="outputArtifactObjectKey")
    candidate_snapshot_object_key: str | None = Field(serialization_alias="candidateSnapshotObjectKey")
    produced_mock_exam_revision_id: UUID | None = Field(serialization_alias="producedMockExamRevisionId")
    attempt_count: int = Field(serialization_alias="attemptCount")
    last_error_code: str | None = Field(serialization_alias="lastErrorCode")
    last_error_message: str | None = Field(serialization_alias="lastErrorMessage")
    queued_at: datetime = Field(serialization_alias="queuedAt")
    started_at: datetime | None = Field(serialization_alias="startedAt")
    completed_at: datetime | None = Field(serialization_alias="completedAt")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class AIJobListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = AI_JOB_LIST_DEFAULT_PAGE_SIZE
    job_type: AIGenerationJobType | None = None
    status: AIGenerationJobStatus | None = None
    mock_exam_id: UUID | None = None

    @field_validator("page")
    @classmethod
    def validate_page(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_page")
        return value

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, value: int) -> int:
        if value <= 0 or value > AI_JOB_LIST_MAX_PAGE_SIZE:
            raise ValueError("invalid_page_size")
        return value


class AIJobListResponse(BaseModel):
    items: list[AIJobResponse]
    total: int
    page: int
    page_size: int = Field(serialization_alias="pageSize")


class AIArtifactKind(str, Enum):
    INPUT = "input"
    OUTPUT = "output"
    CANDIDATE_SNAPSHOT = "candidate-snapshot"


class AIArtifactDownloadUrlResponse(BaseModel):
    job_id: UUID = Field(serialization_alias="jobId")
    artifact_kind: str = Field(serialization_alias="artifactKind")
    object_key: str = Field(serialization_alias="objectKey")
    download_url: str = Field(serialization_alias="downloadUrl")
    expires_in_seconds: int = Field(serialization_alias="expiresInSeconds")
    expires_at: datetime = Field(serialization_alias="expiresAt")

    @field_validator("artifact_kind")
    @classmethod
    def validate_artifact_kind(cls, value: str) -> str:
        normalized = _validate_identifier(value, field_name="artifact_kind", max_length=32)
        if normalized not in {AIArtifactKind.INPUT, AIArtifactKind.OUTPUT, AIArtifactKind.CANDIDATE_SNAPSHOT}:
            raise ValueError("invalid_artifact_kind")
        return normalized

    @field_validator("object_key")
    @classmethod
    def validate_object_key(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="object_key",
            max_length=AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH,
        )
