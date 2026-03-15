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
from app.services.type_specific_generation_quality_service import (
    L_SITUATION_CONTEXTUAL_GENERATION_MODE,
    R_BLANK_OUTLINE_GENERATION_MODE,
    R_ORDER_OUTLINE_GENERATION_MODE,
)


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


def _h2_listening_context(type_tag: ContentTypeTag) -> ContentGenerationContext:
    return ContentGenerationContext(
        request_id="provider-h2-listening-hardtag-test",
        target_matrix=[
            ContentGenerationTarget(
                track=Track.H2,
                skill=Skill.LISTENING,
                type_tag=type_tag,
                difficulty=3,
                count=1,
            )
        ],
        candidate_count_per_target=1,
        dry_run=False,
        notes="provider-h2-listening-hardtag-test",
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
    assert (
        '"promptTemplateVersion":"content-v1-listening-longtalk"'
        in captured_payload["messages"][1]["content"]
    )
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
    assert (
        "Passage must include insertion markers [1], [2], [3], and [4]."
        in captured_payload["messages"][0]["content"]
    )
    assert (
        '"promptTemplateVersion":"content-v1-reading-insertion"'
        in captured_payload["messages"][1]["content"]
    )


def test_openai_provider_uses_l_response_skeleton_template_and_compiles_candidate(
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
                                            "difficulty": 1,
                                            "typeTag": "L_RESPONSE",
                                            "turns": [
                                                {
                                                    "speaker": "A",
                                                    "text": (
                                                        "Could you tell me where the meeting is?"
                                                    ),
                                                },
                                                {
                                                    "speaker": "B",
                                                    "text": (
                                                        "Yes, but check the board "
                                                        "near the office first."
                                                    ),
                                                },
                                            ],
                                            "responsePromptSpeaker": "B",
                                            "correctResponseText": (
                                                "Okay, I'll check the board first."
                                            ),
                                            "distractorResponseTexts": [
                                                "I already bought lunch.",
                                                "The weather was nice yesterday.",
                                                "My bag is under the desk.",
                                                "Let's clean the room after class.",
                                            ],
                                            "evidenceTurnIndexes": [2],
                                            "whyCorrectKo": (
                                                "마지막 화자가 먼저 게시판을 확인하라고 말하므로 "
                                                "그에 맞는 응답이 정답입니다."
                                            ),
                                            "whyWrongKoByOption": {
                                                "B": "점심 이야기는 대화 맥락과 무관합니다.",
                                                "C": (
                                                    "날씨 이야기는 마지막 발화에 대한 "
                                                    "응답이 아닙니다."
                                                ),
                                                "D": "가방 위치는 대화 목적과 관련이 없습니다.",
                                                "E": (
                                                    "청소 제안은 마지막 화자의 요청과 "
                                                    "맞지 않습니다."
                                                ),
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

    result = _provider().generate_candidates(context=_listening_context(ContentTypeTag.L_RESPONSE))

    assert result.prompt_template_version == "content-v1-listening-response-skeleton"
    assert result.generation_mode == "L_RESPONSE_SKELETON"
    assert result.compiler_version == "l-response-compiler-v1"
    assert "response-item skeleton" in captured_payload["messages"][0]["content"]
    assert '"generationMode":"L_RESPONSE_SKELETON"' in captured_payload["messages"][1]["content"]
    assert result.candidates[0].stem == "What is the most appropriate response to the last speaker?"
    assert result.candidates[0].answer_key == "A"
    assert result.candidates[0].options["A"] == "Okay, I'll check the board first."
    assert result.candidates[0].evidence_sentence_ids == ["s2"]


def test_openai_provider_uses_h2_l_situation_contextual_profile_and_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured_payload: dict[str, object] = {}
    observed_timeout: list[int] = []
    setting_summary = "Two students are adjusting a plan after a room problem."
    line_1 = "Our group presentation is tomorrow morning, but the room is closed for repairs."
    line_2 = "Then we need another room, and the media lab is free only after lunch."
    line_3 = "I should ask the teacher whether we can change the presentation time."
    implied_label = "schedule change under a room constraint"
    correct_option = "Explain the room problem and ask to move the presentation."
    distractor_b = "Wait in front of the closed room and hope it opens."
    distractor_c = "Cancel the presentation without telling the teacher."
    why_correct = "시간과 장소 제약을 함께 고려해야 하므로 시간 변경 요청이 적절합니다."
    why_wrong_b = "기다리는 것만으로는 핵심 문제를 해결하지 못합니다."

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
                                            "difficulty": 3,
                                            "typeTag": "L_SITUATION",
                                            "settingSummary": setting_summary,
                                            "turns": [
                                                {"speaker": "Mina", "text": line_1},
                                                {"speaker": "Joon", "text": line_2},
                                                {"speaker": "Mina", "text": line_3},
                                            ],
                                            "impliedSituationLabel": implied_label,
                                            "contextElements": ["problem", "constraint", "request"],
                                            "correctOptionText": correct_option,
                                            "distractorOptionTexts": [
                                                distractor_b,
                                                distractor_c,
                                                "Practice alone tonight and ignore the room issue.",
                                                "Borrow sports equipment from the gym office.",
                                            ],
                                            "plausibleDistractorLabels": ["B", "C"],
                                            "evidenceTurnIndexes": [1, 2, 3],
                                            "contextInferenceScore": 72,
                                            "directCluePenalty": 10,
                                            "finalTurnOnlySolvable": False,
                                            "whyCorrectKo": why_correct,
                                            "whyWrongKoByOption": {
                                                "B": why_wrong_b,
                                                "C": "교사 승인 없이 취소하는 것은 과도합니다.",
                                                "D": "연습만으로는 장소 문제를 해결하지 못합니다.",
                                                "E": "체육 장비는 상황과 무관합니다.",
                                            },
                                        }
                                    ]
                                },
                                ensure_ascii=False,
                            )
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    def fake_urlopen(request, timeout):
        captured_payload.update(json.loads(request.data.decode("utf-8")))
        observed_timeout.append(timeout)
        return _Response()

    monkeypatch.setattr("app.services.ai_content_provider.urllib_request.urlopen", fake_urlopen)

    result = _provider().generate_candidates(
        context=_h2_listening_context(ContentTypeTag.L_SITUATION)
    )

    assert result.prompt_template_version == "content-v1-listening-situation-contextual"
    assert result.generation_mode == L_SITUATION_CONTEXTUAL_GENERATION_MODE
    assert result.generation_profile == "H2_L_SITUATION_CONTEXTUAL"
    assert result.timeout_seconds == 60
    assert observed_timeout == [60]
    assert (
        '"generationProfile":"H2_L_SITUATION_CONTEXTUAL"'
        in captured_payload["messages"][1]["content"]
    )
    assert result.candidates[0].track == Track.H2
    assert len(result.candidates[0].turns) == 3


