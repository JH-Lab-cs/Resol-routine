from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.dependencies import get_db
from app.schemas.content_delivery import (
    PublicContentListQuery,
    PublishedContentDetailResponse,
    PublishedContentListResponse,
)
from app.services.content_delivery_service import (
    get_published_content_unit_detail,
    list_published_content_units,
)

router = APIRouter(
    prefix="/public/content",
    tags=["content-public"],
)


def _build_public_content_list_query(
    track: str = Query(..., alias="track"),
    skill: str | None = Query(default=None, alias="skill"),
    type_tag: str | None = Query(default=None, alias="typeTag"),
    changed_since: str | None = Query(default=None, alias="changedSince"),
    page: int = Query(default=1, ge=1, alias="page"),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> PublicContentListQuery:
    try:
        return PublicContentListQuery.model_validate(
            {
                "track": track,
                "skill": skill,
                "typeTag": type_tag,
                "changedSince": changed_since,
                "page": page,
                "pageSize": page_size,
            }
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=exc.errors(
                include_context=False,
                include_url=False,
            ),
        ) from exc


@router.get(
    "/units",
    response_model=PublishedContentListResponse,
)
def get_published_content_units(
    query: Annotated[PublicContentListQuery, Depends(_build_public_content_list_query)],
    db: Annotated[Session, Depends(get_db)],
) -> PublishedContentListResponse:
    return list_published_content_units(db, query=query)


@router.get(
    "/units/{revision_id}",
    response_model=PublishedContentDetailResponse,
)
def get_published_content_unit(
    revision_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> PublishedContentDetailResponse:
    return get_published_content_unit_detail(db, revision_id=revision_id)
