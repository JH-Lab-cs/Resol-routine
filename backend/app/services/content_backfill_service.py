from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.content_type_taxonomy import canonical_type_tags_for_skill
from app.core.policies import (
    AI_CONTENT_MAX_CANDIDATES_PER_JOB,
    CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
    CONTENT_BACKFILL_ESTIMATED_OUTPUT_TOKENS_PER_CANDIDATE,
    CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_JOB,
    CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_TARGET,
    CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_DEFAULT,
    CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_MAX,
    CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_DEFAULT,
    CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_MAX,
    CONTENT_BACKFILL_PRIORITY_ORDER,
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
)
from app.db.session import run_post_commit_ai_content_generation_tasks
from app.models.enums import Skill, Track
from app.schemas.ai_content_generation import AIContentGenerationJobCreateRequest
from app.services.ai_content_generation_service import create_ai_content_generation_job
from app.services.content_readiness_service import (
    PublishedContentInventoryItem,
    VocabularySeedItem,
    build_content_readiness_report,
    load_published_inventory,
    load_seed_vocabulary_rows,
)


@dataclass(frozen=True, slots=True)
class BackfillDeficitRow:
    track: Track
    skill: Skill
    type_tag: str
    difficulty: int
    required_count: int
    reason: str
    reasons: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class BackfillFilter:
    track: Track | None = None
    skill: Skill | None = None
    type_tag: str | None = None
    difficulty_min: int | None = None
    difficulty_max: int | None = None
    limit: int | None = None


def build_content_backfill_plan(
    db: Session,
    *,
    filters: BackfillFilter | None = None,
    max_targets_per_run: int = CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_DEFAULT,
    max_candidates_per_run: int = CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_DEFAULT,
    provider_override: str | None = None,
) -> dict[str, object]:
    normalized_targets_per_run = _normalize_max_targets_per_run(max_targets_per_run)
    normalized_candidates_per_run = _normalize_max_candidates_per_run(max_candidates_per_run)
    active_filters = filters or BackfillFilter()

    readiness_report = build_content_readiness_report(db)
    inventory = load_published_inventory(db)
    vocab_rows = load_seed_vocabulary_rows()
    aggregated_content_deficits = _build_aggregated_content_deficits(inventory)
    filtered_content_deficits = _apply_content_filters(
        aggregated_content_deficits,
        filters=active_filters,
    )
    vocab_deficits = _build_vocab_deficits(vocab_rows=vocab_rows)
    target_batches = _build_target_matrix_batches(
        deficits=filtered_content_deficits,
        max_targets_per_run=normalized_targets_per_run,
        max_candidates_per_run=normalized_candidates_per_run,
    )
    queue_preview = _build_queue_preview(
        target_batches=target_batches,
        max_targets_per_run=normalized_targets_per_run,
        max_candidates_per_run=normalized_candidates_per_run,
        provider_override=provider_override,
    )

    return {
        "policyVersion": CONTENT_READINESS_POLICY_VERSION,
        "generatedAt": _utc_now_iso(),
        "dryRunDefault": True,
        "filters": _serialize_filters(active_filters),
        "readiness": readiness_report,
        "contentDeficits": [
            _serialize_content_deficit(row=row) for row in filtered_content_deficits
        ],
        "vocabDeficits": vocab_deficits,
        "enqueuePreview": queue_preview,
    }


def enqueue_content_backfill_jobs(
    db: Session,
    *,
    filters: BackfillFilter | None = None,
    max_targets_per_run: int = CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_DEFAULT,
    max_candidates_per_run: int = CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_DEFAULT,
    provider_override: str | None = None,
    execute: bool = False,
) -> dict[str, object]:
    plan = build_content_backfill_plan(
        db,
        filters=filters,
        max_targets_per_run=max_targets_per_run,
        max_candidates_per_run=max_candidates_per_run,
        provider_override=provider_override,
    )
    preview_jobs = plan["enqueuePreview"]["jobs"]
    if not execute or not preview_jobs:
        plan["enqueueSummary"] = {
            "executed": False,
            "jobCount": 0,
            "jobs": [],
        }
        return plan

    created_jobs: list[dict[str, object]] = []
    for index, job_preview in enumerate(preview_jobs, start=1):
        payload = AIContentGenerationJobCreateRequest.model_validate(
            {
                "requestId": _build_backfill_request_id(index=index),
                "targetMatrix": job_preview["targetMatrix"],
                "candidateCountPerTarget": CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
                "providerOverride": provider_override,
                "dryRun": False,
                "notes": "B2.6.3 readiness backfill enqueue",
                "metadata": {
                    "source": "content_readiness_backfill",
                    "primaryReasons": job_preview["primaryReasons"],
                    "filters": plan["filters"],
                    "estimatedTotalTokens": job_preview["estimatedTotalTokens"],
                },
            }
        )
        response = create_ai_content_generation_job(db, payload=payload)
        created_jobs.append(response.model_dump(mode="json"))

    db.commit()
    run_post_commit_ai_content_generation_tasks(db)
    plan["enqueueSummary"] = {
        "executed": True,
        "jobCount": len(created_jobs),
        "jobs": created_jobs,
    }
    return plan


