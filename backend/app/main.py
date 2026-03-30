import asyncio
import os
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
import sentry_sdk
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, users, loyalty, products, orders, cart, favorites, chat, locations, promo_codes, notifications, referrals, webhooks

if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=0.3,
        environment="production",
    )
from app.routers.admin import (
    products as admin_products,
    orders as admin_orders,
    users as admin_users,
    categories as admin_categories,
    promo_codes as admin_promo_codes,
    locations as admin_locations,
    dashboard as admin_dashboard,
    notifications as admin_notifications,
    inventory as admin_inventory,
)

IS_VERCEL = bool(os.environ.get("VERCEL"))
RENDER_URL = os.environ.get("RENDER_EXTERNAL_URL", "")


async def _keep_alive():
    """Ping self every 13 minutes to prevent Render free tier spin-down."""
    if not RENDER_URL:
        return
    await asyncio.sleep(60)  # wait for startup
    async with httpx.AsyncClient() as client:
        while True:
            try:
                await client.get(f"{RENDER_URL}/api/v1/health", timeout=10)
            except Exception:
                pass
            await asyncio.sleep(780)  # 13 minutes


async def _auto_migrate():
    """Create all tables on first start if they don't exist."""
    from app.database import engine, Base
    # Import all models so Base.metadata knows about them
    from app.models import user, loyalty, product, order, cart, chat, notification, promo_code, location, referral  # noqa: F401
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if not IS_VERCEL:
        for sub in ("payment-proofs", "product-images", "avatars"):
            Path(settings.UPLOAD_DIR, sub).mkdir(parents=True, exist_ok=True)
    # Auto-create tables if needed (new DB)
    await _auto_migrate()
    # Keep-alive task for Render free tier
    task = asyncio.create_task(_keep_alive())
    yield
    task.cancel()


import logging
import traceback

from fastapi.requests import Request
from fastapi.responses import JSONResponse

app = FastAPI(title="TOOLOR API", version="1.0.0", lifespan=lifespan)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("toolor")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error(f"Unhandled error on {request.method} {request.url.path}: {exc}\n{tb}")
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc), "path": request.url.path},
    )


# CORS — allow all origins since auth is token-based (not cookie-based)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for uploads (not available on Vercel serverless)
if not IS_VERCEL:
    app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Public + authenticated routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
app.include_router(loyalty.router, prefix="/api/v1/loyalty", tags=["loyalty"])
app.include_router(products.router, prefix="/api/v1/products", tags=["products"])
app.include_router(orders.router, prefix="/api/v1/orders", tags=["orders"])
app.include_router(cart.router, prefix="/api/v1/cart", tags=["cart"])
app.include_router(favorites.router, prefix="/api/v1/favorites", tags=["favorites"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(locations.router, prefix="/api/v1/locations", tags=["locations"])
app.include_router(promo_codes.router, prefix="/api/v1/promo-codes", tags=["promo-codes"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["notifications"])
app.include_router(referrals.router, prefix="/api/v1/referrals", tags=["referrals"])
app.include_router(webhooks.router, prefix="/api/v1/webhooks", tags=["webhooks"])

# Admin routers
app.include_router(admin_dashboard.router, prefix="/api/v1/admin", tags=["admin"])
app.include_router(admin_products.router, prefix="/api/v1/admin/products", tags=["admin-products"])
app.include_router(admin_orders.router, prefix="/api/v1/admin/orders", tags=["admin-orders"])
app.include_router(admin_users.router, prefix="/api/v1/admin/users", tags=["admin-users"])
app.include_router(admin_categories.router, prefix="/api/v1/admin/categories", tags=["admin-categories"])
app.include_router(admin_promo_codes.router, prefix="/api/v1/admin/promo-codes", tags=["admin-promo-codes"])
app.include_router(admin_locations.router, prefix="/api/v1/admin/locations", tags=["admin-locations"])
app.include_router(admin_notifications.router, prefix="/api/v1/admin/notifications", tags=["admin-notifications"])
app.include_router(admin_inventory.router, prefix="/api/v1/admin/inventory", tags=["admin-inventory"])


@app.get("/api/v1/health")
async def health():
    return {"status": "ok"}


@app.post("/api/v1/admin/migrate-from-neon")
async def migrate_from_neon():
    """One-time migration: copy data from Neon to current DB. Remove after use."""
    import asyncpg as apg
    from app.database import engine

    neon_url = "postgresql://neondb_owner:npg_3NKgvsFrW5io@ep-blue-boat-amiwae15.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require"

    src = await apg.connect(neon_url)
    # Get all table names
    # Order matters: parent tables first to satisfy foreign keys
    table_names = [
        "profiles", "categories", "subcategories", "products", "locations",
        "loyalty_accounts", "promo_codes",
        "orders", "order_items", "loyalty_transactions",
        "cart_items", "favorites",
        "chat_sessions", "chat_messages", "notifications", "referrals",
    ]

    # Also copy sequences
    seqs = await src.fetch(
        "SELECT sequencename FROM pg_sequences WHERE schemaname = 'public'"
    )

    results = {}
    # Build destination URL from settings (internal Render Postgres)
    dst_url = settings.DATABASE_URL.replace("+asyncpg", "")
    # Remove sslmode params for internal render connection
    for p in ("?sslmode=require", "&sslmode=require"):
        dst_url = dst_url.replace(p, "")

    dst = await apg.connect(dst_url)

    # Create sequences first
    for seq in seqs:
        name = seq['sequencename']
        try:
            val = await src.fetchval(f"SELECT last_value FROM {name}")
            await dst.execute(f"CREATE SEQUENCE IF NOT EXISTS {name}")
            await dst.execute(f"SELECT setval('{name}', {val})")
            results[f"seq_{name}"] = val
        except Exception as e:
            results[f"seq_{name}"] = str(e)

    for tname in table_names:
        try:
            rows = await src.fetch(f"SELECT * FROM {tname}")
            if not rows:
                results[tname] = 0
                continue
            cols = list(rows[0].keys())
            # Clear destination table
            await dst.execute(f"DELETE FROM {tname}")
            # Insert rows
            for row in rows:
                placeholders = ", ".join(f"${i+1}" for i in range(len(cols)))
                col_names = ", ".join(f'"{c}"' for c in cols)
                await dst.execute(
                    f'INSERT INTO "{tname}" ({col_names}) VALUES ({placeholders})',
                    *[row[c] for c in cols]
                )
            results[tname] = len(rows)
        except Exception as e:
            results[tname] = str(e)

    await src.close()
    await dst.close()
    return {"migrated": results}


@app.get("/api/v1/img")
async def proxy_image(url: str = Query(...)):
    """Proxy product images from toolorkg.com to avoid CORS issues on web."""
    if not url.startswith("https://toolorkg.com/"):
        return Response(status_code=400, content="Only toolorkg.com URLs allowed")
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, timeout=10, follow_redirects=True)
    return Response(
        content=resp.content,
        media_type=resp.headers.get("content-type", "image/jpeg"),
        headers={"Cache-Control": "public, max-age=86400"},
    )
