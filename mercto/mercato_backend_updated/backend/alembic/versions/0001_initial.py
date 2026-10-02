"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


UPGRADE_SQL = """
CREATE TYPE tenant_status AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED');

CREATE TYPE user_status AS ENUM ('ACTIVE', 'DISABLED');

CREATE TYPE cart_status AS ENUM ('OPEN', 'CHECKED_OUT', 'ABANDONED');

CREATE TYPE category_status AS ENUM ('ACTIVE', 'HIDDEN');

CREATE TYPE contract_status AS ENUM ('DRAFT', 'PENDING_SIGNATURE', 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'CANCELLED');

CREATE TYPE tenant_role AS ENUM ('OWNER_TENANT', 'ADMIN_TENANT');

CREATE TYPE member_status AS ENUM ('ACTIVE', 'INVITED', 'REMOVED');

CREATE TYPE order_status AS ENUM ('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED');

CREATE TYPE product_status AS ENUM ('DRAFT', 'ACTIVE', 'OUT_OF_STOCK', 'ARCHIVED');

CREATE TABLE plans (
	name VARCHAR(100) NOT NULL, 
	max_products INTEGER NOT NULL, 
	max_admins INTEGER NOT NULL, 
	storage_limit_mb INTEGER NOT NULL, 
	features_json JSON NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id)
);

CREATE TABLE tenants (
	code VARCHAR(32) NOT NULL, 
	slug VARCHAR(64) NOT NULL, 
	name VARCHAR(200) NOT NULL, 
	status tenant_status NOT NULL, 
	logo_url VARCHAR(500), 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id)
);

CREATE TABLE users (
	email VARCHAR(255) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	name VARCHAR(200) NOT NULL, 
	status user_status NOT NULL, 
	is_super_admin BOOLEAN NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id)
);

CREATE TABLE addresses (
	user_id UUID NOT NULL, 
	city VARCHAR(100) NOT NULL, 
	address_text VARCHAR(500) NOT NULL, 
	notes VARCHAR(500), 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE audit_logs (
	tenant_id UUID, 
	user_id UUID, 
	action VARCHAR(100) NOT NULL, 
	entity_type VARCHAR(100) NOT NULL, 
	entity_id VARCHAR(100), 
	metadata_json JSON NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE SET NULL, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE carts (
	customer_id UUID NOT NULL, 
	tenant_id UUID NOT NULL, 
	status cart_status NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(customer_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
);

CREATE TABLE categories (
	tenant_id UUID NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	slug VARCHAR(150) NOT NULL, 
	status category_status NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_category_tenant_slug UNIQUE (tenant_id, slug), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
);

CREATE TABLE contracts (
	tenant_id UUID NOT NULL, 
	plan_id UUID NOT NULL, 
	start_at VARCHAR(32) NOT NULL, 
	end_at VARCHAR(32), 
	status contract_status NOT NULL, 
	version INTEGER NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE, 
	FOREIGN KEY(plan_id) REFERENCES plans (id)
);

CREATE TABLE notifications (
	user_id UUID NOT NULL, 
	tenant_id UUID, 
	type VARCHAR(50) NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	body VARCHAR(1000) NOT NULL, 
	read_at TIMESTAMP WITH TIME ZONE, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
);

CREATE TABLE refresh_tokens (
	user_id UUID NOT NULL, 
	token_hash VARCHAR(255) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	revoked_at TIMESTAMP WITH TIME ZONE, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE tenant_members (
	tenant_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	role tenant_role NOT NULL, 
	status member_status NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_tenant_user UNIQUE (tenant_id, user_id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE themes (
	tenant_id UUID NOT NULL, 
	primary_color VARCHAR(9) NOT NULL, 
	secondary_color VARCHAR(9) NOT NULL, 
	background_color VARCHAR(9) NOT NULL, 
	text_color VARCHAR(9) NOT NULL, 
	logo_url VARCHAR(500), 
	banner_url VARCHAR(500), 
	font_family VARCHAR(100), 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
);

CREATE TABLE orders (
	tenant_id UUID NOT NULL, 
	customer_id UUID NOT NULL, 
	status order_status NOT NULL, 
	subtotal FLOAT NOT NULL, 
	delivery_fee FLOAT NOT NULL, 
	total FLOAT NOT NULL, 
	address_id UUID, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE, 
	FOREIGN KEY(customer_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(address_id) REFERENCES addresses (id)
);

CREATE TABLE products (
	tenant_id UUID NOT NULL, 
	category_id UUID, 
	name VARCHAR(200) NOT NULL, 
	description VARCHAR(4000), 
	price FLOAT NOT NULL, 
	stock INTEGER NOT NULL, 
	status product_status NOT NULL, 
	sku VARCHAR(64) NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_product_tenant_sku UNIQUE (tenant_id, sku), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE, 
	FOREIGN KEY(category_id) REFERENCES categories (id) ON DELETE SET NULL
);

CREATE TABLE cart_items (
	cart_id UUID NOT NULL, 
	product_id UUID NOT NULL, 
	quantity INTEGER NOT NULL, 
	unit_price FLOAT NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(cart_id) REFERENCES carts (id) ON DELETE CASCADE, 
	FOREIGN KEY(product_id) REFERENCES products (id) ON DELETE CASCADE
);

CREATE TABLE order_items (
	order_id UUID NOT NULL, 
	product_id UUID NOT NULL, 
	product_name_snapshot VARCHAR(200) NOT NULL, 
	unit_price FLOAT NOT NULL, 
	quantity INTEGER NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(order_id) REFERENCES orders (id) ON DELETE CASCADE, 
	FOREIGN KEY(product_id) REFERENCES products (id)
);

CREATE TABLE product_images (
	tenant_id UUID NOT NULL, 
	product_id UUID NOT NULL, 
	object_key VARCHAR(500) NOT NULL, 
	sort_order INTEGER NOT NULL, 
	id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(tenant_id) REFERENCES tenants (id) ON DELETE CASCADE, 
	FOREIGN KEY(product_id) REFERENCES products (id) ON DELETE CASCADE
);
"""


