from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import cast

_POLICY_PATH = (
    Path(__file__).resolve().parents[2]
    / "shared"
    / "generation"
    / "korean_exam_generation_policy_v1.json"
)
_REQUIRED_ROOT_KEYS = (
    "version",
    "families",
    "subtypes",
    "gradeStyles",
    "discourseModes",
    "bands",
    "rules",
    "mappings",
)
_REQUIRED_AXIS_KEYS = (
    "wordCount",
    "syntaxDepth",
    "abstractionLevel",
    "evidenceDistance",
    "referentAmbiguity",
    "distractorOverlap",
    "discourseDensity",
    "clueDirectness",
)
_REQUIRED_BAND_KEYS = ("wordCountBand", "sentenceCountBand", "wordsPerSentenceBand")
_REQUIRED_RANGE_KEYS = ("min", "target", "max")


@dataclass(frozen=True, slots=True)
class PolicyBand:
    minimum: int
    target: int
    maximum: int

    def to_dict(self) -> dict[str, int]:
        return {
            "min": self.minimum,
            "target": self.target,
            "max": self.maximum,
        }


@dataclass(frozen=True, slots=True)
class PolicyAxes:
    word_count: int
    syntax_depth: int
    abstraction_level: int
    evidence_distance: int
    referent_ambiguity: int
    distractor_overlap: int
    discourse_density: int
    clue_directness: int

    def to_dict(self) -> dict[str, int]:
        return {
            "wordCount": self.word_count,
            "syntaxDepth": self.syntax_depth,
            "abstractionLevel": self.abstraction_level,
            "evidenceDistance": self.evidence_distance,
            "referentAmbiguity": self.referent_ambiguity,
            "distractorOverlap": self.distractor_overlap,
            "discourseDensity": self.discourse_density,
            "clueDirectness": self.clue_directness,
        }


@dataclass(frozen=True, slots=True)
class KoreanExamGenerationPolicyLookup:
    version: str
    family: str
    grade_style: str
    subtype: str
    skill: str
    canonical_type_tag: str
    discourse_mode: str
    band_profile_key: str
    axis_profile_key: str
    word_count_band: PolicyBand
    sentence_count_band: PolicyBand
    words_per_sentence_band: PolicyBand
    axes: PolicyAxes
    notes: tuple[str, ...]

    def to_dict(self) -> dict[str, object]:
        return {
            "version": self.version,
            "family": self.family,
            "gradeStyle": self.grade_style,
            "subtype": self.subtype,
            "skill": self.skill,
            "canonicalTypeTag": self.canonical_type_tag,
            "discourseMode": self.discourse_mode,
            "bandProfileKey": self.band_profile_key,
            "axisProfileKey": self.axis_profile_key,
            "wordCountBand": self.word_count_band.to_dict(),
            "sentenceCountBand": self.sentence_count_band.to_dict(),
            "wordsPerSentenceBand": self.words_per_sentence_band.to_dict(),
            "axes": self.axes.to_dict(),
            "notes": list(self.notes),
        }


@lru_cache(maxsize=1)
def load_korean_exam_generation_policy() -> dict[str, object]:
    return _load_policy_from_path(_POLICY_PATH)


