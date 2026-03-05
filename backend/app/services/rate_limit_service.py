from __future__ import annotations

from collections.abc import Sequence

from redis import Redis
from redis.exceptions import RedisError


class RateLimitExceededError(Exception):
    pass


class RateLimiterUnavailableError(Exception):
    pass


class RedisRateLimiter:
    def __init__(self, redis_url: str) -> None:
        self._redis = Redis.from_url(redis_url, decode_responses=True)

    def enforce(self, *, keys: Sequence[str], max_attempts: int, window_seconds: int) -> None:
        try:
            pipeline = self._redis.pipeline()
            for key in keys:
                pipeline.incr(key)
                pipeline.expire(key, window_seconds, nx=True)
            results = pipeline.execute()
        except RedisError as exc:
            raise RateLimiterUnavailableError("Rate limiter backend unavailable") from exc

        for index in range(0, len(results), 2):
            attempts = int(results[index])
            if attempts > max_attempts:
                raise RateLimitExceededError("Rate limit exceeded")
