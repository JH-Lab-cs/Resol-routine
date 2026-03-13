from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select

import app.workers.tasks as worker_tasks
from app.core.timekeys import day_key, to_kst, week_key
from app.models.daily_report_aggregate import DailyReportAggregate
from app.models.enums import SubscriptionFeatureCode, SubscriptionPlanStatus, UserSubscriptionStatus
from app.models.monthly_report_aggregate import MonthlyReportAggregate
from app.models.parent_child_link import ParentChildLink
from app.models.student_attempt_projection import StudentAttemptProjection
from app.models.study_event import StudyEvent
from app.models.subscription_plan import SubscriptionPlan
from app.models.subscription_plan_feature import SubscriptionPlanFeature
from app.models.user_subscription import UserSubscription
from app.models.weekly_report_aggregate import WeeklyReportAggregate
from app.services.report_aggregation_service import recompute_student_reports


def _default_test_password() -> str:
    return "SecurePass" + "123!"


def _register_user(
    client: TestClient,
    *,
    role: str,
    email: str,
    password: str | None = None,
    device_id: str = "device-1",
) -> dict[str, object]:
    effective_password = password or _default_test_password()
    response = client.post(
        f"/auth/register/{role}",
        json={
            "email": email,
            "password": effective_password,
            "device_id": device_id,
        },
        headers={"x-forwarded-for": "203.0.113.10", "user-agent": "pytest-agent"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _student_headers(token: str) -> dict[str, str]:
    return {
        "authorization": f"Bearer {token}",
        "x-forwarded-for": "203.0.113.11",
        "user-agent": "pytest-agent",
    }


def _parent_headers(token: str) -> dict[str, str]:
    return {
        "authorization": f"Bearer {token}",
        "x-forwarded-for": "203.0.113.12",
        "user-agent": "pytest-agent",
    }


def _grant_parent_entitlements(
    db_session_factory,
    *,
    parent_id: UUID,
    feature_codes: set[SubscriptionFeatureCode],
) -> None:
    seed = uuid4().hex[:8]
    with db_session_factory() as db:
        plan = SubscriptionPlan(
            plan_code=f"report-plan-{seed}",
            display_name=f"Report Plan {seed}",
            status=SubscriptionPlanStatus.ACTIVE,
            metadata_json={"seed": seed},
        )
        db.add(plan)
        db.flush()

        for feature_code in feature_codes:
            db.add(
                SubscriptionPlanFeature(
                    subscription_plan_id=plan.id,
                    feature_code=feature_code,
                )
            )

        now = datetime.now(UTC)
        db.add(
            UserSubscription(
                owner_user_id=parent_id,
                subscription_plan_id=plan.id,
                status=UserSubscriptionStatus.ACTIVE,
                starts_at=now - timedelta(days=1),
                ends_at=now + timedelta(days=30),
                grace_ends_at=None,
                canceled_at=None,
                external_billing_ref=None,
                metadata_json={"seed": seed},
            )
        )
        db.commit()


def _insert_today_event(
    db_session_factory,
    *,
    student_id: UUID,
    idempotency_key: str,
    occurred_at_client: datetime,
    session_id: int,
    question_id: str,
    selected_answer: str,
    is_correct: bool,
    wrong_reason_tag: str | None,
) -> None:
    with db_session_factory() as db:
        db.add(
            StudyEvent(
                student_id=student_id,
                event_type="TODAY_ATTEMPT_SAVED",
                schema_version=1,
                device_id="ios-device-1",
                occurred_at_client=occurred_at_client,
                idempotency_key=idempotency_key,
                payload={
                    "sessionId": session_id,
                    "questionId": question_id,
                    "selectedAnswer": selected_answer,
                    "isCorrect": is_correct,
                    "wrongReasonTag": wrong_reason_tag,
                },
            )
        )
        db.commit()


def _insert_mock_event(
    db_session_factory,
    *,
    student_id: UUID,
    idempotency_key: str,
    occurred_at_client: datetime,
    mock_session_id: int,
    question_id: str,
    selected_answer: str,
    is_correct: bool,
    wrong_reason_tag: str | None,
) -> None:
    with db_session_factory() as db:
        db.add(
            StudyEvent(
                student_id=student_id,
                event_type="MOCK_EXAM_ATTEMPT_SAVED",
                schema_version=1,
                device_id="ios-device-1",
                occurred_at_client=occurred_at_client,
                idempotency_key=idempotency_key,
                payload={
                    "mockSessionId": mock_session_id,
                    "questionId": question_id,
                    "selectedAnswer": selected_answer,
                    "isCorrect": is_correct,
                    "wrongReasonTag": wrong_reason_tag,
                },
            )
        )
        db.commit()


def _insert_vocab_completed_event(
    db_session_factory,
    *,
    student_id: UUID,
    idempotency_key: str,
    occurred_at_client: datetime,
    day_key_value: str,
    track: str,
    total_count: int,
    correct_count: int,
    wrong_vocab_ids: list[str],
) -> None:
    with db_session_factory() as db:
        db.add(
            StudyEvent(
                student_id=student_id,
                event_type="VOCAB_QUIZ_COMPLETED",
                schema_version=1,
                device_id="ios-device-1",
                occurred_at_client=occurred_at_client,
                idempotency_key=idempotency_key,
                payload={
                    "dayKey": day_key_value,
                    "track": track,
                    "totalCount": total_count,
                    "correctCount": correct_count,
                    "wrongVocabIds": wrong_vocab_ids,
                },
            )
        )
        db.commit()


def _insert_mock_completed_event(
    db_session_factory,
    *,
    student_id: UUID,
    idempotency_key: str,
    occurred_at_client: datetime,
    mock_session_id: int,
    exam_type: str,
    period_key_value: str,
    track: str,
    planned_items: int,
    completed_items: int,
    listening_correct_count: int,
    reading_correct_count: int,
    wrong_count: int,
) -> None:
    with db_session_factory() as db:
        db.add(
            StudyEvent(
                student_id=student_id,
                event_type="MOCK_EXAM_COMPLETED",
                schema_version=1,
                device_id="ios-device-1",
                occurred_at_client=occurred_at_client,
                idempotency_key=idempotency_key,
                payload={
                    "mockSessionId": mock_session_id,
                    "examType": exam_type,
                    "periodKey": period_key_value,
                    "track": track,
                    "plannedItems": planned_items,
                    "completedItems": completed_items,
                    "listeningCorrectCount": listening_correct_count,
                    "readingCorrectCount": reading_correct_count,
                    "wrongCount": wrong_count,
                },
            )
        )
        db.commit()


def _recompute(db_session_factory, *, student_id: UUID):
    with db_session_factory() as db:
        result = recompute_student_reports(db, student_id=student_id)
        db.commit()
    return result


def test_single_student_recompute_success(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="agg-single@example.com")
    student_id = UUID(str(student["user"]["id"]))

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-single-1",
        occurred_at_client=datetime.fromisoformat("2026-03-02T00:30:00+09:00"),
        session_id=101,
        question_id="q_001",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_mock_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-single-2",
        occurred_at_client=datetime.fromisoformat("2026-03-02T00:35:00+09:00"),
        mock_session_id=55,
        question_id="mq_010",
        selected_answer="C",
        is_correct=False,
        wrong_reason_tag="EVIDENCE",
    )

    result = _recompute(db_session_factory, student_id=student_id)
    assert result.source_event_count == 2
    assert result.projection_count == 2
    assert result.daily_count == 1
    assert result.weekly_count == 1
    assert result.monthly_count == 1

    with db_session_factory() as db:
        daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    assert daily.answered_count == 2
    assert daily.correct_count == 1
    assert daily.wrong_count == 1
    assert daily.wrong_reason_counts["EVIDENCE"] == 1


def test_projection_latest_wins_same_logical_attempt(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="agg-latest-wins@example.com")
    student_id = UUID(str(student["user"]["id"]))

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-latest-1",
        occurred_at_client=datetime.fromisoformat("2026-03-02T01:00:00+09:00"),
        session_id=201,
        question_id="q_same",
        selected_answer="B",
        is_correct=False,
        wrong_reason_tag="VOCAB",
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-latest-2",
        occurred_at_client=datetime.fromisoformat("2026-03-02T01:05:00+09:00"),
        session_id=201,
        question_id="q_same",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        projection = db.execute(
            select(StudentAttemptProjection).where(
                StudentAttemptProjection.student_id == student_id,
                StudentAttemptProjection.event_type == "TODAY_ATTEMPT_SAVED",
                StudentAttemptProjection.session_id == 201,
                StudentAttemptProjection.question_id == "q_same",
            )
        ).scalar_one()
        daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    assert projection.selected_answer == "A"
    assert projection.is_correct is True
    assert projection.wrong_reason_tag is None
    assert daily.answered_count == 1
    assert daily.correct_count == 1
    assert daily.wrong_count == 0


def test_wrong_to_correct_and_correct_to_wrong_adjusts_aggregate(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="agg-directional@example.com")
    student_id = UUID(str(student["user"]["id"]))

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-dir-1",
        occurred_at_client=datetime.fromisoformat("2026-03-02T02:00:00+09:00"),
        session_id=301,
        question_id="q_wrong_to_correct",
        selected_answer="C",
        is_correct=False,
        wrong_reason_tag="TIME",
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-dir-2",
        occurred_at_client=datetime.fromisoformat("2026-03-02T02:05:00+09:00"),
        session_id=301,
        question_id="q_wrong_to_correct",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-dir-3",
        occurred_at_client=datetime.fromisoformat("2026-03-02T02:10:00+09:00"),
        session_id=301,
        question_id="q_correct_to_wrong",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-dir-4",
        occurred_at_client=datetime.fromisoformat("2026-03-02T02:12:00+09:00"),
        session_id=301,
        question_id="q_correct_to_wrong",
        selected_answer="D",
        is_correct=False,
        wrong_reason_tag="CARELESS",
    )

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    assert daily.answered_count == 2
    assert daily.correct_count == 1
    assert daily.wrong_count == 1
    assert daily.wrong_reason_counts["CARELESS"] == 1
    assert daily.wrong_reason_counts["TIME"] == 0


