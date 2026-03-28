from contextlib import asynccontextmanager
from pathlib import Path

import httpx
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, users, loyalty, products, orders, cart, favorites, chat, locations, promo_codes
from app.routers.admin import (
    products as admin_products,
    orders as admin_orders,
    users as admin_users,
    categories as admin_categories,
    promo_codes as admin_promo_codes,
    locations as admin_locations,
    dashboard as admin_dashboard,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure upload dirs exist
    for sub in ("payment-proofs", "product-images", "avatars"):
        Path(settings.UPLOAD_DIR, sub).mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(title="TOOLOR API", version="1.0.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for uploads
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

# Admin routers
app.include_router(admin_dashboard.router, prefix="/api/v1/admin", tags=["admin"])
app.include_router(admin_products.router, prefix="/api/v1/admin/products", tags=["admin-products"])
app.include_router(admin_orders.router, prefix="/api/v1/admin/orders", tags=["admin-orders"])
app.include_router(admin_users.router, prefix="/api/v1/admin/users", tags=["admin-users"])
app.include_router(admin_categories.router, prefix="/api/v1/admin/categories", tags=["admin-categories"])
app.include_router(admin_promo_codes.router, prefix="/api/v1/admin/promo-codes", tags=["admin-promo-codes"])
app.include_router(admin_locations.router, prefix="/api/v1/admin/locations", tags=["admin-locations"])


@app.get("/api/v1/health")
async def health():
    return {"status": "ok"}


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
