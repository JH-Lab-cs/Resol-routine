from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import is_canonical_type_tag_for_skill
from app.core.policies import (
    MOCK_ASSEMBLY_DIFFICULTY_HARD_TOLERANCE,
    MOCK_ASSEMBLY_DIFFICULTY_WARNING_TOLERANCE,
    MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN,
    MOCK_ASSEMBLY_TRACE_MAX_REJECTED_IDS,
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
from app.models.mock_assembly_job import MockAssemblyJob
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.mock_exam_revision_item import MockExamRevisionItem
from app.schemas.mock_assembly import (
    MockAssemblyFailureCode,
    MockAssemblyJobCreateRequest,
    MockAssemblyJobResponse,
    default_difficulty_profile_for_track,
)
from app.services.audit_service import append_audit_log


@dataclass(frozen=True, slots=True)
class AssemblyCandidate:
    question_id: UUID
    unit_id: UUID
    unit_revision_id: UUID
    question_code: str
    skill: Skill
    type_tag: str
    difficulty: int
    unit_score: str
    question_score: str


@dataclass(frozen=True, slots=True)
class AssemblySelection:
    candidates: list[AssemblyCandidate]
    rejected: list[dict[str, str]]


class AssemblyError(Exception):
    def __init__(self, *, code: MockAssemblyFailureCode, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def create_mock_assembly_job(
    db: Session,
    *,
    payload: MockAssemblyJobCreateRequest,
) -> MockAssemblyJobResponse:
    target_profile = (
        {
            "minAverage": payload.target_difficulty_profile.min_average,
            "maxAverage": payload.target_difficulty_profile.max_average,
        }
        if payload.target_difficulty_profile is not None
        else default_difficulty_profile_for_track(payload.track)
    )
    seed = payload.seed_override or _default_seed(
        exam_type=payload.exam_type,
        track=payload.track,
        period_key=payload.period_key,
    )

    job = MockAssemblyJob(
        status=AIGenerationJobStatus.RUNNING,
        exam_type=payload.exam_type,
        track=payload.track,
        period_key=payload.period_key,
        seed=seed,
        dry_run=payload.dry_run,
        force_rebuild=payload.force_rebuild,
        target_difficulty_profile_json=target_profile,
        candidate_pool_counts_json={},
        summary_json={},
        constraint_summary_json={},
        warnings_json=[],
        assembly_trace_json={},
        failure_code=None,
        failure_message=None,
        produced_mock_exam_id=None,
        produced_mock_exam_revision_id=None,
        completed_at=None,
    )
    db.add(job)
    db.flush()

    candidate_counts: dict[str, object] = {}
    warnings_json: list[str] = []
    constraint_summary_value: dict[str, object] = {}
    trace_json: dict[str, object] = {}

    try:
        candidate_pool = _load_candidate_pool(db, track=payload.track, seed=seed)
        candidate_counts = _build_candidate_pool_counts(candidate_pool)
        job.candidate_pool_counts_json = candidate_counts

        selections = _select_candidates(exam_type=payload.exam_type, candidate_pool=candidate_pool)

        summary_json = _build_selection_summary(
            exam_type=payload.exam_type,
            selection=selections,
            target_profile=target_profile,
        )
        warnings_value = summary_json.get("warnings")
        if not isinstance(warnings_value, list):
            raise AssemblyError(
                code=MockAssemblyFailureCode.ASSEMBLY_TRACE_PERSIST_FAILED,
                message="assembly_summary_missing_warnings",
            )
        warnings_json = [str(item) for item in warnings_value]

        constraint_summary_value = summary_json.get("constraintSummary")
        if not isinstance(constraint_summary_value, dict):
            raise AssemblyError(
                code=MockAssemblyFailureCode.ASSEMBLY_TRACE_PERSIST_FAILED,
                message="assembly_summary_missing_constraint_summary",
            )

        trace_json = _build_trace_json(
            job_id=job.id,
            payload=payload,
            seed=seed,
            candidate_pool_counts=candidate_counts,
            selection=selections,
            warnings=warnings_json,
            constraint_summary=constraint_summary_value,
        )

        hard_constraint_failed = bool(summary_json.get("hardConstraintFailed"))
        if hard_constraint_failed:
            _finalize_job_failure(
                job,
                code=MockAssemblyFailureCode.ASSEMBLY_CONSTRAINT_FAILED,
                message="Selected candidates violate hard difficulty constraints.",
                summary_json=summary_json,
                constraint_summary_json=constraint_summary_value,
                warnings=warnings_json,
                candidate_pool_counts=candidate_counts,
                trace_json=trace_json,
            )
            db.flush()
            return _to_job_response(job)

        produced_exam_id: UUID | None = None
        produced_revision_id: UUID | None = None
        if not payload.dry_run:
            try:
                with db.begin_nested():
                    produced_exam_id, produced_revision_id = _persist_mock_exam_revision_draft(
                        db,
                        payload=payload,
                        selection=selections,
                        trace_json=trace_json,
                    )
            except AssemblyError:
                raise
            except Exception as exc:
                raise AssemblyError(
                    code=MockAssemblyFailureCode.REVISION_PERSIST_FAILED,
                    message=str(exc),
                ) from exc

        job.status = AIGenerationJobStatus.SUCCEEDED
        job.summary_json = summary_json
        job.constraint_summary_json = constraint_summary_value
        job.warnings_json = warnings_json
        job.assembly_trace_json = trace_json
        job.failure_code = None
        job.failure_message = None
        job.produced_mock_exam_id = produced_exam_id
        job.produced_mock_exam_revision_id = produced_revision_id
        job.completed_at = datetime.now(UTC)

        append_audit_log(
            db,
            action="mock_exam_assembly_succeeded",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "exam_type": payload.exam_type.value,
                "track": payload.track.value,
                "period_key": payload.period_key,
                "dry_run": payload.dry_run,
                "produced_mock_exam_id": (
                    str(produced_exam_id) if produced_exam_id is not None else None
                ),
                "produced_mock_exam_revision_id": (
                    str(produced_revision_id) if produced_revision_id is not None else None
                ),
            },
        )
        db.flush()
    except AssemblyError as exc:
        failure_trace_json = trace_json or _build_failure_trace_json(
            job_id=job.id,
            payload=payload,
            seed=seed,
            candidate_pool_counts=candidate_counts,
            warnings=warnings_json,
            constraint_summary=constraint_summary_value,
        )
        _finalize_job_failure(
            job,
            code=exc.code,
            message=exc.message,
            summary_json={"status": "failed", "failureCode": exc.code.value},
            constraint_summary_json=constraint_summary_value,
            warnings=warnings_json,
            candidate_pool_counts=candidate_counts,
            trace_json=failure_trace_json,
        )
        db.flush()
    except Exception as exc:  # pragma: no cover - defensive fallback
        failure_trace_json = trace_json or _build_failure_trace_json(
            job_id=job.id,
            payload=payload,
            seed=seed,
            candidate_pool_counts=candidate_counts,
            warnings=warnings_json,
            constraint_summary=constraint_summary_value,
        )
        _finalize_job_failure(
            job,
            code=MockAssemblyFailureCode.REVISION_PERSIST_FAILED,
            message=str(exc),
            summary_json={
                "status": "failed",
                "failureCode": MockAssemblyFailureCode.REVISION_PERSIST_FAILED.value,
            },
            constraint_summary_json=constraint_summary_value,
            warnings=warnings_json,
            candidate_pool_counts=candidate_counts,
            trace_json=failure_trace_json,
        )
        db.flush()

    return _to_job_response(job)


def get_mock_assembly_job(db: Session, *, job_id: UUID) -> MockAssemblyJobResponse:
    job = db.get(MockAssemblyJob, job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="mock_assembly_job_not_found",
        )
    return _to_job_response(job)


def _default_seed(*, exam_type: MockExamType, track: Track, period_key: str) -> str:
    return f"{exam_type.value}|{period_key}|{track.value}"


def _expected_counts(*, exam_type: MockExamType) -> tuple[int, int]:
    if exam_type == MockExamType.WEEKLY:
        return MOCK_EXAM_WEEKLY_LISTENING_COUNT, MOCK_EXAM_WEEKLY_READING_COUNT
    return MOCK_EXAM_MONTHLY_LISTENING_COUNT, MOCK_EXAM_MONTHLY_READING_COUNT


def _required_type_diversity(*, exam_type: MockExamType, skill: Skill) -> int:
    if exam_type == MockExamType.WEEKLY:
        if skill == Skill.LISTENING:
            return MOCK_ASSEMBLY_WEEKLY_LISTENING_TYPE_DIVERSITY_MIN
        return MOCK_ASSEMBLY_WEEKLY_READING_TYPE_DIVERSITY_MIN

    if skill == Skill.LISTENING:
        return MOCK_ASSEMBLY_MONTHLY_LISTENING_TYPE_DIVERSITY_MIN
    return MOCK_ASSEMBLY_MONTHLY_READING_TYPE_DIVERSITY_MIN


def _load_candidate_pool(
    db: Session,
    *,
    track: Track,
    seed: str,
) -> list[AssemblyCandidate]:
    rows = db.execute(
        select(ContentQuestion, ContentUnitRevision, ContentUnit)
        .join(
            ContentUnitRevision,
            ContentQuestion.content_unit_revision_id == ContentUnitRevision.id,
        )
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnit.track == track,
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
            ContentUnitRevision.validator_version.is_not(None),
            ContentUnitRevision.validated_at.is_not(None),
            ContentUnitRevision.reviewer_identity.is_not(None),
            ContentUnitRevision.reviewed_at.is_not(None),
        )
    ).all()

    candidates: list[AssemblyCandidate] = []
    for question, revision, unit in rows:
        metadata = question.metadata_json if isinstance(question.metadata_json, dict) else {}
        raw_type_tag = metadata.get("typeTag")
        raw_difficulty = metadata.get("difficulty")
        if not isinstance(raw_type_tag, str):
            continue
        if not isinstance(raw_difficulty, (int, float, str)):
            continue

        type_tag = raw_type_tag.strip().upper()
        if not is_canonical_type_tag_for_skill(skill=unit.skill.value, type_tag=type_tag):
            continue

        try:
            difficulty = int(raw_difficulty)
        except (TypeError, ValueError):
            continue
        if difficulty < 1 or difficulty > 5:
            continue

        unit_id_str = str(unit.id)
        question_id_str = str(question.id)
        unit_score = hashlib.sha256(f"{seed}|{unit_id_str}".encode()).hexdigest()
        question_score = hashlib.sha256(
            f"{seed}|{unit_id_str}|{question_id_str}".encode()
        ).hexdigest()

        candidates.append(
            AssemblyCandidate(
                question_id=question.id,
                unit_id=unit.id,
                unit_revision_id=revision.id,
                question_code=question.question_code,
                skill=unit.skill,
                type_tag=type_tag,
                difficulty=difficulty,
                unit_score=unit_score,
                question_score=question_score,
            )
        )

    return sorted(
        candidates,
        key=lambda candidate: (
            candidate.unit_score,
            str(candidate.unit_id),
            candidate.question_score,
            str(candidate.question_id),
        ),
    )


