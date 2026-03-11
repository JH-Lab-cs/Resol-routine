from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.content_type_taxonomy import normalize_type_tag_alias_or_canonical
from app.core.input_validation import contains_hidden_unicode
from app.models.content_asset import ContentAsset
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import ContentSourcePolicy, ContentTypeTag, Skill
from app.schemas.content_delivery import (
    PublicContentListQuery,
    PublishedContentAssetPayload,
    PublishedContentDetailResponse,
    PublishedContentListItem,
    PublishedContentListResponse,
    PublishedContentQuestionPayload,
)
from app.services.content_asset_service import issue_asset_download_url


def list_published_content_units(
    db: Session,
    *,
    query: PublicContentListQuery,
) -> PublishedContentListResponse:
    stmt = (
        select(ContentUnitRevision, ContentUnit)
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
            ContentUnit.track == query.track,
            ContentUnitRevision.published_at.is_not(None),
        )
        .order_by(
            ContentUnitRevision.published_at.asc(),
            ContentUnitRevision.id.asc(),
        )
    )

    if query.skill is not None:
        stmt = stmt.where(ContentUnit.skill == query.skill)
    if query.changed_since is not None:
        stmt = stmt.where(ContentUnitRevision.published_at > query.changed_since)

    rows = db.execute(stmt).all()
    primary_questions = _load_primary_questions_for_revisions(
        db,
        revision_ids=[revision.id for revision, _unit in rows],
    )
    filtered_rows = [
        (revision, unit)
        for revision, unit in rows
        if query.type_tag is None
        or _extract_type_tag(
            revision=revision,
            question=primary_questions.get(revision.id),
        )
        == query.type_tag
    ]

    total = len(filtered_rows)
    offset = (query.page - 1) * query.page_size
    paged_rows = filtered_rows[offset : offset + query.page_size]

    next_changed_since = (
        max(
            _require_published_at(revision)
            for revision, _unit in filtered_rows
        )
        if filtered_rows
        else query.changed_since
    )

    return PublishedContentListResponse(
        items=[
            build_published_content_list_item(
                revision=revision,
                unit=unit,
                question=primary_questions.get(revision.id),
            )
            for revision, unit in paged_rows
        ],
        page=query.page,
        page_size=query.page_size,
        total=total,
        next_changed_since=next_changed_since,
    )


def get_published_content_unit_detail(
    db: Session,
    *,
    revision_id: UUID,
) -> PublishedContentDetailResponse:
    row = db.execute(
        select(ContentUnitRevision, ContentUnit)
        .join(ContentUnit, ContentUnitRevision.content_unit_id == ContentUnit.id)
        .where(
            ContentUnitRevision.id == revision_id,
            ContentUnit.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnitRevision.lifecycle_status == ContentLifecycleStatus.PUBLISHED,
            ContentUnit.published_revision_id == ContentUnitRevision.id,
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="published_content_not_found",
        )

    revision, unit = row
    questions = db.execute(
        select(ContentQuestion)
        .where(ContentQuestion.content_unit_revision_id == revision.id)
        .order_by(
            ContentQuestion.order_index.asc(),
            ContentQuestion.question_code.asc(),
            ContentQuestion.id.asc(),
        )
    ).scalars().all()
    if len(questions) != 1:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )

    question = questions[0]
    asset_payload = None
    if unit.skill == Skill.LISTENING and revision.asset_id is not None:
        asset = db.get(ContentAsset, revision.asset_id)
        if asset is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="published_content_contract_invalid",
            )
        signed_asset = issue_asset_download_url(db, asset_id=revision.asset_id)
        asset_payload = PublishedContentAssetPayload(
            asset_id=signed_asset.asset_id,
            mime_type=_safe_text(asset.mime_type),
            signed_url=signed_asset.download_url,
            expires_in_seconds=signed_asset.expires_in_seconds,
        )

    tts_plan = _extract_tts_plan(revision)
    if tts_plan is not None:
        _assert_no_hidden_unicode_in_value(tts_plan)

    return PublishedContentDetailResponse(
        unit_id=unit.id,
        revision_id=revision.id,
        track=unit.track,
        skill=unit.skill,
        type_tag=_extract_type_tag(revision=revision, question=question),
        difficulty=_extract_difficulty(revision=revision, question=question),
        published_at=_require_published_at(revision),
        content_source_policy=_extract_source_policy(revision=revision, question=question),
        body_text=_safe_optional_text(revision.body_text),
        transcript_text=_safe_optional_text(revision.transcript_text),
        tts_plan=tts_plan,
        asset=asset_payload,
        question=_build_question_payload(revision=revision, question=question),
    )


def _load_primary_questions_for_revisions(
    db: Session,
    *,
    revision_ids: list[UUID],
) -> dict[UUID, ContentQuestion]:
    if not revision_ids:
        return {}

    rows = (
        db.execute(
            select(ContentQuestion)
            .where(ContentQuestion.content_unit_revision_id.in_(revision_ids))
            .order_by(
                ContentQuestion.content_unit_revision_id.asc(),
                ContentQuestion.order_index.asc(),
                ContentQuestion.question_code.asc(),
                ContentQuestion.id.asc(),
            )
        )
        .scalars()
        .all()
    )

    questions_by_revision_id: dict[UUID, ContentQuestion] = {}
    for question in rows:
        questions_by_revision_id.setdefault(question.content_unit_revision_id, question)
    return questions_by_revision_id


def build_published_content_list_item(
    *,
    revision: ContentUnitRevision,
    unit: ContentUnit,
    question: ContentQuestion | None,
) -> PublishedContentListItem:
    return PublishedContentListItem(
        unit_id=unit.id,
        revision_id=revision.id,
        track=unit.track,
        skill=unit.skill,
        type_tag=_extract_type_tag(revision=revision, question=question),
        difficulty=_extract_difficulty(revision=revision, question=question),
        published_at=_require_published_at(revision),
        has_audio=unit.skill == Skill.LISTENING and revision.asset_id is not None,
    )


def _build_question_payload(
    *,
    revision: ContentUnitRevision,
    question: ContentQuestion,
) -> PublishedContentQuestionPayload:
    metadata = _question_metadata(question)
    return PublishedContentQuestionPayload(
        stem=_safe_text(question.stem),
        options={
            "A": _safe_text(question.choice_a),
            "B": _safe_text(question.choice_b),
            "C": _safe_text(question.choice_c),
            "D": _safe_text(question.choice_d),
            "E": _safe_text(question.choice_e),
        },
        answer_key=_require_answer_key(question.correct_answer),
        explanation=_safe_text(question.explanation or revision.explanation_text or ""),
        evidence_sentence_ids=_extract_string_list(metadata.get("evidenceSentenceIds")),
        why_correct_ko=_safe_text(_coerce_string(metadata.get("whyCorrectKo")) or ""),
        why_wrong_ko_by_option=_extract_string_dict(metadata.get("whyWrongKoByOption")),
        vocab_notes_ko=_safe_optional_text(_coerce_string(metadata.get("vocabNotesKo"))),
        structure_notes_ko=_safe_optional_text(_coerce_string(metadata.get("structureNotesKo"))),
    )


def _require_answer_key(value: str) -> str:
    normalized = _safe_text(value)
    if normalized not in {"A", "B", "C", "D", "E"}:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    return normalized


def _extract_type_tag(
    *,
    revision: ContentUnitRevision,
    question: ContentQuestion | None,
) -> ContentTypeTag:
    raw_value = _coerce_string(_revision_metadata(revision).get("typeTag"))
    if raw_value is None and question is not None:
        raw_value = _coerce_string(_question_metadata(question).get("typeTag"))
    if raw_value is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )

    normalized = normalize_type_tag_alias_or_canonical(type_tag=raw_value)
    try:
        type_tag = ContentTypeTag(normalized)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        ) from exc
    _assert_no_hidden_unicode_in_value(type_tag.value)
    return type_tag


def _extract_difficulty(
    *,
    revision: ContentUnitRevision,
    question: ContentQuestion | None,
) -> int:
    raw_value = _revision_metadata(revision).get("difficulty")
    if raw_value is None and question is not None:
        raw_value = _question_metadata(question).get("difficulty")
    if raw_value is None or isinstance(raw_value, bool):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    try:
        difficulty = int(raw_value)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        ) from exc
    if difficulty < 1 or difficulty > 5:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    return difficulty


def _extract_source_policy(
    *,
    revision: ContentUnitRevision,
    question: ContentQuestion | None,
) -> ContentSourcePolicy:
    raw_value = _coerce_string(_revision_metadata(revision).get("sourcePolicy"))
    if raw_value is None and question is not None:
        raw_value = _coerce_string(_question_metadata(question).get("sourcePolicy"))
    if raw_value is None:
        return ContentSourcePolicy.AI_ORIGINAL
    _assert_no_hidden_unicode_in_value(raw_value)
    try:
        return ContentSourcePolicy(raw_value)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        ) from exc


def _extract_tts_plan(revision: ContentUnitRevision) -> dict[str, Any] | None:
    raw_value = _revision_metadata(revision).get("ttsPlan")
    if raw_value is None:
        return None
    if not isinstance(raw_value, dict):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    return raw_value


def _extract_string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    items: list[str] = []
    for raw_item in value:
        item = _coerce_string(raw_item)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="published_content_contract_invalid",
            )
        items.append(_safe_text(item))
    return items


def _extract_string_dict(value: Any) -> dict[str, str]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    items: dict[str, str] = {}
    for key, raw_item in value.items():
        normalized_key = _coerce_string(key)
        normalized_value = _coerce_string(raw_item)
        if normalized_key is None or normalized_value is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="published_content_contract_invalid",
            )
        items[_safe_text(normalized_key)] = _safe_text(normalized_value)
    return items


def _safe_text(value: str) -> str:
    _assert_no_hidden_unicode_in_value(value)
    return value


def _safe_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    return _safe_text(value)


def _assert_no_hidden_unicode_in_value(value: Any) -> None:
    if isinstance(value, str):
        if _contains_disallowed_hidden_unicode(value):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="published_content_contract_invalid",
            )
        return
    if isinstance(value, list):
        for item in value:
            _assert_no_hidden_unicode_in_value(item)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _assert_no_hidden_unicode_in_value(key)
            _assert_no_hidden_unicode_in_value(item)


def _coerce_string(value: Any) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        return None
    return value


def _contains_disallowed_hidden_unicode(value: str) -> bool:
    # Canonical content payloads may legitimately contain line breaks and tabs.
    sanitized = value.replace("\n", "").replace("\r", "").replace("\t", "")
    return contains_hidden_unicode(sanitized)


def _revision_metadata(revision: ContentUnitRevision) -> dict[str, Any]:
    return revision.metadata_json


def _question_metadata(question: ContentQuestion) -> dict[str, Any]:
    return question.metadata_json


def _require_published_at(revision: ContentUnitRevision) -> datetime:
    if revision.published_at is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="published_content_contract_invalid",
        )
    if revision.published_at.tzinfo is None or revision.published_at.utcoffset() is None:
        return revision.published_at.replace(tzinfo=UTC)
    return revision.published_at.astimezone(UTC)
