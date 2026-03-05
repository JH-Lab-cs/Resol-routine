from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

WrongReasonTagValue = Literal["VOCAB", "EVIDENCE", "INFERENCE", "CARELESS", "TIME"]


class ReportAggregateBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    student_id: UUID
    answered_count: int
    correct_count: int
    wrong_count: int
    wrong_reason_counts: dict[WrongReasonTagValue, int]
    top_wrong_reason_tag: WrongReasonTagValue | None
    first_occurred_at: datetime | None
    last_occurred_at: datetime | None
    aggregated_at: datetime | None


class DailyReportResponse(ReportAggregateBase):
    day_key: str


class WeeklyReportResponse(ReportAggregateBase):
    week_key: str


class MonthlyReportResponse(ReportAggregateBase):
    period_key: str
