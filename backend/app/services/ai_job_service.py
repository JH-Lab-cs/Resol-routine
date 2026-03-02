from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
import logging
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session

from app.core.policies import (
    AI_ARTIFACT_RETENTION_DAYS_MAX,
    AI_JOB_MAX_ATTEMPTS,
    AI_JOB_RETRY_BACKOFF_BASE_SECONDS,
    AI_JOB_RETRY_BACKOFF_MAX_SECONDS,
    AI_MOCK_EXAM_CANDIDATE_LIMIT_DEFAULT,
    MOCK_EXAM_MONTHLY_LISTENING_COUNT,
    MOCK_EXAM_MONTHLY_READING_COUNT,
    MOCK_EXAM_WEEKLY_LISTENING_COUNT,
    MOCK_EXAM_WEEKLY_READING_COUNT,
)
from app.db.session import schedule_ai_generation_job_after_commit
from app.models.ai_generation_job import AIGenerationJob
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import (
    AIGenerationJobStatus,
    AIGenerationJobType,
    MockExamType,
    Skill,
)
from app.models.mock_exam import MockExam
from app.schemas.ai_jobs import (
    AIArtifactDownloadUrlResponse,
    AIArtifactKind,
    AIArtifactPurgeRequest,
    AIArtifactPurgeResponse,
    AIJobListQuery,
    AIJobListResponse,
    AIJobResponse,
    AIMockExamJobCreateRequest,
)
from app.schemas.mock_exam import MockExamRevisionCreateRequest
from app.services.ai_artifact_service import (
    ArtifactStoreError,
    get_ai_artifact_store,
    issue_artifact_download_url,
)
from app.services.audit_service import append_audit_log
from app.services.ai_provider import (
    AIProviderError,
    CandidateQuestion,
    MockExamGenerationContext,
    ProviderGenerationResult,
    ProviderStructuredItem,
    build_mock_exam_generation_provider,
)
from app.services.mock_exam_internal_service import (
    AIGeneratedRevisionSelectionItem,
    create_ai_generated_mock_exam_revision_draft,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class AIJobExecutionResult:
    job_id: UUID
    status: AIGenerationJobStatus
    produced_mock_exam_revision_id: UUID | None
    error_code: str | None
    retry_after_seconds: int | None


def create_mock_exam_draft_generation_job(
    db: Session,
    *,
    payload: AIMockExamJobCreateRequest,
) -> AIJobResponse:
    exam = db.get(MockExam, payload.mock_exam_id)
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="mock_exam_not_found")

    existing = db.execute(
        select(AIGenerationJob).where(
            AIGenerationJob.job_type == AIGenerationJobType.MOCK_EXAM_REVISION_DRAFT_GENERATION,
            AIGenerationJob.request_id == payload.request_id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return _to_job_response(existing)

    job = AIGenerationJob(
        job_type=AIGenerationJobType.MOCK_EXAM_REVISION_DRAFT_GENERATION,
        request_id=payload.request_id,
        status=AIGenerationJobStatus.QUEUED,
        target_mock_exam_id=payload.mock_exam_id,
        notes=payload.notes,
        generator_version=payload.generator_version,
        candidate_limit=payload.candidate_limit,
        metadata_json=payload.metadata_json,
    )
    db.add(job)
    db.flush()

    schedule_ai_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def list_ai_jobs(db: Session, *, query: AIJobListQuery) -> AIJobListResponse:
    stmt = select(AIGenerationJob)

    if query.job_type is not None:
        stmt = stmt.where(AIGenerationJob.job_type == query.job_type)
    if query.status is not None:
        stmt = stmt.where(AIGenerationJob.status == query.status)
    if query.mock_exam_id is not None:
        stmt = stmt.where(AIGenerationJob.target_mock_exam_id == query.mock_exam_id)

    total = db.execute(select(func.count()).select_from(stmt.subquery())).scalar_one()
    offset = (query.page - 1) * query.page_size
    rows = db.execute(
        stmt.order_by(
            AIGenerationJob.queued_at.desc(),
            AIGenerationJob.id.desc(),
        )
        .offset(offset)
        .limit(query.page_size)
    ).scalars().all()

    return AIJobListResponse(
        items=[_to_job_response(row) for row in rows],
        total=int(total),
        page=query.page,
        page_size=query.page_size,
    )


def get_ai_job(db: Session, *, job_id: UUID) -> AIJobResponse:
    job = db.get(AIGenerationJob, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ai_job_not_found")
    return _to_job_response(job)


def retry_ai_job(db: Session, *, job_id: UUID) -> AIJobResponse:
    job = _get_job_for_update(db, job_id=job_id)

    if job.status == AIGenerationJobStatus.RUNNING:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ai_job_already_running")

    if job.status == AIGenerationJobStatus.SUCCEEDED:
        return _to_job_response(job)

    job.status = AIGenerationJobStatus.QUEUED
    job.queued_at = datetime.now(UTC)
    job.started_at = None
    job.completed_at = None
    job.next_retry_at = None
    job.dead_lettered_at = None
    job.last_error_code = None
    job.last_error_message = None
    job.last_error_transient = None
    db.flush()

    schedule_ai_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def issue_ai_job_artifact_download_url(
    db: Session,
    *,
    job_id: UUID,
    artifact_kind: str,
) -> AIArtifactDownloadUrlResponse:
    job = db.get(AIGenerationJob, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ai_job_not_found")

    object_key = _resolve_artifact_object_key(job=job, artifact_kind=artifact_kind)
    result = issue_artifact_download_url(object_key=object_key)
    append_audit_log(
        db,
        action="ai_job_artifact_download_url_issued",
        actor_user_id=None,
        target_user_id=None,
        details={
            "job_id": str(job.id),
            "artifact_kind": artifact_kind,
            "object_key": object_key,
        },
    )

    return AIArtifactDownloadUrlResponse(
        job_id=job.id,
        artifact_kind=artifact_kind,
        object_key=result.object_key,
        download_url=result.download_url,
        expires_in_seconds=result.expires_in_seconds,
        expires_at=result.expires_at,
    )


def purge_ai_job_artifacts(
    db: Session,
    *,
    payload: AIArtifactPurgeRequest | None = None,
) -> AIArtifactPurgeResponse:
    requested_days = (
        payload.retention_days
        if payload is not None and payload.retention_days is not None
        else None
    )
    retention_days = requested_days
    if retention_days is None:
        from app.core.config import settings

        retention_days = settings.ai_artifact_retention_days
    if retention_days <= 0 or retention_days > AI_ARTIFACT_RETENTION_DAYS_MAX:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="invalid_retention_days")

    cutoff = datetime.now(UTC) - timedelta(days=retention_days)
    rows = db.execute(
        select(AIGenerationJob)
        .where(
            AIGenerationJob.completed_at.is_not(None),
            AIGenerationJob.completed_at < cutoff,
            or_(
                AIGenerationJob.input_artifact_object_key.is_not(None),
                AIGenerationJob.output_artifact_object_key.is_not(None),
                AIGenerationJob.candidate_snapshot_object_key.is_not(None),
            ),
        )
        .order_by(AIGenerationJob.completed_at.asc(), AIGenerationJob.id.asc())
    ).scalars().all()

    store = get_ai_artifact_store()
    purged_jobs = 0
    purged_objects = 0

    for job in rows:
        keys = [
            job.input_artifact_object_key,
            job.output_artifact_object_key,
            job.candidate_snapshot_object_key,
        ]
        valid_keys = [key for key in keys if key is not None]
        if not valid_keys:
            continue

        for key in valid_keys:
            store.delete_object(object_key=key)
            purged_objects += 1

        job.input_artifact_object_key = None
        job.output_artifact_object_key = None
        job.candidate_snapshot_object_key = None
        purged_jobs += 1

        append_audit_log(
            db,
            action="ai_job_artifacts_purged",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "retention_days": retention_days,
                "purged_object_count": len(valid_keys),
            },
        )

    db.flush()
    return AIArtifactPurgeResponse(
        retention_days=retention_days,
        cutoff_before=cutoff,
        purged_job_count=purged_jobs,
        purged_object_count=purged_objects,
    )


def run_mock_exam_draft_generation_job(
    db: Session,
    *,
    job_id: UUID,
) -> AIJobExecutionResult:
    now = datetime.now(UTC)
    retry_ready_condition = or_(
        AIGenerationJob.status == AIGenerationJobStatus.QUEUED,
        and_(
            AIGenerationJob.status == AIGenerationJobStatus.FAILED,
            or_(AIGenerationJob.next_retry_at.is_(None), AIGenerationJob.next_retry_at <= now),
        ),
    )
    claimed_rows = db.execute(
        update(AIGenerationJob)
        .where(
            AIGenerationJob.id == job_id,
            retry_ready_condition,
        )
        .values(
            status=AIGenerationJobStatus.RUNNING,
            started_at=now,
            completed_at=None,
            attempt_count=AIGenerationJob.attempt_count + 1,
            next_retry_at=None,
            last_error_code=None,
            last_error_message=None,
            last_error_transient=None,
        )
    ).rowcount

    if claimed_rows == 0:
        existing = db.get(AIGenerationJob, job_id)
        if existing is None:
            raise ValueError("ai_job_not_found")

        return AIJobExecutionResult(
            job_id=existing.id,
            status=existing.status,
            produced_mock_exam_revision_id=existing.produced_mock_exam_revision_id,
            error_code=existing.last_error_code,
            retry_after_seconds=None,
        )

    job = _get_job_for_update(db, job_id=job_id)

    if job.produced_mock_exam_revision_id is not None:
        job.status = AIGenerationJobStatus.SUCCEEDED
        job.completed_at = datetime.now(UTC)
        job.next_retry_at = None
        job.dead_lettered_at = None
        job.last_error_code = None
        job.last_error_message = None
        job.last_error_transient = None
        db.flush()
        return AIJobExecutionResult(
            job_id=job.id,
            status=job.status,
            produced_mock_exam_revision_id=job.produced_mock_exam_revision_id,
            error_code=None,
            retry_after_seconds=None,
        )

    exam = db.get(MockExam, job.target_mock_exam_id)
    if exam is None:
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code="mock_exam_not_found",
            message="Target mock exam does not exist.",
            transient=False,
        )
        db.flush()
        return AIJobExecutionResult(
            job_id=job.id,
            status=job.status,
            produced_mock_exam_revision_id=None,
            error_code=job.last_error_code,
            retry_after_seconds=retry_after_seconds,
        )

    if exam.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code="mock_exam_archived",
            message="Target mock exam is archived.",
            transient=False,
        )
        db.flush()
        return AIJobExecutionResult(
            job_id=job.id,
            status=job.status,
            produced_mock_exam_revision_id=None,
            error_code=job.last_error_code,
            retry_after_seconds=retry_after_seconds,
        )

    artifact_store = get_ai_artifact_store()

    try:
        candidate_questions = _load_or_create_candidate_snapshot(
            db,
            job=job,
            exam=exam,
            artifact_store=artifact_store,
        )
        provider = build_mock_exam_generation_provider()
        generation_context = MockExamGenerationContext(
            mock_exam_id=exam.id,
            exam_type=exam.exam_type,
            track=exam.track,
            period_key=exam.period_key,
            candidate_questions=candidate_questions,
            candidate_limit=job.candidate_limit or AI_MOCK_EXAM_CANDIDATE_LIMIT_DEFAULT,
            notes=job.notes,
        )
        provider_result = provider.generate_structured_output(context=generation_context)

        job.provider_name = provider_result.provider_name
        job.model_name = provider_result.model_name
        job.prompt_template_version = provider_result.prompt_template_version
        job.input_artifact_object_key = artifact_store.put_text(
            kind=AIArtifactKind.INPUT,
            job_id=job.id,
            body=provider_result.raw_prompt,
            content_type="application/json",
        )
        job.output_artifact_object_key = artifact_store.put_text(
            kind=AIArtifactKind.OUTPUT,
            job_id=job.id,
            body=provider_result.raw_response,
            content_type="application/json",
        )

        selected_items = _validate_and_build_selected_items(
            exam_type=exam.exam_type,
            provider_result=provider_result,
            candidate_questions=candidate_questions,
            generator_version=job.generator_version,
        )

        metadata = _build_generated_revision_metadata(job=job, provider_result=provider_result)
        revision = create_ai_generated_mock_exam_revision_draft(
            db,
            exam_id=exam.id,
            title=provider_result.structured_output.title,
            instructions=provider_result.structured_output.instructions,
            generator_version=job.generator_version,
            metadata_json=metadata,
            selections=selected_items,
        )

        job.produced_mock_exam_revision_id = revision.id
        job.status = AIGenerationJobStatus.SUCCEEDED
        job.completed_at = datetime.now(UTC)
        job.next_retry_at = None
        job.dead_lettered_at = None
        job.last_error_code = None
        job.last_error_message = None
        job.last_error_transient = None
        db.flush()

        logger.info(
            "AI draft generation job succeeded",
            extra={
                "job_id": str(job.id),
                "mock_exam_id": str(job.target_mock_exam_id),
                "produced_mock_exam_revision_id": str(revision.id),
                "attempt_count": job.attempt_count,
            },
        )

        return AIJobExecutionResult(
            job_id=job.id,
            status=job.status,
            produced_mock_exam_revision_id=revision.id,
            error_code=None,
            retry_after_seconds=None,
        )
    except AIProviderError as exc:
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code=exc.code,
            message=exc.message,
            transient=exc.transient,
        )
    except ArtifactStoreError as exc:
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code=exc.code,
            message=exc.message,
            transient=False,
        )
    except HTTPException as exc:
        detail_code = exc.detail if isinstance(exc.detail, str) else "ai_generation_validation_failed"
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code=detail_code,
            message=f"Generation failed: {detail_code}",
            transient=False,
        )
    except Exception as exc:  # pragma: no cover - defensive fallback
        logger.exception(
            "Unexpected AI draft generation worker failure",
            extra={
                "job_id": str(job.id),
                "mock_exam_id": str(job.target_mock_exam_id),
            },
        )
        retry_after_seconds = _mark_job_failure(
            db,
            job,
            code="ai_generation_unexpected_error",
            message=str(exc),
            transient=True,
        )

    db.flush()

    logger.info(
        "AI draft generation job failed",
        extra={
            "job_id": str(job.id),
            "mock_exam_id": str(job.target_mock_exam_id),
            "error_code": job.last_error_code,
            "attempt_count": job.attempt_count,
        },
    )

    return AIJobExecutionResult(
        job_id=job.id,
        status=job.status,
        produced_mock_exam_revision_id=job.produced_mock_exam_revision_id,
        error_code=job.last_error_code,
        retry_after_seconds=retry_after_seconds,
    )


