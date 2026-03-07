from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_internal_api_key
from app.models.content_enums import ContentLifecycleStatus
from app.schemas.content import (
    AssetDownloadUrlResponse,
    AssetFinalizeRequest,
    AssetUploadUrlRequest,
    AssetUploadUrlResponse,
    ContentAssetResponse,
    ContentQuestionListQuery,
    ContentQuestionListResponse,
    ContentRevisionArchiveRequest,
    ContentRevisionArchiveResponse,
    ContentRevisionDetailResponse,
    ContentRevisionListQuery,
    ContentRevisionListResponse,
    ContentRevisionReviewRequest,
    ContentRevisionValidateRequest,
    ContentUnitArchiveResponse,
    ContentUnitCreateRequest,
    ContentUnitListQuery,
    ContentUnitListResponse,
    ContentUnitPublishRequest,
    ContentUnitPublishResponse,
    ContentUnitResponse,
    ContentUnitRevisionCreateRequest,
    ContentUnitRevisionListResponse,
    ContentUnitRevisionResponse,
    ContentUnitRollbackRequest,
    ContentUnitRollbackResponse,
)
from app.services.content_asset_service import (
    finalize_asset,
    issue_asset_download_url,
    issue_asset_upload_url,
)
from app.services.content_ingest_service import create_content_unit, create_content_unit_revision
from app.services.content_publish_service import (
    archive_content_revision,
    archive_content_unit,
    publish_content_unit_revision,
    review_content_unit_revision,
    rollback_content_unit_revision,
    validate_content_unit_revision,
)
from app.services.content_query_service import (
    get_content_revision,
    get_content_unit,
    list_content_questions,
    list_content_revisions,
    list_content_unit_revisions,
    list_content_units,
)

router = APIRouter(
    prefix="/internal/content",
    tags=["content-internal"],
    dependencies=[Depends(require_internal_api_key)],
)


def _build_unit_list_query(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    published_only: bool = False,
    skill: str | None = None,
    track: str | None = None,
    lifecycle_status: str | None = None,
    external_id: str | None = None,
    slug: str | None = None,
) -> ContentUnitListQuery:
    try:
        return ContentUnitListQuery(
            page=page,
            page_size=page_size,
            published_only=published_only,
            skill=skill,
            track=track,
            lifecycle_status=lifecycle_status,
            external_id=external_id,
            slug=slug,
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=_validation_error_detail(exc),
        ) from exc


def _build_question_list_query(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    published_only: bool = False,
    skill: str | None = None,
    track: str | None = None,
    lifecycle_status: str | None = None,
    unit_id: UUID | None = None,
    revision_id: UUID | None = None,
    question_code: str | None = None,
    unit_external_id: str | None = None,
) -> ContentQuestionListQuery:
    try:
        return ContentQuestionListQuery(
            page=page,
            page_size=page_size,
            published_only=published_only,
            skill=skill,
            track=track,
            lifecycle_status=lifecycle_status,
            unit_id=unit_id,
            revision_id=revision_id,
            question_code=question_code,
            unit_external_id=unit_external_id,
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=_validation_error_detail(exc),
        ) from exc


def _build_revision_list_query(
    status_value: str = Query(default=ContentLifecycleStatus.DRAFT.value, alias="status"),
    track: str | None = Query(default=None, alias="track"),
    skill: str | None = Query(default=None, alias="skill"),
    type_tag: str | None = Query(default=None, alias="typeTag"),
    page: int = Query(default=1, ge=1, alias="page"),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
    created_after: str | None = Query(default=None, alias="createdAfter"),
    created_before: str | None = Query(default=None, alias="createdBefore"),
) -> ContentRevisionListQuery:
    try:
        return ContentRevisionListQuery(
            status=status_value,
            track=track,
            skill=skill,
            type_tag=type_tag,
            page=page,
            page_size=page_size,
            created_after=created_after,
            created_before=created_before,
        )
    except ValidationError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="INVALID_FILTER_VALUE",
        ) from None


def _validation_error_detail(exc: ValidationError) -> list[dict[str, object]]:
    return exc.errors(
        include_context=False,
        include_url=False,
    )


