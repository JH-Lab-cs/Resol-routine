from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import normalize_type_tag_alias_or_canonical
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import ContentTypeTag, Skill, Track
from app.schemas.content import (
    ContentRevisionReviewRequest,
    ContentRevisionValidateRequest,
    ContentUnitPublishRequest,
)
from app.services.content_publish_service import (
    publish_content_unit_revision,
    review_content_unit_revision,
    validate_content_unit_revision,
)


@dataclass(frozen=True, slots=True)
class ReviewerBatchFilter:
    track: Track | None = None
    skill: Skill | None = None
    type_tag: str | None = None
    difficulty_min: int | None = None
    difficulty_max: int | None = None
    limit: int | None = None


@dataclass(frozen=True, slots=True)
class RevisionBatchTarget:
    revision_id: UUID
    unit_id: UUID
    track: Track
    skill: Skill
    type_tag: str | None
    difficulty: int | None
    can_publish: bool
    created_at: Any


def batch_validate_content_revisions(
    db: Session,
    *,
    filters: ReviewerBatchFilter,
    validator_version: str,
) -> dict[str, object]:
    targets = _select_revision_batch_targets(db, filters=filters, publish_mode=False)
    return _run_batch_action(
        action="validate",
        targets=targets,
        callback=lambda target: validate_content_unit_revision(
            db,
            unit_id=target.unit_id,
            revision_id=target.revision_id,
            payload=ContentRevisionValidateRequest(validator_version=validator_version),
        ),
    )


def batch_review_content_revisions(
    db: Session,
    *,
    filters: ReviewerBatchFilter,
    reviewer_identity: str,
) -> dict[str, object]:
    targets = _select_revision_batch_targets(db, filters=filters, publish_mode=False)
    return _run_batch_action(
        action="review",
        targets=targets,
        callback=lambda target: review_content_unit_revision(
            db,
            unit_id=target.unit_id,
            revision_id=target.revision_id,
            payload=ContentRevisionReviewRequest(reviewer_identity=reviewer_identity),
        ),
    )


def batch_publish_content_revisions(
    db: Session,
    *,
    filters: ReviewerBatchFilter,
    confirm: bool,
) -> dict[str, object]:
    if not confirm:
        raise ValueError("batch_publish_requires_confirm")

    targets = _select_revision_batch_targets(db, filters=filters, publish_mode=True)
    return _run_batch_action(
        action="publish",
        targets=targets,
        callback=lambda target: publish_content_unit_revision(
            db,
            unit_id=target.unit_id,
            payload=ContentUnitPublishRequest(revision_id=target.revision_id),
        ),
    )


def _select_revision_batch_targets(
    db: Session,
    *,
    filters: ReviewerBatchFilter,
    publish_mode: bool,
) -> list[RevisionBatchTarget]:
    rows = db.execute(
        select(ContentUnitRevision, ContentUnit)
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.DRAFT,
            ContentUnit.lifecycle_status != ContentLifecycleStatus.ARCHIVED,
        )
        .order_by(ContentUnitRevision.created_at.desc(), ContentUnitRevision.id.desc())
    ).all()

    targets: list[RevisionBatchTarget] = []
    seen_unit_ids: set[UUID] = set()
    for revision, unit in rows:
        type_tag = _extract_revision_type_tag(revision)
        difficulty = _extract_revision_difficulty(revision)
        target = RevisionBatchTarget(
            revision_id=revision.id,
            unit_id=unit.id,
            track=unit.track,
            skill=unit.skill,
            type_tag=type_tag,
            difficulty=difficulty,
            can_publish=_can_publish(revision),
            created_at=revision.created_at,
        )
        if not _matches_filters(target=target, filters=filters):
            continue
        if publish_mode:
            if not target.can_publish:
                continue
            if target.unit_id in seen_unit_ids:
                continue
            seen_unit_ids.add(target.unit_id)
        targets.append(target)
        if filters.limit is not None and len(targets) >= filters.limit:
            break

    return list(reversed(targets))


def _run_batch_action(
    *,
    action: str,
    targets: list[RevisionBatchTarget],
    callback,
) -> dict[str, object]:
    processed: list[dict[str, object]] = []
    failed: list[dict[str, object]] = []
    for target in targets:
        try:
            response = callback(target)
            processed.append(
                {
                    "revisionId": str(target.revision_id),
                    "unitId": str(target.unit_id),
                    "track": target.track.value,
                    "skill": target.skill.value,
                    "typeTag": target.type_tag,
                    "difficulty": target.difficulty,
                    "result": (
                        response.model_dump(mode="json")
                        if hasattr(response, "model_dump")
                        else str(response)
                    ),
                }
            )
        except HTTPException as exc:
            failed.append(
                {
                    "revisionId": str(target.revision_id),
                    "unitId": str(target.unit_id),
                    "statusCode": exc.status_code,
                    "detail": exc.detail,
                }
            )

    return {
        "action": action,
        "matchedCount": len(targets),
        "processedCount": len(processed),
        "failedCount": len(failed),
        "items": processed,
        "failedItems": failed,
    }


def _matches_filters(*, target: RevisionBatchTarget, filters: ReviewerBatchFilter) -> bool:
    if filters.track is not None and target.track != filters.track:
        return False
    if filters.skill is not None and target.skill != filters.skill:
        return False
    if filters.type_tag is not None and target.type_tag != filters.type_tag:
        return False
    if filters.difficulty_min is not None:
        if target.difficulty is None or target.difficulty < filters.difficulty_min:
            return False
    if filters.difficulty_max is not None:
        if target.difficulty is None or target.difficulty > filters.difficulty_max:
            return False
    return True


def _extract_revision_type_tag(revision: ContentUnitRevision) -> str | None:
    metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    raw_type_tag = metadata.get("typeTag")
    if not isinstance(raw_type_tag, str) or not raw_type_tag.strip():
        return None

    normalized = normalize_type_tag_alias_or_canonical(type_tag=raw_type_tag)
    try:
        return ContentTypeTag(normalized).value
    except ValueError:
        return None


def _extract_revision_difficulty(revision: ContentUnitRevision) -> int | None:
    metadata = revision.metadata_json if isinstance(revision.metadata_json, dict) else {}
    raw_difficulty = metadata.get("difficulty")
    if isinstance(raw_difficulty, bool) or raw_difficulty is None:
        return None

    try:
        difficulty = int(raw_difficulty)
    except (TypeError, ValueError):
        return None

    if difficulty < 1 or difficulty > 5:
        return None
    return difficulty


def _can_publish(revision: ContentUnitRevision) -> bool:
    return (
        revision.lifecycle_status == ContentLifecycleStatus.DRAFT
        and revision.validated_at is not None
        and revision.validator_version is not None
        and revision.reviewed_at is not None
        and revision.reviewer_identity is not None
    )
