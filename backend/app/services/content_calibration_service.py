from __future__ import annotations

import json
import re
from dataclasses import dataclass
from enum import StrEnum
from functools import lru_cache
from pathlib import Path
from typing import cast

from app.core.input_validation import contains_hidden_unicode
from app.core.policies import (
    CONTENT_CALIBRATION_ACCEPTABLE_LEVELS_BY_TRACK,
    CONTENT_CALIBRATION_ALLOWED_WARNING_TRACKS,
    CONTENT_CALIBRATION_FAIL_CLOSE_TRACKS,
    CONTENT_CALIBRATION_FAIL_CLOSE_TYPE_TAGS,
    CONTENT_CALIBRATION_IMMEDIATE_BLOCK_FAIL_REASONS,
    CONTENT_CALIBRATION_RUBRIC_VERSION,
    CONTENT_CALIBRATION_WARNING_BUDGET_BY_TRACK,
    CONTENT_QUALITY_GATE_VERSION,
)
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import ContentTypeTag, Skill, Track

_TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z'-]*")
_ABSTRACT_SUFFIXES = ("tion", "sion", "ment", "ness", "ity", "ance", "ence", "ology")
_ADVANCED_LEXICON = {
    "abstract",
    "advantage",
    "analysis",
    "appropriate",
    "assumption",
    "beneficial",
    "consequently",
    "contextual",
    "contrast",
    "diverse",
    "enhance",
    "environmental",
    "establish",
    "exertion",
    "facilitate",
    "furthermore",
    "hypothesis",
    "indicate",
    "influence",
    "meticulous",
    "nonetheless",
    "perspective",
    "physiological",
    "profound",
    "psychological",
    "resilience",
    "rigorous",
    "substantial",
    "transformative",
    "undisturbed",
    "vantage",
}
_DISCOURSE_MARKERS = {
    "although",
    "because",
    "however",
    "if",
    "meanwhile",
    "moreover",
    "nevertheless",
    "nonetheless",
    "since",
    "therefore",
    "unless",
    "while",
    "yet",
}
_INFERENCE_MARKERS = {
    "attitude",
    "best",
    "implies",
    "imply",
    "infer",
    "intention",
    "most",
    "purpose",
    "suggests",
    "suggest",
    "summarizes",
    "theme",
    "why",
}
_DIRECT_CLUE_MARKERS = (
    "beyond these",
    "this is because",
    "therefore",
    "for this reason",
    "as a result",
    "on the other hand",
    "in addition",
    "for example",
    "in fact",
)
_CALIBRATION_ANCHOR_PATH = (
    Path(__file__).resolve().parents[2]
    / "shared"
    / "calibration"
    / "content_calibration_anchor_set.json"
)


class ContentCalibrationLevel(StrEnum):
    TOO_EASY = "TOO_EASY"
    EASY = "EASY"
    STANDARD = "STANDARD"
    HARD = "HARD"
    KILLER = "KILLER"
    TOO_HARD = "TOO_HARD"


@dataclass(frozen=True, slots=True)
class ContentCalibrationResult:
    calibration_score: int
    calibrated_level: ContentCalibrationLevel
    passed: bool
    warnings: tuple[str, ...]
    fail_reasons: tuple[str, ...]
    rubric_version: str
    quality_gate_version: str
    override_required: bool
    lexical_difficulty_score: int
    discourse_complexity_score: int
    distractor_strength_score: int
    clue_directness_penalty: int
    inference_load_score: int
    structure_complexity_score: int
    minimum_length_gate: int
    discourse_density_gate: int
    distractor_plausibility_gate: int
    transition_complexity_gate: int
    redundancy_penalty: int

    def to_metadata(self) -> dict[str, object]:
        return {
            "calibrationScore": self.calibration_score,
            "calibratedLevel": self.calibrated_level.value,
            "calibrationPass": self.passed,
            "calibrationWarnings": list(self.warnings),
            "calibrationFailReasons": list(self.fail_reasons),
            "calibrationRubricVersion": self.rubric_version,
            "qualityGateVersion": self.quality_gate_version,
            "overrideRequired": self.override_required,
            "calibrationMetrics": {
                "lexicalDifficultyScore": self.lexical_difficulty_score,
                "discourseComplexityScore": self.discourse_complexity_score,
                "distractorStrengthScore": self.distractor_strength_score,
                "clueDirectnessPenalty": self.clue_directness_penalty,
                "inferenceLoadScore": self.inference_load_score,
                "structureComplexityScore": self.structure_complexity_score,
            },
            "qualityMetrics": {
                "minimumLengthGate": self.minimum_length_gate,
                "discourseDensityGate": self.discourse_density_gate,
                "directCluePenalty": self.clue_directness_penalty,
                "distractorPlausibilityGate": self.distractor_plausibility_gate,
                "transitionComplexityGate": self.transition_complexity_gate,
                "redundancyPenalty": self.redundancy_penalty,
            },
        }


@lru_cache(maxsize=1)
def load_content_calibration_anchor_set() -> list[dict[str, object]]:
    anchors = json.loads(_CALIBRATION_ANCHOR_PATH.read_text(encoding="utf-8"))
    return cast(list[dict[str, object]], anchors)


