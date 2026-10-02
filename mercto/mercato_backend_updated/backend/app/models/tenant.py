import enum
import uuid

from sqlalchemy import Enum, Float, ForeignKey, Integer, JSON, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.base import TimestampMixin, UUIDPKMixin


class TenantStatus(str, enum.Enum):
    PENDING = "PENDING"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    CLOSED = "CLOSED"


class Tenant(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "tenants"

    code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(200))
    status: Mapped[TenantStatus] = mapped_column(
        Enum(TenantStatus, name="tenant_status"), default=TenantStatus.PENDING, nullable=False
    )
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    members: Mapped[list["TenantMember"]] = relationship(back_populates="tenant", cascade="all, delete-orphan")
    contracts: Mapped[list["Contract"]] = relationship(back_populates="tenant", cascade="all, delete-orphan")
    theme: Mapped["Theme"] = relationship(back_populates="tenant", uselist=False, cascade="all, delete-orphan")


class UserStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    DISABLED = "DISABLED"


class User(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(200))
    status: Mapped[UserStatus] = mapped_column(
        Enum(UserStatus, name="user_status"), default=UserStatus.ACTIVE, nullable=False
    )
    is_super_admin: Mapped[bool] = mapped_column(default=False)

    memberships: Mapped[list["TenantMember"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class TenantRole(str, enum.Enum):
    OWNER_TENANT = "OWNER_TENANT"
    ADMIN_TENANT = "ADMIN_TENANT"


class MemberStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INVITED = "INVITED"
    REMOVED = "REMOVED"


class TenantMember(UUIDPKMixin, TimestampMixin, Base):
    """Links a User to a Tenant with a role.
    This -- NOT a client-supplied tenant_id -- is the source of truth
    for 'which tenant can this user act on'. See app/deps/tenant.py."""
    __tablename__ = "tenant_members"
    __table_args__ = (UniqueConstraint("tenant_id", "user_id", name="uq_tenant_user"),)

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[TenantRole] = mapped_column(Enum(TenantRole, name="tenant_role"))
    status: Mapped[MemberStatus] = mapped_column(Enum(MemberStatus, name="member_status"), default=MemberStatus.ACTIVE)

    tenant: Mapped["Tenant"] = relationship(back_populates="members")
    user: Mapped["User"] = relationship(back_populates="memberships")


class Plan(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "plans"

    name: Mapped[str] = mapped_column(String(100))
    max_products: Mapped[int] = mapped_column(Integer)
    max_admins: Mapped[int] = mapped_column(Integer)
    storage_limit_mb: Mapped[int] = mapped_column(Integer)
    features_json: Mapped[dict] = mapped_column(JSON, default=dict)

    contracts: Mapped[list["Contract"]] = relationship(back_populates="plan")


class ContractStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PENDING_SIGNATURE = "PENDING_SIGNATURE"
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    SUSPENDED = "SUSPENDED"
    CANCELLED = "CANCELLED"


class Contract(UUIDPKMixin, TimestampMixin, Base):
    """A contract is the enforceable link between a Tenant and a Plan.
    Backend policies (see services/contract_policy.py) read this table
    to allow/reject operations -- never trust the UI to hide a button."""
    __tablename__ = "contracts"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("plans.id"))
    start_at: Mapped[str] = mapped_column(String(32))  # ISO date string kept simple for MVP
    end_at: Mapped[str | None] = mapped_column(String(32), nullable=True)
    status: Mapped[ContractStatus] = mapped_column(Enum(ContractStatus, name="contract_status"), default=ContractStatus.DRAFT)
    version: Mapped[int] = mapped_column(Integer, default=1)

    tenant: Mapped["Tenant"] = relationship(back_populates="contracts")
    plan: Mapped["Plan"] = relationship(back_populates="contracts")


class Theme(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "themes"

    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), unique=True, index=True)
    primary_color: Mapped[str] = mapped_column(String(9), default="#E91E63")
    secondary_color: Mapped[str] = mapped_column(String(9), default="#FFFFFF")
    background_color: Mapped[str] = mapped_column(String(9), default="#F7F7F7")
    text_color: Mapped[str] = mapped_column(String(9), default="#222222")
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    banner_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    font_family: Mapped[str | None] = mapped_column(String(100), nullable=True)

    tenant: Mapped["Tenant"] = relationship(back_populates="theme")
