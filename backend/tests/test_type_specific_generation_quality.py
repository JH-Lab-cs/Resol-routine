from __future__ import annotations

from dataclasses import replace

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import ContentTypeTag, Skill, Track
from app.services.content_calibration_service import evaluate_content_calibration
from app.services.type_specific_generation_quality_service import (
    LSituationContextualCandidate,
    RBlankDiscourseCandidate,
    ROrderDiscourseCandidate,
    TypeSpecificGenerationError,
    build_deterministic_l_situation_contextual_candidate,
    build_deterministic_r_blank_discourse_candidate,
    build_deterministic_r_order_discourse_candidate,
    compile_l_situation_contextual_candidate,
    compile_r_blank_discourse_candidate,
    compile_r_order_discourse_candidate,
)


def test_h2_l_situation_two_turn_direct_fixture_fails() -> None:
    candidate = LSituationContextualCandidate(
        track=Track.H2,
        difficulty=3,
        type_tag=ContentTypeTag.L_SITUATION,
        setting_summary="Two students talk after class.",
        turns=(
            {"speaker": "A", "text": "Can you help me tomorrow?"},
            {"speaker": "B", "text": "Yes, I can help you tomorrow."},
        ),
        implied_situation_label="simple request",
        context_elements=("request", "offer"),
        correct_option_text="Sure, I can help you tomorrow.",
        distractor_option_texts=(
            "I lost my notebook yesterday.",
            "The weather is cold today.",
            "My lunch box is in the classroom.",
            "Let's buy movie tickets after school.",
        ),
        plausible_distractor_labels=("B", "C"),
        evidence_turn_indexes=(2,),
        context_inference_score=72,
        direct_clue_penalty=24,
        final_turn_only_solvable=True,
        why_correct_ko="단순 직설형 예시",
        why_wrong_ko_by_option={
            "B": "오답",
            "C": "오답",
            "D": "오답",
            "E": "오답",
        },
    )

    try:
        compile_l_situation_contextual_candidate(candidate)
    except TypeSpecificGenerationError as exc:
        assert exc.code in {"OUTPUT_INVALID_TURN_COUNT", "OUTPUT_VALIDATION_FAILED"}
    else:
        raise AssertionError("two-turn direct H2 L_SITUATION fixture must fail")


def test_h2_l_situation_redesigned_contextual_fixture_passes_generation_and_calibration() -> None:
    payload = compile_l_situation_contextual_candidate(
        build_deterministic_l_situation_contextual_candidate(
            track=Track.H2,
            difficulty=3,
            index=1,
        )
    )

    result = _evaluate_compiled_payload(payload)

    assert result.passed is True
    assert not result.fail_reasons


def test_h2_l_situation_requires_two_plausible_distractors() -> None:
    candidate = build_deterministic_l_situation_contextual_candidate(
        track=Track.H2,
        difficulty=3,
        index=2,
    )
    candidate = replace(candidate, plausible_distractor_labels=("B",))

    try:
        compile_l_situation_contextual_candidate(candidate)
    except TypeSpecificGenerationError as exc:
        assert exc.code == "OUTPUT_VALIDATION_FAILED"
    else:
        raise AssertionError("H2 L_SITUATION must require at least two plausible distractors")


def test_h1_r_blank_too_short_paraphrase_only_fixture_fails() -> None:
    candidate = RBlankDiscourseCandidate(
        track=Track.H1,
        difficulty=2,
        type_tag=ContentTypeTag.R_BLANK,
        context_before_blank=(
            "Students revise their notes before a presentation.",
            "This habit helps them feel prepared.",
        ),
        context_after_blank=(
            "As a result, they feel calmer later.",
            "The teacher notices that they seem ready.",
        ),
        key_idea_map=("revision", "preparation"),
        blank_target_proposition="revision helps",
        correct_blank_text="Revision helps them feel prepared.",
        distractor_blank_texts=(
            "They should skip revision entirely.",
            "Preparation matters only after the presentation.",
            "Teachers dislike organized notes.",
            "Calm students never need evidence.",
        ),
        discourse_shift_label="contrast",
        paraphrase_only_risk=True,
        requires_inference_across_sentences=False,
        structure_complexity_score=36,
        direct_clue_penalty=24,
        inference_load_score=32,
        why_correct_ko="직접 단서 예시",
        why_wrong_ko_by_option={
            "B": "오답",
            "C": "오답",
            "D": "오답",
            "E": "오답",
        },
    )

    try:
        compile_r_blank_discourse_candidate(candidate)
    except TypeSpecificGenerationError as exc:
        assert exc.code == "OUTPUT_VALIDATION_FAILED"
    else:
        raise AssertionError("short paraphrase-only H1 R_BLANK fixture must fail")