def upgrade() -> None:
    for statement in UPGRADE_SQL.strip().split(";\n\n"):
        stmt = statement.strip()
        if stmt:
            op.execute(stmt if stmt.endswith(";") else stmt + ";")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS product_images CASCADE;")
    op.execute("DROP TABLE IF EXISTS order_items CASCADE;")
    op.execute("DROP TABLE IF EXISTS cart_items CASCADE;")
    op.execute("DROP TABLE IF EXISTS products CASCADE;")
    op.execute("DROP TABLE IF EXISTS orders CASCADE;")
    op.execute("DROP TABLE IF EXISTS themes CASCADE;")
    op.execute("DROP TABLE IF EXISTS tenant_members CASCADE;")
    op.execute("DROP TABLE IF EXISTS refresh_tokens CASCADE;")
    op.execute("DROP TABLE IF EXISTS notifications CASCADE;")
    op.execute("DROP TABLE IF EXISTS contracts CASCADE;")
    op.execute("DROP TABLE IF EXISTS categories CASCADE;")
    op.execute("DROP TABLE IF EXISTS carts CASCADE;")
    op.execute("DROP TABLE IF EXISTS audit_logs CASCADE;")
    op.execute("DROP TABLE IF EXISTS addresses CASCADE;")
    op.execute("DROP TABLE IF EXISTS users CASCADE;")
    op.execute("DROP TABLE IF EXISTS tenants CASCADE;")
    op.execute("DROP TABLE IF EXISTS plans CASCADE;")
    op.execute("DROP TYPE IF EXISTS tenant_status;")
    op.execute("DROP TYPE IF EXISTS user_status;")
    op.execute("DROP TYPE IF EXISTS cart_status;")
    op.execute("DROP TYPE IF EXISTS category_status;")
    op.execute("DROP TYPE IF EXISTS contract_status;")
    op.execute("DROP TYPE IF EXISTS tenant_role;")
    op.execute("DROP TYPE IF EXISTS member_status;")
    op.execute("DROP TYPE IF EXISTS order_status;")
    op.execute("DROP TYPE IF EXISTS product_status;")
