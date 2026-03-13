from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import (
    SYNC_DEVICE_ID_MAX_LENGTH,
    SYNC_EVENT_SCHEMA_VERSION,
    SYNC_EVENT_STRING_MAX_LENGTH,
    SYNC_EVENT_TYPES,
    SYNC_IDEMPOTENCY_KEY_MAX_LENGTH,
    WRONG_REASON_TAG_DB_VALUES,
)


class SyncItemStatus(StrEnum):
    ACCEPTED = "accepted"
    DUPLICATE = "duplicate"
    INVALID = "invalid"


class SyncEventsBatchEnvelope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    events: list[Any]


class SyncEventCommon(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_type: str
    schema_version: int
    device_id: str
    occurred_at_client: datetime
    idempotency_key: str
    payload: dict[str, Any]

    @field_validator("event_type")
    @classmethod
    def validate_event_type(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="event_type")
        if len(normalized) > SYNC_EVENT_STRING_MAX_LENGTH:
            raise ValueError("invalid_event_type")
        if normalized not in SYNC_EVENT_TYPES:
            raise ValueError("invalid_event_type")
        return normalized

    @field_validator("schema_version")
    @classmethod
    def validate_schema_version(cls, value: int) -> int:
        if value != SYNC_EVENT_SCHEMA_VERSION:
            raise ValueError("invalid_schema_version")
        return value

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="device_id")
        if len(normalized) > SYNC_DEVICE_ID_MAX_LENGTH:
            raise ValueError("invalid_device_id")
        return normalized

    @field_validator("idempotency_key")
    @classmethod
    def validate_idempotency_key(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="idempotency_key")
        if len(normalized) > SYNC_IDEMPOTENCY_KEY_MAX_LENGTH:
            raise ValueError("invalid_idempotency_key")
        return normalized

    @field_validator("occurred_at_client")
    @classmethod
    def validate_occurred_at_client(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("invalid_occurred_at_client")
        return value

    @field_validator("payload")
    @classmethod
    def validate_payload(cls, value: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise ValueError("invalid_payload")
        return value


class TodayAttemptSavedPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    session_id: int = Field(alias="sessionId")
    question_id: str = Field(alias="questionId")
    selected_answer: str = Field(alias="selectedAnswer")
    is_correct: bool = Field(alias="isCorrect")
    wrong_reason_tag: str | None = Field(default=None, alias="wrongReasonTag")

    @field_validator("session_id")
    @classmethod
    def validate_session_id(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_session_id")
        return value

    @field_validator("question_id")
    @classmethod
    def validate_question_id(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="question_id")

    @field_validator("selected_answer")
    @classmethod
    def validate_selected_answer(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="selected_answer")

    @field_validator("wrong_reason_tag")
    @classmethod
    def validate_wrong_reason_tag(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = validate_user_input_text(value, field_name="wrong_reason_tag")
        if normalized not in WRONG_REASON_TAG_DB_VALUES:
            raise ValueError("invalid_wrong_reason_tag")
        return normalized

    @model_validator(mode="after")
    def validate_correctness_and_tag(self) -> TodayAttemptSavedPayload:
        if not self.is_correct and self.wrong_reason_tag is None:
            raise ValueError("wrong_reason_tag_required")
        if self.is_correct and self.wrong_reason_tag is not None:
            raise ValueError("wrong_reason_tag_must_be_null")
        return self


class MockExamAttemptSavedPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    mock_session_id: int = Field(alias="mockSessionId")
    question_id: str = Field(alias="questionId")
    selected_answer: str = Field(alias="selectedAnswer")
    is_correct: bool = Field(alias="isCorrect")
    wrong_reason_tag: str | None = Field(default=None, alias="wrongReasonTag")

    @field_validator("mock_session_id")
    @classmethod
    def validate_mock_session_id(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_mock_session_id")
        return value

    @field_validator("question_id")
    @classmethod
    def validate_question_id(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="question_id")

    @field_validator("selected_answer")
    @classmethod
    def validate_selected_answer(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="selected_answer")

    @field_validator("wrong_reason_tag")
    @classmethod
    def validate_wrong_reason_tag(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = validate_user_input_text(value, field_name="wrong_reason_tag")
        if normalized not in WRONG_REASON_TAG_DB_VALUES:
            raise ValueError("invalid_wrong_reason_tag")
        return normalized

    @model_validator(mode="after")
    def validate_correctness_and_tag(self) -> MockExamAttemptSavedPayload:
        if not self.is_correct and self.wrong_reason_tag is None:
            raise ValueError("wrong_reason_tag_required")
        if self.is_correct and self.wrong_reason_tag is not None:
            raise ValueError("wrong_reason_tag_must_be_null")
        return self


class VocabQuizCompletedPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    day_key: str = Field(alias="dayKey")
    track: str
    total_count: int = Field(alias="totalCount")
    correct_count: int = Field(alias="correctCount")
    wrong_vocab_ids: list[str] = Field(alias="wrongVocabIds")

    @field_validator("day_key")
    @classmethod
    def validate_day_key(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="day_key")
        if len(normalized) != 8 or not normalized.isdigit():
            raise ValueError("invalid_day_key")
        return normalized

    @field_validator("track")
    @classmethod
    def validate_track(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="track")
        if normalized not in {"M3", "H1", "H2", "H3"}:
            raise ValueError("invalid_track")
        return normalized

    @field_validator("total_count", "correct_count")
    @classmethod
    def validate_counts(cls, value: int) -> int:
        if value < 0 or value > 20:
            raise ValueError("invalid_count")
        return value

    @field_validator("wrong_vocab_ids")
    @classmethod
    def validate_wrong_vocab_ids(cls, value: list[str]) -> list[str]:
        normalized = [
            validate_user_input_text(item, field_name="wrong_vocab_ids")
            for item in value
        ]
        if len(set(normalized)) != len(normalized):
            raise ValueError("duplicate_wrong_vocab_ids")
        return normalized

    @model_validator(mode="after")
    def validate_completion_shape(self) -> VocabQuizCompletedPayload:
        if self.correct_count > self.total_count:
            raise ValueError("invalid_correct_count")
        if len(self.wrong_vocab_ids) != self.total_count - self.correct_count:
            raise ValueError("wrong_vocab_ids_length_mismatch")
        return self


class MockExamCompletedPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    mock_session_id: int = Field(alias="mockSessionId")
    exam_type: str = Field(alias="examType")
    period_key: str = Field(alias="periodKey")
    track: str
    planned_items: int = Field(alias="plannedItems")
    completed_items: int = Field(alias="completedItems")
    listening_correct_count: int = Field(alias="listeningCorrectCount")
    reading_correct_count: int = Field(alias="readingCorrectCount")
    wrong_count: int = Field(alias="wrongCount")

    @field_validator("mock_session_id")
    @classmethod
    def validate_mock_session_id(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_mock_session_id")
        return value

    @field_validator("exam_type")
    @classmethod
    def validate_exam_type(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="exam_type")
        if normalized not in {"WEEKLY", "MONTHLY"}:
            raise ValueError("invalid_exam_type")
        return normalized

    @field_validator("period_key")
    @classmethod
    def validate_period_key(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="period_key")
        if len(normalized) > 16:
            raise ValueError("invalid_period_key")
        return normalized

    @field_validator("track")
    @classmethod
    def validate_track(cls, value: str) -> str:
        normalized = validate_user_input_text(value, field_name="track")
        if normalized not in {"M3", "H1", "H2", "H3"}:
            raise ValueError("invalid_track")
        return normalized

    @field_validator(
        "planned_items",
        "completed_items",
        "listening_correct_count",
        "reading_correct_count",
        "wrong_count",
    )
    @classmethod
    def validate_non_negative_counts(cls, value: int) -> int:
        if value < 0:
            raise ValueError("invalid_count")
        return value

    @model_validator(mode="after")
    def validate_score_shape(self) -> MockExamCompletedPayload:
        if self.completed_items > self.planned_items:
            raise ValueError("completed_items_exceeds_planned")
        total_scored = (
            self.listening_correct_count
            + self.reading_correct_count
            + self.wrong_count
        )
        if total_scored != self.completed_items:
            raise ValueError("completed_items_score_mismatch")
        return self


class SyncEventItemResult(BaseModel):
    index: int
    idempotency_key: str | None
    status: SyncItemStatus
    detail_code: str | None = None


class SyncBatchSummary(BaseModel):
    accepted: int
    duplicate: int
    invalid: int
    total: int


class SyncEventsBatchResponse(BaseModel):
    results: list[SyncEventItemResult]
    summary: SyncBatchSummary
