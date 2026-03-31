import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.dependencies import get_db
from app.models.loyalty import LoyaltyAccount
from app.models.user import Profile
from app.schemas.auth import (
    AppleAuthRequest,
    GoogleAuthRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services.auth_service import (
    create_access_token,
    create_oauth_user_with_loyalty,
    create_refresh_token,
    create_user_with_loyalty,
    verify_apple_identity_token,
    verify_google_id_token,
    verify_password,
    verify_token,
)
from app.services.loyalty_service import check_birthday_reward
from app.services.analytics_service import track_signup, track_login
from app.services.event_logger import log_event

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(Profile).where(Profile.phone == body.phone))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")

    referred_by = None
    if body.referral_code:
        ref_result = await db.execute(
            select(Profile).where(Profile.referral_code == body.referral_code)
        )
        referrer = ref_result.scalar_one_or_none()
        if referrer:
            referred_by = referrer.id

    user = await create_user_with_loyalty(
        db, body.phone, body.password, body.full_name, referred_by
    )
    await log_event(db, user.id, "signup", {"method": "phone"})
    await db.commit()
    track_signup(str(user.id), body.phone, body.referral_code)
    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Profile).where(Profile.phone == body.phone))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid phone or password")

    # Check birthday reward on login
    if user.birth_date:
        loyalty_result = await db.execute(
            select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
        )
        loyalty = loyalty_result.scalar_one_or_none()
        if loyalty:
            await check_birthday_reward(db, user, loyalty)
            await db.commit()

    await log_event(db, user.id, "login", {"method": "phone"})
    await db.commit()
    track_login(str(user.id))
    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.post("/apple", response_model=TokenResponse)
async def apple_auth(body: AppleAuthRequest, db: AsyncSession = Depends(get_db)):
    try:
        claims = await verify_apple_identity_token(body.identity_token)
    except Exception as e:
        logger.warning("Apple token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid Apple identity token")

    apple_sub = claims["sub"]
    email = claims.get("email")

    try:
        # Check if user already exists by apple_id
        result = await db.execute(select(Profile).where(Profile.apple_id == apple_sub))
        user = result.scalar_one_or_none()

        if not user and email:
            # Check if user exists by email — link accounts
            result = await db.execute(select(Profile).where(Profile.email == email))
            user = result.scalar_one_or_none()
            if user:
                user.apple_id = apple_sub
                await db.flush()

        if not user:
            # New user
            full_name = body.full_name or email or ""
            user = await create_oauth_user_with_loyalty(
                db, full_name=full_name, email=email, apple_id=apple_sub,
            )
            await log_event(db, user.id, "signup", {"method": "apple"})
            try:
                track_signup(str(user.id), email or "", None)
            except Exception:
                pass

        await log_event(db, user.id, "login", {"method": "apple"})
        await db.commit()
        try:
            track_login(str(user.id))
        except Exception:
            pass
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Apple auth DB error: %s", e)
        raise HTTPException(status_code=500, detail=f"Server error: {e}")

    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.post("/google", response_model=TokenResponse)
async def google_auth(body: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    import asyncio
    try:
        loop = asyncio.get_event_loop()
        claims = await loop.run_in_executor(None, verify_google_id_token, body.id_token)
    except Exception as e:
        logger.warning("Google token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid Google ID token")

    google_sub = claims["sub"]
    email = claims.get("email")
    name = claims.get("name", "")

    try:
        # Check if user already exists by google_id
        result = await db.execute(select(Profile).where(Profile.google_id == google_sub))
        user = result.scalar_one_or_none()

        if not user and email:
            # Check if user exists by email — link accounts
            result = await db.execute(select(Profile).where(Profile.email == email))
            user = result.scalar_one_or_none()
            if user:
                user.google_id = google_sub
                await db.flush()

        if not user:
            # New user
            user = await create_oauth_user_with_loyalty(
                db, full_name=name, email=email, google_id=google_sub,
            )
            await log_event(db, user.id, "signup", {"method": "google"})
            try:
                track_signup(str(user.id), email or "", None)
            except Exception:
                pass

        await log_event(db, user.id, "login", {"method": "google"})
        await db.commit()
        try:
            track_login(str(user.id))
        except Exception:
            pass
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Google auth DB error: %s", e)
        raise HTTPException(status_code=500, detail=f"Server error: {e}")

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
