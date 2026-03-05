from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import json
from typing import Any, Protocol
from urllib import error as urllib_error
from urllib import request as urllib_request

from app.core.config import settings
from app.core.policies import AI_PROVIDER_HTTP_TIMEOUT_SECONDS
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill, Track
from app.services.ai_provider import AIProviderError


@dataclass(frozen=True, slots=True)
class ContentGenerationTarget:
    track: Track
    skill: Skill
    type_tag: ContentTypeTag
    difficulty: int
    count: int


@dataclass(frozen=True, slots=True)
class ContentGenerationContext:
    request_id: str
    target_matrix: list[ContentGenerationTarget]
    candidate_count_per_target: int
    dry_run: bool
    notes: str | None


@dataclass(frozen=True, slots=True)
class GeneratedContentCandidate:
    track: Track
    skill: Skill
    type_tag: ContentTypeTag
    difficulty: int
    source_policy: ContentSourcePolicy
    title: str | None
    passage: str | None
    transcript: str | None
    turns: list[dict[str, str]]
    sentences: list[dict[str, str]]
    tts_plan: dict[str, Any]
    stem: str
    options: dict[str, str]
    answer_key: str
    explanation: str
    evidence_sentence_ids: list[str]
    why_correct_ko: str
    why_wrong_ko_by_option: dict[str, str]
    vocab_notes_ko: str | None
    structure_notes_ko: str | None


@dataclass(frozen=True, slots=True)
class ContentGenerationResult:
    provider_name: str
    model_name: str
    prompt_template_version: str
    raw_prompt: str
    raw_response: str
    candidates: list[GeneratedContentCandidate]


class AIContentGenerationProvider(Protocol):
    def generate_candidates(self, *, context: ContentGenerationContext) -> ContentGenerationResult: ...


class DeterministicAIContentProvider:
    def __init__(self, *, model_name: str, prompt_template_version: str) -> None:
        self._provider_name = "fake"
        self._model_name = model_name
        self._prompt_template_version = prompt_template_version

    def generate_candidates(self, *, context: ContentGenerationContext) -> ContentGenerationResult:
        prompt_payload = _build_prompt_payload(context=context)
        candidates: list[GeneratedContentCandidate] = []
        counter = 1

        for target in context.target_matrix:
            for _ in range(target.count * context.candidate_count_per_target):
                candidates.append(
                    _build_deterministic_candidate(
                        index=counter,
                        target=target,
                    )
                )
                counter += 1

        response_payload = {
            "candidates": [_candidate_to_json_payload(candidate) for candidate in candidates],
        }
        return ContentGenerationResult(
            provider_name=self._provider_name,
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(prompt_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=json.dumps(response_payload, ensure_ascii=False, separators=(",", ":")),
            candidates=candidates,
        )


class OpenAIContentGenerationProvider:
    def __init__(
        self,
        *,
        api_key: str,
        model_name: str,
        prompt_template_version: str,
        base_url: str,
    ) -> None:
        self._api_key = api_key
        self._model_name = model_name
        self._prompt_template_version = prompt_template_version
        self._endpoint = f"{base_url.rstrip('/')}/v1/chat/completions"

    def generate_candidates(self, *, context: ContentGenerationContext) -> ContentGenerationResult:
        prompt_payload = _build_prompt_payload(context=context)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": _system_instruction()},
                {
                    "role": "user",
                    "content": json.dumps(prompt_payload, ensure_ascii=False, separators=(",", ":")),
                },
            ],
        }
        response_body = _post_json(
            url=self._endpoint,
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            payload=request_payload,
        )
        response_data = _parse_json_object(response_body)

        try:
            raw_content = response_data["choices"][0]["message"]["content"]
        except Exception as exc:
            raise AIProviderError(
                code="PROVIDER_BAD_RESPONSE",
                message="OpenAI response is missing structured content.",
                transient=False,
            ) from exc

        if not isinstance(raw_content, str):
            raise AIProviderError(
                code="PROVIDER_BAD_RESPONSE",
                message="OpenAI response content must be a string.",
                transient=False,
            )

        candidates = _parse_generated_candidates(raw_content)
        return ContentGenerationResult(
            provider_name="openai",
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            candidates=candidates,
        )


