from __future__ import annotations

from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import json
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.models.billing_receipt_verification import BillingReceiptVerification
from app.models.billing_webhook_event import BillingWebhookEvent
from app.models.enums import BillingReceiptVerificationStatus, BillingWebhookStatus, UserSubscriptionStatus
from app.models.user_subscription import UserSubscription
import app.services.billing_service as billing_service

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _auth_headers(access_token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {access_token}"}


def _register_parent(
    client: TestClient,
    *,
    email: str,
    password: str = "SecurePass123!",
    device_id: str = "billing-device-1",
) -> dict[str, object]:
    response = client.post(
        "/auth/register/parent",
        json={"email": email, "password": password, "device_id": device_id},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_plan(
    client: TestClient,
    *,
    plan_code: str,
) -> None:
    response = client.post(
        "/internal/subscriptions/plans",
        json={
            "planCode": plan_code,
            "displayName": f"Plan {plan_code}",
            "featureCodes": ["CHILD_REPORTS", "WEEKLY_MOCK_EXAMS", "MONTHLY_MOCK_EXAMS"],
            "metadata": {"seed": plan_code},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text


def _stripe_signature(payload: bytes, *, secret: str, timestamp: int | None = None) -> str:
    signed_timestamp = timestamp or int(datetime.now(UTC).timestamp())
    signed_payload = f"{signed_timestamp}.{payload.decode('utf-8')}".encode("utf-8")
    digest = hmac.new(secret.encode("utf-8"), signed_payload, hashlib.sha256).hexdigest()
    return f"t={signed_timestamp},v1={digest}"


def test_stripe_webhook_processed_and_idempotent(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(billing_service.settings, "stripe_webhook_secret", "test-stripe-secret")

    parent = _register_parent(client, email="billing-stripe-parent@example.com")
    parent_id = str(parent["user"]["id"])
    _create_plan(client, plan_code="billing-pro")

    now = datetime.now(UTC)
    payload_dict = {
        "id": "evt_001",
        "type": "customer.subscription.updated",
        "data": {
            "object": {
                "id": "sub_001",
                "status": "active",
                "current_period_start": int((now - timedelta(days=1)).timestamp()),
                "current_period_end": int((now + timedelta(days=30)).timestamp()),
                "metadata": {
                    "parent_user_id": parent_id,
                    "plan_code": "billing-pro",
                },
            }
        },
    }
    payload_bytes = json.dumps(payload_dict, separators=(",", ":")).encode("utf-8")
    signature = _stripe_signature(payload_bytes, secret="test-stripe-secret")

    response = client.post(
        "/billing/webhooks/stripe",
        content=payload_bytes,
        headers={"Stripe-Signature": signature, "Content-Type": "application/json"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == BillingWebhookStatus.PROCESSED.value
    assert body["detailCode"] == "stripe_event_processed"

    duplicate_response = client.post(
        "/billing/webhooks/stripe",
        content=payload_bytes,
        headers={"Stripe-Signature": signature, "Content-Type": "application/json"},
    )
    assert duplicate_response.status_code == 200, duplicate_response.text
    assert duplicate_response.json()["detailCode"] == "stripe_event_duplicate"

    with db_session_factory() as db:
        webhook_row = db.execute(
            select(BillingWebhookEvent).where(BillingWebhookEvent.provider_event_id == "evt_001")
        ).scalar_one()
        assert webhook_row.status == BillingWebhookStatus.PROCESSED
        subscription = db.execute(
            select(UserSubscription).where(UserSubscription.external_billing_ref == "stripe:sub_001")
        ).scalar_one()
        assert subscription.status == UserSubscriptionStatus.ACTIVE
        assert subscription.owner_user_id == UUID(parent_id)


def test_stripe_webhook_invalid_signature_rejected(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(billing_service.settings, "stripe_webhook_secret", "test-stripe-secret")
    payload_bytes = b'{"id":"evt_invalid","type":"customer.subscription.updated"}'

    response = client.post(
        "/billing/webhooks/stripe",
        content=payload_bytes,
        headers={"Stripe-Signature": "t=1,v1=invalid", "Content-Type": "application/json"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "invalid_stripe_signature"


def test_app_store_receipt_verify_success(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(billing_service.settings, "app_store_shared_secret", "app-store-shared-secret")

    parent = _register_parent(client, email="billing-app-store-parent@example.com")
    parent_id = str(parent["user"]["id"])
    _create_plan(client, plan_code="billing-app-store-plan")

    now = datetime.now(UTC)
    purchase_ms = int((now - timedelta(days=1)).timestamp() * 1000)
    expiry_ms = int((now + timedelta(days=30)).timestamp() * 1000)

    def fake_post_json(*, url: str, payload: dict[str, object]) -> dict[str, object]:
        _ = url
        _ = payload
        return {
            "status": 0,
            "latest_receipt_info": [
                {
                    "transaction_id": "tx-001",
                    "original_transaction_id": "otx-001",
                    "purchase_date_ms": str(purchase_ms),
                    "expires_date_ms": str(expiry_ms),
                }
            ],
        }

    monkeypatch.setattr(billing_service, "_post_json", fake_post_json)

    response = client.post(
        "/billing/app-store/verify",
        json={
            "planCode": "billing-app-store-plan",
            "receiptData": "encoded-receipt-data",
            "metadata": {"source": "pytest"},
        },
        headers=_auth_headers(str(parent["access_token"])),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == BillingReceiptVerificationStatus.VERIFIED.value
    assert body["detailCode"] == "app_store_receipt_verified"
    assert body["subscriptionId"] is not None

    with db_session_factory() as db:
        row = db.execute(
            select(BillingReceiptVerification).where(BillingReceiptVerification.owner_user_id == UUID(parent_id))
        ).scalar_one()
        assert row.status == BillingReceiptVerificationStatus.VERIFIED
        subscription = db.get(UserSubscription, row.subscription_id)
        assert subscription is not None
        assert subscription.external_billing_ref == "appstore:otx-001"


def test_app_store_receipt_verify_rejected(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(billing_service.settings, "app_store_shared_secret", "app-store-shared-secret")
    parent = _register_parent(client, email="billing-app-store-rejected@example.com")
    _create_plan(client, plan_code="billing-app-store-rejected-plan")

    def fake_post_json(*, url: str, payload: dict[str, object]) -> dict[str, object]:
        _ = url
        _ = payload
        return {"status": 21010}

    monkeypatch.setattr(billing_service, "_post_json", fake_post_json)

    response = client.post(
        "/billing/app-store/verify",
        json={
            "planCode": "billing-app-store-rejected-plan",
            "receiptData": "invalid-receipt-data",
            "metadata": {},
        },
        headers=_auth_headers(str(parent["access_token"])),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == BillingReceiptVerificationStatus.REJECTED.value
    assert body["detailCode"] == "app_store_receipt_rejected"
    assert body["subscriptionId"] is None

    with db_session_factory() as db:
        rows = db.execute(select(BillingReceiptVerification)).scalars().all()
        assert rows
        assert rows[-1].status == BillingReceiptVerificationStatus.REJECTED
