from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import (
    canonical_type_tags_for_skill,
    is_canonical_type_tag_for_skill,
    normalize_type_tag_alias_or_canonical,
)
from app.core.policies import (
    CONTENT_READINESS_POLICY_VERSION,
    DAILY_READINESS_DIFFICULTY_RANGE_BY_TRACK,
    DAILY_READINESS_LISTENING_TYPE_DIVERSITY_MIN,
    DAILY_READINESS_MIN_PER_SKILL,
    DAILY_READINESS_READING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK,
    MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_WEEKLY_LISTENING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_WEEKLY_READING_TYPE_DIVERSITY_MIN,
    MOCK_EXAM_MONTHLY_LISTENING_COUNT,
    MOCK_EXAM_MONTHLY_READING_COUNT,
    MOCK_EXAM_WEEKLY_LISTENING_COUNT,
    MOCK_EXAM_WEEKLY_READING_COUNT,
    VOCAB_READINESS_MIN_ROWS_BY_TRACK,
    VOCAB_READINESS_REQUIRED_SOURCE_TAGS,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import AIGenerationJobStatus, MockExamType, Skill, Track
from app.schemas.mock_assembly import MockAssemblyJobCreateRequest
from app.services.mock_assembly_service import create_mock_assembly_job

DAILY_MIN_LISTENING_COUNT = 3
DAILY_MIN_READING_COUNT = 3
_CONTENT_PACK_PATH = (
    Path(__file__).resolve().parents[3] / "assets" / "content_packs" / "starter_pack.json"
)
_TRACK_SEQUENCE = [Track.M3, Track.H1, Track.H2, Track.H3]
_TRACK_INDEX = {track.value: index for index, track in enumerate(_TRACK_SEQUENCE)}


@dataclass(frozen=True, slots=True)
class PublishedContentInventoryItem:
    track: Track
    skill: Skill
    unit_id: UUID
    revision_id: UUID
    question_id: UUID
    type_tag: str
    difficulty: int


@dataclass(frozen=True, slots=True)
class VocabularySeedItem:
    vocab_id: str
    source_tag: str | None
    target_min_track: str | None
    target_max_track: str | None
    difficulty_band: int | None
    frequency_tier: int | None


def build_content_readiness_report(db: Session) -> dict[str, object]:
    inventory = load_published_inventory(db)
    vocab_rows = load_seed_vocabulary_rows()
    return {
        "policyVersion": CONTENT_READINESS_POLICY_VERSION,
        "generatedAt": _utc_now_iso(),
        "daily": build_daily_readiness_report(inventory),
        "mock": build_mock_readiness_report(db, inventory=inventory),
        "vocab": build_vocab_readiness_report(vocab_rows=vocab_rows),
    }


def build_b34_content_sync_gate(
    readiness_report: dict[str, object],
    *,
    backfill_plan: dict[str, object] | None = None,
) -> dict[str, object]:
    daily_section = _require_object_mapping(readiness_report["daily"])
    mock_section = _require_object_mapping(readiness_report["mock"])
    daily_tracks = _require_object_mapping(daily_section["tracks"])
    mock_tracks = _require_object_mapping(mock_section["tracks"])
    vocab_report = _require_object_mapping(readiness_report["vocab"])

    planned_daily_tracks = _planned_deficit_tracks(
        backfill_plan=backfill_plan,
        reasons={"DAILY_READINESS_DEFICIT"},
    )
    planned_mock_tracks = _planned_deficit_tracks(
        backfill_plan=backfill_plan,
        reasons={"WEEKLY_READINESS_DEFICIT", "MONTHLY_READINESS_DEFICIT"},
    )

    daily_all_at_least_warning = all(
        _readiness_value(daily_tracks, track.value) in {"WARNING", "READY"} for track in Track
    )
    daily_h2_h3_ready = all(
        _readiness_value(daily_tracks, track) == "READY" for track in ("H2", "H3")
    )
    daily_m3_h1_planned = {"M3", "H1"}.issubset(planned_daily_tracks)

    mock_h2_weekly_ready = _nested_readiness_value(mock_tracks, "H2", "weekly") == "READY"
    mock_h3_weekly_ready = _nested_readiness_value(mock_tracks, "H3", "weekly") == "READY"
    mock_h3_monthly_ready = _nested_readiness_value(mock_tracks, "H3", "monthly") == "READY"
    mock_m3_h1_planned = {"M3", "H1"}.issubset(planned_mock_tracks)

    vocab_tracks = _require_object_mapping(vocab_report["tracks"])
    vocab_non_empty_pool = all(_eligible_count(vocab_tracks, track.value) > 0 for track in Track)
    metadata_coverage = _require_object_mapping(vocab_report["metadataCoverage"])
    vocab_metadata_present = (
        _as_positive_int(metadata_coverage["rowsWithRequiredMetadata"]) > 0
        and not _as_object_list(metadata_coverage["missingMetadataIds"])
    )

    blockers: list[str] = []
    warnings: list[str] = []
    if not daily_all_at_least_warning:
        blockers.append("daily_all_tracks_must_be_warning_or_ready")
    if not daily_h2_h3_ready:
        warnings.append("daily_h2_h3_not_fully_ready")
    if not daily_m3_h1_planned:
        blockers.append("daily_m3_h1_deficit_plan_required")
    if not mock_h2_weekly_ready:
        blockers.append("mock_h2_weekly_must_be_ready")
    if not mock_h3_weekly_ready:
        blockers.append("mock_h3_weekly_must_be_ready")
    if not mock_h3_monthly_ready:
        blockers.append("mock_h3_monthly_must_be_ready")
    if not mock_m3_h1_planned:
        blockers.append("mock_m3_h1_deficit_plan_required")
    if not vocab_non_empty_pool:
        blockers.append("vocab_each_track_band_requires_non_empty_pool")
    if not vocab_metadata_present:
        blockers.append("vocab_metadata_required")
    if vocab_report["backendCatalogPresent"] is False:
        warnings.append("vocab_backend_catalog_not_implemented")

    return {
        "status": "READY" if not blockers else "NOT_READY",
        "eligibleForB34ContentSync": not blockers,
        "blockers": blockers,
        "warnings": warnings,
        "requirements": {
            "daily": {
                "allTracksAtLeastWarning": daily_all_at_least_warning,
                "h2AndH3Ready": daily_h2_h3_ready,
                "m3AndH1Planned": daily_m3_h1_planned,
                "plannedTracks": sorted(planned_daily_tracks),
            },
            "mock": {
                "h2WeeklyReady": mock_h2_weekly_ready,
                "h3WeeklyReady": mock_h3_weekly_ready,
                "h3MonthlyReady": mock_h3_monthly_ready,
                "m3AndH1Planned": mock_m3_h1_planned,
                "plannedTracks": sorted(planned_mock_tracks),
            },
            "vocab": {
                "metadataPresent": vocab_metadata_present,
                "nonEmptyPoolPerTrack": vocab_non_empty_pool,
                "backendCatalogPresent": vocab_report["backendCatalogPresent"],
            },
        },
    }


def load_published_inventory(db: Session) -> list[PublishedContentInventoryItem]:
    rows = db.execute(
        select(ContentUnit, ContentUnitRevision, ContentQuestion)
        .join(ContentUnitRevision, ContentUnitRevision.id == ContentUnit.published_revision_id)
        .join(ContentQuestion, ContentQuestion.content_unit_revision_id == ContentUnitRevision.id)
        .where(
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id.is_not(None),
        )
        .order_by(
            ContentUnit.track.asc(),
            ContentUnit.skill.asc(),
            ContentUnit.external_id.asc(),
            ContentQuestion.order_index.asc(),
            ContentQuestion.id.asc(),
        )
    ).all()

    inventory: list[PublishedContentInventoryItem] = []
    for unit, revision, question in rows:
        metadata = question.metadata_json if isinstance(question.metadata_json, dict) else {}
        raw_type_tag = metadata.get("typeTag")
        raw_difficulty = metadata.get("difficulty")
        if not isinstance(raw_type_tag, str):
            continue
        if not isinstance(raw_difficulty, (int, float, str)) or isinstance(raw_difficulty, bool):
            continue

        normalized_type_tag = normalize_type_tag_alias_or_canonical(type_tag=raw_type_tag)
        if not is_canonical_type_tag_for_skill(
            skill=unit.skill.value,
            type_tag=normalized_type_tag,
        ):
            continue

        try:
            difficulty = int(raw_difficulty)
        except (TypeError, ValueError):
            continue
        if difficulty < 1 or difficulty > 5:
            continue

        inventory.append(
            PublishedContentInventoryItem(
                track=unit.track,
                skill=unit.skill,
                unit_id=unit.id,
                revision_id=revision.id,
                question_id=question.id,
                type_tag=normalized_type_tag,
                difficulty=difficulty,
            )
        )

    return inventory


def load_seed_vocabulary_rows(*, pack_path: Path | None = None) -> list[VocabularySeedItem]:
    resolved_path = pack_path or _CONTENT_PACK_PATH
    payload = json.loads(resolved_path.read_text(encoding="utf-8"))
    rows = payload.get("vocabulary", [])
    if not isinstance(rows, list):
        return []

    items: list[VocabularySeedItem] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        items.append(
            VocabularySeedItem(
                vocab_id=str(row.get("id", "")),
                source_tag=_as_optional_str(row.get("sourceTag")),
                target_min_track=_as_optional_str(row.get("targetMinTrack")),
                target_max_track=_as_optional_str(row.get("targetMaxTrack")),
                difficulty_band=_as_optional_int(row.get("difficultyBand")),
                frequency_tier=_as_optional_int(row.get("frequencyTier")),
            )
        )
    return items


def build_daily_readiness_report(
    inventory: list[PublishedContentInventoryItem],
) -> dict[str, object]:
    tracks: dict[str, object] = {}
    for track in Track:
        track_items = [item for item in inventory if item.track == track]
        per_skill: dict[str, object] = {}
        daily_possible = True
        warning_reasons: list[str] = []
        expected_min, expected_max = DAILY_READINESS_DIFFICULTY_RANGE_BY_TRACK[track.value]
        average_min, average_max = MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value]

        for skill in Skill:
            skill_items = [item for item in track_items if item.skill == skill]
            type_counts: dict[str, int] = {}
            difficulty_counts = {str(index): 0 for index in range(1, 6)}
            in_band_count = 0
            for item in skill_items:
                type_counts[item.type_tag] = type_counts.get(item.type_tag, 0) + 1
                difficulty_counts[str(item.difficulty)] += 1
                if expected_min <= item.difficulty <= expected_max:
                    in_band_count += 1

            missing_type_tags = [
                type_tag
                for type_tag in canonical_type_tags_for_skill(skill.value)
                if type_counts.get(type_tag, 0) == 0
            ]
            missing_difficulty_buckets = [
                bucket for bucket, count in difficulty_counts.items() if count == 0
            ]
            average_difficulty = _average_difficulty(skill_items)

            per_skill[skill.value] = {
                "total": len(skill_items),
                "averageDifficulty": average_difficulty,
                "expectedDifficultyBand": {
                    "min": expected_min,
                    "max": expected_max,
                },
                "targetAverageRange": {
                    "min": average_min,
                    "max": average_max,
                },
                "inBandCount": in_band_count,
                "byTypeTag": dict(sorted(type_counts.items())),
                "byDifficulty": difficulty_counts,
                "missingTypeTags": missing_type_tags,
                "missingDifficultyBuckets": missing_difficulty_buckets,
            }

            minimum_count = (
                DAILY_MIN_LISTENING_COUNT if skill == Skill.LISTENING else DAILY_MIN_READING_COUNT
            )
            diversity_floor = (
                DAILY_READINESS_LISTENING_TYPE_DIVERSITY_MIN
                if skill == Skill.LISTENING
                else DAILY_READINESS_READING_TYPE_DIVERSITY_MIN
            )
            if len(skill_items) < minimum_count:
                daily_possible = False
            if len(skill_items) < DAILY_READINESS_MIN_PER_SKILL:
                warning_reasons.append(f"{skill.value.lower()}_count_below_service_threshold")
            if len(type_counts) < diversity_floor:
                warning_reasons.append(f"{skill.value.lower()}_type_diversity_below_service_threshold")
            if (
                average_difficulty is not None
                and not (average_min <= average_difficulty <= average_max)
            ):
                warning_reasons.append(f"{skill.value.lower()}_difficulty_band_misaligned")

        readiness = "READY"
        if not daily_possible:
            readiness = "NOT_READY"
        elif warning_reasons:
            readiness = "WARNING"

        tracks[track.value] = {
            "matrix": per_skill,
            "dailyPossible": daily_possible,
            "recommendedMinimumThreshold": {
                "listening": DAILY_READINESS_MIN_PER_SKILL,
                "reading": DAILY_READINESS_MIN_PER_SKILL,
                "listeningTypeDiversity": DAILY_READINESS_LISTENING_TYPE_DIVERSITY_MIN,
                "readingTypeDiversity": DAILY_READINESS_READING_TYPE_DIVERSITY_MIN,
            },
            "readiness": readiness,
            "warningReasons": sorted(set(warning_reasons)),
        }

    return {"tracks": tracks}


