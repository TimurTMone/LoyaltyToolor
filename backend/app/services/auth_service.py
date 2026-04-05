import uuid
import random
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.loyalty import LoyaltyAccount
from app.models.user import Profile

OTP_LENGTH = 4
OTP_TTL_SECONDS = 300  # 5 minutes
MAX_VERIFY_ATTEMPTS = 5


async def generate_otp(db: AsyncSession, phone: str) -> str:
    """Generate a random OTP code, store it in DB (upsert), and return it."""
    code = "".join([str(random.randint(0, 9)) for _ in range(OTP_LENGTH)])
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=OTP_TTL_SECONDS)

    await db.execute(
        text("""INSERT INTO otp_codes (phone, code, expires_at, attempts)
                VALUES (:phone, :code, :expires_at, 0)
                ON CONFLICT (phone) DO UPDATE SET
                    code = EXCLUDED.code,
                    expires_at = EXCLUDED.expires_at,
                    attempts = 0,
                    created_at = NOW()"""),
        {"phone": phone, "code": code, "expires_at": expires_at},
    )
    await db.commit()
    return code


async def verify_otp(db: AsyncSession, phone: str, code: str) -> bool:
    """Verify an OTP code. Rate-limits attempts per phone."""
    result = await db.execute(
        text("SELECT code, expires_at, attempts FROM otp_codes WHERE phone = :phone"),
        {"phone": phone},
    )
    row = result.fetchone()
    if not row:
        return False

    stored_code, expires_at, attempts = row

    # Too many failed attempts — invalidate
    if attempts >= MAX_VERIFY_ATTEMPTS:
        await db.execute(text("DELETE FROM otp_codes WHERE phone = :phone"), {"phone": phone})
        await db.commit()
        return False

    # Expired
    if datetime.now(timezone.utc) > expires_at:
        await db.execute(text("DELETE FROM otp_codes WHERE phone = :phone"), {"phone": phone})
        await db.commit()
        return False

    # Wrong code — increment attempts
    if stored_code != code:
        await db.execute(
            text("UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = :phone"),
            {"phone": phone},
        )
        await db.commit()
        return False

    # Correct — single-use, delete
    await db.execute(text("DELETE FROM otp_codes WHERE phone = :phone"), {"phone": phone})
    await db.commit()
    return True


def create_token(data: dict, expires_delta: timedelta) -> str:
    to_encode = data.copy()
    to_encode["exp"] = datetime.now(timezone.utc) + expires_delta
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_access_token(user: Profile) -> str:
    return create_token(
        {"sub": str(user.id), "is_admin": user.is_admin},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )


def create_refresh_token(user: Profile) -> str:
    return create_token(
        {"sub": str(user.id), "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def verify_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return None


async def create_user_with_loyalty(
    db: AsyncSession,
    phone: str,
) -> Profile:
    """Create a new user (phone-only, no password) with a loyalty account."""
    user_id = uuid.uuid4()
    ref_code = f"TOOLOR-{str(user_id)[:8].upper()}"
    qr_code = f"TOOLOR-{str(user_id).replace('-', '')[:12].upper()}"

    user = Profile(
        id=user_id,
        phone=phone,
        password_hash="",
        full_name="",
        referral_code=ref_code,
    )
    db.add(user)

    loyalty = LoyaltyAccount(
        user_id=user_id,
        qr_code=qr_code,
        tier="kulun",
        points=0,
        total_spent=0,
    )
    db.add(loyalty)

    await db.flush()
    return user