def _build_candidate_pool_counts(candidates: list[AssemblyCandidate]) -> dict[str, object]:
    listening_total = 0
    reading_total = 0
    listening_by_type: dict[str, int] = {}
    reading_by_type: dict[str, int] = {}
    listening_by_difficulty: dict[str, int] = {}
    reading_by_difficulty: dict[str, int] = {}

    for candidate in candidates:
        difficulty_key = str(candidate.difficulty)
        if candidate.skill == Skill.LISTENING:
            listening_total += 1
            listening_by_type[candidate.type_tag] = listening_by_type.get(candidate.type_tag, 0) + 1
            listening_by_difficulty[difficulty_key] = (
                listening_by_difficulty.get(difficulty_key, 0) + 1
            )
        else:
            reading_total += 1
            reading_by_type[candidate.type_tag] = reading_by_type.get(candidate.type_tag, 0) + 1
            reading_by_difficulty[difficulty_key] = (
                reading_by_difficulty.get(difficulty_key, 0) + 1
            )

    return {
        "listening": {
            "total": listening_total,
            "byTypeTag": listening_by_type,
            "byDifficulty": listening_by_difficulty,
        },
        "reading": {
            "total": reading_total,
            "byTypeTag": reading_by_type,
            "byDifficulty": reading_by_difficulty,
        },
    }