def build_mock_readiness_report(
    db: Session,
    *,
    inventory: list[PublishedContentInventoryItem],
) -> dict[str, object]:
    tracks: dict[str, object] = {}
    for track in Track:
        track_items = [item for item in inventory if item.track == track]
        listening_items = [item for item in track_items if item.skill == Skill.LISTENING]
        reading_items = [item for item in track_items if item.skill == Skill.READING]

        tracks[track.value] = {
            "inventory": {
                "LISTENING": _skill_bucket_counts(listening_items),
                "READING": _skill_bucket_counts(reading_items),
            },
            "weekly": _run_mock_readiness_check(
                db,
                track=track,
                exam_type=MockExamType.WEEKLY,
                period_key="2026W15",
            ),
            "monthly": _run_mock_readiness_check(
                db,
                track=track,
                exam_type=MockExamType.MONTHLY,
                period_key="202603",
            ),
        }

    return {"tracks": tracks}


def build_vocab_readiness_report(
    *,
    vocab_rows: list[VocabularySeedItem] | None = None,
) -> dict[str, object]:
    rows = vocab_rows or load_seed_vocabulary_rows()
    missing_metadata_ids: list[str] = []
    track_counts: dict[str, int] = {track.value: 0 for track in Track}
    source_counts: dict[str, int] = defaultdict(int)
    difficulty_counts: dict[str, int] = {str(index): 0 for index in range(1, 6)}

    for row in rows:
        if not _vocab_row_has_required_metadata(row):
            missing_metadata_ids.append(row.vocab_id)
            continue

        assert row.source_tag is not None
        assert row.difficulty_band is not None
        source_counts[row.source_tag] += 1
        difficulty_counts[str(row.difficulty_band)] += 1

        for track in Track:
            if _track_is_within_vocab_band(
                track=track.value,
                minimum=row.target_min_track,
                maximum=row.target_max_track,
            ):
                track_counts[track.value] += 1

    tracks: dict[str, object] = {}
    overall_readiness = "READY"
    for track in Track:
        minimum_required = VOCAB_READINESS_MIN_ROWS_BY_TRACK[track.value]
        count = track_counts[track.value]
        track_readiness = "READY" if count >= minimum_required else "NOT_READY"
        if track_readiness != "READY":
            overall_readiness = "NOT_READY"
        tracks[track.value] = {
            "eligibleCount": count,
            "minimumRequired": minimum_required,
            "readiness": track_readiness,
        }

    if missing_metadata_ids:
        overall_readiness = "NOT_READY"

    return {
        "backendCatalogPresent": False,
        "serviceReadiness": overall_readiness,
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
            "requiredSourceTags": list(VOCAB_READINESS_REQUIRED_SOURCE_TAGS),
        },
    }


