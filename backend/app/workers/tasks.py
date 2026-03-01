from __future__ import annotations

import logging
from datetime import UTC, datetime

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="workers.ping")
def ping_worker() -> dict[str, str]:
    executed_at = datetime.now(UTC).isoformat()
    logger.info("Celery ping task executed", extra={"executed_at_utc": executed_at})
    return {"status": "ok", "executed_at_utc": executed_at}