def test_openai_provider_uses_h1_r_blank_outline_profile_and_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    observed_timeout: list[int] = []
    blank_before_1 = (
        "Many students assume that careful planning begins only after a project "
        "falls apart, so they postpone difficult choices until the last minute."
    )
    blank_before_2 = (
        "However, strong planners often do the opposite: they test their "
        "assumptions early, compare several explanations, and ask what evidence "
        "would force them to change direction before the pressure becomes "
        "intense."
    )
    blank_after_1 = (
        "Because of that habit, they notice weak reasoning while revision is "
        "still possible, and they can replace a convenient claim with one that "
        "actually matches the evidence they collected."
    )
    blank_after_2 = (
        "The result is not simply a cleaner final product but a more deliberate "
        "habit of thinking, since each revision teaches them how a judgment can "
        "improve when it is challenged from several angles."
    )
    blank_target = "planned self-questioning before pressure leads to stronger revision later"
    correct_blank = (
        "In other words, disciplined planning is less about predicting every "
        "detail in advance than about building checkpoints that expose weak "
        "reasoning before it hardens into a final claim."
    )

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
                                            "difficulty": 2,
                                            "typeTag": "R_BLANK",
                                            "contextBeforeBlank": [
                                                blank_before_1,
                                                blank_before_2,
                                            ],
                                            "contextAfterBlank": [
                                                blank_after_1,
                                                blank_after_2,
                                            ],
                                            "keyIdeaMap": [
                                                "early testing of assumptions",
                                                "revision guided by evidence",
                                                "deliberate habit of thinking",
                                            ],
                                            "blankTargetProposition": blank_target,
                                            "correctBlankText": correct_blank,
                                            "distractorBlankTexts": [
                                                (
                                                    "Students should finish a "
                                                    "project quickly and let "
                                                    "teachers handle revision later."
                                                ),
                                                (
                                                    "Planning matters only "
                                                    "after grammar mistakes "
                                                    "appear in a final draft."
                                                ),
                                                (
                                                    "Careful planners rarely "
                                                    "change their first "
                                                    "interpretation because "
                                                    "confidence matters most."
                                                ),
                                                (
                                                    "Students benefit most "
                                                    "when they avoid comparing "
                                                    "explanations and defend "
                                                    "the easiest claim."
                                                ),
                                            ],
                                            "discourseShiftLabel": "qualification",
                                            "paraphraseOnlyRisk": False,
                                            "requiresInferenceAcrossSentences": True,
                                            "structureComplexityScore": 72,
                                            "directCluePenalty": 10,
                                            "inferenceLoadScore": 68,
                                            "whyCorrectKo": (
                                                "앞뒤 문장의 논리를 연결하는 재정의 문장입니다."
                                            ),
                                            "whyWrongKoByOption": {
                                                "B": "교사 의존으로 글의 핵심과 어긋납니다.",
                                                "C": "문법만 강조해 논점을 축소합니다.",
                                                "D": "첫 해석을 고수해 글의 방향과 반대입니다.",
                                                "E": (
                                                    "여러 설명 비교를 부정해 "
                                                    "핵심 논리와 충돌합니다."
                                                ),
                                            },
                                        }
                                    ]
                                },
                                ensure_ascii=False,
                            )
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: observed_timeout.append(timeout) or _Response(),
    )

    result = _provider().generate_candidates(context=_reading_context(ContentTypeTag.R_BLANK))

    assert result.prompt_template_version == "content-v1-reading-blank-discourse"
    assert result.generation_mode == R_BLANK_OUTLINE_GENERATION_MODE
    assert result.generation_profile == "H1_R_BLANK_DISCOURSE"
    assert result.timeout_seconds == 60
    assert observed_timeout == [60]
    assert "[BLANK]" in (result.candidates[0].passage or "")