def _run_mock_readiness_check(
    db: Session,
    *,
    track: Track,
    exam_type: MockExamType,
    period_key: str,
) -> dict[str, object]:
    payload = MockAssemblyJobCreateRequest.model_validate(
        {
            "examType": exam_type.value,
            "track": track.value,
            "periodKey": period_key,
            "dryRun": True,
            "forceRebuild": False,
        }
    )
    nested = db.begin_nested()
    try:
        response = create_mock_assembly_job(db, payload=payload)
    finally:
        nested.rollback()

    difficulty_profile = MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value]
    summary = response.summary_json
    constraint_summary = response.constraint_summary_json
    warning_codes: list[str] = []
    warnings = summary.get("warnings")
    if isinstance(warnings, list):
        warning_codes = [str(item) for item in warnings]

    if exam_type == MockExamType.WEEKLY:
        required_counts = {
            "listening": MOCK_EXAM_WEEKLY_LISTENING_COUNT,
            "reading": MOCK_EXAM_WEEKLY_READING_COUNT,
        }
        type_diversity = {
            "listening": MOCK_ASSEMBLY_WEEKLY_LISTENING_TYPE_DIVERSITY_MIN,
            "reading": MOCK_ASSEMBLY_WEEKLY_READING_TYPE_DIVERSITY_MIN,
        }
    else:
        required_counts = {
            "listening": MOCK_EXAM_MONTHLY_LISTENING_COUNT,
            "reading": MOCK_EXAM_MONTHLY_READING_COUNT,
        }
        type_diversity = {
            "listening": MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN,
            "reading": MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN,
        }

    blocked_by_missing_content = response.failure_code in {
        "INSUFFICIENT_PUBLISHED_CONTENT",
        "INSUFFICIENT_LISTENING_CONTENT",
        "INSUFFICIENT_READING_CONTENT",
        "INSUFFICIENT_TYPE_DIVERSITY",
    }

    readiness = "READY"
    if response.status != AIGenerationJobStatus.SUCCEEDED:
        readiness = "NOT_READY"
    elif warning_codes:
        readiness = "WARNING"

    return {
        "readiness": readiness,
        "status": response.status.value,
        "failureCode": response.failure_code,
        "failureMessage": response.failure_message,
        "blockedByMissingContent": blocked_by_missing_content,
        "requiredCounts": required_counts,
        "requiredTypeDiversity": type_diversity,
        "targetDifficultyRange": {
            "minAverage": difficulty_profile[0],
            "maxAverage": difficulty_profile[1],
        },
        "candidatePoolCounts": response.candidate_pool_counts_json,
        "summary": {
            "accepted": summary.get("accepted"),
            "listeningCount": summary.get("listeningCount"),
            "readingCount": summary.get("readingCount"),
            "warnings": warning_codes,
            "constraintSummary": constraint_summary,
        },
    }


