from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


def append_audit_log(
    db: Session,
    *,
    action: str,
    actor_user_id: UUID | None,
    target_user_id: UUID | None,
    details: dict[str, Any] | None = None,
) -> None:
    payload = details or {}
    db.add(
        AuditLog(
            actor_user_id=actor_user_id,
            target_user_id=target_user_id,
            action=action,
            details=payload,
        )
    )
