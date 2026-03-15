from __future__ import annotations

import json
from pathlib import Path
from textwrap import dedent

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Skill, Track
from app.services.content_calibration_service import (
    ContentCalibrationLevel,
    evaluate_content_calibration,
)

_GOLD_SET_PATH = Path(__file__).resolve().parent / "fixtures" / "calibration_gold_set.json"


def test_h2_near_fail_insertion_is_hard_block_candidate() -> None:
    unit, revision, question, _ = _build_case_from_gold_fixture("h2_r_insertion_fail_1")

    result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])

    assert result.passed is False
    assert "length_too_short" in result.fail_reasons
    assert "direct_clue_too_strong" in result.fail_reasons
    assert result.calibrated_level in {
        ContentCalibrationLevel.TOO_EASY,
        ContentCalibrationLevel.EASY,
        ContentCalibrationLevel.STANDARD,
    }
    assert result.quality_gate_version is not None


def test_h2_h3_length_and_density_floor_fail_when_content_is_too_short() -> None:
    short_cases = [
        "h3_r_summary_fail_1",
        "h3_l_long_talk_fail_1",
    ]

    for fixture_id in short_cases:
        unit, revision, question, _ = _build_case_from_gold_fixture(fixture_id)
        result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])

        assert result.passed is False
        assert "length_too_short" in result.fail_reasons
        assert result.minimum_length_gate < 100


def test_m3_h1_warning_budget_allows_single_warning_but_requires_override_after_budget() -> None:
    h1_warning_only = evaluate_content_calibration(
        unit=_build_unit(track=Track.H1, skill=Skill.READING),
        revision=_build_reading_revision(
            track=Track.H1,
            type_tag="R_BLANK",
            difficulty=2,
            body_text=dedent(
                """
                Students often record questions in a notebook before revising a draft.
                The habit helps them compare their first explanation with a later version.
                When they revisit the notebook, they notice where evidence remains vague.
                Careful revision eventually leads them to justify each claim more precisely.
                Over time, the notebook becomes a record of how their reasoning improves.
                """
            ).strip(),
            sentences=[
                "Students often record questions in a notebook before revising a draft.",
                "The habit helps them compare their first explanation with a later version.",
                "When they revisit the notebook, they notice where evidence remains vague.",
                "Careful revision eventually leads them to justify each claim more precisely.",
                "Over time, the notebook becomes a record of how their reasoning improves.",
            ],
        ),
        questions=[
            _build_question(
                type_tag="R_BLANK",
                difficulty=2,
                stem="Which statement best completes the blank in the passage?",
                choices=(
                    "The notebook encourages deliberate revision and clearer reasoning.",
                    "The notebook should replace all teacher feedback immediately.",
                    "Students improve only when they avoid early mistakes entirely.",
                    "Revision matters less than writing quickly during class.",
                    "Evidence becomes unnecessary once the first draft is finished.",
                ),
            )
        ],
    )

    assert h1_warning_only.passed is True
    assert "reading_blank_discourse_marker_sparse" in h1_warning_only.warnings
    assert h1_warning_only.override_required is False

    h1_budget_exceeded = evaluate_content_calibration(
        unit=_build_unit(track=Track.H1, skill=Skill.READING),
            revision=_build_reading_revision(
                track=Track.H1,
                type_tag="R_ORDER",
                difficulty=2,
                body_text=(
                    "Students join debate club because they want to feel better "
                    "when they talk in class. "
                    "They give short talks to other students and repeat the same "
                    "simple points after each round. "
                    "Teachers say the group answers a little more in class later. "
                    "Many students come back the next year, but the passage gives only "
                    "basic reasons for that change."
                ),
                sentences=[
                    "Students join debate club because they want to feel better when "
                    "they talk in class.",
                    "They give short talks to other students and repeat the same "
                    "simple points after each round.",
                    "Teachers say the group answers a little more in class later.",
                    "Many students come back the next year, but the passage gives "
                    "only basic reasons for that change.",
                ],
            ),
        questions=[
            _build_question(
                type_tag="R_ORDER",
                difficulty=2,
                stem="Which order best matches the flow of the passage?",
                choices=(
                    "A-B-C",
                    "A-C-B",
                    "B-A-C",
                    "B-C-A",
                    "C-A-B",
                ),
            )
        ],
    )

    assert h1_budget_exceeded.passed is False
    assert h1_budget_exceeded.override_required is True
    assert "direct_clue_too_strong" not in h1_budget_exceeded.fail_reasons