def _select_candidates(
    *,
    exam_type: MockExamType,
    candidate_pool: list[AssemblyCandidate],
) -> AssemblySelection:
    listening_required, reading_required = _expected_counts(exam_type=exam_type)

    listening_candidates = [
        candidate for candidate in candidate_pool if candidate.skill == Skill.LISTENING
    ]
    reading_candidates = [
        candidate for candidate in candidate_pool if candidate.skill == Skill.READING
    ]

    listening_unique_units = {candidate.unit_id for candidate in listening_candidates}
    reading_unique_units = {candidate.unit_id for candidate in reading_candidates}

    listening_shortage = len(listening_unique_units) < listening_required
    reading_shortage = len(reading_unique_units) < reading_required
    if listening_shortage and reading_shortage:
        raise AssemblyError(
            code=MockAssemblyFailureCode.INSUFFICIENT_PUBLISHED_CONTENT,
            message="Not enough published listening and reading candidates to assemble the exam.",
        )
    if listening_shortage:
        raise AssemblyError(
            code=MockAssemblyFailureCode.INSUFFICIENT_LISTENING_CONTENT,
            message="Not enough published listening candidates to assemble the exam.",
        )
    if reading_shortage:
        raise AssemblyError(
            code=MockAssemblyFailureCode.INSUFFICIENT_READING_CONTENT,
            message="Not enough published reading candidates to assemble the exam.",
        )

    listening_selection = _select_for_skill(
        candidates=listening_candidates,
        required_count=listening_required,
        type_diversity_min=_required_type_diversity(exam_type=exam_type, skill=Skill.LISTENING),
    )
    reading_selection = _select_for_skill(
        candidates=reading_candidates,
        required_count=reading_required,
        type_diversity_min=_required_type_diversity(exam_type=exam_type, skill=Skill.READING),
    )

    combined = listening_selection.candidates + reading_selection.candidates
    rejected = (
        listening_selection.rejected + reading_selection.rejected
    )[:MOCK_ASSEMBLY_TRACE_MAX_REJECTED_IDS]
    return AssemblySelection(candidates=combined, rejected=rejected)


