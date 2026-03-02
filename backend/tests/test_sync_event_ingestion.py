from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import func, select

import app.services.sync_service as sync_service
from app.models.study_event import StudyEvent


def _register_student(
    client: TestClient,
    *,
    email: str,
    password: str = "SecurePass123!",
) -> dict[str, object]:
    response = client.post(
        "/auth/register/student",
        json={"email": email, "password": password, "device_id": "student-device"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _register_parent(
    client: TestClient,
    *,
    email: str,
    password: str = "SecurePass123!",
) -> dict[str, object]:
    response = client.post(
        "/auth/register/parent",
        json={"email": email, "password": password, "device_id": "parent-device"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _auth_headers(access_token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {access_token}"}


def _today_event(
    *,
    idempotency_key: str,
    payload: dict[str, object] | None = None,
    device_id: str = "ios-device-001",
    occurred_at_client: str = "2026-03-02T09:00:00+09:00",
    event_type: str = "TODAY_ATTEMPT_SAVED",
) -> dict[str, object]:
    return {
        "event_type": event_type,
        "schema_version": 1,
        "device_id": device_id,
        "occurred_at_client": occurred_at_client,
        "idempotency_key": idempotency_key,
        "payload": payload
        or {
            "sessionId": 101,
            "questionId": "q_001",
            "selectedAnswer": "A",
            "isCorrect": True,
        },
    }


def _mock_event(
    *,
    idempotency_key: str,
    payload: dict[str, object] | None = None,
    device_id: str = "ios-device-001",
    occurred_at_client: str = "2026-03-02T09:00:00+09:00",
) -> dict[str, object]:
    return {
        "event_type": "MOCK_EXAM_ATTEMPT_SAVED",
        "schema_version": 1,
        "device_id": device_id,
        "occurred_at_client": occurred_at_client,
        "idempotency_key": idempotency_key,
        "payload": payload
        or {
            "mockSessionId": 55,
            "questionId": "mq_010",
            "selectedAnswer": "C",
            "isCorrect": False,
            "wrongReasonTag": "EVIDENCE",
        },
    }


def _post_sync_batch(
    client: TestClient,
    *,
    access_token: str,
    events: list[dict[str, object] | object],
) -> dict[str, object]:
    response = client.post(
        "/sync/events/batch",
        json={"events": events},
        headers=_auth_headers(access_token),
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_sync_batch_accepted_insert_success(client: TestClient, db_session_factory) -> None:
    student = _register_student(client, email="sync-accepted@example.com")
    student_id = UUID(str(student["user"]["id"]))
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[_today_event(idempotency_key="k-accepted-1")],
    )

    assert body["summary"] == {"accepted": 1, "duplicate": 0, "invalid": 0, "total": 1}
    assert body["results"][0]["status"] == "accepted"

    with db_session_factory() as db:
        row = db.execute(
            select(StudyEvent).where(
                StudyEvent.student_id == student_id,
                StudyEvent.idempotency_key == "k-accepted-1",
            )
        ).scalar_one()

    assert row.event_type == "TODAY_ATTEMPT_SAVED"
    assert row.payload["questionId"] == "q_001"


def test_same_student_same_idempotency_key_is_duplicate(client: TestClient, db_session_factory) -> None:
    student = _register_student(client, email="sync-dup@example.com")
    token = str(student["access_token"])

    _post_sync_batch(client, access_token=token, events=[_today_event(idempotency_key="k-dup-1")])
    body = _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(
                idempotency_key="k-dup-1",
                payload={
                    "sessionId": 101,
                    "questionId": "q_999",
                    "selectedAnswer": "B",
                    "isCorrect": False,
                    "wrongReasonTag": "VOCAB",
                },
            )
        ],
    )

    assert body["summary"] == {"accepted": 0, "duplicate": 1, "invalid": 0, "total": 1}
    assert body["results"][0]["status"] == "duplicate"

    with db_session_factory() as db:
        count = db.execute(
            select(func.count()).select_from(StudyEvent).where(
                StudyEvent.student_id == UUID(str(student["user"]["id"])),
                StudyEvent.idempotency_key == "k-dup-1",
            )
        ).scalar_one()
    assert count == 1


def test_different_students_same_idempotency_key_allowed(client: TestClient, db_session_factory) -> None:
    student_one = _register_student(client, email="sync-student-one@example.com")
    student_two = _register_student(client, email="sync-student-two@example.com")
    key = "shared-key-001"

    body_one = _post_sync_batch(
        client,
        access_token=str(student_one["access_token"]),
        events=[_today_event(idempotency_key=key)],
    )
    body_two = _post_sync_batch(
        client,
        access_token=str(student_two["access_token"]),
        events=[_today_event(idempotency_key=key)],
    )

    assert body_one["results"][0]["status"] == "accepted"
    assert body_two["results"][0]["status"] == "accepted"

    with db_session_factory() as db:
        count = db.execute(
            select(func.count()).select_from(StudyEvent).where(StudyEvent.idempotency_key == key)
        ).scalar_one()
    assert count == 2


def test_mixed_batch_handling(client: TestClient) -> None:
    student = _register_student(client, email="sync-mixed@example.com")
    token = str(student["access_token"])
    body = _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(idempotency_key="mixed-k-1"),
            _today_event(idempotency_key="mixed-k-1"),
            _mock_event(
                idempotency_key="mixed-k-2",
                payload={
                    "mockSessionId": 55,
                    "questionId": "mq_010",
                    "selectedAnswer": "C",
                    "isCorrect": False,
                },
            ),
        ],
    )

    assert body["summary"] == {"accepted": 1, "duplicate": 1, "invalid": 1, "total": 3}
    assert [item["status"] for item in body["results"]] == ["accepted", "duplicate", "invalid"]


def test_invalid_payload_item_handling(client: TestClient) -> None:
    student = _register_student(client, email="sync-invalid-payload@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(
                idempotency_key="k-invalid-payload",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "A",
                    "isCorrect": True,
                    "unexpected": "field",
                },
            )
        ],
    )

    assert body["summary"]["invalid"] == 1
    assert body["results"][0]["status"] == "invalid"