def test_gold_anchor_regression_cases_match_expected_pass_fail() -> None:
    fixtures = _load_gold_fixtures()

    for fixture in fixtures:
        unit, revision, question, expected_levels = _build_case_from_fixture(fixture)
        result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])

        expected_pass = bool(fixture["expectedPass"])
        if expected_pass:
            assert result.passed is True, fixture["fixtureId"]
        else:
            assert result.passed is False, fixture["fixtureId"]
        assert result.calibrated_level.value in expected_levels, fixture["fixtureId"]


def test_track_representative_samples_align_with_expected_calibration_bands() -> None:
    samples = [
        (
            _build_unit(track=Track.M3, skill=Skill.READING),
            _build_reading_revision(
                track=Track.M3,
                type_tag="R_VOCAB",
                difficulty=1,
                body_text=(
                    "Lena brought a spare umbrella to work because it might rain. "
                    "When her coworker forgot theirs, Lena offered the spare one so they "
                    "would not get wet. Later she kept the spare umbrella in her locker "
                    "in case she needed it again."
                ),
                sentences=[
                    "Lena brought a spare umbrella to work because it might rain.",
                    "When her coworker forgot theirs, Lena offered the spare one so "
                    "they would not get wet.",
                    "Later she kept the spare umbrella in her locker in case she needed it again.",
                ],
            ),
            _build_question(
                type_tag="R_VOCAB",
                difficulty=1,
                stem="In the passage, what does the word 'spare' most nearly mean?",
                choices=("extra", "damaged", "expensive", "fashionable", "borrowed"),
            ),
            {ContentCalibrationLevel.EASY, ContentCalibrationLevel.STANDARD},
        ),
        (
            _build_unit(track=Track.H1, skill=Skill.READING),
            _build_reading_revision(
                track=Track.H1,
                type_tag="R_MAIN_IDEA",
                difficulty=2,
                body_text=dedent(
                    """
                    Students often think feedback is useful only after they make a mistake.
                    However, feedback can also guide planning before a task begins.
                    When learners compare early ideas with later revisions, they notice
                    patterns in their thinking. As a result, they become more deliberate
                    about setting goals before the next assignment starts.
                    That process builds stronger self-monitoring habits over time.
                    """
                ).strip(),
                sentences=[
                    "Students often think feedback is useful only after they make a mistake.",
                    "However, feedback can also guide planning before a task begins.",
                    "When learners compare early ideas with later revisions, they "
                    "notice patterns in their thinking.",
                    "As a result, they become more deliberate about setting goals "
                    "before the next assignment starts.",
                    "That process builds stronger self-monitoring habits over time.",
                ],
            ),
            _build_question(
                type_tag="R_MAIN_IDEA",
                difficulty=2,
                stem="What does the passage suggest is the main purpose of feedback?",
                choices=(
                    "Feedback supports planning and self-monitoring, not just correction.",
                    "Students should avoid mistakes before asking for feedback.",
                    "Teachers should rewrite students' work for them.",
                    "Planning matters less than revision in most classes.",
                    "Self-monitoring develops only through testing.",
                ),
            ),
            {ContentCalibrationLevel.STANDARD, ContentCalibrationLevel.HARD},
        ),
    ]

    for unit, revision, question, expected_levels in samples:
        result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])
        assert result.calibrated_level in expected_levels