def test_recompute_twice_is_deterministic(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="agg-deterministic@example.com")
    student_id = UUID(str(student["user"]["id"]))

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-det-1",
        occurred_at_client=datetime.fromisoformat("2026-03-02T03:00:00+09:00"),
        session_id=401,
        question_id="q_001",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_mock_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-det-2",
        occurred_at_client=datetime.fromisoformat("2026-03-02T03:05:00+09:00"),
        mock_session_id=77,
        question_id="mq_001",
        selected_answer="B",
        is_correct=False,
        wrong_reason_tag="VOCAB",
    )

    _recompute(db_session_factory, student_id=student_id)
    with db_session_factory() as db:
        first_projection = db.execute(
            select(StudentAttemptProjection)
            .where(StudentAttemptProjection.student_id == student_id)
            .order_by(StudentAttemptProjection.id.asc())
        ).scalars().all()
        first_daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    _recompute(db_session_factory, student_id=student_id)
    with db_session_factory() as db:
        second_projection = db.execute(
            select(StudentAttemptProjection)
            .where(StudentAttemptProjection.student_id == student_id)
            .order_by(StudentAttemptProjection.id.asc())
        ).scalars().all()
        second_daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    first_projection_view = [
        (
            row.event_type,
            row.session_id,
            row.mock_session_id,
            row.question_id,
            row.selected_answer,
            row.is_correct,
            row.wrong_reason_tag,
            row.latest_event_id,
            row.day_key,
            row.week_key,
            row.period_key,
        )
        for row in first_projection
    ]
    second_projection_view = [
        (
            row.event_type,
            row.session_id,
            row.mock_session_id,
            row.question_id,
            row.selected_answer,
            row.is_correct,
            row.wrong_reason_tag,
            row.latest_event_id,
            row.day_key,
            row.week_key,
            row.period_key,
        )
        for row in second_projection
    ]
    assert first_projection_view == second_projection_view

    first_daily_view = (
        first_daily.day_key,
        first_daily.answered_count,
        first_daily.correct_count,
        first_daily.wrong_count,
        first_daily.wrong_reason_counts,
        first_daily.top_wrong_reason_tag,
        first_daily.first_occurred_at,
        first_daily.last_occurred_at,
        first_daily.aggregated_at,
    )
    second_daily_view = (
        second_daily.day_key,
        second_daily.answered_count,
        second_daily.correct_count,
        second_daily.wrong_count,
        second_daily.wrong_reason_counts,
        second_daily.top_wrong_reason_tag,
        second_daily.first_occurred_at,
        second_daily.last_occurred_at,
        second_daily.aggregated_at,
    )
    assert first_daily_view == second_daily_view


