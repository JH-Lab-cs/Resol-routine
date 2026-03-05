from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from app.db.session import SessionLocal
from app.models.enums import AIGenerationJobStatus
from app.services.ai_content_generation_service import run_ai_content_generation_job
from app.services.ai_job_service import run_mock_exam_draft_generation_job
from app.services.report_aggregation_service import recompute_student_reports
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="workers.ping")
def ping_worker() -> dict[str, str]:
    executed_at = datetime.now(UTC).isoformat()
    logger.info("Celery ping task executed", extra={"executed_at_utc": executed_at})
    return {"status": "ok", "executed_at_utc": executed_at}


@celery_app.task(name="workers.aggregate_student_events")
def aggregate_student_events(student_id: str) -> dict[str, str | int]:
    executed_at = datetime.now(UTC).isoformat()
    try:
        parsed_student_id = UUID(student_id)
    except ValueError as exc:
        logger.exception(
            "Invalid student id for aggregation task",
            extra={"student_id": student_id, "executed_at_utc": executed_at},
        )
        raise ValueError("invalid_student_id") from exc

    db = SessionLocal()
    try:
        recompute_result = recompute_student_reports(db, student_id=parsed_student_id)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception(
            "Failed student report aggregation",
            extra={"student_id": student_id, "executed_at_utc": executed_at},
        )
        raise
    finally:
        db.close()

    logger.info(
        "Student report aggregation completed",
        extra={
            "student_id": student_id,
            "executed_at_utc": executed_at,
            "source_event_count": recompute_result.source_event_count,
            "projection_count": recompute_result.projection_count,
            "daily_count": recompute_result.daily_count,
            "weekly_count": recompute_result.weekly_count,
            "monthly_count": recompute_result.monthly_count,
        },
    )
    return {
        "status": "ok",
        "student_id": student_id,
        "executed_at_utc": executed_at,
        "source_event_count": recompute_result.source_event_count,
        "projection_count": recompute_result.projection_count,
        "daily_count": recompute_result.daily_count,
        "weekly_count": recompute_result.weekly_count,
        "monthly_count": recompute_result.monthly_count,
    }


def trigger_student_event_aggregation(*, student_id: UUID) -> None:
    aggregate_student_events.delay(str(student_id))


@celery_app.task(name="workers.generate_mock_exam_revision_draft")
def generate_mock_exam_revision_draft(job_id: str) -> dict[str, str | int | None]:
    executed_at = datetime.now(UTC).isoformat()
    try:
        parsed_job_id = UUID(job_id)
    except ValueError as exc:
        logger.exception(
            "Invalid ai generation job id for worker task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise ValueError("invalid_ai_job_id") from exc

    db = SessionLocal()
    try:
        execution_result = run_mock_exam_draft_generation_job(db, job_id=parsed_job_id)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception(
            "Failed ai draft generation task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise
    finally:
        db.close()

    if execution_result.status == AIGenerationJobStatus.FAILED and execution_result.retry_after_seconds is not None:
        generate_mock_exam_revision_draft.apply_async(
            args=[job_id],
            countdown=execution_result.retry_after_seconds,
        )

    logger.info(
        "AI draft generation task completed",
        extra={
            "job_id": job_id,
            "executed_at_utc": executed_at,
            "job_status": execution_result.status.value,
            "produced_mock_exam_revision_id": (
                str(execution_result.produced_mock_exam_revision_id)
                if execution_result.produced_mock_exam_revision_id is not None
                else None
            ),
            "error_code": execution_result.error_code,
            "retry_after_seconds": execution_result.retry_after_seconds,
        },
    )
    return {
        "status": execution_result.status.value,
        "job_id": job_id,
        "executed_at_utc": executed_at,
        "produced_mock_exam_revision_id": (
            str(execution_result.produced_mock_exam_revision_id)
            if execution_result.produced_mock_exam_revision_id is not None
            else None
        ),
        "error_code": execution_result.error_code,
        "retry_after_seconds": execution_result.retry_after_seconds,
    }


def trigger_ai_generation_job(*, job_id: UUID) -> None:
    generate_mock_exam_revision_draft.delay(str(job_id))


@celery_app.task(name="workers.generate_ai_content_candidates")
def generate_ai_content_candidates(job_id: str) -> dict[str, str | int | None]:
    executed_at = datetime.now(UTC).isoformat()
    try:
        parsed_job_id = UUID(job_id)
    except ValueError as exc:
        logger.exception(
            "Invalid ai content generation job id for worker task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise ValueError("invalid_ai_content_job_id") from exc

    db = SessionLocal()
    try:
        execution_result = run_ai_content_generation_job(db, job_id=parsed_job_id)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception(
            "Failed ai content generation task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise
    finally:
        db.close()

    if execution_result.status == AIGenerationJobStatus.FAILED and execution_result.retry_after_seconds is not None:
        generate_ai_content_candidates.apply_async(
            args=[job_id],
            countdown=execution_result.retry_after_seconds,
        )

    logger.info(
        "AI content generation task completed",
        extra={
            "job_id": job_id,
            "executed_at_utc": executed_at,
            "job_status": execution_result.status.value,
            "error_code": execution_result.error_code,
            "retry_after_seconds": execution_result.retry_after_seconds,
        },
    )
    return {
        "status": execution_result.status.value,
        "job_id": job_id,
        "executed_at_utc": executed_at,
        "error_code": execution_result.error_code,
        "retry_after_seconds": execution_result.retry_after_seconds,
    }


def trigger_ai_content_generation_job(*, job_id: UUID) -> None:
    generate_ai_content_candidates.delay(str(job_id))
