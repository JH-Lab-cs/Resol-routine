from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import json
from typing import Any
from urllib import error as urllib_error
from urllib import request as urllib_request
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.policies import (
    BILLING_PROVIDER_RESPONSE_MAX_LENGTH,
    BILLING_WEBHOOK_SIGNATURE_TOLERANCE_SECONDS,
)
from app.models.billing_receipt_verification import BillingReceiptVerification
from app.models.billing_webhook_event import BillingWebhookEvent
from app.models.enums import (
    BillingProvider,
    BillingReceiptVerificationStatus,
    BillingWebhookStatus,
    UserSubscriptionStatus,
)
from app.schemas.billing import (
    AppStoreReceiptVerifyRequest,
    AppStoreReceiptVerifyResponse,
    StripeWebhookResponse,
)
from app.services.audit_service import append_audit_log
from app.services.subscription_service import upsert_parent_subscription_from_billing


@dataclass(frozen=True, slots=True)
class StripeWebhookOutcome:
    status: BillingWebhookStatus
    detail_code: str
    owner_user_id: UUID | None
    subscription_id: UUID | None
    details: dict[str, object]


def process_stripe_webhook(
    db: Session,
    *,
    payload_bytes: bytes,
    stripe_signature: str | None,
    request_id: str | None,
) -> StripeWebhookResponse:
    secret = settings.stripe_webhook_secret
    if secret is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="stripe_webhook_not_configured")

    if stripe_signature is None or not stripe_signature.strip():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing_stripe_signature")

    _verify_stripe_signature(payload_bytes=payload_bytes, signature_header=stripe_signature, secret=secret)
    payload_sha256 = hashlib.sha256(payload_bytes).hexdigest()

    payload_json = _parse_json_bytes(payload_bytes, invalid_detail="invalid_stripe_payload")
    event_id = str(payload_json.get("id", "")).strip()
    event_type = str(payload_json.get("type", "")).strip()
    if not event_id or not event_type:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_stripe_event")

    existing = db.execute(
        select(BillingWebhookEvent).where(
            BillingWebhookEvent.provider == BillingProvider.STRIPE,
            BillingWebhookEvent.provider_event_id == event_id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return StripeWebhookResponse(
            status=existing.status,
            event_id=existing.provider_event_id,
            detail_code="stripe_event_duplicate",
        )

    event_row = BillingWebhookEvent(
        provider=BillingProvider.STRIPE,
        provider_event_id=event_id,
        event_type=event_type,
        status=BillingWebhookStatus.IGNORED,
        owner_user_id=None,
        subscription_id=None,
        request_id=request_id,
        payload_sha256=payload_sha256,
        details={},
    )
    db.add(event_row)
    db.flush()

    now = datetime.now(UTC)
    try:
        outcome = _apply_stripe_event(db, payload_json=payload_json)
        event_row.status = outcome.status
        event_row.owner_user_id = outcome.owner_user_id
        event_row.subscription_id = outcome.subscription_id
        event_row.details = outcome.details
        event_row.error_code = None
        event_row.error_message = None
        detail_code = outcome.detail_code
    except HTTPException as exc:
        detail_code = exc.detail if isinstance(exc.detail, str) else "stripe_event_processing_failed"
        event_row.status = BillingWebhookStatus.FAILED
        event_row.error_code = detail_code[:64]
        event_row.error_message = detail_code[:BILLING_PROVIDER_RESPONSE_MAX_LENGTH]
        event_row.details = {"eventType": event_type}
    except Exception as exc:  # pragma: no cover - defensive fallback
        detail_code = "stripe_event_processing_failed"
        event_row.status = BillingWebhookStatus.FAILED
        event_row.error_code = detail_code
        event_row.error_message = str(exc)[:BILLING_PROVIDER_RESPONSE_MAX_LENGTH]
        event_row.details = {"eventType": event_type}

    event_row.processed_at = now
    db.flush()

    append_audit_log(
        db,
        action="billing_stripe_webhook_processed",
        actor_user_id=None,
        target_user_id=event_row.owner_user_id,
        details={
            "event_id": event_id,
            "event_type": event_type,
            "status": event_row.status.value,
            "detail_code": detail_code,
        },
    )

    return StripeWebhookResponse(
        status=event_row.status,
        event_id=event_id,
        detail_code=detail_code,
    )


def verify_app_store_receipt_for_parent(
    db: Session,
    *,
    parent_id: UUID,
    payload: AppStoreReceiptVerifyRequest,
) -> AppStoreReceiptVerifyResponse:
    shared_secret = settings.app_store_shared_secret
    if shared_secret is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="app_store_verify_not_configured")

    request_hash = hashlib.sha256(payload.receipt_data.encode("utf-8")).hexdigest()
    now = datetime.now(UTC)
    verify_status: BillingReceiptVerificationStatus = BillingReceiptVerificationStatus.ERROR
    detail_code = "app_store_verify_error"
    provider_response_code: str | None = None
    starts_at: datetime | None = None
    expires_at: datetime | None = None
    subscription_id: UUID | None = None
    transaction_id: str | None = None
    original_transaction_id: str | None = None
    verification_details: dict[str, object] = {}

    try:
        verify_response, used_sandbox = _verify_app_store_receipt(
            receipt_data=payload.receipt_data,
            shared_secret=shared_secret,
        )
        status_code_value = verify_response.get("status")
        provider_response_code = str(status_code_value)
        verification_details["usedSandbox"] = used_sandbox

        if status_code_value != 0:
            verify_status = BillingReceiptVerificationStatus.REJECTED
            detail_code = "app_store_receipt_rejected"
        else:
            parsed_receipt = _extract_latest_app_store_receipt(verify_response)
            transaction_id = parsed_receipt.get("transaction_id")
            original_transaction_id = parsed_receipt.get("original_transaction_id")
            starts_at = _millis_to_datetime(parsed_receipt.get("purchase_date_ms"), fallback=now)
            expires_at = _millis_to_datetime(parsed_receipt.get("expires_date_ms"), fallback=now)
            target_status = (
                UserSubscriptionStatus.ACTIVE
                if expires_at > now
                else UserSubscriptionStatus.EXPIRED
            )
            external_ref_source = original_transaction_id or transaction_id
            if external_ref_source is None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="app_store_transaction_id_missing",
                )
            subscription = upsert_parent_subscription_from_billing(
                db,
                parent_id=parent_id,
                plan_code=payload.plan_code,
                external_billing_ref=f"appstore:{external_ref_source}",
                subscription_status=target_status,
                starts_at=starts_at,
                ends_at=expires_at if expires_at > starts_at else starts_at + timedelta(seconds=1),
                grace_ends_at=None,
                metadata_json={
                    "source": "app_store_receipt_verify",
                    "requestHash": request_hash,
                    "providerResponseCode": provider_response_code,
                    "metadata": payload.metadata_json,
                },
            )
            subscription_id = subscription.id
            verify_status = BillingReceiptVerificationStatus.VERIFIED
            detail_code = "app_store_receipt_verified"
    except HTTPException as exc:
        verify_status = BillingReceiptVerificationStatus.ERROR
        detail_code = exc.detail if isinstance(exc.detail, str) else "app_store_verify_error"
    except Exception:
        verify_status = BillingReceiptVerificationStatus.ERROR
        detail_code = "app_store_verify_error"

    receipt_row = BillingReceiptVerification(
        provider=BillingProvider.APP_STORE,
        owner_user_id=parent_id,
        subscription_id=subscription_id,
        status=verify_status,
        plan_code=payload.plan_code,
        transaction_id=transaction_id,
        original_transaction_id=original_transaction_id,
        verification_request_hash=request_hash,
        provider_response_code=provider_response_code,
        error_code=None if verify_status == BillingReceiptVerificationStatus.VERIFIED else detail_code[:64],
        error_message=None if verify_status == BillingReceiptVerificationStatus.VERIFIED else detail_code,
        details=verification_details,
        verified_at=now if verify_status == BillingReceiptVerificationStatus.VERIFIED else None,
        starts_at=starts_at,
        expires_at=expires_at,
    )
    db.add(receipt_row)
    db.flush()

    append_audit_log(
        db,
        action="billing_app_store_receipt_verified",
        actor_user_id=parent_id,
        target_user_id=parent_id,
        details={
            "verification_id": str(receipt_row.id),
            "status": verify_status.value,
            "detail_code": detail_code,
            "subscription_id": str(subscription_id) if subscription_id is not None else None,
        },
    )

    return AppStoreReceiptVerifyResponse(
        verification_id=str(receipt_row.id),
        status=verify_status,
        subscription_id=str(subscription_id) if subscription_id is not None else None,
        plan_code=payload.plan_code,
        starts_at=starts_at,
        expires_at=expires_at,
        provider_response_code=provider_response_code,
        detail_code=detail_code,
    )


