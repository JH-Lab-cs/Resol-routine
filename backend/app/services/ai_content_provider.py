from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Protocol
from urllib import error as urllib_error
from urllib import request as urllib_request

from app.core.config import settings
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill, Track
from app.services.ai_provider import AIProviderError
from app.services.l_response_generation_service import (
    L_RESPONSE_COMPILER_VERSION,
    L_RESPONSE_GENERATION_MODE,
    L_RESPONSE_PROMPT_TEMPLATE_SUFFIX,
    build_deterministic_l_response_skeleton,
    compile_l_response_skeleton_candidate,
    parse_l_response_generation_candidates,
    serialize_l_response_skeleton_candidate,
)


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
    raw_candidate_payloads: list[dict[str, Any]] | None = None
    compiled_candidate_payloads: list[dict[str, Any]] | None = None
    generation_mode: str = "CANONICAL"
    compiler_version: str | None = None


@dataclass(frozen=True, slots=True)
class PromptProfile:
    template_version: str
    skill_mode: str
    target_type_tags: tuple[str, ...]
    instructions: tuple[str, ...]
    generation_mode: str = "CANONICAL"


@dataclass(frozen=True, slots=True)
class ParsedGeneratedCandidateBatch:
    candidates: list[GeneratedContentCandidate]
    raw_candidate_payloads: list[dict[str, Any]]
    compiled_candidate_payloads: list[dict[str, Any]]
    generation_mode: str
    compiler_version: str | None


class AIContentGenerationProvider(Protocol):
    def generate_candidates(
        self, *, context: ContentGenerationContext
    ) -> ContentGenerationResult: ...


