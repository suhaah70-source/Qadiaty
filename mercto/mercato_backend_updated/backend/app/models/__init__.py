"""Import every model module here so Base.metadata is complete when
Alembic (or `Base.metadata.create_all`) needs to see the full schema."""
from app.models.tenant import Tenant, User, TenantMember, Plan, Contract, Theme  # noqa: F401
from app.models.catalog import Category, Product, ProductImage  # noqa: F401
from app.models.order import Address, Cart, CartItem, Order, OrderItem  # noqa: F401
from app.models.system import Notification, AuditLog, RefreshToken  # noqa: F401