def test_naive_occurred_at_client_rejected(client: TestClient) -> None:
    student = _register_student(client, email="sync-naive-time@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(
                idempotency_key="k-naive-time",
                occurred_at_client="2026-03-02T09:00:00",
            )
        ],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "invalid_occurred_at_client"


def test_hidden_unicode_rejected_for_device_id(client: TestClient) -> None:
    student = _register_student(client, email="sync-hidden-device@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[_today_event(idempotency_key="k-hidden-device", device_id="ios\u200b-device")],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "invalid_hidden_unicode"


def test_hidden_unicode_rejected_for_event_type(client: TestClient) -> None:
    student = _register_student(client, email="sync-hidden-type@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[_today_event(idempotency_key="k-hidden-type", event_type="TODAY_ATTEMPT_SAVED\u200b")],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "invalid_hidden_unicode"


def test_hidden_unicode_rejected_for_idempotency_key(client: TestClient) -> None:
    student = _register_student(client, email="sync-hidden-key@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[_today_event(idempotency_key="k-hidden\u200b-key")],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "invalid_hidden_unicode"


def test_hidden_unicode_rejected_for_selected_answer_and_question_id(client: TestClient) -> None:
    student = _register_student(client, email="sync-hidden-payload@example.com")
    token = str(student["access_token"])

    answer_hidden = _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(
                idempotency_key="k-hidden-answer",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "A\u200b",
                    "isCorrect": True,
                },
            )
        ],
    )
    question_hidden = _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(
                idempotency_key="k-hidden-question",
                payload={
                    "sessionId": 101,
                    "questionId": "q\u200b_001",
                    "selectedAnswer": "A",
                    "isCorrect": True,
                },
            )
        ],
    )

    assert answer_hidden["results"][0]["status"] == "invalid"
    assert answer_hidden["results"][0]["detail_code"] == "invalid_hidden_unicode"
    assert question_hidden["results"][0]["status"] == "invalid"
    assert question_hidden["results"][0]["detail_code"] == "invalid_hidden_unicode"


def test_invalid_wrong_reason_tag_rejected(client: TestClient) -> None:
    student = _register_student(client, email="sync-invalid-tag@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(
                idempotency_key="k-invalid-tag",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "B",
                    "isCorrect": False,
                    "wrongReasonTag": "GRAMMAR",
                },
            )
        ],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "invalid_wrong_reason_tag"


