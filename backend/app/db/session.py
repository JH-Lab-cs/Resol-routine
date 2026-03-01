from collections.abc import Generator
from typing import Any

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


def get_db_session() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
