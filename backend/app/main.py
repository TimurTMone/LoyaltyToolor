import logging
import traceback
from contextlib import asynccontextmanager
from pathlib import Path

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, users, loyalty, products, orders, cart, favorites, chat, locations, promo_codes, notifications, referrals, webhooks
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
    analytics as admin_analytics,
)
from app.middleware.request_logging import RequestLoggingMiddleware

import os
if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=0.3,
        environment=os.getenv("ENVIRONMENT", "production"),
        send_default_pii=False,
    )

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("toolor")


async def _auto_migrate():
    """Create all tables on first start if they don't exist."""
    from app.database import engine, Base
    from app.models import user, loyalty, product, order, cart, chat, notification, promo_code, location, referral, app_event  # noqa: F401
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@asynccontextmanager
async def lifespan(app: FastAPI):
    for sub in ("product-images", "avatars"):
        Path(settings.UPLOAD_DIR, sub).mkdir(parents=True, exist_ok=True)
    await _auto_migrate()
    yield


app = FastAPI(title="TOOLOR API", version="1.0.0", lifespan=lifespan)
app.add_middleware(RequestLoggingMiddleware)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error(f"Unhandled error on {request.method} {request.url.path}: {exc}\n{tb}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


# CORS — allow all origins since auth is token-based (not cookie-based)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
app.include_router(admin_analytics.router, prefix="/api/v1/admin", tags=["admin-analytics"])


@app.get("/api/v1/health")
async def health():
    return {"status": "ok"}


@app.get("/api/v1/sentry-debug")
async def sentry_debug():
    """Intentionally raises an error to verify Sentry is capturing exceptions.
    Also returns whether Sentry is configured."""
    sentry_enabled = bool(settings.SENTRY_DSN)
    if not sentry_enabled:
        return {"sentry_configured": False, "message": "SENTRY_DSN not set"}
    division_by_zero = 1 / 0  # noqa — intentional
    return {"result": division_by_zero}