def _build_aggregated_content_deficits(
    inventory: list[PublishedContentInventoryItem],
) -> list[BackfillDeficitRow]:
    raw_rows: list[BackfillDeficitRow] = []
    for track in Track:
        preferred_difficulties = _preferred_daily_difficulties(track)
        for skill in Skill:
            required_diversity = (
                DAILY_READINESS_LISTENING_TYPE_DIVERSITY_MIN
                if skill == Skill.LISTENING
                else DAILY_READINESS_READING_TYPE_DIVERSITY_MIN
            )
            raw_rows.extend(
                _build_objective_deficits(
                    inventory=inventory,
                    track=track,
                    skill=skill,
                    required_total=DAILY_READINESS_MIN_PER_SKILL,
                    required_diversity=required_diversity,
                    preferred_difficulties=preferred_difficulties,
                    reason="DAILY_READINESS_DEFICIT",
                    target_average_range=None,
                )
            )

        raw_rows.extend(
            _build_objective_deficits(
                inventory=inventory,
                track=track,
                skill=Skill.LISTENING,
                required_total=MOCK_EXAM_WEEKLY_LISTENING_COUNT,
                required_diversity=MOCK_ASSEMBLY_WEEKLY_LISTENING_TYPE_DIVERSITY_MIN,
                preferred_difficulties=_preferred_mock_difficulties(track),
                reason="WEEKLY_READINESS_DEFICIT",
                target_average_range=MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value],
            )
        )
        raw_rows.extend(
            _build_objective_deficits(
                inventory=inventory,
                track=track,
                skill=Skill.READING,
                required_total=MOCK_EXAM_WEEKLY_READING_COUNT,
                required_diversity=MOCK_ASSEMBLY_WEEKLY_READING_TYPE_DIVERSITY_MIN,
                preferred_difficulties=_preferred_mock_difficulties(track),
                reason="WEEKLY_READINESS_DEFICIT",
                target_average_range=MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value],
            )
        )
        raw_rows.extend(
            _build_objective_deficits(
                inventory=inventory,
                track=track,
                skill=Skill.LISTENING,
                required_total=MOCK_EXAM_MONTHLY_LISTENING_COUNT,
                required_diversity=MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN,
                preferred_difficulties=_preferred_mock_difficulties(track),
                reason="MONTHLY_READINESS_DEFICIT",
                target_average_range=MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value],
            )
        )
        raw_rows.extend(
            _build_objective_deficits(
                inventory=inventory,
                track=track,
                skill=Skill.READING,
                required_total=MOCK_EXAM_MONTHLY_READING_COUNT,
                required_diversity=MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN,
                preferred_difficulties=_preferred_mock_difficulties(track),
                reason="MONTHLY_READINESS_DEFICIT",
                target_average_range=MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value],
            )
        )

    aggregated: dict[tuple[str, str, str, int], dict[str, object]] = {}
    for row in raw_rows:
        key = (row.track.value, row.skill.value, row.type_tag, row.difficulty)
        entry = aggregated.get(key)
        if entry is None:
            aggregated[key] = {
                "track": row.track,
                "skill": row.skill,
                "type_tag": row.type_tag,
                "difficulty": row.difficulty,
                "required_count": row.required_count,
                "reason": row.reason,
                "reasons": set(row.reasons),
            }
            continue
        entry["required_count"] = max(int(entry["required_count"]), row.required_count)
        entry["reasons"].update(row.reasons)
        if _reason_priority(row.reason) < _reason_priority(str(entry["reason"])):
            entry["reason"] = row.reason

    rows = [
        BackfillDeficitRow(
            track=entry["track"],
            skill=entry["skill"],
            type_tag=str(entry["type_tag"]),
            difficulty=int(entry["difficulty"]),
            required_count=int(entry["required_count"]),
            reason=str(entry["reason"]),
            reasons=tuple(sorted(set(entry["reasons"]), key=_reason_priority)),
        )
        for entry in aggregated.values()
        if int(entry["required_count"]) > 0
    ]
    rows.sort(
        key=lambda row: (
            _reason_priority(row.reason),
            _track_priority(row.track.value),
            row.skill.value,
            row.type_tag,
            row.difficulty,
        )
    )
    return rows