def _load_or_create_candidate_snapshot(
    db: Session,
    *,
    job: AIGenerationJob,
    exam: MockExam,
    artifact_store: Any,
) -> list[CandidateQuestion]:
    if job.candidate_snapshot_object_key is not None:
        snapshot_payload = artifact_store.get_json(object_key=job.candidate_snapshot_object_key)
        return _candidate_questions_from_snapshot(snapshot_payload)

    candidate_limit = job.candidate_limit or AI_MOCK_EXAM_CANDIDATE_LIMIT_DEFAULT
    rows = db.execute(
        select(ContentQuestion, ContentUnitRevision, ContentUnit)
        .join(ContentUnitRevision, ContentQuestion.content_unit_revision_id == ContentUnitRevision.id)
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnit.track == exam.track,
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
        )
        .order_by(
            ContentUnit.external_id.asc(),
            ContentUnitRevision.revision_no.asc(),
            ContentQuestion.order_index.asc(),
            ContentQuestion.question_code.asc(),
            ContentQuestion.id.asc(),
        )
        .limit(candidate_limit)
    ).all()

    candidate_questions = [
        CandidateQuestion(
            content_question_id=question.id,
            content_unit_revision_id=revision.id,
            question_code=question.question_code,
            skill=unit.skill,
            stem=question.stem,
            has_asset=revision.asset_id is not None,
            unit_title=revision.title,
        )
        for question, revision, unit in rows
    ]

    if not candidate_questions:
        raise AIProviderError(
            code="candidate_pool_empty",
            message="No published content candidates found for the target exam.",
            transient=False,
        )

    snapshot_payload: dict[str, object] = {
        "jobId": str(job.id),
        "mockExamId": str(exam.id),
        "examType": exam.exam_type.value,
        "track": exam.track.value,
        "periodKey": exam.period_key,
        "generatedAt": datetime.now(UTC).isoformat(),
        "candidateQuestions": [
            {
                "contentQuestionId": str(item.content_question_id),
                "contentUnitRevisionId": str(item.content_unit_revision_id),
                "questionCode": item.question_code,
                "skill": item.skill.value,
                "stem": item.stem,
                "hasAsset": item.has_asset,
                "unitTitle": item.unit_title,
            }
            for item in candidate_questions
        ],
    }

    job.candidate_snapshot_object_key = artifact_store.put_json(
        kind=AIArtifactKind.CANDIDATE_SNAPSHOT,
        job_id=job.id,
        payload=snapshot_payload,
    )
    db.flush()
    return candidate_questions