def evaluate_content_calibration(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    questions: list[ContentQuestion],
) -> ContentCalibrationResult:
    if not questions:
        return _failed_result(
            score=0,
            level=ContentCalibrationLevel.TOO_EASY,
            fail_reasons=("missing_primary_question",),
            warnings=(),
            lexical=0,
            discourse=0,
            distractor=0,
            clue_penalty=0,
            inference=0,
            structure=0,
        )

    question = questions[0]
    type_tag = _extract_type_tag(revision, question)
    difficulty = _extract_difficulty(revision, question)
    if type_tag is None or difficulty is None:
        return _failed_result(
            score=0,
            level=ContentCalibrationLevel.TOO_EASY,
            fail_reasons=("missing_type_tag_or_difficulty",),
            warnings=(),
            lexical=0,
            discourse=0,
            distractor=0,
            clue_penalty=0,
            inference=0,
            structure=0,
        )

    canonical_text = _build_canonical_text(unit=unit, revision=revision, question=question)
    content_shape = _build_content_shape(revision=revision, canonical_text=canonical_text)
    lexical = _compute_lexical_difficulty_score(canonical_text)
    discourse = _compute_discourse_complexity_score(
        unit=unit,
        revision=revision,
        question=question,
        canonical_text=canonical_text,
    )
    distractor = _compute_distractor_strength_score(question)
    clue_penalty = _compute_clue_directness_penalty(
        unit=unit,
        revision=revision,
        question=question,
        canonical_text=canonical_text,
    )
    inference = _compute_inference_load_score(question=question, canonical_text=canonical_text)
    structure = _compute_structure_complexity_score(
        unit=unit,
        revision=revision,
        question=question,
        canonical_text=canonical_text,
    )
    minimum_length_gate = _compute_minimum_length_gate(
        track=unit.track,
        type_tag=type_tag,
        content_shape=content_shape,
    )
    discourse_density_gate = _compute_discourse_density_gate(content_shape=content_shape)
    distractor_plausibility_gate = _compute_distractor_plausibility_gate(
        question=question,
        type_tag=type_tag,
    )
    transition_complexity_gate = _compute_transition_complexity_gate(
        skill=unit.skill,
        content_shape=content_shape,
    )
    redundancy_penalty = _compute_redundancy_penalty(
        revision=revision,
        canonical_text=canonical_text,
    )

    raw_score = round(
        lexical * 0.18
        + discourse * 0.14
        + distractor * 0.12
        + inference * 0.16
        + structure * 0.18
        - clue_penalty * 0.45
        + minimum_length_gate * 0.04
        + discourse_density_gate * 0.03
        + distractor_plausibility_gate * 0.04
        + transition_complexity_gate * 0.03
        - redundancy_penalty * 0.16
        - 10
    )
    calibration_score = max(0, min(100, raw_score))
    calibrated_level = _score_to_level(calibration_score)

    warnings: list[str] = []
    fail_reasons: list[str] = []

    if canonical_text.hidden_unicode_detected:
        fail_reasons.append("hidden_unicode_detected")

    if calibrated_level.value not in _acceptable_levels_for_track_type(
        track=unit.track,
        type_tag=type_tag,
    ):
        fail_reasons.append(f"track_level_mismatch:{unit.track.value}:{calibrated_level.value}")

    if clue_penalty >= 25:
        fail_reasons.append("clue_directness_too_high")
    elif clue_penalty >= 15:
        warnings.append("clue_directness_review_recommended")

    if lexical < _lexical_minimum_for_track(unit.track):
        fail_reasons.append("lexical_difficulty_below_track_baseline")
    if discourse < _discourse_minimum_for_track(unit.track, unit.skill, type_tag):
        fail_reasons.append("discourse_complexity_below_track_baseline")
    if structure < _structure_minimum_for_track(unit.track, unit.skill, type_tag):
        fail_reasons.append("structure_complexity_below_track_baseline")
    if distractor < _distractor_minimum_for_track(unit.track, type_tag):
        fail_reasons.append("distractor_strength_below_track_baseline")
    if inference < _inference_minimum_for_track(unit.track, type_tag):
        fail_reasons.append("inference_load_below_track_baseline")

    _apply_type_tag_specific_rules(
        track=unit.track,
        skill=unit.skill,
        type_tag=type_tag,
        revision=revision,
        question=question,
        canonical_text=canonical_text,
        lexical=lexical,
        discourse=discourse,
        distractor=distractor,
        clue_penalty=clue_penalty,
        inference=inference,
        structure=structure,
        minimum_length_gate=minimum_length_gate,
        discourse_density_gate=discourse_density_gate,
        distractor_plausibility_gate=distractor_plausibility_gate,
        transition_complexity_gate=transition_complexity_gate,
        redundancy_penalty=redundancy_penalty,
        warnings=warnings,
        fail_reasons=fail_reasons,
    )

    passed = len(fail_reasons) == 0
    if passed and calibrated_level == ContentCalibrationLevel.TOO_HARD:
        fail_reasons.append(f"track_level_mismatch:{unit.track.value}:{calibrated_level.value}")
        passed = False

    shadow_warning_allowed = _allows_shadow_warning(track=unit.track, type_tag=type_tag)
    if (
        not passed
        and shadow_warning_allowed
        and calibrated_level not in {ContentCalibrationLevel.TOO_HARD}
    ):
        warnings.extend(fail_reasons)

    override_required = _compute_override_required(
        track=unit.track,
        warnings=warnings,
        fail_reasons=fail_reasons,
    )

    return ContentCalibrationResult(
        calibration_score=calibration_score,
        calibrated_level=calibrated_level,
        passed=passed,
        warnings=tuple(sorted(set(warnings))),
        fail_reasons=tuple(sorted(set(fail_reasons))),
        rubric_version=CONTENT_CALIBRATION_RUBRIC_VERSION,
        quality_gate_version=CONTENT_QUALITY_GATE_VERSION,
        override_required=override_required,
        lexical_difficulty_score=lexical,
        discourse_complexity_score=discourse,
        distractor_strength_score=distractor,
        clue_directness_penalty=clue_penalty,
        inference_load_score=inference,
        structure_complexity_score=structure,
        minimum_length_gate=minimum_length_gate,
        discourse_density_gate=discourse_density_gate,
        distractor_plausibility_gate=distractor_plausibility_gate,
        transition_complexity_gate=transition_complexity_gate,
        redundancy_penalty=redundancy_penalty,
    )


