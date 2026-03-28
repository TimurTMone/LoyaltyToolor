import hashlib
import hmac
import math
import secrets
import time
from decimal import Decimal

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
    MilestonesOut,
    QrScanRequest,
    QrScanResponse,
    QrScanCustomer,
)
from app.services.loyalty_service import get_next_tier, TIER_ORDER

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


@router.get("/me/milestones", response_model=MilestonesOut)
async def get_my_milestones(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    loyalty = result.scalar_one_or_none()
    if not loyalty:
        raise HTTPException(status_code=404, detail="Loyalty account not found")

    next_tier, next_threshold = get_next_tier(loyalty.tier)
    current_spent = float(loyalty.total_spent)

    if next_tier and next_threshold:
        remaining = float(next_threshold) - current_spent
        # Calculate progress within current tier range
        current_tier_idx = TIER_ORDER.index(loyalty.tier)
        if current_tier_idx == 0:
            current_threshold = 0.0
        else:
            from app.services.loyalty_service import TIER_THRESHOLDS
            current_threshold = float(
                next(t for t, tier in TIER_THRESHOLDS if tier == loyalty.tier)
            )
        range_total = float(next_threshold) - current_threshold
        progress = ((current_spent - current_threshold) / range_total * 100) if range_total > 0 else 100.0
    else:
        remaining = 0.0
        progress = 100.0

    return MilestonesOut(
        current_tier=loyalty.tier,
        current_spent=current_spent,
        next_tier=next_tier,
        next_tier_threshold=float(next_threshold) if next_threshold else None,
        remaining=remaining,
        progress_percent=round(progress, 1),
    )
