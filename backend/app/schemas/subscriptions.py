from __future__ import annotations

from datetime import datetime
import json
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.input_validation import validate_user_input_text
from app.core.policies import (
    SUBSCRIPTION_DISPLAY_NAME_MAX_LENGTH,
    SUBSCRIPTION_EXTERNAL_BILLING_REF_MAX_LENGTH,
    SUBSCRIPTION_LIST_DEFAULT_PAGE_SIZE,
    SUBSCRIPTION_LIST_MAX_PAGE_SIZE,
    SUBSCRIPTION_METADATA_MAX_LENGTH,
    SUBSCRIPTION_PLAN_CODE_MAX_LENGTH,
)
from app.models.enums import (
    SubscriptionFeatureCode,
    SubscriptionPlanStatus,
    UserRole,
    UserSubscriptionStatus,
)


def _validate_identifier(value: str, *, field_name: str, max_length: int) -> str:
    normalized = validate_user_input_text(value, field_name=field_name)
    if len(normalized) > max_length:
        raise ValueError(f"{field_name}_too_long")
    return normalized


def _validate_metadata(value: dict[str, object]) -> dict[str, object]:
    serialized = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if len(serialized) > SUBSCRIPTION_METADATA_MAX_LENGTH:
        raise ValueError("metadata_too_large")
    return value


def _validate_timezone_aware(value: datetime, *, field_name: str) -> datetime:
    if value.tzinfo is None:
        raise ValueError(f"{field_name}_must_be_timezone_aware")
    return value


class SubscriptionPlanCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    plan_code: str = Field(alias="planCode")
    display_name: str = Field(alias="displayName")
    feature_codes: list[SubscriptionFeatureCode] = Field(alias="featureCodes")
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")

    @field_validator("plan_code")
    @classmethod
    def validate_plan_code(cls, value: str) -> str:
        return _validate_identifier(value, field_name="plan_code", max_length=SUBSCRIPTION_PLAN_CODE_MAX_LENGTH)

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, value: str) -> str:
        return _validate_identifier(
            value,
            field_name="display_name",
            max_length=SUBSCRIPTION_DISPLAY_NAME_MAX_LENGTH,
        )

    @field_validator("feature_codes")
    @classmethod
    def validate_feature_codes(cls, value: list[SubscriptionFeatureCode]) -> list[SubscriptionFeatureCode]:
        if not value:
            raise ValueError("feature_codes_must_not_be_empty")
        if len(value) != len(set(value)):
            raise ValueError("duplicate_feature_code")
        return value

    @field_validator("metadata_json")
    @classmethod
    def validate_metadata_json(cls, value: dict[str, object]) -> dict[str, object]:
        return _validate_metadata(value)


class SubscriptionPlanResponse(BaseModel):
    id: str
    plan_code: str = Field(serialization_alias="planCode")
    display_name: str = Field(serialization_alias="displayName")
    status: SubscriptionPlanStatus
    feature_codes: list[SubscriptionFeatureCode] = Field(serialization_alias="featureCodes")
    metadata_json: dict[str, object] = Field(serialization_alias="metadata")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class SubscriptionPlanListResponse(BaseModel):
    items: list[SubscriptionPlanResponse]


class UserSubscriptionCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    plan_code: str = Field(alias="planCode")
    status: UserSubscriptionStatus
    starts_at: datetime = Field(alias="startsAt")
    ends_at: datetime = Field(alias="endsAt")
    grace_ends_at: datetime | None = Field(default=None, alias="graceEndsAt")
    external_billing_ref: str | None = Field(default=None, alias="externalBillingRef")
    metadata_json: dict[str, object] = Field(default_factory=dict, alias="metadata")

    @field_validator("plan_code")
    @classmethod
    def validate_plan_code(cls, value: str) -> str:
        return _validate_identifier(value, field_name="plan_code", max_length=SUBSCRIPTION_PLAN_CODE_MAX_LENGTH)

    @field_validator("starts_at")
    @classmethod
    def validate_starts_at(cls, value: datetime) -> datetime:
        return _validate_timezone_aware(value, field_name="starts_at")

    @field_validator("ends_at")
    @classmethod
    def validate_ends_at(cls, value: datetime) -> datetime:
        return _validate_timezone_aware(value, field_name="ends_at")

    @field_validator("grace_ends_at")
    @classmethod
    def validate_grace_ends_at(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return _validate_timezone_aware(value, field_name="grace_ends_at")

    @field_validator("external_billing_ref")
    @classmethod
    def validate_external_billing_ref(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_identifier(
            value,
            field_name="external_billing_ref",
            max_length=SUBSCRIPTION_EXTERNAL_BILLING_REF_MAX_LENGTH,
        )

    @field_validator("metadata_json")
    @classmethod
    def validate_metadata_json(cls, value: dict[str, object]) -> dict[str, object]:
        return _validate_metadata(value)

    @model_validator(mode="after")
    def validate_window_and_status(self) -> UserSubscriptionCreateRequest:
        if self.starts_at >= self.ends_at:
            raise ValueError("invalid_subscription_window")
        if self.status not in {
            UserSubscriptionStatus.TRIALING,
            UserSubscriptionStatus.ACTIVE,
            UserSubscriptionStatus.GRACE,
        }:
            raise ValueError("invalid_initial_subscription_status")
        if self.status == UserSubscriptionStatus.GRACE and self.grace_ends_at is None:
            raise ValueError("grace_ends_at_required")
        if self.grace_ends_at is not None and self.grace_ends_at < self.ends_at:
            raise ValueError("invalid_grace_window")
        return self


class UserSubscriptionResponse(BaseModel):
    id: str
    owner_user_id: str = Field(serialization_alias="ownerUserId")
    plan_code: str = Field(serialization_alias="planCode")
    status: UserSubscriptionStatus
    starts_at: datetime = Field(serialization_alias="startsAt")
    ends_at: datetime = Field(serialization_alias="endsAt")
    grace_ends_at: datetime | None = Field(serialization_alias="graceEndsAt")
    canceled_at: datetime | None = Field(serialization_alias="canceledAt")
    metadata_json: dict[str, object] = Field(serialization_alias="metadata")
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class UserSubscriptionListResponse(BaseModel):
    owner_user_id: str = Field(serialization_alias="ownerUserId")
    items: list[UserSubscriptionResponse]


class SubscriptionStateChangeResponse(BaseModel):
    subscription_id: str = Field(serialization_alias="subscriptionId")
    status: UserSubscriptionStatus
    canceled_at: datetime | None = Field(serialization_alias="canceledAt")
    ends_at: datetime = Field(serialization_alias="endsAt")
    grace_ends_at: datetime | None = Field(serialization_alias="graceEndsAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")


class SubscriptionMeParentActiveSubscription(BaseModel):
    status: UserSubscriptionStatus
    starts_at: datetime = Field(serialization_alias="startsAt")
    ends_at: datetime = Field(serialization_alias="endsAt")
    grace_ends_at: datetime | None = Field(serialization_alias="graceEndsAt")
    plan_code: str = Field(serialization_alias="planCode")
    source: Literal["OWN"]


class SubscriptionMeParentResponse(BaseModel):
    actor_role: UserRole = Field(serialization_alias="actorRole")
    feature_codes: list[SubscriptionFeatureCode] = Field(serialization_alias="featureCodes")
    active_subscription: SubscriptionMeParentActiveSubscription | None = Field(
        serialization_alias="activeSubscription"
    )


class SubscriptionMeStudentParentSource(BaseModel):
    parent_id: str = Field(serialization_alias="parentId")
    status: UserSubscriptionStatus | None
    plan_code: str | None = Field(serialization_alias="planCode")
    feature_codes: list[SubscriptionFeatureCode] = Field(serialization_alias="featureCodes")


class SubscriptionMeStudentResponse(BaseModel):
    actor_role: UserRole = Field(serialization_alias="actorRole")
    source: Literal["LINKED_PARENTS"]
    feature_codes: list[SubscriptionFeatureCode] = Field(serialization_alias="featureCodes")
    linked_parent_sources: list[SubscriptionMeStudentParentSource] = Field(serialization_alias="linkedParentSources")
    effective_status: Literal["ACTIVE", "INACTIVE"] = Field(serialization_alias="effectiveStatus")


SubscriptionMeResponse = SubscriptionMeParentResponse | SubscriptionMeStudentResponse


class SubscriptionPlanListQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    page: int = 1
    page_size: int = SUBSCRIPTION_LIST_DEFAULT_PAGE_SIZE

    @field_validator("page")
    @classmethod
    def validate_page(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("invalid_page")
        return value

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, value: int) -> int:
        if value <= 0 or value > SUBSCRIPTION_LIST_MAX_PAGE_SIZE:
            raise ValueError("invalid_page_size")
        return value
