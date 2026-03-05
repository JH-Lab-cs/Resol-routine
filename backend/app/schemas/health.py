from datetime import datetime

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    service: str
    timestamp_utc: datetime
    database: str
    redis: str
