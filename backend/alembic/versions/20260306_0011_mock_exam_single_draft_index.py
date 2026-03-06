"""Enforce single draft revision per mock exam

Revision ID: 20260306_0011
Revises: 20260305_0010
Create Date: 2026-03-06 15:55:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260306_0011"
down_revision: str | None = "20260305_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _chunked(values: list[str], size: int) -> list[list[str]]:
    return [values[index : index + size] for index in range(0, len(values), size)]


def _archive_duplicate_drafts() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        draft_rows = bind.execute(
            sa.text(
                """
                SELECT id::text AS id, mock_exam_id::text AS mock_exam_id
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
                SELECT id, mock_exam_id
                FROM mock_exam_revisions
                WHERE lifecycle_status = 'DRAFT'
                ORDER BY mock_exam_id ASC, revision_no DESC, id DESC
                """
            )
        ).all()

    seen_exam_ids: set[str] = set()
    archive_ids: list[str] = []
    for row in draft_rows:
        exam_id = str(row.mock_exam_id)
        if exam_id in seen_exam_ids:
            archive_ids.append(str(row.id))
            continue
        seen_exam_ids.add(exam_id)

    if not archive_ids:
        return

    for batch in _chunked(archive_ids, 500):
        for revision_id in batch:
            if bind.dialect.name == "postgresql":
                op.execute(
                    sa.text(
                        """
                        UPDATE mock_exam_revisions
                        SET lifecycle_status = 'ARCHIVED'::content_lifecycle_status
                        WHERE id = CAST(:revision_id AS uuid)
                        """
                    ).bindparams(revision_id=revision_id)
                )
            else:
                op.execute(
                    sa.text(
                        """
                        UPDATE mock_exam_revisions
                        SET lifecycle_status = 'ARCHIVED'
                        WHERE id = :revision_id
                        """
                    ).bindparams(revision_id=revision_id)
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
