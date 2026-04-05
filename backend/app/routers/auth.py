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
    LoginRequest,
    RefreshRequest,
    SendOtpRequest,
    SendOtpResponse,
    TokenResponse,
    VerifyOtpRequest,
)
import bcrypt
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
from app.services.sms_service import send_otp_sms, is_sms_configured

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

    code = await generate_otp(db, phone)

    # Send SMS if a provider is configured
    sms_sent = await send_otp_sms(phone, code)
    if not sms_sent and is_sms_configured():
        raise HTTPException(status_code=502, detail="Failed to send SMS. Please try again.")

    # In dev mode (no SMS provider), return code in response for testing
    # In prod with real SMS, return empty string so code isn't leaked via API
    response_code = code if not is_sms_configured() else ""
    return SendOtpResponse(otp_code=response_code)


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp_endpoint(body: VerifyOtpRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Verify OTP and return tokens. Creates account if user is new."""
    ip = get_client_ip(request)
    auth_limiter.check(ip)

    phone = body.phone.strip()

    if not await verify_otp(db, phone, body.otp_code):
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


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Phone + password login. Used by the admin panel."""
    ip = get_client_ip(request)
    auth_limiter.check(ip)

    phone = body.phone.strip()
    result = await db.execute(select(Profile).where(Profile.phone == phone))
    user = result.scalar_one_or_none()
    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not bcrypt.checkpw(body.password.encode(), user.password_hash.encode()):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    await log_event(db, user.id, "login", {"method": "password"})
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