def resolve_korean_exam_generation_policy(
    *,
    grade_style: str,
    subtype: str,
    discourse_mode: str,
    family: str | None = None,
) -> KoreanExamGenerationPolicyLookup:
    policy = load_korean_exam_generation_policy()
    grade_key = _resolve_key(_keys_for(policy["gradeStyles"]), grade_style, "grade_style")
    subtype_key = _resolve_key(_keys_for(policy["subtypes"]), subtype, "subtype")
    discourse_key = _resolve_key(
        _keys_for(policy["discourseModes"]),
        discourse_mode,
        "discourse_mode",
    )
    mappings = _dict(policy["mappings"], "mappings")
    default_family_by_grade = _dict(
        mappings.get("defaultFamilyByGrade"),
        "defaultFamilyByGrade",
    )
    grade_styles = _dict(policy["gradeStyles"], "gradeStyles")
    if family is None:
        family = str(default_family_by_grade.get(grade_key, "")).strip()
        if not family:
            raise ValueError("generation_policy_default_family_missing")
    family_key = _resolve_key(_keys_for(policy["families"]), family, "family")

    family_entry = _dict(_dict(policy["families"], "families").get(family_key), "family_entry")
    supported_grades = _string_list(family_entry.get("supportedGrades"), "supportedGrades")
    if grade_key not in supported_grades:
        raise ValueError("generation_policy_family_grade_mismatch")

    subtype_entry = _dict(_dict(policy["subtypes"], "subtypes").get(subtype_key), "subtype_entry")
    allowed_modes = _string_list(
        subtype_entry.get("allowedDiscourseModes"),
        "allowedDiscourseModes",
    )
    if discourse_key not in allowed_modes:
        raise ValueError("generation_policy_discourse_mode_not_allowed")

    band_profile_key = _string(subtype_entry.get("bandProfileKey"), "bandProfileKey")
    axis_profile_key = _string(subtype_entry.get("axisProfileKey"), "axisProfileKey")
    band_profiles = _dict(_dict(policy["bands"], "bands").get("profiles"), "band_profiles")
    band_profile = _dict(band_profiles.get(band_profile_key), "band_profile")
    axis_profile = _dict(
        _dict(_dict(policy["rules"], "rules").get("axisProfiles"), "axis_profiles").get(
            axis_profile_key
        ),
        "axis_profile",
    )
    grade_bands = _dict(
        _dict(band_profile.get("gradeBands"), "gradeBands").get(grade_key),
        "grade_band",
    )
    grade_axes = _dict(
        _dict(axis_profile.get("gradeAxes"), "gradeAxes").get(grade_key),
        "grade_axes",
    )
    discourse_entry = _dict(
        _dict(policy["discourseModes"], "discourseModes").get(discourse_key),
        "discourse_entry",
    )

    word_count_band = _apply_band_adjustments(
        _load_band(grade_bands.get("wordCountBand"), "wordCountBand"),
        discourse_entry.get("bandAdjustments"),
        family_entry.get("bandAdjustments"),
        key="wordCountBand",
    )
    sentence_count_band = _apply_band_adjustments(
        _load_band(grade_bands.get("sentenceCountBand"), "sentenceCountBand"),
        discourse_entry.get("bandAdjustments"),
        family_entry.get("bandAdjustments"),
        key="sentenceCountBand",
    )
    words_per_sentence_band = _apply_band_adjustments(
        _load_band(grade_bands.get("wordsPerSentenceBand"), "wordsPerSentenceBand"),
        discourse_entry.get("bandAdjustments"),
        family_entry.get("bandAdjustments"),
        key="wordsPerSentenceBand",
    )
    axes = _apply_axis_adjustments(
        _load_axes(grade_axes),
        discourse_entry.get("axisAdjustments"),
        family_entry.get("axisOverrides"),
    )

    notes = (
        _string(
            _dict(grade_styles[grade_key], "grade_style_entry").get("description"),
            "grade_description",
        ),
        _string(subtype_entry.get("description"), "subtype_description"),
        _string(discourse_entry.get("description"), "discourse_description"),
        _string(family_entry.get("description"), "family_description"),
    )

    return KoreanExamGenerationPolicyLookup(
        version=_string(policy.get("version"), "version"),
        family=family_key,
        grade_style=grade_key,
        subtype=subtype_key,
        skill=_string(subtype_entry.get("skill"), "skill"),
        canonical_type_tag=_string(subtype_entry.get("canonicalTypeTag"), "canonical_type_tag"),
        discourse_mode=discourse_key,
        band_profile_key=band_profile_key,
        axis_profile_key=axis_profile_key,
        word_count_band=word_count_band,
        sentence_count_band=sentence_count_band,
        words_per_sentence_band=words_per_sentence_band,
        axes=axes,
        notes=notes,
    )


