from __future__ import annotations

import hashlib
import logging
import unicodedata
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, cast
from uuid import UUID

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException, status
from sqlalchemy import or_, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.policies import TTS_ERROR_MESSAGE_MAX_LENGTH, TTS_INPUT_TEXT_MAX_LENGTH
from app.db.session import schedule_tts_generation_job_after_commit
from app.models.content_asset import ContentAsset
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Skill
from app.models.tts_enums import TTSGenerationJobStatus
from app.models.tts_generation_job import TTSGenerationJob
from app.schemas.ai_tts import (
    TTSGenerationEnsureAudioRequest,
    TTSGenerationEnsureAudioResponse,
    TTSGenerationJobCreateRequest,
    TTSGenerationJobResponse,
)
from app.services.ai_artifact_service import ArtifactStoreError, get_ai_artifact_store
from app.services.audit_service import append_audit_log
from app.services.tts_provider import TTSProviderError, build_tts_provider

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class TTSJobExecutionResult:
    job_id: UUID
    status: TTSGenerationJobStatus
    output_asset_id: UUID | None
    error_code: str | None


class TTSGenerationExecutionError(RuntimeError):
    def __init__(self, *, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def create_tts_generation_job(
    db: Session,
    *,
    payload: TTSGenerationJobCreateRequest,
) -> TTSGenerationJobResponse:
    revision, unit, sanitized_text = _get_revision_and_validated_text(
        db,
        revision_id=payload.revision_id,
    )

    active_job = db.execute(
        select(TTSGenerationJob)
        .where(
            TTSGenerationJob.revision_id == revision.id,
            TTSGenerationJob.status.in_(
                [TTSGenerationJobStatus.PENDING, TTSGenerationJobStatus.RUNNING]
            ),
        )
        .order_by(TTSGenerationJob.created_at.desc(), TTSGenerationJob.id.desc())
    ).scalar_one_or_none()
    if active_job is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="tts_job_already_in_progress",
        )

    if revision.asset_id is not None and not payload.force_regen:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="tts_asset_already_exists_use_force_regen",
        )

    input_text_sha256 = hashlib.sha256(sanitized_text.encode("utf-8")).hexdigest()
    job = TTSGenerationJob(
        revision_id=revision.id,
        track=unit.track,
        provider=payload.provider.strip().lower(),
        model_name=payload.model.strip(),
        voice=payload.voice.strip(),
        speed=payload.speed,
        force_regen=payload.force_regen,
        input_text_sha256=input_text_sha256,
        input_text_len=len(sanitized_text),
        status=TTSGenerationJobStatus.PENDING,
        attempts=0,
        error_code=None,
        error_message=None,
        artifact_request_key=None,
        artifact_response_key=None,
        artifact_candidate_key=None,
        artifact_validation_key=None,
        output_asset_id=None,
        output_object_key=None,
        output_bytes=None,
        output_sha256=None,
        started_at=None,
        finished_at=None,
    )
    db.add(job)
    db.flush()

    schedule_tts_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def ensure_tts_audio_for_revision(
    db: Session,
    *,
    revision_id: UUID,
    payload: TTSGenerationEnsureAudioRequest,
) -> TTSGenerationEnsureAudioResponse:
    revision, _, _ = _get_revision_and_validated_text(db, revision_id=revision_id)
    if revision.asset_id is not None and not payload.force_regen:
        return TTSGenerationEnsureAudioResponse(
            created=False,
            revision_id=revision.id,
            existing_asset_id=revision.asset_id,
            job=None,
        )

    active_job = db.execute(
        select(TTSGenerationJob)
        .where(
            TTSGenerationJob.revision_id == revision.id,
            TTSGenerationJob.status.in_(
                [TTSGenerationJobStatus.PENDING, TTSGenerationJobStatus.RUNNING]
            ),
        )
        .order_by(TTSGenerationJob.created_at.desc(), TTSGenerationJob.id.desc())
    ).scalar_one_or_none()
    if active_job is not None:
        return TTSGenerationEnsureAudioResponse(
            created=False,
            revision_id=revision.id,
            existing_asset_id=revision.asset_id,
            job=_to_job_response(active_job),
        )

    created_job = create_tts_generation_job(
        db,
        payload=TTSGenerationJobCreateRequest.model_validate(
            {
                "revisionId": str(revision.id),
                "provider": payload.provider,
                "model": payload.model,
                "voice": payload.voice,
                "speed": payload.speed,
                "forceRegen": payload.force_regen,
            }
        ),
    )
    return TTSGenerationEnsureAudioResponse(
        created=True,
        revision_id=revision.id,
        existing_asset_id=None,
        job=created_job,
    )