def test_openai_provider_uses_h1_r_order_outline_profile_and_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    observed_timeout: list[int] = []
    intro_1 = (
        "A school debate program wanted to understand why some first-year "
        "members began contributing more thoughtful arguments during the second "
        "semester."
    )
    intro_2 = (
        "The change did not occur simply because students spoke more often; it "
        "appeared after the club altered the way members prepared for each "
        "discussion and the standard they used to judge whether an explanation "
        "was ready to share."
    )
    segment_a = (
        "At first, the club emphasized quick reactions, so many students "
        "repeated familiar opinions without testing whether those claims "
        "actually matched the evidence in the prompt. Faster answers often "
        "looked impressive even when the reasoning underneath them remained "
        "thin and unstable."
    )
    segment_b = (
        "Later, coaches required students to map possible counterarguments "
        "before each session, which forced them to compare weak explanations "
        "with stronger ones and revise their position in advance. That extra "
        "preparation made unsupported claims easier to notice before the "
        "discussion began."
    )
    segment_c = (
        "As a consequence, students began entering discussions with fewer but "
        "better-supported claims, and their classmates responded to the depth "
        "of the reasoning rather than to the speed of delivery alone. The club "
        "also started valuing slower but better-evidenced answers over quick "
        "but shallow responses."
    )

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
                                            "difficulty": 2,
                                            "typeTag": "R_ORDER",
                                            "introductionSentences": [
                                                intro_1,
                                                intro_2,
                                            ],
                                            "segmentTexts": {
                                                "A": segment_a,
                                                "B": segment_b,
                                                "C": segment_c,
                                            },
                                            "correctOrder": ["A", "B", "C"],
                                            "plausibleDistractorOrders": ["B-A-C", "A-C-B"],
                                            "discourseRelationLabels": [
                                                "contrast",
                                                "consequence",
                                                "elaboration",
                                            ],
                                            "cueWordOnlySolvable": False,
                                            "transitionComplexityScore": 70,
                                            "structureComplexityScore": 74,
                                            "directCluePenalty": 9,
                                            "whyCorrectKo": "문제-변화-결과 흐름이 유지됩니다.",
                                            "whyWrongKoByOption": {
                                                "B": (
                                                    "변화가 문제보다 먼저 나오면 인과가 흐려집니다."
                                                ),
                                                "C": "결과가 설명보다 먼저 나오면 흐름이 깨집니다.",
                                                "D": "원인과 결과가 교차되어 흐름이 어색합니다.",
                                                "E": "초기 문제 제시 없이 결과를 먼저 두게 됩니다.",
                                            },
                                        }
                                    ]
                                },
                                ensure_ascii=False,
                            )
                        }
                    }
                ]
            }
            return json.dumps(payload, ensure_ascii=False).encode("utf-8")

    monkeypatch.setattr(
        "app.services.ai_content_provider.urllib_request.urlopen",
        lambda request, timeout: observed_timeout.append(timeout) or _Response(),
    )

    result = _provider().generate_candidates(context=_reading_context(ContentTypeTag.R_ORDER))

    assert result.prompt_template_version == "content-v1-reading-order-discourse"
    assert result.generation_mode == R_ORDER_OUTLINE_GENERATION_MODE
    assert result.generation_profile == "H1_R_ORDER_DISCOURSE"
    assert result.timeout_seconds == 60
    assert observed_timeout == [60]
    assert result.candidates[0].options["A"] == "A-B-C"
