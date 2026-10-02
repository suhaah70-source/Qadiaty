"""
Shared model mixins.

TenantScopedMixin is the cornerstone of Multi-Tenancy isolation (SRS §16):
every table that holds tenant-owned data MUST include tenant_id and
every query against it MUST be filtered by the tenant_id resolved from
the authenticated user's membership -- never from a client-supplied
value alone. See app/deps/tenant.py for how tenant_id is resolved.
"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UUIDPKMixin:
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


# NOTE: tenant_id itself is declared explicitly in each tenant-scoped
# model (not via a mixin) because SQLAlchemy declarative mixins with
# ForeignKey columns need care around shared state; explicit is safer
# and matches the "every tenant table has tenant_id" rule in SRS §16/§21.

