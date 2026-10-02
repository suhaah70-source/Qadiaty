from __future__ import annotations

import re
import json
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import Depends, HTTPException, status
from sqlalchemy import ForeignKey, String, UniqueConstraint, func, select
from sqlalchemy.orm import Mapped, Session, mapped_column


def attach_dashboard_compatibility(api):
    from backend.app import main as legacy
    from backend.app.database import Base, engine
    from backend.app.models import Category, Order, Product, Store, User

    class StoreCategory(Base):
        __tablename__ = "store_category_links"
        __table_args__ = (UniqueConstraint("store_id", "category_id", name="uq_store_category"),)
        id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
        store_id: Mapped[str] = mapped_column(ForeignKey("stores.id", ondelete="CASCADE"), index=True)
        category_id: Mapped[str] = mapped_column(ForeignKey("categories.id", ondelete="CASCADE"), index=True)

    class StoreMember(Base):
        __tablename__ = "store_dashboard_members"
        __table_args__ = (UniqueConstraint("store_id", "user_id", name="uq_store_dashboard_member"),)
        id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
        store_id: Mapped[str] = mapped_column(ForeignKey("stores.id", ondelete="CASCADE"), index=True)
        user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
        role: Mapped[str] = mapped_column(String(32), default="ADMIN_TENANT")

    Base.metadata.create_all(bind=engine)
    from sqlalchemy import inspect, text
    if "logo_shape" not in {column["name"] for column in inspect(engine).get_columns("stores")}:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE stores ADD COLUMN logo_shape VARCHAR(20) NOT NULL DEFAULT 'circle'"))

    def store_for(db: Session, user: User, store_id: str) -> Store:
        store = db.get(Store, store_id)
        if store is None:
            raise HTTPException(status_code=404, detail="Store not found")
        if store.owner_id != user.id:
            member = db.scalar(select(StoreMember).where(
                StoreMember.store_id == store.id,
                StoreMember.user_id == user.id,
            ))
            if member is None and user.role != "ADMIN":
                raise HTTPException(status_code=404, detail="Store not found")
        if store.status != "APPROVED" and user.role != "ADMIN":
            raise HTTPException(status_code=403, detail="Store is not approved")
        return store

    original_owned_store = legacy.owned_store

    def member_aware_owned_store(db: Session, user: User) -> Store:
        store = db.scalar(select(Store).where(Store.owner_id == user.id))
        if store is None:
            membership = db.scalar(select(StoreMember).where(StoreMember.user_id == user.id))
            if membership is not None:
                store = db.get(Store, membership.store_id)
        if store is None:
            raise HTTPException(status_code=404, detail="No store is linked to this account")
        if store.status != "APPROVED" and user.role != "ADMIN":
            raise HTTPException(status_code=403, detail="Store is not approved")
        return store

    legacy.owned_store = member_aware_owned_store

    @api.get("/api/v1/tenants")
    def admin_tenants(db: Session = Depends(legacy.get_db), user: User = Depends(legacy.require_admin)):
        rows = db.scalars(select(Store).order_by(Store.created_at.desc())).all()
        result = []
        for store in rows:
            item = legacy.store_json(store)
            item["status"] = {"APPROVED": "ACTIVE", "REJECTED": "CLOSED"}.get(store.status, store.status)
            item["plan_id"] = "mercato-standard"
            result.append(item)
        return result

    @api.post("/api/v1/tenants", status_code=201)
    def admin_create_store(payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.require_admin)):
        name = str(payload.get("name", "")).strip()
        slug = str(payload.get("slug", "")).strip().lower()
        owner_name = str(payload.get("owner_name", "")).strip()
        owner_phone = legacy.normalize_phone(str(payload.get("owner_phone") or payload.get("owner_email") or ""))
        password = str(payload.get("owner_password", ""))
        city = str(payload.get("city", "")).strip()
        if len(name) < 2 or len(slug) < 2 or len(owner_name) < 2 or len(password) < 8 or len(city) < 2:
            raise HTTPException(status_code=422, detail="Store, city, owner and an 8-character password are required")
        if db.scalar(select(Store).where(Store.slug == slug)):
            raise HTTPException(status_code=409, detail="Store slug is already in use")
        owner = db.scalar(select(User).where(User.phone == owner_phone))
        if owner is not None:
            raise HTTPException(status_code=409, detail="This phone number already has an account; have the store owner submit an application from Customer App")
        owner = User(phone=owner_phone, full_name=owner_name, password_hash=legacy.hash_password(password), role="VENDOR")
        db.add(owner)
        db.flush()
        store = Store(owner_id=owner.id, code=f"SHOP-{uuid4().hex[:8].upper()}", slug=slug,
                      name=name, city=city, status="APPROVED", store_category="general")
        db.add(store)
        db.commit()
        db.refresh(store)
        return legacy.store_json(store)

    @api.get("/api/v1/plans")
    def dashboard_plans(user: User = Depends(legacy.require_admin)):
        return [{"id": "mercato-standard", "name": "قضيتي", "max_products": 10000, "max_admins": 10, "storage_limit_mb": 5000}]

    @api.get("/api/v1/admin/analytics")
    def dashboard_analytics(db: Session = Depends(legacy.get_db), user: User = Depends(legacy.require_admin)):
        stores = db.scalars(select(Store)).all()
        orders = db.scalars(select(Order)).all()
        products = db.scalars(select(Product)).all()
        now = datetime.now(timezone.utc)
        months = []
        for offset in range(5, -1, -1):
            month_index = now.month - 1 - offset
            year = now.year + month_index // 12
            month = month_index % 12 + 1
            months.append({"month": f"{year:04d}-{month:02d}", "revenue": 0.0})
        revenue_by_month = {item["month"]: item for item in months}
        for order in orders:
            if order.status != "DELIVERED":
                continue
            month_key = f"{order.created_at.year:04d}-{order.created_at.month:02d}"
            if month_key in revenue_by_month:
                revenue_by_month[month_key]["revenue"] += float(order.total)
        return {
            "tenants_total": len(stores),
            "tenants_active": sum(row.status == "APPROVED" for row in stores),
            "tenants_suspended": sum(row.status == "SUSPENDED" for row in stores),
            "tenants_pending": sum(row.status == "PENDING" for row in stores),
            "contracts_active": 0,
            "catalog_total_products": len(products),
            "orders_total": len(orders),
            "orders_pending": sum(row.status == "PENDING" for row in orders),
            "gross_merchandise_value": sum(float(row.total) for row in orders if row.status == "DELIVERED"),
            "revenue_by_month": months,
        }

    @api.patch("/api/v1/tenants/{tenant_id}/status")
    def admin_tenant_status(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.require_admin)):
        store = db.get(Store, tenant_id)
        if store is None:
            raise HTTPException(status_code=404, detail="Store not found")
        status_value = payload.get("status")
        mapped = {"ACTIVE": "APPROVED", "SUSPENDED": "SUSPENDED", "CLOSED": "REJECTED", "PENDING": "PENDING"}.get(status_value)
        if mapped is None:
            raise HTTPException(status_code=422, detail="Unsupported store status")
        store.status = mapped
        db.commit()
        return legacy.store_json(store)

    @api.get("/api/v1/me/tenants")
    def my_stores(db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = db.scalar(select(Store).where(Store.owner_id == user.id))
        if store is None:
            membership = db.scalar(select(StoreMember).where(StoreMember.user_id == user.id))
            if membership is not None:
                store = db.get(Store, membership.store_id)
        return [legacy.store_json(store)] if store else []

    @api.get("/api/v1/tenants/{tenant_id}/analytics")
    def store_analytics(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        product_count = db.scalar(select(func.count()).select_from(Product).where(Product.store_id == store.id)) or 0
        orders = db.scalars(select(Order).where(Order.store_id == store.id)).all()
        pending_count = sum(order.status == "PENDING" for order in orders)
        sales_total = sum(float(order.total) for order in orders if order.status == "DELIVERED")
        now = datetime.now(timezone.utc)
        months = []
        for offset in range(5, -1, -1):
            month_index = now.month - 1 - offset
            year = now.year + month_index // 12
            month = month_index % 12 + 1
            months.append({"month": f"{year:04d}-{month:02d}", "revenue": 0.0})
        revenue_by_month = {item["month"]: item for item in months}
        for order in orders:
            if order.status != "DELIVERED":
                continue
            created = order.created_at
            month_key = f"{created.year:04d}-{created.month:02d}"
            if month_key in revenue_by_month:
                revenue_by_month[month_key]["revenue"] += float(order.total)
        return {
            "store_id": store.id,
            "catalog": {"total_products": product_count},
            "orders": {
                "total": len(orders),
                "pending": pending_count,
                "gross_merchandise_value": sales_total,
            },
            "revenue_by_month": months,
            # Keep the legacy scalar fields available to older clients.
            "products": product_count,
            "orders_total": len(orders),
            "pending_orders": pending_count,
            "sales": sales_total,
        }

    @api.get("/api/v1/tenants/{tenant_id}/categories")
    def list_store_categories(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        rows = db.scalars(
            select(Category).join(StoreCategory, StoreCategory.category_id == Category.id)
            .where(StoreCategory.store_id == store.id, Category.is_active.is_(True))
            .order_by(Category.sort_order, Category.name)
        ).all()
        return [{"id": row.id, "name": row.name, "slug": row.slug, "status": "ACTIVE"} for row in rows]

    @api.post("/api/v1/tenants/{tenant_id}/categories", status_code=201)
    def create_store_category(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        name = str(payload.get("name", "")).strip()
        slug = str(payload.get("slug", "")).strip().lower()
        if not name or not slug:
            raise HTTPException(status_code=422, detail="Category name and slug are required")
        category = db.scalar(select(Category).where(Category.slug == slug))
        if category is None:
            category = Category(name=name, slug=slug, sort_order=int(payload.get("sort_order", 0)))
            db.add(category)
            db.flush()
        link = db.scalar(select(StoreCategory).where(StoreCategory.store_id == store.id, StoreCategory.category_id == category.id))
        if link is None:
            db.add(StoreCategory(store_id=store.id, category_id=category.id))
        db.commit()
        return {"id": category.id, "name": category.name, "slug": category.slug, "status": "ACTIVE"}

    @api.delete("/api/v1/tenants/{tenant_id}/categories/{category_id}", status_code=204)
    def remove_store_category(tenant_id: str, category_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        link = db.scalar(select(StoreCategory).where(StoreCategory.store_id == store.id, StoreCategory.category_id == category_id))
        if link is None:
            raise HTTPException(status_code=404, detail="Category not found in this store")
        db.delete(link)
        db.commit()

    @api.get("/api/v1/tenants/{tenant_id}/products")
    def list_store_products(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        return legacy.vendor_products(db, user)

    @api.patch("/api/v1/tenants/{tenant_id}/products/order")
    def reorder_store_products(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        product_ids = payload.get("product_ids")
        if not isinstance(product_ids, list) or not all(isinstance(item, str) for item in product_ids):
            raise HTTPException(status_code=422, detail="product_ids must be a list of product IDs")
        rows = db.scalars(select(Product).where(Product.store_id == store.id)).all()
        by_id = {row.id: row for row in rows}
        if len(product_ids) != len(set(product_ids)) or set(product_ids) != set(by_id):
            raise HTTPException(status_code=422, detail="The product order must include every store product once")
        for index, product_id in enumerate(product_ids):
            by_id[product_id].sort_order = index
        db.commit()
        return {"product_ids": product_ids}

    @api.post("/api/v1/tenants/{tenant_id}/products", status_code=201)
    def create_store_product(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        parsed = legacy.ProductInput.model_validate(payload)
        return legacy.create_product(parsed, db, user)

    @api.patch("/api/v1/tenants/{tenant_id}/products/{product_id}")
    def update_store_product(tenant_id: str, product_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        parsed = legacy.ProductInput.model_validate(payload)
        return legacy.update_product(product_id, parsed, db, user)

    @api.delete("/api/v1/tenants/{tenant_id}/products/{product_id}")
    def delete_store_product(tenant_id: str, product_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        return legacy.delete_product(product_id, db, user)

    @api.get("/api/v1/tenants/{tenant_id}/orders")
    def list_store_orders(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        return legacy.vendor_orders(db, user)

    @api.patch("/api/v1/tenants/{tenant_id}/orders/{order_id}/status")
    def update_store_order(tenant_id: str, order_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store_for(db, user, tenant_id)
        parsed = legacy.OrderStatusInput.model_validate(payload)
        return legacy.vendor_update_order(order_id, parsed, db, user)

    @api.get("/api/v1/tenants/{tenant_id}/theme")
    def get_store_theme(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        try:
            design_elements = json.loads(store.design_json or "[]")
        except (TypeError, ValueError):
            design_elements = []
        return {"store_name": store.name, "store_description": store.description or "",
                "design_elements": design_elements,
                "primary_color": store.primary_color, "secondary_color": store.secondary_color,
                "background_color": store.background_color, "text_color": store.text_color,
                "accent_color": store.accent_color,
                "card_color": store.card_color,
                "background_style": store.background_style,
                "background_gradient_start": store.background_gradient_start,
                "background_gradient_end": store.background_gradient_end,
                "controls_x": store.controls_x,
                "controls_y": store.controls_y,
                "logo_url": store.logo_url, "banner_url": store.banner_url,
                "product_image_shape": store.product_image_shape,
                "product_image_scale": store.product_image_scale,
                "show_product_card": store.show_product_card,
                "product_layout": store.product_layout,
                "product_columns": store.product_columns,
                "category_style": store.category_style,
                "product_card_style": store.product_card_style,
                "show_product_descriptions": store.show_product_descriptions,
                "background_image_url": store.background_image_url,
                "background_image_fit": store.background_image_fit,
                "background_overlay_opacity": store.background_overlay_opacity,
                "logo_position": store.logo_position,
                "logo_shape": store.logo_shape,
                "store_category": store.store_category}

    @api.patch("/api/v1/tenants/{tenant_id}/theme")
    def update_store_theme(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        allowed = {"primary_color", "secondary_color", "background_color", "text_color", "logo_url", "banner_url", "logo_shape", "product_image_shape", "product_image_scale", "product_layout", "product_columns", "category_style", "product_card_style", "show_product_card", "show_product_descriptions", "store_category", "background_image_url", "background_image_fit", "background_overlay_opacity", "logo_position", "background_style", "background_gradient_start", "background_gradient_end", "accent_color", "card_color", "controls_x", "controls_y", "name", "description", "store_name", "store_description"}
        name_value = payload.get("store_name", payload.get("name"))
        description_value = payload.get("store_description", payload.get("description"))
        if name_value is not None and (not isinstance(name_value, str) or not name_value.strip() or len(name_value.strip()) > 140):
            raise HTTPException(status_code=422, detail="Store name must be between 1 and 140 characters")
        if description_value is not None and (not isinstance(description_value, str) or len(description_value) > 2000):
            raise HTTPException(status_code=422, detail="Store description must be 2000 characters or less")
        if "design_elements" in payload:
            elements = payload["design_elements"]
            if not isinstance(elements, list) or len(elements) > 40:
                raise HTTPException(status_code=422, detail="design_elements must be a list with at most 40 items")
            safe_elements = []
            for element in elements:
                if not isinstance(element, dict) or element.get("type") not in ("text", "button", "shape", "image"):
                    raise HTTPException(status_code=422, detail="Unsupported store design element")
                try:
                    x, y, width, height = (float(element[key]) for key in ("x", "y", "width", "height"))
                except (KeyError, TypeError, ValueError):
                    raise HTTPException(status_code=422, detail="Invalid store design position")
                if (not all(0 <= number <= 1 for number in (x, y, width, height))
                        or x + width > 1 or y + height > 1):
                    raise HTTPException(status_code=422, detail="Store design positions must be between 0 and 1")
                color = str(element.get("color", "#FFFFFF"))
                if not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
                    raise HTTPException(status_code=422, detail="Design element color must be a six-digit hex color")
                try:
                    font_size = float(element.get("font_size", 16))
                    radius = float(element.get("radius", 12))
                except (TypeError, ValueError):
                    raise HTTPException(status_code=422, detail="Invalid store design style")
                image_url = str(element.get("image_url", ""))[:500]
                if element["type"] == "image" and not (
                    image_url.startswith("/")
                    or image_url.startswith("https://")
                    or image_url.startswith("http://")
                ):
                    raise HTTPException(status_code=422, detail="Design images must use an uploaded or HTTP image URL")
                safe_elements.append({
                    "id": str(element.get("id", ""))[:40],
                    "type": element["type"],
                    "text": str(element.get("text", ""))[:100],
                    "x": x, "y": y, "width": width, "height": height,
                    "color": color,
                    "image_url": image_url,
                    "font_size": min(40.0, max(10.0, font_size)),
                    "radius": min(40.0, max(0.0, radius)),
                })
            store.design_json = json.dumps(safe_elements, ensure_ascii=False)
        if payload.get("product_image_shape") not in (None, "rounded", "square", "circle", "portrait", "triangle", "diamond"):
            raise HTTPException(status_code=422, detail="Unsupported product image shape")
        if payload.get("product_image_scale") is not None and not 0.5 <= float(payload["product_image_scale"]) <= 1:
            raise HTTPException(status_code=422, detail="Product image scale must be between 0.5 and 1")
        if "show_product_card" in payload and not isinstance(payload["show_product_card"], bool):
            raise HTTPException(status_code=422, detail="show_product_card must be boolean")
        if payload.get("background_image_fit") not in (None, "cover", "contain"):
            raise HTTPException(status_code=422, detail="Unsupported background image fit")
        if payload.get("product_layout") not in (None, "grid", "list"):
            raise HTTPException(status_code=422, detail="Unsupported product layout")
        if "product_columns" in payload and (isinstance(payload["product_columns"], bool) or not 1 <= int(payload["product_columns"]) <= 4):
            raise HTTPException(status_code=422, detail="Product columns must be between 1 and 4")
        if payload.get("category_style") not in (None, "chips", "cards"):
            raise HTTPException(status_code=422, detail="Unsupported category style")
        if payload.get("product_card_style") not in (None, "classic", "minimal", "poster"):
            raise HTTPException(status_code=422, detail="Unsupported product card style")
        if "show_product_descriptions" in payload and not isinstance(payload["show_product_descriptions"], bool):
            raise HTTPException(status_code=422, detail="show_product_descriptions must be boolean")
        if payload.get("background_overlay_opacity") is not None and not 0 <= float(payload["background_overlay_opacity"]) <= 0.85:
            raise HTTPException(status_code=422, detail="Background overlay opacity must be between 0 and 0.85")
        if payload.get("logo_position") not in (None, "topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"):
            raise HTTPException(status_code=422, detail="Unsupported logo position")
        if payload.get("logo_shape") not in (None, "circle", "square", "rounded", "triangle", "diamond", "hexagon"):
            raise HTTPException(status_code=422, detail="Unsupported logo shape")
        if payload.get("store_category") not in (None, "clothing", "shoes", "pharmacy", "electronics", "home", "beauty", "grocery", "general"):
            raise HTTPException(status_code=422, detail="Unsupported store category")
        for color_key in ("primary_color", "secondary_color", "background_color", "text_color"):
            if color_key in payload and not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(payload[color_key])):
                raise HTTPException(status_code=422, detail=f"{color_key} must be a six-digit hex color")
        for color_key in ("accent_color", "card_color", "background_gradient_start", "background_gradient_end"):
            if color_key in payload and not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(payload[color_key])):
                raise HTTPException(status_code=422, detail=f"{color_key} must be a six-digit hex color")
        if payload.get("background_style") not in (None, "solid", "gradient", "image", "blend"):
            raise HTTPException(status_code=422, detail="Unsupported background style")
        for position in ("controls_x", "controls_y"):
            if position in payload and not 0 <= float(payload[position]) <= 1:
                raise HTTPException(status_code=422, detail=f"{position} must be between 0 and 1")
        for key, value in payload.items():
            if key in allowed:
                target = {"name": "name", "store_name": "name", "store_description": "description"}.get(key, key)
                setattr(store, target, value.strip() if target == "name" else value)
        db.commit()
        db.refresh(store)
        return {"store_name": store.name, "store_description": store.description or "",
                "design_elements": json.loads(store.design_json or "[]"),
                "primary_color": store.primary_color, "secondary_color": store.secondary_color,
                "background_color": store.background_color, "text_color": store.text_color,
                "accent_color": store.accent_color,
                "card_color": store.card_color,
                "background_style": store.background_style,
                "background_gradient_start": store.background_gradient_start,
                "background_gradient_end": store.background_gradient_end,
                "controls_x": store.controls_x,
                "controls_y": store.controls_y,
                "logo_url": store.logo_url, "banner_url": store.banner_url,
                "product_image_shape": store.product_image_shape,
                "product_image_scale": store.product_image_scale,
                "show_product_card": store.show_product_card,
                "product_layout": store.product_layout,
                "product_columns": store.product_columns,
                "category_style": store.category_style,
                "product_card_style": store.product_card_style,
                "show_product_descriptions": store.show_product_descriptions,
                "background_image_url": store.background_image_url,
                "background_image_fit": store.background_image_fit,
                "background_overlay_opacity": store.background_overlay_opacity,
                "logo_position": store.logo_position,
                "logo_shape": store.logo_shape,
                "store_category": store.store_category}

    @api.get("/api/v1/tenants/{tenant_id}/team")
    def list_store_team(tenant_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        rows = db.scalars(select(StoreMember).where(StoreMember.store_id == store.id)).all()
        result = [{"id": f"owner:{store.owner_id}", "user_id": store.owner_id,
                   "role": "OWNER_TENANT", "email": (db.get(User, store.owner_id).phone if db.get(User, store.owner_id) else ""),
                   "name": (db.get(User, store.owner_id).full_name if db.get(User, store.owner_id) else "Store owner")}]
        for row in rows:
            member = db.get(User, row.user_id)
            if member:
                result.append({"id": row.id, "user_id": member.id, "role": row.role,
                               "email": member.phone, "name": member.full_name or member.phone})
        return result

    @api.post("/api/v1/tenants/{tenant_id}/team", status_code=201)
    def invite_store_team_member(tenant_id: str, payload: dict, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        if store.owner_id != user.id:
            raise HTTPException(status_code=403, detail="Only the store owner can invite team members")
        phone = legacy.normalize_phone(str(payload.get("phone") or payload.get("email") or ""))
        name = str(payload.get("name", "")).strip()
        password = str(payload.get("password", ""))
        if not phone or not name or len(password) < 8:
            raise HTTPException(status_code=422, detail="Phone, full name, and a password of at least 8 characters are required")
        member = db.scalar(select(User).where(User.phone == phone))
        if member is None:
            member = User(phone=phone, full_name=name, password_hash=legacy.hash_password(password), role="VENDOR")
            db.add(member)
            db.flush()
        elif member.id == store.owner_id:
            raise HTTPException(status_code=409, detail="The store owner is already a team member")
        link = db.scalar(select(StoreMember).where(StoreMember.store_id == store.id, StoreMember.user_id == member.id))
        if link is None:
            link = StoreMember(store_id=store.id, user_id=member.id, role="ADMIN_TENANT")
            db.add(link)
        db.commit()
        db.refresh(link)
        return {"id": link.id, "user_id": member.id, "role": link.role,
                "email": member.phone, "name": member.full_name or member.phone}

    @api.delete("/api/v1/tenants/{tenant_id}/team/{member_id}", status_code=204)
    def remove_store_team_member(tenant_id: str, member_id: str, db: Session = Depends(legacy.get_db), user: User = Depends(legacy.current_user)):
        store = store_for(db, user, tenant_id)
        if store.owner_id != user.id:
            raise HTTPException(status_code=403, detail="Only the store owner can remove team members")
        link = db.scalar(select(StoreMember).where(StoreMember.id == member_id, StoreMember.store_id == store.id))
        if link is None:
            raise HTTPException(status_code=404, detail="Team member not found")
        db.delete(link)
        db.commit()
