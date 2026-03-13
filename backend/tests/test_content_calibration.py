from __future__ import annotations

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


def test_h2_reading_insertion_with_direct_clue_and_weak_structure_fails() -> None:
    unit = _build_unit(track=Track.H2, skill=Skill.READING)
    revision = _build_reading_revision(
        track=Track.H2,
        type_tag="R_INSERTION",
        difficulty=3,
        body_text=(
            "Many people enjoy hiking because it offers physical exercise and time in nature. [1] "
            "The trails can vary from easy forest paths to steep mountain climbs. [2] "
            "Hiking also gives people a chance to observe wildlife in natural habitats. [3] "
            "However, hikers should prepare carefully by bringing enough water and proper gear. [4]"
        ),
        sentences=[
            "Many people enjoy hiking because it offers physical exercise and time in nature.",
            "The trails can vary from easy forest paths to steep mountain climbs.",
            "Hiking also gives people a chance to observe wildlife in natural habitats.",
            "However, hikers should prepare carefully by bringing enough water and proper gear.",
        ],
    )
    question = _build_question(
        type_tag="R_INSERTION",
        difficulty=3,
        stem=(
            "Where is the best place to insert the sentence "
            "'Beyond these physical advantages, hiking can improve mental well-being'?"
        ),
        choices=("A", "B", "C", "D", "E"),
    )

    result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])

    assert result.passed is False
    assert result.calibrated_level in {
        ContentCalibrationLevel.TOO_EASY,
        ContentCalibrationLevel.EASY,
        ContentCalibrationLevel.STANDARD,
    }
    assert result.fail_reasons
    assert any(
        reason in result.fail_reasons
        for reason in (
            "reading_insertion_single_slot_too_obvious",
            "reading_insertion_direct_clue",
            "track_level_mismatch:H2:STANDARD",
            "inference_load_below_track_baseline",
        )
    )


