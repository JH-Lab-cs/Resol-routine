from datetime import UTC, datetime

from fastapi import APIRouter
from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings
from app.db.health import check_database_connection
from app.schemas.health import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health_check() -> HealthResponse:
    database_ok = check_database_connection()

    redis_client: Redis | None = None
    redis_ok = False
    try:
        redis_client = Redis.from_url(
            settings.redis_url,
            socket_connect_timeout=0.5,
            socket_timeout=0.5,
            decode_responses=True,
        )
        redis_ok = bool(redis_client.ping())
    except RedisError:
        redis_ok = False
    finally:
        if redis_client is not None:
            redis_client.close()

    status = "ok" if database_ok and redis_ok else "degraded"
    return HealthResponse(
        status=status,
        service=settings.app_name,
        timestamp_utc=datetime.now(UTC),
        database="up" if database_ok else "down",
        redis="up" if redis_ok else "down",
    )