def _candidate_questions_from_snapshot(payload: dict[str, object]) -> list[CandidateQuestion]:
    raw_items = payload.get("candidateQuestions")
    if not isinstance(raw_items, list):
        raise ArtifactStoreError(
            code="candidate_snapshot_invalid",
            message="Candidate snapshot does not include a valid candidateQuestions array.",
        )

    parsed: list[CandidateQuestion] = []
    for raw_item in raw_items:
        if not isinstance(raw_item, dict):
            raise ArtifactStoreError(
                code="candidate_snapshot_invalid",
                message="Candidate snapshot contains malformed candidate items.",
            )
        try:
            content_question_id = UUID(str(raw_item["contentQuestionId"]))
            content_unit_revision_id = UUID(str(raw_item["contentUnitRevisionId"]))
            question_code = str(raw_item["questionCode"])
            skill = Skill(str(raw_item["skill"]))
            stem = str(raw_item["stem"])
            has_asset = bool(raw_item.get("hasAsset", False))
            unit_title = raw_item.get("unitTitle")
            if unit_title is not None:
                unit_title = str(unit_title)
        except Exception as exc:
            raise ArtifactStoreError(
                code="candidate_snapshot_invalid",
                message="Candidate snapshot contains invalid field values.",
            ) from exc

        parsed.append(
            CandidateQuestion(
                content_question_id=content_question_id,
                content_unit_revision_id=content_unit_revision_id,
                question_code=question_code,
                skill=skill,
                stem=stem,
                has_asset=has_asset,
                unit_title=unit_title,
            )
        )

    if not parsed:
        raise ArtifactStoreError(
            code="candidate_snapshot_empty",
            message="Candidate snapshot is empty.",
        )
    return parsed


