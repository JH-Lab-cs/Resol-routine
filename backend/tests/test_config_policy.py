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
        "CONTENT_PIPELINE_API_KEY": "secure-content-pipeline-api-key",
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


def test_rejects_invalid_ai_content_run_limits(monkeypatch: pytest.MonkeyPatch) -> None:
    env = _valid_env(
        {
            "AI_CONTENT_MAX_TARGETS_PER_RUN": "0",
            "AI_CONTENT_MAX_CANDIDATES_PER_RUN": "-1",
        }
    )
    _apply_env(monkeypatch, env)

    with pytest.raises(ValidationError):
        Settings()


def test_ai_content_default_dry_run_must_remain_enabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    env = _valid_env({"AI_CONTENT_DEFAULT_DRY_RUN": "false"})
    _apply_env(monkeypatch, env)

    with pytest.raises(ValidationError):
        Settings()


def test_ai_content_provider_specific_values_resolve_with_fallback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    env = _valid_env(
        {
            "AI_GENERATION_PROVIDER": "fake",
            "AI_GENERATION_API_KEY": "generation-api-key",
            "AI_CONTENT_PROVIDER": "openai",
            "AI_CONTENT_API_KEY": "content-api-key",
            "AI_CONTENT_MODEL": "gpt-4.1-mini",
            "AI_CONTENT_PROMPT_TEMPLATE_VERSION": "content-v2",
            "AI_CONTENT_MAX_ESTIMATED_COST_USD": "3.5",
        }
    )
    _apply_env(monkeypatch, env)

    settings = Settings()

    assert settings.resolved_ai_content_provider == "openai"
    assert settings.resolved_ai_content_api_key == "content-api-key"
    assert settings.ai_content_model == "gpt-4.1-mini"
    assert settings.ai_content_prompt_template_version == "content-v2"
    assert settings.ai_content_max_estimated_cost_usd == 3.5
