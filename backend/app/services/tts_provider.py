from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Protocol
from urllib import error as urllib_error
from urllib import request as urllib_request

from app.core.config import settings
from app.core.policies import AI_PROVIDER_HTTP_TIMEOUT_SECONDS, TTS_OUTPUT_MIME_TYPE


@dataclass(frozen=True, slots=True)
class TTSProviderResult:
    provider_name: str
    model_name: str
    voice: str
    speed: float
    mime_type: str
    audio_bytes: bytes
    raw_request: str
    raw_response: str


class TTSProviderError(RuntimeError):
    def __init__(self, *, code: str, message: str, transient: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.transient = transient


class TTSProvider(Protocol):
    def synthesize(self, *, text: str) -> TTSProviderResult: ...


class FakeTTSProvider:
    def __init__(self, *, model_name: str, voice: str, speed: float) -> None:
        self._model_name = model_name
        self._voice = voice
        self._speed = speed

    def synthesize(self, *, text: str) -> TTSProviderResult:
        request_payload = {
            "provider": "fake",
            "model": self._model_name,
            "voice": self._voice,
            "speed": self._speed,
            "textLength": len(text),
            "textSha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        }
        digest = hashlib.sha256(
            f"{self._model_name}|{self._voice}|{self._speed}|{text}".encode()
        ).digest()
        audio_bytes = b"FAKE_MP3_" + digest
        response_payload = {
            "mimeType": TTS_OUTPUT_MIME_TYPE,
            "byteLength": len(audio_bytes),
            "byteSha256": hashlib.sha256(audio_bytes).hexdigest(),
        }
        return TTSProviderResult(
            provider_name="fake",
            model_name=self._model_name,
            voice=self._voice,
            speed=self._speed,
            mime_type=TTS_OUTPUT_MIME_TYPE,
            audio_bytes=audio_bytes,
            raw_request=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=json.dumps(response_payload, ensure_ascii=False, separators=(",", ":")),
        )


class OpenAITTSProvider:
    def __init__(
        self,
        *,
        api_key: str,
        model_name: str,
        voice: str,
        speed: float,
        base_url: str,
    ) -> None:
        self._api_key = api_key
        self._model_name = model_name
        self._voice = voice
        self._speed = speed
        self._endpoint = f"{base_url.rstrip('/')}/v1/audio/speech"

    def synthesize(self, *, text: str) -> TTSProviderResult:
        request_payload: dict[str, Any] = {
            "model": self._model_name,
            "voice": self._voice,
            "input": text,
            "response_format": "mp3",
            "speed": self._speed,
        }

        request = urllib_request.Request(  # noqa: S310
            url=self._endpoint,
            data=json.dumps(request_payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib_request.urlopen(  # noqa: S310
                request,
                timeout=AI_PROVIDER_HTTP_TIMEOUT_SECONDS,
            ) as response:
                content_type = str(response.headers.get("Content-Type", "")).split(
                    ";",
                    maxsplit=1,
                )[0].strip()
                body = response.read()
        except urllib_error.HTTPError as exc:
            status_code = int(exc.code)
            transient = status_code == 429 or 500 <= status_code < 600
            code = "PROVIDER_BAD_RESPONSE"
            raise TTSProviderError(
                code=code,
                message=f"OpenAI TTS request failed with status {status_code}.",
                transient=transient,
            ) from exc
        except urllib_error.URLError as exc:
            raise TTSProviderError(
                code="PROVIDER_TIMEOUT",
                message="OpenAI TTS request timed out or could not reach provider.",
                transient=True,
            ) from exc

        if not body:
            raise TTSProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Provider returned empty audio payload.",
                transient=False,
            )
        if content_type not in {"audio/mpeg", "audio/mp3", ""}:
            raise TTSProviderError(
                code="OUTPUT_SCHEMA_INVALID",
                message="Provider returned unsupported audio content type.",
                transient=False,
            )

        normalized_mime_type = "audio/mpeg"
        response_payload = {
            "mimeType": normalized_mime_type,
            "byteLength": len(body),
            "byteSha256": hashlib.sha256(body).hexdigest(),
        }
        return TTSProviderResult(
            provider_name="openai",
            model_name=self._model_name,
            voice=self._voice,
            speed=self._speed,
            mime_type=normalized_mime_type,
            audio_bytes=body,
            raw_request=json.dumps(request_payload, ensure_ascii=False, separators=(",", ":")),
            raw_response=json.dumps(response_payload, ensure_ascii=False, separators=(",", ":")),
        )


def build_tts_provider(*, provider: str, model: str, voice: str, speed: float) -> TTSProvider:
    provider_name = provider.strip().lower()
    if provider_name in {"", "disabled", "none"}:
        raise TTSProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="TTS provider is not configured.",
            transient=False,
        )

    if provider_name == "fake":
        return FakeTTSProvider(model_name=model, voice=voice, speed=speed)

    if provider_name == "openai":
        api_key = settings.ai_generation_api_key
        if api_key is None:
            raise TTSProviderError(
                code="PROVIDER_NOT_CONFIGURED",
                message="TTS provider API key is missing.",
                transient=False,
            )
        return OpenAITTSProvider(
            api_key=api_key,
            model_name=model,
            voice=voice,
            speed=speed,
            base_url=settings.ai_openai_base_url,
        )

    raise TTSProviderError(
        code="PROVIDER_NOT_SUPPORTED",
        message=f"Unsupported TTS provider: {provider}",
        transient=False,
    )
