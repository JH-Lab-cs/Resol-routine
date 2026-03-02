from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_parent_user, get_current_student_user, get_db
from app.models.user import User
from app.schemas.reports import DailyReportResponse, MonthlyReportResponse, WeeklyReportResponse
from app.services.report_query_service import (
    ensure_parent_has_active_child_link,
    get_daily_report_for_student,
    get_monthly_report_for_student,
    get_weekly_report_for_student,
)

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/me/daily/{day_key}", response_model=DailyReportResponse)
def get_my_daily_report(
    day_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> DailyReportResponse:
    return get_daily_report_for_student(db, student_id=current_student.id, day_key_value=day_key)


@router.get("/me/weekly/{week_key}", response_model=WeeklyReportResponse)
def get_my_weekly_report(
    week_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> WeeklyReportResponse:
    return get_weekly_report_for_student(db, student_id=current_student.id, week_key_value=week_key)


@router.get("/me/monthly/{period_key}", response_model=MonthlyReportResponse)
def get_my_monthly_report(
    period_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_student: Annotated[User, Depends(get_current_student_user)],
) -> MonthlyReportResponse:
    return get_monthly_report_for_student(
        db,
        student_id=current_student.id,
        period_key_value=period_key,
    )


@router.get("/children/{child_id}/daily/{day_key}", response_model=DailyReportResponse)
def get_child_daily_report(
    child_id: UUID,
    day_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
) -> DailyReportResponse:
    ensure_parent_has_active_child_link(db, parent_id=current_parent.id, child_id=child_id)
    return get_daily_report_for_student(db, student_id=child_id, day_key_value=day_key)


@router.get("/children/{child_id}/weekly/{week_key}", response_model=WeeklyReportResponse)
def get_child_weekly_report(
    child_id: UUID,
    week_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
) -> WeeklyReportResponse:
    ensure_parent_has_active_child_link(db, parent_id=current_parent.id, child_id=child_id)
    return get_weekly_report_for_student(db, student_id=child_id, week_key_value=week_key)


@router.get("/children/{child_id}/monthly/{period_key}", response_model=MonthlyReportResponse)
def get_child_monthly_report(
    child_id: UUID,
    period_key: str,
    db: Annotated[Session, Depends(get_db)],
    current_parent: Annotated[User, Depends(get_current_parent_user)],
) -> MonthlyReportResponse:
    ensure_parent_has_active_child_link(db, parent_id=current_parent.id, child_id=child_id)
    return get_monthly_report_for_student(
        db,
        student_id=child_id,
        period_key_value=period_key,
    )