def merge_content_calibration_metadata(
    *,
    metadata_json: dict[str, object] | None,
    result: ContentCalibrationResult,
) -> dict[str, object]:
    merged = dict(metadata_json) if isinstance(metadata_json, dict) else {}
    merged.update(result.to_metadata())
    return merged


def extract_content_calibration_metadata(
    metadata_json: dict[str, object] | None,
) -> dict[str, object] | None:
    metadata = metadata_json if isinstance(metadata_json, dict) else {}
    if "calibrationScore" not in metadata:
        return None
    return {
        "calibrationScore": metadata.get("calibrationScore"),
        "calibratedLevel": metadata.get("calibratedLevel"),
        "calibrationPass": metadata.get("calibrationPass"),
        "calibrationWarnings": metadata.get("calibrationWarnings", []),
        "calibrationFailReasons": metadata.get("calibrationFailReasons", []),
        "calibrationRubricVersion": metadata.get("calibrationRubricVersion"),
        "qualityGateVersion": metadata.get("qualityGateVersion"),
        "overrideRequired": metadata.get("overrideRequired"),
    }


def is_calibration_publish_blocked(
    *,
    track: Track,
    type_tag: ContentTypeTag | None,
    result: ContentCalibrationResult,
) -> bool:
    if any(
        reason in CONTENT_CALIBRATION_IMMEDIATE_BLOCK_FAIL_REASONS for reason in result.fail_reasons
    ):
        return True
    if result.override_required:
        return True
    if type_tag is not None and _is_fail_close_target(track=track, type_tag=type_tag):
        return not result.passed
    return False


@dataclass(frozen=True, slots=True)
class _CanonicalText:
    body: str
    stem: str
    option_texts: tuple[str, ...]
    explanation: str
    hidden_unicode_detected: bool


@dataclass(frozen=True, slots=True)
class _ContentShape:
    word_count: int
    sentence_count: int
    turn_count: int
    transition_count: int
    average_sentence_words: float
    average_turn_words: float


@dataclass(frozen=True, slots=True)
class _QualityHardGateProfile:
    min_sentences: int = 0
    min_words: int = 0
    min_turns: int = 0
    min_discourse_density: int = 0
    min_transition_complexity: int = 0
    min_distractor_plausibility: int = 0
    max_direct_clue_penalty: int = 100


def _build_canonical_text(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    question: ContentQuestion,
) -> _CanonicalText:
    body = (revision.body_text or revision.transcript_text or "").strip()
    stem = question.stem.strip()
    option_texts = (
        question.choice_a.strip(),
        question.choice_b.strip(),
        question.choice_c.strip(),
        question.choice_d.strip(),
        question.choice_e.strip(),
    )
    explanation = (question.explanation or revision.explanation_text or "").strip()
    joined = "\n".join([body, stem, *option_texts, explanation])
    return _CanonicalText(
        body=body,
        stem=stem,
        option_texts=option_texts,
        explanation=explanation,
        hidden_unicode_detected=_contains_disallowed_hidden_unicode(joined),
    )


def _build_content_shape(
    *,
    revision: ContentUnitRevision,
    canonical_text: _CanonicalText,
) -> _ContentShape:
    sentences = _extract_sentence_texts(revision=revision)
    turns = _extract_turns(revision=revision)
    body_tokens = _tokenize(canonical_text.body)
    transition_count = sum(1 for token in body_tokens if token in _DISCOURSE_MARKERS)
    sentence_lengths = [len(_tokenize(sentence)) for sentence in sentences if sentence.strip()]
    turn_lengths = [len(_tokenize(turn["text"])) for turn in turns if turn["text"].strip()]
    average_sentence_words = (
        sum(sentence_lengths) / len(sentence_lengths) if sentence_lengths else 0.0
    )
    average_turn_words = sum(turn_lengths) / len(turn_lengths) if turn_lengths else 0.0
    return _ContentShape(
        word_count=len(body_tokens),
        sentence_count=len(sentences),
        turn_count=len(turns),
        transition_count=transition_count,
        average_sentence_words=average_sentence_words,
        average_turn_words=average_turn_words,
    )


def _extract_type_tag(
    revision: ContentUnitRevision, question: ContentQuestion
) -> ContentTypeTag | None:
    revision_metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    question_metadata = question.metadata_json if isinstance(question.metadata_json, dict) else {}
    raw = revision_metadata.get("typeTag", question_metadata.get("typeTag"))
    if not isinstance(raw, str):
        return None
    try:
        return ContentTypeTag(raw.strip())
    except ValueError:
        return None