def _load_policy_from_path(path: Path) -> dict[str, object]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("generation_policy_invalid_root")
    for key in _REQUIRED_ROOT_KEYS:
        if key not in raw:
            raise ValueError(f"generation_policy_missing_root:{key}")

    families = _dict(raw.get("families"), "families")
    subtypes = _dict(raw.get("subtypes"), "subtypes")
    grade_styles = _dict(raw.get("gradeStyles"), "gradeStyles")
    discourse_modes = _dict(raw.get("discourseModes"), "discourseModes")
    bands = _dict(raw.get("bands"), "bands")
    rules = _dict(raw.get("rules"), "rules")
    mappings = _dict(raw.get("mappings"), "mappings")

    grade_keys = tuple(grade_styles.keys())
    _validate_root_mapping(mappings, grade_keys=grade_keys)
    _validate_families(families, grade_keys=grade_keys)
    _validate_discourse_modes(discourse_modes)
    _validate_band_profiles(
        _dict(bands.get("profiles"), "band_profiles"),
        grade_keys=grade_keys,
    )
    _validate_axis_profiles(
        _dict(rules.get("axisProfiles"), "axis_profiles"),
        grade_keys=grade_keys,
    )
    _validate_subtypes(
        subtypes,
        discourse_modes=discourse_modes,
        band_profiles=_dict(bands.get("profiles"), "band_profiles"),
        axis_profiles=_dict(rules.get("axisProfiles"), "axis_profiles"),
        mappings=mappings,
    )

    return cast(dict[str, object], raw)


def _validate_root_mapping(
    mappings: dict[str, object],
    *,
    grade_keys: tuple[str, ...],
) -> None:
    subtype_mapping = _dict(
        mappings.get("subtypeToCanonicalTypeTag"),
        "subtypeToCanonicalTypeTag",
    )
    if not subtype_mapping:
        raise ValueError("generation_policy_subtype_mapping_missing")
    default_family_by_grade = _dict(
        mappings.get("defaultFamilyByGrade"),
        "defaultFamilyByGrade",
    )
    for grade in grade_keys:
        if grade not in default_family_by_grade:
            raise ValueError(f"generation_policy_default_family_missing:{grade}")


def _validate_families(
    families: dict[str, object],
    *,
    grade_keys: tuple[str, ...],
) -> None:
    if not families:
        raise ValueError("generation_policy_families_missing")
    grade_key_set = set(grade_keys)
    for family_key, raw_family in families.items():
        family = _dict(raw_family, f"family:{family_key}")
        _string(family.get("description"), f"family_description:{family_key}")
        base_grade_style = _string(family.get("baseGradeStyle"), f"family_base_grade:{family_key}")
        if base_grade_style not in grade_key_set:
            raise ValueError(f"generation_policy_family_base_grade_invalid:{family_key}")
        supported_grades = _string_list(
            family.get("supportedGrades"),
            f"family_supported:{family_key}",
        )
        if not supported_grades:
            raise ValueError(f"generation_policy_family_supported_missing:{family_key}")
        for grade in supported_grades:
            if grade not in grade_key_set:
                raise ValueError(f"generation_policy_family_supported_invalid:{family_key}:{grade}")
        _validate_band_adjustments(
            _dict(family.get("bandAdjustments"), f"family_band_adjustments:{family_key}")
        )
        _validate_axis_adjustments(
            _dict(family.get("axisOverrides"), f"family_axis_overrides:{family_key}")
        )


def _validate_discourse_modes(discourse_modes: dict[str, object]) -> None:
    if not discourse_modes:
        raise ValueError("generation_policy_discourse_modes_missing")
    for mode_key, raw_mode in discourse_modes.items():
        mode = _dict(raw_mode, f"discourse_mode:{mode_key}")
        _string(mode.get("description"), f"discourse_description:{mode_key}")
        _validate_band_adjustments(
            _dict(mode.get("bandAdjustments"), f"discourse_band_adjustments:{mode_key}")
        )
        _validate_axis_adjustments(
            _dict(mode.get("axisAdjustments"), f"discourse_axis_adjustments:{mode_key}")
        )


def _validate_band_profiles(
    profiles: dict[str, object],
    *,
    grade_keys: tuple[str, ...],
) -> None:
    if not profiles:
        raise ValueError("generation_policy_band_profiles_missing")
    grade_key_set = set(grade_keys)
    for profile_key, raw_profile in profiles.items():
        profile = _dict(raw_profile, f"band_profile:{profile_key}")
        _string(profile.get("description"), f"band_profile_description:{profile_key}")
        grade_bands = _dict(profile.get("gradeBands"), f"band_profile_grade_bands:{profile_key}")
        if set(grade_bands.keys()) != grade_key_set:
            raise ValueError(f"generation_policy_band_profile_grade_coverage:{profile_key}")
        for grade_key in grade_keys:
            grade_band = _dict(grade_bands.get(grade_key), f"grade_band:{profile_key}:{grade_key}")
            for band_key in _REQUIRED_BAND_KEYS:
                _load_band(grade_band.get(band_key), f"{profile_key}:{grade_key}:{band_key}")


