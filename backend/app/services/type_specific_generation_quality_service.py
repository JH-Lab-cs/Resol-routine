from __future__ import annotations

import json
import re
from dataclasses import dataclass
from itertools import permutations
from typing import Any, cast

from app.core.input_validation import contains_hidden_unicode
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill, Track

HARD_QUALITY_PROFILE_TIMEOUT_SECONDS = 60

L_SITUATION_CONTEXTUAL_GENERATION_MODE = "L_SITUATION_CONTEXTUAL_SKELETON"
L_SITUATION_CONTEXTUAL_COMPILER_VERSION = "l-situation-contextual-compiler-v1"
L_SITUATION_CONTEXTUAL_PROMPT_TEMPLATE_SUFFIX = "listening-situation-contextual"
L_SITUATION_CONTEXTUAL_GENERATION_PROFILE = "H2_L_SITUATION_CONTEXTUAL"
L_SITUATION_STEM = "What is the most appropriate thing to say or do in this situation?"

R_BLANK_OUTLINE_GENERATION_MODE = "R_BLANK_DISCOURSE_OUTLINE"
R_BLANK_OUTLINE_COMPILER_VERSION = "r-blank-discourse-compiler-v1"
R_BLANK_OUTLINE_PROMPT_TEMPLATE_SUFFIX = "reading-blank-discourse"
R_BLANK_OUTLINE_GENERATION_PROFILE = "H1_R_BLANK_DISCOURSE"
R_BLANK_STEM = "Which of the following best completes the blank in the passage?"

R_ORDER_OUTLINE_GENERATION_MODE = "R_ORDER_DISCOURSE_OUTLINE"
R_ORDER_OUTLINE_COMPILER_VERSION = "r-order-discourse-compiler-v1"
R_ORDER_OUTLINE_PROMPT_TEMPLATE_SUFFIX = "reading-order-discourse"
R_ORDER_OUTLINE_GENERATION_PROFILE = "H1_R_ORDER_DISCOURSE"
R_ORDER_STEM = "What is the most logical order of the labeled parts in the passage?"

_DISTRACTOR_LABELS = ("B", "C", "D", "E")
_ORDER_LABELS = ("A", "B", "C")
_DISCOURSE_SHIFT_LABELS = {
    "contrast",
    "cause-result",
    "concession",
    "qualification",
    "consequence",
    "elaboration",
}
_SITUATION_CONTEXT_ELEMENTS = {"request", "offer", "problem", "constraint"}
_TOKEN_RE = re.compile(r"[A-Za-z0-9']+")
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


@dataclass(frozen=True, slots=True)
class TypeSpecificGenerationError(Exception):
    code: str
    message: str

    def __str__(self) -> str:
        return self.message


@dataclass(frozen=True, slots=True)
class LSituationContextualCandidate:
    track: Track
    difficulty: int
    type_tag: ContentTypeTag
    setting_summary: str
    turns: tuple[dict[str, str], ...]
    implied_situation_label: str
    context_elements: tuple[str, ...]
    correct_option_text: str
    distractor_option_texts: tuple[str, str, str, str]
    plausible_distractor_labels: tuple[str, ...]
    evidence_turn_indexes: tuple[int, ...]
    context_inference_score: int
    direct_clue_penalty: int
    final_turn_only_solvable: bool
    why_correct_ko: str
    why_wrong_ko_by_option: dict[str, str]
    notes: str | None = None


@dataclass(frozen=True, slots=True)
class RBlankDiscourseCandidate:
    track: Track
    difficulty: int
    type_tag: ContentTypeTag
    context_before_blank: tuple[str, ...]
    context_after_blank: tuple[str, ...]
    key_idea_map: tuple[str, ...]
    blank_target_proposition: str
    correct_blank_text: str
    distractor_blank_texts: tuple[str, str, str, str]
    discourse_shift_label: str
    paraphrase_only_risk: bool
    requires_inference_across_sentences: bool
    structure_complexity_score: int
    direct_clue_penalty: int
    inference_load_score: int
    why_correct_ko: str
    why_wrong_ko_by_option: dict[str, str]
    notes: str | None = None


@dataclass(frozen=True, slots=True)
class ROrderDiscourseCandidate:
    track: Track
    difficulty: int
    type_tag: ContentTypeTag
    introduction_sentences: tuple[str, ...]
    segment_texts: dict[str, str]
    correct_order: tuple[str, str, str]
    plausible_distractor_orders: tuple[str, ...]
    discourse_relation_labels: tuple[str, ...]
    cue_word_only_solvable: bool
    transition_complexity_score: int
    structure_complexity_score: int
    direct_clue_penalty: int
    why_correct_ko: str
    why_wrong_ko_by_option: dict[str, str]
    notes: str | None = None


def parse_l_situation_contextual_candidates(
    raw_content: str,
) -> list[LSituationContextualCandidate]:
    raw_candidates = _parse_candidate_array(raw_content)
    parsed: list[LSituationContextualCandidate] = []
    for raw_candidate in raw_candidates:
        parsed.append(_parse_l_situation_candidate(raw_candidate))
    return parsed


def parse_r_blank_outline_candidates(
    raw_content: str,
) -> list[RBlankDiscourseCandidate]:
    raw_candidates = _parse_candidate_array(raw_content)
    parsed: list[RBlankDiscourseCandidate] = []
    for raw_candidate in raw_candidates:
        parsed.append(_parse_r_blank_candidate(raw_candidate))
    return parsed


def parse_r_order_outline_candidates(
    raw_content: str,
) -> list[ROrderDiscourseCandidate]:
    raw_candidates = _parse_candidate_array(raw_content)
    parsed: list[ROrderDiscourseCandidate] = []
    for raw_candidate in raw_candidates:
        parsed.append(_parse_r_order_candidate(raw_candidate))
    return parsed