def _extract_difficulty(revision: ContentUnitRevision, question: ContentQuestion) -> int | None:
    revision_metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    question_metadata = question.metadata_json if isinstance(question.metadata_json, dict) else {}
    raw = revision_metadata.get("difficulty", question_metadata.get("difficulty"))
    if isinstance(raw, bool) or raw is None:
        return None
    try:
        difficulty = int(raw)
    except (TypeError, ValueError):
        return None
    if not 1 <= difficulty <= 5:
        return None
    return difficulty


def _compute_lexical_difficulty_score(text: _CanonicalText) -> int:
    tokens = _tokenize(" ".join([text.body, text.stem, *text.option_texts]))
    if not tokens:
        return 0
    advanced_count = sum(1 for token in tokens if token in _ADVANCED_LEXICON)
    long_count = sum(1 for token in tokens if len(token) >= 8)
    abstract_count = sum(1 for token in tokens if token.endswith(_ABSTRACT_SUFFIXES))
    average_len = sum(len(token) for token in tokens) / len(tokens)
    ratio = (advanced_count + abstract_count + (long_count * 0.5)) / len(tokens)
    score = 15 + ratio * 220 + average_len * 3.2 + min(long_count, 12) * 1.8
    return max(0, min(100, round(score)))


def _compute_discourse_complexity_score(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    question: ContentQuestion,
    canonical_text: _CanonicalText,
) -> int:
    sentences = _extract_sentence_texts(revision=revision)
    turns = _extract_turns(revision=revision)
    tokens = _tokenize(canonical_text.body)
    marker_count = sum(1 for token in tokens if token in _DISCOURSE_MARKERS)
    subordinate_count = canonical_text.body.count(",") + canonical_text.body.count(";")
    if unit.skill == Skill.LISTENING:
        score = float(
            len(turns) * 10 + len(sentences) * 6 + marker_count * 8 + subordinate_count * 2
        )
    else:
        score = float(len(sentences) * 8 + marker_count * 10 + subordinate_count * 3)
    if question.explanation:
        score += min(len(_tokenize(question.explanation)) * 0.8, 10)
    return max(0, min(100, round(score)))


def _compute_distractor_strength_score(question: ContentQuestion) -> int:
    option_texts = [
        question.choice_a.strip(),
        question.choice_b.strip(),
        question.choice_c.strip(),
        question.choice_d.strip(),
        question.choice_e.strip(),
    ]
    normalized = [_normalize_text(option) for option in option_texts]
    unique_ratio = len(set(normalized)) / 5
    lengths = [max(1, len(_tokenize(option))) for option in option_texts]
    average_length = sum(lengths) / len(lengths)
    spread = max(lengths) - min(lengths)
    score = 25 + unique_ratio * 40 + min(average_length * 7, 25) - min(spread * 2, 18)
    return max(0, min(100, round(score)))


def _compute_clue_directness_penalty(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    question: ContentQuestion,
    canonical_text: _CanonicalText,
) -> int:
    haystack = " ".join(
        [canonical_text.body, canonical_text.stem, canonical_text.explanation]
    ).lower()
    penalty = 0
    for marker in _DIRECT_CLUE_MARKERS:
        if marker in haystack:
            penalty += 12 if marker in {"beyond these", "in addition", "this is because"} else 9
    if unit.skill == Skill.READING and len(_extract_sentence_texts(revision=revision)) <= 4:
        penalty += 8
    if unit.skill == Skill.LISTENING and len(_extract_turns(revision=revision)) <= 2:
        penalty += 8
    if "most nearly mean" in canonical_text.stem.lower():
        penalty += 4
    return max(0, min(100, penalty))


def _compute_inference_load_score(
    *,
    question: ContentQuestion,
    canonical_text: _CanonicalText,
) -> int:
    tokens = _tokenize(" ".join([canonical_text.body, canonical_text.stem]))
    marker_count = sum(1 for token in tokens if token in _INFERENCE_MARKERS)
    abstract_count = sum(1 for token in tokens if token.endswith(_ABSTRACT_SUFFIXES))
    score = 10 + marker_count * 12 + abstract_count * 4
    return max(0, min(100, round(score)))


def _compute_structure_complexity_score(
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    question: ContentQuestion,
    canonical_text: _CanonicalText,
) -> int:
    sentences = _extract_sentence_texts(revision=revision)
    turns = _extract_turns(revision=revision)
    score = len(sentences) * 7
    if unit.skill == Skill.LISTENING:
        score += len(turns) * 9
    body = canonical_text.body
    for marker in ("[1]", "[2]", "[3]", "[4]"):
        if marker in body:
            score += 6
    if question.stem.count("?") >= 1:
        score += 3
    return max(0, min(100, round(score)))


def _compute_minimum_length_gate(
    *,
    track: Track,
    type_tag: ContentTypeTag,
    content_shape: _ContentShape,
) -> int:
    profile = _quality_hard_gate_profile(track=track, type_tag=type_tag)
    penalties = 0
    if profile.min_sentences > 0 and content_shape.sentence_count < profile.min_sentences:
        penalties += (profile.min_sentences - content_shape.sentence_count) * 20
    if profile.min_words > 0 and content_shape.word_count < profile.min_words:
        missing_ratio = (profile.min_words - content_shape.word_count) / profile.min_words
        penalties += round(missing_ratio * 60)
    if profile.min_turns > 0 and content_shape.turn_count < profile.min_turns:
        penalties += (profile.min_turns - content_shape.turn_count) * 25
    return max(0, min(100, 100 - penalties))