def _validate_and_build_selected_items(
    *,
    exam_type: MockExamType,
    provider_result: ProviderGenerationResult,
    candidate_questions: list[CandidateQuestion],
    generator_version: str,
) -> list[AIGeneratedRevisionSelectionItem]:
    raw_items = provider_result.structured_output.items
    if not raw_items:
        raise AIProviderError(
            code="invalid_generated_output",
            message="Generated output must include at least one item.",
            transient=False,
        )

    candidate_by_question_id: dict[UUID, CandidateQuestion] = {
        candidate.content_question_id: candidate for candidate in candidate_questions
    }

    seen_question_ids: set[UUID] = set()
    expected_indexes = list(range(1, len(raw_items) + 1))
    actual_indexes = [item.order_index for item in raw_items]
    if actual_indexes != expected_indexes:
        raise AIProviderError(
            code="invalid_order_sequence",
            message="Generated output order indexes must be contiguous starting from 1.",
            transient=False,
        )

    selected: list[AIGeneratedRevisionSelectionItem] = []
    listening_count = 0
    reading_count = 0
    schema_items: list[dict[str, object]] = []

    for item in raw_items:
        if item.content_question_id in seen_question_ids:
            raise AIProviderError(
                code="duplicate_content_question_id",
                message="Generated output contains duplicate contentQuestionId.",
                transient=False,
            )
        seen_question_ids.add(item.content_question_id)

        candidate = candidate_by_question_id.get(item.content_question_id)
        if candidate is None:
            raise AIProviderError(
                code="invalid_generated_reference",
                message="Generated output references a question outside the candidate snapshot.",
                transient=False,
            )

        if candidate.skill == Skill.LISTENING:
            listening_count += 1
        else:
            reading_count += 1

        selected.append(
            AIGeneratedRevisionSelectionItem(
                order_index=item.order_index,
                content_question_id=item.content_question_id,
                content_unit_revision_id=candidate.content_unit_revision_id,
            )
        )

        schema_items.append(
            {
                "orderIndex": item.order_index,
                "contentUnitRevisionId": str(candidate.content_unit_revision_id),
                "contentQuestionId": str(candidate.content_question_id),
            }
        )

    expected_listening, expected_reading = _expected_skill_counts(exam_type)
    if listening_count != expected_listening or reading_count != expected_reading:
        raise AIProviderError(
            code="mock_exam_skill_count_mismatch",
            message="Generated output does not satisfy required listening/reading counts.",
            transient=False,
        )

    try:
        MockExamRevisionCreateRequest.model_validate(
            {
                "title": provider_result.structured_output.title,
                "instructions": provider_result.structured_output.instructions,
                "generatorVersion": generator_version,
                "metadata": {"source": "ai-worker"},
                "items": schema_items,
            }
        )
    except ValidationError as exc:
        detail_code = _extract_validation_detail_code(exc)
        raise AIProviderError(
            code=detail_code,
            message="Generated output failed revision schema validation.",
            transient=False,
        ) from exc

    return selected