def _select_for_skill(
    *,
    candidates: list[AssemblyCandidate],
    required_count: int,
    type_diversity_min: int,
) -> AssemblySelection:
    available_types = {candidate.type_tag for candidate in candidates}
    if len(available_types) < type_diversity_min:
        raise AssemblyError(
            code=MockAssemblyFailureCode.INSUFFICIENT_TYPE_DIVERSITY,
            message="Published candidate pool does not satisfy the minimum type diversity.",
        )

    selected: list[AssemblyCandidate] = []
    selected_questions: set[UUID] = set()
    selected_units: set[UUID] = set()
    selected_types: set[str] = set()
    rejected: list[dict[str, str]] = []

    for candidate in candidates:
        if len(selected_types) >= type_diversity_min:
            break
        if candidate.type_tag in selected_types:
            continue
        if candidate.question_id in selected_questions:
            continue
        if candidate.unit_id in selected_units:
            continue

        selected.append(candidate)
        selected_questions.add(candidate.question_id)
        selected_units.add(candidate.unit_id)
        selected_types.add(candidate.type_tag)

    if len(selected_types) < type_diversity_min:
        raise AssemblyError(
            code=MockAssemblyFailureCode.INSUFFICIENT_TYPE_DIVERSITY,
            message="Unable to pick deterministic seed candidates with required type diversity.",
        )

    for candidate in candidates:
        if len(selected) >= required_count:
            break

        if candidate.question_id in selected_questions:
            if len(rejected) < MOCK_ASSEMBLY_TRACE_MAX_REJECTED_IDS:
                rejected.append(
                    {
                        "questionId": str(candidate.question_id),
                        "reason": "duplicate_question",
                    }
                )
            continue

        if candidate.unit_id in selected_units:
            if len(rejected) < MOCK_ASSEMBLY_TRACE_MAX_REJECTED_IDS:
                rejected.append(
                    {
                        "questionId": str(candidate.question_id),
                        "reason": "duplicate_content_unit",
                    }
                )
            continue

        selected.append(candidate)
        selected_questions.add(candidate.question_id)
        selected_units.add(candidate.unit_id)
        selected_types.add(candidate.type_tag)

    if len(selected) < required_count:
        code = (
            MockAssemblyFailureCode.INSUFFICIENT_LISTENING_CONTENT
            if selected and selected[0].skill == Skill.LISTENING
            else MockAssemblyFailureCode.INSUFFICIENT_READING_CONTENT
        )
        message = (
            "Not enough unique listening units after deterministic filtering."
            if code == MockAssemblyFailureCode.INSUFFICIENT_LISTENING_CONTENT
            else "Not enough unique reading units after deterministic filtering."
        )
        raise AssemblyError(code=code, message=message)

    return AssemblySelection(candidates=selected, rejected=rejected)