def test_kst_day_week_period_keys_use_projection_latest_occurred_at(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="agg-kst-keys@example.com")
    student_id = UUID(str(student["user"]["id"]))

    day_boundary = datetime.fromisoformat("2026-03-01T15:30:00+00:00")
    week_boundary = datetime.fromisoformat("2026-01-04T16:30:00+00:00")
    period_boundary = datetime.fromisoformat("2026-01-31T16:00:00+00:00")

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-kst-day",
        occurred_at_client=day_boundary,
        session_id=501,
        question_id="q_day",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-kst-week",
        occurred_at_client=week_boundary,
        session_id=501,
        question_id="q_week",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_mock_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-kst-period",
        occurred_at_client=period_boundary,
        mock_session_id=88,
        question_id="mq_period",
        selected_answer="B",
        is_correct=False,
        wrong_reason_tag="EVIDENCE",
    )

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        day_projection = db.execute(
            select(StudentAttemptProjection).where(
                StudentAttemptProjection.student_id == student_id,
                StudentAttemptProjection.question_id == "q_day",
            )
        ).scalar_one()
        week_projection = db.execute(
            select(StudentAttemptProjection).where(
                StudentAttemptProjection.student_id == student_id,
                StudentAttemptProjection.question_id == "q_week",
            )
        ).scalar_one()
        period_projection = db.execute(
            select(StudentAttemptProjection).where(
                StudentAttemptProjection.student_id == student_id,
                StudentAttemptProjection.question_id == "mq_period",
            )
        ).scalar_one()

    assert day_projection.day_key == "20260302"
    assert week_projection.week_key == "2026W02"
    assert period_projection.period_key == "202602"