def compile_l_situation_contextual_candidate(
    candidate: LSituationContextualCandidate,
) -> dict[str, Any]:
    _validate_l_situation_candidate(candidate)
    transcript_text = "\n".join(f"{turn['speaker']}: {turn['text']}" for turn in candidate.turns)
    sentence_rows = [
        {"id": f"s{index}", "text": turn["text"]}
        for index, turn in enumerate(candidate.turns, start=1)
    ]
    evidence_sentence_ids = [f"s{index}" for index in candidate.evidence_turn_indexes]
    structure_note = (
        f"Setting: {candidate.setting_summary}. "
        f"Inference focus: {candidate.implied_situation_label}."
    )
    if candidate.notes:
        structure_note = f"{structure_note} {candidate.notes}".strip()

    return {
        "track": candidate.track.value,
        "skill": Skill.LISTENING.value,
        "typeTag": ContentTypeTag.L_SITUATION.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": ContentSourcePolicy.AI_ORIGINAL.value,
        "title": f"{candidate.track.value} Listening L_SITUATION",
        "transcriptText": transcript_text,
        "turns": [dict(turn) for turn in candidate.turns],
        "sentences": sentence_rows,
        "ttsPlan": {"voice": "en-US-neutral", "pace": "normal"},
        "question": {
            "stem": L_SITUATION_STEM,
            "options": {
                "A": candidate.correct_option_text,
                "B": candidate.distractor_option_texts[0],
                "C": candidate.distractor_option_texts[1],
                "D": candidate.distractor_option_texts[2],
                "E": candidate.distractor_option_texts[3],
            },
            "answerKey": "A",
            "explanation": (
                "Option A is correct because it requires the listener to combine the "
                "setup, constraint, and final response rather than reacting to the last "
                "line alone."
            ),
            "evidenceSentenceIds": evidence_sentence_ids,
            "whyCorrectKo": candidate.why_correct_ko,
            "whyWrongKoByOption": {
                "A": "정답 보기입니다.",
                "B": candidate.why_wrong_ko_by_option["B"],
                "C": candidate.why_wrong_ko_by_option["C"],
                "D": candidate.why_wrong_ko_by_option["D"],
                "E": candidate.why_wrong_ko_by_option["E"],
            },
            "structureNotesKo": structure_note,
        },
    }


def compile_r_blank_discourse_candidate(candidate: RBlankDiscourseCandidate) -> dict[str, Any]:
    _validate_r_blank_candidate(candidate)
    sentences = [*candidate.context_before_blank, *candidate.context_after_blank]
    passage_text = " ".join(
        [*candidate.context_before_blank, "[BLANK]", *candidate.context_after_blank]
    )
    sentence_rows = [
        {"id": f"s{index}", "text": sentence} for index, sentence in enumerate(sentences, start=1)
    ]
    evidence_ids: list[str] = []
    if candidate.context_before_blank:
        evidence_ids.append(f"s{len(candidate.context_before_blank)}")
    if candidate.context_after_blank:
        evidence_ids.append(f"s{len(candidate.context_before_blank) + 1}")
    structure_note = (
        f"Discourse shift: {candidate.discourse_shift_label}. "
        f"Blank target: {candidate.blank_target_proposition}."
    )
    if candidate.notes:
        structure_note = f"{structure_note} {candidate.notes}".strip()

    return {
        "track": candidate.track.value,
        "skill": Skill.READING.value,
        "typeTag": ContentTypeTag.R_BLANK.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": ContentSourcePolicy.AI_ORIGINAL.value,
        "title": f"{candidate.track.value} Reading R_BLANK",
        "passage": passage_text,
        "sentences": sentence_rows,
        "question": {
            "stem": R_BLANK_STEM,
            "options": {
                "A": candidate.correct_blank_text,
                "B": candidate.distractor_blank_texts[0],
                "C": candidate.distractor_blank_texts[1],
                "D": candidate.distractor_blank_texts[2],
                "E": candidate.distractor_blank_texts[3],
            },
            "answerKey": "A",
            "explanation": (
                "Option A is correct because it preserves the discourse shift and the "
                "idea map across the surrounding context."
            ),
            "evidenceSentenceIds": evidence_ids,
            "whyCorrectKo": candidate.why_correct_ko,
            "whyWrongKoByOption": {
                "A": "정답 보기입니다.",
                "B": candidate.why_wrong_ko_by_option["B"],
                "C": candidate.why_wrong_ko_by_option["C"],
                "D": candidate.why_wrong_ko_by_option["D"],
                "E": candidate.why_wrong_ko_by_option["E"],
            },
            "structureNotesKo": structure_note,
        },
    }


def compile_r_order_discourse_candidate(candidate: ROrderDiscourseCandidate) -> dict[str, Any]:
    _validate_r_order_candidate(candidate)
    options = _build_order_options(candidate)
    body_parts = [*candidate.introduction_sentences]
    for label in _ORDER_LABELS:
        body_parts.append(f"({label}) {candidate.segment_texts[label]}")
    body_text = " ".join(body_parts)

    sentence_rows: list[dict[str, str]] = []
    index = 1
    for sentence in candidate.introduction_sentences:
        sentence_rows.append({"id": f"s{index}", "text": sentence})
        index += 1
    for label in _ORDER_LABELS:
        for sentence in _split_into_sentences(candidate.segment_texts[label]):
            sentence_rows.append({"id": f"s{index}", "text": sentence})
            index += 1

    structure_note = (
        f"Discourse relations: {', '.join(candidate.discourse_relation_labels)}. "
        f"Correct order: {'-'.join(candidate.correct_order)}."
    )
    if candidate.notes:
        structure_note = f"{structure_note} {candidate.notes}".strip()

    return {
        "track": candidate.track.value,
        "skill": Skill.READING.value,
        "typeTag": ContentTypeTag.R_ORDER.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": ContentSourcePolicy.AI_ORIGINAL.value,
        "title": f"{candidate.track.value} Reading R_ORDER",
        "passage": body_text,
        "sentences": sentence_rows,
        "question": {
            "stem": R_ORDER_STEM,
            "options": options,
            "answerKey": "A",
            "explanation": (
                "Option A is correct because it preserves the intended discourse build-up "
                "instead of following a surface chronology cue."
            ),
            "evidenceSentenceIds": [row["id"] for row in sentence_rows],
            "whyCorrectKo": candidate.why_correct_ko,
            "whyWrongKoByOption": {
                "A": "정답 보기입니다.",
                "B": candidate.why_wrong_ko_by_option["B"],
                "C": candidate.why_wrong_ko_by_option["C"],
                "D": candidate.why_wrong_ko_by_option["D"],
                "E": candidate.why_wrong_ko_by_option["E"],
            },
            "structureNotesKo": structure_note,
        },
    }