def test_h1_r_blank_discourse_shift_fixture_passes_generation_and_calibration() -> None:
    payload = compile_r_blank_discourse_candidate(
        build_deterministic_r_blank_discourse_candidate(
            track=Track.H1,
            difficulty=2,
            index=1,
        )
    )

    result = _evaluate_compiled_payload(payload)

    assert result.passed is True
    assert not result.fail_reasons


def test_h1_r_order_simple_chronology_fixture_fails() -> None:
    candidate = ROrderDiscourseCandidate(
        track=Track.H1,
        difficulty=2,
        type_tag=ContentTypeTag.R_ORDER,
        introduction_sentences=(
            "Students met after school.",
            "Then they started a club project.",
        ),
        segment_texts={
            "A": "First, they chose a topic.",
            "B": "Next, they collected pictures.",
            "C": "Finally, they finished the poster.",
        },
        correct_order=("A", "B", "C"),
        plausible_distractor_orders=("A-C-B",),
        discourse_relation_labels=("consequence",),
        cue_word_only_solvable=True,
        transition_complexity_score=34,
        structure_complexity_score=34,
        direct_clue_penalty=26,
        why_correct_ko="연대기 단서 예시",
        why_wrong_ko_by_option={
            "B": "오답",
            "C": "오답",
            "D": "오답",
            "E": "오답",
        },
    )

    try:
        compile_r_order_discourse_candidate(candidate)
    except TypeSpecificGenerationError as exc:
        assert exc.code == "OUTPUT_VALIDATION_FAILED"
    else:
        raise AssertionError("simple chronology H1 R_ORDER fixture must fail")


def test_h1_r_order_discourse_relation_fixture_passes_generation_and_calibration() -> None:
    payload = compile_r_order_discourse_candidate(
        build_deterministic_r_order_discourse_candidate(
            track=Track.H1,
            difficulty=2,
            index=1,
        )
    )

    result = _evaluate_compiled_payload(payload)

    assert result.passed is True
    assert not result.fail_reasons


def _evaluate_compiled_payload(payload: dict[str, object]):
    skill = Skill(str(payload["skill"]))
    track = Track(str(payload["track"]))
    type_tag = str(payload["typeTag"])
    difficulty = int(payload["difficulty"])
    question_payload = payload["question"]
    assert isinstance(question_payload, dict)
    options = question_payload["options"]
    assert isinstance(options, dict)
    unit = ContentUnit(
        external_id=f"{track.value.lower()}-{type_tag.lower()}-generated",
        slug=f"{track.value.lower()}-{type_tag.lower()}-generated",
        track=track,
        skill=skill,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )

    if skill == Skill.READING:
        sentences = payload["sentences"]
        assert isinstance(sentences, list)
        revision = ContentUnitRevision(
            revision_no=1,
            revision_code=f"{track.value.lower()}-{type_tag.lower()}",
            generator_version="pytest-b2.6.20",
            body_text=str(payload["passage"]),
            transcript_text=None,
            explanation_text=str(question_payload["explanation"]),
            metadata_json={
                "typeTag": type_tag,
                "difficulty": difficulty,
                "sentences": sentences,
            },
            lifecycle_status=ContentLifecycleStatus.DRAFT,
        )
    else:
        turns = payload["turns"]
        sentences = payload["sentences"]
        assert isinstance(turns, list)
        assert isinstance(sentences, list)
        revision = ContentUnitRevision(
            revision_no=1,
            revision_code=f"{track.value.lower()}-{type_tag.lower()}",
            generator_version="pytest-b2.6.20",
            body_text=None,
            transcript_text=str(payload["transcriptText"]),
            explanation_text=str(question_payload["explanation"]),
            metadata_json={
                "typeTag": type_tag,
                "difficulty": difficulty,
                "turns": turns,
                "sentences": sentences,
            },
            lifecycle_status=ContentLifecycleStatus.DRAFT,
        )

    question = ContentQuestion(
        question_code=f"{type_tag.lower()}-q1",
        order_index=1,
        stem=str(question_payload["stem"]),
        choice_a=str(options["A"]),
        choice_b=str(options["B"]),
        choice_c=str(options["C"]),
        choice_d=str(options["D"]),
        choice_e=str(options["E"]),
        correct_answer="A",
        explanation=str(question_payload["explanation"]),
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
        },
    )
    return evaluate_content_calibration(unit=unit, revision=revision, questions=[question])
