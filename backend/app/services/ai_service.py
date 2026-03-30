"""TOOLOR AI assistant powered by Claude API.

Handles product recommendations, size help, order tracking, and loyalty info
in natural language — in Russian.
"""

import json
import logging
import uuid

import anthropic
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.loyalty import LoyaltyAccount
from app.models.order import Order
from app.models.product import Product, Category, Subcategory
from app.models.chat import ChatMessage

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Ты — AI-стилист бренда TOOLOR, магазина функциональной верхней одежды в Бишкеке (Кыргызстан).
Бутик находится в AsiaMall, 2 этаж, бутик 19(1).

Твои задачи:
1. Рекомендовать товары из каталога TOOLOR (куртки, худи, брюки, аксессуары)
2. Помогать с подбором размера (S/M/L/XL/XXL)
3. Отвечать про заказы — статус, доставку, примерку дома
4. Объяснять программу лояльности (бронза 3%, серебро 5%, золото 8%, платина 12% кэшбэк)
5. Составлять образы по стилю (городской, outdoor, деловой, casual)

Правила:
- Отвечай на русском языке, дружелюбно и кратко (2-4 предложения)
- Используй эмодзи уместно
- Валюта: сом (KGS)
- Если нужно порекомендовать товары, верни их ID в формате JSON-блока: ```products["id1","id2"]```
- Максимум 4 товара за раз
- Не выдумывай товары — используй только те, что есть в контексте
- Если клиент спрашивает про товар которого нет, честно скажи что не нашёл, предложи альтернативу
- Для размеров: рост <170 → S, 170-178 → M, 178-185 → L, 185-190 → XL, >190 → XXL (±1 размер от веса)"""


_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        if not settings.ANTHROPIC_API_KEY:
            raise RuntimeError("ANTHROPIC_API_KEY not configured")
        _client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


async def _build_user_context(db: AsyncSession, user_id: uuid.UUID) -> str:
    """Build a context string with user's loyalty info and recent orders."""
    parts: list[str] = []

    # Loyalty
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
    )
    loyalty = result.scalar_one_or_none()
    if loyalty:
        tier_names = {"bronze": "Бронза", "silver": "Серебро", "gold": "Золото", "platinum": "Платина"}
        cashback = {"bronze": 3, "silver": 5, "gold": 8, "platinum": 12}
        parts.append(
            f"Клиент: уровень {tier_names.get(loyalty.tier, loyalty.tier)}, "
            f"{loyalty.points} баллов, потрачено {loyalty.total_spent} сом, "
            f"кэшбэк {cashback.get(loyalty.tier, 3)}%"
        )

    # Recent orders (last 5)
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.user_id == user_id)
        .order_by(Order.created_at.desc())
        .limit(5)
    )
    orders = result.scalars().all()
    if orders:
        status_names = {
            "pending": "ожидает",
            "payment_confirmed": "оплачен",
            "processing": "собирается",
            "ready_for_pickup": "готов к выдаче",
            "shipped": "отправлен",
            "delivered": "доставлен",
            "cancelled": "отменён",
        }
        order_lines = []
        for o in orders:
            items_str = ", ".join(f"{i.product_name} ({i.selected_size or '?'})" for i in o.items)
            order_lines.append(
                f"  #{o.order_number} — {status_names.get(o.status, o.status)} — {o.total} сом — [{items_str}]"
            )
        parts.append("Последние заказы:\n" + "\n".join(order_lines))

    return "\n\n".join(parts) if parts else "Новый клиент, заказов пока нет."