@router.post(
    "/assets/upload-url",
    response_model=AssetUploadUrlResponse,
)
def create_asset_upload_url(
    payload: AssetUploadUrlRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AssetUploadUrlResponse:
    return issue_asset_upload_url(db, payload=payload)


@router.post(
    "/assets/finalize",
    response_model=ContentAssetResponse,
    status_code=status.HTTP_201_CREATED,
)
def finalize_content_asset(
    payload: AssetFinalizeRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentAssetResponse:
    return finalize_asset(db, payload=payload)


@router.get(
    "/revisions",
    response_model=ContentRevisionListResponse,
)
def get_revisions(
    query: Annotated[ContentRevisionListQuery, Depends(_build_revision_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> ContentRevisionListResponse:
    return list_content_revisions(db, query=query)


@router.get(
    "/revisions/{revision_id}",
    response_model=ContentRevisionDetailResponse,
)
def get_revision(
    revision_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> ContentRevisionDetailResponse:
    return get_content_revision(db, revision_id=revision_id)


@router.post(
    "/revisions/{revision_id}/archive",
    response_model=ContentRevisionArchiveResponse,
)
def archive_revision(
    revision_id: UUID,
    payload: ContentRevisionArchiveRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentRevisionArchiveResponse:
    return archive_content_revision(
        db,
        revision_id=revision_id,
        reason=payload.reason,
    )


@router.get(
    "/assets/{asset_id}/download-url",
    response_model=AssetDownloadUrlResponse,
)
def create_asset_download_url(
    asset_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> AssetDownloadUrlResponse:
    result = issue_asset_download_url(db, asset_id=asset_id)
    return AssetDownloadUrlResponse(
        asset_id=result.asset_id,
        object_key=result.object_key,
        download_url=result.download_url,
        expires_in_seconds=result.expires_in_seconds,
        expires_at=result.expires_at,
    )


@router.post(
    "/units",
    response_model=ContentUnitResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_unit(
    payload: ContentUnitCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitResponse:
    return create_content_unit(db, payload=payload)


@router.post(
    "/units/{unit_id}/revisions",
    response_model=ContentUnitRevisionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_unit_revision(
    unit_id: UUID,
    payload: ContentUnitRevisionCreateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitRevisionResponse:
    return create_content_unit_revision(db, unit_id=unit_id, payload=payload)


@router.post(
    "/units/{unit_id}/revisions/{revision_id}/validate",
    response_model=ContentUnitRevisionResponse,
)
def validate_unit_revision(
    unit_id: UUID,
    revision_id: UUID,
    payload: ContentRevisionValidateRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitRevisionResponse:
    return validate_content_unit_revision(
        db,
        unit_id=unit_id,
        revision_id=revision_id,
        payload=payload,
    )


@router.post(
    "/units/{unit_id}/revisions/{revision_id}/review",
    response_model=ContentUnitRevisionResponse,
)
def review_unit_revision(
    unit_id: UUID,
    revision_id: UUID,
    payload: ContentRevisionReviewRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitRevisionResponse:
    return review_content_unit_revision(
        db,
        unit_id=unit_id,
        revision_id=revision_id,
        payload=payload,
    )


@router.post(
    "/units/{unit_id}/publish",
    response_model=ContentUnitPublishResponse,
)
def publish_unit_revision(
    unit_id: UUID,
    payload: ContentUnitPublishRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitPublishResponse:
    return publish_content_unit_revision(db, unit_id=unit_id, payload=payload)


@router.post(
    "/units/{unit_id}/archive",
    response_model=ContentUnitArchiveResponse,
)
def archive_unit(
    unit_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitArchiveResponse:
    return archive_content_unit(db, unit_id=unit_id)


@router.post(
    "/units/{unit_id}/rollback",
    response_model=ContentUnitRollbackResponse,
)
def rollback_unit(
    unit_id: UUID,
    payload: ContentUnitRollbackRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitRollbackResponse:
    return rollback_content_unit_revision(
        db,
        unit_id=unit_id,
        payload=payload,
    )


@router.get(
    "/units",
    response_model=ContentUnitListResponse,
)
def get_units(
    query: Annotated[ContentUnitListQuery, Depends(_build_unit_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitListResponse:
    return list_content_units(db, query=query)


@router.get(
    "/units/{unit_id}",
    response_model=ContentUnitResponse,
)
def get_unit(
    unit_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitResponse:
    return get_content_unit(db, unit_id=unit_id)


@router.get(
    "/units/{unit_id}/revisions",
    response_model=ContentUnitRevisionListResponse,
)
def get_unit_revisions(
    unit_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> ContentUnitRevisionListResponse:
    return list_content_unit_revisions(db, unit_id=unit_id)


@router.get(
    "/questions",
    response_model=ContentQuestionListResponse,
)
def get_questions(
    query: Annotated[ContentQuestionListQuery, Depends(_build_question_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> ContentQuestionListResponse:
    return list_content_questions(db, query=query)