def _build_selection_summary(
    *,
    exam_type: MockExamType,
    selection: AssemblySelection,
    target_profile: dict[str, float],
) -> dict[str, object]:
    selected_listening = [
        candidate for candidate in selection.candidates if candidate.skill == Skill.LISTENING
    ]
    selected_reading = [
        candidate for candidate in selection.candidates if candidate.skill == Skill.READING
    ]
    total_selected = len(selection.candidates)

    average_difficulty = (
        sum(candidate.difficulty for candidate in selection.candidates) / total_selected
        if total_selected > 0
        else 0.0
    )

    min_avg = float(target_profile["minAverage"])
    max_avg = float(target_profile["maxAverage"])
    warning_codes: list[str] = []
    hard_failed = False

    if average_difficulty < min_avg:
        delta = min_avg - average_difficulty
        if delta > MOCK_ASSEMBLY_DIFFICULTY_HARD_TOLERANCE:
            hard_failed = True
        elif delta > MOCK_ASSEMBLY_DIFFICULTY_WARNING_TOLERANCE:
            warning_codes.append("difficulty_below_target")
    elif average_difficulty > max_avg:
        delta = average_difficulty - max_avg
        if delta > MOCK_ASSEMBLY_DIFFICULTY_HARD_TOLERANCE:
            hard_failed = True
        elif delta > MOCK_ASSEMBLY_DIFFICULTY_WARNING_TOLERANCE:
            warning_codes.append("difficulty_above_target")

    listening_types = sorted({candidate.type_tag for candidate in selected_listening})
    reading_types = sorted({candidate.type_tag for candidate in selected_reading})

    expected_listening, expected_reading = _expected_counts(exam_type=exam_type)
    constraint_summary = {
        "requiredCounts": {
            "listening": expected_listening,
            "reading": expected_reading,
            "total": expected_listening + expected_reading,
        },
        "selectedCounts": {
            "listening": len(selected_listening),
            "reading": len(selected_reading),
            "total": total_selected,
        },
        "selectedTypeDiversity": {
            "listening": {
                "count": len(listening_types),
                "typeTags": listening_types,
            },
            "reading": {
                "count": len(reading_types),
                "typeTags": reading_types,
            },
        },
        "difficulty": {
            "average": round(average_difficulty, 4),
            "target": {
                "minAverage": min_avg,
                "maxAverage": max_avg,
            },
        },
    }

    return {
        "status": "succeeded",
        "accepted": total_selected,
        "listeningCount": len(selected_listening),
        "readingCount": len(selected_reading),
        "warnings": warning_codes,
        "hardConstraintFailed": hard_failed,
        "constraintSummary": constraint_summary,
    }


