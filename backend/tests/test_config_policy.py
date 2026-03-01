import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.core.policies import ACCESS_TOKEN_TTL_MINUTES, JWT_ALGORITHM, REFRESH_TOKEN_TTL_DAYS


def _valid_env(overrides: dict[str, str] | None = None) -> dict[str, str]:
    base = {
        "DATABASE_URL": "postgresql+psycopg://resol:resol@localhost:5432/resol_backend",
        "REDIS_URL": "redis://localhost:6379/0",
        "JWT_SECRET": "this-is-a-secure-jwt-secret-value-over-32-chars",
        "R2_ENDPOINT": "https://example.r2.cloudflarestorage.com",
        "R2_BUCKET": "resol-private-bucket",
        "R2_ACCESS_KEY_ID": "secure-access-key-id",
        "R2_SECRET_ACCESS_KEY": "secure-secret-access-key",
    }
    if overrides:
        base.update(overrides)
    return base


def _apply_env(monkeypatch: pytest.MonkeyPatch, values: dict[str, str]) -> None:
    for key, value in values.items():
        monkeypatch.setenv(key, value)


def test_rejects_placeholder_like_credentials(monkeypatch: pytest.MonkeyPatch) -> None:
    env = _valid_env({"JWT_SECRET": "replace-with-a-long-random-secret-at-least-32-characters"})
    _apply_env(monkeypatch, env)

    with pytest.raises(ValidationError):
        Settings()


def test_rejects_change_me_for_r2_credentials(monkeypatch: pytest.MonkeyPatch) -> None:
    env = _valid_env({"R2_ACCESS_KEY_ID": "change-me"})
    _apply_env(monkeypatch, env)

    with pytest.raises(ValidationError):
        Settings()


def test_fixed_policies_cannot_be_overridden_by_env(monkeypatch: pytest.MonkeyPatch) -> None:
    env = _valid_env(
        {
            "ACCESS_TOKEN_TTL_MINUTES": "999",
            "REFRESH_TOKEN_TTL_DAYS": "999",
            "JWT_ALGORITHM": "none",
        }
    )
    _apply_env(monkeypatch, env)

    settings = Settings()

    assert settings.access_token_ttl_minutes == ACCESS_TOKEN_TTL_MINUTES
    assert settings.refresh_token_ttl_days == REFRESH_TOKEN_TTL_DAYS
    assert settings.jwt_algorithm == JWT_ALGORITHM


def test_rejects_invalid_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    env = _valid_env({"DATABASE_URL": "sqlite:///tmp.db"})
    _apply_env(monkeypatch, env)

    with pytest.raises(ValidationError):
        Settings()