def test_wrong_reason_counts_zero_filled_and_top_tag_tie_break(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="agg-wrong-reason@example.com")
    student_id = UUID(str(student["user"]["id"]))
    occurred_at = datetime.fromisoformat("2026-03-02T04:00:00+09:00")

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-wrong-1",
        occurred_at_client=occurred_at,
        session_id=601,
        question_id="q_1",
        selected_answer="B",
        is_correct=False,
        wrong_reason_tag="CARELESS",
    )
    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-wrong-2",
        occurred_at_client=occurred_at,
        session_id=601,
        question_id="q_2",
        selected_answer="B",
        is_correct=False,
        wrong_reason_tag="EVIDENCE",
    )

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()

    assert set(daily.wrong_reason_counts.keys()) == {
        "VOCAB",
        "EVIDENCE",
        "INFERENCE",
        "CARELESS",
        "TIME",
    }
    assert daily.wrong_reason_counts["VOCAB"] == 0
    assert daily.wrong_reason_counts["INFERENCE"] == 0
    assert daily.wrong_reason_counts["TIME"] == 0
    assert daily.wrong_reason_counts["CARELESS"] == 1
    assert daily.wrong_reason_counts["EVIDENCE"] == 1
    assert daily.top_wrong_reason_tag == "CARELESS"


