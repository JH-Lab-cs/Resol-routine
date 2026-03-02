from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import json
from typing import Any, Protocol
from urllib import error as urllib_error
from urllib import request as urllib_request
from uuid import UUID

from app.core.config import settings
from app.core.policies import (
    AI_PROVIDER_HTTP_TIMEOUT_SECONDS,
    MOCK_EXAM_MONTHLY_LISTENING_COUNT,
    MOCK_EXAM_MONTHLY_READING_COUNT,
    MOCK_EXAM_WEEKLY_LISTENING_COUNT,
    MOCK_EXAM_WEEKLY_READING_COUNT,
)
from app.models.enums import MockExamType, Skill, Track


@dataclass(frozen=True, slots=True)
class CandidateQuestion:
    content_question_id: UUID
    content_unit_revision_id: UUID
    question_code: str
    skill: Skill
    stem: str
    has_asset: bool
    unit_title: str | None


@dataclass(frozen=True, slots=True)
class MockExamGenerationContext:
    mock_exam_id: UUID
    exam_type: MockExamType
    track: Track
    period_key: str
    candidate_questions: list[CandidateQuestion]
    candidate_limit: int
    notes: str | None


@dataclass(frozen=True, slots=True)
class ProviderStructuredItem:
    order_index: int
    content_question_id: UUID


@dataclass(frozen=True, slots=True)
class ProviderStructuredOutput:
    title: str
    instructions: str | None
    items: list[ProviderStructuredItem]


@dataclass(frozen=True, slots=True)
class ProviderGenerationResult:
    provider_name: str
    model_name: str
    prompt_template_version: str
    raw_prompt: str
    raw_response: str
    structured_output: ProviderStructuredOutput