def _apply_stripe_event(db: Session, *, payload_json: dict[str, object]) -> StripeWebhookOutcome:
    event_type = str(payload_json.get("type", ""))
    supported_event_types = {
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
    }
    if event_type not in supported_event_types:
        return StripeWebhookOutcome(
            status=BillingWebhookStatus.IGNORED,
            detail_code="stripe_event_ignored",
            owner_user_id=None,
            subscription_id=None,
            details={"eventType": event_type},
        )

    data_object = payload_json.get("data")
    if not isinstance(data_object, dict):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_stripe_event")
    stripe_object = data_object.get("object")
    if not isinstance(stripe_object, dict):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_stripe_event")

    metadata = stripe_object.get("metadata")
    if not isinstance(metadata, dict):
        return StripeWebhookOutcome(
            status=BillingWebhookStatus.IGNORED,
            detail_code="stripe_metadata_missing",
            owner_user_id=None,
            subscription_id=None,
            details={"eventType": event_type},
        )

    parent_user_id_raw = metadata.get("parent_user_id") or metadata.get("parentUserId")
    plan_code_raw = metadata.get("plan_code") or metadata.get("planCode")
    if not isinstance(parent_user_id_raw, str) or not isinstance(plan_code_raw, str):
        return StripeWebhookOutcome(
            status=BillingWebhookStatus.IGNORED,
            detail_code="stripe_metadata_missing",
            owner_user_id=None,
            subscription_id=None,
            details={"eventType": event_type},
        )

    try:
        parent_user_id = UUID(parent_user_id_raw)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="stripe_parent_id_invalid") from exc

    subscription_external_ref = stripe_object.get("id")
    if not isinstance(subscription_external_ref, str) or not subscription_external_ref.strip():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="stripe_subscription_id_missing")

    now = datetime.now(UTC)
    starts_at = _unix_seconds_to_datetime(stripe_object.get("current_period_start"), fallback=now)
    ends_at = _unix_seconds_to_datetime(stripe_object.get("current_period_end"), fallback=now)
    if ends_at <= starts_at:
        ends_at = starts_at + timedelta(seconds=1)

    target_status = _map_stripe_subscription_status(
        event_type=event_type,
        stripe_status=str(stripe_object.get("status", "")).strip().lower(),
    )
    grace_ends_at = ends_at if target_status == UserSubscriptionStatus.GRACE else None

    subscription = upsert_parent_subscription_from_billing(
        db,
        parent_id=parent_user_id,
        plan_code=plan_code_raw.strip(),
        external_billing_ref=f"stripe:{subscription_external_ref.strip()}",
        subscription_status=target_status,
        starts_at=starts_at,
        ends_at=ends_at,
        grace_ends_at=grace_ends_at,
        metadata_json={
            "source": "stripe_webhook",
            "eventType": event_type,
            "stripeStatus": stripe_object.get("status"),
        },
    )

    return StripeWebhookOutcome(
        status=BillingWebhookStatus.PROCESSED,
        detail_code="stripe_event_processed",
        owner_user_id=parent_user_id,
        subscription_id=subscription.id,
        details={
            "eventType": event_type,
            "planCode": plan_code_raw.strip(),
            "subscriptionStatus": target_status.value,
        },
    )