def _build_generated_revision_metadata(
    *,
    job: AIGenerationJob,
    provider_result: ProviderGenerationResult,
) -> dict[str, object]:
    metadata = dict(job.metadata_json)
    metadata["aiGeneration"] = {
        "jobId": str(job.id),
        "jobType": job.job_type.value,
        "requestId": job.request_id,
        "provider": provider_result.provider_name,
        "model": provider_result.model_name,
        "promptTemplateVersion": provider_result.prompt_template_version,
        "candidateSnapshotObjectKey": job.candidate_snapshot_object_key,
        "inputArtifactObjectKey": job.input_artifact_object_key,
        "outputArtifactObjectKey": job.output_artifact_object_key,
    }
    return metadata


def _resolve_artifact_object_key(*, job: AIGenerationJob, artifact_kind: str) -> str:
    if artifact_kind == AIArtifactKind.INPUT:
        object_key = job.input_artifact_object_key
    elif artifact_kind == AIArtifactKind.OUTPUT:
        object_key = job.output_artifact_object_key
    elif artifact_kind == AIArtifactKind.CANDIDATE_SNAPSHOT:
        object_key = job.candidate_snapshot_object_key
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_artifact_kind")

    if object_key is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ai_job_artifact_not_found")
    return object_key


def _extract_validation_detail_code(error: ValidationError) -> str:
    errors = error.errors()
    if not errors:
        return "invalid_generated_output"

    first_error = errors[0]
    message = first_error.get("msg")
    if isinstance(message, str):
        marker = "Value error, "
        if message.startswith(marker):
            return message[len(marker) :]
    return "invalid_generated_output"


