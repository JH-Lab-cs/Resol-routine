from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

WrongReasonTagValue = Literal["VOCAB", "EVIDENCE", "INFERENCE", "CARELESS", "TIME"]
ParentReportActivityType = Literal[
    "DAILY",
    "WEEKLY_REPORT",
    "MONTHLY_REPORT",
    "VOCAB",
    "WEEKLY_MOCK",
    "MONTHLY_MOCK",
]


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


class ParentReportChildResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    email: str
    linked_at: datetime


class ParentReportVocabSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    day_key: str
    track: str
    total_count: int
    correct_count: int
    wrong_count: int
    wrong_vocab_count: int
    occurred_at: datetime


class ParentReportMockSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exam_type: Literal["WEEKLY", "MONTHLY"]
    period_key: str
    track: str
    planned_items: int
    completed_items: int
    listening_correct_count: int
    reading_correct_count: int
    wrong_count: int
    occurred_at: datetime


class ParentReportTrendPointResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    day_key: str
    answered_count: int
    correct_count: int
    wrong_count: int
    aggregated_at: datetime | None


class ParentReportActivityResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    activity_type: ParentReportActivityType
    day_key: str | None
    period_key: str | None
    track: str | None
    answered_count: int | None
    correct_count: int | None
    wrong_count: int | None
    occurred_at: datetime | None


class ParentReportSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    child: ParentReportChildResponse
    has_any_report_data: bool
    daily_summary: DailyReportResponse | None
    vocab_summary: ParentReportVocabSummaryResponse | None
    weekly_mock_summary: ParentReportMockSummaryResponse | None
    monthly_mock_summary: ParentReportMockSummaryResponse | None
    recent_activity: list[ParentReportActivityResponse]


class ParentReportDetailResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    child: ParentReportChildResponse
    has_any_report_data: bool
    daily_summary: DailyReportResponse | None
    weekly_summary: WeeklyReportResponse | None
    monthly_summary: MonthlyReportResponse | None
    vocab_summary: ParentReportVocabSummaryResponse | None
    weekly_mock_summary: ParentReportMockSummaryResponse | None
    monthly_mock_summary: ParentReportMockSummaryResponse | None
    recent_trend: list[ParentReportTrendPointResponse]
    recent_activity: list[ParentReportActivityResponse]
