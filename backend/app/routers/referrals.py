from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.notification import Notification
from app.models.referral import Referral
from app.models.user import Profile
from app.schemas.referral import (
    ApplyReferralRequest,
    ReferralCodeOut,
    ReferralListOut,
    ReferredUserOut,
)

router = APIRouter()

REFERRAL_BONUS_POINTS = 500


@router.get("/my-code", response_model=ReferralCodeOut)
async def get_my_referral_code(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Count total referrals
    count_q = select(func.count()).select_from(
        select(Referral).where(Referral.referrer_id == user.id).subquery()
    )
    total_referrals = (await db.execute(count_q)).scalar() or 0

    # Sum total points earned from referrals
    points_q = select(func.coalesce(func.sum(Referral.referrer_points), 0)).where(
        Referral.referrer_id == user.id
    )
    total_points = (await db.execute(points_q)).scalar() or 0

    return ReferralCodeOut(
        referral_code=user.referral_code or "",
        total_referrals=total_referrals,
        total_points_earned=total_points,
    )


@router.get("/my-referrals", response_model=ReferralListOut)
async def get_my_referrals(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Referral, Profile)
        .join(Profile, Referral.referred_id == Profile.id)
        .where(Referral.referrer_id == user.id)
        .order_by(Referral.created_at.desc())
    )
    rows = result.all()

    referrals = []
    for ref, profile in rows:
        referrals.append(
            ReferredUserOut(
                id=profile.id,
                full_name=profile.full_name,
                points_awarded=ref.referrer_points,
                created_at=ref.created_at,
            )
        )

    return ReferralListOut(referrals=referrals, total=len(referrals))


@router.post("/apply")
async def apply_referral_code(
    body: ApplyReferralRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Check if user has already been referred
    if user.referred_by is not None:
        raise HTTPException(status_code=400, detail="Вы уже использовали реферальный код")

    # Can't refer yourself
    if user.referral_code == body.referral_code:
        raise HTTPException(status_code=400, detail="Нельзя использовать свой собственный код")

    # Find the referrer
    result = await db.execute(
        select(Profile).where(Profile.referral_code == body.referral_code)
    )
    referrer = result.scalar_one_or_none()
    if not referrer:
        raise HTTPException(status_code=404, detail="Реферальный код не найден")

    # Check if referral already exists
    existing = await db.execute(
        select(Referral).where(Referral.referred_id == user.id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Вы уже использовали реферальный код")

    # Update user's referred_by
    user.referred_by = referrer.id

    # Create referral record
    referral = Referral(
        referrer_id=referrer.id,
        referred_id=user.id,
        bonus_awarded=True,
        referrer_points=REFERRAL_BONUS_POINTS,
        referred_points=REFERRAL_BONUS_POINTS,
    )
    db.add(referral)

    # Award points to referrer
    referrer_loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == referrer.id)
    )
    referrer_loyalty = referrer_loyalty_result.scalar_one_or_none()
    if referrer_loyalty:
        referrer_loyalty.points += REFERRAL_BONUS_POINTS
        txn_referrer = LoyaltyTransaction(
            loyalty_id=referrer_loyalty.id,
            user_id=referrer.id,
            type="referral_bonus",
            amount=0,
            points_change=REFERRAL_BONUS_POINTS,
            description=f"Бонус за приглашение друга ({user.full_name or user.phone})",
        )
        db.add(txn_referrer)

    # Award points to referred user
    user_loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    user_loyalty = user_loyalty_result.scalar_one_or_none()
    if user_loyalty:
        user_loyalty.points += REFERRAL_BONUS_POINTS
        txn_referred = LoyaltyTransaction(
            loyalty_id=user_loyalty.id,
            user_id=user.id,
            type="referral_bonus",
            amount=0,
            points_change=REFERRAL_BONUS_POINTS,
            description=f"Бонус за использование реферального кода",
        )
        db.add(txn_referred)

    # Notifications
    notif_referrer = Notification(
        user_id=referrer.id,
        type="referral",
        title="Новый реферал!",
        body=f"{user.full_name or user.phone} присоединился по вашей ссылке. +{REFERRAL_BONUS_POINTS} баллов!",
    )
    db.add(notif_referrer)

    notif_referred = Notification(
        user_id=user.id,
        type="referral",
        title="Реферальный бонус!",
        body=f"Вы получили {REFERRAL_BONUS_POINTS} баллов за использование реферального кода!",
    )
    db.add(notif_referred)

    await db.commit()
    return {
        "status": "ok",
        "points_awarded": REFERRAL_BONUS_POINTS,
        "message": f"Вы получили {REFERRAL_BONUS_POINTS} бонусных баллов!",
    }