def _compute_discourse_density_gate(*, content_shape: _ContentShape) -> int:
    score = (
        10
        + content_shape.sentence_count * 7
        + content_shape.turn_count * 8
        + content_shape.transition_count * 10
        + min(content_shape.average_sentence_words * 2.2, 28)
        + min(content_shape.average_turn_words * 1.8, 18)
    )
    return max(0, min(100, round(score)))


def _compute_distractor_plausibility_gate(
    *,
    question: ContentQuestion,
    type_tag: ContentTypeTag,
) -> int:
    options = [
        question.choice_a.strip(),
        question.choice_b.strip(),
        question.choice_c.strip(),
        question.choice_d.strip(),
        question.choice_e.strip(),
    ]
    distractors = [_normalize_text(option) for option in options[1:]]
    unique_ratio = len(set(distractors)) / max(1, len(distractors))
    lengths = [len(_tokenize(option)) for option in options]
    spread = max(lengths) - min(lengths)
    if type_tag in {
        ContentTypeTag.R_INSERTION,
        ContentTypeTag.R_ORDER,
        ContentTypeTag.R_SUMMARY,
    }:
        score = 42 + unique_ratio * 28 + max(0, 18 - spread * 2)
        return max(0, min(100, round(score)))
    correct = _normalize_text(options[0])
    overlap_scores: list[float] = []
    for distractor in distractors:
        distractor_tokens = set(distractor.split())
        correct_tokens = set(correct.split())
        if not distractor_tokens or not correct_tokens:
            overlap_scores.append(0.0)
            continue
        overlap_scores.append(len(distractor_tokens & correct_tokens) / len(correct_tokens))
    average_overlap = sum(overlap_scores) / len(overlap_scores) if overlap_scores else 0.0
    score = 30 + unique_ratio * 30 + average_overlap * 25 + max(0, 15 - spread * 3)
    return max(0, min(100, round(score)))


def _compute_transition_complexity_gate(
    *,
    skill: Skill,
    content_shape: _ContentShape,
) -> int:
    score = (
        20
        + content_shape.transition_count * 15
        + content_shape.sentence_count * 4
        + content_shape.turn_count * (6 if skill == Skill.LISTENING else 2)
    )
    return max(0, min(100, round(score)))


def _compute_redundancy_penalty(
    *,
    revision: ContentUnitRevision,
    canonical_text: _CanonicalText,
) -> int:
    sentences = _extract_sentence_texts(revision=revision)
    normalized_sentences = [_normalize_text(sentence) for sentence in sentences if sentence.strip()]
    duplicate_sentences = len(normalized_sentences) - len(set(normalized_sentences))
    repeated_prefixes = len(
        {
            " ".join(sentence.split()[:3])
            for sentence in normalized_sentences
            if len(sentence.split()) >= 3
        }
    )
    prefix_penalty = max(0, len(normalized_sentences) - repeated_prefixes)
    body_tokens = _tokenize(canonical_text.body)
    unique_ratio = len(set(body_tokens)) / len(body_tokens) if body_tokens else 1.0
    score = (
        duplicate_sentences * 18 + prefix_penalty * 7 + max(0, round((0.55 - unique_ratio) * 80))
    )
    return max(0, min(100, score))


