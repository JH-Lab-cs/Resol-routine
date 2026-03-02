# ruff: noqa: E402

import os
from collections.abc import Generator
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

# Test env must be initialized before importing any app package that resolves settings.
os.environ["DATABASE_URL"] = "postgresql+psycopg://resol:resol@localhost:5432/resol_backend"
os.environ["REDIS_URL"] = "redis://localhost:6379/0"
os.environ["JWT_SECRET"] = "unit-test-secret-value-that-is-longer-than-32-chars"
os.environ["R2_ENDPOINT"] = "https://example.r2.cloudflarestorage.com"
os.environ["R2_BUCKET"] = "resol-private-bucket"
os.environ["R2_ACCESS_KEY_ID"] = "unit-test-access-key-id"
os.environ["R2_SECRET_ACCESS_KEY"] = "unit-test-secret-access-key"
os.environ["CONTENT_PIPELINE_API_KEY"] = "unit-test-internal-api-key-value"

from app.core.config import get_settings

get_settings.cache_clear()

import app.models  # noqa: F401
from app.api.dependencies import get_db, get_rate_limiter
from app.db.base import Base
from app.db.session import (
    POST_COMMIT_AGGREGATION_STUDENT_IDS_KEY,
    run_post_commit_aggregation_tasks,
)
from app.main import app
from app.services.rate_limit_service import RateLimitExceededError


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._counters: dict[str, int] = {}

    def enforce(self, *, keys: list[str], max_attempts: int, window_seconds: int) -> None:  # noqa: ARG002
        for key in keys:
            new_count = self._counters.get(key, 0) + 1
            self._counters[key] = new_count
            if new_count > max_attempts:
                raise RateLimitExceededError("Rate limit exceeded")


@pytest.fixture()
def test_app() -> Generator[FastAPI, None, None]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)
    Base.metadata.create_all(bind=engine)

    limiter = InMemoryRateLimiter()

    def override_db() -> Generator[Session, None, None]:
        db = testing_session()
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

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_rate_limiter] = lambda: limiter
    app.state.testing_sessionmaker = testing_session
    yield app
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(test_app: FastAPI) -> Generator[TestClient, None, None]:
    with TestClient(test_app) as http_client:
        yield http_client


@pytest.fixture()
def db_session_factory(test_app: FastAPI) -> Any:
    return test_app.state.testing_sessionmaker
