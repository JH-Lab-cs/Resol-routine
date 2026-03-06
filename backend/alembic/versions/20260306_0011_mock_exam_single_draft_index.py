"""Enforce single draft revision per mock exam

Revision ID: 20260306_0011
Revises: 20260305_0010
Create Date: 2026-03-06 15:55:00.000000
"""

import json
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260306_0011"
down_revision: str | None = "20260305_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ARCHIVED_BY_MOCK_ASSEMBLY_SERVICE = "mock_assembly_service"
ARCHIVED_REASON_DEDUP_SINGLE_DRAFT_MIGRATION = "DEDUP_SINGLE_DRAFT_MIGRATION"


def _chunked(values: list[tuple[str, str]], size: int) -> list[list[tuple[str, str]]]:
    return [values[index : index + size] for index in range(0, len(values), size)]


def _utc_iso8601_utc(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _merge_archive_audit_metadata(
    *,
    metadata_json: object,
    archived_at_utc: str,
) -> dict[str, object]:
    parsed: dict[str, object]
    if isinstance(metadata_json, dict):
        parsed = dict(metadata_json)
    elif isinstance(metadata_json, str):
        try:
            loaded_value = json.loads(metadata_json)
        except json.JSONDecodeError:
            loaded_value = {}
        parsed = dict(loaded_value) if isinstance(loaded_value, dict) else {}
    else:
        parsed = {}

    parsed["archivedAtUtc"] = archived_at_utc
    parsed["archivedBy"] = ARCHIVED_BY_MOCK_ASSEMBLY_SERVICE
    parsed["archivedReason"] = ARCHIVED_REASON_DEDUP_SINGLE_DRAFT_MIGRATION
    return parsed


def _archive_duplicate_drafts() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        draft_rows = bind.execute(
            sa.text(
                """
                SELECT id::text AS id, mock_exam_id::text AS mock_exam_id, metadata_json
                FROM mock_exam_revisions
                WHERE lifecycle_status = 'DRAFT'::content_lifecycle_status
                ORDER BY mock_exam_id ASC, revision_no DESC, id DESC
                """
            )
        ).all()
    else:
        draft_rows = bind.execute(
            sa.text(
                """
                SELECT id, mock_exam_id, metadata_json
                FROM mock_exam_revisions
                WHERE lifecycle_status = 'DRAFT'
                ORDER BY mock_exam_id ASC, revision_no DESC, id DESC
                """
            )
        ).all()

    seen_exam_ids: set[str] = set()
    archive_entries: list[tuple[str, str]] = []
    archived_at_utc = _utc_iso8601_utc(datetime.now(UTC))
    for row in draft_rows:
        exam_id = str(row.mock_exam_id)
        if exam_id in seen_exam_ids:
            merged_metadata = _merge_archive_audit_metadata(
                metadata_json=row.metadata_json,
                archived_at_utc=archived_at_utc,
            )
            archive_entries.append(
                (
                    str(row.id),
                    json.dumps(merged_metadata, separators=(",", ":"), ensure_ascii=True),
                )
            )
            continue
        seen_exam_ids.add(exam_id)

    if not archive_entries:
        return

    for batch in _chunked(archive_entries, 500):
        for revision_id, metadata_json in batch:
            if bind.dialect.name == "postgresql":
                op.execute(
                    sa.text(
                        """
                        UPDATE mock_exam_revisions
                        SET lifecycle_status = 'ARCHIVED'::content_lifecycle_status,
                            metadata_json = CAST(:metadata_json AS jsonb)
                        WHERE id = CAST(:revision_id AS uuid)
                        """
                    ).bindparams(revision_id=revision_id, metadata_json=metadata_json)
                )
            else:
                op.execute(
                    sa.text(
                        """
                        UPDATE mock_exam_revisions
                        SET lifecycle_status = 'ARCHIVED',
                            metadata_json = :metadata_json
                        WHERE id = :revision_id
                        """
                    ).bindparams(revision_id=revision_id, metadata_json=metadata_json)
                )


def upgrade() -> None:
    _archive_duplicate_drafts()
    draft_where = sa.text("lifecycle_status = 'DRAFT'")
    op.create_index(
        "uq_mock_exam_revisions_single_draft_per_exam",
        "mock_exam_revisions",
        ["mock_exam_id"],
        unique=True,
        postgresql_where=draft_where,
        sqlite_where=draft_where,
    )


def downgrade() -> None:
    op.drop_index("uq_mock_exam_revisions_single_draft_per_exam", table_name="mock_exam_revisions")