def get_tts_generation_job(db: Session, *, job_id: UUID) -> TTSGenerationJobResponse:
    job = db.get(TTSGenerationJob, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="tts_job_not_found")
    return _to_job_response(job)


def retry_tts_generation_job(db: Session, *, job_id: UUID) -> TTSGenerationJobResponse:
    job = _get_job_for_update(db, job_id=job_id)
    if job.status == TTSGenerationJobStatus.RUNNING:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="tts_job_already_running")
    if job.status == TTSGenerationJobStatus.SUCCEEDED:
        return _to_job_response(job)
    if job.status != TTSGenerationJobStatus.FAILED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="tts_job_not_retryable")

    job.status = TTSGenerationJobStatus.PENDING
    job.error_code = None
    job.error_message = None
    job.started_at = None
    job.finished_at = None
    db.flush()

    schedule_tts_generation_job_after_commit(db, job_id=job.id)
    return _to_job_response(job)


def run_tts_generation_job(db: Session, *, job_id: UUID) -> TTSJobExecutionResult:
    execution_result = cast(
        CursorResult[Any],
        db.execute(
            update(TTSGenerationJob)
            .where(
                TTSGenerationJob.id == job_id,
                or_(
                    TTSGenerationJob.status == TTSGenerationJobStatus.PENDING,
                    TTSGenerationJob.status == TTSGenerationJobStatus.FAILED,
                ),
            )
            .values(
                status=TTSGenerationJobStatus.RUNNING,
                started_at=datetime.now(UTC),
                finished_at=None,
                attempts=TTSGenerationJob.attempts + 1,
                error_code=None,
                error_message=None,
            )
        ),
    )
    claimed_rows = int(execution_result.rowcount)
    if claimed_rows == 0:
        existing = db.get(TTSGenerationJob, job_id)
        if existing is None:
            raise ValueError("tts_job_not_found")
        return TTSJobExecutionResult(
            job_id=existing.id,
            status=existing.status,
            output_asset_id=existing.output_asset_id,
            error_code=existing.error_code,
        )

    job = _get_job_for_update(db, job_id=job_id)
    if job.output_asset_id is not None and job.status == TTSGenerationJobStatus.SUCCEEDED:
        return TTSJobExecutionResult(
            job_id=job.id,
            status=job.status,
            output_asset_id=job.output_asset_id,
            error_code=None,
        )

    try:
        revision, unit, sanitized_text = _get_revision_and_validated_text(
            db,
            revision_id=job.revision_id,
        )
        if unit.track != job.track:
            raise TTSGenerationExecutionError(
                code="VALIDATION_FAILED",
                message="revision_track_mismatch",
            )

        provider = build_tts_provider(
            provider=job.provider,
            model=job.model_name,
            voice=job.voice,
            speed=job.speed,
        )
        provider_result = provider.synthesize(text=sanitized_text)

        artifact_store = get_ai_artifact_store()
        request_artifact_key = artifact_store.put_text_with_object_key(
            object_key=_build_tts_artifact_key(job_id=job.id, filename="request.json"),
            body=provider_result.raw_request,
            content_type="application/json",
        )
        response_artifact_key = artifact_store.put_text_with_object_key(
            object_key=_build_tts_artifact_key(job_id=job.id, filename="response.json"),
            body=provider_result.raw_response,
            content_type="application/json",
        )
        candidate_artifact_key = artifact_store.put_json_with_object_key(
            object_key=_build_tts_artifact_key(job_id=job.id, filename="candidate.json"),
            payload={
                "jobId": str(job.id),
                "revisionId": str(revision.id),
                "provider": provider_result.provider_name,
                "model": provider_result.model_name,
                "voice": provider_result.voice,
                "speed": provider_result.speed,
                "track": unit.track.value,
                "inputTextSha256": hashlib.sha256(sanitized_text.encode("utf-8")).hexdigest(),
                "inputTextLen": len(sanitized_text),
            },
        )
        validation_artifact_key = artifact_store.put_json_with_object_key(
            object_key=_build_tts_artifact_key(job_id=job.id, filename="validation.json"),
            payload={
                "revisionLifecycleStatus": revision.lifecycle_status.value,
                "skill": unit.skill.value,
                "track": unit.track.value,
                "hiddenUnicodeCheck": "passed",
                "inputTextLengthCheck": "passed",
            },
        )

        output_sha256 = hashlib.sha256(provider_result.audio_bytes).hexdigest()
        output_object_key = _build_tts_output_object_key(
            revision_id=revision.id,
            job_id=job.id,
            output_sha256=output_sha256,
        )
        output_etag = _upload_audio_object_to_r2(
            object_key=output_object_key,
            body=provider_result.audio_bytes,
            mime_type=provider_result.mime_type,
        )

        try:
            with db.begin_nested():
                asset = ContentAsset(
                    object_key=output_object_key,
                    mime_type=provider_result.mime_type,
                    size_bytes=len(provider_result.audio_bytes),
                    sha256_hex=output_sha256,
                    etag=output_etag,
                    bucket=settings.r2_bucket,
                )
                db.add(asset)
                db.flush()

                revision.asset_id = asset.id
                revision.metadata_json = _merge_tts_metadata(
                    metadata_json=revision.metadata_json,
                    job_id=job.id,
                    asset_id=asset.id,
                    provider_name=provider_result.provider_name,
                    model_name=provider_result.model_name,
                    voice=provider_result.voice,
                    speed=provider_result.speed,
                    input_text_sha256=job.input_text_sha256,
                    output_object_key=output_object_key,
                )

                job.output_asset_id = asset.id
                job.output_object_key = output_object_key
                job.output_bytes = len(provider_result.audio_bytes)
                job.output_sha256 = output_sha256
        except Exception as exc:
            raise TTSGenerationExecutionError(
                code="DRAFT_PERSIST_FAILED",
                message=str(exc),
            ) from exc

        job.artifact_request_key = request_artifact_key
        job.artifact_response_key = response_artifact_key
        job.artifact_candidate_key = candidate_artifact_key
        job.artifact_validation_key = validation_artifact_key
        job.status = TTSGenerationJobStatus.SUCCEEDED
        job.error_code = None
        job.error_message = None
        job.finished_at = datetime.now(UTC)
        db.flush()

        append_audit_log(
            db,
            action="tts_generation_job_succeeded",
            actor_user_id=None,
            target_user_id=None,
            details={
                "job_id": str(job.id),
                "revision_id": str(job.revision_id),
                "output_asset_id": (
                    str(job.output_asset_id)
                    if job.output_asset_id is not None
                    else None
                ),
            },
        )

        return TTSJobExecutionResult(
            job_id=job.id,
            status=job.status,
            output_asset_id=job.output_asset_id,
            error_code=None,
        )
    except TTSGenerationExecutionError as exc:
        _mark_job_failed(job, code=exc.code, message=exc.message)
    except TTSProviderError as exc:
        _mark_job_failed(job, code=exc.code, message=exc.message)
    except ArtifactStoreError as exc:
        _mark_job_failed(job, code="ARTIFACT_UPLOAD_FAILED", message=exc.message)
    except ClientError:
        _mark_job_failed(
            job,
            code="DRAFT_PERSIST_FAILED",
            message="audio_upload_failed",
        )
    except Exception as exc:  # pragma: no cover - defensive fallback
        logger.exception(
            "Unexpected TTS generation failure",
            extra={"job_id": str(job.id)},
        )
        _mark_job_failed(job, code="DRAFT_PERSIST_FAILED", message=str(exc))

    db.flush()
    append_audit_log(
        db,
        action="tts_generation_job_failed",
        actor_user_id=None,
        target_user_id=None,
        details={
            "job_id": str(job.id),
            "revision_id": str(job.revision_id),
            "error_code": job.error_code,
        },
    )
    return TTSJobExecutionResult(
        job_id=job.id,
        status=job.status,
        output_asset_id=job.output_asset_id,
        error_code=job.error_code,
    )