def serialize_l_situation_contextual_candidate(
    candidate: LSituationContextualCandidate,
) -> dict[str, Any]:
    return {
        "track": candidate.track.value,
        "difficulty": candidate.difficulty,
        "typeTag": candidate.type_tag.value,
        "settingSummary": candidate.setting_summary,
        "turns": [dict(turn) for turn in candidate.turns],
        "impliedSituationLabel": candidate.implied_situation_label,
        "contextElements": list(candidate.context_elements),
        "correctOptionText": candidate.correct_option_text,
        "distractorOptionTexts": list(candidate.distractor_option_texts),
        "plausibleDistractorLabels": list(candidate.plausible_distractor_labels),
        "evidenceTurnIndexes": list(candidate.evidence_turn_indexes),
        "contextInferenceScore": candidate.context_inference_score,
        "directCluePenalty": candidate.direct_clue_penalty,
        "finalTurnOnlySolvable": candidate.final_turn_only_solvable,
        "whyCorrectKo": candidate.why_correct_ko,
        "whyWrongKoByOption": dict(candidate.why_wrong_ko_by_option),
        "notes": candidate.notes,
    }


def serialize_r_blank_discourse_candidate(candidate: RBlankDiscourseCandidate) -> dict[str, Any]:
    return {
        "track": candidate.track.value,
        "difficulty": candidate.difficulty,
        "typeTag": candidate.type_tag.value,
        "contextBeforeBlank": list(candidate.context_before_blank),
        "contextAfterBlank": list(candidate.context_after_blank),
        "keyIdeaMap": list(candidate.key_idea_map),
        "blankTargetProposition": candidate.blank_target_proposition,
        "correctBlankText": candidate.correct_blank_text,
        "distractorBlankTexts": list(candidate.distractor_blank_texts),
        "discourseShiftLabel": candidate.discourse_shift_label,
        "paraphraseOnlyRisk": candidate.paraphrase_only_risk,
        "requiresInferenceAcrossSentences": candidate.requires_inference_across_sentences,
        "structureComplexityScore": candidate.structure_complexity_score,
        "directCluePenalty": candidate.direct_clue_penalty,
        "inferenceLoadScore": candidate.inference_load_score,
        "whyCorrectKo": candidate.why_correct_ko,
        "whyWrongKoByOption": dict(candidate.why_wrong_ko_by_option),
        "notes": candidate.notes,
    }


def serialize_r_order_discourse_candidate(candidate: ROrderDiscourseCandidate) -> dict[str, Any]:
    return {
        "track": candidate.track.value,
        "difficulty": candidate.difficulty,
        "typeTag": candidate.type_tag.value,
        "introductionSentences": list(candidate.introduction_sentences),
        "segmentTexts": dict(candidate.segment_texts),
        "correctOrder": list(candidate.correct_order),
        "plausibleDistractorOrders": list(candidate.plausible_distractor_orders),
        "discourseRelationLabels": list(candidate.discourse_relation_labels),
        "cueWordOnlySolvable": candidate.cue_word_only_solvable,
        "transitionComplexityScore": candidate.transition_complexity_score,
        "structureComplexityScore": candidate.structure_complexity_score,
        "directCluePenalty": candidate.direct_clue_penalty,
        "whyCorrectKo": candidate.why_correct_ko,
        "whyWrongKoByOption": dict(candidate.why_wrong_ko_by_option),
        "notes": candidate.notes,
    }


def build_deterministic_l_situation_contextual_candidate(
    *,
    track: Track,
    difficulty: int,
    index: int,
) -> LSituationContextualCandidate:
    return LSituationContextualCandidate(
        track=track,
        difficulty=difficulty,
        type_tag=ContentTypeTag.L_SITUATION,
        setting_summary="Two students are adjusting a plan after a scheduling problem.",
        turns=(
            {
                "speaker": "Mina",
                "text": (
                    "Our group presentation is still tomorrow morning, but room "
                    f"{index + 100} is closed for repairs."
                ),
            },
            {
                "speaker": "Joon",
                "text": (
                    "Then we need a backup room, and the teacher said the media lab "
                    "is free only after lunch."
                ),
            },
            {
                "speaker": "Mina",
                "text": (
                    "In that case, I should ask the teacher whether we can switch "
                    "our presentation time."
                ),
            },
        ),
        implied_situation_label="schedule change under a room constraint",
        context_elements=("problem", "constraint", "request"),
        correct_option_text=(
            "You should explain the room problem and ask to move the presentation."
        ),
        distractor_option_texts=(
            "Just arrive early tomorrow and wait in front of the closed room.",
            "Tell everyone to cancel the presentation without asking the teacher.",
            "Practice alone tonight and ignore the room issue for now.",
            "Borrow sports equipment because the media lab might be noisy.",
        ),
        plausible_distractor_labels=("B", "C"),
        evidence_turn_indexes=(1, 2, 3),
        context_inference_score=76,
        direct_clue_penalty=9,
        final_turn_only_solvable=False,
        why_correct_ko=(
            "앞선 두 발화에서 발표실 문제와 대체 가능한 시간 제약이 제시되므로, "
            "교사에게 시간 변경을 요청하는 응답이 가장 적절합니다."
        ),
        why_wrong_ko_by_option={
            "B": (
                "문제 상황은 반영하지만 교사와 발표 시간 조정이라는 핵심 해결 행동이 빠져 있습니다."
            ),
            "C": ("교사 승인 없이 발표를 취소하는 것은 대화에서 제시된 합리적 해결책이 아닙니다."),
            "D": "연습 자체는 가능하지만 방 사용 문제를 해결하지 못합니다.",
            "E": "체육 장비는 대화 맥락과 관련이 없습니다.",
        },
        notes="The answer requires combining the room problem and the time constraint.",
    )