class AIProviderError(RuntimeError):
    def __init__(self, *, code: str, message: str, transient: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.transient = transient


class MockExamGenerationProvider(Protocol):
    def generate_structured_output(self, *, context: MockExamGenerationContext) -> ProviderGenerationResult: ...


class DeterministicMockExamProvider:
    def __init__(self, *, model_name: str, prompt_template_version: str) -> None:
        self._provider_name = "fake"
        self._model_name = model_name
        self._prompt_template_version = prompt_template_version

    def generate_structured_output(self, *, context: MockExamGenerationContext) -> ProviderGenerationResult:
        expected_listening, expected_reading = _expected_skill_counts(context.exam_type)
        listening_candidates = [item for item in context.candidate_questions if item.skill == Skill.LISTENING]
        reading_candidates = [item for item in context.candidate_questions if item.skill == Skill.READING]
        if len(listening_candidates) < expected_listening or len(reading_candidates) < expected_reading:
            raise AIProviderError(
                code="insufficient_candidates",
                message="Insufficient candidate pool for required skill counts.",
                transient=False,
            )

        selected = listening_candidates[:expected_listening] + reading_candidates[:expected_reading]
        structured_items = [
            ProviderStructuredItem(order_index=index + 1, content_question_id=item.content_question_id)
            for index, item in enumerate(selected)
        ]
        structured_output = ProviderStructuredOutput(
            title=f"{context.exam_type.value.title()} Mock Draft {context.period_key}",
            instructions=(
                "Answer every question carefully. Choose one option for each item and review before submission."
            ),
            items=structured_items,
        )

        prompt_payload = _build_prompt_payload(context=context)
        response_payload = {
            "title": structured_output.title,
            "instructions": structured_output.instructions,
            "items": [
                {
                    "orderIndex": item.order_index,
                    "contentQuestionId": str(item.content_question_id),
                }
                for item in structured_output.items
            ],
        }
        return ProviderGenerationResult(
            provider_name=self._provider_name,
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(prompt_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=json.dumps(response_payload, ensure_ascii=False, separators=(",", ":")),
            structured_output=structured_output,
        )


class OpenAIMockExamProvider:
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

    def generate_structured_output(self, *, context: MockExamGenerationContext) -> ProviderGenerationResult:
        prompt_payload = _build_prompt_payload(context=context)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": _system_instruction(context.exam_type)},
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
        response_data = _parse_json_response(response_body, invalid_code="openai_invalid_response")

        try:
            choices = response_data["choices"]
            first_choice = choices[0]
            message = first_choice["message"]
            raw_content = message["content"]
        except Exception as exc:
            raise AIProviderError(
                code="openai_invalid_response",
                message="OpenAI response is missing structured content.",
                transient=False,
            ) from exc

        if not isinstance(raw_content, str):
            raise AIProviderError(
                code="openai_invalid_response",
                message="OpenAI response content must be a string.",
                transient=False,
            )

        structured_output = _parse_structured_output_json(raw_content)
        return ProviderGenerationResult(
            provider_name="openai",
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            structured_output=structured_output,
        )


class AnthropicMockExamProvider:
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

    def generate_structured_output(self, *, context: MockExamGenerationContext) -> ProviderGenerationResult:
        prompt_payload = _build_prompt_payload(context=context)
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "max_tokens": 2048,
            "system": _system_instruction(context.exam_type),
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
        response_data = _parse_json_response(response_body, invalid_code="anthropic_invalid_response")

        try:
            content_items = response_data["content"]
            first_item = content_items[0]
            raw_content = first_item["text"]
        except Exception as exc:
            raise AIProviderError(
                code="anthropic_invalid_response",
                message="Anthropic response is missing structured content.",
                transient=False,
            ) from exc

        if not isinstance(raw_content, str):
            raise AIProviderError(
                code="anthropic_invalid_response",
                message="Anthropic response content must be a string.",
                transient=False,
            )

        structured_output = _parse_structured_output_json(raw_content)
        return ProviderGenerationResult(
            provider_name="anthropic",
            model_name=self._model_name,
            prompt_template_version=self._prompt_template_version,
            raw_prompt=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=response_body,
            structured_output=structured_output,
        )


def build_mock_exam_generation_provider() -> MockExamGenerationProvider:
    provider_name = settings.ai_generation_provider.strip().lower()
    if provider_name in {"", "disabled", "none"}:
        raise AIProviderError(
            code="provider_not_configured",
            message="AI generation provider is not configured.",
            transient=False,
        )

    if provider_name == "fake":
        return DeterministicMockExamProvider(
            model_name=settings.ai_mock_exam_model,
            prompt_template_version=settings.ai_mock_exam_prompt_template_version,
        )

    api_key = settings.ai_generation_api_key
    if api_key is None:
        raise AIProviderError(
            code="provider_api_key_missing",
            message="AI provider API key is missing.",
            transient=False,
        )

    if provider_name == "openai":
        return OpenAIMockExamProvider(
            api_key=api_key,
            model_name=settings.ai_mock_exam_model,
            prompt_template_version=settings.ai_mock_exam_prompt_template_version,
            base_url=settings.ai_openai_base_url,
        )

    if provider_name == "anthropic":
        return AnthropicMockExamProvider(
            api_key=api_key,
            model_name=settings.ai_mock_exam_model,
            prompt_template_version=settings.ai_mock_exam_prompt_template_version,
            base_url=settings.ai_anthropic_base_url,
        )

    raise AIProviderError(
        code="provider_not_supported",
        message=f"Unsupported AI provider: {settings.ai_generation_provider}",
        transient=False,
    )


def _expected_skill_counts(exam_type: MockExamType) -> tuple[int, int]:
    if exam_type == MockExamType.WEEKLY:
        return MOCK_EXAM_WEEKLY_LISTENING_COUNT, MOCK_EXAM_WEEKLY_READING_COUNT
    return MOCK_EXAM_MONTHLY_LISTENING_COUNT, MOCK_EXAM_MONTHLY_READING_COUNT


def _system_instruction(exam_type: MockExamType) -> str:
    listening_count, reading_count = _expected_skill_counts(exam_type)
    return (
        "You are assembling a mock exam draft. "
        "Return strict JSON only with keys: title, instructions, items. "
        "items must be an array of objects with orderIndex (int) and contentQuestionId (uuid string). "
        "Do not include markdown or prose. "
        f"The output must include exactly {listening_count} LISTENING and {reading_count} READING items."
    )


def _build_prompt_payload(*, context: MockExamGenerationContext) -> dict[str, object]:
    generated_at = datetime.now(UTC).isoformat()
    return {
        "generatedAt": generated_at,
        "mockExamId": str(context.mock_exam_id),
        "examType": context.exam_type.value,
        "track": context.track.value,
        "periodKey": context.period_key,
        "candidateLimit": context.candidate_limit,
        "notes": context.notes,
        "candidateQuestions": [
            {
                "contentQuestionId": str(item.content_question_id),
                "contentUnitRevisionId": str(item.content_unit_revision_id),
                "questionCode": item.question_code,
                "skill": item.skill.value,
                "stem": item.stem,
                "hasAsset": item.has_asset,
                "unitTitle": item.unit_title,
            }
            for item in context.candidate_questions
        ],
    }


def _post_json(*, url: str, headers: dict[str, str], payload: dict[str, object]) -> str:
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
            code="provider_http_error",
            message=f"Provider HTTP error {exc.code}: {body[:400]}",
            transient=transient,
        ) from exc
    except urllib_error.URLError as exc:
        raise AIProviderError(
            code="provider_network_error",
            message=f"Provider network error: {exc.reason}",
            transient=True,
        ) from exc
    except TimeoutError as exc:
        raise AIProviderError(
            code="provider_timeout",
            message="Provider request timed out.",
            transient=True,
        ) from exc

    return body.decode("utf-8")


def _parse_json_response(response_body: str, *, invalid_code: str) -> dict[str, object]:
    try:
        decoded = json.loads(response_body)
    except json.JSONDecodeError as exc:
        raise AIProviderError(
            code=invalid_code,
            message="Provider response is not valid JSON.",
            transient=False,
        ) from exc

    if not isinstance(decoded, dict):
        raise AIProviderError(
            code=invalid_code,
            message="Provider response payload must be a JSON object.",
            transient=False,
        )
    return decoded


def _parse_structured_output_json(raw_content: str) -> ProviderStructuredOutput:
    parsed = _parse_json_response(raw_content, invalid_code="invalid_generated_output")
    title = parsed.get("title")
    instructions = parsed.get("instructions")
    items = parsed.get("items")
    if not isinstance(title, str) or not title.strip():
        raise AIProviderError(
            code="invalid_generated_output",
            message="Generated output title is missing.",
            transient=False,
        )
    if instructions is not None and not isinstance(instructions, str):
        raise AIProviderError(
            code="invalid_generated_output",
            message="Generated output instructions must be a string or null.",
            transient=False,
        )
    if not isinstance(items, list) or not items:
        raise AIProviderError(
            code="invalid_generated_output",
            message="Generated output items must be a non-empty array.",
            transient=False,
        )

    structured_items: list[ProviderStructuredItem] = []
    for item in items:
        if not isinstance(item, dict):
            raise AIProviderError(
                code="invalid_generated_output",
                message="Generated output item must be an object.",
                transient=False,
            )
        try:
            order_index = int(item["orderIndex"])
            content_question_id = UUID(str(item["contentQuestionId"]))
        except Exception as exc:
            raise AIProviderError(
                code="invalid_generated_output",
                message="Generated output item fields are invalid.",
                transient=False,
            ) from exc
        structured_items.append(
            ProviderStructuredItem(
                order_index=order_index,
                content_question_id=content_question_id,
            )
        )

    return ProviderStructuredOutput(
        title=title.strip(),
        instructions=instructions.strip() if isinstance(instructions, str) and instructions.strip() else None,
        items=structured_items,
    )
