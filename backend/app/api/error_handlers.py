from __future__ import annotations

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


def _extract_error_code(detail: object) -> str:
    if isinstance(detail, dict):
        code = detail.get("code")
        if isinstance(code, str):
            return code
    if isinstance(detail, str):
        return detail
    return "http_error"


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(HTTPException)
    async def handle_http_exception(_: Request, exc: HTTPException) -> JSONResponse:
        detail = exc.detail
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "detail": detail,
                "errorCode": _extract_error_code(detail),
            },
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_exception(_: Request, exc: RequestValidationError) -> JSONResponse:
        detail = jsonable_encoder(exc.errors())
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content={
                "detail": detail,
                "errorCode": "validation_error",
            },
        )
