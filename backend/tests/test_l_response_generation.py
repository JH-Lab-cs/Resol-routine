from __future__ import annotations

import pytest

from app.models.enums import Track
from app.services.l_response_generation_service import (
    LResponseGenerationError,
    LResponseSkeletonCandidate,
    build_deterministic_l_response_skeleton,
    compile_l_response_skeleton_candidate,
)


def test_compile_l_response_skeleton_builds_canonical_payload() -> None:
    skeleton = build_deterministic_l_response_skeleton(track=Track.M3, difficulty=1, index=1)

    compiled = compile_l_response_skeleton_candidate(skeleton)

    assert compiled["skill"] == "LISTENING"
    assert compiled["typeTag"] == "L_RESPONSE"
    assert compiled["transcriptText"].count("\n") == 1
    assert (
        compiled["question"]["stem"]
        == "What is the most appropriate response to the last speaker?"
    )
    assert compiled["question"]["answerKey"] == "A"
    assert set(compiled["question"]["options"].keys()) == {"A", "B", "C", "D", "E"}
    assert compiled["question"]["evidenceSentenceIds"] == ["s2"]
    assert compiled["question"]["whyWrongKoByOption"]["A"] == "정답 보기입니다."


def test_compile_l_response_skeleton_rejects_duplicate_response_texts() -> None:
    skeleton = build_deterministic_l_response_skeleton(track=Track.M3, difficulty=1, index=1)
    duplicate = LResponseSkeletonCandidate(
        track=skeleton.track,
        difficulty=skeleton.difficulty,
        type_tag=skeleton.type_tag,
        turns=skeleton.turns,
        response_prompt_speaker=skeleton.response_prompt_speaker,
        correct_response_text=skeleton.correct_response_text,
        distractor_response_texts=(
            skeleton.correct_response_text,
            "No, thanks.",
            "Maybe later.",
            "I already finished.",
        ),
        evidence_turn_indexes=skeleton.evidence_turn_indexes,
        why_correct_ko=skeleton.why_correct_ko,
        why_wrong_ko_by_option=skeleton.why_wrong_ko_by_option,
        notes=skeleton.notes,
    )

    with pytest.raises(LResponseGenerationError) as exc_info:
        compile_l_response_skeleton_candidate(duplicate)

    assert exc_info.value.code == "OUTPUT_INVALID_RESPONSE_OPTIONS"


def test_compile_l_response_skeleton_rejects_out_of_range_evidence_turn() -> None:
    skeleton = build_deterministic_l_response_skeleton(track=Track.M3, difficulty=1, index=1)
    invalid = LResponseSkeletonCandidate(
        track=skeleton.track,
        difficulty=skeleton.difficulty,
        type_tag=skeleton.type_tag,
        turns=skeleton.turns,
        response_prompt_speaker=skeleton.response_prompt_speaker,
        correct_response_text=skeleton.correct_response_text,
        distractor_response_texts=skeleton.distractor_response_texts,
        evidence_turn_indexes=(3,),
        why_correct_ko=skeleton.why_correct_ko,
        why_wrong_ko_by_option=skeleton.why_wrong_ko_by_option,
        notes=skeleton.notes,
    )

    with pytest.raises(LResponseGenerationError) as exc_info:
        compile_l_response_skeleton_candidate(invalid)

    assert exc_info.value.code == "OUTPUT_INVALID_EVIDENCE_TURN"
