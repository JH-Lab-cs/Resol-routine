from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.generation_policy_service import (
    _load_policy_from_path,
    load_korean_exam_generation_policy,
    resolve_korean_exam_generation_policy,
)


def test_policy_file_integrity_and_coverage() -> None:
    policy = load_korean_exam_generation_policy()

    assert policy["version"] == "korean-exam-policy-v1"
    assert len(policy["subtypes"]) == 34
    assert set(policy["families"].keys()) == {
        "official_high1",
        "official_high2",
        "official_high3",
        "official_high3_hard",
        "indepth_high3",
        "middle3_official",
        "middle3_bridge",
    }
    assert set(policy["mappings"]["defaultFamilyByGrade"].keys()) == {
        "middle1",
        "middle2",
        "middle3_official",
        "middle3_bridge",
        "H1",
        "H2",
        "H3",
    }

    grade_keys = set(policy["gradeStyles"].keys())
    for subtype, raw_subtype in policy["subtypes"].items():
        band_profile_key = raw_subtype["bandProfileKey"]
        axis_profile_key = raw_subtype["axisProfileKey"]
        assert raw_subtype["canonicalTypeTag"] == (
            policy["mappings"]["subtypeToCanonicalTypeTag"][subtype]
        )
        assert set(
            policy["bands"]["profiles"][band_profile_key]["gradeBands"].keys()
        ) == grade_keys
        assert set(
            policy["rules"]["axisProfiles"][axis_profile_key]["gradeAxes"].keys()
        ) == grade_keys


def test_lookup_returns_expected_h2_insertion_band_and_axes() -> None:
    result = resolve_korean_exam_generation_policy(
        grade_style="H2",
        subtype="R_INSERTION",
        discourse_mode="expository",
    )

    assert result.family == "official_high2"
    assert result.skill == "READING"
    assert result.canonical_type_tag == "R_INSERTION"
    assert result.band_profile_key == "r_order_insertion_q36_39"
    assert result.word_count_band.to_dict() == {"min": 141, "target": 164, "max": 186}
    assert result.sentence_count_band.to_dict() == {"min": 5, "target": 6, "max": 7}
    assert result.axes.to_dict() == {
        "wordCount": 3,
        "syntaxDepth": 5,
        "abstractionLevel": 5,
        "evidenceDistance": 5,
        "referentAmbiguity": 4,
        "distractorOverlap": 5,
        "discourseDensity": 5,
        "clueDirectness": 5,
    }


def test_lookup_returns_expected_h3_long_narrative_and_middle3_bridge_blank() -> None:
    h3_result = resolve_korean_exam_generation_policy(
        grade_style="H3",
        subtype="R_LONG_PASSAGE_NARRATIVE",
        discourse_mode="narrative",
    )
    bridge_result = resolve_korean_exam_generation_policy(
        grade_style="middle3_bridge",
        subtype="R_BLANK",
        discourse_mode="expository",
    )

    assert h3_result.family == "official_high3"
    assert h3_result.band_profile_key == "r_long_narrative_q43_45"
    assert h3_result.word_count_band.to_dict() == {"min": 356, "target": 383, "max": 410}
    assert h3_result.canonical_type_tag == "R_INFERENCE"
    assert bridge_result.family == "middle3_bridge"
    assert bridge_result.word_count_band.to_dict() == {"min": 113, "target": 136, "max": 160}
    assert bridge_result.axes.to_dict() == {
        "wordCount": 2,
        "syntaxDepth": 3,
        "abstractionLevel": 4,
        "evidenceDistance": 3,
        "referentAmbiguity": 3,
        "distractorOverlap": 4,
        "discourseDensity": 5,
        "clueDirectness": 3,
    }


def test_h3_family_modes_apply_distinct_overrides() -> None:
    official = resolve_korean_exam_generation_policy(
        grade_style="H3",
        subtype="R_SUMMARY",
        discourse_mode="academic_argument",
        family="official_high3",
    )
    official_hard = resolve_korean_exam_generation_policy(
        grade_style="H3",
        subtype="R_SUMMARY",
        discourse_mode="academic_argument",
        family="official_high3_hard",
    )
    indepth = resolve_korean_exam_generation_policy(
        grade_style="H3",
        subtype="R_SUMMARY",
        discourse_mode="academic_argument",
        family="indepth_high3",
    )

    assert official_hard.word_count_band.target > official.word_count_band.target
    assert official_hard.words_per_sentence_band.target > official.words_per_sentence_band.target
    assert official_hard.axes.clue_directness >= official.axes.clue_directness
    assert indepth.word_count_band.target < official.word_count_band.target
    assert indepth.words_per_sentence_band.target > official.words_per_sentence_band.target
    assert indepth.axes.abstraction_level >= official.axes.abstraction_level


def test_invalid_policy_json_fails_validation(tmp_path: Path) -> None:
    invalid_path = tmp_path / "invalid_policy.json"
    invalid_path.write_text(
        json.dumps(
            {
                "version": "korean-exam-policy-v1",
                "families": {},
                "subtypes": {},
                "gradeStyles": {},
                "discourseModes": {},
                "bands": {},
                "rules": {},
                "mappings": {},
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="generation_policy_"):
        _load_policy_from_path(invalid_path)


def test_anchor_sanity_shows_step_up_for_long_passage_and_harder_axes_for_blank_and_order() -> None:
    h1_long = resolve_korean_exam_generation_policy(
        grade_style="H1",
        subtype="R_LONG_PASSAGE_NARRATIVE",
        discourse_mode="narrative",
    )
    h2_long = resolve_korean_exam_generation_policy(
        grade_style="H2",
        subtype="R_LONG_PASSAGE_NARRATIVE",
        discourse_mode="narrative",
    )
    h3_long = resolve_korean_exam_generation_policy(
        grade_style="H3",
        subtype="R_LONG_PASSAGE_NARRATIVE",
        discourse_mode="narrative",
    )
    h1_blank = resolve_korean_exam_generation_policy(
        grade_style="H1",
        subtype="R_BLANK",
        discourse_mode="expository",
    )
    h2_blank = resolve_korean_exam_generation_policy(
        grade_style="H2",
        subtype="R_BLANK",
        discourse_mode="expository",
    )
    h1_order = resolve_korean_exam_generation_policy(
        grade_style="H1",
        subtype="R_ORDER",
        discourse_mode="expository",
    )
    h2_order = resolve_korean_exam_generation_policy(
        grade_style="H2",
        subtype="R_ORDER",
        discourse_mode="expository",
    )

    assert (
        h1_long.word_count_band.target
        < h2_long.word_count_band.target
        < h3_long.word_count_band.target
    )
    assert h2_blank.word_count_band.target <= h1_blank.word_count_band.target + 10
    assert h2_blank.axes.abstraction_level > h1_blank.axes.abstraction_level
    assert h2_blank.axes.clue_directness > h1_blank.axes.clue_directness
    assert h2_order.word_count_band.target <= h1_order.word_count_band.target + 10
    assert h2_order.axes.abstraction_level > h1_order.axes.abstraction_level
    assert h2_order.axes.clue_directness > h1_order.axes.clue_directness