def _mark_job_failed(job: TTSGenerationJob, *, code: str, message: str) -> None:
    job.status = TTSGenerationJobStatus.FAILED
    job.error_code = code[:64]
    job.error_message = message[:TTS_ERROR_MESSAGE_MAX_LENGTH]
    job.finished_at = datetime.now(UTC)


def _get_job_for_update(db: Session, *, job_id: UUID) -> TTSGenerationJob:
    row = (
        db.query(TTSGenerationJob)
        .filter(TTSGenerationJob.id == job_id)
        .with_for_update()
        .one_or_none()
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="tts_job_not_found")
    return row


def _get_revision_and_validated_text(
    db: Session,
    *,
    revision_id: UUID,
) -> tuple[ContentUnitRevision, ContentUnit, str]:
    revision = (
        db.query(ContentUnitRevision)
        .filter(ContentUnitRevision.id == revision_id)
        .with_for_update()
        .one_or_none()
    )
    if revision is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="content_revision_not_found",
        )

    unit = db.get(ContentUnit, revision.content_unit_id)
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="content_unit_not_found")
    if unit.skill != Skill.LISTENING:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="listening_skill_required")
    if revision.lifecycle_status != ContentLifecycleStatus.DRAFT:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="revision_not_draft")

    sanitized_text = _sanitize_tts_input_text(revision.transcript_text)
    return revision, unit, sanitized_text