def _build_objective_deficits(
    *,
    inventory: list[PublishedContentInventoryItem],
    track: Track,
    skill: Skill,
    required_total: int,
    required_diversity: int,
    preferred_difficulties: tuple[int, ...],
    reason: str,
    target_average_range: tuple[float, float] | None,
) -> list[BackfillDeficitRow]:
    skill_items = [
        item for item in inventory if item.track == track and item.skill == skill
    ]
    current_total = len(skill_items)
    current_sum = sum(item.difficulty for item in skill_items)
    type_counts: dict[str, int] = defaultdict(int)
    for item in skill_items:
        type_counts[item.type_tag] += 1

    allocations: dict[tuple[str, int], int] = defaultdict(int)
    missing_type_tags = [
        type_tag
        for type_tag in canonical_type_tags_for_skill(skill.value)
        if type_counts.get(type_tag, 0) == 0
    ]
    current_diversity = len(type_counts)
    needed_unique_tags = max(0, required_diversity - current_diversity)
    base_quota = max(1, ceil(required_total / required_diversity))
    remaining_total_deficit = max(0, required_total - current_total)

    for type_tag in missing_type_tags[:needed_unique_tags]:
        if remaining_total_deficit <= 0:
            break
        requested = min(remaining_total_deficit, max(1, base_quota - type_counts.get(type_tag, 0)))
        added_sum = _allocate_counts(
            allocations=allocations,
            type_tag=type_tag,
            count=requested,
            preferred_difficulties=preferred_difficulties,
        )
        type_counts[type_tag] += requested
        current_total += requested
        current_sum += added_sum
        remaining_total_deficit -= requested

    canonical_tags = list(canonical_type_tags_for_skill(skill.value))
    while remaining_total_deficit > 0:
        selected_type_tag = min(
            canonical_tags,
            key=lambda value: (type_counts.get(value, 0), canonical_tags.index(value)),
        )
        added_sum = _allocate_counts(
            allocations=allocations,
            type_tag=selected_type_tag,
            count=1,
            preferred_difficulties=preferred_difficulties,
        )
        type_counts[selected_type_tag] += 1
        current_total += 1
        current_sum += added_sum
        remaining_total_deficit -= 1

    if target_average_range is not None and current_total > 0:
        lower_bound, upper_bound = target_average_range
        simulated_average = current_sum / current_total
        if simulated_average < lower_bound:
            difficulty = preferred_difficulties[-1]
            required_average_count = _required_average_adjustment_count(
                total_count=current_total,
                total_sum=current_sum,
                target_average=lower_bound,
                fill_difficulty=difficulty,
                direction="raise",
            )
            if required_average_count > 0:
                _allocate_counts(
                    allocations=allocations,
                    type_tag=canonical_tags[0],
                    count=required_average_count,
                    preferred_difficulties=(difficulty,),
                )
        elif simulated_average > upper_bound:
            difficulty = preferred_difficulties[0]
            required_average_count = _required_average_adjustment_count(
                total_count=current_total,
                total_sum=current_sum,
                target_average=upper_bound,
                fill_difficulty=difficulty,
                direction="lower",
            )
            if required_average_count > 0:
                _allocate_counts(
                    allocations=allocations,
                    type_tag=canonical_tags[0],
                    count=required_average_count,
                    preferred_difficulties=(difficulty,),
                )

    rows: list[BackfillDeficitRow] = []
    for (type_tag, difficulty), count in allocations.items():
        rows.append(
            BackfillDeficitRow(
                track=track,
                skill=skill,
                type_tag=type_tag,
                difficulty=difficulty,
                required_count=count,
                reason=reason,
                reasons=(reason,),
            )
        )
    rows.sort(key=lambda row: (row.type_tag, row.difficulty))
    return rows


