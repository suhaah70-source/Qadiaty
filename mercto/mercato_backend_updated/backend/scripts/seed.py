"""
Seed script: creates the first Super Admin account and a default plan
so the platform is usable immediately after `docker compose up`.

Run with:
    docker compose exec api python -m scripts.seed
or locally:
    python -m scripts.seed
"""
import asyncio
import os

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
from app.models.tenant import Plan, User

SUPER_ADMIN_EMAIL = os.getenv("SEED_SUPER_ADMIN_EMAIL", "admin@platform.local")
SUPER_ADMIN_PASSWORD = os.getenv("SEED_SUPER_ADMIN_PASSWORD", "ChangeMe123!")


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        existing_admin = (await db.execute(select(User).where(User.email == SUPER_ADMIN_EMAIL))).scalar_one_or_none()
        if existing_admin is None:
            db.add(
                User(
                    email=SUPER_ADMIN_EMAIL,
                    name="Super Admin",
                    password_hash=hash_password(SUPER_ADMIN_PASSWORD),
                    is_super_admin=True,
                )
            )
            print(f"[seed] Created super admin: {SUPER_ADMIN_EMAIL}")
        else:
            print("[seed] Super admin already exists, skipping.")

        existing_plans = (await db.execute(select(Plan))).scalars().all()
        if not existing_plans:
            db.add_all(
                [
                    Plan(name="Basic", max_products=100, max_admins=1, storage_limit_mb=5000, features_json={}),
                    Plan(name="Standard", max_products=500, max_admins=3, storage_limit_mb=20000, features_json={"analytics": True}),
                    Plan(name="Premium", max_products=2000, max_admins=10, storage_limit_mb=100000, features_json={"analytics": True, "priority_support": True}),
                ]
            )
            print("[seed] Created default plans: Basic, Standard, Premium")
        else:
            print("[seed] Plans already exist, skipping.")

        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
    print("[seed] Done.")
