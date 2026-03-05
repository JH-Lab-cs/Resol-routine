from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import lru_cache
import mimetypes
import re
from uuid import UUID, uuid4

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.policies import (
    CONTENT_ASSET_ALLOWED_MIME_TYPES,
    CONTENT_OBJECT_KEY_MAX_LENGTH,
    R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
    R2_UPLOAD_SIGNED_URL_TTL_SECONDS,
)
from app.models.content_asset import ContentAsset
from app.schemas.content import (
    AssetFinalizeRequest,
    AssetUploadUrlRequest,
    AssetUploadUrlResponse,
    ContentAssetResponse,
)

_SAFE_OBJECT_KEY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9/._-]*$")
_OBJECT_KEY_PREFIX = "content-assets/"


@dataclass(frozen=True, slots=True)
class AssetDownloadUrlResult:
    asset_id: UUID
    object_key: str
    download_url: str
    expires_in_seconds: int
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class R2ObjectMetadata:
    content_length: int | None
    content_type: str | None
    etag: str | None


class R2Signer:
    def __init__(self) -> None:
        self._bucket = settings.r2_bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint,
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
            config=Config(signature_version="s3v4"),
        )

    @property
    def bucket(self) -> str:
        return self._bucket

    def generate_upload_url(self, *, object_key: str, mime_type: str, expires_in_seconds: int) -> str:
        return self._client.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": self._bucket,
                "Key": object_key,
                "ContentType": mime_type,
            },
            ExpiresIn=expires_in_seconds,
        )

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        return self._client.generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": self._bucket,
                "Key": object_key,
            },
            ExpiresIn=expires_in_seconds,
        )

    def get_object_metadata(self, *, object_key: str) -> R2ObjectMetadata | None:
        try:
            response = self._client.head_object(
                Bucket=self._bucket,
                Key=object_key,
            )
        except ClientError as exc:
            error_code = str(exc.response.get("Error", {}).get("Code", ""))
            if error_code in {"404", "NoSuchKey", "NotFound"}:
                return None
            raise
        return R2ObjectMetadata(
            content_length=int(response.get("ContentLength", 0))
            if response.get("ContentLength") is not None
            else None,
            content_type=response.get("ContentType"),
            etag=_normalize_etag(response.get("ETag")),
        )


@lru_cache(maxsize=1)
def get_r2_signer() -> R2Signer:
    return R2Signer()


def issue_asset_upload_url(db: Session, *, payload: AssetUploadUrlRequest) -> AssetUploadUrlResponse:
    _ensure_allowed_mime_type(payload.mime_type)

    signer = get_r2_signer()
    object_key = _generate_unique_object_key(
        db,
        request_id=payload.request_id,
        mime_type=payload.mime_type,
        sha256_hex=payload.sha256_hex,
    )

    now = datetime.now(UTC)
    expires_at = now + timedelta(seconds=R2_UPLOAD_SIGNED_URL_TTL_SECONDS)
    upload_url = signer.generate_upload_url(
        object_key=object_key,
        mime_type=payload.mime_type,
        expires_in_seconds=R2_UPLOAD_SIGNED_URL_TTL_SECONDS,
    )

    return AssetUploadUrlResponse(
        object_key=object_key,
        upload_url=upload_url,
        expires_in_seconds=R2_UPLOAD_SIGNED_URL_TTL_SECONDS,
        expires_at=expires_at,
    )


def finalize_asset(db: Session, *, payload: AssetFinalizeRequest) -> ContentAssetResponse:
    _ensure_allowed_mime_type(payload.mime_type)
    _ensure_safe_object_key(payload.object_key)

    if payload.bucket is not None and payload.bucket != settings.r2_bucket:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_asset_bucket")
    signer = get_r2_signer()
    object_metadata = _fetch_object_metadata_or_reject(signer=signer, object_key=payload.object_key)
    _validate_finalize_metadata(payload=payload, object_metadata=object_metadata)

    existing = db.execute(
        select(ContentAsset).where(ContentAsset.object_key == payload.object_key)
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="asset_object_key_conflict")

    asset = ContentAsset(
        object_key=payload.object_key,
        mime_type=payload.mime_type,
        size_bytes=payload.size_bytes,
        sha256_hex=payload.sha256_hex,
        etag=payload.etag,
        bucket=settings.r2_bucket,
    )
    db.add(asset)
    db.flush()

    return ContentAssetResponse(
        id=asset.id,
        object_key=asset.object_key,
        mime_type=asset.mime_type,
        size_bytes=asset.size_bytes,
        sha256_hex=asset.sha256_hex,
        etag=asset.etag,
        bucket=asset.bucket,
        created_at=asset.created_at,
        updated_at=asset.updated_at,
    )


