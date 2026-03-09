from __future__ import annotations

import json
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


def test_openai_provider_accepts_array_options_in_structured_output(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    content_payload = {
        "candidates": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_MAIN_IDEA",
                "difficulty": 3,
                "sourcePolicy": "AI_ORIGINAL",
                "title": "Unit",
                "passage": "Passage text",
                "sentences": [{"id": "s1", "text": "Sentence 1"}],
                "question": {
                    "stem": "Stem",
                    "options": ["A text", "B text", "C text", "D text", "E text"],
                    "answerKey": "A",
                    "explanation": "Explanation",
                    "evidenceSentenceIds": ["s1"],
                    "whyCorrectKo": "정답 설명",
                    "whyWrongKoByOption": {
                        "B": "오답",
                        "C": "오답",
                        "D": "오답",
                        "E": "오답",
                    },
                },
            }
        ]
    }

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            payload = {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(content_payload, ensure_ascii=False),
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: _Response(),
    )

    result = _provider().generate_candidates(context=_context())

    assert result.provider_name == "openai"
    assert len(result.candidates) == 1
    assert result.candidates[0].options == {
        "A": "A text",
        "B": "B text",
        "C": "C text",
        "D": "D text",
        "E": "E text",
    }


def test_openai_provider_normalizes_descriptive_ai_original_source_policy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    content_payload = {
        "candidates": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_MAIN_IDEA",
                "difficulty": 3,
                "sourcePolicy": "Original content created for educational use; free to reuse.",
                "title": "Unit",
                "passage": "Passage text",
                "sentences": [{"id": "s1", "text": "Sentence 1"}],
                "question": {
                    "stem": "Stem",
                    "options": {
                        "A": "A text",
                        "B": "B text",
                        "C": "C text",
                        "D": "D text",
                        "E": "E text",
                    },
                    "answerKey": "A",
                    "explanation": "Explanation",
                    "evidenceSentenceIds": ["s1"],
                    "whyCorrectKo": "정답 설명",
                    "whyWrongKoByOption": {"B": "오답", "C": "오답", "D": "오답", "E": "오답"},
                },
            }
        ]
    }

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            payload = {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(content_payload, ensure_ascii=False),
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: _Response(),
    )

    result = _provider().generate_candidates(context=_context())

    assert result.candidates[0].source_policy.value == "AI_ORIGINAL"


def test_openai_provider_normalizes_any_non_empty_source_policy_string(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    content_payload = {
        "candidates": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_MAIN_IDEA",
                "difficulty": 3,
                "sourcePolicy": "Freshly generated for this learner cohort.",
                "title": "Unit",
                "passage": "Passage text",
                "sentences": [{"id": "s1", "text": "Sentence 1"}],
                "question": {
                    "stem": "Stem",
                    "options": {
                        "A": "A text",
                        "B": "B text",
                        "C": "C text",
                        "D": "D text",
                        "E": "E text",
                    },
                    "answerKey": "A",
                    "explanation": "Explanation",
                    "evidenceSentenceIds": ["s1"],
                    "whyCorrectKo": "정답 설명",
                    "whyWrongKoByOption": {"B": "오답", "C": "오답", "D": "오답", "E": "오답"},
                },
            }
        ]
    }

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            payload = {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(content_payload, ensure_ascii=False),
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: _Response(),
    )

    result = _provider().generate_candidates(context=_context())

    assert result.candidates[0].source_policy.value == "AI_ORIGINAL"


def test_openai_provider_uses_configured_http_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    observed_timeout: list[int] = []

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            payload = {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "candidates": [
                                        {
                                            "track": "H2",
                                            "skill": "READING",
                                            "typeTag": "R_MAIN_IDEA",
                                            "difficulty": 3,
                                            "sourcePolicy": "AI_ORIGINAL",
                                            "title": "Unit",
                                            "passage": "Passage text",
                                            "sentences": [{"id": "s1", "text": "Sentence 1"}],
                                            "question": {
                                                "stem": "Stem",
                                                "options": {
                                                    "A": "A text",
                                                    "B": "B text",
                                                    "C": "C text",
                                                    "D": "D text",
                                                    "E": "E text",
                                                },
                                                "answerKey": "A",
                                                "explanation": "Explanation",
                                                "evidenceSentenceIds": ["s1"],
                                                "whyCorrectKo": "정답 설명",
                                                "whyWrongKoByOption": {
                                                    "B": "오답",
                                                    "C": "오답",
                                                    "D": "오답",
                                                    "E": "오답",
                                                },
                                            },
                                        }
                                    ]
                                },
                                ensure_ascii=False,
                            ),
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    def _fake_urlopen(request, timeout):
        observed_timeout.append(timeout)
        return _Response()

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        _fake_urlopen,
    )
    monkeypatch.setattr(
        "app.services.ai_content_provider.settings.ai_provider_http_timeout_seconds",
        90,
    )

    _provider().generate_candidates(context=_context())

    assert observed_timeout == [90]


def test_openai_provider_accepts_single_key_option_objects(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    content_payload = {
        "candidates": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_MAIN_IDEA",
                "difficulty": 3,
                "sourcePolicy": "AI_ORIGINAL",
                "title": "Unit",
                "passage": "Passage text",
                "sentences": [{"id": "s1", "text": "Sentence 1"}],
                "question": {
                    "stem": "Stem",
                    "options": [
                        {"A": "A text"},
                        {"B": {"text": "B text"}},
                        {"C": {"value": "C text"}},
                        {"D": {"content": "D text"}},
                        {"E": {"answer": "E text"}},
                    ],
                    "answerKey": "A",
                    "explanation": "Explanation",
                    "evidenceSentenceIds": ["s1"],
                    "whyCorrectKo": "정답 설명",
                    "whyWrongKoByOption": {
                        "A": "정답 보기입니다.",
                        "B": "오답",
                        "C": "오답",
                        "D": "오답",
                        "E": "오답",
                    },
                },
            }
        ]
    }

    class _Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            payload = {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(content_payload, ensure_ascii=False),
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: _Response(),
    )

    result = _provider().generate_candidates(context=_context())

    assert result.candidates[0].options == {
        "A": "A text",
        "B": "B text",
        "C": "C text",
        "D": "D text",
        "E": "E text",
    }