async def _build_product_context(db: AsyncSession, user_message: str) -> str:
    """Fetch relevant products based on user message keywords."""
    # Fetch on-sale + featured products as base context
    base_q = (
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.is_active == True)
    )

    # Search for products matching user's query
    search_terms = [w for w in user_message.lower().split() if len(w) > 2]
    search_q = base_q
    if search_terms:
        conditions = []
        for term in search_terms[:5]:
            conditions.append(Product.name.ilike(f"%{term}%"))
            conditions.append(Product.description.ilike(f"%{term}%"))
        search_q = base_q.where(or_(*conditions)).limit(8)

    result = await db.execute(search_q)
    products = list(result.scalars().all())

    # Also include featured + on-sale items if we have fewer than 8
    if len(products) < 8:
        featured_q = base_q.where(
            or_(Product.is_featured == True, Product.original_price.isnot(None))
        ).limit(8 - len(products))
        result = await db.execute(featured_q)
        existing_ids = {p.id for p in products}
        for p in result.scalars().all():
            if p.id not in existing_ids:
                products.append(p)

    if not products:
        return "Каталог пуст."

    lines = []
    for p in products[:12]:
        sale = ""
        if p.original_price and p.original_price > p.price:
            discount = int((1 - float(p.price) / float(p.original_price)) * 100)
            sale = f" (СКИДКА -{discount}%, было {p.original_price} сом)"
        sizes = ", ".join(p.sizes) if p.sizes else "нет данных"
        cat = p.category.name if p.category else ""
        subcat = p.subcategory.name if p.subcategory else ""
        lines.append(
            f"- ID:{p.id} | {p.name} | {p.price} сом{sale} | {cat}/{subcat} | Размеры: {sizes}"
        )

    return "Доступные товары:\n" + "\n".join(lines)


async def _get_conversation_history(db: AsyncSession, session_id: uuid.UUID, limit: int = 20) -> list[dict]:
    """Load recent messages for conversation context."""
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit)
    )
    messages = list(reversed(result.scalars().all()))
    return [{"role": m.role, "content": m.content} for m in messages]


def _extract_product_ids(text: str) -> list[str]:
    """Extract product IDs from Claude's response ```products[...]``` block."""
    import re
    match = re.search(r'```products\s*\[([^\]]*)\]```', text)
    if not match:
        return []
    raw = match.group(1)
    ids = re.findall(r'"([^"]+)"', raw)
    return ids


def _clean_response(text: str) -> str:
    """Remove the products JSON block from the visible response text."""
    import re
    return re.sub(r'\s*```products\s*\[[^\]]*\]```\s*', '', text).strip()


async def generate_ai_reply(
    db: AsyncSession,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
    user_message: str,
) -> tuple[str, list[dict]]:
    """Generate an AI reply using Claude API.

    Returns (reply_text, product_list) where product_list contains
    product dicts with id, name, price, image_url etc.
    """
    # Build context
    user_context = await _build_user_context(db, user_id)
    product_context = await _build_product_context(db, user_message)
    history = await _get_conversation_history(db, session_id)

    # Build messages for Claude
    context_block = f"--- КОНТЕКСТ КЛИЕНТА ---\n{user_context}\n\n--- КАТАЛОГ ---\n{product_context}"

    messages = []
    # Add history (skip the system-injected context messages)
    for msg in history:
        messages.append({"role": msg["role"], "content": msg["content"]})

    # Add current user message with context
    messages.append({
        "role": "user",
        "content": f"{context_block}\n\n--- СООБЩЕНИЕ КЛИЕНТА ---\n{user_message}",
    })

    try:
        client = _get_client()
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=messages,
        )
        reply_text = response.content[0].text
    except Exception as e:
        logger.error(f"Claude API error: {e}")
        # Graceful fallback
        return (
            "Извините, сейчас я не могу ответить. Попробуйте позже! 🔄",
            [],
        )

    # Extract product recommendations
    product_ids = _extract_product_ids(reply_text)
    clean_text = _clean_response(reply_text)

    products_data: list[dict] = []
    if product_ids:
        try:
            uuids = [uuid.UUID(pid) for pid in product_ids]
            result = await db.execute(
                select(Product)
                .options(selectinload(Product.category), selectinload(Product.subcategory))
                .where(Product.id.in_(uuids), Product.is_active == True)
            )
            for p in result.scalars().all():
                products_data.append({
                    "id": str(p.id),
                    "name": p.name,
                    "price": float(p.price),
                    "original_price": float(p.original_price) if p.original_price else None,
                    "image_url": p.image_url,
                    "sizes": p.sizes,
                    "category": p.category.name if p.category else "",
                    "subcategory": p.subcategory.name if p.subcategory else "",
                })
        except (ValueError, Exception) as e:
            logger.warning(f"Failed to fetch recommended products: {e}")

    return clean_text, products_data
