import json
from uuid import UUID
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends, HTTPException, Header, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, desc, or_, and_, func

from app.core.config import settings
from app.core.database import get_db, async_session_factory
from app.core.security import decode_access_token, verify_firebase_token
from app.services.websocket_manager import chat_manager
from app.services.notification_service import send_push_notification
from app.services.chat_sanitizer import sanitize_chat_message
from app.models.domain.message import Message
from app.models.domain.direct_message import DirectMessage
from app.models.domain.match import Match
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.api.dependencies import get_current_user_id, get_current_user

router = APIRouter()

# Schema for history response
class MessageHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    match_id: UUID
    sender_id: UUID
    encrypted_text: str
    content: Optional[str] = None
    status: str = "sent"
    is_delivered: bool = False
    is_read: bool = False
    created_at: datetime



class MatchPartnerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    match_id: str
    partner_id: str
    partner_name: str
    partner_city: Optional[str] = ""
    partner_photo: Optional[str] = None
    partner_photo_url: Optional[str] = ""
    partner_bio: Optional[str] = ""
    last_message: Optional[str] = None
    last_message_at: Optional[str] = None
    whatsapp_unlocked: bool = False
    created_at: Optional[str] = None


# ------------------------------------------------------------------------------
# REST: User Matches Endpoint
# ------------------------------------------------------------------------------
@router.get("/matches")
async def get_user_matches(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns all active matches for the authenticated user with partner profile details.
    Safely accesses whatsapp_unlocked to avoid AttributeError.
    """
    stmt = (
        select(Match)
        .where(
            Match.is_active == True,
            or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
        )
        .order_by(Match.last_message_at.desc())
    )
    result = await db.execute(stmt)
    matches = result.scalars().all()

    matches_data = []
    for m in matches:
        partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id

        # Fetch partner details
        partner_stmt = select(User).where(User.id == partner_id)
        partner_res = await db.execute(partner_stmt)
        partner = partner_res.scalar_one_or_none()
        if not partner:
            continue

        # Fetch partner photo
        photo_stmt = select(UserPhoto.photo_storage_path).where(
            and_(UserPhoto.user_id == partner.id, UserPhoto.slot_index == 1)
        )
        photo_res = await db.execute(photo_stmt)
        avatar_path = photo_res.scalar_one_or_none()
        avatar_url = ""
        if avatar_path:
            avatar_url = avatar_path if avatar_path.startswith("http") else f"{settings.SUPABASE_URL}/storage/v1/object/public/user-photos/{avatar_path}"

        # Fetch latest message (DirectMessage first, fallback to Message)
        msg_stmt = (
            select(DirectMessage)
            .where(DirectMessage.match_id == m.id)
            .order_by(DirectMessage.created_at.desc())
            .limit(1)
        )
        msg_res = await db.execute(msg_stmt)
        last_msg = msg_res.scalar_one_or_none()

        last_content = last_msg.content if last_msg else None
        last_time = last_msg.created_at if last_msg else None

        if not last_content:
            legacy_msg_stmt = (
                select(Message)
                .where(Message.match_id == m.id)
                .order_by(desc(Message.id))
                .limit(1)
            )
            legacy_res = await db.execute(legacy_msg_stmt)
            legacy_msg = legacy_res.scalar_one_or_none()
            if legacy_msg:
                last_content = legacy_msg.encrypted_text
                last_time = legacy_msg.created_at

        effective_last_at = last_time or getattr(m, "last_message_at", m.created_at)

        matches_data.append({
            "match_id": str(m.id),
            "partner_id": str(partner.id),
            "partner_name": partner.full_name,
            "partner_city": partner.city,
            "partner_photo": avatar_url,
            "partner_photo_url": avatar_url,
            "partner_bio": partner.bio or "Hey there! We matched on UR-Heart.",
            "last_message": last_content if last_content else "Start your private conversation",
            "last_message_at": effective_last_at.isoformat() if effective_last_at else m.created_at.isoformat(),
            "whatsapp_unlocked": getattr(m, "whatsapp_unlocked", False),
            "created_at": m.created_at.isoformat()
        })

    return matches_data


# ------------------------------------------------------------------------------
# REST: Chat History Endpoint
# ------------------------------------------------------------------------------
@router.get("/history/{match_id}", response_model=List[MessageHistoryResponse])
@router.get("/{match_id}/messages", response_model=List[MessageHistoryResponse])
async def get_chat_history(
    match_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    before_id: Optional[int] = Query(None, description="Keyset pagination cursor"),
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Chronological chat history with keyset pagination.
    Verifies match participation before returning messages.
    Supports both DirectMessage and legacy Message tables.
    """
    # 1. Verify Match Participation
    match_stmt = select(Match).where(
        Match.id == match_id,
        or_(Match.user1_id == current_user_id, Match.user2_id == current_user_id)
    )
    match_res = await db.execute(match_stmt)
    match_rec = match_res.scalar_one_or_none()

    if not match_rec:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Not a participant of this match."
        )

    # 2. Query DirectMessage first
    query = (
        select(DirectMessage)
        .where(DirectMessage.match_id == match_id)
        .order_by(desc(DirectMessage.id))
        .limit(limit)
    )
    if before_id is not None:
        query = query.where(DirectMessage.id < before_id)

    res = await db.execute(query)
    direct_msgs = res.scalars().all()

    if direct_msgs:
        return sorted([
            MessageHistoryResponse(
                id=m.id,
                match_id=m.match_id,
                sender_id=m.sender_id,
                encrypted_text=getattr(m, "content", getattr(m, "encrypted_text", "")),
                content=getattr(m, "content", getattr(m, "encrypted_text", "")),
                status="read" if getattr(m, "is_read", False) else ("delivered" if getattr(m, "is_delivered", False) else getattr(m, "status", "sent")),
                is_delivered=getattr(m, "is_delivered", False) or getattr(m, "is_read", False),
                is_read=getattr(m, "is_read", False),
                created_at=m.created_at,
            ) for m in direct_msgs
        ], key=lambda m: m.id)

    # 3. Fallback to legacy Message table
    legacy_query = (
        select(Message)
        .where(Message.match_id == match_id)
        .order_by(desc(Message.id))
        .limit(limit)
    )
    if before_id is not None:
        legacy_query = legacy_query.where(Message.id < before_id)

    legacy_res = await db.execute(legacy_query)
    legacy_messages = legacy_res.scalars().all()

    return sorted([
        MessageHistoryResponse(
            id=m.id,
            match_id=m.match_id,
            sender_id=m.sender_id,
            encrypted_text=getattr(m, "encrypted_text", getattr(m, "content", "")),
            content=getattr(m, "content", getattr(m, "encrypted_text", "")),
            status=getattr(m, "status", "sent"),
            is_delivered=getattr(m, "status", "") in ("delivered", "read"),
            is_read=getattr(m, "status", "") == "read",
            created_at=m.created_at,
        ) for m in legacy_messages
    ], key=lambda m: m.id)