def _apply_type_tag_specific_rules(
    *,
    track: Track,
    skill: Skill,
    type_tag: ContentTypeTag,
    revision: ContentUnitRevision,
    question: ContentQuestion,
    canonical_text: _CanonicalText,
    lexical: int,
    discourse: int,
    distractor: int,
    clue_penalty: int,
    inference: int,
    structure: int,
    minimum_length_gate: int,
    discourse_density_gate: int,
    distractor_plausibility_gate: int,
    transition_complexity_gate: int,
    redundancy_penalty: int,
    warnings: list[str],
    fail_reasons: list[str],
) -> None:
    body_lower = canonical_text.body.lower()
    stem_lower = canonical_text.stem.lower()
    turn_count = len(_extract_turns(revision=revision))
    sentence_count = len(_extract_sentence_texts(revision=revision))

    if type_tag == ContentTypeTag.R_INSERTION:
        if clue_penalty >= 18:
            fail_reasons.append("reading_insertion_direct_clue")
        if sentence_count <= 4 and discourse < 45:
            fail_reasons.append("reading_insertion_single_slot_too_obvious")
        if track in {Track.H2, Track.H3} and structure < 55:
            fail_reasons.append("reading_insertion_structure_too_simple")
    elif type_tag == ContentTypeTag.R_BLANK:
        if track in {Track.H2, Track.H3} and inference < 45:
            fail_reasons.append("reading_blank_inference_load_too_low")
        if track == Track.H1 and inference < 34:
            fail_reasons.append("reading_blank_inference_load_too_low")
        if track == Track.H1 and structure < 40:
            fail_reasons.append("reading_blank_structure_too_simple")
        if (
            "although" not in body_lower
            and "however" not in body_lower
            and "while" not in body_lower
            and "therefore" not in body_lower
            and "instead" not in body_lower
        ):
            warnings.append("reading_blank_discourse_marker_sparse")
    elif type_tag in {ContentTypeTag.R_ORDER, ContentTypeTag.R_SUMMARY, ContentTypeTag.R_VOCAB}:
        if track in {Track.H2, Track.H3} and inference < 45:
            fail_reasons.append("reading_discourse_inference_too_low")
        if track in {Track.H2, Track.H3} and lexical < 42:
            fail_reasons.append("reading_lexical_density_too_low")
        if type_tag == ContentTypeTag.R_ORDER and track == Track.H1 and inference < 34:
            fail_reasons.append("reading_discourse_inference_too_low")
        if type_tag == ContentTypeTag.R_ORDER and track == Track.H1 and structure < 42:
            fail_reasons.append("reading_order_structure_too_simple")
    elif type_tag == ContentTypeTag.L_RESPONSE:
        if turn_count != 2:
            fail_reasons.append("listening_response_turn_count_invalid")
        if distractor < 55:
            fail_reasons.append("listening_response_distractor_strength_too_low")
        if clue_penalty >= 20:
            fail_reasons.append("listening_response_answer_too_obvious")
    elif type_tag == ContentTypeTag.L_LONG_TALK:
        if sentence_count < 4 or turn_count < 4:
            fail_reasons.append("listening_long_talk_density_too_low")
        if track in {Track.H2, Track.H3} and inference < 40:
            fail_reasons.append("listening_long_talk_inference_too_low")
    elif type_tag == ContentTypeTag.L_SITUATION:
        situation_inference_minimum = {
            Track.H1: 28,
            Track.H2: 34,
            Track.H3: 34,
        }.get(track, 24)
        if track in {Track.H1, Track.H2, Track.H3} and inference < situation_inference_minimum:
            fail_reasons.append("listening_situation_context_inference_too_low")
        if clue_penalty >= 20:
            fail_reasons.append("listening_situation_surface_clue_too_high")
        if track == Track.H2 and turn_count < 3:
            fail_reasons.append("listening_situation_density_too_low")

    if track == Track.H3 and skill == Skill.READING and lexical < 50:
        fail_reasons.append("h3_reading_lexical_density_too_low")
    if track == Track.H3 and skill == Skill.LISTENING and (turn_count < 4 or sentence_count < 4):
        fail_reasons.append("h3_listening_density_too_low")
    if track == Track.M3 and lexical >= 72:
        warnings.append("m3_difficulty_review_recommended")
    if "placeholder" in stem_lower or "placeholder" in body_lower:
        fail_reasons.append("placeholder_text_detected")

    _apply_phase2_quality_rules(
        track=track,
        type_tag=type_tag,
        sentence_count=sentence_count,
        turn_count=turn_count,
        clue_penalty=clue_penalty,
        minimum_length_gate=minimum_length_gate,
        discourse_density_gate=discourse_density_gate,
        distractor_plausibility_gate=distractor_plausibility_gate,
        transition_complexity_gate=transition_complexity_gate,
        redundancy_penalty=redundancy_penalty,
        warnings=warnings,
        fail_reasons=fail_reasons,
    )


def _apply_phase2_quality_rules(
    *,
    track: Track,
    type_tag: ContentTypeTag,
    sentence_count: int,
    turn_count: int,
    clue_penalty: int,
    minimum_length_gate: int,
    discourse_density_gate: int,
    distractor_plausibility_gate: int,
    transition_complexity_gate: int,
    redundancy_penalty: int,
    warnings: list[str],
    fail_reasons: list[str],
) -> None:
    profile = _quality_hard_gate_profile(track=track, type_tag=type_tag)
    if profile.min_sentences > 0 and sentence_count < profile.min_sentences:
        fail_reasons.append("length_too_short")
    if profile.min_turns > 0 and turn_count < profile.min_turns:
        fail_reasons.append("length_too_short")
    if profile.min_words > 0 and minimum_length_gate < 100:
        fail_reasons.append("length_too_short")
    if clue_penalty > profile.max_direct_clue_penalty:
        fail_reasons.append("direct_clue_too_strong")
    if discourse_density_gate < profile.min_discourse_density:
        fail_reasons.append("discourse_density_too_low")
    if distractor_plausibility_gate < profile.min_distractor_plausibility:
        fail_reasons.append("distractor_plausibility_too_low")
    if transition_complexity_gate < profile.min_transition_complexity:
        fail_reasons.append("transition_complexity_too_low")
    if redundancy_penalty >= 24:
        warnings.append("redundancy_review_recommended")


