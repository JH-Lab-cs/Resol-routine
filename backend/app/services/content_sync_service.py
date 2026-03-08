from __future__ import annotations

import base64
import json
from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_sync_enums import ContentSyncEventReason, ContentSyncEventType
from app.models.content_sync_event import ContentSyncEvent
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Track
from app.schemas.content_sync import (
    PublicContentSyncCursorPayload,
    PublicContentSyncDeleteItem,
    PublicContentSyncQuery,
    PublicContentSyncResponse,
    PublicContentSyncUpsertItem,
)
from app.services.content_delivery_service import (
    _load_primary_questions_for_revisions,
    build_published_content_list_item,
)


def append_content_upsert_event(
    db: Session,
    *,
    unit: ContentUnit,
    revision: ContentUnitRevision,
    published_at: datetime,
    reason: ContentSyncEventReason = ContentSyncEventReason.PUBLISHED,
) -> ContentSyncEvent:
    return _append_content_sync_event(
        db,
        track=unit.track,
        unit_id=unit.id,
        revision_id=revision.id,
        event_type=ContentSyncEventType.UPSERT,
        reason=reason,
        cursor_published_at=published_at,
        cursor_revision_id=revision.id,
    )


def append_content_delete_event(
    db: Session,
    *,
    unit: ContentUnit,
    revision_id: UUID,
    changed_at: datetime,
    reason: ContentSyncEventReason,
) -> ContentSyncEvent:
    return _append_content_sync_event(
        db,
        track=unit.track,
        unit_id=unit.id,
        revision_id=revision_id,
        event_type=ContentSyncEventType.DELETE,
        reason=reason,
        cursor_published_at=changed_at,
        cursor_revision_id=revision_id,
    )


def list_public_content_sync(
    db: Session,
    *,
    query: PublicContentSyncQuery,
) -> PublicContentSyncResponse:
    cursor = _decode_sync_cursor(query.cursor)

    ranked_events = (
        select(
            ContentSyncEvent.id.label("id"),
            ContentSyncEvent.track.label("track"),
            ContentSyncEvent.unit_id.label("unit_id"),
            ContentSyncEvent.revision_id.label("revision_id"),
            ContentSyncEvent.event_type.label("event_type"),
            ContentSyncEvent.reason.label("reason"),
            ContentSyncEvent.cursor_published_at.label("cursor_published_at"),
            ContentSyncEvent.cursor_revision_id.label("cursor_revision_id"),
            func.row_number()
            .over(
                partition_by=ContentSyncEvent.revision_id,
                order_by=(
                    ContentSyncEvent.cursor_published_at.desc(),
                    ContentSyncEvent.cursor_revision_id.desc(),
                ),
            )
            .label("row_number"),
        )
        .where(ContentSyncEvent.track == query.track)
    )

    if cursor is not None:
        ranked_events = ranked_events.where(
            or_(
                ContentSyncEvent.cursor_published_at > cursor.published_at,
                and_(
                    ContentSyncEvent.cursor_published_at == cursor.published_at,
                    ContentSyncEvent.cursor_revision_id > cursor.revision_id,
                ),
            )
        )

    ranked_subquery = ranked_events.subquery()
    rows = db.execute(
        select(ranked_subquery)
        .where(ranked_subquery.c.row_number == 1)
        .order_by(
            ranked_subquery.c.cursor_published_at.asc(),
            ranked_subquery.c.cursor_revision_id.asc(),
        )
        .limit(query.page_size + 1)
    ).mappings().all()

    has_more = len(rows) > query.page_size
    page_rows = rows[: query.page_size]

    upsert_revision_ids = [
        row["revision_id"]
        for row in page_rows
        if row["event_type"] == ContentSyncEventType.UPSERT
    ]
    upsert_rows = _load_upsert_rows(
        db,
        revision_ids=upsert_revision_ids,
    )
    primary_questions = _load_primary_questions_for_revisions(
        db,
        revision_ids=upsert_revision_ids,
    )

    upserts: list[PublicContentSyncUpsertItem] = []
    deletes: list[PublicContentSyncDeleteItem] = []
    for row in page_rows:
        if row["event_type"] == ContentSyncEventType.UPSERT:
            revision_unit = upsert_rows.get(row["revision_id"])
            if revision_unit is None:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="content_sync_contract_invalid",
                )
            revision, unit = revision_unit
            summary = build_published_content_list_item(
                revision=revision,
                unit=unit,
                question=primary_questions.get(revision.id),
            )
            upserts.append(
                PublicContentSyncUpsertItem(
                    unit_id=summary.unit_id,
                    revision_id=summary.revision_id,
                    track=summary.track,
                    skill=summary.skill,
                    type_tag=summary.type_tag,
                    difficulty=summary.difficulty,
                    published_at=summary.published_at,
                    has_audio=summary.has_audio,
                )
            )
        else:
            deletes.append(
                PublicContentSyncDeleteItem(
                    unit_id=row["unit_id"],
                    revision_id=row["revision_id"],
                    reason=row["reason"],
                    changed_at=_normalize_cursor_datetime(row["cursor_published_at"]),
                )
            )

    next_cursor = (
        _encode_sync_cursor(
            published_at=_normalize_cursor_datetime(page_rows[-1]["cursor_published_at"]),
            revision_id=page_rows[-1]["cursor_revision_id"],
        )
        if page_rows
        else None
    )

    return PublicContentSyncResponse(
        upserts=upserts,
        deletes=deletes,
        next_cursor=next_cursor,
        has_more=has_more,
    )


def _load_upsert_rows(
    db: Session,
    *,
    revision_ids: list[UUID],
) -> dict[UUID, tuple[ContentUnitRevision, ContentUnit]]:
    if not revision_ids:
        return {}
    rows = db.execute(
        select(ContentUnitRevision, ContentUnit)
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnitRevision.id.in_(revision_ids),
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
            ContentUnitRevision.published_at.is_not(None),
        )
    ).all()
    return {revision.id: (revision, unit) for revision, unit in rows}


def _append_content_sync_event(
    db: Session,
    *,
    track: Track,
    unit_id: UUID,
    revision_id: UUID,
    event_type: ContentSyncEventType,
    reason: ContentSyncEventReason,
    cursor_published_at: datetime,
    cursor_revision_id: UUID,
) -> ContentSyncEvent:
    event = ContentSyncEvent(
        track=track,
        unit_id=unit_id,
        revision_id=revision_id,
        event_type=event_type,
        reason=reason,
        cursor_published_at=_normalize_cursor_datetime(cursor_published_at),
        cursor_revision_id=cursor_revision_id,
    )
    db.add(event)
    db.flush()
    return event


def _encode_sync_cursor(*, published_at: datetime, revision_id: UUID) -> str:
    payload = PublicContentSyncCursorPayload(
        publishedAt=published_at,
        revisionId=revision_id,
    )
    raw = json.dumps(
        payload.model_dump(mode="json", by_alias=True),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _decode_sync_cursor(cursor: str | None) -> PublicContentSyncCursorPayload | None:
    if cursor is None:
        return None
    try:
        padding = "=" * (-len(cursor) % 4)
        decoded = base64.urlsafe_b64decode(f"{cursor}{padding}".encode("ascii"))
        payload = json.loads(decoded.decode("utf-8"))
        return PublicContentSyncCursorPayload.model_validate(payload)
    except (ValueError, TypeError, json.JSONDecodeError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="INVALID_SYNC_CURSOR",
        ) from None


def _normalize_cursor_datetime(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
