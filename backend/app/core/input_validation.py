from __future__ import annotations

import unicodedata

INVALID_HIDDEN_UNICODE_DETAIL = "invalid_hidden_unicode"
INVALID_DEVICE_ID_DETAIL = "invalid_device_id"
INVALID_INVITE_CODE_DETAIL = "invalid_invite_code"


def validate_user_input_text(value: str, *, field_name: str) -> str:
    if not isinstance(value, str):
        raise TypeError(f"{field_name} must be a string.")

    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} must not be empty.")

    if contains_hidden_unicode(normalized):
        raise ValueError(INVALID_HIDDEN_UNICODE_DETAIL)
    return normalized


def validate_optional_device_id(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = validate_user_input_text(value, field_name="device_id")
    if len(normalized) > 128:
        raise ValueError(INVALID_DEVICE_ID_DETAIL)
    return normalized


def validate_invite_code_input(value: str) -> str:
    normalized = validate_user_input_text(value, field_name="code")
    if len(normalized) != 6 or not normalized.isdigit():
        raise ValueError(INVALID_INVITE_CODE_DETAIL)
    return normalized


def contains_hidden_unicode(value: str) -> bool:
    for char in value:
        category = unicodedata.category(char)
        if category in {"Cc", "Cf"}:
            return True
    return False
