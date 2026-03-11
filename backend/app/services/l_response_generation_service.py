from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any

from app.core.input_validation import contains_hidden_unicode
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill, Track

L_RESPONSE_GENERATION_MODE = "L_RESPONSE_SKELETON"
L_RESPONSE_COMPILER_VERSION = "l-response-compiler-v1"
L_RESPONSE_PROMPT_TEMPLATE_SUFFIX = "listening-response-skeleton"
L_RESPONSE_STEM = "What is the most appropriate response to the last speaker?"
L_RESPONSE_DEFAULT_TTS_PLAN: dict[str, str] = {
    "voice": "en-US-neutral",
    "pace": "normal",
}
_L_RESPONSE_CORRECT_OPTION_LABEL = "A"
_L_RESPONSE_DISTRACTOR_LABELS = ("B", "C", "D", "E")


@dataclass(frozen=True, slots=True)
class LResponseGenerationError(Exception):
    code: str
    message: str

    def __str__(self) -> str:
        return self.message


@dataclass(frozen=True, slots=True)
class LResponseSkeletonCandidate:
    track: Track
    difficulty: int
    type_tag: ContentTypeTag
    turns: tuple[dict[str, str], dict[str, str]]
    response_prompt_speaker: str
    correct_response_text: str
    distractor_response_texts: tuple[str, str, str, str]
    evidence_turn_indexes: tuple[int, ...]
    why_correct_ko: str
    why_wrong_ko_by_option: dict[str, str]
    notes: str | None = None


def parse_l_response_generation_candidates(raw_content: str) -> list[LResponseSkeletonCandidate]:
    try:
        payload = json.loads(raw_content)
    except json.JSONDecodeError as exc:
        raise LResponseGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must be valid JSON.",
        ) from exc

    if not isinstance(payload, dict):
        raise LResponseGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must be a JSON object.",
        )

    raw_candidates = payload.get("candidates")
    if not isinstance(raw_candidates, list) or not raw_candidates:
        raise LResponseGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must include a non-empty candidates array.",
        )

    parsed: list[LResponseSkeletonCandidate] = []
    for raw_candidate in raw_candidates:
        if not isinstance(raw_candidate, dict):
            raise LResponseGenerationError(
                code="OUTPUT_SCHEMA_INVALID",
                message="L_RESPONSE candidate must be an object.",
            )
        parsed.append(_parse_l_response_candidate(raw_candidate))
    return parsed


def compile_l_response_skeleton_candidate(
    skeleton: LResponseSkeletonCandidate,
) -> dict[str, Any]:
    _validate_l_response_skeleton(skeleton)

    sentence_rows = [
        {"id": f"s{index}", "text": turn["text"]}
        for index, turn in enumerate(skeleton.turns, start=1)
    ]
    transcript_text = "\n".join(
        f"{turn['speaker']}: {turn['text']}" for turn in skeleton.turns
    )
    evidence_sentence_ids = [f"s{index}" for index in skeleton.evidence_turn_indexes]
    why_wrong = {
        "A": "정답 보기입니다.",
        "B": skeleton.why_wrong_ko_by_option["B"],
        "C": skeleton.why_wrong_ko_by_option["C"],
        "D": skeleton.why_wrong_ko_by_option["D"],
        "E": skeleton.why_wrong_ko_by_option["E"],
    }
    options = {
        "A": skeleton.correct_response_text,
        "B": skeleton.distractor_response_texts[0],
        "C": skeleton.distractor_response_texts[1],
        "D": skeleton.distractor_response_texts[2],
        "E": skeleton.distractor_response_texts[3],
    }
    explanation = (
        "Option A is correct because it is the most appropriate spoken response to the "
        f"last speaker in turn {skeleton.evidence_turn_indexes[-1]}."
    )
    structure_note = (
        "마지막 화자의 발화 의도와 가장 자연스럽게 이어지는 응답을 고르세요."
    )
    if skeleton.notes is not None:
        structure_note = f"{structure_note} {skeleton.notes}".strip()

    return {
        "track": skeleton.track.value,
        "skill": Skill.LISTENING.value,
        "typeTag": ContentTypeTag.L_RESPONSE.value,
        "difficulty": skeleton.difficulty,
        "sourcePolicy": ContentSourcePolicy.AI_ORIGINAL.value,
        "title": f"{skeleton.track.value} Listening L_RESPONSE",
        "transcriptText": transcript_text,
        "turns": list(skeleton.turns),
        "sentences": sentence_rows,
        "ttsPlan": dict(L_RESPONSE_DEFAULT_TTS_PLAN),
        "question": {
            "stem": L_RESPONSE_STEM,
            "options": options,
            "answerKey": _L_RESPONSE_CORRECT_OPTION_LABEL,
            "explanation": explanation,
            "evidenceSentenceIds": evidence_sentence_ids,
            "whyCorrectKo": skeleton.why_correct_ko,
            "whyWrongKoByOption": why_wrong,
            "structureNotesKo": structure_note,
        },
    }