def _validate_axis_profiles(
    profiles: dict[str, object],
    *,
    grade_keys: tuple[str, ...],
) -> None:
    if not profiles:
        raise ValueError("generation_policy_axis_profiles_missing")
    grade_key_set = set(grade_keys)
    for profile_key, raw_profile in profiles.items():
        profile = _dict(raw_profile, f"axis_profile:{profile_key}")
        _string(profile.get("description"), f"axis_profile_description:{profile_key}")
        grade_axes = _dict(profile.get("gradeAxes"), f"axis_profile_grade_axes:{profile_key}")
        if set(grade_axes.keys()) != grade_key_set:
            raise ValueError(f"generation_policy_axis_profile_grade_coverage:{profile_key}")
        for grade_key in grade_keys:
            _load_axes(_dict(grade_axes.get(grade_key), f"axis_values:{profile_key}:{grade_key}"))


def _validate_subtypes(
    subtypes: dict[str, object],
    *,
    discourse_modes: dict[str, object],
    band_profiles: dict[str, object],
    axis_profiles: dict[str, object],
    mappings: dict[str, object],
) -> None:
    if not subtypes:
        raise ValueError("generation_policy_subtypes_missing")
    subtype_mapping = _dict(
        mappings.get("subtypeToCanonicalTypeTag"),
        "subtypeToCanonicalTypeTag",
    )
    discourse_mode_set = set(discourse_modes.keys())
    for subtype_key, raw_subtype in subtypes.items():
        subtype = _dict(raw_subtype, f"subtype:{subtype_key}")
        skill = _string(subtype.get("skill"), f"subtype_skill:{subtype_key}")
        if skill not in {"LISTENING", "READING"}:
            raise ValueError(f"generation_policy_subtype_skill_invalid:{subtype_key}")
        canonical_type_tag = _string(
            subtype.get("canonicalTypeTag"),
            f"subtype_canonical:{subtype_key}",
        )
        if subtype_mapping.get(subtype_key) != canonical_type_tag:
            raise ValueError(f"generation_policy_subtype_mapping_mismatch:{subtype_key}")
        band_profile_key = _string(
            subtype.get("bandProfileKey"),
            f"subtype_band_profile:{subtype_key}",
        )
        axis_profile_key = _string(
            subtype.get("axisProfileKey"),
            f"subtype_axis_profile:{subtype_key}",
        )
        if band_profile_key not in band_profiles:
            raise ValueError(f"generation_policy_subtype_band_profile_missing:{subtype_key}")
        if axis_profile_key not in axis_profiles:
            raise ValueError(f"generation_policy_subtype_axis_profile_missing:{subtype_key}")
        modes = _string_list(
            subtype.get("allowedDiscourseModes"),
            f"subtype_allowed_modes:{subtype_key}",
        )
        if not modes:
            raise ValueError(f"generation_policy_subtype_modes_missing:{subtype_key}")
        for mode in modes:
            if mode not in discourse_mode_set:
                raise ValueError(f"generation_policy_subtype_mode_invalid:{subtype_key}:{mode}")
        _string(subtype.get("description"), f"subtype_description:{subtype_key}")


def _validate_band_adjustments(adjustments: dict[str, object]) -> None:
    for band_key in _REQUIRED_BAND_KEYS:
        adjustment = _dict(adjustments.get(band_key), f"band_adjustment:{band_key}")
        _float(adjustment.get("multiplier"), f"{band_key}:multiplier")
        for key in ("minDelta", "targetDelta", "maxDelta"):
            _int(adjustment.get(key), f"{band_key}:{key}")


def _validate_axis_adjustments(adjustments: dict[str, object]) -> None:
    for axis_key in _REQUIRED_AXIS_KEYS:
        _int(adjustments.get(axis_key), f"axis_adjustment:{axis_key}")


def _apply_band_adjustments(
    base_band: PolicyBand,
    discourse_adjustments_raw: object,
    family_adjustments_raw: object,
    *,
    key: str,
) -> PolicyBand:
    band = base_band
    discourse_adjustments = _dict(discourse_adjustments_raw, "discourse_band_adjustments")
    family_adjustments = _dict(family_adjustments_raw, "family_band_adjustments")
    band = _apply_single_band_adjustment(
        band,
        _dict(discourse_adjustments.get(key), f"discourse_band_adjustment:{key}"),
    )
    band = _apply_single_band_adjustment(
        band,
        _dict(family_adjustments.get(key), f"family_band_adjustment:{key}"),
    )
    return band