def _skill_bucket_counts(
    items: list[PublishedContentInventoryItem],
) -> dict[str, object]:
    by_type_tag: dict[str, int] = defaultdict(int)
    by_difficulty = {str(index): 0 for index in range(1, 6)}
    for item in items:
        by_type_tag[item.type_tag] += 1
        by_difficulty[str(item.difficulty)] += 1

    skill = items[0].skill.value if items else None
    missing_type_tags: list[str] = []
    if skill is not None:
        missing_type_tags = [
            type_tag
            for type_tag in canonical_type_tags_for_skill(skill)
            if by_type_tag.get(type_tag, 0) == 0
        ]

    return {
        "total": len(items),
        "averageDifficulty": _average_difficulty(items),
        "byTypeTag": dict(sorted(by_type_tag.items())),
        "byDifficulty": by_difficulty,
        "missingTypeTags": missing_type_tags,
        "missingDifficultyBuckets": [
            bucket for bucket, count in by_difficulty.items() if count == 0
        ],
    }


def _average_difficulty(items: list[PublishedContentInventoryItem]) -> float | None:
    if not items:
        return None
    return round(sum(item.difficulty for item in items) / len(items), 4)


def _track_is_within_vocab_band(
    *,
    track: str,
    minimum: str | None,
    maximum: str | None,
) -> bool:
    if minimum is None or maximum is None:
        return False
    try:
        track_index = _TRACK_INDEX[track]
        minimum_index = _TRACK_INDEX[minimum]
        maximum_index = _TRACK_INDEX[maximum]
    except KeyError:
        return False
    return minimum_index <= track_index <= maximum_index