def _build_case_from_gold_fixture(
    fixture_id: str,
) -> tuple[ContentUnit, ContentUnitRevision, ContentQuestion, set[str]]:
    fixture = next(item for item in _load_gold_fixtures() if item["fixtureId"] == fixture_id)
    return _build_case_from_fixture(fixture)


def _build_case_from_fixture(
    fixture: dict[str, object],
) -> tuple[ContentUnit, ContentUnitRevision, ContentQuestion, set[str]]:
    track = Track(str(fixture["track"]))
    skill = Skill(str(fixture["skill"]))
    type_tag = str(fixture["typeTag"])
    difficulty = int(fixture["difficulty"])
    expected_levels = {str(level) for level in fixture["expectedLevels"]}
    unit = _build_unit(track=track, skill=skill)

    if skill == Skill.READING:
        revision = _build_reading_revision(
            track=track,
            type_tag=type_tag,
            difficulty=difficulty,
            body_text=str(fixture["bodyText"]),
            sentences=[str(item) for item in fixture["sentences"]],
        )
    else:
        revision = _build_listening_revision(
            track=track,
            type_tag=type_tag,
            difficulty=difficulty,
            transcript_text=str(fixture["transcriptText"]),
            turns=[
                (str(item[0]), str(item[1]))
                for item in fixture["turns"]
            ],
            sentences=[str(item) for item in fixture["sentences"]],
        )

    question = _build_question(
        type_tag=type_tag,
        difficulty=difficulty,
        stem=str(fixture["stem"]),
        choices=tuple(str(choice) for choice in fixture["choices"]),
    )
    return unit, revision, question, expected_levels


def _load_gold_fixtures() -> list[dict[str, object]]:
    return json.loads(_GOLD_SET_PATH.read_text(encoding="utf-8"))


def _build_unit(*, track: Track, skill: Skill) -> ContentUnit:
    return ContentUnit(
        external_id=f"{track.value.lower()}-{skill.value.lower()}-unit",
        slug=f"{track.value.lower()}-{skill.value.lower()}-unit",
        track=track,
        skill=skill,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )


def _build_reading_revision(
    *,
    track: Track,
    type_tag: str,
    difficulty: int,
    body_text: str,
    sentences: list[str],
) -> ContentUnitRevision:
    return ContentUnitRevision(
        revision_no=1,
        revision_code=f"{track.value.lower()}-{type_tag.lower()}",
        generator_version="pytest-calibration",
        body_text=body_text,
        transcript_text=None,
        explanation_text="Korean explanation placeholder",
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
            "sentences": [
                {"id": f"s{index + 1}", "text": sentence}
                for index, sentence in enumerate(sentences)
            ],
        },
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )


def _build_listening_revision(
    *,
    track: Track,
    type_tag: str,
    difficulty: int,
    transcript_text: str,
    turns: list[tuple[str, str]],
    sentences: list[str],
) -> ContentUnitRevision:
    return ContentUnitRevision(
        revision_no=1,
        revision_code=f"{track.value.lower()}-{type_tag.lower()}",
        generator_version="pytest-calibration",
        body_text=None,
        transcript_text=transcript_text,
        explanation_text="Korean explanation placeholder",
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
            "turns": [{"speaker": speaker, "text": text} for speaker, text in turns],
            "sentences": [
                {"id": f"s{index + 1}", "text": sentence}
                for index, sentence in enumerate(sentences)
            ],
        },
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )


def _build_question(
    *,
    type_tag: str,
    difficulty: int,
    stem: str,
    choices: tuple[str, str, str, str, str],
) -> ContentQuestion:
    return ContentQuestion(
        question_code=f"{type_tag.lower()}-q1",
        order_index=1,
        stem=stem,
        choice_a=choices[0],
        choice_b=choices[1],
        choice_c=choices[2],
        choice_d=choices[3],
        choice_e=choices[4],
        correct_answer="A",
        explanation="Korean explanation placeholder",
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
        },
    )