# ------------------------------------------------------------------------------
# WebSocket: Real-Time Chat Gateway & Dispatcher
# ------------------------------------------------------------------------------
async def authenticate_ws_token(token: Optional[str]) -> Optional[str]:
    """Authenticates WebSocket handshake token via internal JWT or Firebase auth. Returns user_id string."""
    if not token:
        return None

    # Internal JWT token decoding
    user_id_str = decode_access_token(token)
    if user_id_str:
        return str(user_id_str)

    # Firebase ID token decoding
    try:
        fb_auth = verify_firebase_token(token)
        fb_uid = fb_auth.get("uid") if fb_auth else None
        if fb_uid:
            async with async_session_factory() as db:
                res = await db.execute(select(User.id).where(User.firebase_uid == fb_uid))
                uid_val = res.scalar_one_or_none()
                if uid_val:
                    return str(uid_val)
    except Exception:
        pass

    return None


@router.websocket("/ws/chat")
@router.websocket("/ws")
async def chat_websocket_endpoint(websocket: WebSocket, token: Optional[str] = Query(None)):
    """
    Central WebSocket gateway:
    1. Authenticates handshake.
    2. Maps user connection in ChatConnectionManager.
    3. Runs anti-leak NLP guard on incoming messages.
    4. Persists message in public.direct_messages and updates matches.last_message_at.
    5. Optimistically echoes to sender, delivers live to receiver or triggers FCM push.
    """
    user_id_str = await authenticate_ws_token(token)
    if not user_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    try:
        user_id = UUID(user_id_str)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await chat_manager.connect(user_id_str, websocket)

    try:
        while True:
            raw_data = await websocket.receive_text()
            try:
                data = json.loads(raw_data)
            except Exception:
                continue

            action = data.get("action") or data.get("type") or data.get("event") or "send_message"
            match_id_str = data.get("match_id")
            recipient_id_str = data.get("recipient_id")
            content = (data.get("content") or "").strip()

            # -------------------------------------------------------------
            # ACTION 1: MARK READ (Emits Blue Ticks to Sender)
            # -------------------------------------------------------------
            if action in ("mark_read", "read_receipt"):
                sender_id = data.get("sender_id") or recipient_id_str
                if match_id_str:
                    try:
                        async with async_session_factory() as db:
                            await db.execute(
                                update(DirectMessage)
                                .where(
                                    and_(
                                        DirectMessage.match_id == UUID(match_id_str),
                                        DirectMessage.recipient_id == user_id,
                                        DirectMessage.is_read.is_(False)
                                    )
                                )
                                .values(is_read=True, is_delivered=True, read_at=func.now())
                            )
                            await db.commit()
                    except Exception:
                        pass

                    if sender_id:
                        # Notify sender in real time to turn ticks blue
                        await chat_manager.send_personal_message({
                            "type": "messages_read",
                            "event": "messages_read",
                            "match_id": match_id_str,
                            "reader_id": user_id_str
                        }, str(sender_id))
                continue

            # Handle delivery acks and typing events
            if action == "delivery_ack":
                msg_id = data.get("msg_id") or data.get("message_id")
                if recipient_id_str:
                    await chat_manager.send_personal_message({
                        "event": "message_delivered",
                        "type": "message_delivered",
                        "match_id": match_id_str,
                        "msg_id": msg_id,
                        "message_id": str(msg_id) if msg_id else "",
                    }, recipient_id_str)
                continue

            if action == "typing":
                if recipient_id_str:
                    await chat_manager.send_personal_message({
                        "event": "user_typing",
                        "type": "typing",
                        "match_id": match_id_str,
                        "sender_id": user_id_str,
                        "is_typing": data.get("is_typing", True)
                    }, recipient_id_str)
                continue

            if not content or not match_id_str or not recipient_id_str:
                continue

            # 2. Anti-Leak NLP Guard
            if not sanitize_chat_message(content):
                await websocket.send_text(json.dumps({
                    "event": "anti_leak_violation",
                    "type": "error",
                    "code": 422,
                    "match_id": match_id_str,
                    "message": "Sharing phone numbers, social media handles (@, IG, WA, Snap) or external contacts is strictly prohibited on UR-Heart.",
                    "detail": "Sharing phone numbers, social media handles (@, IG, WA, Snap) or external contacts is strictly prohibited on UR-Heart."
                }))
                continue

            recipient_id = UUID(recipient_id_str)
            is_recipient_online = recipient_id_str in chat_manager.active_connections or recipient_id_str in chat_manager
            initial_status = "delivered" if is_recipient_online else "sent"

            # 3. Persist message in PostgreSQL
            async with async_session_factory() as db:
                new_msg = DirectMessage(
                    match_id=UUID(match_id_str),
                    sender_id=user_id,
                    recipient_id=recipient_id,
                    content=content,
                    is_delivered=is_recipient_online,
                    delivered_at=func.now() if is_recipient_online else None,
                    is_read=False
                )
                legacy_msg = Message(
                    match_id=UUID(match_id_str),
                    sender_id=user_id,
                    encrypted_text=content,
                    status=initial_status
                )
                db.add(new_msg)
                db.add(legacy_msg)

                # Update match last_message_at
                await db.execute(
                    update(Match)
                    .where(Match.id == UUID(match_id_str))
                    .values(last_message_at=func.now())
                )
                await db.commit()
                try:
                    await db.refresh(new_msg)
                except Exception:
                    pass

                msg_id = getattr(new_msg, "id", None) or getattr(legacy_msg, "id", 101)
                created_at_dt = getattr(new_msg, "created_at", None) or getattr(legacy_msg, "created_at", datetime.now(timezone.utc))
                created_at_iso = created_at_dt.isoformat() if hasattr(created_at_dt, "isoformat") else str(created_at_dt)

                msg_payload = {
                    "type": "new_message",
                    "event": "incoming_message",
                    "id": str(msg_id),
                    "msg_id": msg_id,
                    "message_id": str(msg_id),
                    "match_id": match_id_str,
                    "sender_id": user_id_str,
                    "recipient_id": recipient_id_str,
                    "content": content,
                    "is_delivered": is_recipient_online,
                    "is_read": False,
                    "status": initial_status,
                    "created_at": created_at_iso
                }

                # Single / delivered tick confirmation to sender
                await websocket.send_text(json.dumps({
                    **msg_payload,
                    "event": "message_sent"
                }))

                # 4. Deliver to recipient if online
                if is_recipient_online:
                    await chat_manager.send_personal_message(msg_payload, recipient_id_str)
                else:
                    # 5. If recipient offline, trigger Firebase FCM background notification
                    try:
                        user_stmt = select(User.fcm_token).where(User.id == recipient_id)
                        res = await db.execute(user_stmt)
                        fcm_token = res.scalar_one_or_none()
                        if fcm_token:
                            sender_stmt = select(User.full_name).where(User.id == user_id)
                            sender_res = await db.execute(sender_stmt)
                            sender_name = sender_res.scalar_one_or_none() or "Your Match"
                            await send_push_notification(
                                fcm_token=fcm_token,
                                title=sender_name,
                                body=content if len(content) < 50 else content[:47] + "...",
                                data={"match_id": match_id_str, "type": "chat_message"}
                            )
                    except Exception:
                        pass

    except WebSocketDisconnect:
        chat_manager.disconnect(user_id_str)
    except Exception:
        chat_manager.disconnect(user_id_str)


# Alias for backwards compatibility with main.py
handle_chat_websocket = chat_websocket_endpoint
