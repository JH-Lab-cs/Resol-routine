from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import lru_cache
import json
import re
from typing import Any
from uuid import UUID

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException, status

from app.core.config import settings
from app.core.policies import AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH, R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS

_SAFE_OBJECT_KEY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9/._-]*$")
_OBJECT_KEY_PREFIX = "ai-artifacts/"


@dataclass(frozen=True, slots=True)
class ArtifactDownloadUrlResult:
    object_key: str
    download_url: str
    expires_in_seconds: int
    expires_at: datetime


class ArtifactStoreError(RuntimeError):
    def __init__(self, *, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class AIGenerationArtifactStore:
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

    def put_json(self, *, kind: str, job_id: UUID, payload: dict[str, object]) -> str:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        return self.put_text(
            kind=kind,
            job_id=job_id,
            body=body,
            content_type="application/json",
        )

    def put_text(self, *, kind: str, job_id: UUID, body: str, content_type: str = "text/plain") -> str:
        object_key = _build_object_key(kind=kind, job_id=job_id)
        self._client.put_object(
            Bucket=self._bucket,
            Key=object_key,
            Body=body.encode("utf-8"),
            ContentType=content_type,
        )
        return object_key

    def get_text(self, *, object_key: str) -> str:
        _ensure_safe_object_key(object_key)
        try:
            response = self._client.get_object(Bucket=self._bucket, Key=object_key)
        except ClientError as exc:
            error_code = str(exc.response.get("Error", {}).get("Code", ""))
            if error_code in {"404", "NoSuchKey", "NotFound"}:
                raise ArtifactStoreError(code="artifact_object_not_found", message="Artifact object does not exist.") from exc
            raise ArtifactStoreError(code="artifact_object_read_failed", message="Failed to read artifact object.") from exc

        body = response.get("Body")
        if body is None:
            raise ArtifactStoreError(code="artifact_object_read_failed", message="Artifact body is missing.")

        try:
            content = body.read()
        except Exception as exc:  # pragma: no cover - defensive fallback for stream failures
            raise ArtifactStoreError(code="artifact_object_read_failed", message="Failed to read artifact stream.") from exc
        return content.decode("utf-8")

    def get_json(self, *, object_key: str) -> dict[str, Any]:
        text_payload = self.get_text(object_key=object_key)
        try:
            decoded = json.loads(text_payload)
        except json.JSONDecodeError as exc:
            raise ArtifactStoreError(code="artifact_object_invalid_json", message="Artifact payload is not valid JSON.") from exc
        if not isinstance(decoded, dict):
            raise ArtifactStoreError(code="artifact_object_invalid_json", message="Artifact payload must be a JSON object.")
        return decoded

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        return self._client.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": self._bucket, "Key": object_key},
            ExpiresIn=expires_in_seconds,
        )


@lru_cache(maxsize=1)
def get_ai_artifact_store() -> AIGenerationArtifactStore:
    return AIGenerationArtifactStore()


def issue_artifact_download_url(*, object_key: str) -> ArtifactDownloadUrlResult:
    _ensure_safe_object_key(object_key)
    store = get_ai_artifact_store()
    expires_at = datetime.now(UTC) + timedelta(seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS)
    download_url = store.generate_download_url(
        object_key=object_key,
        expires_in_seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
    )
    return ArtifactDownloadUrlResult(
        object_key=object_key,
        download_url=download_url,
        expires_in_seconds=R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
        expires_at=expires_at,
    )


def _build_object_key(*, kind: str, job_id: UUID) -> str:
    timestamp = datetime.now(UTC).strftime("%Y/%m/%d/%H%M%S")
    normalized_kind = _normalize_kind(kind)
    object_key = f"{_OBJECT_KEY_PREFIX}{timestamp}/{job_id}/{normalized_kind}-{datetime.now(UTC).timestamp():.6f}.json"
    _ensure_safe_object_key(object_key)
    return object_key


def _normalize_kind(kind: str) -> str:
    lowered = kind.strip().lower().replace(" ", "-")
    lowered = lowered.replace("/", "-")
    lowered = re.sub(r"[^a-z0-9._-]+", "-", lowered).strip("-")
    if not lowered:
        return "artifact"
    return lowered[:64]


def _ensure_safe_object_key(value: str) -> None:
    if not value.startswith(_OBJECT_KEY_PREFIX):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_artifact_object_key")
    if len(value) > AI_ARTIFACT_OBJECT_KEY_MAX_LENGTH:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="artifact_object_key_too_long")
    if value.startswith("/") or ".." in value or "\\" in value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_artifact_object_key")
    if "//" in value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_artifact_object_key")
    if _SAFE_OBJECT_KEY_PATTERN.fullmatch(value) is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_artifact_object_key")