def _build_vocab_deficits(*, vocab_rows: list[VocabularySeedItem]) -> list[dict[str, object]]:
    track_counts: dict[str, int] = {track.value: 0 for track in Track}
    for row in vocab_rows:
        if row.target_min_track is None or row.target_max_track is None:
            continue
        for track in Track:
            if _track_in_range(
                track=track.value,
                minimum=row.target_min_track,
                maximum=row.target_max_track,
            ):
                track_counts[track.value] += 1

    deficits: list[dict[str, object]] = []
    for track in Track:
        minimum_required = VOCAB_READINESS_MIN_ROWS_BY_TRACK[track.value]
        current_count = track_counts[track.value]
        if current_count >= minimum_required:
            continue
        min_difficulty, max_difficulty = DAILY_READINESS_DIFFICULTY_RANGE_BY_TRACK[track.value]
        deficits.append(
            {
                "track": track.value,
                "requiredCount": minimum_required - current_count,
                "currentCount": current_count,
                "reason": "VOCAB_BANDING_DEFICIT",
                "difficultyMin": min_difficulty,
                "difficultyMax": max_difficulty,
                "enqueuable": False,
                "note": (
                    "Backend vocab catalog is not implemented; local/front vocabulary "
                    "metadata remains the source for this audit."
                ),
            }
        )
    return deficits


def _apply_content_filters(
    rows: list[BackfillDeficitRow],
    *,
    filters: BackfillFilter,
) -> list[BackfillDeficitRow]:
    filtered = rows
    if filters.track is not None:
        filtered = [row for row in filtered if row.track == filters.track]
    if filters.skill is not None:
        filtered = [row for row in filtered if row.skill == filters.skill]
    if filters.type_tag is not None:
        filtered = [row for row in filtered if row.type_tag == filters.type_tag]
    if filters.difficulty_min is not None:
        filtered = [row for row in filtered if row.difficulty >= filters.difficulty_min]
    if filters.difficulty_max is not None:
        filtered = [row for row in filtered if row.difficulty <= filters.difficulty_max]
    if filters.limit is not None:
        filtered = filtered[: filters.limit]
    return filtered


def _build_target_matrix_batches(
    *,
    deficits: list[BackfillDeficitRow],
    max_targets_per_run: int,
    max_candidates_per_run: int,
) -> list[list[dict[str, object]]]:
    batches: list[list[dict[str, object]]] = []
    current_batch: list[dict[str, object]] = []
    current_candidate_total = 0
    for row in deficits:
        row_candidate_total = (
            row.required_count * CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET
        )
        if current_batch and (
            len(current_batch) >= max_targets_per_run
            or current_candidate_total + row_candidate_total > max_candidates_per_run
            or current_candidate_total + row_candidate_total > AI_CONTENT_MAX_CANDIDATES_PER_JOB
        ):
            batches.append(current_batch)
            current_batch = []
            current_candidate_total = 0

        current_batch.append(
            {
                "track": row.track.value,
                "skill": row.skill.value,
                "typeTag": row.type_tag,
                "difficulty": row.difficulty,
                "count": row.required_count,
                "reason": row.reason,
                "reasons": list(row.reasons),
            }
        )
        current_candidate_total += row_candidate_total

    if current_batch:
        batches.append(current_batch)
    return batches


def _build_queue_preview(
    *,
    target_batches: list[list[dict[str, object]]],
    max_targets_per_run: int,
    max_candidates_per_run: int,
    provider_override: str | None,
) -> dict[str, object]:
    provider_name = provider_override or settings.ai_generation_provider
    jobs: list[dict[str, object]] = []
    estimated_prompt_tokens = 0
    estimated_output_tokens = 0
    for index, batch in enumerate(target_batches, start=1):
        candidate_total = sum(int(row["count"]) for row in batch)
        prompt_tokens = (
            CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_JOB
            + len(batch) * CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_TARGET
        )
        output_tokens = candidate_total * CONTENT_BACKFILL_ESTIMATED_OUTPUT_TOKENS_PER_CANDIDATE
        estimated_prompt_tokens += prompt_tokens
        estimated_output_tokens += output_tokens
        jobs.append(
            {
                "index": index,
                "targetCount": len(batch),
                "candidateCount": candidate_total,
                "primaryReasons": sorted(
                    {str(row["reason"]) for row in batch},
                    key=_reason_priority,
                ),
                "estimatedPromptTokens": prompt_tokens,
                "estimatedOutputTokens": output_tokens,
                "estimatedTotalTokens": prompt_tokens + output_tokens,
                "targetMatrix": [
                    {
                        "track": row["track"],
                        "skill": row["skill"],
                        "typeTag": row["typeTag"],
                        "difficulty": row["difficulty"],
                        "count": row["count"],
                    }
                    for row in batch
                ],
            }
        )

    return {
        "dryRunDefault": True,
        "provider": provider_name,
        "model": settings.ai_content_model,
        "promptTemplateVersion": settings.ai_content_prompt_template_version,
        "candidateCountPerTarget": CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
        "maxTargetsPerRun": max_targets_per_run,
        "maxCandidatesPerRun": max_candidates_per_run,
        "estimatedProviderCalls": len(jobs),
        "estimatedPromptTokens": estimated_prompt_tokens,
        "estimatedOutputTokens": estimated_output_tokens,
        "estimatedTotalTokens": estimated_prompt_tokens + estimated_output_tokens,
        "estimatedCostUsd": None,
        "costComputation": "pricing_not_configured",
        "jobs": jobs,
    }