class AnthropicContentGenerationProvider:
    def __init__(
        self,
        *,
        api_key: str,
        model_name: str,
        prompt_template_version: str,
        base_url: str,
    ) -> None:
        self._api_key = api_key
        self._model_name = model_name
        self._prompt_template_version = prompt_template_version
        self._endpoint = f"{base_url.rstrip('/')}/v1/messages"

    def generate_candidates(self, *, context: ContentGenerationContext) -> ContentGenerationResult:
        prompt_payload = _build_prompt_payload(context=context)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "max_tokens": 4096,
            "system": _system_instruction(),
            "messages": [
                {
                    "role": "user",
                    "content": json.dumps(prompt_payload, ensure_ascii=False, separators=(",", ":")),
                }
            ],
        }
        response_body = _post_json(
            url=self._endpoint,
            headers={
                "x-api-key": self._api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            payload=request_payload,
        )
        response_data = _parse_json_object(response_body)

        try:
            raw_content = response_data["content"][0]["text"]
        except Exception as exc:
            raise AIProviderError(
                code="PROVIDER_BAD_RESPONSE",
                message="Anthropic response is missing structured content.",
                transient=False,
            ) from exc

        if not isinstance(raw_content, str):
            raise AIProviderError(
                code="PROVIDER_BAD_RESPONSE",
                message="Anthropic response content must be a string.",
                transient=False,
            )

        candidates = _parse_generated_candidates(raw_content)
        return ContentGenerationResult(
            provider_name="anthropic",
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            candidates=candidates,
        )


def build_ai_content_generation_provider(*, provider_override: str | None = None) -> AIContentGenerationProvider:
    provider_name = provider_override.strip().lower() if provider_override is not None else settings.ai_generation_provider.strip().lower()
    if provider_name in {"", "disabled", "none"}:
        raise AIProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI content generation provider is not configured.",
            transient=False,
        )

    if provider_name == "fake":
        return DeterministicAIContentProvider(
            model_name=settings.ai_content_model,
            prompt_template_version=settings.ai_content_prompt_template_version,
        )

    api_key = settings.ai_generation_api_key
    if api_key is None:
        raise AIProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI provider API key is missing.",
            transient=False,
        )

    if provider_name == "openai":
        return OpenAIContentGenerationProvider(
            api_key=api_key,
            model_name=settings.ai_content_model,
            prompt_template_version=settings.ai_content_prompt_template_version,
            base_url=settings.ai_openai_base_url,
        )

    if provider_name == "anthropic":
        return AnthropicContentGenerationProvider(
            api_key=api_key,
            model_name=settings.ai_content_model,
            prompt_template_version=settings.ai_content_prompt_template_version,
            base_url=settings.ai_anthropic_base_url,
        )

    raise AIProviderError(
        code="PROVIDER_NOT_CONFIGURED",
        message=f"Unsupported AI provider: {provider_name}",
        transient=False,
    )


def _build_deterministic_candidate(*, index: int, target: ContentGenerationTarget) -> GeneratedContentCandidate:
    sentence_ids = ["s1", "s2", "s3"]
    options = {
        "A": f"Correct option for {target.type_tag.value} {index}",
        "B": f"Distractor option B for {target.type_tag.value} {index}",
        "C": f"Distractor option C for {target.type_tag.value} {index}",
        "D": f"Distractor option D for {target.type_tag.value} {index}",
        "E": f"Distractor option E for {target.type_tag.value} {index}",
    }
    why_wrong = {
        "A": "정답 보기입니다.",
        "B": "핵심 근거를 잘못 해석했습니다.",
        "C": "지문에 없는 내용을 추론했습니다.",
        "D": "부분 정보만 보고 판단했습니다.",
        "E": "유사 표현에 현혹되었습니다.",
    }

    if target.skill == Skill.READING:
        passage = (
            f"Track {target.track.value} reading passage for {target.type_tag.value}. "
            f"Difficulty level {target.difficulty}. The message emphasizes careful evidence tracking."
        )
        sentences = [
            {"id": "s1", "text": "The speaker introduces the main context in clear terms."},
            {"id": "s2", "text": "A key supporting detail explains the intended interpretation."},
            {"id": "s3", "text": "The final sentence narrows the best answer to one option."},
        ]
        return GeneratedContentCandidate(
            track=target.track,
            skill=target.skill,
            type_tag=target.type_tag,
            difficulty=target.difficulty,
            source_policy=ContentSourcePolicy.AI_ORIGINAL,
            title=f"{target.track.value} Reading {target.type_tag.value} #{index}",
            passage=passage,
            transcript=None,
            turns=[],
            sentences=sentences,
            tts_plan={},
            stem=f"What is the best answer for reading item {index}?",
            options=options,
            answer_key="A",
            explanation="Option A is correct because it matches the explicit evidence in sentence s2.",
            evidence_sentence_ids=sentence_ids[:2],
            why_correct_ko="근거 문장 s2의 핵심 의미와 정답 선택지가 일치합니다.",
            why_wrong_ko_by_option=why_wrong,
            vocab_notes_ko="핵심 표현은 evidence tracking입니다.",
            structure_notes_ko="도입-근거-결론 구조로 읽으면 정답 근거가 분명합니다.",
        )

    turns = [
        {"speaker": "A", "text": "Could you summarize the key point from the meeting?"},
        {"speaker": "B", "text": "Sure. We should focus on evidence before making a decision."},
    ]
    sentences = [
        {"id": "s1", "text": turns[0]["text"]},
        {"id": "s2", "text": turns[1]["text"]},
    ]
    transcript = "\n".join(f"{turn['speaker']}: {turn['text']}" for turn in turns)
    return GeneratedContentCandidate(
        track=target.track,
        skill=target.skill,
        type_tag=target.type_tag,
        difficulty=target.difficulty,
        source_policy=ContentSourcePolicy.AI_ORIGINAL,
        title=f"{target.track.value} Listening {target.type_tag.value} #{index}",
        passage=None,
        transcript=transcript,
        turns=turns,
        sentences=sentences,
        tts_plan={"voice": "en-US-neutral", "pace": "normal"},
        stem=f"What is the best response for listening item {index}?",
        options=options,
        answer_key="A",
        explanation="Option A is correct because it reflects the explicit instruction in sentence s2.",
        evidence_sentence_ids=["s2"],
        why_correct_ko="문장 s2에서 의사결정 전에 근거를 확인해야 한다고 명시합니다.",
        why_wrong_ko_by_option=why_wrong,
        vocab_notes_ko="evidence, decision 같은 핵심 어휘를 확인하세요.",
        structure_notes_ko="요청-응답 구조이므로 응답 화자의 핵심 문장을 우선 확인하세요.",
    )


