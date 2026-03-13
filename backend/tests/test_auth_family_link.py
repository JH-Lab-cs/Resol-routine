from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.models.audit_log import AuditLog
from app.models.family_link_code import FamilyLinkCode
from app.models.invite_code import InviteCode
from app.models.parent_child_link import ParentChildLink
from app.models.refresh_token import RefreshToken

TEST_PASSWORD = "SecurePass123!"  # noqa: S105
TEST_DEVICE_ID = "device-1"


def _register_user(
    client: TestClient,
    *,
    role: str,
    email: str,
    password: str = TEST_PASSWORD,
    device_id: str = TEST_DEVICE_ID,
) -> dict[str, object]:
    response = client.post(
        f"/auth/register/{role}",
        json={"email": email, "password": password, "device_id": device_id},
        headers={
            "x-forwarded-for": "203.0.113.10",
            "user-agent": "pytest-agent",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _issue_invite(client: TestClient, parent_token: str) -> dict[str, object]:
    response = client.post(
        "/family/invites/issue",
        headers={
            "authorization": f"Bearer {parent_token}",
            "x-forwarded-for": "203.0.113.11",
            "user-agent": "pytest-agent",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _issue_child_link_code(client: TestClient, student_token: str) -> dict[str, object]:
    response = client.post(
        "/family/link-codes",
        headers={
            "authorization": f"Bearer {student_token}",
            "x-forwarded-for": "203.0.113.13",
            "user-agent": "pytest-agent",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _student_headers(token: str) -> dict[str, str]:
    return {
        "authorization": f"Bearer {token}",
        "x-forwarded-for": "203.0.113.12",
        "user-agent": "pytest-agent",
    }


def _parent_headers(token: str) -> dict[str, str]:
    return {
        "authorization": f"Bearer {token}",
        "x-forwarded-for": "203.0.113.11",
        "user-agent": "pytest-agent",
    }


def _assert_validation_error_detail(response, expected: str) -> None:
    assert response.status_code == 422, response.text
    details = response.json().get("detail", [])
    assert any(expected in str(item.get("msg", "")) for item in details)


def test_register_and_login_success(client: TestClient) -> None:
    register_payload = _register_user(
        client,
        role="student",
        email="student@example.com",
    )
    access_token = register_payload["access_token"]
    assert isinstance(access_token, str)
    assert isinstance(register_payload["refresh_token"], str)
    assert register_payload["user"]["role"] == "STUDENT"

    me_response = client.get(
        "/users/me",
        headers={
            "authorization": f"Bearer {access_token}",
            "x-forwarded-for": "203.0.113.10",
            "user-agent": "pytest-agent",
        },
    )
    assert me_response.status_code == 200, me_response.text
    assert me_response.json()["email"] == "student@example.com"

    login_response = client.post(
        "/auth/login",
        json={
            "email": "student@example.com",
            "password": TEST_PASSWORD,
            "device_id": TEST_DEVICE_ID,
        },
        headers={
            "x-forwarded-for": "203.0.113.10",
            "user-agent": "pytest-agent",
        },
    )
    assert login_response.status_code == 200, login_response.text
    assert login_response.json()["user"]["role"] == "STUDENT"
    assert login_response.json()["refresh_token"] != register_payload["refresh_token"]


def test_login_invalid_credentials_failure(client: TestClient, db_session_factory) -> None:
    _register_user(client, role="parent", email="parent@example.com")

    response = client.post(
        "/auth/login",
        json={
            "email": "parent@example.com",
            "password": "WrongPassword123!",
            "device_id": TEST_DEVICE_ID,
        },
        headers={
            "x-forwarded-for": "203.0.113.10",
            "user-agent": "pytest-agent",
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "invalid_credentials"

    with db_session_factory() as db:
        audit_actions = db.execute(
            select(AuditLog.action).where(AuditLog.action == "login_failure")
        ).scalars().all()
    assert len(audit_actions) == 1


def test_refresh_rotation_success(client: TestClient, db_session_factory) -> None:
    registered = _register_user(client, role="student", email="rotate@example.com")
    old_refresh_token = registered["refresh_token"]
    user_id = UUID(registered["user"]["id"])

    refresh_response = client.post(
        "/auth/refresh",
        json={"refresh_token": old_refresh_token, "device_id": "device-1"},
        headers={"x-forwarded-for": "203.0.113.10", "user-agent": "pytest-agent"},
    )
    assert refresh_response.status_code == 200, refresh_response.text

    new_refresh_token = refresh_response.json()["refresh_token"]
    assert isinstance(new_refresh_token, str)
    assert new_refresh_token != old_refresh_token

    with db_session_factory() as db:
        tokens = db.execute(
            select(RefreshToken).where(RefreshToken.user_id == user_id)
        ).scalars().all()

    assert len(tokens) == 2

    rotated_token = next(token for token in tokens if token.rotated_at is not None)
    replacement_token = next(
        token
        for token in tokens
        if token.id == rotated_token.replaced_by_token_id
    )

    assert rotated_token.revoked_at is None
    assert replacement_token.revoked_at is None
    assert rotated_token.family_id == replacement_token.family_id


def test_refresh_reuse_detection_revokes_family(client: TestClient, db_session_factory) -> None:
    registered = _register_user(client, role="student", email="reuse@example.com")
    old_refresh_token = registered["refresh_token"]

    first_refresh = client.post(
        "/auth/refresh",
        json={"refresh_token": old_refresh_token, "device_id": "device-1"},
        headers={"x-forwarded-for": "203.0.113.10", "user-agent": "pytest-agent"},
    )
    assert first_refresh.status_code == 200, first_refresh.text

    reuse_response = client.post(
        "/auth/refresh",
        json={"refresh_token": old_refresh_token, "device_id": "device-1"},
        headers={"x-forwarded-for": "203.0.113.10", "user-agent": "pytest-agent"},
    )
    assert reuse_response.status_code == 401
    assert reuse_response.json()["detail"] == "refresh_token_reuse_detected"

    user_id = UUID(registered["user"]["id"])
    with db_session_factory() as db:
        tokens = db.execute(
            select(RefreshToken).where(RefreshToken.user_id == user_id)
        ).scalars().all()

        reused_token = next(token for token in tokens if token.rotated_at is not None)

    assert all(token.revoked_at is not None for token in tokens)
    assert reused_token.reuse_detected_at is not None


def test_invite_issue_verify_consume_success(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="parent-link@example.com")
    student = _register_user(client, role="student", email="student-link@example.com")
    parent_id = parent["user"]["id"]
    student_id = student["user"]["id"]

    invite = _issue_invite(client, str(parent["access_token"]))

    verify_response = client.post(
        "/family/invites/verify",
        json={"parent_id": parent_id, "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert verify_response.status_code == 200, verify_response.text
    assert verify_response.json()["valid"] is True

    consume_response = client.post(
        "/family/invites/consume",
        json={"parent_id": parent_id, "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert consume_response.status_code == 200, consume_response.text
    assert consume_response.json()["parent_id"] == parent_id
    assert consume_response.json()["child_id"] == student_id

    with db_session_factory() as db:
        invite_row = db.execute(
            select(InviteCode).where(InviteCode.parent_id == UUID(parent_id))
        ).scalar_one()
        link_rows = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == UUID(parent_id),
                ParentChildLink.child_id == UUID(student_id),
                ParentChildLink.unlinked_at.is_(None),
            )
        ).scalars().all()

    assert invite_row.consumed_at is not None
    assert str(invite_row.consumed_by_user_id) == student_id
    assert len(link_rows) == 1


def test_expired_invite_rejected(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="expired-parent@example.com")
    student = _register_user(client, role="student", email="expired-student@example.com")
    parent_id = parent["user"]["id"]

    invite = _issue_invite(client, str(parent["access_token"]))

    with db_session_factory() as db:
        invite_row = db.execute(
            select(InviteCode).where(InviteCode.parent_id == UUID(parent_id))
        ).scalar_one()
        expired_base = datetime.now(UTC) - timedelta(hours=1)
        invite_row.created_at = expired_base
        invite_row.expires_at = expired_base + timedelta(minutes=1)
        db.commit()

    response = client.post(
        "/family/invites/verify",
        json={"parent_id": parent_id, "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert response.status_code == 410
    assert response.json()["detail"] == "invite_code_expired"


def test_consumed_invite_rejected(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="consumed-parent@example.com")
    student = _register_user(client, role="student", email="consumed-student@example.com")
    parent_id = parent["user"]["id"]

    invite = _issue_invite(client, str(parent["access_token"]))

    consume_response = client.post(
        "/family/invites/consume",
        json={"parent_id": parent_id, "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert consume_response.status_code == 200, consume_response.text

    second_consume = client.post(
        "/family/invites/consume",
        json={"parent_id": parent_id, "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert second_consume.status_code == 409
    assert second_consume.json()["detail"] == "invite_code_already_consumed"


def test_parent_max_five_children_limit(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="parent-max@example.com")
    parent_id = UUID(parent["user"]["id"])

    child_ids: list[UUID] = []
    for index in range(5):
        child = _register_user(client, role="student", email=f"child-max-{index}@example.com")
        child_ids.append(UUID(child["user"]["id"]))

    with db_session_factory() as db:
        for child_id in child_ids:
            db.add(ParentChildLink(parent_id=parent_id, child_id=child_id))
        db.commit()

    response = client.post(
        "/family/invites/issue",
        headers={
            "authorization": f"Bearer {parent['access_token']}",
            "x-forwarded-for": "203.0.113.11",
            "user-agent": "pytest-agent",
        },
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "parent_child_limit_reached"


def test_child_max_two_parents_limit(client: TestClient, db_session_factory) -> None:
    child = _register_user(client, role="student", email="child-limit@example.com")
    child_id = UUID(child["user"]["id"])

    first_parent = _register_user(client, role="parent", email="parent-limit-1@example.com")
    second_parent = _register_user(client, role="parent", email="parent-limit-2@example.com")
    third_parent = _register_user(client, role="parent", email="parent-limit-3@example.com")

    with db_session_factory() as db:
        db.add(
            ParentChildLink(parent_id=UUID(first_parent["user"]["id"]), child_id=child_id)
        )
        db.add(
            ParentChildLink(parent_id=UUID(second_parent["user"]["id"]), child_id=child_id)
        )
        db.commit()

    invite = _issue_invite(client, str(third_parent["access_token"]))

    response = client.post(
        "/family/invites/consume",
        json={
            "parent_id": third_parent["user"]["id"],
            "code": invite["code"],
            "device_id": "student-device",
        },
        headers=_student_headers(str(child["access_token"])),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "child_parent_limit_reached"


def test_duplicate_active_link_rejected(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="dup-parent@example.com")
    child = _register_user(client, role="student", email="dup-child@example.com")
    parent_id = UUID(parent["user"]["id"])
    child_id = UUID(child["user"]["id"])

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=child_id))
        db.commit()

    invite = _issue_invite(client, str(parent["access_token"]))

    response = client.post(
        "/family/invites/consume",
        json={"parent_id": str(parent_id), "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(child["access_token"])),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "duplicate_active_link"


def test_invite_verify_rate_limit_smoke(client: TestClient) -> None:
    student = _register_user(client, role="student", email="ratelimit-student@example.com")
    parent_id = uuid4()
    payload = {"parent_id": str(parent_id), "code": "123456", "device_id": "student-device"}
    headers = _student_headers(str(student["access_token"]))

    status_codes: list[int] = []
    for _ in range(6):
        response = client.post("/family/invites/verify", json=payload, headers=headers)
        status_codes.append(response.status_code)

    assert status_codes[:5] == [400, 400, 400, 400, 400]
    assert status_codes[5] == 429


def test_parent_unlink_success(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="unlink-parent@example.com")
    student = _register_user(client, role="student", email="unlink-student@example.com")
    parent_id = UUID(parent["user"]["id"])
    student_id = UUID(student["user"]["id"])

    invite = _issue_invite(client, str(parent["access_token"]))
    consume_response = client.post(
        "/family/invites/consume",
        json={"parent_id": str(parent_id), "code": invite["code"], "device_id": "student-device"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert consume_response.status_code == 200, consume_response.text

    unlink_response = client.post(
        "/family/unlink",
        json={"child_id": str(student_id)},
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert unlink_response.status_code == 200, unlink_response.text
    assert unlink_response.json()["parent_id"] == str(parent_id)
    assert unlink_response.json()["child_id"] == str(student_id)

    with db_session_factory() as db:
        link_row = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == parent_id,
                ParentChildLink.child_id == student_id,
            )
        ).scalar_one()
        audit_actions = db.execute(
            select(AuditLog.action).where(AuditLog.action == "parent_child_unlinked")
        ).scalars().all()

    assert link_row.unlinked_at is not None
    assert len(audit_actions) == 1


def test_student_unlink_forbidden(client: TestClient, db_session_factory) -> None:
    parent = _register_user(client, role="parent", email="unlink-forbidden-parent@example.com")
    student = _register_user(client, role="student", email="unlink-forbidden-student@example.com")
    parent_id = UUID(parent["user"]["id"])
    student_id = UUID(student["user"]["id"])

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=parent_id, child_id=student_id))
        db.commit()

    response = client.post(
        "/family/unlink",
        json={"child_id": str(student_id)},
        headers=_student_headers(str(student["access_token"])),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "parent_role_required"


def test_unlink_rejects_when_no_active_link(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="unlink-missing-parent@example.com")
    student = _register_user(client, role="student", email="unlink-missing-student@example.com")

    response = client.post(
        "/family/unlink",
        json={"child_id": student["user"]["id"]},
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "active_link_not_found"


def test_relink_after_unlink_requires_new_invite_success(
    client: TestClient,
    db_session_factory,
) -> None:
    parent = _register_user(client, role="parent", email="relink-parent@example.com")
    student = _register_user(client, role="student", email="relink-student@example.com")
    parent_id = UUID(parent["user"]["id"])
    student_id = UUID(student["user"]["id"])

    first_invite = _issue_invite(client, str(parent["access_token"]))
    first_consume = client.post(
        "/family/invites/consume",
        json={
            "parent_id": str(parent_id),
            "code": first_invite["code"],
            "device_id": "student-device",
        },
        headers=_student_headers(str(student["access_token"])),
    )
    assert first_consume.status_code == 200, first_consume.text

    unlink_response = client.post(
        "/family/unlink",
        json={"child_id": str(student_id)},
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert unlink_response.status_code == 200, unlink_response.text

    second_invite = _issue_invite(client, str(parent["access_token"]))
    second_consume = client.post(
        "/family/invites/consume",
        json={
            "parent_id": str(parent_id),
            "code": second_invite["code"],
            "device_id": "student-device",
        },
        headers=_student_headers(str(student["access_token"])),
    )
    assert second_consume.status_code == 200, second_consume.text

    with db_session_factory() as db:
        active_links = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == parent_id,
                ParentChildLink.child_id == student_id,
                ParentChildLink.unlinked_at.is_(None),
            )
        ).scalars().all()
        historical_links = db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == parent_id,
                ParentChildLink.child_id == student_id,
            )
        ).scalars().all()

    assert len(active_links) == 1
    assert len(historical_links) == 2


def test_register_rejects_hidden_unicode_in_email(client: TestClient) -> None:
    response = client.post(
        "/auth/register/student",
        json={
            "email": "bad\u200bemail@example.com",
            "password": TEST_PASSWORD,
            "device_id": TEST_DEVICE_ID,
        },
    )
    _assert_validation_error_detail(response, "invalid_hidden_unicode")


def test_login_rejects_hidden_unicode_in_device_id(client: TestClient) -> None:
    _register_user(client, role="student", email="device-check@example.com")

    response = client.post(
        "/auth/login",
        json={
            "email": "device-check@example.com",
            "password": "SecurePass123!",
            "device_id": "device\u202e1",
        },
    )
    _assert_validation_error_detail(response, "invalid_hidden_unicode")


def test_family_verify_consume_reject_hidden_unicode_device_id_and_code(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="hidden-parent@example.com")
    student = _register_user(client, role="student", email="hidden-student@example.com")
    invite = _issue_invite(client, str(parent["access_token"]))

    verify_device_response = client.post(
        "/family/invites/verify",
        json={
            "parent_id": parent["user"]["id"],
            "code": invite["code"],
            "device_id": "student\u200b-device",
        },
        headers=_student_headers(str(student["access_token"])),
    )
    _assert_validation_error_detail(verify_device_response, "invalid_hidden_unicode")

    consume_device_response = client.post(
        "/family/invites/consume",
        json={
            "parent_id": parent["user"]["id"],
            "code": invite["code"],
            "device_id": "student\u200b-device",
        },
        headers=_student_headers(str(student["access_token"])),
    )
    _assert_validation_error_detail(consume_device_response, "invalid_hidden_unicode")

    verify_code_response = client.post(
        "/family/invites/verify",
        json={
            "parent_id": parent["user"]["id"],
            "code": f"{invite['code']}\u200b",
            "device_id": "student-device",
        },
        headers=_student_headers(str(student["access_token"])),
    )
    _assert_validation_error_detail(verify_code_response, "invalid_hidden_unicode")


def test_student_link_code_issue_parent_consume_and_list_success(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="child-code-student@example.com")
    parent = _register_user(client, role="parent", email="child-code-parent@example.com")

    issue_response = _issue_child_link_code(client, str(student["access_token"]))
    assert issue_response["active_parent_count"] == 0
    assert issue_response["max_parents_per_child"] == 2

    consume_response = client.post(
        "/family/link-codes/consume",
        json={"code": issue_response["code"], "device_id": "parent-device"},
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert consume_response.status_code == 200, consume_response.text
    assert consume_response.json()["parent_id"] == parent["user"]["id"]
    assert consume_response.json()["child_id"] == student["user"]["id"]

    parent_links = client.get(
        "/family/links",
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert parent_links.status_code == 200, parent_links.text
    assert parent_links.json()["role"] == "PARENT"
    assert [row["email"] for row in parent_links.json()["linked_children"]] == [
        "child-code-student@example.com"
    ]

    student_links = client.get(
        "/family/links",
        headers=_student_headers(str(student["access_token"])),
    )
    assert student_links.status_code == 200, student_links.text
    assert student_links.json()["role"] == "STUDENT"
    assert [row["email"] for row in student_links.json()["linked_parents"]] == [
        "child-code-parent@example.com"
    ]

    with db_session_factory() as db:
        link_code = db.execute(select(FamilyLinkCode)).scalar_one()
        link_rows = db.execute(select(ParentChildLink)).scalars().all()

    assert link_code.consumed_at is not None
    assert str(link_code.consumed_by_user_id) == parent["user"]["id"]
    assert len(link_rows) == 1


def test_student_link_code_expired_rejected(client: TestClient, db_session_factory) -> None:
    student = _register_user(client, role="student", email="expired-link-student@example.com")
    parent = _register_user(client, role="parent", email="expired-link-parent@example.com")

    issue_response = _issue_child_link_code(client, str(student["access_token"]))

    with db_session_factory() as db:
        link_code = db.execute(select(FamilyLinkCode)).scalar_one()
        expired_base = datetime.now(UTC) - timedelta(hours=1)
        link_code.created_at = expired_base
        link_code.expires_at = expired_base + timedelta(minutes=1)
        db.commit()

    consume_response = client.post(
        "/family/link-codes/consume",
        json={"code": issue_response["code"], "device_id": "parent-device"},
        headers=_parent_headers(str(parent["access_token"])),
    )
    assert consume_response.status_code == 410
    assert consume_response.json()["detail"] == "link_code_expired"


def test_student_link_code_consumed_rejected(client: TestClient) -> None:
    student = _register_user(
        client,
        role="student",
        email="consumed-link-student@example.com",
    )
    first_parent = _register_user(
        client,
        role="parent",
        email="consumed-link-parent-1@example.com",
    )
    second_parent = _register_user(
        client,
        role="parent",
        email="consumed-link-parent-2@example.com",
    )

    issue_response = _issue_child_link_code(client, str(student["access_token"]))

    first_consume = client.post(
        "/family/link-codes/consume",
        json={"code": issue_response["code"], "device_id": "parent-device-1"},
        headers=_parent_headers(str(first_parent["access_token"])),
    )
    assert first_consume.status_code == 200, first_consume.text

    second_consume = client.post(
        "/family/link-codes/consume",
        json={"code": issue_response["code"], "device_id": "parent-device-2"},
        headers=_parent_headers(str(second_parent["access_token"])),
    )
    assert second_consume.status_code == 409
    assert second_consume.json()["detail"] == "link_code_already_consumed"


def test_child_link_code_issue_respects_parent_limit(
    client: TestClient,
    db_session_factory,
) -> None:
    student = _register_user(client, role="student", email="issue-limit-student@example.com")
    first_parent = _register_user(client, role="parent", email="issue-limit-parent-1@example.com")
    second_parent = _register_user(client, role="parent", email="issue-limit-parent-2@example.com")
    child_id = UUID(student["user"]["id"])

    with db_session_factory() as db:
        db.add(ParentChildLink(parent_id=UUID(first_parent["user"]["id"]), child_id=child_id))
        db.add(ParentChildLink(parent_id=UUID(second_parent["user"]["id"]), child_id=child_id))
        db.commit()

    response = client.post(
        "/family/link-codes",
        headers=_student_headers(str(student["access_token"])),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "child_parent_limit_reached"


def test_family_link_code_consume_rate_limit_smoke(client: TestClient) -> None:
    parent = _register_user(client, role="parent", email="link-ratelimit-parent@example.com")
    payload = {"code": "123456", "device_id": "parent-device"}
    headers = _parent_headers(str(parent["access_token"]))

    status_codes: list[int] = []
    for _ in range(6):
        response = client.post("/family/link-codes/consume", json=payload, headers=headers)
        status_codes.append(response.status_code)

    assert status_codes[:5] == [400, 400, 400, 400, 400]
    assert status_codes[5] == 429