def serialize_l_response_skeleton_candidate(
    skeleton: LResponseSkeletonCandidate,
) -> dict[str, Any]:
    return {
        "track": skeleton.track.value,
        "difficulty": skeleton.difficulty,
        "typeTag": skeleton.type_tag.value,
        "turns": [dict(turn) for turn in skeleton.turns],
        "responsePromptSpeaker": skeleton.response_prompt_speaker,
        "correctResponseText": skeleton.correct_response_text,
        "distractorResponseTexts": list(skeleton.distractor_response_texts),
        "evidenceTurnIndexes": list(skeleton.evidence_turn_indexes),
        "whyCorrectKo": skeleton.why_correct_ko,
        "whyWrongKoByOption": dict(skeleton.why_wrong_ko_by_option),
        "notes": skeleton.notes,
    }


def build_deterministic_l_response_skeleton(
    *,
    track: Track,
    difficulty: int,
    index: int,
) -> LResponseSkeletonCandidate:
    return LResponseSkeletonCandidate(
        track=track,
        difficulty=difficulty,
        type_tag=ContentTypeTag.L_RESPONSE,
        turns=(
            {
                "speaker": "A",
                "text": f"Can you help me with the schedule for activity {index}?",
            },
            {
                "speaker": "B",
                "text": "Yes, but please check the notice board before you decide.",
            },
        ),
        response_prompt_speaker="B",
        correct_response_text="Okay, I'll read the notice board first.",
        distractor_response_texts=(
            "I finished the project yesterday.",
            "No, I only brought a pencil.",
            "Let's buy some snacks after school.",
            "I forgot where the library is today.",
        ),
        evidence_turn_indexes=(2,),
        why_correct_ko=(
            "마지막 화자가 공지판을 먼저 확인하라고 했으므로 "
            "그에 맞는 응답이 정답입니다."
        ),
        why_wrong_ko_by_option={
            "B": "마지막 화자의 요청에 직접 응답하지 않고 전혀 다른 정보를 말합니다.",
            "C": "준비물 이야기로 화제만 바꾸고 공지판 확인 요구에 반응하지 않습니다.",
            "D": "간식 이야기는 대화 맥락과 무관합니다.",
            "E": "도서관 위치는 마지막 발화의 요구와 관련이 없습니다.",
        },
        notes="Keep the response grounded in the final turn only.",
    )


def _parse_l_response_candidate(raw_candidate: dict[str, Any]) -> LResponseSkeletonCandidate:
    raw_track = raw_candidate.get("track")
    raw_difficulty = raw_candidate.get("difficulty")
    raw_type_tag = raw_candidate.get("typeTag")
    if not isinstance(raw_track, str):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE skeleton track is required.",
        )
    if not isinstance(raw_difficulty, int):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE skeleton difficulty is required.",
        )
    if raw_type_tag != ContentTypeTag.L_RESPONSE.value:
        raise LResponseGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="L_RESPONSE skeleton typeTag must be L_RESPONSE.",
        )

    turns = _parse_turns(raw_candidate.get("turns"))
    response_prompt_speaker = _required_text(
        raw_candidate.get("responsePromptSpeaker"),
        field_name="responsePromptSpeaker",
    )
    correct_response_text = _required_text(
        raw_candidate.get("correctResponseText"),
        field_name="correctResponseText",
    )
    distractor_response_texts = _parse_distractor_response_texts(
        raw_candidate.get("distractorResponseTexts")
    )
    evidence_turn_indexes = _parse_evidence_turn_indexes(
        raw_candidate.get("evidenceTurnIndexes")
    )
    why_correct_ko = _required_text(
        raw_candidate.get("whyCorrectKo"),
        field_name="whyCorrectKo",
    )
    why_wrong_ko_by_option = _parse_why_wrong_ko_by_option(
        raw_candidate.get("whyWrongKoByOption")
    )
    notes = _optional_text(raw_candidate.get("notes"))

    return LResponseSkeletonCandidate(
        track=Track(raw_track),
        difficulty=raw_difficulty,
        type_tag=ContentTypeTag.L_RESPONSE,
        turns=turns,
        response_prompt_speaker=response_prompt_speaker,
        correct_response_text=correct_response_text,
        distractor_response_texts=distractor_response_texts,
        evidence_turn_indexes=evidence_turn_indexes,
        why_correct_ko=why_correct_ko,
        why_wrong_ko_by_option=why_wrong_ko_by_option,
        notes=notes,
    )