def test_report_read_apis_for_student_and_parent(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="agg-api-student@example.com")
    parent = _register_user(client, role="parent", email="agg-api-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))
    occurred_at = datetime.fromisoformat("2026-03-03T10:00:00+09:00")

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=student_id))
        db.commit()
    _grant_parent_entitlements(
        db_session_factory,
        parent_id=parent_id,
        feature_codes={SubscriptionFeatureCode.CHILD_REPORTS},
    )

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="agg-api-1",
        occurred_at_client=occurred_at,
        session_id=701,
        question_id="q_api",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _recompute(db_session_factory, student_id=student_id)

    day = day_key(occurred_at)
    week = week_key(occurred_at)
    period = to_kst(occurred_at).strftime("%Y%m")

    student_daily = client.get(
        f"/reports/me/daily/{day}",
        headers=_student_headers(str(student["access_token"])),
    )
    student_weekly = client.get(
        f"/reports/me/weekly/{week}",
        headers=_student_headers(str(student["access_token"])),
    )
    student_monthly = client.get(
        f"/reports/me/monthly/{period}",
        headers=_student_headers(str(student["access_token"])),
    )
    assert student_daily.status_code == 200, student_daily.text
    assert student_weekly.status_code == 200, student_weekly.text
    assert student_monthly.status_code == 200, student_monthly.text
    assert student_daily.json()["answered_count"] == 1

    parent_daily = client.get(
        f"/reports/children/{student_id}/daily/{day}",
        headers=_parent_headers(str(parent["access_token"])),
    )
    parent_weekly = client.get(
        f"/reports/children/{student_id}/weekly/{week}",
        headers=_parent_headers(str(parent["access_token"])),
    )
    parent_monthly = client.get(
        f"/reports/children/{student_id}/monthly/{period}",
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert parent_daily.status_code == 200, parent_daily.text
    assert parent_weekly.status_code == 200, parent_weekly.text
    assert parent_monthly.status_code == 200, parent_monthly.text


def test_parent_report_summary_and_detail_endpoints(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="parent-summary-student@example.com")
    parent = _register_user(client, role="parent", email="parent-summary-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))
    occurred_at = datetime.fromisoformat("2026-03-03T10:00:00+09:00")

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=student_id))
        db.commit()
    _grant_parent_entitlements(
        db_session_factory,
        parent_id=parent_id,
        feature_codes={SubscriptionFeatureCode.CHILD_REPORTS},
    )

    _insert_today_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="parent-summary-daily",
        occurred_at_client=occurred_at,
        session_id=901,
        question_id="q_parent_summary",
        selected_answer="A",
        is_correct=True,
        wrong_reason_tag=None,
    )
    _insert_vocab_completed_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="parent-summary-vocab",
        occurred_at_client=occurred_at + timedelta(minutes=5),
        day_key_value="20260303",
        track="H1",
        total_count=10,
        correct_count=8,
        wrong_vocab_ids=["vocab-1", "vocab-2"],
    )
    _insert_mock_completed_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="parent-summary-weekly",
        occurred_at_client=occurred_at + timedelta(minutes=10),
        mock_session_id=99,
        exam_type="WEEKLY",
        period_key_value="2026W10",
        track="H1",
        planned_items=20,
        completed_items=20,
        listening_correct_count=8,
        reading_correct_count=7,
        wrong_count=5,
    )
    _insert_mock_completed_event(
        db_session_factory,
        student_id=student_id,
        idempotency_key="parent-summary-monthly",
        occurred_at_client=occurred_at + timedelta(minutes=15),
        mock_session_id=100,
        exam_type="MONTHLY",
        period_key_value="202603",
        track="H1",
        planned_items=45,
        completed_items=45,
        listening_correct_count=16,
        reading_correct_count=20,
        wrong_count=9,
    )
    _recompute(db_session_factory, student_id=student_id)

    summary_response = client.get(
        f"/reports/children/{student_id}/summary",
        headers=_parent_headers(str(parent["access_token"])),
    )
    detail_response = client.get(
        f"/reports/children/{student_id}/detail",
        headers=_parent_headers(str(parent["access_token"])),
    )

    assert summary_response.status_code == 200, summary_response.text
    assert detail_response.status_code == 200, detail_response.text

    summary_body = summary_response.json()
    detail_body = detail_response.json()

    assert summary_body["child"]["id"] == str(student_id)
    assert summary_body["has_any_report_data"] is True
    assert summary_body["daily_summary"]["answered_count"] == 1
    assert summary_body["vocab_summary"]["correct_count"] == 8
    assert summary_body["weekly_mock_summary"]["exam_type"] == "WEEKLY"
    assert summary_body["monthly_mock_summary"]["exam_type"] == "MONTHLY"
    assert len(summary_body["recent_activity"]) >= 1

    assert detail_body["weekly_summary"]["answered_count"] == 1
    assert detail_body["monthly_summary"]["answered_count"] == 1
    assert detail_body["recent_trend"][0]["day_key"] == "20260303"
    assert len(detail_body["recent_activity"]) >= 1