def _quality_hard_gate_profile(
    *,
    track: Track,
    type_tag: ContentTypeTag,
) -> _QualityHardGateProfile:
    profiles: dict[tuple[Track, ContentTypeTag], _QualityHardGateProfile] = {
        (Track.H1, ContentTypeTag.R_INSERTION): _QualityHardGateProfile(
            min_sentences=4,
            min_words=60,
            min_discourse_density=42,
            min_transition_complexity=30,
            min_distractor_plausibility=44,
            max_direct_clue_penalty=18,
        ),
        (Track.H1, ContentTypeTag.R_BLANK): _QualityHardGateProfile(
            min_sentences=4,
            min_words=130,
            min_discourse_density=46,
            min_transition_complexity=34,
            min_distractor_plausibility=46,
            max_direct_clue_penalty=17,
        ),
        (Track.H1, ContentTypeTag.R_ORDER): _QualityHardGateProfile(
            min_sentences=4,
            min_words=130,
            min_discourse_density=46,
            min_transition_complexity=36,
            min_distractor_plausibility=46,
            max_direct_clue_penalty=17,
        ),
        (Track.H1, ContentTypeTag.R_SUMMARY): _QualityHardGateProfile(
            min_sentences=4,
            min_words=65,
            min_discourse_density=44,
            min_transition_complexity=32,
            min_distractor_plausibility=45,
            max_direct_clue_penalty=17,
        ),
        (Track.H2, ContentTypeTag.R_INSERTION): _QualityHardGateProfile(
            min_sentences=5,
            min_words=75,
            min_discourse_density=58,
            min_transition_complexity=42,
            min_distractor_plausibility=54,
            max_direct_clue_penalty=17,
        ),
        (Track.H2, ContentTypeTag.R_ORDER): _QualityHardGateProfile(
            min_sentences=5,
            min_words=78,
            min_discourse_density=56,
            min_transition_complexity=44,
            min_distractor_plausibility=52,
            max_direct_clue_penalty=17,
        ),
        (Track.H2, ContentTypeTag.R_SUMMARY): _QualityHardGateProfile(
            min_sentences=5,
            min_words=80,
            min_discourse_density=58,
            min_transition_complexity=42,
            min_distractor_plausibility=55,
            max_direct_clue_penalty=16,
        ),
        (Track.H3, ContentTypeTag.R_INSERTION): _QualityHardGateProfile(
            min_sentences=6,
            min_words=95,
            min_discourse_density=66,
            min_transition_complexity=48,
            min_distractor_plausibility=58,
            max_direct_clue_penalty=15,
        ),
        (Track.H3, ContentTypeTag.R_ORDER): _QualityHardGateProfile(
            min_sentences=6,
            min_words=98,
            min_discourse_density=66,
            min_transition_complexity=50,
            min_distractor_plausibility=58,
            max_direct_clue_penalty=15,
        ),
        (Track.H3, ContentTypeTag.R_SUMMARY): _QualityHardGateProfile(
            min_sentences=6,
            min_words=100,
            min_discourse_density=68,
            min_transition_complexity=50,
            min_distractor_plausibility=60,
            max_direct_clue_penalty=14,
        ),
        (Track.H1, ContentTypeTag.L_SITUATION): _QualityHardGateProfile(
            min_sentences=2,
            min_words=18,
            min_turns=2,
            min_discourse_density=34,
            min_transition_complexity=26,
            min_distractor_plausibility=46,
            max_direct_clue_penalty=18,
        ),
        (Track.H1, ContentTypeTag.L_LONG_TALK): _QualityHardGateProfile(
            min_sentences=3,
            min_words=36,
            min_turns=3,
            min_discourse_density=40,
            min_transition_complexity=28,
            min_distractor_plausibility=40,
            max_direct_clue_penalty=18,
        ),
        (Track.H2, ContentTypeTag.L_SITUATION): _QualityHardGateProfile(
            min_sentences=3,
            min_words=42,
            min_turns=3,
            min_discourse_density=50,
            min_transition_complexity=38,
            min_distractor_plausibility=56,
            max_direct_clue_penalty=16,
        ),
        (Track.H3, ContentTypeTag.L_SITUATION): _QualityHardGateProfile(
            min_sentences=2,
            min_words=28,
            min_turns=2,
            min_discourse_density=46,
            min_transition_complexity=36,
            min_distractor_plausibility=56,
            max_direct_clue_penalty=16,
        ),
        (Track.H2, ContentTypeTag.L_LONG_TALK): _QualityHardGateProfile(
            min_sentences=4,
            min_words=55,
            min_turns=4,
            min_discourse_density=54,
            min_transition_complexity=40,
            min_distractor_plausibility=48,
            max_direct_clue_penalty=18,
        ),
        (Track.H3, ContentTypeTag.L_LONG_TALK): _QualityHardGateProfile(
            min_sentences=5,
            min_words=75,
            min_turns=5,
            min_discourse_density=60,
            min_transition_complexity=44,
            min_distractor_plausibility=52,
            max_direct_clue_penalty=17,
        ),
    }
    return profiles.get((track, type_tag), _QualityHardGateProfile())


def _is_fail_close_target(*, track: Track, type_tag: ContentTypeTag) -> bool:
    return (
        track.value in CONTENT_CALIBRATION_FAIL_CLOSE_TRACKS
        and type_tag.value in CONTENT_CALIBRATION_FAIL_CLOSE_TYPE_TAGS
    )


def _allows_shadow_warning(*, track: Track, type_tag: ContentTypeTag) -> bool:
    if track.value in CONTENT_CALIBRATION_ALLOWED_WARNING_TRACKS:
        return True
    return not _is_fail_close_target(track=track, type_tag=type_tag)


def _compute_override_required(
    *,
    track: Track,
    warnings: list[str],
    fail_reasons: list[str],
) -> bool:
    budget = CONTENT_CALIBRATION_WARNING_BUDGET_BY_TRACK.get(track.value)
    if budget is None:
        return False
    unique_warning_codes = set(warnings) | set(fail_reasons)
    if len(unique_warning_codes) > budget:
        return True
    return False


def _lexical_minimum_for_track(track: Track) -> int:
    return {
        Track.M3: 18,
        Track.H1: 26,
        Track.H2: 38,
        Track.H3: 48,
    }[track]


def _acceptable_levels_for_track_type(
    *,
    track: Track,
    type_tag: ContentTypeTag,
) -> tuple[str, ...]:
    if track == Track.H2 and type_tag == ContentTypeTag.L_SITUATION:
        return ("STANDARD", "HARD")
    return CONTENT_CALIBRATION_ACCEPTABLE_LEVELS_BY_TRACK[track.value]


