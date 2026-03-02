from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Protocol
from uuid import UUID

from app.core.config import settings
from app.core.policies import (
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

        prompt_payload = {
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

    if settings.ai_generation_api_key is None:
        raise AIProviderError(
            code="provider_api_key_missing",
            message="AI provider API key is missing.",
            transient=False,
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
