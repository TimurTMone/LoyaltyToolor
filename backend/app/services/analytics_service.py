"""Analytics service — Mixpanel event tracking for TOOLOR.

Tracks key business events: purchases, signups, chat usage, product views.
Non-blocking: errors are logged but never bubble up to the user.
"""

import logging
from datetime import datetime
from typing import Any

from app.config import settings

logger = logging.getLogger(__name__)

_mp = None


def _get_mp():
    global _mp
    if _mp is None:
        if not settings.MIXPANEL_TOKEN:
            return None
        from mixpanel import Mixpanel
        _mp = Mixpanel(settings.MIXPANEL_TOKEN)
    return _mp


def track(user_id: str, event: str, properties: dict[str, Any] | None = None):
    """Track an event in Mixpanel. Non-blocking, never raises."""
    try:
        mp = _get_mp()
        if mp is None:
            return
        props = properties or {}
        props["time"] = int(datetime.utcnow().timestamp())
        mp.track(user_id, event, props)
    except Exception as e:
        logger.warning(f"Mixpanel track error: {e}")


def set_user(user_id: str, properties: dict[str, Any]):
    """Set user profile properties in Mixpanel."""
    try:
        mp = _get_mp()
        if mp is None:
            return
        mp.people_set(user_id, properties)
    except Exception as e:
        logger.warning(f"Mixpanel people_set error: {e}")


# ── Convenience wrappers for common events ───────────────────────────────

def track_signup(user_id: str, phone: str, referral_code: str | None = None):
    track(user_id, "signup", {"phone": phone, "referral_code": referral_code})
    set_user(user_id, {
        "$phone": phone,
        "$created": datetime.utcnow().isoformat(),
        "tier": "bronze",
        "points": 0,
    })


def track_login(user_id: str):
    track(user_id, "login")


def track_purchase(user_id: str, order_id: str, total: float, items_count: int,
                   payment_method: str, points_used: int = 0):
    track(user_id, "purchase", {
        "order_id": order_id,
        "total": total,
        "items_count": items_count,
        "payment_method": payment_method,
        "points_used": points_used,
        "currency": "KGS",
    })


def track_chat_message(user_id: str, session_id: str, is_ai: bool = False):
    track(user_id, "chat_message", {
        "session_id": session_id,
        "is_ai_response": is_ai,
    })


def track_product_view(user_id: str, product_id: str, product_name: str, price: float):
    track(user_id, "product_view", {
        "product_id": product_id,
        "product_name": product_name,
        "price": price,
    })


def track_add_to_cart(user_id: str, product_id: str, product_name: str, price: float):
    track(user_id, "add_to_cart", {
        "product_id": product_id,
        "product_name": product_name,
        "price": price,
    })


def track_tier_upgrade(user_id: str, old_tier: str, new_tier: str):
    track(user_id, "tier_upgrade", {"old_tier": old_tier, "new_tier": new_tier})
    set_user(user_id, {"tier": new_tier})
