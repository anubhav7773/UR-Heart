from datetime import date, datetime
from typing import List, Dict, Any, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_

from app.core.database import get_db
from app.core.security import get_current_user_optional
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message

router = APIRouter(prefix="/chat", tags=["1:1 Encrypted Dialogues"])


def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


class SendMessageRequest(BaseModel):
    match_id: Optional[str] = None
    recipient_id: Optional[str] = None
    text: Optional[str] = None
    content: Optional[str] = None


@router.get("/threads", status_code=status.HTTP_200_OK, summary="Get Active Dialogue Threads")
async def get_dialogue_threads(
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Returns active dialogue threads from PostgreSQL matches table."""
    threads = []
    if current_user:
        stmt = (
            select(Match)
            .where(
                or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id),
                Match.is_active == True
            )
            .order_by(Match.matched_at.desc())
        )
        res = await db.execute(stmt)
        matches = res.scalars().all()

        for m in matches:
            partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
            partner_res = await db.execute(select(User).where(User.id == partner_id))
            partner = partner_res.scalar_one_or_none()
            if not partner:
                continue

            msg_stmt = (
                select(Message)
                .where(Message.match_id == m.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            msg_res = await db.execute(msg_stmt)
            last_msg = msg_res.scalar_one_or_none()

            photo = partner.avatar_url or (partner.photos[0] if partner.photos else "")
            last_text = last_msg.encrypted_text if last_msg else "Resonance established. Begin your sacred dialogue."
            last_time = last_msg.created_at.strftime("%I:%M %p") if last_msg else (
                m.matched_at.strftime("%I:%M %p") if m.matched_at else "Recently"
            )
            unread_count = 1 if (last_msg and last_msg.sender_id != current_user.id and last_msg.status != "read") else 0

            threads.append({
                "match_id": str(m.id),
                "peer_id": str(partner.id),
                "peer_name": partner.full_name,
                "peer_age": _calculate_age(partner.dob),
                "peer_photo": photo,
                "is_online": True,
                "last_message": last_text,
                "last_timestamp": last_time,
                "unread_count": unread_count,
                "delivery_status": last_msg.status if last_msg else "delivered"
            })

    print(f"[CHAT THREADS] Serving {len(threads)} live conversation threads from PostgreSQL", flush=True)
    return {"threads": threads, "data": threads}


@router.get("/sparks", status_code=status.HTTP_200_OK, summary="Get Active Exploration Sparks")
async def get_active_sparks(
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Returns active sparks under exploration timer from PostgreSQL."""
    sparks = []
    if current_user:
        stmt = (
            select(Match)
            .where(
                or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id),
                Match.is_active == True
            )
            .order_by(Match.matched_at.desc())
            .limit(10)
        )
        res = await db.execute(stmt)
        matches = res.scalars().all()

        for m in matches:
            partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
            partner_res = await db.execute(select(User).where(User.id == partner_id))
            partner = partner_res.scalar_one_or_none()
            if not partner:
                continue

            photo = partner.avatar_url or (partner.photos[0] if partner.photos else "")
            sparks.append({
                "id": str(m.id),
                "match_id": str(m.id),
                "name": partner.full_name,
                "age": _calculate_age(partner.dob),
                "avatar_url": photo,
                "is_online": True,
                "match_type": "MUTUAL"
            })

    print(f"[CHAT SPARKS] Serving {len(sparks)} live exploration sparks from PostgreSQL", flush=True)
    return {"sparks": sparks, "data": sparks}


@router.get("/messages/{match_id}", status_code=status.HTTP_200_OK, summary="Get Messages for Dialogue")
async def get_dialogue_messages(
    match_id: str,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Returns chronologically ordered messages for match dialogue."""
    messages = []
    try:
        match_uuid = UUID(match_id)
    except ValueError:
        match_uuid = None

    if match_uuid:
        stmt = (
            select(Message)
            .where(Message.match_id == match_uuid)
            .order_by(Message.created_at.asc())
        )
        res = await db.execute(stmt)
        rows = res.scalars().all()

        for msg in rows:
            is_me = (current_user and msg.sender_id == current_user.id)
            messages.append({
                "id": str(msg.id),
                "match_id": match_id,
                "sender_id": str(msg.sender_id),
                "content": msg.encrypted_text,
                "timestamp": msg.created_at.strftime("%I:%M %p") if msg.created_at else "",
                "is_me": is_me,
                "status": msg.status
            })

    print(f"[CHAT MESSAGES] Serving {len(messages)} messages for match_id={match_id}", flush=True)
    return messages


@router.get("/threads/{match_id}/messages", status_code=status.HTTP_200_OK, summary="Get Thread Messages")
async def get_thread_messages(
    match_id: str,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Returns chronologically ordered messages for match dialogue thread."""
    msgs = await get_dialogue_messages(match_id, current_user, db)
    return {"messages": msgs, "data": msgs}


@router.post("/threads/{match_id}/messages", status_code=status.HTTP_201_CREATED, summary="Send Thread Message")
@router.post("/messages", status_code=status.HTTP_201_CREATED, summary="Send Message")
async def send_chat_message(
    payload: SendMessageRequest,
    match_id: Optional[str] = None,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Persists a new message in PostgreSQL messages table."""
    resolved_match_id = match_id or payload.match_id
    text_content = payload.text or payload.content

    if not resolved_match_id or not text_content:
        raise HTTPException(status_code=400, detail="match_id and message text are required.")

    try:
        match_uuid = UUID(resolved_match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID format.")

    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required to send messages.")

    msg = Message(
        match_id=match_uuid,
        sender_id=current_user.id,
        encrypted_text=text_content.strip(),
        status="delivered"
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)

    # Find recipient from match and push notification
    try:
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        m = match_res.scalar_one_or_none()
        if m:
            recipient_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
            from app.api.v1.endpoints.notifications import push_notification
            push_notification(
                user_id=str(recipient_id),
                notif_type="message",
                title=f"Message from {current_user.full_name} 💬",
                body=text_content[:80],
                data={
                    "match_id": str(match_uuid),
                    "sender_id": str(current_user.id),
                    "sender_name": current_user.full_name,
                    "target_route": "/chat-dialogue",
                }
            )
    except Exception as e:
        print(f"[CHAT MESSAGE NOTIF] Notice: {e}", flush=True)

    return {
        "status": "sent",
        "id": str(msg.id),
        "match_id": str(msg.match_id),
        "sender_id": str(msg.sender_id),
        "content": msg.encrypted_text,
        "timestamp": msg.created_at.strftime("%I:%M %p"),
        "delivery_status": msg.status
    }
