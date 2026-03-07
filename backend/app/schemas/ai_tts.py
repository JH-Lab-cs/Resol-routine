from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import (
    AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH,
    TTS_DEFAULT_SPEED,
    TTS_MODEL_MAX_LENGTH,
    TTS_PROVIDER_MAX_LENGTH,
    TTS_SPEED_MAX,
    TTS_SPEED_MIN,
    TTS_VOICE_MAX_LENGTH,
)
from app.models.enums import Track
from app.models.tts_enums import TTSGenerationJobStatus


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


class TTSGenerationJobCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    revision_id: UUID = Field(alias="revisionId")
    provider: str
    model: str
    voice: str
    speed: float = TTS_DEFAULT_SPEED
    force_regen: bool = Field(default=False, alias="forceRegen")

    @field_validator("provider")
    @classmethod
    def validate_provider(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="provider",
            max_length=TTS_PROVIDER_MAX_LENGTH,
        )

    @field_validator("model")
    @classmethod
    def validate_model(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="model",
            max_length=TTS_MODEL_MAX_LENGTH,
        )

    @field_validator("voice")
    @classmethod
    def validate_voice(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="voice",
            max_length=TTS_VOICE_MAX_LENGTH,
        )

    @field_validator("speed")
    @classmethod
    def validate_speed(cls, value: float) -> float:
        if value < TTS_SPEED_MIN or value > TTS_SPEED_MAX:
            raise ValueError("invalid_speed")
        return value


class TTSGenerationJobRetryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")


class TTSGenerationEnsureAudioRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    provider: str
    model: str
    voice: str
    speed: float = TTS_DEFAULT_SPEED
    force_regen: bool = Field(default=False, alias="forceRegen")

    @field_validator("provider")
    @classmethod
    def validate_provider(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="provider",
            max_length=TTS_PROVIDER_MAX_LENGTH,
        )

    @field_validator("model")
    @classmethod
    def validate_model(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="model",
            max_length=TTS_MODEL_MAX_LENGTH,
        )

    @field_validator("voice")
    @classmethod
    def validate_voice(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="voice",
            max_length=TTS_VOICE_MAX_LENGTH,
        )

    @field_validator("speed")
    @classmethod
    def validate_speed(cls, value: float) -> float:
        if value < TTS_SPEED_MIN or value > TTS_SPEED_MAX:
            raise ValueError("invalid_speed")
        return value


class TTSGenerationJobResponse(BaseModel):
    id: UUID = Field(serialization_alias="jobId")
    revision_id: UUID = Field(serialization_alias="revisionId")
    track: Track
    provider: str
    model_name: str = Field(serialization_alias="model")
    voice: str
    speed: float
    force_regen: bool = Field(serialization_alias="forceRegen")
    input_text_sha256: str = Field(serialization_alias="inputTextSha256")
    input_text_len: int = Field(serialization_alias="inputTextLen")
    status: TTSGenerationJobStatus
    attempts: int
    error_code: str | None = Field(serialization_alias="errorCode")
    error_message: str | None = Field(serialization_alias="errorMessage")
    artifact_request_key: str | None = Field(serialization_alias="artifactRequestKey")
    artifact_response_key: str | None = Field(serialization_alias="artifactResponseKey")
    artifact_candidate_key: str | None = Field(serialization_alias="artifactCandidateKey")
    artifact_validation_key: str | None = Field(serialization_alias="artifactValidationKey")
    output_asset_id: UUID | None = Field(serialization_alias="outputAssetId")
    output_object_key: str | None = Field(serialization_alias="outputObjectKey")
    output_bytes: int | None = Field(serialization_alias="outputBytes")
    output_sha256: str | None = Field(serialization_alias="outputSha256")
    created_at: datetime = Field(serialization_alias="createdAt")
    started_at: datetime | None = Field(serialization_alias="startedAt")
    finished_at: datetime | None = Field(serialization_alias="finishedAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")

    @field_validator(
        "artifact_request_key",
        "artifact_response_key",
        "artifact_candidate_key",
        "artifact_validation_key",
        "output_object_key",
    )
    @classmethod
    def validate_optional_object_keys(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name="object_key",
            max_length=AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH,
        )


class TTSGenerationEnsureAudioResponse(BaseModel):
    created: bool
    revision_id: UUID = Field(serialization_alias="revisionId")
    existing_asset_id: UUID | None = Field(serialization_alias="existingAssetId")
    job: TTSGenerationJobResponse | None = None
