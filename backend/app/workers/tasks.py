from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="workers.ping")
def ping_worker() -> dict[str, str]:
    executed_at = datetime.now(UTC).isoformat()
    logger.info("Celery ping task executed", extra={"executed_at_utc": executed_at})
    return {"status": "ok", "executed_at_utc": executed_at}


@celery_app.task(name="workers.aggregate_student_events")
def aggregate_student_events(student_id: str) -> dict[str, str]:
    executed_at = datetime.now(UTC).isoformat()
    logger.info(
        "Aggregate student events task scheduled",
        extra={"student_id": student_id, "executed_at_utc": executed_at},
    )
    return {"status": "scheduled", "student_id": student_id, "executed_at_utc": executed_at}


def trigger_student_event_aggregation(*, student_id: UUID) -> None:
    aggregate_student_events.delay(str(student_id))
