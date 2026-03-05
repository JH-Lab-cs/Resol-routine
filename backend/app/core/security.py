from __future__ import annotations

import hmac
import hashlib
import re
import secrets
from datetime import UTC, datetime, timedelta

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from jose import jwt

from app.core.config import settings
from app.core.input_validation import validate_user_input_text
from app.core.policies import ACCESS_TOKEN_TTL_MINUTES, JWT_ALGORITHM, PASSWORD_MIN_LENGTH

_PASSWORD_HASHER = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
)

_INVITE_CODE_PATTERN = re.compile(r"^\d{6}$")


def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    if not subject:
        raise ValueError("Token subject must not be empty.")

    issued_at = datetime.now(UTC)
    expires_in = expires_delta or timedelta(minutes=ACCESS_TOKEN_TTL_MINUTES)
    expires_at = issued_at + expires_in

    payload = {
        "sub": subject,
        "iat": int(issued_at.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def generate_opaque_token() -> str:
    # 48 random bytes provide 384 bits of entropy (>256-bit requirement).
    return secrets.token_urlsafe(48)


def hash_opaque_token(token: str) -> str:
    if not token:
        raise ValueError("Opaque token must not be empty.")
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_password(password: str) -> str:
    validate_password(password)
    return _PASSWORD_HASHER.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    if not password or not password_hash:
        return False
    try:
        return bool(_PASSWORD_HASHER.verify(password_hash, password))
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def validate_password(password: str) -> None:
    if len(password) < PASSWORD_MIN_LENGTH:
        raise ValueError(f"Password must be at least {PASSWORD_MIN_LENGTH} characters long.")


def normalize_email(email: str) -> str:
    normalized = validate_user_input_text(email, field_name="email")
    return normalized.lower()


def generate_invite_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_invite_code(code: str) -> str:
    if _INVITE_CODE_PATTERN.fullmatch(code) is None:
        raise ValueError("Invite code must be a six-digit number.")
    digest = hmac.new(
        settings.jwt_secret.encode("utf-8"),
        code.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return digest
