from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from typing import Any, cast
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.content_type_taxonomy import canonical_type_tags_for_skill
from app.core.policies import (
    AI_CONTENT_MAX_CANDIDATES_PER_JOB,
    CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
    CONTENT_BACKFILL_ESTIMATED_OUTPUT_TOKENS_PER_CANDIDATE,
    CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_JOB,
    CONTENT_BACKFILL_ESTIMATED_PROMPT_TOKENS_PER_TARGET,
    CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_MAX,
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
from app.models.ai_content_generation_job import AIContentGenerationJob
from app.models.enums import AIGenerationJobStatus, Skill, Track
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


class ContentBackfillExecutionError(RuntimeError):
    def __init__(self, *, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True, slots=True)
class ContentBackfillExecutionConfig:
    provider_name: str
    provider_configured: bool
    api_key_present: bool
    model_name: str
    prompt_template_version: str
    max_targets_per_run: int
    max_candidates_per_run: int
    max_estimated_cost_usd: float
    default_dry_run: bool
    estimated_input_cost_per_million_tokens: float
    estimated_output_cost_per_million_tokens: float


def build_content_backfill_plan(
    db: Session,
    *,
    filters: BackfillFilter | None = None,
    max_targets_per_run: int | None = None,
    max_candidates_per_run: int | None = None,
    provider_override: str | None = None,
) -> dict[str, object]:
    execution_config = _resolve_execution_config(
        provider_override=provider_override,
        max_targets_per_run=max_targets_per_run,
        max_candidates_per_run=max_candidates_per_run,
    )
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
        max_targets_per_run=execution_config.max_targets_per_run,
        max_candidates_per_run=execution_config.max_candidates_per_run,
    )
    queue_preview = _build_queue_preview(
        target_batches=target_batches,
        execution_config=execution_config,
    )

    return {
        "policyVersion": CONTENT_READINESS_POLICY_VERSION,
        "generatedAt": _utc_now_iso(),
        "dryRunDefault": execution_config.default_dry_run,
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
    max_targets_per_run: int | None = None,
    max_candidates_per_run: int | None = None,
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
    preview = cast(dict[str, Any], plan["enqueuePreview"])
    preview_jobs = cast(list[dict[str, Any]], preview["jobs"])
    if not execute:
        plan["enqueueSummary"] = {
            "executed": False,
            "jobCount": 0,
            "jobs": [],
        }
        return plan

    if not preview_jobs:
        raise ContentBackfillExecutionError(
            code="VALIDATION_FAILED",
            message="No deficits matched the requested filters.",
        )

    if not bool(preview["providerConfigured"]):
        raise ContentBackfillExecutionError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI content provider is not configured for execution.",
        )
    if str(preview["provider"]) != "fake" and not bool(preview["apiKeyPresent"]):
        raise ContentBackfillExecutionError(
            code="PROVIDER_NOT_CONFIGURED",
            message="AI content provider API key is not configured for execution.",
        )
    if str(preview["model"]) in {"", "not-configured"}:
        raise ContentBackfillExecutionError(
            code="PROVIDER_MODEL_NOT_SET",
            message="AI content model is not configured.",
        )
    if str(preview["promptTemplateVersion"]) in {"", "not-configured"}:
        raise ContentBackfillExecutionError(
            code="PROVIDER_MODEL_NOT_SET",
            message="AI content prompt template version is not configured.",
        )

    estimated_cost_usd = float(preview["estimatedCostUsd"])
    max_estimated_cost_usd = float(preview["maxEstimatedCostUsd"])
    if estimated_cost_usd > max_estimated_cost_usd:
        raise ContentBackfillExecutionError(
            code="PROVIDER_BUDGET_EXCEEDED",
            message="Estimated backfill cost exceeds the configured budget limit.",
        )

    created_jobs: list[dict[str, object]] = []
    skipped_existing_jobs: list[dict[str, object]] = []
    existing_active_jobs = _list_existing_active_backfill_jobs(db)
    for index, job_preview in enumerate(preview_jobs, start=1):
        deficit_signature = _build_deficit_signature(job_preview["targetMatrix"])
        duplicate_job = existing_active_jobs.get(deficit_signature)
        if duplicate_job is not None:
            skipped_existing_jobs.append(
                {
                    "existingJobId": str(duplicate_job.id),
                    "deficitSignature": deficit_signature,
                    "status": duplicate_job.status.value,
                    "primaryReasons": job_preview["primaryReasons"],
                }
            )
            continue

        payload = AIContentGenerationJobCreateRequest.model_validate(
            {
                "requestId": _build_backfill_request_id(index=index),
                "targetMatrix": job_preview["targetMatrix"],
                "candidateCountPerTarget": CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
                "providerOverride": provider_override,
                "dryRun": False,
                "notes": "Controlled readiness backfill enqueue",
                "metadata": {
                    "source": "content_readiness_backfill",
                    "primaryReasons": job_preview["primaryReasons"],
                    "filters": plan["filters"],
                    "originatingDeficitPlan": job_preview["originatingDeficits"],
                    "deficitSignature": deficit_signature,
                    "estimatedCostUsd": job_preview["estimatedCostUsd"],
                    "estimatedTotalTokens": job_preview["estimatedTotalTokens"],
                    "estimatedProviderCalls": job_preview["estimatedProviderCalls"],
                    "estimatedPromptTokens": job_preview["estimatedPromptTokens"],
                    "estimatedOutputTokens": job_preview["estimatedOutputTokens"],
                    "costComputation": preview["costComputation"],
                },
            }
        )
        response = create_ai_content_generation_job(db, payload=payload)
        created_jobs.append(response.model_dump(mode="json"))
        stored_job = db.get(AIContentGenerationJob, response.id)
        if stored_job is not None:
            existing_active_jobs[deficit_signature] = stored_job

    db.commit()
    run_post_commit_ai_content_generation_tasks(db)
    plan["enqueueSummary"] = {
        "executed": True,
        "jobCount": len(created_jobs),
        "jobs": created_jobs,
        "skippedExistingJobs": skipped_existing_jobs,
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

    aggregated: dict[tuple[str, str, str, int], dict[str, Any]] = {}
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
    skill_items = [item for item in inventory if item.track == track and item.skill == skill]
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
) -> list[list[dict[str, Any]]]:
    batches: list[list[dict[str, Any]]] = []
    current_batch: list[dict[str, Any]] = []
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
    target_batches: list[list[dict[str, Any]]],
    execution_config: ContentBackfillExecutionConfig,
) -> dict[str, object]:
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
                "estimatedProviderCalls": 1,
                "estimatedCostUsd": _estimate_cost_usd(
                    prompt_tokens=prompt_tokens,
                    output_tokens=output_tokens,
                    execution_config=execution_config,
                ),
                "originatingDeficits": [
                    {
                        "track": row["track"],
                        "skill": row["skill"],
                        "typeTag": row["typeTag"],
                        "difficultyMin": row["difficulty"],
                        "difficultyMax": row["difficulty"],
                        "requiredCount": row["count"],
                        "reason": row["reason"],
                        "reasons": list(row["reasons"]),
                        "priority": _reason_priority(str(row["reason"])),
                    }
                    for row in batch
                ],
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

    estimated_total_tokens = estimated_prompt_tokens + estimated_output_tokens
    estimated_cost_usd = _estimate_cost_usd(
        prompt_tokens=estimated_prompt_tokens,
        output_tokens=estimated_output_tokens,
        execution_config=execution_config,
    )
    return {
        "dryRunDefault": execution_config.default_dry_run,
        "provider": execution_config.provider_name,
        "providerConfigured": execution_config.provider_configured,
        "apiKeyPresent": execution_config.api_key_present,
        "model": execution_config.model_name,
        "promptTemplateVersion": execution_config.prompt_template_version,
        "candidateCountPerTarget": CONTENT_BACKFILL_DEFAULT_CANDIDATE_COUNT_PER_TARGET,
        "maxTargetsPerRun": execution_config.max_targets_per_run,
        "maxCandidatesPerRun": execution_config.max_candidates_per_run,
        "maxEstimatedCostUsd": execution_config.max_estimated_cost_usd,
        "estimatedProviderCalls": len(jobs),
        "estimatedPromptTokens": estimated_prompt_tokens,
        "estimatedOutputTokens": estimated_output_tokens,
        "estimatedTotalTokens": estimated_total_tokens,
        "estimatedCostUsd": estimated_cost_usd,
        "costComputation": "heuristic_per_million_tokens",
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
    max_allowed = min(
        settings.ai_content_max_targets_per_run,
        CONTENT_BACKFILL_MAX_TARGETS_PER_RUN_MAX,
    )
    if value <= 0 or value > max_allowed:
        raise ValueError("invalid_max_targets_per_run")
    return value


def _normalize_max_candidates_per_run(value: int) -> int:
    max_allowed = min(
        settings.ai_content_max_candidates_per_run,
        CONTENT_BACKFILL_MAX_CANDIDATES_PER_RUN_MAX,
    )
    if value <= 0 or value > max_allowed:
        raise ValueError("invalid_max_candidates_per_run")
    return value


def _resolve_execution_config(
    *,
    provider_override: str | None,
    max_targets_per_run: int | None,
    max_candidates_per_run: int | None,
) -> ContentBackfillExecutionConfig:
    provider_name = (provider_override or settings.resolved_ai_content_provider).strip()
    api_key = settings.resolved_ai_content_api_key
    model_name = settings.ai_content_model.strip()
    prompt_template_version = settings.ai_content_prompt_template_version.strip()
    resolved_max_targets = _normalize_max_targets_per_run(
        max_targets_per_run or settings.ai_content_max_targets_per_run
    )
    resolved_max_candidates = _normalize_max_candidates_per_run(
        max_candidates_per_run or settings.ai_content_max_candidates_per_run
    )
    return ContentBackfillExecutionConfig(
        provider_name=provider_name,
        provider_configured=provider_name not in {"", "disabled", "not-configured"},
        api_key_present=bool(api_key and api_key.strip()),
        model_name=model_name,
        prompt_template_version=prompt_template_version,
        max_targets_per_run=resolved_max_targets,
        max_candidates_per_run=resolved_max_candidates,
        max_estimated_cost_usd=settings.ai_content_max_estimated_cost_usd,
        default_dry_run=settings.ai_content_default_dry_run,
        estimated_input_cost_per_million_tokens=(
            settings.ai_content_estimated_input_cost_per_million_tokens
        ),
        estimated_output_cost_per_million_tokens=(
            settings.ai_content_estimated_output_cost_per_million_tokens
        ),
    )


def _estimate_cost_usd(
    *,
    prompt_tokens: int,
    output_tokens: int,
    execution_config: ContentBackfillExecutionConfig,
) -> float:
    input_cost = (
        prompt_tokens / 1_000_000
    ) * execution_config.estimated_input_cost_per_million_tokens
    output_cost = (
        output_tokens / 1_000_000
    ) * execution_config.estimated_output_cost_per_million_tokens
    return round(input_cost + output_cost, 6)


def _build_deficit_signature(target_matrix: list[dict[str, Any]]) -> str:
    normalized = sorted(
        [
            {
                "track": str(row["track"]),
                "skill": str(row["skill"]),
                "typeTag": str(row["typeTag"]),
                "difficulty": int(row["difficulty"]),
                "count": int(row["count"]),
            }
            for row in target_matrix
        ],
        key=lambda row: (
            row["track"],
            row["skill"],
            row["typeTag"],
            row["difficulty"],
            row["count"],
        ),
    )
    payload = json.dumps(normalized, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _list_existing_active_backfill_jobs(
    db: Session,
) -> dict[str, AIContentGenerationJob]:
    rows = db.execute(
        select(AIContentGenerationJob).where(
            AIContentGenerationJob.status.in_(
                [AIGenerationJobStatus.QUEUED, AIGenerationJobStatus.RUNNING]
            )
        )
    ).scalars()
    active_jobs: dict[str, AIContentGenerationJob] = {}
    for row in rows:
        metadata = row.metadata_json or {}
        if metadata.get("source") != "content_readiness_backfill":
            continue
        signature = metadata.get("deficitSignature")
        if not isinstance(signature, str) or not signature:
            continue
        active_jobs[signature] = row
    return active_jobs


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
