from __future__ import annotations

from datetime import datetime
import json

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import (
    BILLING_PRODUCT_CODE_MAX_LENGTH,
    BILLING_PROVIDER_RESPONSE_MAX_LENGTH,
    BILLING_RECEIPT_DATA_MAX_LENGTH,
    SUBSCRIPTION_METADATA_MAX_LENGTH,
)
from app.models.enums import BillingReceiptVerificationStatus, BillingWebhookStatus


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


class AppStoreReceiptVerifyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    plan_code: str = Field(alias="planCode")
    receipt_data: str = Field(alias="receiptData")
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")

    @field_validator("plan_code")
    @classmethod
    def validate_plan_code(cls, value: str) -> str:
        return _validate_identifier(value, field_name="plan_code", max_length=BILLING_PRODUCT_CODE_MAX_LENGTH)

    @field_validator("receipt_data")
    @classmethod
    def validate_receipt_data(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("receipt_data_must_not_be_empty")
        if len(normalized) > BILLING_RECEIPT_DATA_MAX_LENGTH:
            raise ValueError("receipt_data_too_large")
        return normalized

    @field_validator("metadata_json")
    @classmethod
    def validate_metadata_json(cls, value: dict[str, object]) -> dict[str, object]:
        serialized = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        if len(serialized) > SUBSCRIPTION_METADATA_MAX_LENGTH:
            raise ValueError("metadata_too_large")
        return value


class AppStoreReceiptVerifyResponse(BaseModel):
    verification_id: str = Field(serialization_alias="verificationId")
    status: BillingReceiptVerificationStatus
    subscription_id: str | None = Field(serialization_alias="subscriptionId")
    plan_code: str = Field(serialization_alias="planCode")
    starts_at: datetime | None = Field(serialization_alias="startsAt")
    expires_at: datetime | None = Field(serialization_alias="expiresAt")
    provider_response_code: str | None = Field(serialization_alias="providerResponseCode")
    detail_code: str = Field(serialization_alias="detailCode")


class StripeWebhookResponse(BaseModel):
    status: BillingWebhookStatus
    event_id: str = Field(serialization_alias="eventId")
    detail_code: str = Field(serialization_alias="detailCode")

    @field_validator("event_id")
    @classmethod
    def validate_event_id(cls, value: str) -> str:
        return _validate_identifier(value, field_name="event_id", max_length=128)

    @field_validator("detail_code")
    @classmethod
    def validate_detail_code(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="detail_code",
            max_length=BILLING_PROVIDER_RESPONSE_MAX_LENGTH,
        )
