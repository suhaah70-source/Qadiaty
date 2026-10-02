import uuid
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.system import AuditLog


async def log_action(
    db: AsyncSession,
    *,
    action: str,
    entity_type: str,
    entity_id: Optional[str] = None,
    user_id: Optional[uuid.UUID] = None,
    tenant_id: Optional[uuid.UUID] = None,
    metadata: Optional[dict] = None,
) -> None:
    entry = AuditLog(
        tenant_id=tenant_id,
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id) if entity_id else None,
        metadata_json=metadata or {},
    )
    db.add(entry)
    # caller controls the commit boundary (usually part of the same
    # transaction as the business change being audited)