def issue_asset_download_url(db: Session, *, asset_id: UUID) -> AssetDownloadUrlResult:
    asset = db.get(ContentAsset, asset_id)
    if asset is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="asset_not_found")

    signer = get_r2_signer()
    now = datetime.now(UTC)
    expires_at = now + timedelta(seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS)
    download_url = signer.generate_download_url(
        object_key=asset.object_key,
        expires_in_seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
    )

    return AssetDownloadUrlResult(
        asset_id=asset.id,
        object_key=asset.object_key,
        download_url=download_url,
        expires_in_seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
        expires_at=expires_at,
    )


def _ensure_allowed_mime_type(mime_type: str) -> None:
    if mime_type not in CONTENT_ASSET_ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="unsupported_mime_type")


def _generate_unique_object_key(
    db: Session,
    *,
    request_id: str,
    mime_type: str,
    sha256_hex: str,
) -> str:
    suffix = _mime_suffix(mime_type)
    date_part = datetime.now(UTC).strftime("%Y/%m/%d")
    request_key = _normalize_request_id_for_object_key(request_id)
    for _ in range(5):
        object_key = (
            f"{_OBJECT_KEY_PREFIX}{date_part}/{request_key}-{sha256_hex[:12]}-{uuid4().hex}{suffix}"
        )
        _ensure_safe_object_key(object_key)
        exists = db.execute(
            select(ContentAsset.id).where(ContentAsset.object_key == object_key)
        ).scalar_one_or_none()
        if exists is None:
            return object_key
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="asset_object_key_generation_failed",
    )


def _mime_suffix(mime_type: str) -> str:
    if mime_type == "audio/mpeg":
        return ".mp3"
    if mime_type == "audio/mp4":
        return ".m4a"
    if mime_type == "audio/wav":
        return ".wav"
    guessed = mimetypes.guess_extension(mime_type) or ".bin"
    return guessed


def _ensure_safe_object_key(value: str) -> None:
    if not value.startswith(_OBJECT_KEY_PREFIX):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_object_key")
    if len(value) > CONTENT_OBJECT_KEY_MAX_LENGTH:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="object_key_too_long")
    if value.startswith("/") or ".." in value or "\\" in value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_object_key")
    if "//" in value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_object_key")
    if _SAFE_OBJECT_KEY_PATTERN.fullmatch(value) is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_object_key")


def _normalize_request_id_for_object_key(value: str) -> str:
    lowered = value.lower()
    normalized = re.sub(r"[^a-z0-9._-]+", "-", lowered).strip("-")
    if not normalized:
        return "req"
    if len(normalized) > 64:
        return normalized[:64]
    return normalized


def _fetch_object_metadata_or_reject(*, signer: R2Signer, object_key: str) -> R2ObjectMetadata:
    try:
        object_metadata = signer.get_object_metadata(object_key=object_key)
    except ClientError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="asset_head_check_failed",
        ) from exc
    if object_metadata is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="asset_object_not_found")
    return object_metadata


def _validate_finalize_metadata(
    *,
    payload: AssetFinalizeRequest,
    object_metadata: R2ObjectMetadata,
) -> None:
    if object_metadata.content_length is not None and object_metadata.content_length != payload.size_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="asset_size_mismatch")

    if object_metadata.content_type:
        observed_content_type = object_metadata.content_type.lower().split(";", maxsplit=1)[0].strip()
        if observed_content_type != payload.mime_type:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="asset_mime_type_mismatch")

    if payload.etag is not None and object_metadata.etag is not None:
        payload_etag = _normalize_etag(payload.etag)
        if payload_etag != object_metadata.etag:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="asset_etag_mismatch")


def _normalize_etag(value: str | None) -> str | None:
    if value is None:
        return None
    return value.strip().strip("\"")
