import json
from uuid import UUID
from datetime import datetime, timezone
from typing import Optional, List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends, HTTPException, Header, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, desc, or_

from app.core.config import settings
from app.core.database import get_db, async_session_factory
from app.core.security import decode_access_token, verify_firebase_token
from app.services.chat_manager import manager
from app.services.chat_sanitizer import sanitize_chat_message
from app.models.domain.message import Message
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
    status: str
    created_at: datetime


class MatchPartnerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    match_id: UUID
    partner_id: UUID
    partner_name: str
    partner_photo_url: str
    partner_city: str
    partner_bio: str
    whatsapp_unlocked: bool
    last_message: Optional[str] = None
    created_at: datetime


# ------------------------------------------------------------------------------
# REST: User Matches Endpoint
# ------------------------------------------------------------------------------
@router.get("/matches", response_model=List[MatchPartnerResponse])
async def get_user_matches(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns all active matches for the authenticated user with partner profile details.
    """
    match_stmt = (
        select(Match)
        .where(
            Match.is_active == True,
            or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
        )
        .order_by(desc(Match.created_at))
    )
    res = await db.execute(match_stmt)
    matches = res.scalars().all()

    result: List[MatchPartnerResponse] = []
    for m in matches:
        partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
        partner_res = await db.execute(select(User).where(User.id == partner_id))
        partner = partner_res.scalar_one_or_none()
        if not partner:
            continue

        photo_res = await db.execute(
            select(UserPhoto)
            .where(UserPhoto.user_id == partner.id)
            .order_by(UserPhoto.slot_index.asc())
            .limit(1)
        )
        photo = photo_res.scalar_one_or_none()
        photo_url = "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500"
        if photo and photo.photo_storage_path:
            p = photo.photo_storage_path
            photo_url = p if p.startswith("http") else f"{settings.SUPABASE_URL}/storage/v1/object/public/user-photos/{p}"

        last_msg_res = await db.execute(
            select(Message)
            .where(Message.match_id == m.id)
            .order_by(desc(Message.id))
            .limit(1)
        )
        last_msg = last_msg_res.scalar_one_or_none()

        result.append(MatchPartnerResponse(
            match_id=m.id,
            partner_id=partner.id,
            partner_name=partner.full_name,
            partner_photo_url=photo_url,
            partner_city=partner.city,
            partner_bio=partner.bio or "Hey there! We matched on UR-Heart.",
            whatsapp_unlocked=m.whatsapp_unlocked,
            last_message=last_msg.encrypted_text if last_msg else None,
            created_at=m.created_at,
        ))

    return result


# ------------------------------------------------------------------------------
# REST: Chat History Endpoint
# ------------------------------------------------------------------------------
@router.get("/history/{match_id}", response_model=List[MessageHistoryResponse])
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

    # 2. Keyset Query on Messages
    query = (
        select(Message)
        .where(Message.match_id == match_id)
        .order_by(desc(Message.id))
        .limit(limit)
    )
    if before_id is not None:
        query = query.where(Message.id < before_id)

    res = await db.execute(query)
    messages = res.scalars().all()

    # Return in ascending chronological order for client UI rendering
    return sorted(messages, key=lambda m: m.id)

# ------------------------------------------------------------------------------
# WebSocket: Real-Time Chat Gateway & Gatekeeper
# ------------------------------------------------------------------------------
@router.websocket("/ws")
async def websocket_chat_gateway_sub(
    websocket: WebSocket,
    token: Optional[str] = Query(None)
):
    await handle_chat_websocket(websocket, token)

async def handle_chat_websocket(websocket: WebSocket, token: Optional[str]):
    """
    Core WebSocket handler:
    - Verifies token authentication via decode_access_token.
    - Intercepts outbound content with sanitize_chat_message() (Anti-Leak).
    - Persists clean messages to PostgreSQL and coordinates live dispatch.
    - Handles read receipts and typing events.
    """
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id_str = decode_access_token(token)
    if not user_id_str:
        # Fallback: check if token is valid Firebase ID token
        try:
            fb_auth = verify_firebase_token(token)
            fb_uid = fb_auth.get("uid")
            if fb_uid:
                async with async_session_factory() as db:
                    stmt = select(User.id).where(User.firebase_uid == fb_uid)
                    res = await db.execute(stmt)
                    uid_val = res.scalar_one_or_none()
                    if uid_val:
                        user_id_str = str(uid_val)
        except Exception:
            pass

    if not user_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    try:
        user_id = UUID(user_id_str)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    await manager.connect(user_id, websocket)

    try:
        while True:
            raw_text = await websocket.receive_text()
            try:
                payload = json.loads(raw_text)
            except Exception:
                continue

            event_type = payload.get("type")
            match_id_str = payload.get("match_id")
            if not match_id_str:
                continue

            try:
                match_id = UUID(match_id_str)
            except Exception:
                continue

            # ==================================================================
            # Event 1: Outgoing Chat Message
            # ==================================================================
            if event_type == "message":
                recipient_id_str = payload.get("recipient_id")
                content = payload.get("content", "")

                if not recipient_id_str or not content:
                    continue

                try:
                    recipient_id = UUID(recipient_id_str)
                except Exception:
                    continue

                # 1. Anti-Leak Gatekeeper Interception
                is_safe = sanitize_chat_message(content)
                if not is_safe:
                    await websocket.send_text(json.dumps({
                        "event": "anti_leak_violation",
                        "code": 422,
                        "match_id": str(match_id),
                        "message": "Sharing phone numbers, social media handles (@, IG, WA, Snap) or external contacts is strictly prohibited on UR-Heart."
                    }))
                    # Abort: Message dropped; neither written to DB nor sent to recipient
                    continue

                # 2. Database Persistence for Clean Messages
                async with async_session_factory() as db:
                    # Check active match and user participation (prevent IDOR)
                    match_stmt = select(Match).where(
                        Match.id == match_id,
                        Match.is_active == True,
                        or_(Match.user1_id == user_id, Match.user2_id == user_id)
                    )
                    m_res = await db.execute(match_stmt)
                    if not m_res.scalar_one_or_none():
                        continue

                    # Check recipient online status
                    is_recipient_online = recipient_id in manager.active_connections
                    initial_status = "delivered" if is_recipient_online else "sent"

                    new_msg = Message(
                        match_id=match_id,
                        sender_id=user_id,
                        encrypted_text=content,
                        status=initial_status
                    )
                    db.add(new_msg)
                    await db.commit()
                    await db.refresh(new_msg)
                    msg_id = new_msg.id
                    created_at_iso = new_msg.created_at.isoformat()

                # 3. Real-Time Delivery to Recipient & Ack to Sender
                await websocket.send_text(json.dumps({
                    "event": "message_sent",
                    "msg_id": msg_id,
                    "match_id": str(match_id),
                    "status": initial_status
                }))

                if is_recipient_online:
                    await manager.send_personal_message({
                        "event": "incoming_message",
                        "msg_id": msg_id,
                        "match_id": str(match_id),
                        "sender_id": str(user_id),
                        "content": content,
                        "created_at": created_at_iso
                    }, recipient_id)

            # ==================================================================
            # Event 2: Read Receipts
            # ==================================================================
            elif event_type == "read_receipt":
                async with async_session_factory() as db:
                    await db.execute(
                        update(Message)
                        .where(
                            Message.match_id == match_id,
                            Message.sender_id != user_id,
                            Message.status != "read"
                        )
                        .values(status="read")
                    )
                    await db.commit()

                # Notify other match participant if recipient_id provided
                recipient_id_str = payload.get("recipient_id")
                if recipient_id_str:
                    try:
                        rec_id = UUID(recipient_id_str)
                        await manager.send_personal_message({
                            "event": "messages_read",
                            "match_id": str(match_id)
                        }, rec_id)
                    except Exception:
                        pass

            # ==================================================================
            # Event 3: Typing Indicators
            # ==================================================================
            elif event_type == "typing":
                recipient_id_str = payload.get("recipient_id")
                if recipient_id_str:
                    try:
                        rec_id = UUID(recipient_id_str)
                        await manager.send_personal_message({
                            "event": "user_typing",
                            "match_id": str(match_id),
                            "sender_id": str(user_id),
                            "is_typing": payload.get("is_typing", True)
                        }, rec_id)
                    except Exception:
                        pass

    except WebSocketDisconnect:
        manager.disconnect(user_id)
    except Exception:
        manager.disconnect(user_id)
