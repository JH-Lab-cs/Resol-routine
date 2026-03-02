from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, SecretStr, field_validator

from app.core.input_validation import validate_optional_device_id, validate_user_input_text
from app.schemas.user import UserMeResponse


class RegisterRequest(BaseModel):
    email: EmailStr
    password: SecretStr = Field(min_length=8, max_length=256)
    device_id: str | None = Field(default=None, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def validate_email_input(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="email")

    @field_validator("device_id")
    @classmethod
    def validate_device_id_input(cls, value: str | None) -> str | None:
        return validate_optional_device_id(value)


class LoginRequest(BaseModel):
    email: EmailStr
    password: SecretStr
    device_id: str | None = Field(default=None, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def validate_email_input(cls, value: str) -> str:
        return validate_user_input_text(value, field_name="email")

    @field_validator("device_id")
    @classmethod
    def validate_device_id_input(cls, value: str | None) -> str | None:
        return validate_optional_device_id(value)


class RefreshRequest(BaseModel):
    refresh_token: SecretStr
    device_id: str | None = Field(default=None, max_length=128)

    @field_validator("device_id")
    @classmethod
    def validate_device_id_input(cls, value: str | None) -> str | None:
        return validate_optional_device_id(value)


class LogoutRequest(BaseModel):
    refresh_token: SecretStr
    all_devices: bool = False


class SessionTokensResponse(BaseModel):
    access_token: str
    access_token_expires_at: datetime
    refresh_token: str
    refresh_token_expires_at: datetime
    user: UserMeResponse