def test_parent_report_summary_and_detail_return_empty_payload_when_child_has_no_data(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="parent-empty-student@example.com")
    parent = _register_user(client, role="parent", email="parent-empty-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=student_id))
        db.commit()
    _grant_parent_entitlements(
        db_session_factory,
        parent_id=parent_id,
        feature_codes={SubscriptionFeatureCode.CHILD_REPORTS},
    )

    summary_response = client.get(
        f"/reports/children/{student_id}/summary",
        headers=_parent_headers(str(parent["access_token"])),
    )
    detail_response = client.get(
        f"/reports/children/{student_id}/detail",
        headers=_parent_headers(str(parent["access_token"])),
    )

    assert summary_response.status_code == 200, summary_response.text
    assert detail_response.status_code == 200, detail_response.text
    assert summary_response.json()["has_any_report_data"] is False
    assert summary_response.json()["daily_summary"] is None
    assert detail_response.json()["recent_trend"] == []
    assert detail_response.json()["recent_activity"] == []


def test_report_read_forbidden_for_unrelated_or_unlinked_parent(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(
        client,
        role="student",
        email="agg-forbidden-student@example.com",
    )
    linked_parent = _register_user(client, role="parent", email="agg-forbidden-linked@example.com")
    unrelated_parent = _register_user(
        client,
        role="parent",
        email="agg-forbidden-unrelated@example.com",
    )
    student_id = UUID(str(student["user"]["id"]))
    linked_parent_id = UUID(str(linked_parent["user"]["id"]))
    day = "20260302"

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=linked_parent_id, child_id=student_id))
        db.commit()

    unrelated_response = client.get(
        f"/reports/children/{student_id}/daily/{day}",
        headers=_parent_headers(str(unrelated_parent["access_token"])),
    )
    assert unrelated_response.status_code == 403
    assert unrelated_response.json()["detail"] == "child_report_access_forbidden"

    with db_session_factory() as db:
        active_link = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == linked_parent_id,
                ParentChildLink.child_id == student_id,
                ParentChildLink.unlinked_at.is_(None),
            )
        ).scalar_one()
        active_link.unlinked_at = datetime.now(UTC)
        db.commit()

    unlinked_response = client.get(
        f"/reports/children/{student_id}/daily/{day}",
        headers=_parent_headers(str(linked_parent["access_token"])),
    )
    assert unlinked_response.status_code == 403
    assert unlinked_response.json()["detail"] == "child_report_access_forbidden"


def test_empty_period_returns_zero_filled_response(client: TestClient) -> None:
    student = _register_user(client, role="student", email="agg-empty-period@example.com")

    response = client.get(
        "/reports/me/daily/20260302",
        headers=_student_headers(str(student["access_token"])),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["day_key"] == "20260302"
    assert body["answered_count"] == 0
    assert body["correct_count"] == 0
    assert body["wrong_count"] == 0
    assert body["top_wrong_reason_tag"] is None
    assert body["wrong_reason_counts"] == {
        "VOCAB": 0,
        "EVIDENCE": 0,
        "INFERENCE": 0,
        "CARELESS": 0,
        "TIME": 0,
    }


def test_duplicate_only_batch_then_recompute_is_no_op(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="agg-dup-noop@example.com")
    student_id = UUID(str(student["user"]["id"]))
    token = str(student["access_token"])
    occurred = "2026-03-02T09:00:00+09:00"

    accepted_response = client.post(
        "/sync/events/batch",
        json={
            "events": [
                {
                    "event_type": "TODAY_ATTEMPT_SAVED",
                    "schema_version": 1,
                    "device_id": "ios-device-1",
                    "occurred_at_client": occurred,
                    "idempotency_key": "dup-noop-key",
                    "payload": {
                        "sessionId": 801,
                        "questionId": "q_noop",
                        "selectedAnswer": "A",
                        "isCorrect": True,
                    },
                }
            ]
        },
        headers=_student_headers(token),
    )
    assert accepted_response.status_code == 200, accepted_response.text
    assert accepted_response.json()["summary"]["accepted"] == 1

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        first_daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()
        first_view = (
            first_daily.day_key,
            first_daily.answered_count,
            first_daily.correct_count,
            first_daily.wrong_count,
            first_daily.wrong_reason_counts,
            first_daily.top_wrong_reason_tag,
            first_daily.aggregated_at,
        )

    duplicate_response = client.post(
        "/sync/events/batch",
        json={
            "events": [
                {
                    "event_type": "TODAY_ATTEMPT_SAVED",
                    "schema_version": 1,
                    "device_id": "ios-device-1",
                    "occurred_at_client": occurred,
                    "idempotency_key": "dup-noop-key",
                    "payload": {
                        "sessionId": 801,
                        "questionId": "q_noop",
                        "selectedAnswer": "B",
                        "isCorrect": False,
                        "wrongReasonTag": "VOCAB",
                    },
                }
            ]
        },
        headers=_student_headers(token),
    )
    assert duplicate_response.status_code == 200, duplicate_response.text
    assert duplicate_response.json()["summary"] == {
        "accepted": 0,
        "duplicate": 1,
        "invalid": 0,
        "total": 1,
    }

    _recompute(db_session_factory, student_id=student_id)

    with db_session_factory() as db:
        second_daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()
        second_view = (
            second_daily.day_key,
            second_daily.answered_count,
            second_daily.correct_count,
            second_daily.wrong_count,
            second_daily.wrong_reason_counts,
            second_daily.top_wrong_reason_tag,
            second_daily.aggregated_at,
        )

    assert first_view == second_view


def test_worker_aggregation_path_smoke_on_accepted_event(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    student = _register_user(client, role="student", email="agg-worker-smoke@example.com")
    student_id = UUID(str(student["user"]["id"]))
    token = str(student["access_token"])

    response = client.post(
        "/sync/events/batch",
        json={
            "events": [
                {
                    "event_type": "MOCK_EXAM_ATTEMPT_SAVED",
                    "schema_version": 1,
                    "device_id": "ios-device-1",
                    "occurred_at_client": "2026-03-02T09:10:00+09:00",
                    "idempotency_key": "worker-smoke-key",
                    "payload": {
                        "mockSessionId": 999,
                        "questionId": "mq_worker",
                        "selectedAnswer": "C",
                        "isCorrect": False,
                        "wrongReasonTag": "EVIDENCE",
                    },
                }
            ]
        },
        headers=_student_headers(token),
    )
    assert response.status_code == 200, response.text
    assert response.json()["summary"]["accepted"] == 1

    monkeypatch.setattr(worker_tasks, "SessionLocal", db_session_factory)
    task_result = worker_tasks.aggregate_student_events.run(str(student_id))
    assert task_result["status"] == "ok"
    assert int(task_result["projection_count"]) == 1

    with db_session_factory() as db:
        daily = db.execute(
            select(DailyReportAggregate).where(DailyReportAggregate.student_id == student_id)
        ).scalar_one()
        weekly = db.execute(
            select(WeeklyReportAggregate).where(WeeklyReportAggregate.student_id == student_id)
        ).scalar_one()
        monthly = db.execute(
            select(MonthlyReportAggregate).where(MonthlyReportAggregate.student_id == student_id)
        ).scalar_one()

    assert daily.answered_count == 1
    assert weekly.answered_count == 1
    assert monthly.answered_count == 1
