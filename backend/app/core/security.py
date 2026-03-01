from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, datetime, timedelta

from jose import jwt

from app.core.config import settings
from app.core.policies import ACCESS_TOKEN_TTL_MINUTES, JWT_ALGORITHM


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