def test_is_correct_false_requires_wrong_reason_tag(client: TestClient) -> None:
    student = _register_student(client, email="sync-wrong-tag-required@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(
                idempotency_key="k-wrong-tag-required",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "B",
                    "isCorrect": False,
                },
            )
        ],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "wrong_reason_tag_required"


def test_is_correct_true_requires_null_wrong_reason_tag(client: TestClient) -> None:
    student = _register_student(client, email="sync-correct-tag-null@example.com")
    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(
                idempotency_key="k-correct-tag-null",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "A",
                    "isCorrect": True,
                    "wrongReasonTag": "VOCAB",
                },
            )
        ],
    )

    assert body["results"][0]["status"] == "invalid"
    assert body["results"][0]["detail_code"] == "wrong_reason_tag_must_be_null"


def test_append_only_smoke_duplicate_does_not_update_existing_row(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_student(client, email="sync-append-only@example.com")
    token = str(student["access_token"])

    _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(
                idempotency_key="k-append-only",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "A",
                    "isCorrect": True,
                },
            )
        ],
    )
    _post_sync_batch(
        client,
        access_token=token,
        events=[
            _today_event(
                idempotency_key="k-append-only",
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "B",
                    "isCorrect": False,
                    "wrongReasonTag": "VOCAB",
                },
            )
        ],
    )

    with db_session_factory() as db:
        rows = db.execute(
            select(StudyEvent).where(
                StudyEvent.student_id == UUID(str(student["user"]["id"])),
                StudyEvent.idempotency_key == "k-append-only",
            )
        ).scalars().all()

    assert len(rows) == 1
    assert rows[0].payload["selectedAnswer"] == "A"
    assert rows[0].payload["isCorrect"] is True


def test_duplicate_only_batch_does_not_fire_trigger(client: TestClient, db_session_factory, monkeypatch) -> None:
    student = _register_student(client, email="sync-dup-trigger@example.com")
    student_id = UUID(str(student["user"]["id"]))
    duplicate_key = "k-duplicate-trigger"

    with db_session_factory() as db:
        db.add(
            StudyEvent(
                student_id=student_id,
                event_type="TODAY_ATTEMPT_SAVED",
                schema_version=1,
                device_id="ios-device-001",
                occurred_at_client=datetime(2026, 3, 2, 0, 0, tzinfo=UTC),
                idempotency_key=duplicate_key,
                payload={
                    "sessionId": 101,
                    "questionId": "q_001",
                    "selectedAnswer": "A",
                    "isCorrect": True,
                },
            )
        )
        db.commit()

    called: list[UUID] = []
    monkeypatch.setattr(
        sync_service,
        "trigger_student_event_aggregation",
        lambda *, student_id: called.append(student_id),
    )

    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[_today_event(idempotency_key=duplicate_key)],
    )

    assert body["summary"] == {"accepted": 0, "duplicate": 1, "invalid": 0, "total": 1}
    assert called == []


def test_new_event_batch_fires_trigger_once_per_student(client: TestClient, monkeypatch) -> None:
    student = _register_student(client, email="sync-trigger-once@example.com")
    student_id = UUID(str(student["user"]["id"]))

    called: list[UUID] = []
    monkeypatch.setattr(
        sync_service,
        "trigger_student_event_aggregation",
        lambda *, student_id: called.append(student_id),
    )

    body = _post_sync_batch(
        client,
        access_token=str(student["access_token"]),
        events=[
            _today_event(idempotency_key="k-trigger-1"),
            _mock_event(idempotency_key="k-trigger-2"),
        ],
    )

    assert body["summary"] == {"accepted": 2, "duplicate": 0, "invalid": 0, "total": 2}
    assert called == [student_id]


def test_sync_batch_is_student_only(client: TestClient) -> None:
    parent = _register_parent(client, email="sync-parent-only@example.com")

    response = client.post(
        "/sync/events/batch",
        json={"events": [_today_event(idempotency_key="k-parent-forbidden")]},
        headers=_auth_headers(str(parent["access_token"])),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "student_role_required"