def _sanitize_tts_input_text(value: str | None) -> str:
    if value is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="transcript_text_required",
        )

    normalized = value.strip()
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="transcript_text_required",
        )
    if len(normalized) > TTS_INPUT_TEXT_MAX_LENGTH:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="transcript_text_too_long",
        )

    for char in normalized:
        category = unicodedata.category(char)
        if category == "Cf":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="invalid_hidden_unicode",
            )
        if category == "Cc" and char not in {"\n", "\r", "\t"}:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="invalid_hidden_unicode",
            )
    return normalized


def _build_tts_artifact_key(*, job_id: UUID, filename: str) -> str:
    return f"ai-artifacts/tts/jobs/{job_id}/{filename}"


def _build_tts_output_object_key(*, revision_id: UUID, job_id: UUID, output_sha256: str) -> str:
    now = datetime.now(UTC)
    date_part = now.strftime("%Y/%m/%d")
    return f"content-assets/tts/{date_part}/{revision_id}/{job_id}-{output_sha256[:16]}.mp3"


def _upload_audio_object_to_r2(*, object_key: str, body: bytes, mime_type: str) -> str | None:
    client = boto3.client(
        "s3",
        endpoint_url=settings.r2_endpoint,
        aws_access_key_id=settings.r2_access_key_id,
        aws_secret_access_key=settings.r2_secret_access_key,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )
    response = client.put_object(
        Bucket=settings.r2_bucket,
        Key=object_key,
        Body=body,
        ContentType=mime_type,
    )
    etag = response.get("ETag")
    if not isinstance(etag, str):
        return None
    return etag.strip().strip('"')


def _merge_tts_metadata(
    *,
    metadata_json: object,
    job_id: UUID,
    asset_id: UUID,
    provider_name: str,
    model_name: str,
    voice: str,
    speed: float,
    input_text_sha256: str,
    output_object_key: str,
) -> dict[str, object]:
    merged: dict[str, object] = dict(metadata_json) if isinstance(metadata_json, dict) else {}
    merged["tts"] = {
        "generationJobId": str(job_id),
        "assetId": str(asset_id),
        "provider": provider_name,
        "model": model_name,
        "voice": voice,
        "speed": speed,
        "inputTextSha256": input_text_sha256,
        "outputObjectKey": output_object_key,
        "generatedAt": datetime.now(UTC).isoformat(),
    }
    return merged


def _to_job_response(job: TTSGenerationJob) -> TTSGenerationJobResponse:
    return TTSGenerationJobResponse(
        id=job.id,
        revision_id=job.revision_id,
        track=job.track,
        provider=job.provider,
        model_name=job.model_name,
        voice=job.voice,
        speed=job.speed,
        force_regen=job.force_regen,
        input_text_sha256=job.input_text_sha256,
        input_text_len=job.input_text_len,
        status=job.status,
        attempts=job.attempts,
        error_code=job.error_code,
        error_message=job.error_message,
        artifact_request_key=job.artifact_request_key,
        artifact_response_key=job.artifact_response_key,
        artifact_candidate_key=job.artifact_candidate_key,
        artifact_validation_key=job.artifact_validation_key,
        output_asset_id=job.output_asset_id,
        output_object_key=job.output_object_key,
        output_bytes=job.output_bytes,
        output_sha256=job.output_sha256,
        created_at=job.created_at,
        started_at=job.started_at,
        finished_at=job.finished_at,
        updated_at=job.updated_at,
    )