def _build_trace_json(
    *,
    job_id: UUID,
    payload: MockAssemblyJobCreateRequest,
    seed: str,
    candidate_pool_counts: dict[str, object],
    selection: AssemblySelection,
    warnings: list[str],
    constraint_summary: dict[str, object],
) -> dict[str, object]:
    selected_candidates = selection.candidates

    return {
        "assemblyJobId": str(job_id),
        "examType": payload.exam_type.value,
        "track": payload.track.value,
        "periodKey": payload.period_key,
        "seed": seed,
        "candidatePoolCounts": candidate_pool_counts,
        "selectedUnitIds": [str(candidate.unit_id) for candidate in selected_candidates],
        "selectedQuestionIds": [str(candidate.question_id) for candidate in selected_candidates],
        "selectedItems": [
            {
                "contentUnitId": str(candidate.unit_id),
                "contentUnitRevisionId": str(candidate.unit_revision_id),
                "contentQuestionId": str(candidate.question_id),
                "questionCode": candidate.question_code,
                "skill": candidate.skill.value,
                "typeTag": candidate.type_tag,
                "difficulty": candidate.difficulty,
            }
            for candidate in selected_candidates
        ],
        "rejectedUnitIds": selection.rejected,
        "warnings": warnings,
        "constraintSummary": constraint_summary,
    }


def _build_failure_trace_json(
    *,
    job_id: UUID,
    payload: MockAssemblyJobCreateRequest,
    seed: str,
    candidate_pool_counts: dict[str, object],
    warnings: list[str],
    constraint_summary: dict[str, object],
) -> dict[str, object]:
    return {
        "assemblyJobId": str(job_id),
        "examType": payload.exam_type.value,
        "track": payload.track.value,
        "periodKey": payload.period_key,
        "seed": seed,
        "candidatePoolCounts": candidate_pool_counts,
        "selectedUnitIds": [],
        "selectedQuestionIds": [],
        "selectedItems": [],
        "rejectedUnitIds": [],
        "warnings": warnings,
        "constraintSummary": constraint_summary,
    }


def _select_mock_exam_for_update(
    db: Session,
    *,
    payload: MockAssemblyJobCreateRequest,
) -> MockExam | None:
    return (
        db.query(MockExam)
        .filter(
            MockExam.exam_type == payload.exam_type,
            MockExam.track == payload.track,
            MockExam.period_key == payload.period_key,
        )
        .with_for_update()
        .one_or_none()
    )


def _persist_mock_exam_revision_draft(
    db: Session,
    *,
    payload: MockAssemblyJobCreateRequest,
    selection: AssemblySelection,
    trace_json: dict[str, object],
) -> tuple[UUID, UUID]:
    exam = _select_mock_exam_for_update(db, payload=payload)

    if exam is None:
        try:
            with db.begin_nested():
                exam = MockExam(
                    exam_type=payload.exam_type,
                    track=payload.track,
                    period_key=payload.period_key,
                    external_id=None,
                    slug=None,
                    lifecycle_status=ContentLifecycleStatus.DRAFT,
                    published_revision_id=None,
                )
                db.add(exam)
                db.flush()
        except IntegrityError:
            exam = _select_mock_exam_for_update(db, payload=payload)
            if exam is None:
                raise AssemblyError(
                    code=MockAssemblyFailureCode.REVISION_PERSIST_FAILED,
                    message="mock_exam_creation_conflict_recovery_failed",
                ) from None

    if exam is None:  # pragma: no cover - defensive guard
        raise AssemblyError(
            code=MockAssemblyFailureCode.REVISION_PERSIST_FAILED,
            message="mock_exam_creation_unresolved",
        )

    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        raise AssemblyError(
            code=MockAssemblyFailureCode.ASSEMBLY_CONSTRAINT_FAILED,
            message="Mock exam is archived and cannot accept a new draft revision.",
        )

    existing_draft_revision_ids = db.execute(
        select(MockExamRevision.id)
        .where(
            MockExamRevision.mock_exam_id == exam.id,
            MockExamRevision.lifecycle_status == ContentLifecycleStatus.DRAFT,
        )
        .order_by(MockExamRevision.revision_no.desc(), MockExamRevision.id.desc())
    ).scalars().all()

    if existing_draft_revision_ids and not payload.force_rebuild:
        raise AssemblyError(
            code=MockAssemblyFailureCode.ASSEMBLY_ALREADY_EXISTS,
            message="A draft revision already exists for this exam target.",
        )
    if existing_draft_revision_ids and payload.force_rebuild:
        db.execute(
            update(MockExamRevision)
            .where(
                MockExamRevision.mock_exam_id == exam.id,
                MockExamRevision.lifecycle_status == ContentLifecycleStatus.DRAFT,
            )
            .values(lifecycle_status=ContentLifecycleStatus.ARCHIVED)
        )

    max_revision_no = db.execute(
        select(func.max(MockExamRevision.revision_no)).where(
            MockExamRevision.mock_exam_id == exam.id
        )
    ).scalar_one()
    next_revision_no = (int(max_revision_no) if max_revision_no is not None else 0) + 1

    revision = MockExamRevision(
        mock_exam_id=exam.id,
        revision_no=next_revision_no,
        title=f"{payload.exam_type.value.title()} Mock {payload.track.value} {payload.period_key}",
        instructions="Solve each item based on the provided passage or transcript.",
        generator_version="mock-assembly-v1",
        validator_version=None,
        validated_at=None,
        reviewer_identity=None,
        reviewed_at=None,
        metadata_json={
            "mockAssembly": trace_json,
            "source": "mock-assembly",
            "mockAssemblyRebuild": {
                "forceRebuild": payload.force_rebuild,
                "rebuildReason": "force_rebuild" if payload.force_rebuild else "initial_build",
                "archivedOldRevisionIds": [
                    str(revision_id) for revision_id in existing_draft_revision_ids
                ],
            },
        },
        lifecycle_status=ContentLifecycleStatus.DRAFT,
        published_at=None,
    )
    db.add(revision)
    db.flush()

    for index, candidate in enumerate(selection.candidates, start=1):
        db.add(
            MockExamRevisionItem(
                mock_exam_revision_id=revision.id,
                order_index=index,
                content_unit_revision_id=candidate.unit_revision_id,
                content_question_id=candidate.question_id,
                question_code_snapshot=candidate.question_code,
                skill_snapshot=candidate.skill,
            )
        )

    db.flush()

    append_audit_log(
        db,
        action="mock_exam_assembly_draft_created",
        actor_user_id=None,
        target_user_id=None,
        details={
            "mock_exam_id": str(exam.id),
            "mock_exam_revision_id": str(revision.id),
            "exam_type": payload.exam_type.value,
            "track": payload.track.value,
            "period_key": payload.period_key,
            "force_rebuild": payload.force_rebuild,
            "rebuild_reason": "force_rebuild" if payload.force_rebuild else "initial_build",
            "archived_old_revision_ids": [
                str(revision_id) for revision_id in existing_draft_revision_ids
            ],
        },
    )

    return exam.id, revision.id