def _map_stripe_subscription_status(*, event_type: str, stripe_status: str) -> UserSubscriptionStatus:
    if event_type == "customer.subscription.deleted":
        return UserSubscriptionStatus.EXPIRED
    if stripe_status == "trialing":
        return UserSubscriptionStatus.TRIALING
    if stripe_status == "active":
        return UserSubscriptionStatus.ACTIVE
    if stripe_status in {"past_due", "unpaid"}:
        return UserSubscriptionStatus.GRACE
    if stripe_status in {"canceled", "incomplete_expired"}:
        return UserSubscriptionStatus.EXPIRED
    return UserSubscriptionStatus.CANCELED


def _verify_stripe_signature(*, payload_bytes: bytes, signature_header: str, secret: str) -> None:
    timestamp, signatures = _parse_stripe_signature_header(signature_header)
    now_unix = int(datetime.now(UTC).timestamp())
    if abs(now_unix - timestamp) > BILLING_WEBHOOK_SIGNATURE_TOLERANCE_SECONDS:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_stripe_signature")

    signed_payload = f"{timestamp}.{payload_bytes.decode('utf-8')}".encode("utf-8")
    expected = hmac.new(secret.encode("utf-8"), signed_payload, hashlib.sha256).hexdigest()
    if not any(hmac.compare_digest(expected, candidate) for candidate in signatures):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_stripe_signature")