def _mark_job_failure(
    db: Session,
    job: AIGenerationJob,
    *,
    code: str,
    message: str,
    transient: bool,
) -> int | None:
    now = datetime.now(UTC)
    retry_after_seconds: int | None = None
    should_dead_letter = transient and job.attempt_count >= AI_JOB_MAX_ATTEMPTS

    if should_dead_letter:
        job.status = AIGenerationJobStatus.DEAD_LETTER
        job.dead_lettered_at = now
        job.next_retry_at = None
        append_audit_log(
            db,
            action="ai_job_dead_lettered",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "error_code": code,
                "attempt_count": job.attempt_count,
                "transient": transient,
            },
        )
    elif transient:
        retry_after_seconds = min(
            AI_JOB_RETRY_BACKOFF_MAX_SECONDS,
            AI_JOB_RETRY_BACKOFF_BASE_SECONDS * (2 ** max(job.attempt_count - 1, 0)),
        )
        job.status = AIGenerationJobStatus.FAILED
        job.next_retry_at = now + timedelta(seconds=retry_after_seconds)
        job.dead_lettered_at = None
    else:
        job.status = AIGenerationJobStatus.FAILED
        job.next_retry_at = None
        job.dead_lettered_at = None

    job.completed_at = now
    job.last_error_code = code[:64]
    job.last_error_message = message[:2000]
    job.last_error_transient = transient
    return retry_after_seconds


