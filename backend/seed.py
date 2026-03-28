"""
Seed the database with categories, products, locations, and an admin user.
Usage: python seed.py
"""
import asyncio
import os
import re
import sys
from pathlib import Path

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

# Add parent to path so we can import app
sys.path.insert(0, str(Path(__file__).parent))

from app.config import settings
from app.database import async_session, engine, Base
from app.models.user import Profile
from app.models.loyalty import LoyaltyAccount
from app.services.auth_service import hash_password
import app.models  # noqa — register all models
import uuid


MIGRATIONS_DIR = Path(__file__).parent.parent / "supabase" / "migrations"


async def run_sql_file(db: AsyncSession, filename: str):
    """Execute a SQL file, stripping Supabase-specific commands."""
    filepath = MIGRATIONS_DIR / filename
    if not filepath.exists():
        print(f"  [SKIP] {filename} not found")
        return

    sql = filepath.read_text()
    # Remove BEGIN/COMMIT — we handle transactions via SQLAlchemy
    sql = sql.replace("BEGIN;", "").replace("COMMIT;", "")

    # Scope subcategory lookups by parent category to avoid ambiguous names
    sql = re.sub(
        r"\(SELECT id FROM categories WHERE name = '([^']+)'\),"
        r"(\s*\n?\s*)"
        r"\(SELECT id FROM subcategories WHERE name = '([^']+)'\)",
        r"(SELECT id FROM categories WHERE name = '\1'),"
        r"\2"
        r"(SELECT id FROM subcategories WHERE name = '\3'"
        r" AND category_id = (SELECT id FROM categories WHERE name = '\1'))",
        sql,
    )

    # Split into individual statements by semicolons (outside quotes)
    statements = []
    current = []
    for line in sql.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--") or not stripped:
            continue
        current.append(line)
        if stripped.endswith(";"):
            statements.append("\n".join(current))
            current = []
    if current:
        statements.append("\n".join(current))

    for stmt in statements:
        stmt = stmt.strip().rstrip(";").strip()
        if not stmt:
            continue
        try:
            await db.execute(text(stmt))
        except Exception as e:
            err_msg = str(e).split("\n")[0][:150]
            print(f"  [WARN] {err_msg}")
            await db.rollback()


async def seed_admin(db: AsyncSession):
    """Create the admin user if not exists."""
    phone = settings.ADMIN_PHONE
    result = await db.execute(select(Profile).where(Profile.phone == phone))
    if result.scalar_one_or_none():
        print(f"  Admin user {phone} already exists")
        return

    user_id = uuid.uuid4()
    admin = Profile(
        id=user_id,
        phone=phone,
        password_hash=hash_password(settings.ADMIN_PASSWORD),
        full_name="TOOLOR Admin",
        is_admin=True,
        referral_code=f"TOOLOR-{str(user_id)[:8].upper()}",
    )
    db.add(admin)

    loyalty = LoyaltyAccount(
        user_id=user_id,
        qr_code=f"TOOLOR-{str(user_id).replace('-', '')[:12].upper()}",
        tier="platinum",
        points=0,
        total_spent=0,
    )
    db.add(loyalty)
    print(f"  Created admin user: {phone} / {settings.ADMIN_PASSWORD}")


async def create_sequence(db: AsyncSession):
    """Create the order number sequence if not exists."""
    try:
        await db.execute(text("CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1"))
        print("  Created order_number_seq")
    except Exception as e:
        print(f"  [WARN] Sequence: {e}")


async def main():
    print("=== TOOLOR Database Seed ===\n")

    # Create all tables from SQLAlchemy models
    print("[1/6] Creating tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("  Done\n")

    async with async_session() as db:
        # Create sequence
        print("[2/6] Creating sequences...")
        await create_sequence(db)
        await db.commit()
        print()

        # Seed categories
        print("[3/6] Seeding categories & subcategories...")
        await run_sql_file(db, "002_seed_categories.sql")
        await db.commit()
        print("  Done\n")

        # Seed products
        print("[4/6] Seeding products...")
        await run_sql_file(db, "003_seed_products.sql")
        await db.commit()
        print("  Done\n")

        # Seed locations
        print("[5/6] Seeding locations...")
        await run_sql_file(db, "004_seed_locations.sql")
        await db.commit()
        print("  Done\n")

        # Create admin
        print("[6/6] Creating admin user...")
        await seed_admin(db)
        await db.commit()
        print("  Done\n")

    print("=== Seed complete! ===")


if __name__ == "__main__":
    asyncio.run(main())