class DeterministicAIContentProvider:
    def __init__(self, *, model_name: str, prompt_template_version: str) -> None:
        self._provider_name = "fake"
        self._model_name = model_name
        self._prompt_template_version = prompt_template_version

    def generate_candidates(self, *, context: ContentGenerationContext) -> ContentGenerationResult:
        prompt_profile = _resolve_prompt_profile(
            context=context,
            base_template_version=self._prompt_template_version,
        )
        prompt_payload = _build_prompt_payload(context=context, prompt_profile=prompt_profile)
        candidates: list[GeneratedContentCandidate] = []
        raw_candidate_payloads: list[dict[str, Any]] = []
        compiled_candidate_payloads: list[dict[str, Any]] = []
        counter = 1

        for target in context.target_matrix:
            for _ in range(target.count * context.candidate_count_per_target):
                if (
                    prompt_profile.generation_mode == L_RESPONSE_GENERATION_MODE
                    and target.type_tag == ContentTypeTag.L_RESPONSE
                ):
                    skeleton = build_deterministic_l_response_skeleton(
                        track=target.track,
                        difficulty=target.difficulty,
                        index=counter,
                    )
                    compiled_payload = compile_l_response_skeleton_candidate(skeleton)
                    raw_candidate_payloads.append(
                        serialize_l_response_skeleton_candidate(skeleton)
                    )
                    compiled_candidate_payloads.append(compiled_payload)
                    candidates.append(_parse_generated_candidate_payload(compiled_payload))
                else:
                    candidate = _build_deterministic_candidate(
                        index=counter,
                        target=target,
                    )
                    candidate_payload = _candidate_to_json_payload(candidate)
                    raw_candidate_payloads.append(candidate_payload)
                    compiled_candidate_payloads.append(candidate_payload)
                    candidates.append(candidate)
                counter += 1

        response_payload = {
            "candidates": raw_candidate_payloads,
        }
        return ContentGenerationResult(
            provider_name=self._provider_name,
            model_name=self._model_name,
            prompt_template_version=prompt_profile.template_version,
            raw_prompt=json.dumps(prompt_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=json.dumps(response_payload, ensure_ascii=False, separators=(",", ":")),
            candidates=candidates,
            raw_candidate_payloads=raw_candidate_payloads,
            compiled_candidate_payloads=compiled_candidate_payloads,
            generation_mode=prompt_profile.generation_mode,
            compiler_version=(
                L_RESPONSE_COMPILER_VERSION
                if prompt_profile.generation_mode == L_RESPONSE_GENERATION_MODE
                else None
            ),
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
        prompt_profile = _resolve_prompt_profile(
            context=context,
            base_template_version=self._prompt_template_version,
        )
        prompt_payload = _build_prompt_payload(context=context, prompt_profile=prompt_profile)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": _system_instruction(prompt_profile=prompt_profile)},
                {
                    "role": "user",
                    "content": json.dumps(
                        prompt_payload, ensure_ascii=False, separators=(",", ":")
                    ),
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

        parsed_candidates = _parse_generated_candidates(raw_content, prompt_profile=prompt_profile)
        return ContentGenerationResult(
            provider_name="openai",
            model_name=self._model_name,
            prompt_template_version=prompt_profile.template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            candidates=parsed_candidates.candidates,
            raw_candidate_payloads=parsed_candidates.raw_candidate_payloads,
            compiled_candidate_payloads=parsed_candidates.compiled_candidate_payloads,
            generation_mode=parsed_candidates.generation_mode,
            compiler_version=parsed_candidates.compiler_version,
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
        prompt_profile = _resolve_prompt_profile(
            context=context,
            base_template_version=self._prompt_template_version,
        )
        prompt_payload = _build_prompt_payload(context=context, prompt_profile=prompt_profile)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "max_tokens": 4096,
            "system": _system_instruction(prompt_profile=prompt_profile),
            "messages": [
                {
                    "role": "user",
                    "content": json.dumps(
                        prompt_payload, ensure_ascii=False, separators=(",", ":")
                    ),
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

        parsed_candidates = _parse_generated_candidates(raw_content, prompt_profile=prompt_profile)
        return ContentGenerationResult(
            provider_name="anthropic",
            model_name=self._model_name,
            prompt_template_version=prompt_profile.template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            candidates=parsed_candidates.candidates,
            raw_candidate_payloads=parsed_candidates.raw_candidate_payloads,
            compiled_candidate_payloads=parsed_candidates.compiled_candidate_payloads,
            generation_mode=parsed_candidates.generation_mode,
            compiler_version=parsed_candidates.compiler_version,
        )


def build_ai_content_generation_provider(
    *,
    provider_override: str | None = None,
    model_override: str | None = None,
    prompt_template_version_override: str | None = None,
) -> AIContentGenerationProvider:
    provider_name = (
        provider_override.strip().lower()
        if provider_override is not None
        else settings.resolved_ai_content_provider.strip().lower()
    )
    if provider_name in {"", "disabled", "none"}:
        raise AIProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI content generation provider is not configured.",
            transient=False,
        )

    model_name = (
        model_override.strip()
        if model_override is not None
        else settings.ai_content_model.strip()
    )
    if model_name in {"", "not-configured"}:
        raise AIProviderError(
            code="PROVIDER_MODEL_NOT_SET",
            message="AI content generation model is not configured.",
            transient=False,
        )

    prompt_template_version = (
        prompt_template_version_override.strip()
        if prompt_template_version_override is not None
        else settings.ai_content_prompt_template_version.strip()
    )
    if not prompt_template_version or prompt_template_version == "not-configured":
        raise AIProviderError(
            code="PROVIDER_MODEL_NOT_SET",
            message="AI content prompt template version is not configured.",
            transient=False,
        )

    if provider_name == "fake":
        return DeterministicAIContentProvider(
            model_name=model_name,
            prompt_template_version=prompt_template_version,
        )

    api_key = settings.resolved_ai_content_api_key
    if api_key is None:
        raise AIProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI provider API key is missing.",
            transient=False,
        )

    if provider_name == "openai":
        return OpenAIContentGenerationProvider(
            api_key=api_key,
            model_name=model_name,
            prompt_template_version=prompt_template_version,
            base_url=settings.ai_openai_base_url,
        )

    if provider_name == "anthropic":
        return AnthropicContentGenerationProvider(
            api_key=api_key,
            model_name=model_name,
            prompt_template_version=prompt_template_version,
            base_url=settings.ai_anthropic_base_url,
        )

    raise AIProviderError(
        code="PROVIDER_NOT_CONFIGURED",
        message=f"Unsupported AI provider: {provider_name}",
        transient=False,
    )


_HARD_TYPETAG_TEMPLATE_SUFFIX = {
    "L_LONG_TALK": "listening-longtalk",
    "L_RESPONSE": L_RESPONSE_PROMPT_TEMPLATE_SUFFIX,
    "L_SITUATION": "listening-situation",
    "R_INSERTION": "reading-insertion",
    "R_BLANK": "reading-blank",
    "R_ORDER": "reading-order",
    "R_SUMMARY": "reading-summary",
    "R_VOCAB": "reading-vocab",
}

_HARD_TYPETAG_RULES = {
    "L_LONG_TALK": (
        "Produce at least four turns and at least four sentence rows.",
        (
            "Every turn text must appear verbatim inside transcriptText and the "
            "transcript order must match turns order."
        ),
        "Use evidenceSentenceIds that point to explicit sentence ids only.",
        "Keep options A..E mutually exclusive and explanation complete enough for human review.",
    ),
    "L_RESPONSE": (
        "Produce exactly two turns only and keep the final turn as the response prompt.",
        "Return only the response-item skeleton, not the final canonical question payload.",
        "Use evidenceTurnIndexes with 1-based indexes that point only to the existing turns.",
        (
            "correctResponseText must be short spoken-style English and "
            "distractorResponseTexts must contain exactly four distinct replies."
        ),
    ),
    "L_SITUATION": (
        "Produce at least two turns and at least three sentence rows.",
        "The situation must be inferable from dialogue evidence, not from unstated assumptions.",
        "Keep transcript, turns, and sentence ids fully aligned.",
    ),
    "R_INSERTION": (
        "Passage must include insertion markers [1], [2], [3], and [4].",
        "Question options A..E must represent insertion positions or a no-fit distractor.",
        (
            "EvidenceSentenceIds must point to the discourse sentences that "
            "justify the insertion location."
        ),
    ),
    "R_BLANK": (
        "Passage must include exactly one [BLANK] marker.",
        "Question must ask for the best phrase or sentence to fill the blank.",
        "Use evidenceSentenceIds that point to context sentences surrounding [BLANK].",
    ),
    "R_ORDER": (
        "Provide at least four sentence rows so order can be resolved from discourse flow.",
        "Explanation must describe the sequence logic explicitly.",
    ),
    "R_SUMMARY": (
        "Provide at least four sentence rows so the summary is grounded in the passage.",
        (
            "Distractors must omit or distort at least one key idea rather "
            "than paraphrasing the answer."
        ),
    ),
    "R_VOCAB": (
        "Question must ask about the meaning of a target word or phrase in context.",
        "The passage must contain the target expression explicitly.",
        "Explanation must tie the answer to the local context, not a dictionary gloss alone.",
    ),
}

_DEFAULT_PROMPT_RULES = (
    "Return strict JSON only. Do not include markdown or prose outside the JSON object.",
    "question.options must contain exactly A, B, C, D, and E with unique option text.",
    "answerKey must be exactly one of A, B, C, D, or E.",
    "evidenceSentenceIds must contain only ids that exist in sentences[].",
    "whyCorrectKo and whyWrongKoByOption must be complete and reviewer-friendly.",
)


def _build_deterministic_candidate(
    *, index: int, target: ContentGenerationTarget
) -> GeneratedContentCandidate:
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
            f"Difficulty level {target.difficulty}. "
            "The message emphasizes careful evidence tracking."
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
            explanation=(
                "Option A is correct because it matches the explicit evidence in sentence s2."
            ),
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
        explanation=(
            "Option A is correct because it reflects the explicit instruction in sentence s2."
        ),
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


def _build_prompt_payload(
    *, context: ContentGenerationContext, prompt_profile: PromptProfile
) -> dict[str, Any]:
    return {
        "generatedAt": datetime.now(UTC).isoformat(),
        "requestId": context.request_id,
        "promptTemplateVersion": prompt_profile.template_version,
        "generationMode": prompt_profile.generation_mode,
        "promptSkillMode": prompt_profile.skill_mode,
        "promptTargetTypeTags": list(prompt_profile.target_type_tags),
        "candidateCountPerTarget": context.candidate_count_per_target,
        "dryRun": context.dry_run,
        "notes": context.notes,
        "strictOutputChecklist": list(_DEFAULT_PROMPT_RULES),
        "typeTagSpecificRequirements": list(prompt_profile.instructions),
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


def _system_instruction(*, prompt_profile: PromptProfile) -> str:
    if prompt_profile.generation_mode == L_RESPONSE_GENERATION_MODE:
        joined_type_rules = " ".join(prompt_profile.instructions)
        return "".join(
            [
                "Generate English-learning LISTENING response items and return strict JSON only. ",
                "Top-level key must be candidates (array). ",
                (
                    "Each candidate must include track, difficulty, typeTag, turns, "
                    "responsePromptSpeaker, correctResponseText, distractorResponseTexts, "
                    "evidenceTurnIndexes, whyCorrectKo, and whyWrongKoByOption. "
                ),
                (
                    "Do not include question, options, answerKey, explanation, "
                    "transcriptText, sentences, or ttsPlan. "
                ),
                "typeTag must be exactly L_RESPONSE. ",
                "turns must contain exactly two objects with speaker and text. ",
                "responsePromptSpeaker must equal the speaker of the final turn. ",
                (
                    "correctResponseText must be the best short spoken-style reply to the "
                    "final turn. "
                ),
                (
                    "distractorResponseTexts must contain exactly four distinct "
                    "spoken-style replies. "
                ),
                (
                    "whyWrongKoByOption must contain keys B, C, D, and E only, "
                    "in the same order as distractorResponseTexts. "
                ),
                "Use evidenceTurnIndexes as 1-based indexes, and point only to existing turns. ",
                f"TypeTag-specific requirements: {joined_type_rules} ",
                "Do not include markdown or any prose outside the JSON object.",
            ]
        )

    skill_rule = (
        "For READING candidates, bodyText/passage and sentences are required."
        if prompt_profile.skill_mode == "reading"
        else (
            "For LISTENING candidates, transcriptText/transcript, turns, "
            "sentences, and ttsPlan are required."
        )
        if prompt_profile.skill_mode == "listening"
        else (
            "For mixed batches, every candidate must satisfy its own "
            "skill-specific required fields."
        )
    )
    joined_type_rules = " ".join(prompt_profile.instructions)
    return (
        "Generate English-learning content units and return strict JSON only. "
        "Top-level key must be candidates (array). "
        "Every candidate must include track, skill, typeTag, difficulty, sourcePolicy, "
        "sentences, and question(stem/options/answerKey/explanation/evidenceSentenceIds/"
        "whyCorrectKo/whyWrongKoByOption). "
        "sourcePolicy must be exactly AI_ORIGINAL. "
        "question.options must contain exactly five options with keys A, B, C, D, and E, "
        "and all option texts must be unique. "
        "question.whyWrongKoByOption must also contain exactly A, B, C, D, and E. "
        "For the correct option, whyWrongKoByOption may say that it is the correct choice. "
        f"{skill_rule} "
        "turns must be an array of objects with speaker and text. "
        "sentences must be an array of objects with id and text. "
        "Every evidenceSentenceId must point to an existing sentence id. "
        "ttsPlan must be a non-empty object when skill is LISTENING. "
        "Example: {\"voice\":\"en-US-neutral\",\"pace\":\"normal\"}. "
        f"TypeTag-specific requirements: {joined_type_rules} "
        "Do not omit required fields, and do not include markdown or surrounding prose."
    )


def _resolve_prompt_profile(
    *, context: ContentGenerationContext, base_template_version: str
) -> PromptProfile:
    type_tags = tuple(dict.fromkeys(row.type_tag.value for row in context.target_matrix))
    skill_modes = {row.skill.value for row in context.target_matrix}
    if len(skill_modes) == 1:
        skill_mode = next(iter(skill_modes)).lower()
    else:
        skill_mode = "mixed"

    if len(type_tags) == 1 and type_tags[0] in _HARD_TYPETAG_TEMPLATE_SUFFIX:
        type_tag = type_tags[0]
        template_version = f"{base_template_version}-{_HARD_TYPETAG_TEMPLATE_SUFFIX[type_tag]}"
        instructions = _DEFAULT_PROMPT_RULES + _HARD_TYPETAG_RULES[type_tag]
        return PromptProfile(
            template_version=template_version,
            skill_mode=skill_mode,
            target_type_tags=type_tags,
            instructions=instructions,
            generation_mode=(
                L_RESPONSE_GENERATION_MODE
                if type_tag == ContentTypeTag.L_RESPONSE.value
                else "CANONICAL"
            ),
        )

    default_suffix = f"{skill_mode}-default"
    return PromptProfile(
        template_version=f"{base_template_version}-{default_suffix}",
        skill_mode=skill_mode,
        target_type_tags=type_tags,
        instructions=_DEFAULT_PROMPT_RULES,
    )


def _post_json(*, url: str, headers: dict[str, str], payload: dict[str, Any]) -> str:
    encoded_payload = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib_request.Request(  # noqa: S310
        url=url,
        data=encoded_payload,
        headers=headers,
        method="POST",
    )
    try:
        with urllib_request.urlopen(  # noqa: S310
            request,
            timeout=settings.ai_provider_http_timeout_seconds,
        ) as response:
            raw_body = response.read()
            body = raw_body if isinstance(raw_body, bytes) else bytes(raw_body)
    except urllib_error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        if exc.code in {401, 403}:
            code = "PROVIDER_AUTH_FAILED"
            transient = False
        elif exc.code == 429:
            code = "PROVIDER_RATE_LIMITED"
            transient = True
        elif exc.code in {408, 504}:
            code = "PROVIDER_TIMEOUT"
            transient = True
        else:
            code = "PROVIDER_BAD_RESPONSE"
            transient = exc.code in {409, 425, 500, 502, 503}
        raise AIProviderError(
            code=code,
            message=f"Provider HTTP error {exc.code}: {error_body[:400]}",
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

    decoded_body = body.decode("utf-8")
    return decoded_body


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


def _parse_generated_candidates(
    raw_content: str,
    *,
    prompt_profile: PromptProfile,
) -> ParsedGeneratedCandidateBatch:
    payload = _parse_json_object(raw_content)
    raw_candidates = payload.get("candidates")
    if not isinstance(raw_candidates, list) or not raw_candidates:
        raise AIProviderError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must include a non-empty candidates array.",
            transient=False,
        )

    if prompt_profile.generation_mode == L_RESPONSE_GENERATION_MODE:
        return _parse_l_response_candidate_batch(raw_content)

    compiled_payloads: list[dict[str, Any]] = []
    parsed: list[GeneratedContentCandidate] = []
    for raw_candidate in raw_candidates:
        if not isinstance(raw_candidate, dict):
            raise _output_error("OUTPUT_SCHEMA_INVALID", "Candidate item must be an object.")
        compiled_payloads.append(raw_candidate)
        parsed.append(_parse_generated_candidate_payload(raw_candidate))

    return ParsedGeneratedCandidateBatch(
        candidates=parsed,
        raw_candidate_payloads=compiled_payloads,
        compiled_candidate_payloads=compiled_payloads,
        generation_mode="CANONICAL",
        compiler_version=None,
    )


def _parse_generated_candidate_payload(raw_candidate: dict[str, Any]) -> GeneratedContentCandidate:
    question = raw_candidate.get("question")
    if not isinstance(question, dict):
        raise _output_error("OUTPUT_MISSING_FIELD", "Candidate question must be an object.")

    track = Track(str(raw_candidate.get("track")))
    skill = Skill(str(raw_candidate.get("skill")))
    passage = _to_optional_str(
        raw_candidate.get("passage")
        or raw_candidate.get("bodyText")
        or raw_candidate.get("passageText")
    )
    transcript = _to_optional_str(
        raw_candidate.get("transcript")
        or raw_candidate.get("transcriptText")
    )
    turns = _parse_turns(raw_candidate.get("turns"))
    sentences = _parse_sentences(raw_candidate.get("sentences"))
    if skill == Skill.LISTENING and turns and not sentences:
        sentences = _sentences_from_turns(turns)

    options = _parse_options(question.get("options"))
    why_wrong = _parse_why_wrong_by_option(
        value=question.get("whyWrongKoByOption"),
        answer_key=str(question.get("answerKey", "")),
    )

    return GeneratedContentCandidate(
        track=track,
        skill=skill,
        type_tag=ContentTypeTag(str(raw_candidate.get("typeTag"))),
        difficulty=_required_int(raw_candidate.get("difficulty")),
        source_policy=_parse_source_policy(raw_candidate.get("sourcePolicy")),
        title=_to_optional_str(raw_candidate.get("title")),
        passage=passage,
        transcript=transcript,
        turns=turns,
        sentences=sentences,
        tts_plan=_parse_tts_plan(raw_candidate.get("ttsPlan"), skill=skill),
        stem=str(question.get("stem") or question.get("questionStem") or ""),
        options=options,
        answer_key=_normalize_answer_key(question.get("answerKey") or question.get("answer")),
        explanation=str(
            question.get("explanation")
            or question.get("rationale")
            or question.get("why")
            or ""
        ),
        evidence_sentence_ids=_parse_evidence_sentence_ids(
            question.get("evidenceSentenceIds") or question.get("evidence"),
        ),
        why_correct_ko=str(question.get("whyCorrectKo") or question.get("whyCorrect") or ""),
        why_wrong_ko_by_option=why_wrong,
        vocab_notes_ko=_to_optional_str(question.get("vocabNotesKo")),
        structure_notes_ko=_to_optional_str(question.get("structureNotesKo")),
    )


def _parse_l_response_candidate_batch(raw_content: str) -> ParsedGeneratedCandidateBatch:
    try:
        skeletons = parse_l_response_generation_candidates(raw_content)
    except Exception as exc:
        if isinstance(exc, AIProviderError):
            raise
        code = getattr(exc, "code", "OUTPUT_SCHEMA_INVALID")
        message = getattr(exc, "message", str(exc))
        raise AIProviderError(
            code=str(code),
            message=str(message),
            transient=False,
        ) from exc

    raw_payloads = [serialize_l_response_skeleton_candidate(candidate) for candidate in skeletons]
    compiled_payloads: list[dict[str, Any]] = []
    parsed_candidates: list[GeneratedContentCandidate] = []
    for skeleton in skeletons:
        try:
            compiled_payload = compile_l_response_skeleton_candidate(skeleton)
        except Exception as exc:
            code = getattr(exc, "code", "OUTPUT_DETERMINISTIC_COMPILE_FAILED")
            message = getattr(exc, "message", str(exc))
            raise AIProviderError(
                code=str(code),
                message=str(message),
                transient=False,
            ) from exc
        compiled_payloads.append(compiled_payload)
        parsed_candidates.append(_parse_generated_candidate_payload(compiled_payload))

    return ParsedGeneratedCandidateBatch(
        candidates=parsed_candidates,
        raw_candidate_payloads=raw_payloads,
        compiled_candidate_payloads=compiled_payloads,
        generation_mode=L_RESPONSE_GENERATION_MODE,
        compiler_version=L_RESPONSE_COMPILER_VERSION,
    )


def _to_optional_str(value: object) -> str | None:
    if value is None:
        return None
    return str(value)


def _required_int(value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise _output_error("OUTPUT_MISSING_FIELD", "Required integer field is missing or invalid.")
    return value


def _parse_object(value: object, *, default: dict[str, Any]) -> dict[str, Any]:
    if value is None:
        return default
    if not isinstance(value, dict):
        raise _output_error("OUTPUT_SCHEMA_INVALID", "Expected object payload.")
    return value


def _parse_options(value: object) -> dict[str, str]:
    if isinstance(value, dict):
        parsed_from_object: dict[str, str] = {}
        for key, option_value in value.items():
            normalized_label = _normalize_option_label(key)
            normalized_text = _coerce_option_text(option_value)
            if normalized_text is None:
                raise _output_error(
                    "OUTPUT_MISSING_FIELD",
                    "Candidate options object values must be strings.",
                )
            parsed_from_object[normalized_label] = normalized_text
        return parsed_from_object

    if not isinstance(value, list):
        raise _output_error(
            "OUTPUT_SCHEMA_INVALID",
            "Candidate options must be an object or array.",
        )

    parsed: dict[str, str] = {}
    labels = ["A", "B", "C", "D", "E"]
    if all(isinstance(item, str) for item in value):
        if len(value) != len(labels):
            raise _output_error(
                "OUTPUT_MISSING_FIELD",
                "Candidate options array must contain exactly five items.",
            )
        return {label: str(text) for label, text in zip(labels, value, strict=True)}

    for index, item in enumerate(value):
        if not isinstance(item, dict):
            raise _output_error("OUTPUT_SCHEMA_INVALID", "Candidate option item must be an object.")

        label = item.get("label") or item.get("key") or item.get("option") or item.get("id")
        text = _coerce_option_text(
            item.get("text")
            or item.get("value")
            or item.get("content")
            or item.get("answer")
            or item.get("choice")
            or item.get("optionText")
            or item.get("option_text")
        )

        if (not isinstance(label, str) or not label.strip()) and len(item) == 1:
            single_key, single_value = next(iter(item.items()))
            label = str(single_key)
            text = _coerce_option_text(single_value)

        if not isinstance(label, str) or text is None:
            raise _output_error(
                "OUTPUT_MISSING_FIELD",
                "Candidate option object requires string label/text.",
            )
        normalized_label = _normalize_option_label(label)
        if not normalized_label and index < len(labels):
            normalized_label = labels[index]
        parsed[normalized_label] = text

    return parsed


def _coerce_option_text(value: object) -> str | None:
    if isinstance(value, str):
        return value
    if not isinstance(value, dict):
        return None

    for key in (
        "text",
        "value",
        "content",
        "answer",
        "choice",
        "optionText",
        "option_text",
        "label",
    ):
        candidate = value.get(key)
        if isinstance(candidate, str):
            return candidate
    return None


def _parse_source_policy(value: object) -> ContentSourcePolicy:
    if value is None:
        return ContentSourcePolicy.AI_ORIGINAL

    raw = str(value).strip()
    if not raw:
        return ContentSourcePolicy.AI_ORIGINAL

    try:
        return ContentSourcePolicy(raw)
    except ValueError:
        # Provider-generated content is constrained to the AI original policy.
        # Some models return descriptive prose instead of the canonical enum.
        return ContentSourcePolicy.AI_ORIGINAL


def _parse_turns(value: object) -> list[dict[str, str]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise _output_error("OUTPUT_MISSING_FIELD", "Turns must be an array.")

    parsed: list[dict[str, str]] = []
    for index, item in enumerate(value, start=1):
        speaker: object
        text: object
        if isinstance(item, str):
            speaker = "A" if index % 2 == 1 else "B"
            text = item
        elif isinstance(item, dict):
            speaker = item.get("speaker") or item.get("speakerLabel") or item.get("role")
            text = (
                item.get("text")
                or item.get("utterance")
                or item.get("content")
                or item.get("line")
            )
        else:
            raise _output_error("OUTPUT_SCHEMA_INVALID", "Turn item must be an object.")

        if not isinstance(speaker, str) or not isinstance(text, str):
            raise _output_error(
                "OUTPUT_MISSING_FIELD",
                "Turn item requires string speaker/text.",
            )
        parsed.append({"speaker": speaker, "text": text})
    return parsed


def _parse_sentences(value: object) -> list[dict[str, str]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise _output_error("OUTPUT_MISSING_FIELD", "Sentences must be an array.")

    parsed: list[dict[str, str]] = []
    for index, item in enumerate(value, start=1):
        sentence_id: object
        text: object
        if isinstance(item, str):
            sentence_id = f"s{index}"
            text = item
        elif isinstance(item, dict):
            sentence_id = item.get("id") or item.get("sentenceId") or item.get("sentence_id")
            text = item.get("text") or item.get("content") or item.get("sentence")
        else:
            raise _output_error("OUTPUT_SCHEMA_INVALID", "Sentence item must be an object.")
        if not isinstance(sentence_id, str) or not isinstance(text, str):
            raise _output_error(
                "OUTPUT_MISSING_FIELD",
                "Sentence item requires string id/text.",
            )
        parsed.append({"id": sentence_id, "text": text})
    return parsed


def _parse_tts_plan(value: object, *, skill: Skill) -> dict[str, Any]:
    if value is None and skill == Skill.LISTENING:
        return {"voice": "en-US-neutral", "pace": "normal"}
    return _parse_object(value, default={})


def _parse_evidence_sentence_ids(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if not isinstance(value, list):
        raise _output_error(
            "OUTPUT_SENTENCE_ID_MISMATCH",
            "evidenceSentenceIds must be an array or string.",
        )

    parsed: list[str] = []
    for item in value:
        if isinstance(item, int):
            parsed.append(f"s{item}")
            continue
        parsed.append(str(item))
    return parsed


def _parse_why_wrong_by_option(*, value: object, answer_key: str) -> dict[str, str]:
    parsed = {
        str(key): str(item)
        for key, item in _parse_object(value, default={}).items()
    }
    normalized_answer = _normalize_answer_key(answer_key)
    if normalized_answer and normalized_answer not in parsed:
        parsed[normalized_answer] = "정답 보기입니다."
    return parsed


def _normalize_answer_key(value: object) -> str:
    raw = str(value or "").strip().upper()
    if raw[:1] in {"A", "B", "C", "D", "E"}:
        return raw[:1]
    return raw


def _normalize_option_label(value: object) -> str:
    normalized = str(value).strip().upper().replace(".", "").replace(")", "")
    numeric_map = {"1": "A", "2": "B", "3": "C", "4": "D", "5": "E"}
    return numeric_map.get(normalized, normalized)


def _sentences_from_turns(turns: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        {"id": f"s{index}", "text": turn["text"]}
        for index, turn in enumerate(turns, start=1)
    ]


def _output_error(code: str, message: str) -> AIProviderError:
    return AIProviderError(code=code, message=message, transient=False)
