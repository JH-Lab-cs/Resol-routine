from fastapi import APIRouter

from app.api.ai_internal import router as ai_internal_router
from app.api.auth import router as auth_router
from app.api.billing import router as billing_router
from app.api.billing_webhooks import router as billing_webhooks_router
from app.api.content_internal import router as content_internal_router
from app.api.family import router as family_router
from app.api.health import router as health_router
from app.api.mock_exam_internal import router as mock_exam_internal_router
from app.api.mock_exams import router as mock_exams_router
from app.api.reports import router as reports_router
from app.api.subscriptions import router as subscriptions_router
from app.api.subscriptions_internal import router as subscriptions_internal_router
from app.api.sync import router as sync_router

api_router = APIRouter()
api_router.include_router(ai_internal_router)
api_router.include_router(auth_router)
api_router.include_router(billing_router)
api_router.include_router(billing_webhooks_router)
api_router.include_router(content_internal_router)
api_router.include_router(family_router)
api_router.include_router(health_router)
api_router.include_router(mock_exam_internal_router)
api_router.include_router(mock_exams_router)
api_router.include_router(reports_router)
api_router.include_router(subscriptions_router)
api_router.include_router(subscriptions_internal_router)
api_router.include_router(sync_router)
