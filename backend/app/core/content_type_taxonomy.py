from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


@dataclass(frozen=True, slots=True)
class ContentTypeTagContractEntry:
    skill: str
    canonical_type_tag: str
    legacy_aliases: tuple[str, ...]
    description: str


CONTRACT_PATH = (
    Path(__file__).resolve().parents[2]
    / "shared"
    / "contracts"
    / "content_type_tags.json"
)
_VALID_SKILLS = frozenset({"LISTENING", "READING"})


@lru_cache(maxsize=1)
def _load_contract_entries() -> tuple[ContentTypeTagContractEntry, ...]:
    raw = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("content_type_tags_contract_invalid_root")

    entries_raw = raw.get("entries")
    if not isinstance(entries_raw, list) or not entries_raw:
        raise ValueError("content_type_tags_contract_entries_missing")

    entries: list[ContentTypeTagContractEntry] = []
    seen_canonical: set[str] = set()
    seen_legacy_aliases: set[str] = set()

    for index, entry_raw in enumerate(entries_raw):
        if not isinstance(entry_raw, dict):
            raise ValueError(f"content_type_tags_contract_entry_invalid_{index}")

        skill = str(entry_raw.get("skill", "")).strip().upper()
        canonical = str(entry_raw.get("canonicalTypeTag", "")).strip().upper()
        description = str(entry_raw.get("description", "")).strip()
        aliases_raw = entry_raw.get("legacyAliases", [])

        if skill not in _VALID_SKILLS:
            raise ValueError(f"content_type_tags_contract_skill_invalid_{index}")
        if not canonical:
            raise ValueError(f"content_type_tags_contract_canonical_missing_{index}")
        if canonical in seen_canonical:
            raise ValueError(f"content_type_tags_contract_canonical_duplicated_{canonical}")
        seen_canonical.add(canonical)
        if not description:
            raise ValueError(f"content_type_tags_contract_description_missing_{canonical}")
        if not isinstance(aliases_raw, list):
            raise ValueError(f"content_type_tags_contract_aliases_invalid_{canonical}")

        aliases: list[str] = []
        for alias_raw in aliases_raw:
            alias = str(alias_raw).strip().upper()
            if not alias:
                raise ValueError(f"content_type_tags_contract_alias_empty_{canonical}")
            if alias in seen_legacy_aliases:
                raise ValueError(f"content_type_tags_contract_alias_duplicated_{alias}")
            seen_legacy_aliases.add(alias)
            aliases.append(alias)

        entries.append(
            ContentTypeTagContractEntry(
                skill=skill,
                canonical_type_tag=canonical,
                legacy_aliases=tuple(aliases),
                description=description,
            )
        )

    return tuple(entries)


CONTRACT_ENTRIES = _load_contract_entries()
CANONICAL_LISTENING_TYPE_TAGS = tuple(
    entry.canonical_type_tag for entry in CONTRACT_ENTRIES if entry.skill == "LISTENING"
)
CANONICAL_READING_TYPE_TAGS = tuple(
    entry.canonical_type_tag for entry in CONTRACT_ENTRIES if entry.skill == "READING"
)
CANONICAL_TYPE_TAGS = tuple(entry.canonical_type_tag for entry in CONTRACT_ENTRIES)

LEGACY_ALIAS_TO_CANONICAL_TYPE_TAG = {
    alias: entry.canonical_type_tag
    for entry in CONTRACT_ENTRIES
    for alias in entry.legacy_aliases
}


def canonical_type_tags_for_skill(skill: str) -> tuple[str, ...]:
    normalized_skill = skill.strip().upper()
    if normalized_skill == "LISTENING":
        return CANONICAL_LISTENING_TYPE_TAGS
    if normalized_skill == "READING":
        return CANONICAL_READING_TYPE_TAGS
    raise ValueError("invalid_skill")


def is_canonical_type_tag_for_skill(*, skill: str, type_tag: str) -> bool:
    normalized_type_tag = type_tag.strip().upper()
    return normalized_type_tag in canonical_type_tags_for_skill(skill)


def normalize_type_tag_alias_or_canonical(*, type_tag: str) -> str:
    normalized = type_tag.strip().upper()
    return LEGACY_ALIAS_TO_CANONICAL_TYPE_TAG.get(normalized, normalized)
