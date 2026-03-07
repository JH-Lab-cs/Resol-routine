from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from app.db.session import SessionLocal
from app.services.tts_generation_service import run_tts_generation_job
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="workers.generate_tts_audio")  # type: ignore[untyped-decorator]
def generate_tts_audio(job_id: str) -> dict[str, str | int | None]:
    executed_at = datetime.now(UTC).isoformat()
    try:
        parsed_job_id = UUID(job_id)
    except ValueError as exc:
        logger.exception(
            "Invalid tts generation job id for worker task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise ValueError("invalid_tts_job_id") from exc

    db = SessionLocal()
    try:
        execution_result = run_tts_generation_job(db, job_id=parsed_job_id)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception(
            "Failed tts generation task",
            extra={"job_id": job_id, "executed_at_utc": executed_at},
        )
        raise
    finally:
        db.close()

    logger.info(
        "TTS generation task completed",
        extra={
            "job_id": job_id,
            "executed_at_utc": executed_at,
            "job_status": execution_result.status.value,
            "output_asset_id": (
                str(execution_result.output_asset_id)
                if execution_result.output_asset_id is not None
                else None
            ),
            "error_code": execution_result.error_code,
        },
    )
    return {
        "status": execution_result.status.value,
        "job_id": job_id,
        "executed_at_utc": executed_at,
        "output_asset_id": (
            str(execution_result.output_asset_id)
            if execution_result.output_asset_id is not None
            else None
        ),
        "error_code": execution_result.error_code,
    }


def trigger_tts_generation_job(*, job_id: UUID) -> None:
    generate_tts_audio.delay(str(job_id))
