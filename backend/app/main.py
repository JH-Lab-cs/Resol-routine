from fastapi import FastAPI

from app.api.error_handlers import register_error_handlers
from app.api.router import api_router
from app.core.config import settings
from app.core.logging import configure_logging

configure_logging()


def create_application() -> FastAPI:
    application = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )
    register_error_handlers(application)
    application.include_router(api_router, prefix=settings.api_prefix)
    return application


app = create_application()
