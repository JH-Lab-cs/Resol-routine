from datetime import datetime

from app.core.timekeys import day_key, period_key, week_key


def test_day_key_uses_kst_midnight_boundary() -> None:
    source = datetime.fromisoformat("2026-03-01T15:30:00+00:00")

    assert day_key(source) == "20260302"


def test_week_key_uses_kst_date_for_iso_week() -> None:
    source = datetime.fromisoformat("2026-01-04T16:30:00+00:00")

    assert day_key(source) == "20260105"
    assert week_key(source) == "2026W02"


def test_period_key_supports_weekly_and_monthly_kst_boundary() -> None:
    source = datetime.fromisoformat("2026-01-31T16:00:00+00:00")

    assert period_key(source, "WEEKLY") == "2026W05"
    assert period_key(source, "MONTHLY") == "202602"
