from __future__ import annotations

from io import BytesIO
from urllib import error as urllib_error

import pytest

from app.models.enums import ContentTypeTag, Skill, Track
from app.services.ai_content_provider import (
    ContentGenerationContext,
    ContentGenerationTarget,
    OpenAIContentGenerationProvider,
)
from app.services.ai_provider import AIProviderError


def _context() -> ContentGenerationContext:
    return ContentGenerationContext(
        request_id="provider-http-branch-test",
        target_matrix=[
            ContentGenerationTarget(
                track=Track.H2,
                skill=Skill.READING,
                type_tag=ContentTypeTag.R_MAIN_IDEA,
                difficulty=3,
                count=1,
            )
        ],
        candidate_count_per_target=1,
        dry_run=False,
        notes="provider-http-branch-test",
    )


def _provider() -> OpenAIContentGenerationProvider:
    return OpenAIContentGenerationProvider(
        api_key="unit-test-api-key",
        model_name="gpt-4.1-mini",
        prompt_template_version="content-v1",
        base_url="https://api.openai.example",
    )


def test_openai_provider_maps_auth_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def raise_http_error(request, timeout):
        raise urllib_error.HTTPError(
            url=request.full_url,
            code=401,
            msg="Unauthorized",
            hdrs=None,
            fp=BytesIO(b'{"error":"unauthorized"}'),
        )

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", raise_http_error)

    with pytest.raises(AIProviderError) as exc_info:
        _provider().generate_candidates(context=_context())

    assert exc_info.value.code == "PROVIDER_AUTH_FAILED"
    assert exc_info.value.transient is False


def test_openai_provider_maps_rate_limit_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def raise_http_error(request, timeout):
        raise urllib_error.HTTPError(
            url=request.full_url,
            code=429,
            msg="Rate limited",
            hdrs=None,
            fp=BytesIO(b'{"error":"rate_limited"}'),
        )

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", raise_http_error)

    with pytest.raises(AIProviderError) as exc_info:
        _provider().generate_candidates(context=_context())

    assert exc_info.value.code == "PROVIDER_RATE_LIMITED"
    assert exc_info.value.transient is True


def test_openai_provider_maps_timeout_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def raise_timeout(request, timeout):
        raise urllib_error.URLError("timed out")

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", raise_timeout)

    with pytest.raises(AIProviderError) as exc_info:
        _provider().generate_candidates(context=_context())

    assert exc_info.value.code == "PROVIDER_TIMEOUT"
    assert exc_info.value.transient is True
