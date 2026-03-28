import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.chat import ChatMessage, ChatSession
from app.models.user import Profile
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatSessionOut

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
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await _get_user_session(db, session_id, user.id)

    # Save user message
    user_msg = ChatMessage(
        session_id=session.id,
        role="user",
        content=body.content,
    )
    db.add(user_msg)

    # Generate rule-based response (MVP — replace with LLM later)
    reply_text, products = _generate_reply(body.content)
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


def _generate_reply(content: str) -> tuple[str, list]:
    """Rule-based chatbot (MVP). Replace with Claude API integration later."""
    text = content.lower()
    if any(w in text for w in ["скидк", "sale", "акци"]):
        return (
            "У нас сейчас есть отличные скидки в разделе 'Скидки'! "
            "Загляните в каталог — там можно найти куртки, худи и другие вещи со скидкой до 50%.",
            [],
        )
    if any(w in text for w in ["балл", "бонус", "кэшбэк", "лояльност"]):
        return (
            "Система лояльности TOOLOR:\n"
            "• Бронза — кэшбэк 3%\n"
            "• Серебро (от 50 000 сом) — кэшбэк 5%\n"
            "• Золото (от 150 000 сом) — кэшбэк 8%\n"
            "• Платина (от 300 000 сом) — кэшбэк 12%\n\n"
            "Баллы можно использовать при следующей покупке!",
            [],
        )
    if any(w in text for w in ["размер", "size", "подобрать"]):
        return (
            "Для подбора размера рекомендую свериться с размерной сеткой на странице товара. "
            "Если сомневаетесь — выберите услугу 'Примерка дома' при оформлении заказа!",
            [],
        )
    if any(w in text for w in ["образ", "стиль", "look", "outfit"]):
        return (
            "Могу помочь собрать образ! Расскажите, для какого случая ищете одежду — "
            "повседневный стиль, офис или спорт?",
            [],
        )
    return (
        "Привет! Я стилист TOOLOR. Могу помочь с:\n"
        "• Подбором размера\n"
        "• Составлением образа\n"
        "• Информацией о скидках\n"
        "• Программой лояльности\n\n"
        "Что вас интересует?",
        [],
    )
