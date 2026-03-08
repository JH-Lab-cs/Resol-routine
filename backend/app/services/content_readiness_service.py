from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import (
    canonical_type_tags_for_skill,
    is_canonical_type_tag_for_skill,
    normalize_type_tag_alias_or_canonical,
)
from app.core.policies import (
    MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK,
    MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_WEEKLY_LISTENING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_WEEKLY_READING_TYPE_DIVERSITY_MIN,
    MOCK_EXAM_MONTHLY_LISTENING_COUNT,
    MOCK_EXAM_MONTHLY_READING_COUNT,
    MOCK_EXAM_WEEKLY_LISTENING_COUNT,
    MOCK_EXAM_WEEKLY_READING_COUNT,
)
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import AIGenerationJobStatus, MockExamType, Skill, Track
from app.schemas.mock_assembly import MockAssemblyJobCreateRequest
from app.services.mock_assembly_service import create_mock_assembly_job

DAILY_LIVE_SERVICE_MIN_PER_SKILL = 21
DAILY_MIN_LISTENING_COUNT = 3
DAILY_MIN_READING_COUNT = 3
DAILY_READY_LISTENING_TYPE_DIVERSITY_MIN = 4
DAILY_READY_READING_TYPE_DIVERSITY_MIN = 5
DAILY_READY_DIFFICULTY_BUCKET_MIN = 2


@dataclass(frozen=True, slots=True)
class PublishedContentInventoryItem:
    track: Track
    skill: Skill
    unit_id: UUID
    revision_id: UUID
    question_id: UUID
    type_tag: str
    difficulty: int


def build_content_readiness_report(db: Session) -> dict[str, object]:
    inventory = _load_published_inventory(db)
    return {
        "generatedAt": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "daily": build_daily_readiness_report(inventory),
        "mock": build_mock_readiness_report(db, inventory=inventory),
    }


def build_daily_readiness_report(
    inventory: list[PublishedContentInventoryItem],
) -> dict[str, object]:
    tracks: dict[str, object] = {}
    for track in Track:
        track_items = [item for item in inventory if item.track == track]
        per_skill: dict[str, object] = {}
        daily_possible = True
        warning_reasons: list[str] = []

        for skill in Skill:
            skill_items = [item for item in track_items if item.skill == skill]
            type_counts: dict[str, int] = {}
            difficulty_counts = {str(index): 0 for index in range(1, 6)}
            for item in skill_items:
                type_counts[item.type_tag] = type_counts.get(item.type_tag, 0) + 1
                difficulty_counts[str(item.difficulty)] += 1

            missing_type_tags = [
                type_tag
                for type_tag in canonical_type_tags_for_skill(skill.value)
                if type_counts.get(type_tag, 0) == 0
            ]
            missing_difficulty_buckets = [
                bucket for bucket, count in difficulty_counts.items() if count == 0
            ]
            populated_difficulty_buckets = [
                bucket for bucket, count in difficulty_counts.items() if count > 0
            ]

            per_skill[skill.value] = {
                "total": len(skill_items),
                "byTypeTag": dict(sorted(type_counts.items())),
                "byDifficulty": difficulty_counts,
                "missingTypeTags": missing_type_tags,
                "missingDifficultyBuckets": missing_difficulty_buckets,
            }

            minimum_count = (
                DAILY_MIN_LISTENING_COUNT if skill == Skill.LISTENING else DAILY_MIN_READING_COUNT
            )
            diversity_floor = (
                DAILY_READY_LISTENING_TYPE_DIVERSITY_MIN
                if skill == Skill.LISTENING
                else DAILY_READY_READING_TYPE_DIVERSITY_MIN
            )
            if len(skill_items) < minimum_count:
                daily_possible = False
            if len(skill_items) < DAILY_LIVE_SERVICE_MIN_PER_SKILL:
                warning_reasons.append(f"{skill.value.lower()}_count_below_live_threshold")
            if len(type_counts) < diversity_floor:
                warning_reasons.append(f"{skill.value.lower()}_type_diversity_below_ready_threshold")
            if len(populated_difficulty_buckets) < DAILY_READY_DIFFICULTY_BUCKET_MIN:
                warning_reasons.append(
                    f"{skill.value.lower()}_difficulty_buckets_below_ready_threshold"
                )

        readiness = "READY"
        if not daily_possible:
            readiness = "NOT_READY"
        elif warning_reasons:
            readiness = "WARNING"

        tracks[track.value] = {
            "matrix": per_skill,
            "dailyPossible": daily_possible,
            "recommendedMinimumThreshold": {
                "listening": DAILY_LIVE_SERVICE_MIN_PER_SKILL,
                "reading": DAILY_LIVE_SERVICE_MIN_PER_SKILL,
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

        listening_counts = _skill_bucket_counts(listening_items)
        reading_counts = _skill_bucket_counts(reading_items)

        tracks[track.value] = {
            "inventory": {
                "LISTENING": listening_counts,
                "READING": reading_counts,
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
    warning_codes = []
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


def _load_published_inventory(db: Session) -> list[PublishedContentInventoryItem]:
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


def _skill_bucket_counts(
    items: list[PublishedContentInventoryItem],
) -> dict[str, object]:
    by_type_tag: dict[str, int] = defaultdict(int)
    by_difficulty = {str(index): 0 for index in range(1, 6)}
    for item in items:
        by_type_tag[item.type_tag] += 1
        by_difficulty[str(item.difficulty)] += 1

    average_difficulty = None
    if items:
        average_difficulty = round(
            sum(item.difficulty for item in items) / len(items),
            4,
        )

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
        "averageDifficulty": average_difficulty,
        "byTypeTag": dict(sorted(by_type_tag.items())),
        "byDifficulty": by_difficulty,
        "missingTypeTags": missing_type_tags,
        "missingDifficultyBuckets": [
            bucket for bucket, count in by_difficulty.items() if count == 0
        ],
    }