def _discourse_minimum_for_track(track: Track, skill: Skill, type_tag: ContentTypeTag) -> int:
    base = {
        Track.M3: 18,
        Track.H1: 24,
        Track.H2: 34,
        Track.H3: 42,
    }[track]
    if type_tag == ContentTypeTag.L_SITUATION:
        return max(18, base - 6)
    if skill == Skill.LISTENING:
        return base
    return base + 4


def _structure_minimum_for_track(track: Track, skill: Skill, type_tag: ContentTypeTag) -> int:
    base = {
        Track.M3: 20,
        Track.H1: 28,
        Track.H2: 38,
        Track.H3: 46,
    }[track]
    if type_tag == ContentTypeTag.L_SITUATION:
        return max(18, base - 6)
    if skill == Skill.LISTENING:
        return base
    return base + 4


def _distractor_minimum_for_track(track: Track, type_tag: ContentTypeTag) -> int:
    if type_tag in {ContentTypeTag.R_INSERTION, ContentTypeTag.R_ORDER, ContentTypeTag.R_SUMMARY}:
        return {
            Track.M3: 20,
            Track.H1: 26,
            Track.H2: 32,
            Track.H3: 36,
        }[track]
    return {
        Track.M3: 28,
        Track.H1: 34,
        Track.H2: 44,
        Track.H3: 50,
    }[track]


def _inference_minimum_for_track(track: Track, type_tag: ContentTypeTag) -> int:
    if type_tag == ContentTypeTag.L_SITUATION:
        return {
            Track.M3: 18,
            Track.H1: 24,
            Track.H2: 28,
            Track.H3: 34,
        }[track]
    if type_tag in {ContentTypeTag.R_VOCAB, ContentTypeTag.R_MAIN_IDEA, ContentTypeTag.R_DETAIL}:
        return {
            Track.M3: 16,
            Track.H1: 22,
            Track.H2: 30,
            Track.H3: 34,
        }[track]
    return {
        Track.M3: 18,
        Track.H1: 26,
        Track.H2: 36,
        Track.H3: 42,
    }[track]


def _score_to_level(score: int) -> ContentCalibrationLevel:
    if score < 20:
        return ContentCalibrationLevel.TOO_EASY
    if score < 38:
        return ContentCalibrationLevel.EASY
    if score < 58:
        return ContentCalibrationLevel.STANDARD
    if score < 78:
        return ContentCalibrationLevel.HARD
    if score <= 92:
        return ContentCalibrationLevel.KILLER
    return ContentCalibrationLevel.TOO_HARD


def _extract_turns(*, revision: ContentUnitRevision) -> list[dict[str, str]]:
    metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    raw_turns = metadata.get("turns")
    if not isinstance(raw_turns, list):
        return []
    turns: list[dict[str, str]] = []
    for row in raw_turns:
        if (
            isinstance(row, dict)
            and isinstance(row.get("speaker"), str)
            and isinstance(row.get("text"), str)
        ):
            turns.append({"speaker": row["speaker"].strip(), "text": row["text"].strip()})
    return turns


def _extract_sentence_texts(*, revision: ContentUnitRevision) -> list[str]:
    metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    raw_sentences = metadata.get("sentences")
    if not isinstance(raw_sentences, list):
        return _fallback_sentence_split(revision.body_text or revision.transcript_text or "")
    sentences: list[str] = []
    for row in raw_sentences:
        if isinstance(row, dict) and isinstance(row.get("text"), str):
            sentences.append(row["text"].strip())
    return [sentence for sentence in sentences if sentence]


def _fallback_sentence_split(text: str) -> list[str]:
    return [chunk.strip() for chunk in re.split(r"(?<=[.!?])\s+", text) if chunk.strip()]


def _tokenize(text: str) -> list[str]:
    return [match.group(0).lower() for match in _TOKEN_RE.finditer(text)]


def _contains_disallowed_hidden_unicode(value: str) -> bool:
    sanitized = value.replace("\n", "").replace("\r", "").replace("\t", "")
    return contains_hidden_unicode(sanitized)


def _normalize_text(text: str) -> str:
    return " ".join(_tokenize(text))


def _failed_result(
    *,
    score: int,
    level: ContentCalibrationLevel,
    fail_reasons: tuple[str, ...],
    warnings: tuple[str, ...],
    lexical: int,
    discourse: int,
    distractor: int,
    clue_penalty: int,
    inference: int,
    structure: int,
) -> ContentCalibrationResult:
    return ContentCalibrationResult(
        calibration_score=score,
        calibrated_level=level,
        passed=False,
        warnings=warnings,
        fail_reasons=fail_reasons,
        rubric_version=CONTENT_CALIBRATION_RUBRIC_VERSION,
        quality_gate_version=CONTENT_QUALITY_GATE_VERSION,
        override_required=False,
        lexical_difficulty_score=lexical,
        discourse_complexity_score=discourse,
        distractor_strength_score=distractor,
        clue_directness_penalty=clue_penalty,
        inference_load_score=inference,
        structure_complexity_score=structure,
        minimum_length_gate=0,
        discourse_density_gate=0,
        distractor_plausibility_gate=0,
        transition_complexity_gate=0,
        redundancy_penalty=0,
    )
