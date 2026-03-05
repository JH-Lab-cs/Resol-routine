from functools import lru_cache
from urllib.parse import urlparse

from pydantic import Field, ValidationInfo, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.core.policies import (
    ACCESS_TOKEN_TTL_MINUTES,
    AI_ARTIFACT_RETENTION_DAYS_DEFAULT,
    AI_ARTIFACT_RETENTION_DAYS_MAX,
    APP_TIMEZONE,
    BILLING_WEBHOOK_SIGNATURE_TOLERANCE_SECONDS,
    DB_TIMEZONE,
    JWT_ALGORITHM,
    R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
    R2_UPLOAD_SIGNED_URL_TTL_SECONDS,
    REFRESH_TOKEN_TTL_DAYS,
)

_DISALLOWED_SECRET_TOKENS = (
    "change-me",
    "changeme",
    "replace-with",
    "replace_me",
    "example-secret",
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Resol Routine Backend"
    app_version: str = "0.1.0"
    environment: str = "development"
    api_prefix: str = ""

    database_url: str
    redis_url: str

    jwt_secret: str = Field(min_length=32)
    r2_endpoint: str
    r2_bucket: str
    r2_access_key_id: str
    r2_secret_access_key: str
    content_pipeline_api_key: str = Field(min_length=24)

    ai_generation_provider: str = "disabled"
    ai_generation_api_key: str | None = None
    ai_mock_exam_model: str = "not-configured"
    ai_mock_exam_prompt_template_version: str = "v1"
    ai_content_model: str = "not-configured"
    ai_content_prompt_template_version: str = "v1"
    ai_openai_base_url: str = "https://api.openai.com"
    ai_anthropic_base_url: str = "https://api.anthropic.com"
    ai_artifact_retention_days: int = AI_ARTIFACT_RETENTION_DAYS_DEFAULT

    stripe_webhook_secret: str | None = None
    app_store_shared_secret: str | None = None
    app_store_verify_url: str = "https://buy.itunes.apple.com/verifyReceipt"
    app_store_sandbox_verify_url: str = "https://sandbox.itunes.apple.com/verifyReceipt"

    @property
    def jwt_algorithm(self) -> str:
        return JWT_ALGORITHM

    @property
    def access_token_ttl_minutes(self) -> int:
        return ACCESS_TOKEN_TTL_MINUTES

    @property
    def refresh_token_ttl_days(self) -> int:
        return REFRESH_TOKEN_TTL_DAYS

    @property
    def r2_upload_signed_url_ttl_seconds(self) -> int:
        return R2_UPLOAD_SIGNED_URL_TTL_SECONDS

    @property
    def r2_download_signed_url_ttl_seconds(self) -> int:
        return R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS

    @property
    def app_timezone(self) -> str:
        return APP_TIMEZONE

    @property
    def db_timezone(self) -> str:
        return DB_TIMEZONE

    @property
    def billing_webhook_signature_tolerance_seconds(self) -> int:
        return BILLING_WEBHOOK_SIGNATURE_TOLERANCE_SECONDS

    @field_validator(
        "jwt_secret",
        "r2_access_key_id",
        "r2_secret_access_key",
        "r2_bucket",
        "content_pipeline_api_key",
        mode="before",
    )
    @classmethod
    def validate_non_empty_and_not_sample_defaults(cls, value: str, info: ValidationInfo) -> str:
        if not isinstance(value, str):
            raise TypeError(f"{info.field_name} must be a string.")

        normalized = value.strip()
        if not normalized:
            raise ValueError(f"{info.field_name} must not be empty.")

        lowered = normalized.lower()
        if lowered in _DISALLOWED_SECRET_TOKENS:
            raise ValueError(f"{info.field_name} must not use an insecure sample value.")
        if lowered.startswith("replace-with-") or lowered.startswith("change-"):
            raise ValueError(f"{info.field_name} must not use an insecure sample value.")
        return normalized

    @field_validator(
        "ai_generation_provider",
        "ai_mock_exam_model",
        "ai_mock_exam_prompt_template_version",
        "ai_content_model",
        "ai_content_prompt_template_version",
        mode="before",
    )
    @classmethod
    def validate_non_empty_identifier_settings(cls, value: str, info: ValidationInfo) -> str:
        if not isinstance(value, str):
            raise TypeError(f"{info.field_name} must be a string.")
        normalized = value.strip()
        if not normalized:
            raise ValueError(f"{info.field_name} must not be empty.")
        return normalized

    @field_validator("ai_generation_api_key", mode="before")
    @classmethod
    def validate_optional_ai_api_key(cls, value: str | None) -> str | None:
        return cls._normalize_optional_secret(
            value=value,
            field_name="ai_generation_api_key",
            allow_none=True,
        )

    @field_validator("stripe_webhook_secret", "app_store_shared_secret", mode="before")
    @classmethod
    def validate_optional_billing_secret(cls, value: str | None, info: ValidationInfo) -> str | None:
        return cls._normalize_optional_secret(
            value=value,
            field_name=info.field_name,
            allow_none=True,
        )

    @classmethod
    def _normalize_optional_secret(
        cls,
        *,
        value: str | None,
        field_name: str,
        allow_none: bool,
    ) -> str | None:
        if value is None:
            return None if allow_none else ""
        if not isinstance(value, str):
            raise TypeError(f"{field_name} must be a string.")
        normalized = value.strip()
        if not normalized:
            return None
        lowered = normalized.lower()
        if lowered in _DISALLOWED_SECRET_TOKENS:
            raise ValueError(f"{field_name} must not use an insecure sample value.")
        if lowered.startswith("replace-with-") or lowered.startswith("change-"):
            raise ValueError(f"{field_name} must not use an insecure sample value.")
        return normalized

    @field_validator("ai_openai_base_url", "ai_anthropic_base_url", "app_store_verify_url", "app_store_sandbox_verify_url", mode="before")
    @classmethod
    def validate_https_base_urls(cls, value: str, info: ValidationInfo) -> str:
        if not isinstance(value, str):
            raise TypeError(f"{info.field_name} must be a string.")
        normalized = value.strip()
        parsed = urlparse(normalized)
        if parsed.scheme != "https":
            raise ValueError(f"{info.field_name} must use https scheme.")
        if not parsed.netloc:
            raise ValueError(f"{info.field_name} must include host.")
        return normalized

    @field_validator("ai_artifact_retention_days")
    @classmethod
    def validate_ai_artifact_retention_days(cls, value: int) -> int:
        if value <= 0 or value > AI_ARTIFACT_RETENTION_DAYS_MAX:
            raise ValueError("ai_artifact_retention_days out of allowed range.")
        return value

    @field_validator("database_url", mode="before")
    @classmethod
    def validate_database_url(cls, value: str) -> str:
        if not isinstance(value, str):
            raise TypeError("database_url must be a string.")
        normalized = value.strip()
        parsed = urlparse(normalized)
        if parsed.scheme != "postgresql+psycopg":
            raise ValueError("database_url must use the postgresql+psycopg scheme.")
        if not parsed.netloc:
            raise ValueError("database_url must include host credentials.")
        if not parsed.path or parsed.path == "/":
            raise ValueError("database_url must include a database name.")
        return normalized

    @field_validator("redis_url", mode="before")
    @classmethod
    def validate_redis_url(cls, value: str) -> str:
        if not isinstance(value, str):
            raise TypeError("redis_url must be a string.")
        normalized = value.strip()
        parsed = urlparse(normalized)
        if parsed.scheme not in {"redis", "rediss"}:
            raise ValueError("redis_url must use redis or rediss scheme.")
        if not parsed.netloc:
            raise ValueError("redis_url must include host.")
        return normalized

    @field_validator("r2_endpoint", mode="before")
    @classmethod
    def validate_r2_endpoint(cls, value: str) -> str:
        if not isinstance(value, str):
            raise TypeError("r2_endpoint must be a string.")
        normalized = value.strip()
        parsed = urlparse(normalized)
        if parsed.scheme not in {"http", "https"}:
            raise ValueError("r2_endpoint must use http or https scheme.")
        if not parsed.netloc:
            raise ValueError("r2_endpoint must include host.")
        return normalized


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