def _serialize_content_deficit(*, row: BackfillDeficitRow) -> dict[str, object]:
    return {
        "track": row.track.value,
        "skill": row.skill.value,
        "typeTag": row.type_tag,
        "difficultyMin": row.difficulty,
        "difficultyMax": row.difficulty,
        "requiredCount": row.required_count,
        "reason": row.reason,
        "reasons": list(row.reasons),
        "priority": _reason_priority(row.reason),
    }


def _serialize_filters(filters: BackfillFilter) -> dict[str, object]:
    return {
        "track": filters.track.value if filters.track is not None else None,
        "skill": filters.skill.value if filters.skill is not None else None,
        "typeTag": filters.type_tag,
        "difficultyMin": filters.difficulty_min,
        "difficultyMax": filters.difficulty_max,
        "limit": filters.limit,
    }


def _allocate_counts(
    *,
    allocations: dict[tuple[str, int], int],
    type_tag: str,
    count: int,
    preferred_difficulties: tuple[int, ...],
) -> int:
    existing_total = sum(
        value
        for (allocated_type_tag, _difficulty), value in allocations.items()
        if allocated_type_tag == type_tag
    )
    added_sum = 0
    for offset in range(count):
        difficulty = preferred_difficulties[(existing_total + offset) % len(preferred_difficulties)]
        allocations[(type_tag, difficulty)] += 1
        added_sum += difficulty
    return added_sum


def _required_average_adjustment_count(
    *,
    total_count: int,
    total_sum: int,
    target_average: float,
    fill_difficulty: int,
    direction: str,
) -> int:
    if direction == "raise":
        if fill_difficulty <= target_average:
            return 0
        numerator = target_average * total_count - total_sum
        denominator = fill_difficulty - target_average
    else:
        if fill_difficulty >= target_average:
            return 0
        numerator = total_sum - target_average * total_count
        denominator = target_average - fill_difficulty

    if numerator <= 0:
        return 0
    return ceil(numerator / denominator)


def _preferred_daily_difficulties(track: Track) -> tuple[int, ...]:
    minimum, maximum = DAILY_READINESS_DIFFICULTY_RANGE_BY_TRACK[track.value]
    return tuple(range(minimum, maximum + 1))


def _preferred_mock_difficulties(track: Track) -> tuple[int, ...]:
    minimum, maximum = MOCK_ASSEMBLY_DEFAULT_DIFFICULTY_RANGE_BY_TRACK[track.value]
    rounded_min = max(1, round(minimum))
    rounded_max = min(5, round(maximum + 0.49))
    if rounded_min > rounded_max:
        rounded_min, rounded_max = rounded_max, rounded_min
    return tuple(range(rounded_min, rounded_max + 1))


def _normalize_max_targets_per_run(value: int) -> int:
    if value <= 0 or value > CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_MAX:
        raise ValueError("invalid_max_targets_per_run")
    return value


def _normalize_max_candidates_per_run(value: int) -> int:
    if value <= 0 or value > CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_MAX:
        raise ValueError("invalid_max_candidates_per_run")
    return value


def _track_in_range(*, track: str, minimum: str, maximum: str) -> bool:
    track_order = [entry.value for entry in Track]
    try:
        track_index = track_order.index(track)
        minimum_index = track_order.index(minimum)
        maximum_index = track_order.index(maximum)
    except ValueError:
        return False
    return minimum_index <= track_index <= maximum_index


def _track_priority(track: str) -> int:
    track_order = [entry.value for entry in Track]
    return track_order.index(track)


def _reason_priority(reason: str) -> int:
    return CONTENT_BACKFILL_PRIORITY_ORDER.get(reason, 999)


def _build_backfill_request_id(*, index: int) -> str:
    timestamp = datetime.now(UTC).strftime("%Y%m%d%H%M%S")
    return f"backfill-{timestamp}-{index}-{uuid4().hex[:8]}"


def _utc_now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