def _finalize_job_failure(
    job: MockAssemblyJob,
    *,
    code: MockAssemblyFailureCode,
    message: str,
    summary_json: dict[str, object],
    constraint_summary_json: dict[str, object],
    warnings: list[str],
    candidate_pool_counts: dict[str, object],
    trace_json: dict[str, object],
) -> None:
    job.status = AIGenerationJobStatus.FAILED
    job.failure_code = code.value
    job.failure_message = message[:2000]
    job.summary_json = summary_json
    job.constraint_summary_json = constraint_summary_json
    job.warnings_json = warnings
    job.candidate_pool_counts_json = candidate_pool_counts
    job.assembly_trace_json = trace_json
    job.produced_mock_exam_id = None
    job.produced_mock_exam_revision_id = None
    job.completed_at = datetime.now(UTC)


def _to_job_response(job: MockAssemblyJob) -> MockAssemblyJobResponse:
    return MockAssemblyJobResponse(
        id=job.id,
        status=job.status,
        exam_type=job.exam_type,
        track=job.track,
        period_key=job.period_key,
        seed=job.seed,
        dry_run=job.dry_run,
        force_rebuild=job.force_rebuild,
        target_difficulty_profile_json=job.target_difficulty_profile_json,
        candidate_pool_counts_json=job.candidate_pool_counts_json,
        summary_json=job.summary_json,
        constraint_summary_json=job.constraint_summary_json,
        warnings_json=job.warnings_json,
        failure_code=job.failure_code,
        failure_message=job.failure_message,
        produced_mock_exam_id=job.produced_mock_exam_id,
        produced_mock_exam_revision_id=job.produced_mock_exam_revision_id,
        assembly_trace_json=job.assembly_trace_json,
        created_at=job.created_at,
        updated_at=job.updated_at,
        completed_at=job.completed_at,
    )