def _expected_skill_counts(exam_type: MockExamType) -> tuple[int, int]:
    if exam_type == MockExamType.WEEKLY:
        return MOCK_EXAM_WEEKLY_LISTENING_COUNT, MOCK_EXAM_WEEKLY_READING_COUNT
    return MOCK_EXAM_MONTHLY_LISTENING_COUNT, MOCK_EXAM_MONTHLY_READING_COUNT


def _get_job_for_update(db: Session, *, job_id: UUID) -> AIGenerationJob:
    job = (
        db.query(AIGenerationJob)
        .filter(AIGenerationJob.id == job_id)
        .with_for_update()
        .one_or_none()
    )
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ai_job_not_found")
    return job


def _to_job_response(job: AIGenerationJob) -> AIJobResponse:
    return AIJobResponse(
        id=job.id,
        job_type=job.job_type,
        request_id=job.request_id,
        status=job.status,
        target_mock_exam_id=job.target_mock_exam_id,
        notes=job.notes,
        generator_version=job.generator_version,
        candidate_limit=job.candidate_limit,
        metadata_json=job.metadata_json,
        provider_name=job.provider_name,
        model_name=job.model_name,
        prompt_template_version=job.prompt_template_version,
        input_artifact_object_key=job.input_artifact_object_key,
        output_artifact_object_key=job.output_artifact_object_key,
        candidate_snapshot_object_key=job.candidate_snapshot_object_key,
        produced_mock_exam_revision_id=job.produced_mock_exam_revision_id,
        attempt_count=job.attempt_count,
        last_error_code=job.last_error_code,
        last_error_message=job.last_error_message,
        last_error_transient=job.last_error_transient,
        next_retry_at=job.next_retry_at,
        dead_lettered_at=job.dead_lettered_at,
        queued_at=job.queued_at,
        started_at=job.started_at,
        completed_at=job.completed_at,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )
