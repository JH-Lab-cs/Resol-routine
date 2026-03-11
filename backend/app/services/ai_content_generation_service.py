from __future__ import annotations

import logging
import unicodedata
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, cast
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import and_, delete, or_, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import is_canonical_type_tag_for_skill
from app.core.input_validation import contains_hidden_unicode
from app.core.policies import (
    AI_CONTENT_DIFFICULTY_MAX,
    AI_CONTENT_DIFFICULTY_MIN,
    AI_CONTENT_FAILURE_MESSAGE_MAX_LENGTH,
    AI_JOB_MAX_ATTEMPTS,
    AI_JOB_RETRY_BACKOFF_BASE_SECONDS,
    AI_JOB_RETRY_BACKOFF_MAX_SECONDS,
    CONTENT_IDENTIFIER_MAX_LENGTH,
    CONTENT_QUESTION_CODE_MAX_LENGTH,
    CONTENT_REVISION_CODE_MAX_LENGTH,
    CONTENT_TEXT_MAX_LENGTH,
)
from app.db.session import schedule_ai_content_generation_job_after_commit
from app.models.ai_content_generation_candidate import AIContentGenerationCandidate
from app.models.ai_content_generation_job import AIContentGenerationJob
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_unit import ContentUnit
from app.models.enums import (
    AIContentGenerationCandidateStatus,
    AIGenerationJobStatus,
    ContentTypeTag,
    Skill,
    Track,
)
from app.schemas.ai_content_generation import (
    AIContentGenerationCandidateListResponse,
    AIContentGenerationCandidateResponse,
    AIContentGenerationFailureCode,
    AIContentGenerationJobCreateRequest,
    AIContentGenerationJobResponse,
    AIContentMaterializeDraftResponse,
)
from app.schemas.content import (
    ContentQuestionCreateRequest,
    ContentUnitCreateRequest,
    ContentUnitRevisionCreateRequest,
)
from app.services.ai_artifact_service import ArtifactStoreError, get_ai_artifact_store
from app.services.ai_content_provider import (
    ContentGenerationContext,
    ContentGenerationTarget,
    GeneratedContentCandidate,
    build_ai_content_generation_provider,
)
from app.services.ai_provider import AIProviderError
from app.services.audit_service import append_audit_log
from app.services.content_ingest_service import create_content_unit, create_content_unit_revision
from app.services.l_response_generation_service import (
    L_RESPONSE_COMPILER_VERSION,
    L_RESPONSE_GENERATION_MODE,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class AIContentJobExecutionResult:
    job_id: UUID
    status: AIGenerationJobStatus
    error_code: str | None
    retry_after_seconds: int | None


def create_ai_content_generation_job(
    db: Session,
    *,
    payload: AIContentGenerationJobCreateRequest,
) -> AIContentGenerationJobResponse:
    existing = db.execute(
        select(AIContentGenerationJob).where(
            AIContentGenerationJob.request_id == payload.request_id
        )
    ).scalar_one_or_none()
    if existing is not None:
        return _to_job_response(existing)

    if payload.content_unit_id is not None:
        unit = db.get(ContentUnit, payload.content_unit_id)
        if unit is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found"
            )
        if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived"
            )

        for row in payload.target_matrix:
            if row.track != unit.track or row.skill != unit.skill:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="target_matrix_unit_mismatch",
                )

    job = AIContentGenerationJob(
        request_id=payload.request_id,
        status=AIGenerationJobStatus.QUEUED,
        content_unit_id=payload.content_unit_id,
        dry_run=payload.dry_run,
        candidate_count_per_target=payload.candidate_count_per_target,
        target_matrix_json=[
            {
                "track": row.track.value,
                "skill": row.skill.value,
                "typeTag": row.type_tag.value,
                "difficulty": row.difficulty,
                "count": row.count,
            }
            for row in payload.target_matrix
        ],
        metadata_json=payload.metadata_json,
        provider_override=payload.provider_override,
        attempt_count=0,
        notes=payload.notes,
    )
    db.add(job)
    db.flush()

    schedule_ai_content_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def get_ai_content_generation_job(db: Session, *, job_id: UUID) -> AIContentGenerationJobResponse:
    job = db.get(AIContentGenerationJob, job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ai_content_job_not_found"
        )
    return _to_job_response(job)


def list_ai_content_generation_candidates(
    db: Session,
    *,
    job_id: UUID,
) -> AIContentGenerationCandidateListResponse:
    job = db.get(AIContentGenerationJob, job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ai_content_job_not_found"
        )

    rows = (
        db.execute(
            select(AIContentGenerationCandidate)
            .where(AIContentGenerationCandidate.job_id == job_id)
            .order_by(
                AIContentGenerationCandidate.candidate_index.asc(),
                AIContentGenerationCandidate.id.asc(),
            )
        )
        .scalars()
        .all()
    )

    return AIContentGenerationCandidateListResponse(
        job_id=job_id,
        items=[_to_candidate_response(row) for row in rows],
    )


def retry_ai_content_generation_job(db: Session, *, job_id: UUID) -> AIContentGenerationJobResponse:
    job = _get_job_for_update(db, job_id=job_id)
    if job.status == AIGenerationJobStatus.RUNNING:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="ai_content_job_already_running"
        )
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

    schedule_ai_content_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def materialize_ai_content_candidate_draft(
    db: Session,
    *,
    candidate_id: UUID,
) -> AIContentMaterializeDraftResponse:
    candidate = _get_candidate_for_update(db, candidate_id=candidate_id)
    job = _get_job_for_update(db, job_id=candidate.job_id)

    if candidate.status != AIContentGenerationCandidateStatus.VALID:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="candidate_not_materializable"
        )
    if (
        candidate.materialized_revision_id is not None
        and candidate.materialized_content_unit_id is not None
    ):
        return AIContentMaterializeDraftResponse(
            candidate_id=candidate.id,
            content_unit_id=candidate.materialized_content_unit_id,
            content_revision_id=candidate.materialized_revision_id,
            revision_lifecycle_status=ContentLifecycleStatus.DRAFT,
            materialized_at=candidate.materialized_at or datetime.now(UTC),
        )
    if job.dry_run:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="dry_run_job_cannot_materialize"
        )

    materialized_at = datetime.now(UTC)

    if job.content_unit_id is None:
        external_id = _build_generated_external_id(candidate=candidate)
        slug = _build_generated_slug(candidate=candidate)
        unit_response = create_content_unit(
            db,
            payload=ContentUnitCreateRequest(
                external_id=external_id,
                slug=slug,
                skill=candidate.skill,
                track=candidate.track,
            ),
        )
        unit_id = unit_response.id
    else:
        unit = db.get(ContentUnit, job.content_unit_id)
        if unit is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found"
            )
        if unit.lifecycle_status == ContentLifecycleStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="content_unit_archived"
            )
        if unit.track != candidate.track or unit.skill != candidate.skill:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="materialize_target_unit_mismatch"
            )
        unit_id = unit.id

    revision_code = _build_generated_revision_code(candidate=candidate)
    question_code = _build_generated_question_code(candidate=candidate)
    options = {
        "A": candidate.choice_a,
        "B": candidate.choice_b,
        "C": candidate.choice_c,
        "D": candidate.choice_d,
        "E": candidate.choice_e,
    }

    revision_response = create_content_unit_revision(
        db,
        unit_id=unit_id,
        payload=ContentUnitRevisionCreateRequest(
            revision_code=revision_code,
            generator_version=_build_generator_version(job=job),
            title=candidate.title,
            body_text=candidate.passage_text,
            transcript_text=candidate.transcript_text,
            explanation_text=candidate.explanation_text,
            asset_id=None,
            metadata_json=_build_revision_metadata(job=job, candidate=candidate),
            questions=[
                ContentQuestionCreateRequest(
                    question_code=question_code,
                    order_index=1,
                    stem=candidate.question_stem,
                    choice_a=options["A"],
                    choice_b=options["B"],
                    choice_c=options["C"],
                    choice_d=options["D"],
                    choice_e=options["E"],
                    correct_answer=candidate.answer_key,
                    explanation=candidate.explanation_text,
                    metadata_json=_build_question_metadata(job=job, candidate=candidate),
                )
            ],
        ),
    )

    candidate.status = AIContentGenerationCandidateStatus.MATERIALIZED
    candidate.materialized_content_unit_id = revision_response.content_unit_id
    candidate.materialized_revision_id = revision_response.id
    candidate.materialized_at = materialized_at
    db.flush()

    append_audit_log(
        db,
        action="ai_content_candidate_materialized",
        actor_user_id=None,
        target_user_id=None,
        details={
            "job_id": str(job.id),
            "candidate_id": str(candidate.id),
            "content_unit_id": str(revision_response.content_unit_id),
            "content_revision_id": str(revision_response.id),
        },
    )

    return AIContentMaterializeDraftResponse(
        candidate_id=candidate.id,
        content_unit_id=revision_response.content_unit_id,
        content_revision_id=revision_response.id,
        revision_lifecycle_status=revision_response.lifecycle_status,
        materialized_at=materialized_at,
    )


def run_ai_content_generation_job(db: Session, *, job_id: UUID) -> AIContentJobExecutionResult:
    now = datetime.now(UTC)
    retry_ready_condition = or_(
        AIContentGenerationJob.status == AIGenerationJobStatus.QUEUED,
        and_(
            AIContentGenerationJob.status == AIGenerationJobStatus.FAILED,
            or_(
                AIContentGenerationJob.next_retry_at.is_(None),
                AIContentGenerationJob.next_retry_at <= now,
            ),
        ),
    )
    claim_result = cast(
        CursorResult[Any],
        db.execute(
            update(AIContentGenerationJob)
            .where(AIContentGenerationJob.id == job_id, retry_ready_condition)
            .values(
                status=AIGenerationJobStatus.RUNNING,
                started_at=now,
                completed_at=None,
                attempt_count=AIContentGenerationJob.attempt_count + 1,
                next_retry_at=None,
                last_error_code=None,
                last_error_message=None,
                last_error_transient=None,
            )
        ),
    )
    claimed_rows = claim_result.rowcount or 0

    if claimed_rows == 0:
        existing = db.get(AIContentGenerationJob, job_id)
        if existing is None:
            raise ValueError("ai_content_job_not_found")
        return AIContentJobExecutionResult(
            job_id=existing.id,
            status=existing.status,
            error_code=existing.last_error_code,
            retry_after_seconds=None,
        )

    job = _get_job_for_update(db, job_id=job_id)
    db.execute(
        delete(AIContentGenerationCandidate).where(
            AIContentGenerationCandidate.job_id == job.id,
            AIContentGenerationCandidate.materialized_revision_id.is_(None),
        )
    )

    artifact_store = get_ai_artifact_store()

    try:
        provider = build_ai_content_generation_provider(
            provider_override=job.provider_override,
            model_override=_extract_generation_model_override(job=job),
            prompt_template_version_override=_extract_prompt_template_override(job=job),
        )
        context = _build_provider_context(job=job)
        provider_result = provider.generate_candidates(context=context)
        if not provider_result.candidates:
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Generated output must include at least one candidate.",
                transient=False,
            )

        job.provider_name = provider_result.provider_name
        job.model_name = provider_result.model_name
        job.prompt_template_version = provider_result.prompt_template_version
        job.input_artifact_object_key = artifact_store.put_text_with_object_key(
            object_key=_build_content_job_artifact_key(job_id=job.id, file_name="input.json"),
            body=provider_result.raw_prompt,
            content_type="application/json",
        )
        job.output_artifact_object_key = artifact_store.put_text_with_object_key(
            object_key=_build_content_job_artifact_key(job_id=job.id, file_name="response.json"),
            body=provider_result.raw_response,
            content_type="application/json",
        )

        raw_candidate_payloads = provider_result.raw_candidate_payloads or [
            _candidate_payload_for_artifact(candidate) for candidate in provider_result.candidates
        ]
        compiled_candidate_payloads = provider_result.compiled_candidate_payloads or [
            _candidate_payload_for_artifact(candidate) for candidate in provider_result.candidates
        ]
        if len(raw_candidate_payloads) != len(provider_result.candidates):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Candidate raw payload count must match candidate count.",
                transient=False,
            )
        if len(compiled_candidate_payloads) != len(provider_result.candidates):
            raise AIProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Compiled candidate payload count must match candidate count.",
                transient=False,
            )

        valid_count = 0
        invalid_count = 0
        snapshot_candidates: list[dict[str, object]] = []

        for candidate_index, generated in enumerate(provider_result.candidates, start=1):
            raw_candidate_payload = raw_candidate_payloads[candidate_index - 1]
            candidate_payload = compiled_candidate_payloads[candidate_index - 1]
            validation_report = _validate_candidate_payload(generated)
            snapshot_candidates.append(
                {
                    "candidateIndex": candidate_index,
                    "candidateId": None,
                    "status": "VALID" if not validation_report["errors"] else "INVALID",
                    "track": generated.track.value,
                    "skill": generated.skill.value,
                    "typeTag": generated.type_tag.value,
                    "difficulty": generated.difficulty,
                    "generationMode": provider_result.generation_mode,
                    "compilerVersion": provider_result.compiler_version,
                    "rawCandidate": raw_candidate_payload,
                    "candidate": candidate_payload,
                    "validation": validation_report,
                }
            )

            candidate_id = uuid4()
            prompt_key = artifact_store.put_text_with_object_key(
                object_key=_build_content_candidate_artifact_key(
                    job_id=job.id,
                    candidate_id=candidate_id,
                    file_name="prompt.json",
                ),
                body=provider_result.raw_prompt,
                content_type="application/json",
            )
            response_key = artifact_store.put_text_with_object_key(
                object_key=_build_content_candidate_artifact_key(
                    job_id=job.id,
                    candidate_id=candidate_id,
                    file_name="response.json",
                ),
                body=provider_result.raw_response,
                content_type="application/json",
            )
            candidate_json_key = artifact_store.put_json_with_object_key(
                object_key=_build_content_candidate_artifact_key(
                    job_id=job.id,
                    candidate_id=candidate_id,
                    file_name="candidate.json",
                ),
                payload=candidate_payload,
            )
            validation_key = artifact_store.put_json_with_object_key(
                object_key=_build_content_candidate_artifact_key(
                    job_id=job.id,
                    candidate_id=candidate_id,
                    file_name="validation.json",
                ),
                payload={
                    "generationMode": provider_result.generation_mode,
                    "compilerVersion": provider_result.compiler_version,
                    "rawCandidate": raw_candidate_payload,
                    "compiledCandidate": candidate_payload,
                    "errors": validation_report["errors"],
                    "reviewFlags": validation_report["reviewFlags"],
                },
            )

            status_value = AIContentGenerationCandidateStatus.VALID
            failure_code: str | None = None
            failure_message: str | None = None
            if validation_report["errors"]:
                status_value = AIContentGenerationCandidateStatus.INVALID
                failure_code = _map_candidate_validation_failure_code(
                    validation_report["errors"]
                )
                failure_message = "; ".join(validation_report["errors"])[
                    :AI_CONTENT_FAILURE_MESSAGE_MAX_LENGTH
                ]
                invalid_count += 1
            else:
                valid_count += 1

            stored_difficulty = generated.difficulty
            if (
                stored_difficulty < AI_CONTENT_DIFFICULTY_MIN
                or stored_difficulty > AI_CONTENT_DIFFICULTY_MAX
            ):
                stored_difficulty = AI_CONTENT_DIFFICULTY_MIN

            stored_answer_key = generated.answer_key.strip().upper()
            if stored_answer_key not in {"A", "B", "C", "D", "E"}:
                stored_answer_key = "A"

            row = AIContentGenerationCandidate(
                id=candidate_id,
                job_id=job.id,
                candidate_index=candidate_index,
                status=status_value,
                failure_code=failure_code,
                failure_message=failure_message,
                track=generated.track,
                skill=generated.skill,
                type_tag=generated.type_tag,
                difficulty=stored_difficulty,
                source_policy=generated.source_policy,
                title=generated.title,
                passage_text=generated.passage,
                transcript_text=generated.transcript,
                sentences_json=generated.sentences,
                turns_json=generated.turns,
                tts_plan_json=generated.tts_plan,
                question_stem=generated.stem,
                choice_a=generated.options.get("A", ""),
                choice_b=generated.options.get("B", ""),
                choice_c=generated.options.get("C", ""),
                choice_d=generated.options.get("D", ""),
                choice_e=generated.options.get("E", ""),
                answer_key=stored_answer_key,
                explanation_text=generated.explanation,
                evidence_sentence_ids_json=generated.evidence_sentence_ids,
                why_correct_ko=generated.why_correct_ko,
                why_wrong_ko_by_option_json=generated.why_wrong_ko_by_option,
                vocab_notes_ko=generated.vocab_notes_ko,
                structure_notes_ko=generated.structure_notes_ko,
                review_flags_json=validation_report["reviewFlags"],
                artifact_prompt_key=prompt_key,
                artifact_response_key=response_key,
                artifact_candidate_json_key=candidate_json_key,
                artifact_validation_report_key=validation_key,
            )
            db.add(row)
            db.flush()
            snapshot_candidates[-1]["candidateId"] = str(row.id)

        job.candidate_snapshot_object_key = artifact_store.put_json_with_object_key(
            object_key=_build_content_job_artifact_key(
                job_id=job.id, file_name="candidate-snapshot.json"
            ),
            payload={
                "jobId": str(job.id),
                "requestId": job.request_id,
                "generatedAt": datetime.now(UTC).isoformat(),
                "providerName": provider_result.provider_name,
                "modelName": provider_result.model_name,
                "promptTemplateVersion": provider_result.prompt_template_version,
                "generationMode": provider_result.generation_mode,
                "compilerVersion": provider_result.compiler_version,
                "validCount": valid_count,
                "invalidCount": invalid_count,
                "candidates": snapshot_candidates,
            },
        )

        job.status = AIGenerationJobStatus.SUCCEEDED
        job.completed_at = datetime.now(UTC)
        job.next_retry_at = None
        job.dead_lettered_at = None
        job.last_error_code = None
        job.last_error_message = None
        job.last_error_transient = None
        db.flush()

        append_audit_log(
            db,
            action="ai_content_generation_job_succeeded",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "valid_candidate_count": valid_count,
                "invalid_candidate_count": invalid_count,
            },
        )

        logger.info(
            "AI content generation job succeeded",
            extra={
                "job_id": str(job.id),
                "valid_candidate_count": valid_count,
                "invalid_candidate_count": invalid_count,
            },
        )

        return AIContentJobExecutionResult(
            job_id=job.id,
            status=job.status,
            error_code=None,
            retry_after_seconds=None,
        )
    except AIProviderError as exc:
        retry_after = _mark_job_failure(
            db,
            job,
            code=exc.code,
            message=exc.message,
            transient=exc.transient,
        )
    except ArtifactStoreError as exc:
        retry_after = _mark_job_failure(
            db,
            job,
            code="ARTIFACT_UPLOAD_FAILED",
            message=exc.message,
            transient=False,
        )
    except HTTPException as exc:
        detail_code = exc.detail if isinstance(exc.detail, str) else "DRAFT_PERSIST_FAILED"
        retry_after = _mark_job_failure(
            db,
            job,
            code=str(detail_code),
            message=f"Content generation failed: {detail_code}",
            transient=False,
        )
    except Exception as exc:  # pragma: no cover - defensive fallback
        logger.exception(
            "Unexpected AI content generation worker failure",
            extra={"job_id": str(job.id)},
        )
        retry_after = _mark_job_failure(
            db,
            job,
            code="DRAFT_PERSIST_FAILED",
            message=str(exc),
            transient=True,
        )

    db.flush()

    logger.info(
        "AI content generation job failed",
        extra={
            "job_id": str(job.id),
            "error_code": job.last_error_code,
            "attempt_count": job.attempt_count,
        },
    )

    return AIContentJobExecutionResult(
        job_id=job.id,
        status=job.status,
        error_code=job.last_error_code,
        retry_after_seconds=retry_after,
    )


def _mark_job_failure(
    db: Session,
    job: AIContentGenerationJob,
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
            action="ai_content_generation_job_dead_lettered",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "error_code": code,
                "attempt_count": job.attempt_count,
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
    job.last_error_message = message[:AI_CONTENT_FAILURE_MESSAGE_MAX_LENGTH]
    job.last_error_transient = transient
    return retry_after_seconds


def _validate_candidate_payload(candidate: GeneratedContentCandidate) -> dict[str, list[str]]:
    errors: list[str] = []
    review_flags: list[str] = []

    if (
        candidate.difficulty < AI_CONTENT_DIFFICULTY_MIN
        or candidate.difficulty > AI_CONTENT_DIFFICULTY_MAX
    ):
        errors.append("invalid_difficulty")

    if not is_canonical_type_tag_for_skill(
        skill=candidate.skill.value,
        type_tag=candidate.type_tag.value,
    ):
        errors.append("skill_type_tag_mismatch")

    _validate_text_field(candidate.stem, "stem", errors, required=True)
    _validate_text_field(candidate.explanation, "explanation", errors, required=True)
    _validate_text_field(candidate.why_correct_ko, "why_correct_ko", errors, required=True)

    if candidate.skill == Skill.READING:
        _validate_text_field(candidate.passage, "passage", errors, required=True)
    else:
        _validate_text_field(candidate.transcript, "transcript", errors, required=True)
        if not candidate.turns:
            errors.append("listening_turns_required")
        if not isinstance(candidate.tts_plan, dict) or not candidate.tts_plan:
            errors.append("listening_tts_plan_required")

    if not candidate.sentences:
        errors.append("sentences_must_not_be_empty")

    sentence_ids: set[str] = set()
    for sentence in candidate.sentences:
        sentence_id = sentence.get("id", "")
        sentence_text = sentence.get("text", "")
        if not isinstance(sentence_id, str) or not sentence_id:
            errors.append("invalid_sentence_id")
            continue
        if contains_hidden_unicode(sentence_id):
            errors.append("invalid_hidden_unicode")
        if sentence_id in sentence_ids:
            errors.append("duplicate_sentence_id")
        sentence_ids.add(sentence_id)
        if not isinstance(sentence_text, str) or not sentence_text.strip():
            errors.append("invalid_sentence_text")
        elif len(sentence_text.strip()) > CONTENT_TEXT_MAX_LENGTH:
            errors.append("sentence_text_too_long")
        elif contains_hidden_unicode(sentence_text):
            errors.append("invalid_hidden_unicode")

    if candidate.skill == Skill.LISTENING:
        if candidate.transcript is not None and candidate.turns:
            normalized_transcript = candidate.transcript.strip()
            for turn in candidate.turns:
                turn_text = turn.get("text", "").strip()
                if not turn_text or turn_text not in normalized_transcript:
                    errors.append("listening_turn_sentence_alignment_invalid")
                    break
        if candidate.turns and len(candidate.sentences) < len(candidate.turns):
            errors.append("listening_turn_sentence_alignment_invalid")

        if candidate.type_tag == ContentTypeTag.L_LONG_TALK:
            if len(candidate.turns) < 4:
                errors.append("listening_long_talk_turn_count_insufficient")
            if len(candidate.sentences) < 4:
                errors.append("listening_long_talk_sentence_count_insufficient")
        elif candidate.type_tag == ContentTypeTag.L_RESPONSE:
            if len(candidate.turns) != 2:
                errors.append("l_response_turn_count_invalid")
            if len(candidate.evidence_sentence_ids) == 0:
                errors.append("l_response_evidence_turn_invalid")
            if len(options := candidate.options) == 5:
                response_texts = [
                    options.get("A", ""),
                    options.get("B", ""),
                    options.get("C", ""),
                    options.get("D", ""),
                    options.get("E", ""),
                ]
                normalized_response_texts = [
                    _normalize_response_option_text(value) for value in response_texts
                ]
                if len(set(normalized_response_texts)) != 5:
                    errors.append("l_response_option_duplicate")
                if _response_options_have_semantic_overlap(normalized_response_texts):
                    errors.append("l_response_option_duplicate")
                if candidate.turns and candidate.sentences:
                    expected_sentence_ids = {
                        f"s{index}" for index in range(1, len(candidate.turns) + 1)
                    }
                    if set(sentence_ids) != expected_sentence_ids:
                        errors.append("l_response_sentence_id_mismatch")
        elif candidate.type_tag == ContentTypeTag.L_SITUATION:
            if len(candidate.turns) < 2 or len(candidate.sentences) < 3:
                errors.append("listening_situation_alignment_invalid")
    else:
        passage_text = (candidate.passage or "").strip()
        if candidate.type_tag == ContentTypeTag.R_BLANK and "[BLANK]" not in passage_text:
            errors.append("reading_blank_marker_missing")
        if candidate.type_tag == ContentTypeTag.R_INSERTION:
            required_markers = ("[1]", "[2]", "[3]", "[4]")
            if not all(marker in passage_text for marker in required_markers):
                errors.append("reading_insertion_marker_missing")
        if candidate.type_tag == ContentTypeTag.R_ORDER and len(candidate.sentences) < 4:
            errors.append("reading_order_sentence_count_insufficient")
        if candidate.type_tag == ContentTypeTag.R_SUMMARY and len(candidate.sentences) < 4:
            errors.append("reading_summary_sentence_count_insufficient")
        if candidate.type_tag == ContentTypeTag.R_VOCAB:
            normalized_stem = candidate.stem.casefold()
            if "word" not in normalized_stem and "meaning" not in normalized_stem:
                errors.append("reading_vocab_prompt_misaligned")

    options = candidate.options
    if set(options.keys()) != {"A", "B", "C", "D", "E"}:
        errors.append("invalid_option_keys")
    else:
        normalized_values: dict[str, str] = {}
        for option_key in ["A", "B", "C", "D", "E"]:
            option_text = options[option_key]
            _validate_text_field(option_text, f"option_{option_key}", errors, required=True)
            normalized_values[option_key] = option_text.strip().casefold()

        if len(set(normalized_values.values())) != 5:
            errors.append("duplicate_option_text")

        answer = candidate.answer_key.strip().upper()
        if answer not in {"A", "B", "C", "D", "E"}:
            errors.append("invalid_answer_key")
        else:
            answer_text = normalized_values[answer]
            for option_key, option_text in normalized_values.items():
                if option_key == answer:
                    continue
                if option_text == answer_text:
                    errors.append("answer_distractor_semantic_collision")
                if answer_text in option_text or option_text in answer_text:
                    errors.append("answer_distractor_semantic_collision")

    if not candidate.evidence_sentence_ids:
        errors.append("evidence_sentence_ids_required")
    else:
        for evidence_id in candidate.evidence_sentence_ids:
            if contains_hidden_unicode(evidence_id):
                errors.append("invalid_hidden_unicode")
            if evidence_id not in sentence_ids:
                errors.append("invalid_evidence_sentence_id")

    wrong_map = candidate.why_wrong_ko_by_option
    if set(wrong_map.keys()) != {"A", "B", "C", "D", "E"}:
        errors.append("invalid_why_wrong_map")
    else:
        for option_key in ["A", "B", "C", "D", "E"]:
            _validate_text_field(
                wrong_map[option_key], f"why_wrong_{option_key}", errors, required=True
            )

    if candidate.explanation and len(candidate.explanation.strip()) < 40:
        review_flags.append("explanation_quality_low")
    if candidate.track.value == "M3" and candidate.difficulty >= 4:
        review_flags.append("difficulty_review_recommended")

    return {
        "errors": sorted(set(errors)),
        "reviewFlags": sorted(set(review_flags)),
    }


def _map_candidate_validation_failure_code(errors: list[str]) -> str:
    error_set = set(errors)
    if "l_response_turn_count_invalid" in error_set:
        return AIContentGenerationFailureCode.OUTPUT_INVALID_TURN_COUNT.value
    if any(
        error in error_set
        for error in {
            "l_response_option_duplicate",
            "answer_distractor_semantic_collision",
        }
    ):
        return AIContentGenerationFailureCode.OUTPUT_INVALID_RESPONSE_OPTIONS.value
    if any(
        error in error_set
        for error in {
            "l_response_evidence_turn_invalid",
            "l_response_sentence_id_mismatch",
        }
    ):
        return AIContentGenerationFailureCode.OUTPUT_INVALID_EVIDENCE_TURN.value
    if any(error in error_set for error in {"duplicate_option_text", "invalid_option_keys"}):
        return "OUTPUT_OPTION_DUPLICATE"
    if any(
        error in error_set
        for error in {
            "invalid_evidence_sentence_id",
            "listening_turn_sentence_alignment_invalid",
            "reading_insertion_marker_missing",
        }
    ):
        return "OUTPUT_SENTENCE_ID_MISMATCH"
    if any(
        error in error_set
        for error in {
            "stem_required",
            "explanation_required",
            "why_correct_ko_required",
            "passage_required",
            "transcript_required",
            "listening_turns_required",
            "listening_tts_plan_required",
            "sentences_must_not_be_empty",
            "evidence_sentence_ids_required",
            "reading_blank_marker_missing",
            "listening_long_talk_turn_count_insufficient",
            "listening_long_talk_sentence_count_insufficient",
            "listening_situation_alignment_invalid",
        }
    ) or any(error.endswith("_required") for error in error_set):
        return "OUTPUT_MISSING_FIELD"
    return "OUTPUT_VALIDATION_FAILED"


def _validate_text_field(
    value: str | None, field_name: str, errors: list[str], *, required: bool
) -> None:
    if value is None:
        if required:
            errors.append(f"{field_name}_required")
        return

    stripped = value.strip()
    if not stripped:
        if required:
            errors.append(f"{field_name}_required")
        return

    if len(stripped) > CONTENT_TEXT_MAX_LENGTH:
        errors.append(f"{field_name}_too_long")
    if _contains_disallowed_text_unicode(stripped):
        errors.append("invalid_hidden_unicode")


def _normalize_response_option_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold()
    collapsed = "".join(char if char.isalnum() or char.isspace() else " " for char in normalized)
    return " ".join(collapsed.split())


def _response_options_have_semantic_overlap(normalized_values: list[str]) -> bool:
    for index, current in enumerate(normalized_values):
        for other in normalized_values[index + 1 :]:
            if len(current) < 5 or len(other) < 5:
                continue
            if current in other or other in current:
                return True
    return False


def _contains_disallowed_text_unicode(value: str) -> bool:
    for char in value:
        category = unicodedata.category(char)
        if category == "Cf":
            return True
        if category == "Cc" and char not in {"\n", "\r", "\t"}:
            return True
    return False


def _candidate_payload_for_artifact(candidate: GeneratedContentCandidate) -> dict[str, object]:
    return {
        "track": candidate.track.value,
        "skill": candidate.skill.value,
        "typeTag": candidate.type_tag.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": candidate.source_policy.value,
        "title": candidate.title,
        "passage": candidate.passage,
        "transcript": candidate.transcript,
        "turns": candidate.turns,
        "sentences": candidate.sentences,
        "ttsPlan": candidate.tts_plan,
        "question": {
            "stem": candidate.stem,
            "options": candidate.options,
            "answerKey": candidate.answer_key,
            "explanation": candidate.explanation,
            "evidenceSentenceIds": candidate.evidence_sentence_ids,
            "whyCorrectKo": candidate.why_correct_ko,
            "whyWrongKoByOption": candidate.why_wrong_ko_by_option,
            "vocabNotesKo": candidate.vocab_notes_ko,
            "structureNotesKo": candidate.structure_notes_ko,
        },
    }


def _build_provider_context(job: AIContentGenerationJob) -> ContentGenerationContext:
    matrix: list[ContentGenerationTarget] = []
    for row in job.target_matrix_json:
        try:
            matrix.append(
                ContentGenerationTarget(
                    track=Track(str(row["track"])),
                    skill=Skill(str(row["skill"])),
                    type_tag=ContentTypeTag(str(row["typeTag"])),
                    difficulty=int(row["difficulty"]),
                    count=int(row["count"]),
                )
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="invalid_target_matrix"
            ) from exc

    return ContentGenerationContext(
        request_id=job.request_id,
        target_matrix=matrix,
        candidate_count_per_target=job.candidate_count_per_target,
        dry_run=job.dry_run,
        notes=job.notes,
    )


def _build_content_job_artifact_key(*, job_id: UUID, file_name: str) -> str:
    return f"ai-content/jobs/{job_id}/{file_name}"


def _build_content_candidate_artifact_key(
    *, job_id: UUID, candidate_id: UUID, file_name: str
) -> str:
    return f"ai-content/jobs/{job_id}/candidates/{candidate_id}/{file_name}"


def _build_generated_external_id(*, candidate: AIContentGenerationCandidate) -> str:
    raw = (
        f"ai-unit-{candidate.track.value.lower()}-{candidate.skill.value.lower()}-"
        f"{candidate.type_tag.value.lower()}-{candidate.id.hex[:12]}"
    )
    if len(raw) > CONTENT_IDENTIFIER_MAX_LENGTH:
        return raw[:CONTENT_IDENTIFIER_MAX_LENGTH]
    return raw


def _build_generated_slug(*, candidate: AIContentGenerationCandidate) -> str:
    raw = (
        f"ai-{candidate.track.value.lower()}-"
        f"{candidate.type_tag.value.lower()}-{candidate.id.hex[:10]}"
    )
    if len(raw) > CONTENT_IDENTIFIER_MAX_LENGTH:
        return raw[:CONTENT_IDENTIFIER_MAX_LENGTH]
    return raw


def _build_generated_revision_code(*, candidate: AIContentGenerationCandidate) -> str:
    code = f"ai-{candidate.id.hex[:24]}"
    if len(code) > CONTENT_REVISION_CODE_MAX_LENGTH:
        return code[:CONTENT_REVISION_CODE_MAX_LENGTH]
    return code


def _build_generated_question_code(*, candidate: AIContentGenerationCandidate) -> str:
    code = f"AIQ-{candidate.type_tag.value}-{candidate.id.hex[:16]}"
    if len(code) > CONTENT_QUESTION_CODE_MAX_LENGTH:
        return code[:CONTENT_QUESTION_CODE_MAX_LENGTH]
    return code


def _build_generator_version(*, job: AIContentGenerationJob) -> str:
    template = (job.prompt_template_version or "v1").replace(" ", "-")
    version = f"ai-content-{template}".lower()
    if len(version) > CONTENT_IDENTIFIER_MAX_LENGTH:
        return version[:CONTENT_IDENTIFIER_MAX_LENGTH]
    return version


def _build_revision_metadata(
    *,
    job: AIContentGenerationJob,
    candidate: AIContentGenerationCandidate,
) -> dict[str, object]:
    metadata: dict[str, object] = {
        "generationJobId": str(job.id),
        "generationCandidateId": str(candidate.id),
        "providerName": job.provider_name,
        "modelName": job.model_name,
        "promptTemplateVersion": job.prompt_template_version,
        "track": candidate.track.value,
        "skill": candidate.skill.value,
        "typeTag": candidate.type_tag.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": candidate.source_policy.value,
        "reviewFlags": candidate.review_flags_json,
        "copyrightRisk": "copyright_risk_suspected" in candidate.review_flags_json,
        "artifacts": {
            "prompt": candidate.artifact_prompt_key,
            "response": candidate.artifact_response_key,
            "candidateJson": candidate.artifact_candidate_json_key,
            "validationReport": candidate.artifact_validation_report_key,
        },
    }

    if candidate.sentences_json:
        metadata["sentences"] = candidate.sentences_json
    if candidate.turns_json:
        metadata["turns"] = candidate.turns_json
    if candidate.tts_plan_json:
        metadata["ttsPlan"] = candidate.tts_plan_json
    generation_trace = _extract_generation_trace(job=job, candidate=candidate)
    if generation_trace is not None:
        metadata.update(generation_trace)
    source = _extract_generation_source(job=job)
    if source is not None:
        metadata["source"] = source
    fallback_triggered = _extract_fallback_triggered(job=job)
    if fallback_triggered is not None:
        metadata["fallbackTriggered"] = fallback_triggered

    return metadata


def _build_question_metadata(
    *,
    job: AIContentGenerationJob,
    candidate: AIContentGenerationCandidate,
) -> dict[str, object]:
    metadata: dict[str, object] = {
        "generationJobId": str(job.id),
        "generationCandidateId": str(candidate.id),
        "providerName": job.provider_name,
        "modelName": job.model_name,
        "promptTemplateVersion": job.prompt_template_version,
        "typeTag": candidate.type_tag.value,
        "difficulty": candidate.difficulty,
        "sourcePolicy": candidate.source_policy.value,
        "evidenceSentenceIds": candidate.evidence_sentence_ids_json,
        "whyCorrectKo": candidate.why_correct_ko,
        "whyWrongKoByOption": candidate.why_wrong_ko_by_option_json,
        "vocabNotesKo": candidate.vocab_notes_ko,
        "structureNotesKo": candidate.structure_notes_ko,
        "reviewFlags": candidate.review_flags_json,
    }
    generation_trace = _extract_generation_trace(job=job, candidate=candidate)
    if generation_trace is not None:
        metadata.update(generation_trace)
    source = _extract_generation_source(job=job)
    if source is not None:
        metadata["source"] = source
    fallback_triggered = _extract_fallback_triggered(job=job)
    if fallback_triggered is not None:
        metadata["fallbackTriggered"] = fallback_triggered
    return metadata


def _extract_generation_trace(
    *,
    job: AIContentGenerationJob,
    candidate: AIContentGenerationCandidate,
) -> dict[str, object] | None:
    if (
        candidate.type_tag == ContentTypeTag.L_RESPONSE
        and isinstance(job.prompt_template_version, str)
        and job.prompt_template_version.endswith("listening-response-skeleton")
    ):
        return {
            "generationMode": L_RESPONSE_GENERATION_MODE,
            "compilerVersion": L_RESPONSE_COMPILER_VERSION,
        }
    return None


def _extract_generation_source(*, job: AIContentGenerationJob) -> str | None:
    metadata = job.metadata_json if isinstance(job.metadata_json, dict) else {}
    raw_source = metadata.get("source")
    if not isinstance(raw_source, str):
        return None
    normalized = raw_source.strip()
    return normalized or None


def _extract_fallback_triggered(*, job: AIContentGenerationJob) -> bool | None:
    metadata = job.metadata_json if isinstance(job.metadata_json, dict) else {}
    raw_value = metadata.get("fallbackTriggered")
    if not isinstance(raw_value, bool):
        return None
    return raw_value


def _extract_generation_model_override(*, job: AIContentGenerationJob) -> str | None:
    metadata = job.metadata_json if isinstance(job.metadata_json, dict) else {}
    raw_value = metadata.get("requestedModelName") or metadata.get("modelOverride")
    if not isinstance(raw_value, str):
        return None
    normalized = raw_value.strip()
    return normalized or None


def _extract_prompt_template_override(*, job: AIContentGenerationJob) -> str | None:
    metadata = job.metadata_json if isinstance(job.metadata_json, dict) else {}
    raw_value = metadata.get("requestedPromptTemplateVersion") or metadata.get(
        "promptTemplateVersionOverride"
    )
    if not isinstance(raw_value, str):
        return None
    normalized = raw_value.strip()
    return normalized or None


def _get_job_for_update(db: Session, *, job_id: UUID) -> AIContentGenerationJob:
    job = (
        db.query(AIContentGenerationJob)
        .filter(AIContentGenerationJob.id == job_id)
        .with_for_update()
        .one_or_none()
    )
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ai_content_job_not_found"
        )
    return job


def _get_candidate_for_update(db: Session, *, candidate_id: UUID) -> AIContentGenerationCandidate:
    candidate = (
        db.query(AIContentGenerationCandidate)
        .filter(AIContentGenerationCandidate.id == candidate_id)
        .with_for_update()
        .one_or_none()
    )
    if candidate is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="ai_content_candidate_not_found"
        )
    return candidate


def _to_job_response(job: AIContentGenerationJob) -> AIContentGenerationJobResponse:
    return AIContentGenerationJobResponse(
        id=job.id,
        request_id=job.request_id,
        status=job.status,
        content_unit_id=job.content_unit_id,
        dry_run=job.dry_run,
        target_matrix_json=job.target_matrix_json,
        candidate_count_per_target=job.candidate_count_per_target,
        provider_override=job.provider_override,
        notes=job.notes,
        metadata_json=job.metadata_json,
        provider_name=job.provider_name,
        model_name=job.model_name,
        prompt_template_version=job.prompt_template_version,
        input_artifact_object_key=job.input_artifact_object_key,
        output_artifact_object_key=job.output_artifact_object_key,
        candidate_snapshot_object_key=job.candidate_snapshot_object_key,
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


def _to_candidate_response(
    candidate: AIContentGenerationCandidate,
) -> AIContentGenerationCandidateResponse:
    options = {
        "A": candidate.choice_a,
        "B": candidate.choice_b,
        "C": candidate.choice_c,
        "D": candidate.choice_d,
        "E": candidate.choice_e,
    }
    return AIContentGenerationCandidateResponse(
        id=candidate.id,
        job_id=candidate.job_id,
        candidate_index=candidate.candidate_index,
        status=candidate.status,
        failure_code=candidate.failure_code,
        failure_message=candidate.failure_message,
        track=candidate.track,
        skill=candidate.skill,
        type_tag=candidate.type_tag,
        difficulty=candidate.difficulty,
        source_policy=candidate.source_policy,
        title=candidate.title,
        passage_text=candidate.passage_text,
        transcript_text=candidate.transcript_text,
        turns_json=candidate.turns_json,
        sentences_json=candidate.sentences_json,
        tts_plan_json=candidate.tts_plan_json,
        question_stem=candidate.question_stem,
        options=options,
        answer_key=candidate.answer_key,
        explanation_text=candidate.explanation_text,
        evidence_sentence_ids_json=candidate.evidence_sentence_ids_json,
        why_correct_ko=candidate.why_correct_ko,
        why_wrong_ko_by_option_json=candidate.why_wrong_ko_by_option_json,
        vocab_notes_ko=candidate.vocab_notes_ko,
        structure_notes_ko=candidate.structure_notes_ko,
        review_flags_json=candidate.review_flags_json,
        artifact_prompt_key=candidate.artifact_prompt_key,
        artifact_response_key=candidate.artifact_response_key,
        artifact_candidate_json_key=candidate.artifact_candidate_json_key,
        artifact_validation_report_key=candidate.artifact_validation_report_key,
        materialized_content_unit_id=candidate.materialized_content_unit_id,
        materialized_revision_id=candidate.materialized_revision_id,
        materialized_at=candidate.materialized_at,
        created_at=candidate.created_at,
        updated_at=candidate.updated_at,
    )