def _candidate_to_json_payload(candidate: GeneratedContentCandidate) -> dict[str, Any]:
    return {
        "track": candidate.track.value,
        "skill": candidate.skill.value,
        "typeTag": candidate.type_tag.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": candidate.source_policy.value,
        "title": candidate.title,
        "passage": candidate.passage,
        "transcript": candidate.transcript,
        "turns": candidate.turns,
        "sentences": candidate.sentences,
        "ttsPlan": candidate.tts_plan,
        "question": {
            "stem": candidate.stem,
            "options": candidate.options,
            "answerKey": candidate.answer_key,
            "explanation": candidate.explanation,
            "evidenceSentenceIds": candidate.evidence_sentence_ids,
            "whyCorrectKo": candidate.why_correct_ko,
            "whyWrongKoByOption": candidate.why_wrong_ko_by_option,
            "vocabNotesKo": candidate.vocab_notes_ko,
            "structureNotesKo": candidate.structure_notes_ko,
        },
    }


def _build_prompt_payload(*, context: ContentGenerationContext) -> dict[str, Any]:
    return {
        "generatedAt": datetime.now(UTC).isoformat(),
        "requestId": context.request_id,
        "candidateCountPerTarget": context.candidate_count_per_target,
        "dryRun": context.dry_run,
        "notes": context.notes,
        "targetMatrix": [
            {
                "track": row.track.value,
                "skill": row.skill.value,
                "typeTag": row.type_tag.value,
                "difficulty": row.difficulty,
                "count": row.count,
            }
            for row in context.target_matrix
        ],
    }


def _system_instruction() -> str:
    return (
        "Generate English-learning content units and return strict JSON only. "
        "Top-level key must be candidates (array). "
        "Each candidate must include track, skill, typeTag, difficulty, sourcePolicy, "
        "passage or transcript, sentences, question(stem/options/answerKey/explanation/evidenceSentenceIds/"
        "whyCorrectKo/whyWrongKoByOption). "
        "Do not include markdown or surrounding prose."
    )


def _post_json(*, url: str, headers: dict[str, str], payload: dict[str, Any]) -> str:
    encoded_payload = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib_request.Request(
        url=url,
        data=encoded_payload,
        headers=headers,
        method="POST",
    )
    try:
        with urllib_request.urlopen(request, timeout=AI_PROVIDER_HTTP_TIMEOUT_SECONDS) as response:
            body = response.read()
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        transient = exc.code in {408, 409, 425, 429, 500, 502, 503, 504}
        raise AIProviderError(
            code="PROVIDER_BAD_RESPONSE",
            message=f"Provider HTTP error {exc.code}: {body[:400]}",
            transient=transient,
        ) from exc
    except urllib_error.URLError as exc:
        raise AIProviderError(
            code="PROVIDER_TIMEOUT",
            message=f"Provider network error: {exc.reason}",
            transient=True,
        ) from exc
    except TimeoutError as exc:
        raise AIProviderError(
            code="PROVIDER_TIMEOUT",
            message="Provider request timed out.",
            transient=True,
        ) from exc

    return body.decode("utf-8")


def _parse_json_object(payload: str) -> dict[str, Any]:
    try:
        decoded = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise AIProviderError(
            code="PROVIDER_BAD_RESPONSE",
            message="Provider response is not valid JSON.",
            transient=False,
        ) from exc

    if not isinstance(decoded, dict):
        raise AIProviderError(
            code="PROVIDER_BAD_RESPONSE",
            message="Provider response payload must be a JSON object.",
            transient=False,
        )
    return decoded


def _parse_generated_candidates(raw_content: str) -> list[GeneratedContentCandidate]:
    payload = _parse_json_object(raw_content)
    raw_candidates = payload.get("candidates")
    if not isinstance(raw_candidates, list) or not raw_candidates:
        raise AIProviderError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must include a non-empty candidates array.",
            transient=False,
        )

    parsed: list[GeneratedContentCandidate] = []
    for raw_candidate in raw_candidates:
        if not isinstance(raw_candidate, dict):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Candidate item must be an object.",
                transient=False,
            )

        question = raw_candidate.get("question")
        if not isinstance(question, dict):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Candidate question must be an object.",
                transient=False,
            )

        options = question.get("options")
        if not isinstance(options, dict):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Candidate options must be an object.",
                transient=False,
            )

        parsed.append(
            GeneratedContentCandidate(
                track=Track(str(raw_candidate.get("track"))),
                skill=Skill(str(raw_candidate.get("skill"))),
                type_tag=ContentTypeTag(str(raw_candidate.get("typeTag"))),
                difficulty=int(raw_candidate.get("difficulty")),
                source_policy=ContentSourcePolicy(str(raw_candidate.get("sourcePolicy", "AI_ORIGINAL"))),
                title=_to_optional_str(raw_candidate.get("title")),
                passage=_to_optional_str(raw_candidate.get("passage")),
                transcript=_to_optional_str(raw_candidate.get("transcript")),
                turns=_parse_turns(raw_candidate.get("turns")),
                sentences=_parse_sentences(raw_candidate.get("sentences")),
                tts_plan=_parse_object(raw_candidate.get("ttsPlan"), default={}),
                stem=str(question.get("stem", "")),
                options={str(key): str(value) for key, value in options.items()},
                answer_key=str(question.get("answerKey", "")),
                explanation=str(question.get("explanation", "")),
                evidence_sentence_ids=[str(value) for value in question.get("evidenceSentenceIds", [])],
                why_correct_ko=str(question.get("whyCorrectKo", "")),
                why_wrong_ko_by_option={
                    str(key): str(value)
                    for key, value in _parse_object(question.get("whyWrongKoByOption"), default={}).items()
                },
                vocab_notes_ko=_to_optional_str(question.get("vocabNotesKo")),
                structure_notes_ko=_to_optional_str(question.get("structureNotesKo")),
            )
        )

    return parsed


def _to_optional_str(value: object) -> str | None:
    if value is None:
        return None
    return str(value)


def _parse_object(value: object, *, default: dict[str, Any]) -> dict[str, Any]:
    if value is None:
        return default
    if not isinstance(value, dict):
        raise AIProviderError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Expected object payload.",
            transient=False,
        )
    return value


def _parse_turns(value: object) -> list[dict[str, str]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise AIProviderError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Turns must be an array.",
            transient=False,
        )

    parsed: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Turn item must be an object.",
                transient=False,
            )
        speaker = item.get("speaker")
        text = item.get("text")
        if not isinstance(speaker, str) or not isinstance(text, str):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Turn item requires string speaker/text.",
                transient=False,
            )
        parsed.append({"speaker": speaker, "text": text})
    return parsed


def _parse_sentences(value: object) -> list[dict[str, str]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise AIProviderError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Sentences must be an array.",
            transient=False,
        )

    parsed: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Sentence item must be an object.",
                transient=False,
            )
        sentence_id = item.get("id")
        text = item.get("text")
        if not isinstance(sentence_id, str) or not isinstance(text, str):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Sentence item requires string id/text.",
                transient=False,
            )
        parsed.append({"id": sentence_id, "text": text})
    return parsed
