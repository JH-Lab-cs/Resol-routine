from __future__ import annotations

from datetime import datetime
from enum import Enum
import json
import unicodedata
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.content_type_taxonomy import is_canonical_type_tag_for_skill
from app.core.input_validation import INVALID_HIDDEN_UNICODE_DETAIL, validate_user_input_text
from app.core.policies import (
    AI_CONTENT_CANDIDATE_COUNT_PER_TARGET_DEFAULT,
    AI_CONTENT_CANDIDATE_COUNT_PER_TARGET_MAX,
    AI_CONTENT_DIFFICULTY_MAX,
    AI_CONTENT_DIFFICULTY_MIN,
    AI_CONTENT_IDENTIFIER_MAX_LENGTH,
    AI_CONTENT_MAX_CANDIDATES_PER_JOB,
    AI_CONTENT_TARGET_MATRIX_MAX_ROWS,
    AI_CONTENT_TARGET_ROW_COUNT_MAX,
    AI_JOB_METADATA_MAX_LENGTH,
    AI_JOB_NOTES_MAX_LENGTH,
    AI_JOB_REQUEST_ID_MAX_LENGTH,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import (
    AIContentGenerationCandidateStatus,
    AIGenerationJobStatus,
    ContentSourcePolicy,
    ContentTypeTag,
    Skill,
    Track,
)


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


def _validate_optional_identifier(value: str | None, *, field_name: str, max_length: int) -> str | None:
    if value is None:
        return None
    return _validate_identifier(value, field_name=field_name, max_length=max_length)


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


class AIContentGenerationFailureCode(str, Enum):
    PROVIDER_NOT_CONFIGURED = "PROVIDER_NOT_CONFIGURED"
    PROVIDER_TIMEOUT = "PROVIDER_TIMEOUT"
    PROVIDER_BAD_RESPONSE = "PROVIDER_BAD_RESPONSE"
    OUTPUT_SCHEMA_INVALID = "OUTPUT_SCHEMA_INVALID"
    VALIDATION_FAILED = "VALIDATION_FAILED"
    ARTIFACT_UPLOAD_FAILED = "ARTIFACT_UPLOAD_FAILED"
    DRAFT_PERSIST_FAILED = "DRAFT_PERSIST_FAILED"


class AIContentTargetMatrixRow(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    track: Track
    skill: Skill
    type_tag: ContentTypeTag = Field(alias="typeTag")
    difficulty: int
    count: int

    @field_validator("difficulty")
    @classmethod
    def validate_difficulty(cls, value: int) -> int:
        if value < AI_CONTENT_DIFFICULTY_MIN or value > AI_CONTENT_DIFFICULTY_MAX:
            raise ValueError("invalid_difficulty")
        return value

    @field_validator("count")
    @classmethod
    def validate_count(cls, value: int) -> int:
        if value <= 0 or value > AI_CONTENT_TARGET_ROW_COUNT_MAX:
            raise ValueError("invalid_target_count")
        return value

    @model_validator(mode="after")
    def validate_skill_type_tag_compatibility(self) -> AIContentTargetMatrixRow:
        if not is_canonical_type_tag_for_skill(
            skill=self.skill.value,
            type_tag=self.type_tag.value,
        ):
            raise ValueError("skill_type_tag_mismatch")
        return self


class AIContentGenerationJobCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    request_id: str = Field(alias="requestId")
    target_matrix: list[AIContentTargetMatrixRow] = Field(alias="targetMatrix")
    candidate_count_per_target: int = Field(
        default=AI_CONTENT_CANDIDATE_COUNT_PER_TARGET_DEFAULT,
        alias="candidateCountPerTarget",
    )
    content_unit_id: UUID | None = Field(default=None, alias="contentUnitId")
    provider_override: str | None = Field(default=None, alias="providerOverride")
    dry_run: bool = Field(default=False, alias="dryRun")
    notes: str | None = None
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")

    @field_validator("request_id")
    @classmethod
    def validate_request_id(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="request_id",
            max_length=AI_JOB_REQUEST_ID_MAX_LENGTH,
        )

    @field_validator("provider_override")
    @classmethod
    def validate_provider_override(cls, value: str | None) -> str | None:
        return _validate_optional_identifier(
            value,
            field_name="provider_override",
            max_length=AI_CONTENT_IDENTIFIER_MAX_LENGTH,
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

    @field_validator("target_matrix")
    @classmethod
    def validate_target_matrix(cls, value: list[AIContentTargetMatrixRow]) -> list[AIContentTargetMatrixRow]:
        if not value:
            raise ValueError("target_matrix_must_not_be_empty")
        if len(value) > AI_CONTENT_TARGET_MATRIX_MAX_ROWS:
            raise ValueError("target_matrix_too_large")
        return value

    @field_validator("candidate_count_per_target")
    @classmethod
    def validate_candidate_count_per_target(cls, value: int) -> int:
        if value <= 0 or value > AI_CONTENT_CANDIDATE_COUNT_PER_TARGET_MAX:
            raise ValueError("invalid_candidate_count_per_target")
        return value

    @field_validator("metadata_json")
    @classmethod
    def validate_metadata_size(cls, value: dict[str, object]) -> dict[str, object]:
        serialized = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        if len(serialized) > AI_JOB_METADATA_MAX_LENGTH:
            raise ValueError("metadata_too_large")
        return value

    @model_validator(mode="after")
    def validate_total_candidates(self) -> AIContentGenerationJobCreateRequest:
        requested_count = sum(row.count for row in self.target_matrix) * self.candidate_count_per_target
        if requested_count > AI_CONTENT_MAX_CANDIDATES_PER_JOB:
            raise ValueError("requested_candidates_too_many")
        return self


class AIContentGenerationJobResponse(BaseModel):
    id: UUID
    request_id: str = Field(serialization_alias="requestId")
    status: AIGenerationJobStatus
    content_unit_id: UUID | None = Field(serialization_alias="contentUnitId")
    dry_run: bool = Field(serialization_alias="dryRun")
    target_matrix_json: list[dict[str, object]] = Field(serialization_alias="targetMatrix")
    candidate_count_per_target: int = Field(serialization_alias="candidateCountPerTarget")
    provider_override: str | None = Field(serialization_alias="providerOverride")
    notes: str | None
    metadata_json: dict[str, object] = Field(serialization_alias="metadata")
    provider_name: str | None = Field(serialization_alias="providerName")
    model_name: str | None = Field(serialization_alias="modelName")
    prompt_template_version: str | None = Field(serialization_alias="promptTemplateVersion")
    input_artifact_object_key: str | None = Field(serialization_alias="inputArtifactObjectKey")
    output_artifact_object_key: str | None = Field(serialization_alias="outputArtifactObjectKey")
    candidate_snapshot_object_key: str | None = Field(serialization_alias="candidateSnapshotObjectKey")
    attempt_count: int = Field(serialization_alias="attemptCount")
    last_error_code: str | None = Field(serialization_alias="lastErrorCode")
    last_error_message: str | None = Field(serialization_alias="lastErrorMessage")
    last_error_transient: bool | None = Field(serialization_alias="lastErrorTransient")
    next_retry_at: datetime | None = Field(serialization_alias="nextRetryAt")
    dead_lettered_at: datetime | None = Field(serialization_alias="deadLetteredAt")
    queued_at: datetime = Field(serialization_alias="queuedAt")
    started_at: datetime | None = Field(serialization_alias="startedAt")
    completed_at: datetime | None = Field(serialization_alias="completedAt")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class AIContentGenerationCandidateResponse(BaseModel):
    id: UUID
    job_id: UUID = Field(serialization_alias="jobId")
    candidate_index: int = Field(serialization_alias="candidateIndex")
    status: AIContentGenerationCandidateStatus
    failure_code: str | None = Field(serialization_alias="failureCode")
    failure_message: str | None = Field(serialization_alias="failureMessage")
    track: Track
    skill: Skill
    type_tag: ContentTypeTag = Field(serialization_alias="typeTag")
    difficulty: int
    source_policy: ContentSourcePolicy = Field(serialization_alias="sourcePolicy")
    title: str | None
    passage_text: str | None = Field(serialization_alias="passage")
    transcript_text: str | None = Field(serialization_alias="transcript")
    turns_json: list[dict[str, str]] = Field(serialization_alias="turns")
    sentences_json: list[dict[str, str]] = Field(serialization_alias="sentences")
    tts_plan_json: dict[str, object] = Field(serialization_alias="ttsPlan")
    question_stem: str = Field(serialization_alias="stem")
    options: dict[str, str]
    answer_key: str = Field(serialization_alias="answerKey")
    explanation_text: str = Field(serialization_alias="explanation")
    evidence_sentence_ids_json: list[str] = Field(serialization_alias="evidenceSentenceIds")
    why_correct_ko: str = Field(serialization_alias="whyCorrectKo")
    why_wrong_ko_by_option_json: dict[str, str] = Field(serialization_alias="whyWrongKoByOption")
    vocab_notes_ko: str | None = Field(serialization_alias="vocabNotesKo")
    structure_notes_ko: str | None = Field(serialization_alias="structureNotesKo")
    review_flags_json: list[str] = Field(serialization_alias="reviewFlags")
    artifact_prompt_key: str | None = Field(serialization_alias="artifactPromptKey")
    artifact_response_key: str | None = Field(serialization_alias="artifactResponseKey")
    artifact_candidate_json_key: str | None = Field(serialization_alias="artifactCandidateJsonKey")
    artifact_validation_report_key: str | None = Field(serialization_alias="artifactValidationReportKey")
    materialized_content_unit_id: UUID | None = Field(serialization_alias="materializedContentUnitId")
    materialized_revision_id: UUID | None = Field(serialization_alias="materializedRevisionId")
    materialized_at: datetime | None = Field(serialization_alias="materializedAt")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class AIContentGenerationCandidateListResponse(BaseModel):
    job_id: UUID = Field(serialization_alias="jobId")
    items: list[AIContentGenerationCandidateResponse]


class AIContentMaterializeDraftResponse(BaseModel):
    candidate_id: UUID = Field(serialization_alias="candidateId")
    content_unit_id: UUID = Field(serialization_alias="contentUnitId")
    content_revision_id: UUID = Field(serialization_alias="contentRevisionId")
    revision_lifecycle_status: ContentLifecycleStatus = Field(serialization_alias="revisionLifecycleStatus")
    materialized_at: datetime = Field(serialization_alias="materializedAt")