def build_deterministic_r_blank_discourse_candidate(
    *,
    track: Track,
    difficulty: int,
    index: int,
) -> RBlankDiscourseCandidate:
    del index
    return RBlankDiscourseCandidate(
        track=track,
        difficulty=difficulty,
        type_tag=ContentTypeTag.R_BLANK,
        context_before_blank=(
            (
                "Many students assume that careful planning begins only after a "
                "project falls apart, so they postpone difficult choices until the "
                "last minute and treat revision as an emergency repair rather than "
                "as part of the original thinking process."
            ),
            (
                "However, strong planners often do the opposite: they test their "
                "assumptions early, compare several explanations, and ask what "
                "evidence would force them to change direction before the pressure "
                "becomes intense or their first claim becomes too comfortable to "
                "question."
            ),
            (
                "Because that habit exposes weak logic before a deadline arrives, "
                "they learn to distinguish between an attractive explanation and "
                "one that can survive a closer inspection from multiple angles."
            ),
        ),
        context_after_blank=(
            (
                "As a result, they notice weak reasoning while revision is still "
                "possible, and they can replace a convenient claim with one that "
                "actually matches the evidence they collected instead of defending "
                "the first explanation that sounded fluent."
            ),
            (
                "The result is not simply a cleaner final product but a more "
                "deliberate habit of thinking, since each revision teaches them how "
                "a judgment can improve when it is challenged, qualified, and "
                "rebuilt in response to stronger support."
            ),
            (
                "Consequently, planning becomes a method for exposing fragile ideas "
                "early enough to revise them, not a ritual for protecting the first "
                "interpretation from meaningful scrutiny."
            ),
        ),
        key_idea_map=(
            "early testing of assumptions",
            "revision guided by evidence",
            "deliberate habit of thinking",
        ),
        blank_target_proposition=(
            "planned self-questioning before pressure leads to stronger revision later"
        ),
        correct_blank_text=(
            "In other words, disciplined planning is less about predicting every "
            "detail in advance than about building checkpoints that expose weak "
            "reasoning, invite comparison, and force a writer to revise a claim "
            "before it hardens into a confident mistake."
        ),
        distractor_blank_texts=(
            (
                "For that reason, students should finish a project as quickly as "
                "possible and leave revisions for a teacher to handle later."
            ),
            (
                "As a result, planning matters only when a project already "
                "contains obvious grammar mistakes that can be fixed in a final "
                "review."
            ),
            (
                "In addition, careful planners rarely change their first "
                "interpretation because confidence is more important than "
                "conflicting evidence."
            ),
            (
                "Consequently, students benefit most when they avoid comparing "
                "several explanations and choose the easiest claim to defend."
            ),
        ),
        discourse_shift_label="qualification",
        paraphrase_only_risk=False,
        requires_inference_across_sentences=True,
        structure_complexity_score=72,
        direct_clue_penalty=10,
        inference_load_score=68,
        why_correct_ko=(
            "정답은 계획의 핵심을 단순한 준비가 아니라 근거를 점검하는 중간 "
            "점검 장치로 재정의하며, 앞뒤 문장의 논리와 가장 잘 이어집니다."
        ),
        why_wrong_ko_by_option={
            "B": (
                "교사의 최종 수정에만 의존하는 내용으로, 스스로 점검하며 "
                "수정한다는 글의 핵심과 어긋납니다."
            ),
            "C": "문법 오류만 언급해 글의 추상적 논점을 지나치게 축소합니다.",
            "D": (
                "첫 해석을 고수하라는 내용은 근거를 통해 판단을 수정해야 "
                "한다는 글의 방향과 반대입니다."
            ),
            "E": "여러 설명을 비교하지 말라는 주장은 글의 핵심 논리와 충돌합니다.",
        },
        notes=(
            "The blank should connect the contrast and the later consequence, not "
            "paraphrase one adjacent sentence."
        ),
    )


def build_deterministic_r_order_discourse_candidate(
    *,
    track: Track,
    difficulty: int,
    index: int,
) -> ROrderDiscourseCandidate:
    del index
    return ROrderDiscourseCandidate(
        track=track,
        difficulty=difficulty,
        type_tag=ContentTypeTag.R_ORDER,
        introduction_sentences=(
            (
                "A school debate program wanted to understand why some first-year "
                "members began contributing more thoughtful arguments during the "
                "second semester."
            ),
            (
                "The program director noticed that the change did not occur simply "
                "because students spoke more often; it appeared after the club "
                "altered the way members prepared for each discussion and the "
                "criteria they used to judge whether an explanation was strong "
                "enough to share."
            ),
            (
                "In other words, the improvement seemed to come from a change in "
                "reasoning habits rather than from a sudden increase in confidence "
                "alone."
            ),
        ),
        segment_texts={
            "A": (
                "At first, the club emphasized quick reactions, so many students "
                "repeated familiar opinions without testing whether those claims "
                "actually matched the evidence in the prompt. The faster students "
                "answered, the more prepared they seemed, even when the logic "
                "underneath those answers was still thin."
            ),
            "B": (
                "Later, coaches required students to map possible counterarguments "
                "before each session, which forced them to compare weak "
                "explanations with stronger ones and revise their position in "
                "advance. Although this preparation took more time, it made "
                "unsupported claims easier to notice before the discussion began."
            ),
            "C": (
                "As a consequence, students began entering discussions with fewer "
                "but better-supported claims, and their classmates responded to "
                "the depth of the reasoning rather than to the speed of delivery "
                "alone. That shift also changed how the club defined success, "
                "because a slower but better-evidenced answer started to carry "
                "more weight than a quick but shallow response."
            ),
        },
        correct_order=("A", "B", "C"),
        plausible_distractor_orders=("B-A-C", "A-C-B"),
        discourse_relation_labels=("contrast", "consequence", "elaboration"),
        cue_word_only_solvable=False,
        transition_complexity_score=70,
        structure_complexity_score=74,
        direct_clue_penalty=9,
        why_correct_ko=(
            "A는 초기 문제 상황을 설명하고, B는 준비 방식의 변화, C는 그 "
            "변화의 결과를 제시하므로 가장 자연스러운 흐름입니다."
        ),
        why_wrong_ko_by_option={
            "B": ("준비 방식의 변화가 문제 상황보다 먼저 나오면 담화의 원인 관계가 흐려집니다."),
            "C": "결과를 변화의 설명보다 먼저 두면 논리 전개가 역전됩니다.",
            "D": "원인과 결과가 교차되어 담화 흐름이 끊깁니다.",
            "E": ("초기 문제 제시 없이 결과를 먼저 두어 독자가 전개를 추적하기 어렵습니다."),
        },
        notes=("The ordering should depend on discourse function rather than a single cue word."),
    )


def _parse_candidate_array(raw_content: str) -> list[dict[str, Any]]:
    try:
        payload = json.loads(raw_content)
    except json.JSONDecodeError as exc:
        raise TypeSpecificGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must be valid JSON.",
        ) from exc

    if not isinstance(payload, dict):
        raise TypeSpecificGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must be a JSON object.",
        )
    raw_candidates = payload.get("candidates")
    if not isinstance(raw_candidates, list) or not raw_candidates:
        raise TypeSpecificGenerationError(
            code="OUTPUT_SCHEMA_INVALID",
            message="Generated output must include a non-empty candidates array.",
        )
    parsed: list[dict[str, Any]] = []
    for raw_candidate in raw_candidates:
        if not isinstance(raw_candidate, dict):
            raise TypeSpecificGenerationError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Candidate item must be an object.",
            )
        parsed.append(raw_candidate)
    return parsed


def _parse_l_situation_candidate(
    raw_candidate: dict[str, Any],
) -> LSituationContextualCandidate:
    return LSituationContextualCandidate(
        track=Track(_required_text(raw_candidate.get("track"), field_name="track")),
        difficulty=_required_int(raw_candidate.get("difficulty"), field_name="difficulty"),
        type_tag=ContentTypeTag(_required_text(raw_candidate.get("typeTag"), field_name="typeTag")),
        setting_summary=_required_text(
            raw_candidate.get("settingSummary"), field_name="settingSummary"
        ),
        turns=_parse_turns(raw_candidate.get("turns"), minimum=3),
        implied_situation_label=_required_text(
            raw_candidate.get("impliedSituationLabel"),
            field_name="impliedSituationLabel",
        ),
        context_elements=_parse_string_tuple(
            raw_candidate.get("contextElements"),
            field_name="contextElements",
        ),
        correct_option_text=_required_text(
            raw_candidate.get("correctOptionText"),
            field_name="correctOptionText",
        ),
        distractor_option_texts=cast(
            tuple[str, str, str, str],
            _parse_fixed_text_list(
                raw_candidate.get("distractorOptionTexts"),
                field_name="distractorOptionTexts",
                expected=4,
            ),
        ),
        plausible_distractor_labels=_parse_labels(
            raw_candidate.get("plausibleDistractorLabels"),
            field_name="plausibleDistractorLabels",
        ),
        evidence_turn_indexes=_parse_int_tuple(
            raw_candidate.get("evidenceTurnIndexes"),
            field_name="evidenceTurnIndexes",
        ),
        context_inference_score=_required_int(
            raw_candidate.get("contextInferenceScore"),
            field_name="contextInferenceScore",
        ),
        direct_clue_penalty=_required_int(
            raw_candidate.get("directCluePenalty"),
            field_name="directCluePenalty",
        ),
        final_turn_only_solvable=_required_bool(
            raw_candidate.get("finalTurnOnlySolvable"),
            field_name="finalTurnOnlySolvable",
        ),
        why_correct_ko=_required_text(
            raw_candidate.get("whyCorrectKo"),
            field_name="whyCorrectKo",
        ),
        why_wrong_ko_by_option=_parse_why_wrong(raw_candidate.get("whyWrongKoByOption")),
        notes=_optional_text(raw_candidate.get("notes")),
    )


def _parse_r_blank_candidate(
    raw_candidate: dict[str, Any],
) -> RBlankDiscourseCandidate:
    return RBlankDiscourseCandidate(
        track=Track(_required_text(raw_candidate.get("track"), field_name="track")),
        difficulty=_required_int(raw_candidate.get("difficulty"), field_name="difficulty"),
        type_tag=ContentTypeTag(_required_text(raw_candidate.get("typeTag"), field_name="typeTag")),
        context_before_blank=_parse_string_tuple(
            raw_candidate.get("contextBeforeBlank"),
            field_name="contextBeforeBlank",
        ),
        context_after_blank=_parse_string_tuple(
            raw_candidate.get("contextAfterBlank"),
            field_name="contextAfterBlank",
        ),
        key_idea_map=_parse_string_tuple(
            raw_candidate.get("keyIdeaMap"),
            field_name="keyIdeaMap",
        ),
        blank_target_proposition=_required_text(
            raw_candidate.get("blankTargetProposition"),
            field_name="blankTargetProposition",
        ),
        correct_blank_text=_required_text(
            raw_candidate.get("correctBlankText"),
            field_name="correctBlankText",
        ),
        distractor_blank_texts=cast(
            tuple[str, str, str, str],
            _parse_fixed_text_list(
                raw_candidate.get("distractorBlankTexts"),
                field_name="distractorBlankTexts",
                expected=4,
            ),
        ),
        discourse_shift_label=_required_text(
            raw_candidate.get("discourseShiftLabel"),
            field_name="discourseShiftLabel",
        ),
        paraphrase_only_risk=_required_bool(
            raw_candidate.get("paraphraseOnlyRisk"),
            field_name="paraphraseOnlyRisk",
        ),
        requires_inference_across_sentences=_required_bool(
            raw_candidate.get("requiresInferenceAcrossSentences"),
            field_name="requiresInferenceAcrossSentences",
        ),
        structure_complexity_score=_required_int(
            raw_candidate.get("structureComplexityScore"),
            field_name="structureComplexityScore",
        ),
        direct_clue_penalty=_required_int(
            raw_candidate.get("directCluePenalty"),
            field_name="directCluePenalty",
        ),
        inference_load_score=_required_int(
            raw_candidate.get("inferenceLoadScore"),
            field_name="inferenceLoadScore",
        ),
        why_correct_ko=_required_text(
            raw_candidate.get("whyCorrectKo"),
            field_name="whyCorrectKo",
        ),
        why_wrong_ko_by_option=_parse_why_wrong(raw_candidate.get("whyWrongKoByOption")),
        notes=_optional_text(raw_candidate.get("notes")),
    )


def _parse_r_order_candidate(
    raw_candidate: dict[str, Any],
) -> ROrderDiscourseCandidate:
    segment_texts = raw_candidate.get("segmentTexts")
    if not isinstance(segment_texts, dict):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="segmentTexts must be an object with A, B, and C.",
        )
    normalized_segments = {
        label: _required_text(segment_texts.get(label), field_name=f"segmentTexts.{label}")
        for label in _ORDER_LABELS
    }

    return ROrderDiscourseCandidate(
        track=Track(_required_text(raw_candidate.get("track"), field_name="track")),
        difficulty=_required_int(raw_candidate.get("difficulty"), field_name="difficulty"),
        type_tag=ContentTypeTag(_required_text(raw_candidate.get("typeTag"), field_name="typeTag")),
        introduction_sentences=_parse_string_tuple(
            raw_candidate.get("introductionSentences"),
            field_name="introductionSentences",
        ),
        segment_texts=normalized_segments,
        correct_order=_parse_order_tuple(
            raw_candidate.get("correctOrder"),
            field_name="correctOrder",
        ),
        plausible_distractor_orders=_parse_order_strings(
            raw_candidate.get("plausibleDistractorOrders"),
            field_name="plausibleDistractorOrders",
        ),
        discourse_relation_labels=_parse_string_tuple(
            raw_candidate.get("discourseRelationLabels"),
            field_name="discourseRelationLabels",
        ),
        cue_word_only_solvable=_required_bool(
            raw_candidate.get("cueWordOnlySolvable"),
            field_name="cueWordOnlySolvable",
        ),
        transition_complexity_score=_required_int(
            raw_candidate.get("transitionComplexityScore"),
            field_name="transitionComplexityScore",
        ),
        structure_complexity_score=_required_int(
            raw_candidate.get("structureComplexityScore"),
            field_name="structureComplexityScore",
        ),
        direct_clue_penalty=_required_int(
            raw_candidate.get("directCluePenalty"),
            field_name="directCluePenalty",
        ),
        why_correct_ko=_required_text(
            raw_candidate.get("whyCorrectKo"),
            field_name="whyCorrectKo",
        ),
        why_wrong_ko_by_option=_parse_why_wrong(raw_candidate.get("whyWrongKoByOption")),
        notes=_optional_text(raw_candidate.get("notes")),
    )


def _validate_l_situation_candidate(candidate: LSituationContextualCandidate) -> None:
    if candidate.type_tag != ContentTypeTag.L_SITUATION:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="L_SITUATION contextual candidate must use typeTag L_SITUATION.",
        )
    if candidate.track != Track.H2:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="Dedicated L_SITUATION contextual profile is restricted to H2.",
        )
    if len(candidate.turns) < 3:
        raise TypeSpecificGenerationError(
            code="OUTPUT_INVALID_TURN_COUNT",
            message="H2 L_SITUATION contextual candidates must contain at least three turns.",
        )
    if len(set(candidate.context_elements) & _SITUATION_CONTEXT_ELEMENTS) < 2:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H2 L_SITUATION requires at least two context elements.",
        )
    if candidate.context_inference_score < 60:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H2 L_SITUATION contextInferenceScore is too low.",
        )
    if candidate.direct_clue_penalty >= 18:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H2 L_SITUATION direct clue penalty is too high.",
        )
    if candidate.final_turn_only_solvable:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H2 L_SITUATION cannot be solvable from the final turn alone.",
        )
    if len(set(candidate.plausible_distractor_labels) & set(_DISTRACTOR_LABELS)) < 2:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H2 L_SITUATION requires at least two plausible distractors.",
        )
    _validate_option_uniqueness(
        [candidate.correct_option_text, *candidate.distractor_option_texts],
        error_code="OUTPUT_INVALID_RESPONSE_OPTIONS",
        error_message="L_SITUATION options must be unique and semantically distinct.",
    )
    _validate_visible_text(candidate.setting_summary, field_name="settingSummary")
    _validate_visible_text(candidate.implied_situation_label, field_name="impliedSituationLabel")
    _validate_visible_text(candidate.why_correct_ko, field_name="whyCorrectKo")
    for turn in candidate.turns:
        _validate_visible_text(turn["speaker"], field_name="turn.speaker")
        _validate_visible_text(turn["text"], field_name="turn.text")
    for label, text in candidate.why_wrong_ko_by_option.items():
        _validate_visible_text(text, field_name=f"whyWrongKoByOption.{label}")
    _validate_evidence_indexes(candidate.evidence_turn_indexes, limit=len(candidate.turns))


def _validate_r_blank_candidate(candidate: RBlankDiscourseCandidate) -> None:
    if candidate.type_tag != ContentTypeTag.R_BLANK:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="R_BLANK discourse candidate must use typeTag R_BLANK.",
        )
    if candidate.track != Track.H1:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="Dedicated R_BLANK discourse profile is restricted to H1.",
        )
    if len(candidate.context_before_blank) + len(candidate.context_after_blank) < 4:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK requires at least four context sentences.",
        )
    if (
        _count_words(
            " ".join(
                [
                    *candidate.context_before_blank,
                    *candidate.context_after_blank,
                    candidate.correct_blank_text,
                ]
            )
        )
        < 130
    ):
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK length is too short for the discourse profile.",
        )
    if candidate.discourse_shift_label not in _DISCOURSE_SHIFT_LABELS:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK must declare a supported discourse shift.",
        )
    if candidate.paraphrase_only_risk:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK cannot be paraphrase-only.",
        )
    if not candidate.requires_inference_across_sentences:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK must require inference across multiple sentences.",
        )
    if candidate.structure_complexity_score < 58:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK structureComplexityScore is too low.",
        )
    if candidate.direct_clue_penalty >= 18:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK direct clue penalty is too high.",
        )
    if candidate.inference_load_score < 56:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_BLANK inference load is too low.",
        )
    _validate_option_uniqueness(
        [candidate.correct_blank_text, *candidate.distractor_blank_texts],
        error_code="OUTPUT_INVALID_RESPONSE_OPTIONS",
        error_message="R_BLANK options must be unique and semantically distinct.",
    )
    _validate_visible_text(candidate.blank_target_proposition, field_name="blankTargetProposition")
    _validate_visible_text(candidate.why_correct_ko, field_name="whyCorrectKo")
    for sentence in (*candidate.context_before_blank, *candidate.context_after_blank):
        _validate_visible_text(sentence, field_name="contextSentence")
    for label, text in candidate.why_wrong_ko_by_option.items():
        _validate_visible_text(text, field_name=f"whyWrongKoByOption.{label}")


def _validate_r_order_candidate(candidate: ROrderDiscourseCandidate) -> None:
    if candidate.type_tag != ContentTypeTag.R_ORDER:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="R_ORDER discourse candidate must use typeTag R_ORDER.",
        )
    if candidate.track != Track.H1:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="Dedicated R_ORDER discourse profile is restricted to H1.",
        )
    total_sentences = len(candidate.introduction_sentences) + sum(
        len(_split_into_sentences(candidate.segment_texts[label])) for label in _ORDER_LABELS
    )
    if total_sentences < 4:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER requires at least four sentences.",
        )
    total_word_count = _count_words(
        " ".join(
            [
                *candidate.introduction_sentences,
                *(candidate.segment_texts[label] for label in _ORDER_LABELS),
            ]
        )
    )
    if total_word_count < 130:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER length is too short for the discourse profile.",
        )
    if candidate.cue_word_only_solvable:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER cannot be solvable from a single cue word.",
        )
    if len(set(candidate.discourse_relation_labels) & _DISCOURSE_SHIFT_LABELS) == 0:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER requires at least one supported discourse relation.",
        )
    if len(set(candidate.plausible_distractor_orders)) < 2:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER requires at least two plausible distractor orders.",
        )
    if candidate.transition_complexity_score < 56:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER transitionComplexityScore is too low.",
        )
    if candidate.structure_complexity_score < 58:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER structureComplexityScore is too low.",
        )
    if candidate.direct_clue_penalty >= 18:
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message="H1 R_ORDER direct clue penalty is too high.",
        )
    _validate_visible_text(candidate.why_correct_ko, field_name="whyCorrectKo")
    for sentence in candidate.introduction_sentences:
        _validate_visible_text(sentence, field_name="introductionSentence")
    for label in _ORDER_LABELS:
        _validate_visible_text(candidate.segment_texts[label], field_name=f"segmentTexts.{label}")
    for label, text in candidate.why_wrong_ko_by_option.items():
        _validate_visible_text(text, field_name=f"whyWrongKoByOption.{label}")


def _build_order_options(candidate: ROrderDiscourseCandidate) -> dict[str, str]:
    correct_order_text = "-".join(candidate.correct_order)
    distractor_orders = list(dict.fromkeys(candidate.plausible_distractor_orders))
    for order in _all_order_permutations():
        if order == correct_order_text or order in distractor_orders:
            continue
        distractor_orders.append(order)
        if len(distractor_orders) == 4:
            break
    if len(distractor_orders) < 4:
        raise TypeSpecificGenerationError(
            code="OUTPUT_INVALID_RESPONSE_OPTIONS",
            message="R_ORDER must provide enough distractor orders.",
        )
    return {
        "A": correct_order_text,
        "B": distractor_orders[0],
        "C": distractor_orders[1],
        "D": distractor_orders[2],
        "E": distractor_orders[3],
    }


def _all_order_permutations() -> list[str]:
    return ["-".join(option) for option in permutations(_ORDER_LABELS)]


def _parse_turns(value: object, *, minimum: int) -> tuple[dict[str, str], ...]:
    if not isinstance(value, list):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="turns must be an array.",
        )
    parsed: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            raise TypeSpecificGenerationError(
                code="OUTPUT_SCHEMA_INVALID",
                message="turn must be an object.",
            )
        speaker = _required_text(item.get("speaker"), field_name="turn.speaker")
        text = _required_text(item.get("text"), field_name="turn.text")
        parsed.append({"speaker": speaker, "text": text})
    if len(parsed) < minimum:
        raise TypeSpecificGenerationError(
            code="OUTPUT_INVALID_TURN_COUNT",
            message=f"turns must contain at least {minimum} items.",
        )
    return tuple(parsed)


def _parse_string_tuple(value: object, *, field_name: str) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be an array.",
        )
    parsed = tuple(_required_text(item, field_name=field_name) for item in value)
    if not parsed:
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must not be empty.",
        )
    return parsed


def _parse_fixed_text_list(
    value: object,
    *,
    field_name: str,
    expected: int,
) -> tuple[str, ...]:
    parsed = _parse_string_tuple(value, field_name=field_name)
    if len(parsed) != expected:
        raise TypeSpecificGenerationError(
            code="OUTPUT_INVALID_RESPONSE_OPTIONS",
            message=f"{field_name} must contain exactly {expected} items.",
        )
    return parsed


def _parse_labels(value: object, *, field_name: str) -> tuple[str, ...]:
    parsed = _parse_string_tuple(value, field_name=field_name)
    normalized = tuple(item.strip().upper() for item in parsed)
    return normalized


def _parse_int_tuple(value: object, *, field_name: str) -> tuple[int, ...]:
    if not isinstance(value, list):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be an array.",
        )
    parsed: list[int] = []
    for item in value:
        if isinstance(item, bool) or not isinstance(item, int):
            raise TypeSpecificGenerationError(
                code="OUTPUT_VALIDATION_FAILED",
                message=f"{field_name} must contain integers only.",
            )
        parsed.append(item)
    if not parsed:
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must not be empty.",
        )
    return tuple(parsed)


def _parse_order_tuple(value: object, *, field_name: str) -> tuple[str, str, str]:
    parsed = _parse_string_tuple(value, field_name=field_name)
    normalized = tuple(item.strip().upper() for item in parsed)
    if len(normalized) != 3 or set(normalized) != set(_ORDER_LABELS):
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message=f"{field_name} must contain A, B, and C exactly once.",
        )
    return normalized


def _parse_order_strings(value: object, *, field_name: str) -> tuple[str, ...]:
    parsed = _parse_string_tuple(value, field_name=field_name)
    normalized = tuple(_normalize_order_string(item) for item in parsed)
    for item in normalized:
        parts = item.split("-")
        if len(parts) != 3 or set(parts) != set(_ORDER_LABELS):
            raise TypeSpecificGenerationError(
                code="OUTPUT_VALIDATION_FAILED",
                message=f"{field_name} entries must be order strings like A-B-C.",
            )
    return normalized


def _parse_why_wrong(value: object) -> dict[str, str]:
    if not isinstance(value, dict):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message="whyWrongKoByOption must be an object.",
        )
    return {
        label: _required_text(value.get(label), field_name=f"whyWrongKoByOption.{label}")
        for label in _DISTRACTOR_LABELS
    }


def _validate_option_uniqueness(
    values: list[str],
    *,
    error_code: str,
    error_message: str,
) -> None:
    normalized_values = [_normalize_text(value) for value in values]
    if len(set(normalized_values)) != len(normalized_values):
        raise TypeSpecificGenerationError(code=error_code, message=error_message)
    for index, current in enumerate(normalized_values):
        for other in normalized_values[index + 1 :]:
            if len(current) >= 8 and (current in other or other in current):
                raise TypeSpecificGenerationError(code=error_code, message=error_message)


def _validate_evidence_indexes(indexes: tuple[int, ...], *, limit: int) -> None:
    if any(index < 1 or index > limit for index in indexes):
        raise TypeSpecificGenerationError(
            code="OUTPUT_INVALID_EVIDENCE_TURN",
            message="evidenceTurnIndexes must point to existing turns.",
        )


def _required_text(value: object, *, field_name: str) -> str:
    if not isinstance(value, str):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be a non-empty string.",
        )
    normalized = value.strip()
    if not normalized:
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be a non-empty string.",
        )
    return normalized


def _required_int(value: object, *, field_name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be an integer.",
        )
    return value


def _required_bool(value: object, *, field_name: str) -> bool:
    if not isinstance(value, bool):
        raise TypeSpecificGenerationError(
            code="OUTPUT_MISSING_FIELD",
            message=f"{field_name} must be a boolean.",
        )
    return value


def _optional_text(value: object) -> str | None:
    if value is None:
        return None
    return _required_text(value, field_name="notes")


def _normalize_text(value: str) -> str:
    normalized = value.casefold()
    normalized = re.sub(r"[^a-z0-9 ]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _normalize_order_string(value: str) -> str:
    parts = re.split(r"[^A-Za-z]+", value.upper())
    normalized_parts = [part for part in parts if part]
    return "-".join(normalized_parts)


def _validate_visible_text(value: str, *, field_name: str) -> None:
    if contains_hidden_unicode(value):
        raise TypeSpecificGenerationError(
            code="OUTPUT_VALIDATION_FAILED",
            message=f"{field_name} contains hidden unicode.",
        )


def _count_words(text: str) -> int:
    return len(_TOKEN_RE.findall(text))


def _split_into_sentences(text: str) -> list[str]:
    stripped = text.strip()
    if not stripped:
        return []
    sentences = [chunk.strip() for chunk in _SENTENCE_SPLIT_RE.split(stripped) if chunk.strip()]
    return sentences if sentences else [stripped]
