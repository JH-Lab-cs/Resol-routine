from app.core.content_type_taxonomy import (
    CANONICAL_LISTENING_TYPE_TAGS,
    CANONICAL_READING_TYPE_TAGS,
    CONTRACT_ENTRIES,
    CONTRACT_PATH,
    LEGACY_ALIAS_TO_CANONICAL_TYPE_TAG,
    is_canonical_type_tag_for_skill,
    normalize_type_tag_alias_or_canonical,
)
from app.core.policies import AI_CONTENT_TYPE_TAGS_LISTENING, AI_CONTENT_TYPE_TAGS_READING
from app.models.enums import ContentTypeTag


def test_canonical_content_type_tags_are_frozen_and_consistent() -> None:
    enum_listening = {
        tag.value
        for tag in ContentTypeTag
        if tag.value.startswith("L_")
    }
    enum_reading = {
        tag.value
        for tag in ContentTypeTag
        if tag.value.startswith("R_")
    }

    assert enum_listening == set(AI_CONTENT_TYPE_TAGS_LISTENING)
    assert enum_reading == set(AI_CONTENT_TYPE_TAGS_READING)


def test_contract_file_exists_and_matches_runtime_taxonomy() -> None:
    assert CONTRACT_PATH.exists()

    listening_entries = [entry for entry in CONTRACT_ENTRIES if entry.skill == "LISTENING"]
    reading_entries = [entry for entry in CONTRACT_ENTRIES if entry.skill == "READING"]

    assert tuple(entry.canonical_type_tag for entry in listening_entries) == CANONICAL_LISTENING_TYPE_TAGS
    assert tuple(entry.canonical_type_tag for entry in reading_entries) == CANONICAL_READING_TYPE_TAGS
    assert LEGACY_ALIAS_TO_CANONICAL_TYPE_TAG == {
        alias: entry.canonical_type_tag
        for entry in CONTRACT_ENTRIES
        for alias in entry.legacy_aliases
    }


def test_legacy_aliases_normalize_to_canonical_tags() -> None:
    assert normalize_type_tag_alias_or_canonical(type_tag="L1") == "L_GIST"
    assert normalize_type_tag_alias_or_canonical(type_tag="L2") == "L_DETAIL"
    assert normalize_type_tag_alias_or_canonical(type_tag="L3") == "L_INTENT"
    assert normalize_type_tag_alias_or_canonical(type_tag="R1") == "R_MAIN_IDEA"
    assert normalize_type_tag_alias_or_canonical(type_tag="R2") == "R_DETAIL"
    assert normalize_type_tag_alias_or_canonical(type_tag="R3") == "R_INFERENCE"
    assert normalize_type_tag_alias_or_canonical(type_tag="R_SUMMARY") == "R_SUMMARY"


def test_canonical_skill_and_type_tag_compatibility() -> None:
    assert is_canonical_type_tag_for_skill(skill="LISTENING", type_tag="L_GIST")
    assert is_canonical_type_tag_for_skill(skill="READING", type_tag="R_MAIN_IDEA")
    assert not is_canonical_type_tag_for_skill(skill="LISTENING", type_tag="R_MAIN_IDEA")
    assert not is_canonical_type_tag_for_skill(skill="READING", type_tag="L_GIST")
