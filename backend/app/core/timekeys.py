from __future__ import annotations

from datetime import UTC, datetime
from zoneinfo import ZoneInfo

KST = ZoneInfo("Asia/Seoul")


def to_kst(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        raise ValueError("Datetime must be timezone-aware.")
    return dt.astimezone(KST)


def to_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        raise ValueError("Datetime must be timezone-aware.")
    return dt.astimezone(UTC)


def day_key(dt: datetime) -> str:
    kst = to_kst(dt)
    return kst.strftime("%Y%m%d")


def week_key(dt: datetime) -> str:
    kst = to_kst(dt)
    iso_year, iso_week, _ = kst.isocalendar()
    return f"{iso_year}W{iso_week:02d}"


def period_key(dt: datetime, exam_type: str) -> str:
    normalized = exam_type.upper()
    if normalized == "WEEKLY":
        return week_key(dt)
    if normalized == "MONTHLY":
        return to_kst(dt).strftime("%Y%m")
    raise ValueError(f"Unsupported exam type: {exam_type}")
