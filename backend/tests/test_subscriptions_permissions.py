from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.timekeys import period_key
from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import MockExamType, SubscriptionFeatureCode, Track
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.parent_child_link import ParentChildLink
import app.services.entitlement_service as entitlement_service
import app.services.mock_exam_delivery_service as mock_exam_delivery_service

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


def _register_user(
    client: TestClient,
    *,
    role: str,
    email: str,
    password: str = "SecurePass123!",
    device_id: str = "device-1",
) -> dict[str, object]:
    response = client.post(
        f"/auth/register/{role}",
        json={"email": email, "password": password, "device_id": device_id},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _auth_headers(access_token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {access_token}"}


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _set_fixed_mock_exam_now(monkeypatch, *, iso_timestamp: str) -> datetime:
    fixed_now = datetime.fromisoformat(iso_timestamp)
    monkeypatch.setattr(mock_exam_delivery_service, "_now_utc", lambda: fixed_now)
    monkeypatch.setattr(entitlement_service, "_now_utc", lambda: fixed_now)
    return fixed_now


def _create_plan(
    client: TestClient,
    *,
    plan_code: str,
    feature_codes: list[str],
) -> dict[str, object]:
    response = client.post(
        "/internal/subscriptions/plans",
        json={
            "planCode": plan_code,
            "displayName": f"Plan {plan_code}",
            "featureCodes": feature_codes,
            "metadata": {"seed": plan_code},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_parent_subscription(
    client: TestClient,
    *,
    parent_id: str,
    plan_code: str,
    status: str = "ACTIVE",
    starts_at: datetime | None = None,
    ends_at: datetime | None = None,
    grace_ends_at: datetime | None = None,
) -> dict[str, object]:
    now = entitlement_service._now_utc()
    window_start = starts_at or (now - timedelta(days=1))
    window_end = ends_at or (now + timedelta(days=30))

    response = client.post(
        f"/internal/subscriptions/parents/{parent_id}",
        json={
            "planCode": plan_code,
            "status": status,
            "startsAt": window_start.isoformat(),
            "endsAt": window_end.isoformat(),
            "graceEndsAt": grace_ends_at.isoformat() if grace_ends_at is not None else None,
            "externalBillingRef": f"ext-{uuid4().hex[:10]}",
            "metadata": {"seed": plan_code},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _link_parent_child(
    db_session_factory,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> None:
    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=child_id))
        db.commit()


def _unlink_parent_child(
    db_session_factory,
    *,
    parent_id: UUID,
    child_id: UUID,
) -> None:
    with db_session_factory() as db:
        link = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == parent_id,
                ParentChildLink.child_id == child_id,
                ParentChildLink.unlinked_at.is_(None),
            )
        ).scalar_one()
        link.unlinked_at = datetime.now(UTC)
        db.commit()


def _seed_published_mock_exam(
    db_session_factory,
    *,
    exam_type: MockExamType,
    track: Track,
    period_key_value: str,
) -> tuple[str, str]:
    seed = uuid4().hex[:8]
    with db_session_factory() as db:
        now = datetime.now(UTC)
        exam = MockExam(
            exam_type=exam_type,
            track=track,
            period_key=period_key_value,
            external_id=f"exam-{seed}",
            slug=f"exam-{seed}",
            lifecycle_status=ContentLifecycleStatus.PUBLISHED,
        )
        db.add(exam)
        db.flush()

        revision = MockExamRevision(
            mock_exam_id=exam.id,
            revision_no=1,
            title=f"{exam_type.value} {period_key_value}",
            instructions="Read and answer the questions.",
            generator_version="seed-generator-v1",
            validator_version="seed-validator-v1",
            validated_at=now,
            reviewer_identity="seed-reviewer",
            reviewed_at=now,
            metadata_json={"seed": seed},
            lifecycle_status=ContentLifecycleStatus.PUBLISHED,
            published_at=now,
        )
        db.add(revision)
        db.flush()

        exam.published_revision_id = revision.id
        db.commit()
        return str(exam.id), str(revision.id)


def test_internal_subscription_api_key_missing_and_invalid_rejected(client: TestClient) -> None:
    payload = {
        "planCode": "starter",
        "displayName": "Starter",
        "featureCodes": ["WEEKLY_MOCK_EXAMS"],
        "metadata": {},
    }
    missing = client.post("/internal/subscriptions/plans", json=payload)
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/subscriptions/plans",
        json=payload,
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_subscription_plan_create_success_and_duplicate_plan_code_rejected(client: TestClient) -> None:
    created = _create_plan(
        client,
        plan_code="plan-pro",
        feature_codes=["WEEKLY_MOCK_EXAMS", "MONTHLY_MOCK_EXAMS"],
    )
    assert created["planCode"] == "plan-pro"
    assert sorted(created["featureCodes"]) == ["MONTHLY_MOCK_EXAMS", "WEEKLY_MOCK_EXAMS"]

    duplicate = client.post(
        "/internal/subscriptions/plans",
        json={
            "planCode": "plan-pro",
            "displayName": "Plan Pro Duplicate",
            "featureCodes": ["CHILD_REPORTS"],
            "metadata": {},
        },
        headers=_internal_headers(),
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["detail"] == "subscription_plan_code_conflict"


def test_parent_subscription_create_success(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="sub-parent-create@example.com")
    _create_plan(client, plan_code="plan-parent", feature_codes=["CHILD_REPORTS"])

    created = _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-parent",
    )
    assert created["ownerUserId"] == str(parent["user"]["id"])
    assert created["planCode"] == "plan-parent"
    assert created["status"] == "ACTIVE"


def test_student_owner_subscription_create_rejected(client: TestClient) -> None:
    student = _register_user(client, role="student", email="sub-student-owner@example.com")
    _create_plan(client, plan_code="plan-owner-check", feature_codes=["WEEKLY_MOCK_EXAMS"])

    response = client.post(
        f"/internal/subscriptions/parents/{student['user']['id']}",
        json={
            "planCode": "plan-owner-check",
            "status": "ACTIVE",
            "startsAt": (datetime.now(UTC) - timedelta(days=1)).isoformat(),
            "endsAt": (datetime.now(UTC) + timedelta(days=30)).isoformat(),
            "graceEndsAt": None,
            "externalBillingRef": "ext-owner-check",
            "metadata": {},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "subscription_owner_must_be_parent"


def test_overlapping_active_subscription_rejected(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="sub-overlap-parent@example.com")
    _create_plan(client, plan_code="plan-overlap", feature_codes=["WEEKLY_MOCK_EXAMS"])

    now = datetime.now(UTC)
    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-overlap",
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=10),
    )

    overlap = client.post(
        f"/internal/subscriptions/parents/{parent['user']['id']}",
        json={
            "planCode": "plan-overlap",
            "status": "ACTIVE",
            "startsAt": (now + timedelta(days=5)).isoformat(),
            "endsAt": (now + timedelta(days=20)).isoformat(),
            "graceEndsAt": None,
            "externalBillingRef": "ext-overlap-second",
            "metadata": {},
        },
        headers=_internal_headers(),
    )
    assert overlap.status_code == 409
    assert overlap.json()["detail"] == "overlapping_active_subscription"


def test_subscription_me_parent_success(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="sub-me-parent@example.com")
    _create_plan(
        client,
        plan_code="plan-parent-me",
        feature_codes=["CHILD_REPORTS", "WEEKLY_MOCK_EXAMS"],
    )
    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-parent-me",
    )

    response = client.get("/subscription/me", headers=_auth_headers(str(parent["access_token"])))
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["actorRole"] == "PARENT"
    assert sorted(body["featureCodes"]) == ["CHILD_REPORTS", "WEEKLY_MOCK_EXAMS"]
    assert body["activeSubscription"] is not None
    assert body["activeSubscription"]["planCode"] == "plan-parent-me"
    assert body["activeSubscription"]["source"] == "OWN"


def test_subscription_me_student_linked_parent_union_success(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="sub-me-student@example.com")
    parent_one = _register_user(client, role="parent", email="sub-me-parent-one@example.com")
    parent_two = _register_user(client, role="parent", email="sub-me-parent-two@example.com")

    student_id = UUID(str(student["user"]["id"]))
    parent_one_id = UUID(str(parent_one["user"]["id"]))
    parent_two_id = UUID(str(parent_two["user"]["id"]))

    _link_parent_child(db_session_factory, parent_id=parent_one_id, child_id=student_id)
    _link_parent_child(db_session_factory, parent_id=parent_two_id, child_id=student_id)

    _create_plan(client, plan_code="plan-student-union-1", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_plan(client, plan_code="plan-student-union-2", feature_codes=["MONTHLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(parent_one_id),
        plan_code="plan-student-union-1",
    )
    _create_parent_subscription(
        client,
        parent_id=str(parent_two_id),
        plan_code="plan-student-union-2",
    )

    response = client.get("/subscription/me", headers=_auth_headers(str(student["access_token"])))
    assert response.status_code == 200, response.text
    body = response.json()

    assert body["actorRole"] == "STUDENT"
    assert body["source"] == "LINKED_PARENTS"
    assert body["effectiveStatus"] == "ACTIVE"
    assert sorted(body["featureCodes"]) == ["MONTHLY_MOCK_EXAMS", "WEEKLY_MOCK_EXAMS"]

    sources = {item["parentId"]: item for item in body["linkedParentSources"]}
    assert set(sources.keys()) == {str(parent_one_id), str(parent_two_id)}
    assert sources[str(parent_one_id)]["featureCodes"] == ["WEEKLY_MOCK_EXAMS"]
    assert sources[str(parent_two_id)]["featureCodes"] == ["MONTHLY_MOCK_EXAMS"]


def test_subscription_me_student_without_linked_active_subscription_returns_empty(client: TestClient) -> None:
    student = _register_user(client, role="student", email="sub-empty-student@example.com")

    response = client.get("/subscription/me", headers=_auth_headers(str(student["access_token"])))
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["actorRole"] == "STUDENT"
    assert body["source"] == "LINKED_PARENTS"
    assert body["featureCodes"] == []
    assert body["linkedParentSources"] == []
    assert body["effectiveStatus"] == "INACTIVE"


def test_parent_child_report_access_with_feature_success(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="report-feature-student@example.com")
    parent = _register_user(client, role="parent", email="report-feature-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))

    _link_parent_child(db_session_factory, parent_id=parent_id, child_id=student_id)
    _create_plan(client, plan_code="plan-report", feature_codes=["CHILD_REPORTS"])
    _create_parent_subscription(client, parent_id=str(parent_id), plan_code="plan-report")

    response = client.get(
        f"/reports/children/{student_id}/daily/20260302",
        headers=_auth_headers(str(parent["access_token"])),
    )
    assert response.status_code == 200, response.text


def test_parent_child_report_access_without_feature_forbidden(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="report-no-feature-student@example.com")
    parent = _register_user(client, role="parent", email="report-no-feature-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))

    _link_parent_child(db_session_factory, parent_id=parent_id, child_id=student_id)
    _create_plan(client, plan_code="plan-report-none", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_parent_subscription(client, parent_id=str(parent_id), plan_code="plan-report-none")

    response = client.get(
        f"/reports/children/{student_id}/daily/20260302",
        headers=_auth_headers(str(parent["access_token"])),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "child_reports_subscription_required"


def test_unrelated_parent_with_subscription_still_forbidden(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="report-unrelated-student@example.com")
    linked_parent = _register_user(client, role="parent", email="report-linked-parent@example.com")
    unrelated_parent = _register_user(client, role="parent", email="report-unrelated-parent@example.com")
    student_id = UUID(str(student["user"]["id"]))
    linked_parent_id = UUID(str(linked_parent["user"]["id"]))
    unrelated_parent_id = UUID(str(unrelated_parent["user"]["id"]))

    _link_parent_child(db_session_factory, parent_id=linked_parent_id, child_id=student_id)
    _create_plan(client, plan_code="plan-unrelated", feature_codes=["CHILD_REPORTS"])
    _create_parent_subscription(client, parent_id=str(unrelated_parent_id), plan_code="plan-unrelated")

    response = client.get(
        f"/reports/children/{student_id}/daily/20260302",
        headers=_auth_headers(str(unrelated_parent["access_token"])),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "child_report_access_forbidden"


def test_student_weekly_current_with_and_without_feature(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    fixed_now = _set_fixed_mock_exam_now(monkeypatch, iso_timestamp="2026-03-02T00:00:00+00:00")
    weekly_key = period_key(fixed_now, "WEEKLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    entitled_student = _register_user(client, role="student", email="weekly-entitled-student@example.com")
    entitled_parent = _register_user(client, role="parent", email="weekly-entitled-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(entitled_parent["user"]["id"])),
        child_id=UUID(str(entitled_student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-weekly", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(entitled_parent["user"]["id"]),
        plan_code="plan-weekly",
    )

    success = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(entitled_student["access_token"])),
    )
    assert success.status_code == 200, success.text

    no_feature_student = _register_user(client, role="student", email="weekly-no-feature-student@example.com")
    denied = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(no_feature_student["access_token"])),
    )
    assert denied.status_code == 403
    assert denied.json()["detail"] == "weekly_mock_exams_subscription_required"


def test_student_monthly_current_with_and_without_feature(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    fixed_now = _set_fixed_mock_exam_now(monkeypatch, iso_timestamp="2026-03-02T00:00:00+00:00")
    monthly_key = period_key(fixed_now, "MONTHLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.MONTHLY,
        track=Track.H2,
        period_key_value=monthly_key,
    )

    entitled_student = _register_user(client, role="student", email="monthly-entitled-student@example.com")
    entitled_parent = _register_user(client, role="parent", email="monthly-entitled-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(entitled_parent["user"]["id"])),
        child_id=UUID(str(entitled_student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-monthly", feature_codes=["MONTHLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(entitled_parent["user"]["id"]),
        plan_code="plan-monthly",
    )

    success = client.get(
        "/mock-exams/monthly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(entitled_student["access_token"])),
    )
    assert success.status_code == 200, success.text

    no_feature_student = _register_user(client, role="student", email="monthly-no-feature-student@example.com")
    denied = client.get(
        "/mock-exams/monthly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(no_feature_student["access_token"])),
    )
    assert denied.status_code == 403
    assert denied.json()["detail"] == "monthly_mock_exams_subscription_required"


def test_session_start_gated_by_exam_type_entitlement(client: TestClient, db_session_factory) -> None:
    now = datetime.now(UTC)
    weekly_key = period_key(now, "WEEKLY")
    monthly_key = period_key(now, "MONTHLY")

    _weekly_exam_id, weekly_revision_id = _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )
    _monthly_exam_id, monthly_revision_id = _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.MONTHLY,
        track=Track.H2,
        period_key_value=monthly_key,
    )

    student = _register_user(client, role="student", email="session-gate-student@example.com")
    parent = _register_user(client, role="parent", email="session-gate-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-session-weekly", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-session-weekly",
    )

    weekly_start = client.post(
        f"/mock-exams/{weekly_revision_id}/sessions",
        headers=_auth_headers(str(student["access_token"])),
    )
    assert weekly_start.status_code == 200, weekly_start.text

    monthly_start = client.post(
        f"/mock-exams/{monthly_revision_id}/sessions",
        headers=_auth_headers(str(student["access_token"])),
    )
    assert monthly_start.status_code == 403
    assert monthly_start.json()["detail"] == "monthly_mock_exams_subscription_required"


def test_existing_session_detail_remains_readable_after_subscription_expiry(
    client: TestClient,
    db_session_factory,
) -> None:
    now = datetime.now(UTC)
    weekly_key = period_key(now, "WEEKLY")
    _exam_id, weekly_revision_id = _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student = _register_user(client, role="student", email="session-expiry-student@example.com")
    parent = _register_user(client, role="parent", email="session-expiry-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-session-expiry", feature_codes=["WEEKLY_MOCK_EXAMS"])
    subscription = _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-session-expiry",
    )

    started = client.post(
        f"/mock-exams/{weekly_revision_id}/sessions",
        headers=_auth_headers(str(student["access_token"])),
    )
    assert started.status_code == 200, started.text
    session_id = started.json()["mockSessionId"]

    expired = client.post(
        f"/internal/subscriptions/{subscription['id']}/expire",
        headers=_internal_headers(),
    )
    assert expired.status_code == 200, expired.text
    assert expired.json()["status"] == "EXPIRED"

    detail = client.get(
        f"/mock-exam-sessions/{session_id}",
        headers=_auth_headers(str(student["access_token"])),
    )
    assert detail.status_code == 200, detail.text


def test_student_cannot_read_other_student_session_rule_unchanged(client: TestClient, db_session_factory) -> None:
    now = datetime.now(UTC)
    weekly_key = period_key(now, "WEEKLY")
    _exam_id, weekly_revision_id = _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student_one = _register_user(client, role="student", email="session-owner-b17@example.com")
    student_two = _register_user(client, role="student", email="session-other-b17@example.com")
    parent = _register_user(client, role="parent", email="session-owner-parent-b17@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student_one["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-session-owner", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-session-owner",
    )

    started = client.post(
        f"/mock-exams/{weekly_revision_id}/sessions",
        headers=_auth_headers(str(student_one["access_token"])),
    )
    assert started.status_code == 200, started.text

    forbidden = client.get(
        f"/mock-exam-sessions/{started.json()['mockSessionId']}",
        headers=_auth_headers(str(student_two["access_token"])),
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"] == "mock_exam_session_access_forbidden"


def test_internal_content_mock_exam_ai_apis_unaffected_by_subscription_gate(client: TestClient) -> None:
    content_response = client.get("/internal/content/units", headers=_internal_headers())
    mock_exam_response = client.get("/internal/mock-exams", headers=_internal_headers())
    ai_response = client.get("/internal/ai/jobs", headers=_internal_headers())

    assert content_response.status_code == 200, content_response.text
    assert mock_exam_response.status_code == 200, mock_exam_response.text
    assert ai_response.status_code == 200, ai_response.text


def test_cancel_updates_entitlement_resolution(client: TestClient, db_session_factory) -> None:
    now = datetime.now(UTC)
    weekly_key = period_key(now, "WEEKLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student = _register_user(client, role="student", email="cancel-entitlement-student@example.com")
    parent = _register_user(client, role="parent", email="cancel-entitlement-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-cancel", feature_codes=["WEEKLY_MOCK_EXAMS"])
    subscription = _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-cancel",
    )

    before_cancel = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert before_cancel.status_code == 200, before_cancel.text

    canceled = client.post(
        f"/internal/subscriptions/{subscription['id']}/cancel",
        headers=_internal_headers(),
    )
    assert canceled.status_code == 200, canceled.text
    assert canceled.json()["status"] == "CANCELED"

    after_cancel = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert after_cancel.status_code == 403
    assert after_cancel.json()["detail"] == "weekly_mock_exams_subscription_required"


def test_expire_updates_entitlement_resolution(client: TestClient, db_session_factory) -> None:
    now = datetime.now(UTC)
    weekly_key = period_key(now, "WEEKLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student = _register_user(client, role="student", email="expire-entitlement-student@example.com")
    parent = _register_user(client, role="parent", email="expire-entitlement-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-expire", feature_codes=["WEEKLY_MOCK_EXAMS"])
    subscription = _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-expire",
    )

    before_expire = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert before_expire.status_code == 200, before_expire.text

    expired = client.post(
        f"/internal/subscriptions/{subscription['id']}/expire",
        headers=_internal_headers(),
    )
    assert expired.status_code == 200, expired.text
    assert expired.json()["status"] == "EXPIRED"

    after_expire = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert after_expire.status_code == 403
    assert after_expire.json()["detail"] == "weekly_mock_exams_subscription_required"


def test_grace_status_grants_access_within_grace_window(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    fixed_now = _set_fixed_mock_exam_now(monkeypatch, iso_timestamp="2026-03-02T00:00:00+00:00")
    weekly_key = period_key(fixed_now, "WEEKLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student = _register_user(client, role="student", email="grace-allow-student@example.com")
    parent = _register_user(client, role="parent", email="grace-allow-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-grace-allow", feature_codes=["WEEKLY_MOCK_EXAMS"])

    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-grace-allow",
        status="GRACE",
        starts_at=fixed_now - timedelta(days=30),
        ends_at=fixed_now - timedelta(days=1),
        grace_ends_at=fixed_now + timedelta(days=1),
    )

    response = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert response.status_code == 200, response.text


def test_expired_grace_denies_access(client: TestClient, db_session_factory, monkeypatch) -> None:
    fixed_now = _set_fixed_mock_exam_now(monkeypatch, iso_timestamp="2026-03-02T00:00:00+00:00")
    weekly_key = period_key(fixed_now, "WEEKLY")
    _seed_published_mock_exam(
        db_session_factory,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key_value=weekly_key,
    )

    student = _register_user(client, role="student", email="grace-deny-student@example.com")
    parent = _register_user(client, role="parent", email="grace-deny-parent@example.com")
    _link_parent_child(
        db_session_factory,
        parent_id=UUID(str(parent["user"]["id"])),
        child_id=UUID(str(student["user"]["id"])),
    )
    _create_plan(client, plan_code="plan-grace-deny", feature_codes=["WEEKLY_MOCK_EXAMS"])

    _create_parent_subscription(
        client,
        parent_id=str(parent["user"]["id"]),
        plan_code="plan-grace-deny",
        status="GRACE",
        starts_at=fixed_now - timedelta(days=30),
        ends_at=fixed_now - timedelta(days=2),
        grace_ends_at=fixed_now - timedelta(minutes=1),
    )

    response = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_auth_headers(str(student["access_token"])),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "weekly_mock_exams_subscription_required"


def test_active_link_removal_removes_student_entitlement_source(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="unlink-entitlement-student@example.com")
    parent = _register_user(client, role="parent", email="unlink-entitlement-parent@example.com")

    student_id = UUID(str(student["user"]["id"]))
    parent_id = UUID(str(parent["user"]["id"]))

    _link_parent_child(
        db_session_factory,
        parent_id=parent_id,
        child_id=student_id,
    )
    _create_plan(client, plan_code="plan-unlink", feature_codes=["WEEKLY_MOCK_EXAMS"])
    _create_parent_subscription(
        client,
        parent_id=str(parent_id),
        plan_code="plan-unlink",
    )

    before_unlink = client.get("/subscription/me", headers=_auth_headers(str(student["access_token"])))
    assert before_unlink.status_code == 200, before_unlink.text
    before_body = before_unlink.json()
    assert before_body["featureCodes"] == ["WEEKLY_MOCK_EXAMS"]
    assert len(before_body["linkedParentSources"]) == 1

    _unlink_parent_child(
        db_session_factory,
        parent_id=parent_id,
        child_id=student_id,
    )

    after_unlink = client.get("/subscription/me", headers=_auth_headers(str(student["access_token"])))
    assert after_unlink.status_code == 200, after_unlink.text
    after_body = after_unlink.json()
    assert after_body["featureCodes"] == []
    assert after_body["linkedParentSources"] == []
    assert after_body["effectiveStatus"] == "INACTIVE"
