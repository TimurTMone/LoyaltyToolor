import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.loyalty import LoyaltyAccount
from app.models.user import Profile


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


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
    password: str,
    full_name: str = "",
    referred_by: uuid.UUID | None = None,
) -> Profile:
    user_id = uuid.uuid4()
    ref_code = f"TOOLOR-{str(user_id)[:8].upper()}"
    qr_code = f"TOOLOR-{str(user_id).replace('-', '')[:12].upper()}"

    user = Profile(
        id=user_id,
        phone=phone,
        password_hash=hash_password(password),
        full_name=full_name,
        referral_code=ref_code,
        referred_by=referred_by,
    )
    db.add(user)

    loyalty = LoyaltyAccount(
        user_id=user_id,
        qr_code=qr_code,
        tier="bronze",
        points=0,
        total_spent=0,
    )
    db.add(loyalty)

    await db.flush()
    return user
