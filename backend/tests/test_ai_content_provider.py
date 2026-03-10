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


def _listening_context(type_tag: ContentTypeTag) -> ContentGenerationContext:
    return ContentGenerationContext(
        request_id="provider-listening-hardtag-test",
        target_matrix=[
            ContentGenerationTarget(
                track=Track.M3,
                skill=Skill.LISTENING,
                type_tag=type_tag,
                difficulty=1,
                count=1,
            )
        ],
        candidate_count_per_target=1,
        dry_run=False,
        notes="provider-listening-hardtag-test",
    )


def _reading_context(type_tag: ContentTypeTag) -> ContentGenerationContext:
    return ContentGenerationContext(
        request_id="provider-reading-hardtag-test",
        target_matrix=[
            ContentGenerationTarget(
                track=Track.H1,
                skill=Skill.READING,
                type_tag=type_tag,
                difficulty=2,
                count=1,
            )
        ],
        candidate_count_per_target=1,
        dry_run=False,
        notes="provider-reading-hardtag-test",
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


def test_openai_provider_uses_hard_typetag_prompt_template_and_rules(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured_payload: dict[str, object] = {}

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
                                            "track": "M3",
                                            "skill": "LISTENING",
                                            "typeTag": "L_LONG_TALK",
                                            "difficulty": 1,
                                            "sourcePolicy": "AI_ORIGINAL",
                                            "title": "Unit",
                                            "transcriptText": "A: Hello\nB: Hi\nA: Plan\nB: Agreed",
                                            "turns": [
                                                {"speaker": "A", "text": "Hello"},
                                                {"speaker": "B", "text": "Hi"},
                                                {"speaker": "A", "text": "Plan"},
                                                {"speaker": "B", "text": "Agreed"},
                                            ],
                                            "sentences": [
                                                "Hello",
                                                "Hi",
                                                "Plan",
                                                "Agreed",
                                            ],
                                            "question": {
                                                "stem": "What is the main idea?",
                                                "options": [
                                                    "A text",
                                                    "B text",
                                                    "C text",
                                                    "D text",
                                                    "E text",
                                                ],
                                                "answerKey": "A",
                                                "explanation": "Explanation long enough to pass.",
                                                "evidenceSentenceIds": [1, 2],
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

    def fake_urlopen(request, timeout):
        captured_payload.update(json.loads(request.data.decode("utf-8")))
        return _Response()

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", fake_urlopen)

    result = _provider().generate_candidates(context=_listening_context(ContentTypeTag.L_LONG_TALK))

    assert result.prompt_template_version == "content-v1-listening-longtalk"
    assert "at least four turns" in captured_payload["messages"][0]["content"]
    assert "\"promptTemplateVersion\":\"content-v1-listening-longtalk\"" in captured_payload[
        "messages"
    ][1]["content"]
    assert result.candidates[0].transcript == "A: Hello\nB: Hi\nA: Plan\nB: Agreed"
    assert result.candidates[0].sentences[0]["id"] == "s1"
    assert result.candidates[0].evidence_sentence_ids == ["s1", "s2"]


def test_openai_provider_normalizes_transcript_body_and_answer_key_variants(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    content_payload = {
        "candidates": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_BLANK",
                "difficulty": 3,
                "sourcePolicy": "AI_ORIGINAL",
                "title": "Unit",
                "bodyText": "Sentence one. [BLANK] Sentence two.",
                "sentences": ["Sentence one.", "[BLANK] Sentence two."],
                "question": {
                    "stem": "Fill the blank.",
                    "options": {
                        "1": "A text",
                        "2": "B text",
                        "3": "C text",
                        "4": "D text",
                        "5": "E text",
                    },
                    "answer": "A)",
                    "rationale": "Explanation",
                    "evidence": [1],
                    "whyCorrect": "정답 설명",
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
            payload = {"choices": [{"message": {"content": json.dumps(content_payload)}}]}
            return json.dumps(payload).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: _Response(),
    )

    result = _provider().generate_candidates(context=_context())

    assert result.prompt_template_version == "content-v1-reading-default"
    assert result.candidates[0].passage == "Sentence one. [BLANK] Sentence two."
    assert result.candidates[0].options["A"] == "A text"
    assert result.candidates[0].answer_key == "A"
    assert result.candidates[0].evidence_sentence_ids == ["s1"]


def test_openai_provider_uses_reading_insertion_prompt_template_and_rules(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured_payload: dict[str, object] = {}

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
                                            "track": "H1",
                                            "skill": "READING",
                                            "typeTag": "R_INSERTION",
                                            "difficulty": 2,
                                            "sourcePolicy": "AI_ORIGINAL",
                                            "title": "Unit",
                                            "bodyText": (
                                                "Sentence one. [1] Sentence two. [2] "
                                                "Sentence three. [3] Sentence four. [4]"
                                            ),
                                            "sentences": [
                                                "Sentence one.",
                                                "Sentence two.",
                                                "Sentence three.",
                                                "Sentence four.",
                                            ],
                                            "question": {
                                                "stem": "Where should the sentence be inserted?",
                                                "options": {
                                                    "A": "Position 1",
                                                    "B": "Position 2",
                                                    "C": "Position 3",
                                                    "D": "Position 4",
                                                    "E": "It does not fit.",
                                                },
                                                "answerKey": "B",
                                                "explanation": "Insertion explanation.",
                                                "evidenceSentenceIds": ["s2", "s3"],
                                                "whyCorrectKo": "정답 설명",
                                                "whyWrongKoByOption": {
                                                    "A": "오답",
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

    def fake_urlopen(request, timeout):
        captured_payload.update(json.loads(request.data.decode("utf-8")))
        return _Response()

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", fake_urlopen)

    result = _provider().generate_candidates(context=_reading_context(ContentTypeTag.R_INSERTION))

    assert result.prompt_template_version == "content-v1-reading-insertion"
    assert "Passage must include insertion markers [1], [2], [3], and [4]." in captured_payload[
        "messages"
    ][0]["content"]
    assert '"promptTemplateVersion":"content-v1-reading-insertion"' in captured_payload[
        "messages"
    ][1]["content"]
