from collections.abc import Generator
import logging
from typing import Any
from uuid import UUID

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
)


@event.listens_for(engine, "connect")
def set_postgres_timezone_utc(dbapi_connection: Any, _connection_record: Any) -> None:
    # Enforce UTC at connection level so persisted timestamps are policy-compliant.
    with dbapi_connection.cursor() as cursor:
        cursor.execute(f"SET TIME ZONE '{settings.db_timezone}'")


SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False, expire_on_commit=False)

POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY = "post_commit_aggregation_student_ids"
logger = logging.getLogger(__name__)


def schedule_student_aggregation_after_commit(db: Session, *, student_id: UUID) -> None:
    pending_student_ids = db.info.get(POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY)
    if pending_student_ids is None:
        pending_student_ids = set()
        db.info[POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY] = pending_student_ids
    pending_student_ids.add(student_id)


def run_post_commit_aggregation_tasks(db: Session) -> None:
    pending_student_ids = db.info.pop(POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY, None)
    if not pending_student_ids:
        return

    from app.workers.tasks import trigger_student_event_aggregation

    for student_id in sorted(pending_student_ids, key=lambda value: str(value)):
        try:
            trigger_student_event_aggregation(student_id=student_id)
        except Exception:
            logger.exception(
                "Failed to enqueue post-commit aggregation trigger",
                extra={"student_id": str(student_id)},
            )


def get_db_session() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
        db.commit()
        run_post_commit_aggregation_tasks(db)
    except Exception:
        db.rollback()
        db.info.pop(POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY, None)
        raise
    finally:
        db.close()