def _vocab_row_has_required_metadata(row: VocabularySeedItem) -> bool:
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


def _utc_now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _require_object_mapping(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise RuntimeError("content_readiness_report_shape_invalid")
    return cast(dict[str, object], value)


def _readiness_value(track_map: dict[str, object], track: str) -> str:
    return str(_require_object_mapping(track_map[track])["readiness"])


def _nested_readiness_value(track_map: dict[str, object], track: str, section: str) -> str:
    track_payload = _require_object_mapping(track_map[track])
    section_payload = _require_object_mapping(track_payload[section])
    return str(section_payload["readiness"])


def _eligible_count(track_map: dict[str, object], track: str) -> int:
    raw_value = _require_object_mapping(track_map[track])["eligibleCount"]
    return _as_positive_int(raw_value)


def _as_positive_int(value: object) -> int:
    if isinstance(value, bool) or value is None:
        return 0
    if isinstance(value, (int, float, str)):
        try:
            return int(value)
        except (TypeError, ValueError):
            return 0
    return 0


def _as_object_list(value: object) -> list[object]:
    if isinstance(value, list):
        return value
    return []


def _planned_deficit_tracks(
    *,
    backfill_plan: dict[str, object] | None,
    reasons: set[str],
) -> set[str]:
    if not isinstance(backfill_plan, dict):
        return set()
    content_deficits = backfill_plan.get("contentDeficits")
    if not isinstance(content_deficits, list):
        return set()
    planned_tracks: set[str] = set()
    for row in content_deficits:
        if not isinstance(row, dict):
            continue
        reason = row.get("reason")
        track = row.get("track")
        if reason in reasons and isinstance(track, str) and track in _TRACK_INDEX:
            planned_tracks.add(track)
    return planned_tracks