def _apply_single_band_adjustment(band: PolicyBand, adjustment: dict[str, object]) -> PolicyBand:
    multiplier = _float(adjustment.get("multiplier"), "band_multiplier")
    minimum_delta = _int(adjustment.get("minDelta"), "minDelta")
    target_delta = _int(adjustment.get("targetDelta"), "targetDelta")
    maximum_delta = _int(adjustment.get("maxDelta"), "maxDelta")
    minimum = max(1, round(band.minimum * multiplier) + minimum_delta)
    target = max(minimum, round(band.target * multiplier) + target_delta)
    maximum = max(target, round(band.maximum * multiplier) + maximum_delta)
    return PolicyBand(minimum=minimum, target=target, maximum=maximum)


def _apply_axis_adjustments(
    base_axes: PolicyAxes,
    discourse_adjustments_raw: object,
    family_adjustments_raw: object,
) -> PolicyAxes:
    discourse_adjustments = _dict(discourse_adjustments_raw, "discourse_axis_adjustments")
    family_adjustments = _dict(family_adjustments_raw, "family_axis_adjustments")
    base_values = base_axes.to_dict()
    adjusted: dict[str, int] = {}
    for key in _REQUIRED_AXIS_KEYS:
        adjusted_value = (
            base_values[key]
            + _int(discourse_adjustments.get(key), f"discourse_axis:{key}")
            + _int(family_adjustments.get(key), f"family_axis:{key}")
        )
        adjusted[key] = max(1, min(5, adjusted_value))
    return _load_axes(adjusted)


def _load_band(raw_band: object, label: str) -> PolicyBand:
    band = _dict(raw_band, label)
    values = {key: _int(band.get(key), f"{label}:{key}") for key in _REQUIRED_RANGE_KEYS}
    if values["min"] < 1 or values["min"] > values["target"] or values["target"] > values["max"]:
        raise ValueError(f"generation_policy_band_invalid:{label}")
    return PolicyBand(
        minimum=values["min"],
        target=values["target"],
        maximum=values["max"],
    )


def _load_axes(raw_axes: object) -> PolicyAxes:
    axes = _dict(raw_axes, "axes")
    values = {key: _int(axes.get(key), f"axes:{key}") for key in _REQUIRED_AXIS_KEYS}
    for key, value in values.items():
        if value < 1 or value > 5:
            raise ValueError(f"generation_policy_axis_out_of_range:{key}")
    return PolicyAxes(
        word_count=values["wordCount"],
        syntax_depth=values["syntaxDepth"],
        abstraction_level=values["abstractionLevel"],
        evidence_distance=values["evidenceDistance"],
        referent_ambiguity=values["referentAmbiguity"],
        distractor_overlap=values["distractorOverlap"],
        discourse_density=values["discourseDensity"],
        clue_directness=values["clueDirectness"],
    )


def _dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValueError(f"generation_policy_expected_dict:{label}")
    return cast(dict[str, object], value)


def _string(value: object, label: str) -> str:
    text = str(value).strip()
    if not text:
        raise ValueError(f"generation_policy_expected_string:{label}")
    return text


def _string_list(value: object, label: str) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise ValueError(f"generation_policy_expected_list:{label}")
    normalized = tuple(str(item).strip() for item in value if str(item).strip())
    if len(normalized) != len(value):
        raise ValueError(f"generation_policy_list_contains_empty:{label}")
    return normalized


def _int(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"generation_policy_expected_int:{label}")
    return value


def _float(value: object, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"generation_policy_expected_float:{label}")
    return float(value)


def _resolve_key(keys: tuple[str, ...], requested: str, label: str) -> str:
    normalized = requested.strip()
    if not normalized:
        raise ValueError(f"generation_policy_empty_identifier:{label}")
    lowered = normalized.lower()
    for key in keys:
        if key.lower() == lowered:
            return key
    raise ValueError(f"generation_policy_unknown_identifier:{label}:{requested}")


def _keys_for(mapping: object) -> tuple[str, ...]:
    return tuple(_dict(mapping, "mapping").keys())
