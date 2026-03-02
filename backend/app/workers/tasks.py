from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from app.db.session import SessionLocal
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
