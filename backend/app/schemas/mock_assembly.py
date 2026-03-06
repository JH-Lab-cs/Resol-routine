from __future__ import annotations

import re
from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import (
    MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK,
    MOCK_ASSEMBLY_SEED_MAX_LENGTH,
)
from app.models.enums import AIGenerationJobStatus, MockExamType, Track

_WEEK_KEY_PATTERN = re.compile(r"^\d{4}W(0[1-9]|[1-4]\d|5[0-3])$")
_MONTH_KEY_PATTERN = re.compile(r"^\d{4}(0[1-9]|1[0-2])$")


class MockAssemblyFailureCode(StrEnum):
    INSUFFICIENT_PUBLISHED_CONTENT = "INSUFFICIENT_PUBLISHED_CONTENT"
    INSUFFICIENT_LISTENING_CONTENT = "INSUFFICIENT_LISTENING_CONTENT"
    INSUFFICIENT_READING_CONTENT = "INSUFFICIENT_READING_CONTENT"
    INSUFFICIENT_TYPE_DIVERSITY = "INSUFFICIENT_TYPE_DIVERSITY"
    ASSEMBLY_CONSTRAINT_FAILED = "ASSEMBLY_CONSTRAINT_FAILED"
    REVISION_PERSIST_FAILED = "REVISION_PERSIST_FAILED"
    ASSEMBLY_ALREADY_EXISTS = "ASSEMBLY_ALREADY_EXISTS"
    ASSEMBLY_TRACE_PERSIST_FAILED = "ASSEMBLY_TRACE_PERSIST_FAILED"


class MockAssemblyDifficultyProfile(BaseModel):
    model_config = ConfigDict(extra="forbid")

    min_average: float = Field(alias="minAverage")
    max_average: float = Field(alias="maxAverage")

    @field_validator("min_average", "max_average")
    @classmethod
    def validate_range_bounds(cls, value: float) -> float:
        if value < 1.0 or value > 5.0:
            raise ValueError("difficulty_profile_out_of_range")
        return value

    @model_validator(mode="after")
    def validate_order(self) -> MockAssemblyDifficultyProfile:
        if self.min_average > self.max_average:
            raise ValueError("difficulty_profile_invalid_range")
        return self


class MockAssemblyJobCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    exam_type: MockExamType = Field(alias="examType")
    track: Track
    period_key: str = Field(alias="periodKey")
    seed_override: str | None = Field(default=None, alias="seedOverride")
    dry_run: bool = Field(default=False, alias="dryRun")
    force_rebuild: bool = Field(default=False, alias="forceRebuild")
    target_difficulty_profile: MockAssemblyDifficultyProfile | None = Field(
        default=None,
        alias="targetDifficultyProfile",
    )

    @field_validator("seed_override")
    @classmethod
    def validate_seed_override(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = validate_user_input_text(value, field_name="seed_override")
        if len(normalized) > MOCK_ASSEMBLY_SEED_MAX_LENGTH:
            raise ValueError("seed_override_too_long")
        return normalized

    @model_validator(mode="after")
    def validate_period_key(self) -> MockAssemblyJobCreateRequest:
        normalized = validate_user_input_text(self.period_key, field_name="period_key")
        if self.exam_type == MockExamType.WEEKLY:
            if _WEEK_KEY_PATTERN.fullmatch(normalized) is None:
                raise ValueError("invalid_weekly_period_key")
        elif _MONTH_KEY_PATTERN.fullmatch(normalized) is None:
            raise ValueError("invalid_monthly_period_key")
        self.period_key = normalized
        return self


class MockAssemblyJobResponse(BaseModel):
    id: UUID = Field(serialization_alias="jobId")
    status: AIGenerationJobStatus
    exam_type: MockExamType = Field(serialization_alias="examType")
    track: Track
    period_key: str = Field(serialization_alias="periodKey")
    seed: str
    dry_run: bool = Field(serialization_alias="dryRun")
    force_rebuild: bool = Field(serialization_alias="forceRebuild")
    target_difficulty_profile_json: dict[str, float] = Field(
        serialization_alias="targetDifficultyProfile"
    )
    candidate_pool_counts_json: dict[str, object] = Field(serialization_alias="candidatePoolCounts")
    summary_json: dict[str, object] = Field(serialization_alias="summary")
    constraint_summary_json: dict[str, object] = Field(serialization_alias="constraintSummary")
    warnings_json: list[str] = Field(serialization_alias="warnings")
    failure_code: str | None = Field(serialization_alias="failureCode")
    failure_message: str | None = Field(serialization_alias="failureMessage")
    produced_mock_exam_id: UUID | None = Field(serialization_alias="mockExamId")
    produced_mock_exam_revision_id: UUID | None = Field(serialization_alias="mockExamRevisionId")
    assembly_trace_json: dict[str, object] = Field(serialization_alias="assemblyTrace")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")
    completed_at: datetime | None = Field(serialization_alias="completedAt")


def default_difficulty_profile_for_track(track: Track) -> dict[str, float]:
    minimum, maximum = MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value]
    return {
        "minAverage": minimum,
        "maxAverage": maximum,
    }
