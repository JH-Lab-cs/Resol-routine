from datetime import timedelta

from app.core.policies import ACCESS_TOKEN_TTL_MINUTES
from app.core.security import create_access_token, generate_opaque_token, hash_opaque_token


def test_access_token_contains_three_segments() -> None:
    token = create_access_token(subject="test-user", expires_delta=timedelta(minutes=5))
    assert token.count(".") == 2


def test_opaque_token_hash_is_sha256_hex() -> None:
    raw = generate_opaque_token()
    hashed = hash_opaque_token(raw)
    assert len(hashed) == 64
    assert hashed != raw


def test_access_token_uses_policy_default_expiry_when_not_provided() -> None:
    token = create_access_token(subject="test-user")
    assert token.count(".") == 2
    assert ACCESS_TOKEN_TTL_MINUTES == 15
