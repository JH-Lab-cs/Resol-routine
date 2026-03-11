from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import Track
from app.models.vocab_catalog_entry import VocabCatalogEntry
from app.models.vocab_enums import VocabSourceTag

_STARTER_PACK_PATH = (
    Path(__file__).resolve().parents[3] / "assets" / "content_packs" / "starter_pack.json"
)
_BACKEND_CATALOG_SEED_PATH = (
    Path(__file__).resolve().parents[2] / "shared" / "seed" / "vocab_catalog_seed.json"
)
_TRACK_ORDER = {
    Track.M3.value: 0,
    Track.H1.value: 1,
    Track.H2.value: 2,
    Track.H3.value: 3,
}
_SEEDABLE_SOURCE_TAGS = {
    VocabSourceTag.CSAT.value,
    VocabSourceTag.SCHOOL_CORE.value,
    VocabSourceTag.USER_CUSTOM.value,
}


@dataclass(frozen=True, slots=True)
class VocabCatalogImportRow:
    source_row_id: str
    lemma: str
    pos: str
    meaning: str
    example: str
    ipa: str
    source_tag: str | None
    target_min_track: str | None
    target_max_track: str | None
    difficulty_band: int | None
    frequency_tier: int | None


def load_frontend_compatibility_vocab_import_rows(
    *,
    pack_path: Path | None = None,
) -> list[VocabCatalogImportRow]:
    resolved_path = pack_path or _STARTER_PACK_PATH
    return _load_vocab_import_rows_from_path(resolved_path)


def load_backend_catalog_seed_import_rows(
    *,
    pack_path: Path | None = None,
    backend_seed_path: Path | None = None,
) -> list[VocabCatalogImportRow]:
    frontend_rows = load_frontend_compatibility_vocab_import_rows(pack_path=pack_path)
    resolved_backend_seed_path = backend_seed_path or _BACKEND_CATALOG_SEED_PATH
    backend_rows = _load_vocab_import_rows_from_path(resolved_backend_seed_path)
    return [*frontend_rows, *backend_rows]


def load_seed_vocab_import_rows(*, pack_path: Path | None = None) -> list[VocabCatalogImportRow]:
    return load_frontend_compatibility_vocab_import_rows(pack_path=pack_path)


def _load_vocab_import_rows_from_path(resolved_path: Path) -> list[VocabCatalogImportRow]:
    payload = json.loads(resolved_path.read_text(encoding="utf-8"))
    rows = payload.get("vocabulary", [])
    if not isinstance(rows, list):
        return []

    items: list[VocabCatalogImportRow] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        items.append(
            VocabCatalogImportRow(
                source_row_id=str(row.get("id", "")),
                lemma=_as_optional_str(row.get("lemma")) or "",
                pos=_as_optional_str(row.get("pos")) or "",
                meaning=_as_optional_str(row.get("meaning")) or "",
                example=_as_optional_str(row.get("example")) or "",
                ipa=_as_optional_str(row.get("ipa")) or "",
                source_tag=_as_optional_str(row.get("sourceTag")),
                target_min_track=_as_optional_str(row.get("targetMinTrack")),
                target_max_track=_as_optional_str(row.get("targetMaxTrack")),
                difficulty_band=_as_optional_int(row.get("difficultyBand")),
                frequency_tier=_as_optional_int(row.get("frequencyTier")),
            )
        )
    return items