def test_track_representative_samples_align_with_expected_calibration_bands() -> None:
    m3_body = dedent(
        """
        Lena brought a spare umbrella to work because it might rain.
        When her coworker forgot theirs, Lena offered the spare one so they would not get wet.
        Later she kept the spare umbrella in her locker in case she needed it again.
        """
    ).strip()
    h1_body = dedent(
        """
        Students often think feedback is useful only after they make a mistake.
        However, feedback can also guide planning before a task begins.
        When learners compare early ideas with later revisions,
        they notice patterns in their thinking.
        As a result, they become more deliberate about setting goals
        before the next assignment starts.
        That process builds stronger self-monitoring habits over time.
        """
    ).strip()
    h2_body = dedent(
        """
        Many people are drawn to hiking as it offers a synergistic blend
        of rigorous physical exertion
        and a profound opportunity to reconnect with the natural world. [1]
        The difficulty of trails can vary substantially,
        ranging from rudimentary forest paths to
        grueling mountain ascents that demand significant stamina. [2]
        Hiking also serves as an exceptional vantage point
        for observing diverse wildlife in their
        undisturbed habitats, fostering environmental awareness. [3]
        Nonetheless, such benefits can only be fully realized
        when preceded by meticulous preparation,
        including the carriage of ample hydration and specialized gear. [4]
        Consequently, experienced hikers evaluate both terrain and weather before departure.
        """
    ).strip()
    h3_transcript = dedent(
        """
        Host: Today we will examine how urban wetlands function as ecological infrastructure.
        Host: Although they were once regarded as wasted land,
        contemporary planners increasingly
        recognize their role in moderating floods and filtering pollutants.
        Host: Researchers also note that wetlands preserve biodiversity
        by supporting insects, birds,
        and microorganisms that would otherwise disappear from dense cities.
        Guest: Even so, policymakers face the difficult task
        of reconciling short-term development
        pressure with long-term ecological resilience.
        Guest: That tension explains why restoration projects often require
        both scientific evidence
        and sustained public persuasion.
        """
    ).strip()

    samples = [
        (
            _build_unit(track=Track.M3, skill=Skill.READING),
            _build_reading_revision(
                track=Track.M3,
                type_tag="R_VOCAB",
                difficulty=1,
                body_text=m3_body,
                sentences=[
                    "Lena brought a spare umbrella to work because it might rain.",
                    (
                        "When her coworker forgot theirs, Lena offered the spare one "
                        "so they would not get wet."
                    ),
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
                body_text=h1_body,
                sentences=[
                        "Students often think feedback is useful only after they make a mistake.",
                        "However, feedback can also guide planning before a task begins.",
                        (
                            "When learners compare early ideas with later revisions, they "
                            "notice patterns in their thinking."
                        ),
                        (
                            "As a result, they become more deliberate about setting goals "
                            "before the next assignment starts."
                        ),
                        "That process builds stronger self-monitoring habits over time.",
                    ],
                ),
                _build_question(
                    type_tag="R_MAIN_IDEA",
                    difficulty=2,
                    stem="What does the passage suggest is the main purpose of feedback?",
                    choices=(
                        "Feedback supports planning and self-monitoring, not just correction.",
                        "Students should avoid making mistakes before asking for feedback.",
                    "Teachers should rewrite students' work for them.",
                    "Planning matters less than revision in most classes.",
                    "Self-monitoring develops only through testing.",
                ),
            ),
            {ContentCalibrationLevel.STANDARD, ContentCalibrationLevel.HARD},
        ),
        (
            _build_unit(track=Track.H2, skill=Skill.READING),
            _build_reading_revision(
                track=Track.H2,
                type_tag="R_INSERTION",
                difficulty=3,
                body_text=h2_body,
                sentences=[
                    (
                        "Many people are drawn to hiking as it offers a synergistic "
                        "blend of rigorous physical exertion and a profound opportunity "
                        "to reconnect with the natural world."
                    ),
                    (
                        "The difficulty of trails can vary substantially, ranging from "
                        "rudimentary forest paths to grueling mountain ascents that "
                        "demand significant stamina."
                    ),
                    (
                        "Hiking also serves as an exceptional vantage point for "
                        "observing diverse wildlife in their undisturbed habitats, "
                        "fostering environmental awareness."
                    ),
                    (
                        "Nonetheless, such benefits can only be fully realized when "
                        "preceded by meticulous preparation, including the carriage of "
                        "ample hydration and specialized gear."
                    ),
                    (
                        "Consequently, experienced hikers evaluate both terrain and "
                        "weather before departure."
                    ),
                ],
            ),
            _build_question(
                type_tag="R_INSERTION",
                difficulty=3,
                stem=(
                    "Where is the best place to insert the sentence about the "
                    "psychological resilience built through hiking?"
                ),
                choices=(
                    "Before sentence [1]",
                    "Between sentence [1] and [2]",
                    "Between sentence [2] and [3]",
                    "Between sentence [3] and [4]",
                    "After sentence [4]",
                ),
            ),
            {ContentCalibrationLevel.HARD, ContentCalibrationLevel.KILLER},
        ),
        (
            _build_unit(track=Track.H3, skill=Skill.LISTENING),
            _build_listening_revision(
                track=Track.H3,
                type_tag="L_LONG_TALK",
                difficulty=5,
                transcript_text=h3_transcript,
                turns=[
                    (
                        "Host",
                        (
                            "Today we will examine how urban wetlands function as "
                            "ecological infrastructure."
                        ),
                    ),
                    (
                        "Host",
                        (
                            "Although they were once regarded as wasted land, "
                            "contemporary planners increasingly recognize their role "
                            "in moderating floods and filtering pollutants."
                        ),
                    ),
                    (
                        "Host",
                        (
                            "Researchers also note that wetlands preserve biodiversity "
                            "by supporting insects, birds, and microorganisms that "
                            "would otherwise disappear from dense cities."
                        ),
                    ),
                    (
                        "Guest",
                        (
                            "Even so, policymakers face the difficult task of "
                            "reconciling short-term development pressure with "
                            "long-term ecological resilience."
                        ),
                    ),
                    (
                        "Guest",
                        (
                            "That tension explains why restoration projects often "
                            "require both scientific evidence and sustained public "
                            "persuasion."
                        ),
                    ),
                ],
                sentences=[
                    (
                        "Today we will examine how urban wetlands function as "
                        "ecological infrastructure."
                    ),
                    (
                        "Although they were once regarded as wasted land, "
                        "contemporary planners increasingly recognize their role in "
                        "moderating floods and filtering pollutants."
                    ),
                    (
                        "Researchers also note that wetlands preserve biodiversity by "
                        "supporting insects, birds, and microorganisms that would "
                        "otherwise disappear from dense cities."
                    ),
                    (
                        "Even so, policymakers face the difficult task of reconciling "
                        "short-term development pressure with long-term ecological "
                        "resilience."
                    ),
                    (
                        "That tension explains why restoration projects often require "
                        "both scientific evidence and sustained public persuasion."
                    ),
                ],
            ),
            _build_question(
                type_tag="L_LONG_TALK",
                difficulty=5,
                stem="What is the main point of the talk?",
                choices=(
                    (
                        "Urban wetlands should be protected because they provide "
                        "ecological and planning benefits."
                    ),
                    "Modern cities should replace wetlands with artificial lakes.",
                    "Flood control is less effective than rapid construction in cities.",
                    "Scientific evidence rarely affects environmental policy.",
                    "Public persuasion is unnecessary in restoration projects.",
                ),
            ),
            {ContentCalibrationLevel.HARD, ContentCalibrationLevel.KILLER},
        ),
    ]

    for unit, revision, question, expected_levels in samples:
        result = evaluate_content_calibration(unit=unit, revision=revision, questions=[question])
        assert result.passed is True
        assert result.calibrated_level in expected_levels


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
