from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.input_validation import validate_invite_code_input, validate_optional_device_id


class InviteIssueResponse(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")
    expires_at: datetime


class InviteVerifyRequest(BaseModel):
    parent_id: UUID
    code: str
    device_id: str | None = Field(default=None, max_length=128)

    @field_validator("code")
    @classmethod
    def validate_code(cls, value: str) -> str:
        return validate_invite_code_input(value)

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, value: str | None) -> str | None:
        return validate_optional_device_id(value)


class InviteVerifyResponse(BaseModel):
    valid: bool
    expires_at: datetime


class InviteConsumeRequest(BaseModel):
    parent_id: UUID
    code: str
    device_id: str | None = Field(default=None, max_length=128)

    @field_validator("code")
    @classmethod
    def validate_code(cls, value: str) -> str:
        return validate_invite_code_input(value)

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, value: str | None) -> str | None:
        return validate_optional_device_id(value)


class InviteConsumeResponse(BaseModel):
    parent_id: UUID
    child_id: UUID
    linked_at: datetime


class UnlinkRequest(BaseModel):
    child_id: UUID


class UnlinkResponse(BaseModel):
    parent_id: UUID
    child_id: UUID
    unlinked_at: datetime