def build_vocab_catalog_key(*, lemma: str, pos: str, meaning: str) -> str:
    normalized = "\x1f".join(
        (
            _normalize_catalog_text(lemma),
            _normalize_catalog_text(pos),
            _normalize_catalog_text(meaning),
        )
    )
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def seed_vocab_catalog(
    db: Session,
    *,
    rows: list[VocabCatalogImportRow] | None = None,
    pack_path: Path | None = None,
    dry_run: bool = True,
) -> dict[str, object]:
    source_rows = rows or load_backend_catalog_seed_import_rows(pack_path=pack_path)
    existing_by_key = {
        entry.catalog_key: entry
        for entry in db.execute(select(VocabCatalogEntry)).scalars().all()
    }

    inserted = 0
    updated = 0
    skipped = 0
    invalid = 0
    result_rows: list[dict[str, object]] = []

    for row in source_rows:
        validation_error = _validate_import_row(row)
        if validation_error is not None:
            bucket = "skipped" if validation_error == "user_custom_excluded" else "invalid"
            if bucket == "skipped":
                skipped += 1
            else:
                invalid += 1
            result_rows.append(
                {
                    "sourceRowId": row.source_row_id,
                    "catalogKey": None,
                    "action": bucket,
                    "reason": validation_error,
                }
            )
            continue

        assert row.source_tag is not None
        assert row.target_min_track is not None
        assert row.target_max_track is not None
        assert row.difficulty_band is not None

        catalog_key = build_vocab_catalog_key(
            lemma=row.lemma,
            pos=row.pos,
            meaning=row.meaning,
        )
        payload = {
            "catalog_key": catalog_key,
            "lemma": row.lemma,
            "pos": row.pos,
            "meaning": row.meaning,
            "example": row.example,
            "ipa": row.ipa,
            "source_tag": VocabSourceTag(row.source_tag),
            "target_min_track": Track(row.target_min_track),
            "target_max_track": Track(row.target_max_track),
            "difficulty_band": row.difficulty_band,
            "frequency_tier": row.frequency_tier,
            "is_active": True,
            "source_metadata_json": {"seedRowId": row.source_row_id},
        }
        existing = existing_by_key.get(catalog_key)
        if existing is None:
            inserted += 1
            result_rows.append(
                {
                    "sourceRowId": row.source_row_id,
                    "catalogKey": catalog_key,
                    "action": "inserted",
                }
            )
            if not dry_run:
                db.add(VocabCatalogEntry(**payload))
            continue

        if _entry_matches_payload(existing, payload):
            skipped += 1
            result_rows.append(
                {
                    "sourceRowId": row.source_row_id,
                    "catalogKey": catalog_key,
                    "action": "skipped",
                    "reason": "unchanged",
                }
            )
            continue

        updated += 1
        result_rows.append(
            {
                "sourceRowId": row.source_row_id,
                "catalogKey": catalog_key,
                "action": "updated",
            }
        )
        if not dry_run:
            for key, value in payload.items():
                setattr(existing, key, value)

    return {
        "catalogSource": str(pack_path or _STARTER_PACK_PATH),
        "catalogSources": [
            str(pack_path or _STARTER_PACK_PATH),
            str(_BACKEND_CATALOG_SEED_PATH),
        ]
        if rows is None
        else ["explicit_rows"],
        "dryRun": dry_run,
        "sourceRowCount": len(source_rows),
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "invalid": invalid,
        "rows": result_rows,
    }


def _entry_matches_payload(entry: VocabCatalogEntry, payload: dict[str, Any]) -> bool:
    return bool(
        entry.catalog_key == payload["catalog_key"]
        and entry.lemma == payload["lemma"]
        and entry.pos == payload["pos"]
        and entry.meaning == payload["meaning"]
        and entry.example == payload["example"]
        and entry.ipa == payload["ipa"]
        and entry.source_tag == payload["source_tag"]
        and entry.target_min_track == payload["target_min_track"]
        and entry.target_max_track == payload["target_max_track"]
        and entry.difficulty_band == payload["difficulty_band"]
        and entry.frequency_tier == payload["frequency_tier"]
        and entry.is_active == payload["is_active"]
        and entry.source_metadata_json == payload["source_metadata_json"]
    )


def _validate_import_row(row: VocabCatalogImportRow) -> str | None:
    if row.source_tag == VocabSourceTag.USER_CUSTOM.value:
        return "user_custom_excluded"
    if row.source_tag not in _SEEDABLE_SOURCE_TAGS:
        return "invalid_source_tag"
    if not row.lemma or not row.pos or not row.meaning or not row.example or not row.ipa:
        return "missing_required_text"
    if row.target_min_track not in _TRACK_ORDER or row.target_max_track not in _TRACK_ORDER:
        return "invalid_track_band"
    if _TRACK_ORDER[row.target_min_track] > _TRACK_ORDER[row.target_max_track]:
        return "invalid_track_band_order"
    if row.difficulty_band is None or not 1 <= row.difficulty_band <= 5:
        return "invalid_difficulty_band"
    if row.frequency_tier is not None and not 1 <= row.frequency_tier <= 5:
        return "invalid_frequency_tier"
    return None


def _normalize_catalog_text(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _as_optional_int(value: object) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if not isinstance(value, (int, float, str)):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _as_optional_str(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None
