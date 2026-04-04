import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.dependencies import get_db
from app.middleware.rate_limit import otp_limiter, auth_limiter, get_client_ip
from app.models.loyalty import LoyaltyAccount
from app.models.user import Profile
from app.schemas.auth import (
    RefreshRequest,
    SendOtpRequest,
    SendOtpResponse,
    TokenResponse,
    VerifyOtpRequest,
)
from app.services.auth_service import (
    create_access_token,
    create_refresh_token,
    create_user_with_loyalty,
    generate_otp,
    verify_otp,
    verify_token,
)
from app.services.loyalty_service import check_birthday_reward
from app.services.analytics_service import track_signup, track_login
from app.services.event_logger import log_event

router = APIRouter()


@router.post("/send-otp", response_model=SendOtpResponse)
async def send_otp(body: SendOtpRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Send OTP to phone number. For now returns OTP in response for dev/testing."""
    ip = get_client_ip(request)
    otp_limiter.check(ip)

    phone = body.phone.strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone number is required")

    import re
    if not re.match(r'^\+996\d{9}$', phone):
        raise HTTPException(status_code=400, detail="Invalid phone format. Use +996XXXXXXXXX")

    code = generate_otp(phone)

    # TODO: Send real SMS via provider here
    # await sms_service.send(phone, f"Your TOOLOR code: {code}")

    return SendOtpResponse(otp_code=code)


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp_endpoint(body: VerifyOtpRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Verify OTP and return tokens. Creates account if user is new."""
    ip = get_client_ip(request)
    auth_limiter.check(ip)

    phone = body.phone.strip()

    if not verify_otp(phone, body.otp_code):
        raise HTTPException(status_code=401, detail="Invalid or expired OTP code")

    # Find or create user
    result = await db.execute(select(Profile).where(Profile.phone == phone))
    user = result.scalar_one_or_none()

    is_new = user is None
    if is_new:
        user = await create_user_with_loyalty(db, phone)
        await log_event(db, user.id, "signup", {"method": "phone_otp"})
        await db.commit()
        track_signup(str(user.id), phone, None)
    else:
        # Check birthday reward on login
        if user.birth_date:
            loyalty_result = await db.execute(
                select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
            )
            loyalty = loyalty_result.scalar_one_or_none()
            if loyalty:
                await check_birthday_reward(db, user, loyalty)

        await log_event(db, user.id, "login", {"method": "phone_otp"})
        await db.commit()
        track_login(str(user.id))

    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = verify_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = await db.get(Profile, payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )
