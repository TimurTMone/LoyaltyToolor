import hashlib
import hmac
import math
import secrets
import time

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import get_current_user, get_db, require_admin
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.user import Profile
from app.schemas.loyalty import (
    LoyaltyAccountOut,
    LoyaltyTransactionOut,
    QrScanRequest,
    QrScanResponse,
    QrScanCustomer,
)

router = APIRouter()


@router.get("/me", response_model=LoyaltyAccountOut)
async def get_my_loyalty(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    loyalty = result.scalar_one_or_none()
    if not loyalty:
        raise HTTPException(status_code=404, detail="Loyalty account not found")
    return LoyaltyAccountOut.model_validate(loyalty)


@router.get("/me/transactions", response_model=dict)
async def get_my_transactions(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base = select(LoyaltyTransaction).where(LoyaltyTransaction.user_id == user.id)
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = base.order_by(LoyaltyTransaction.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    items = result.scalars().all()

    return {
        "items": [LoyaltyTransactionOut.model_validate(t) for t in items],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


TIER_CASHBACK = {"bronze": 3, "silver": 5, "gold": 8, "platinum": 12}


def _sign_qr(payload: str) -> str:
    return hmac.new(
        settings.QR_SECRET.encode(), payload.encode(), hashlib.sha256
    ).hexdigest()[:16]


@router.get("/me/qr")
async def generate_qr_token(user: Profile = Depends(get_current_user)):
    ts = int(time.time())
    nonce = secrets.token_hex(4)
    payload = f"{user.id}.{ts}.{nonce}"
    sig = _sign_qr(payload)
    return {"qr_token": f"{payload}.{sig}", "expires_in": 30}


@router.post("/scan", response_model=QrScanResponse)
async def scan_qr_token(
    body: QrScanRequest,
    admin: Profile = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    parts = body.qr_token.split(".")
    if len(parts) != 4:
        return QrScanResponse(valid=False, reason="invalid_format")

    user_id, ts_str, nonce, signature = parts

    # Verify signature
    payload = f"{user_id}.{ts_str}.{nonce}"
    expected_sig = _sign_qr(payload)
    if not hmac.compare_digest(signature, expected_sig):
        return QrScanResponse(valid=False, reason="invalid_signature")

    # Verify expiry (60-second window for some slack)
    try:
        ts = int(ts_str)
    except ValueError:
        return QrScanResponse(valid=False, reason="invalid_format")

    if abs(time.time() - ts) > 60:
        return QrScanResponse(valid=False, reason="expired")

    # Look up user
    user = await db.get(Profile, user_id)
    if not user:
        return QrScanResponse(valid=False, reason="user_not_found")

    # Look up loyalty account
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    loyalty = result.scalar_one_or_none()
    if not loyalty:
        return QrScanResponse(valid=False, reason="user_not_found")

    cashback = TIER_CASHBACK.get(loyalty.tier, 3)

    return QrScanResponse(
        valid=True,
        customer=QrScanCustomer(
            name=user.full_name,
            phone=user.phone,
            tier=loyalty.tier,
            points=loyalty.points,
            total_spent=loyalty.total_spent,
            cashback_percent=cashback,
        ),
    )
