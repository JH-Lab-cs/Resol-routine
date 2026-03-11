from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.policies import (
    VOCAB_READINESS_MIN_ROWS_BY_TRACK,
    VOCAB_READINESS_REQUIRED_SOURCE_TAGS,
)
from app.models.enums import Track
from app.models.vocab_catalog_entry import VocabCatalogEntry
from app.services.vocab_catalog_service import (
    VocabCatalogImportRow,
    load_frontend_compatibility_vocab_import_rows,
)

_TRACK_SEQUENCE = [Track.M3, Track.H1, Track.H2, Track.H3]
_TRACK_INDEX = {track.value: index for index, track in enumerate(_TRACK_SEQUENCE)}


@dataclass(frozen=True, slots=True)
class VocabReadinessRow:
    row_id: str
    source_tag: str | None
    target_min_track: str | None
    target_max_track: str | None
    difficulty_band: int | None
    frequency_tier: int | None


def build_vocab_readiness_report(
    db: Session,
    *,
    compatibility_rows: list[VocabReadinessRow] | None = None,
) -> dict[str, object]:
    catalog_rows = db.execute(
        select(VocabCatalogEntry)
        .where(VocabCatalogEntry.is_active.is_(True))
        .order_by(VocabCatalogEntry.lemma.asc(), VocabCatalogEntry.catalog_key.asc())
    ).scalars().all()

    if catalog_rows:
        rows = [
            VocabReadinessRow(
                row_id=str(entry.id),
                source_tag=entry.source_tag.value,
                target_min_track=entry.target_min_track.value,
                target_max_track=entry.target_max_track.value,
                difficulty_band=entry.difficulty_band,
                frequency_tier=entry.frequency_tier,
            )
            for entry in catalog_rows
        ]
        source_of_truth = "BACKEND_CATALOG"
    else:
        rows = compatibility_rows or [
            _seed_item_to_readiness_row(item)
            for item in load_frontend_compatibility_vocab_import_rows()
        ]
        source_of_truth = "FRONTEND_COMPATIBILITY_SEED"

    return _build_vocab_report(
        rows=rows,
        backend_catalog_present=bool(catalog_rows),
        source_of_truth=source_of_truth,
    )


def _seed_item_to_readiness_row(item: VocabCatalogImportRow) -> VocabReadinessRow:
    return VocabReadinessRow(
        row_id=item.source_row_id,
        source_tag=item.source_tag,
        target_min_track=item.target_min_track,
        target_max_track=item.target_max_track,
        difficulty_band=item.difficulty_band,
        frequency_tier=item.frequency_tier,
    )


def _build_vocab_report(
    *,
    rows: list[VocabReadinessRow],
    backend_catalog_present: bool,
    source_of_truth: str,
) -> dict[str, object]:
    missing_metadata_ids: list[str] = []
    track_counts: dict[str, int] = {track.value: 0 for track in Track}
    source_counts: dict[str, int] = defaultdict(int)
    difficulty_counts = {str(index): 0 for index in range(1, 6)}
    frequency_counts = {str(index): 0 for index in range(1, 6)}

    for row in rows:
        if not _vocab_row_has_required_metadata(row):
            missing_metadata_ids.append(row.row_id)
            continue

        assert row.source_tag is not None
        assert row.target_min_track is not None
        assert row.target_max_track is not None
        assert row.difficulty_band is not None
        source_counts[row.source_tag] += 1
        difficulty_counts[str(row.difficulty_band)] += 1
        if row.frequency_tier is not None:
            frequency_counts[str(row.frequency_tier)] += 1

        for track in Track:
            if _track_is_within_vocab_band(
                track=track.value,
                minimum=row.target_min_track,
                maximum=row.target_max_track,
            ):
                track_counts[track.value] += 1

    tracks: dict[str, object] = {}
    readiness_values: list[str] = []
    for track in Track:
        minimum_required = VOCAB_READINESS_MIN_ROWS_BY_TRACK[track.value]
        count = track_counts[track.value]
        if count >= minimum_required:
            track_readiness = "READY"
        elif count > 0:
            track_readiness = "WARNING"
        else:
            track_readiness = "NOT_READY"
        readiness_values.append(track_readiness)
        tracks[track.value] = {
            "eligibleCount": count,
            "minimumRequired": minimum_required,
            "readiness": track_readiness,
        }

    service_readiness = "READY"
    if missing_metadata_ids:
        service_readiness = "NOT_READY"
    elif any(value == "NOT_READY" for value in readiness_values):
        service_readiness = "NOT_READY"
    elif any(value == "WARNING" for value in readiness_values):
        service_readiness = "WARNING"

    return {
        "backendCatalogPresent": backend_catalog_present,
        "sourceOfTruth": source_of_truth,
        "serviceReadiness": service_readiness,
        "selectionRule": {
            "M3": "foundational / high-frequency academic",
            "H1": "lower-band CSAT / school core",
            "H2": "mid-band CSAT + carry-over review",
            "H3": "upper-band CSAT + spaced review of lower bands",
        },
        "tracks": tracks,
        "metadataCoverage": {
            "totalRows": len(rows),
            "rowsWithRequiredMetadata": len(rows) - len(missing_metadata_ids),
            "missingMetadataIds": missing_metadata_ids,
            "sourceTagCounts": dict(sorted(source_counts.items())),
            "difficultyBandCounts": difficulty_counts,
            "frequencyTierCounts": frequency_counts,
            "requiredSourceTags": list(VOCAB_READINESS_REQUIRED_SOURCE_TAGS),
        },
    }


def _track_is_within_vocab_band(*, track: str, minimum: str | None, maximum: str | None) -> bool:
    if minimum is None or maximum is None:
        return False
    try:
        track_index = _TRACK_INDEX[track]
        minimum_index = _TRACK_INDEX[minimum]
        maximum_index = _TRACK_INDEX[maximum]
    except KeyError:
        return False
    return minimum_index <= track_index <= maximum_index


def _vocab_row_has_required_metadata(row: VocabReadinessRow) -> bool:
    if row.source_tag not in VOCAB_READINESS_REQUIRED_SOURCE_TAGS:
        return False
    if row.target_min_track not in _TRACK_INDEX or row.target_max_track not in _TRACK_INDEX:
        return False
    if row.difficulty_band is None or not 1 <= row.difficulty_band <= 5:
        return False
    if row.frequency_tier is not None and not 1 <= row.frequency_tier <= 5:
        return False
    return _track_is_within_vocab_band(
        track=row.target_min_track,
        minimum=row.target_min_track,
        maximum=row.target_max_track,
    )
