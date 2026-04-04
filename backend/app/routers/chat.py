import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import get_current_user, get_db
from app.middleware.rate_limit import chat_limiter, get_client_ip
from app.models.chat import ChatMessage, ChatSession
from app.models.user import Profile
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatSessionOut
from app.services.ai_service import generate_ai_reply
from app.services.analytics_service import track_chat_message

router = APIRouter()


@router.get("/sessions", response_model=list[ChatSessionOut])
async def list_sessions(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == user.id)
        .order_by(ChatSession.updated_at.desc())
    )
    return [ChatSessionOut.model_validate(s) for s in result.scalars().all()]


@router.post("/sessions", response_model=ChatSessionOut, status_code=201)
async def create_session(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = ChatSession(user_id=user.id, title="Новый чат")
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return ChatSessionOut.model_validate(session)


@router.get("/sessions/{session_id}/messages", response_model=list[ChatMessageOut])
async def get_messages(
    session_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await _get_user_session(db, session_id, user.id)
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session.id)
        .order_by(ChatMessage.created_at)
    )
    return [ChatMessageOut.model_validate(m) for m in result.scalars().all()]


@router.post("/sessions/{session_id}/messages", response_model=list[ChatMessageOut])
async def send_message(
    session_id: uuid.UUID,
    body: ChatMessageCreate,
    request: Request,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    chat_limiter.check(get_client_ip(request))
    session = await _get_user_session(db, session_id, user.id)

    # Save user message
    user_msg = ChatMessage(
        session_id=session.id,
        role="user",
        content=body.content,
    )
    db.add(user_msg)

    # Generate AI response via Claude API (falls back to simple reply if key not set)
    if settings.ANTHROPIC_API_KEY:
        reply_text, products = await generate_ai_reply(
            db=db,
            user_id=user.id,
            session_id=session.id,
            user_message=body.content,
        )
    else:
        reply_text, products = _generate_fallback_reply(body.content)

    assistant_msg = ChatMessage(
        session_id=session.id,
        role="assistant",
        content=reply_text,
        products=products,
    )
    db.add(assistant_msg)

    await db.commit()
    await db.refresh(user_msg)
    await db.refresh(assistant_msg)

    track_chat_message(str(user.id), str(session.id), is_ai=False)
    track_chat_message(str(user.id), str(session.id), is_ai=True)

    return [
        ChatMessageOut.model_validate(user_msg),
        ChatMessageOut.model_validate(assistant_msg),
    ]


async def _get_user_session(db: AsyncSession, session_id: uuid.UUID, user_id: uuid.UUID) -> ChatSession:
    result = await db.execute(
        select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == user_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    return session


def _generate_fallback_reply(content: str) -> tuple[str, list]:
    """Simple fallback when ANTHROPIC_API_KEY is not configured."""
    text = content.lower()
    if any(w in text for w in ["скидк", "sale", "акци"]):
        return (
            "У нас сейчас есть отличные скидки! Загляните в каталог — скидки до 50%. 🔥",
            [],
        )
    if any(w in text for w in ["балл", "бонус", "кэшбэк", "лояльност"]):
        return (
            "Система лояльности TOOLOR:\n"
            "• Бронза — 3% кэшбэк\n• Серебро (от 50К) — 5%\n"
            "• Золото (от 150К) — 8%\n• Платина (от 300К) — 12%",
            [],
        )
    if any(w in text for w in ["размер", "size"]):
        return ("Для подбора размера назовите рост и вес — я подскажу! 📏", [])
    return (
        "Привет! Я стилист TOOLOR. Помогу с подбором одежды, размерами, акциями и бонусами. Что интересует? 😊",
        [],
    )