def _parse_stripe_signature_header(header_value: str) -> tuple[int, list[str]]:
    parts = [part.strip() for part in header_value.split(",") if part.strip()]
    timestamp: int | None = None
    signatures: list[str] = []
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", maxsplit=1)
        if key == "t":
            try:
                timestamp = int(value)
            except ValueError as exc:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_stripe_signature") from exc
        elif key == "v1":
            signatures.append(value)

    if timestamp is None or not signatures:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_stripe_signature")
    return timestamp, signatures


def _verify_app_store_receipt(*, receipt_data: str, shared_secret: str) -> tuple[dict[str, object], bool]:
    production_payload = {
        "receipt-data": receipt_data,
        "password": shared_secret,
        "exclude-old-transactions": True,
    }
    production_response = _post_json(
        url=settings.app_store_verify_url,
        payload=production_payload,
    )
    production_status = production_response.get("status")
    if production_status == 21007:
        sandbox_response = _post_json(
            url=settings.app_store_sandbox_verify_url,
            payload=production_payload,
        )
        return sandbox_response, True
    return production_response, False


def _post_json(*, url: str, payload: dict[str, object]) -> dict[str, object]:
    encoded_payload = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib_request.Request(
        url=url,
        data=encoded_payload,
        headers={"content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib_request.urlopen(request, timeout=20) as response:
            body = response.read().decode("utf-8")
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"billing_provider_http_error:{exc.code}:{body[:200]}",
        ) from exc
    except urllib_error.URLError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"billing_provider_network_error:{exc.reason}") from exc

    try:
        decoded = json.loads(body)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="billing_provider_invalid_json") from exc
    if not isinstance(decoded, dict):
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="billing_provider_invalid_json")
    return decoded


def _extract_latest_app_store_receipt(response_payload: dict[str, object]) -> dict[str, str]:
    latest_items = response_payload.get("latest_receipt_info")
    if not isinstance(latest_items, list):
        receipt = response_payload.get("receipt")
        if isinstance(receipt, dict):
            latest_items = receipt.get("in_app")
    if not isinstance(latest_items, list) or not latest_items:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="app_store_receipt_missing_transactions")

    def sort_key(item: object) -> int:
        if not isinstance(item, dict):
            return 0
        raw_value = item.get("expires_date_ms")
        try:
            return int(str(raw_value))
        except Exception:
            return 0

    latest_item = max(latest_items, key=sort_key)
    if not isinstance(latest_item, dict):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="app_store_receipt_invalid_transaction")

    return {
        "transaction_id": str(latest_item.get("transaction_id", "")).strip() or None,
        "original_transaction_id": str(latest_item.get("original_transaction_id", "")).strip() or None,
        "purchase_date_ms": str(latest_item.get("purchase_date_ms", "")).strip() or "0",
        "expires_date_ms": str(latest_item.get("expires_date_ms", "")).strip() or "0",
    }


def _parse_json_bytes(payload_bytes: bytes, *, invalid_detail: str) -> dict[str, object]:
    try:
        parsed = json.loads(payload_bytes.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail) from exc
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail) from exc
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail)
    return parsed


def _unix_seconds_to_datetime(raw_value: object, *, fallback: datetime) -> datetime:
    try:
        if raw_value is None:
            return fallback
        seconds = int(raw_value)
        return datetime.fromtimestamp(seconds, tz=UTC)
    except Exception:
        return fallback


def _millis_to_datetime(raw_value: object, *, fallback: datetime) -> datetime:
    try:
        milliseconds = int(str(raw_value))
        return datetime.fromtimestamp(milliseconds / 1000, tz=UTC)
    except Exception:
        return fallback