def _validate_l_response_skeleton(skeleton: LResponseSkeletonCandidate) -> None:
    if len(skeleton.turns) != 2:
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_TURN_COUNT",
            message="L_RESPONSE skeleton must contain exactly two turns.",
        )
    if skeleton.response_prompt_speaker != skeleton.turns[-1]["speaker"]:
        raise LResponseGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="responsePromptSpeaker must match the final turn speaker.",
        )
    if len(skeleton.distractor_response_texts) != 4:
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_RESPONSE_OPTIONS",
            message="L_RESPONSE skeleton must contain exactly four distractor responses.",
        )

    response_texts = [
        skeleton.correct_response_text,
        *skeleton.distractor_response_texts,
    ]
    normalized_response_texts = [_normalize_response_text(text) for text in response_texts]
    if len(set(normalized_response_texts)) != len(normalized_response_texts):
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_RESPONSE_OPTIONS",
            message="L_RESPONSE response options must be unique.",
        )
    if _has_semantic_overlap(normalized_response_texts):
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_RESPONSE_OPTIONS",
            message="L_RESPONSE response options must be semantically distinct.",
        )

    if not skeleton.evidence_turn_indexes:
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_EVIDENCE_TURN",
            message="L_RESPONSE evidenceTurnIndexes must not be empty.",
        )
    if any(index < 1 or index > len(skeleton.turns) for index in skeleton.evidence_turn_indexes):
        raise LResponseGenerationError(
            code="OUTPUT_INVALID_EVIDENCE_TURN",
            message="L_RESPONSE evidenceTurnIndexes must point to an existing turn.",
        )

    for turn in skeleton.turns:
        _validate_visible_text(turn["speaker"], field_name="turn.speaker")
        _validate_visible_text(turn["text"], field_name="turn.text")
    for text in response_texts:
        _validate_visible_text(text, field_name="response.text")
    _validate_visible_text(skeleton.why_correct_ko, field_name="whyCorrectKo")
    for key, value in skeleton.why_wrong_ko_by_option.items():
        _validate_visible_text(value, field_name=f"whyWrongKoByOption.{key}")


def _parse_turns(value: object) -> tuple[dict[str, str], dict[str, str]]:
    if not isinstance(value, list):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE turns must be an array.",
        )
    parsed: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            raise LResponseGenerationError(
                code="OUTPUT_SCHEMA_INVALID",
                message="L_RESPONSE turn must be an object.",
            )
        speaker = _required_text(item.get("speaker"), field_name="turn.speaker")
        text = _required_text(item.get("text"), field_name="turn.text")
        parsed.append({"speaker": speaker, "text": text})
    return tuple(parsed)  # type: ignore[return-value]


def _parse_distractor_response_texts(value: object) -> tuple[str, str, str, str]:
    if not isinstance(value, list):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE distractorResponseTexts must be an array.",
        )
    parsed = tuple(
        _required_text(item, field_name="distractorResponseTexts") for item in value
    )
    return parsed  # type: ignore[return-value]


def _parse_evidence_turn_indexes(value: object) -> tuple[int, ...]:
    if not isinstance(value, list):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE evidenceTurnIndexes must be an array.",
        )
    parsed: list[int] = []
    for item in value:
        if not isinstance(item, int):
            raise LResponseGenerationError(
                code="OUTPUT_INVALID_EVIDENCE_TURN",
                message="L_RESPONSE evidenceTurnIndexes must contain integers only.",
            )
        parsed.append(item)
    return tuple(parsed)


def _parse_why_wrong_ko_by_option(value: object) -> dict[str, str]:
    if not isinstance(value, dict):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="L_RESPONSE whyWrongKoByOption must be an object.",
        )

    parsed: dict[str, str] = {}
    for key in _L_RESPONSE_DISTRACTOR_LABELS:
        parsed[key] = _required_text(
            value.get(key),
            field_name=f"whyWrongKoByOption.{key}",
        )
    return parsed


def _required_text(value: object, *, field_name: str) -> str:
    if not isinstance(value, str):
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be a non-empty string.",
        )
    normalized = value.strip()
    if not normalized:
        raise LResponseGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be a non-empty string.",
        )
    return normalized


def _optional_text(value: object) -> str | None:
    if value is None:
        return None
    return _required_text(value, field_name="notes")


def _validate_visible_text(value: str, *, field_name: str) -> None:
    if contains_hidden_unicode(value):
        raise LResponseGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message=f"{field_name} contains hidden unicode.",
        )


def _normalize_response_text(value: str) -> str:
    normalized = value.casefold()
    normalized = re.sub(r"[^a-z0-9 ]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _has_semantic_overlap(normalized_values: list[str]) -> bool:
    for index, current in enumerate(normalized_values):
        for other in normalized_values[index + 1 :]:
            if len(current) < 5 or len(other) < 5:
                continue
            if current in other or other in current:
                return True
    return False
