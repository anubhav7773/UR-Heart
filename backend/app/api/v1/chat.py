import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import Match, ChatMessage, User, UserPhoto, BlockedUser
from app.services.notification_engine import NotificationEngineService
from app.models.schemas import (
    APIResponse,
    MatchRead,
    ChatMessageRead,
    SendMessageRequest,
    UploadMediaData,
    WhatsAppBridgeStatusData,
)
from app.services.storage_engine import StorageEngineService

router = APIRouter(prefix="/chat", tags=["Real-Time Chat & Media Attachments"])


class ConnectionManager:
    """Real-Time WebSocket Connection Manager for instant chat broadcasting."""

    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, match_id: str, websocket: WebSocket):
        await websocket.accept()
        if match_id not in self.active_connections:
            self.active_connections[match_id] = []
        self.active_connections[match_id].append(websocket)

    def disconnect(self, match_id: str, websocket: WebSocket):
        if match_id in self.active_connections:
            if websocket in self.active_connections[match_id]:
                self.active_connections[match_id].remove(websocket)

    async def broadcast(self, match_id: str, message: dict, sender_ws: Optional[WebSocket] = None):
        if match_id in self.active_connections:
            for connection in list(self.active_connections[match_id]):
                if sender_ws is not None and connection == sender_ws:
                    continue  # Never echo message back to its originator socket
                try:
                    await connection.send_json(message)
                except Exception:
                    pass


ws_manager = ConnectionManager()


@router.websocket("/ws/{match_id}")
async def chat_websocket_endpoint(websocket: WebSocket, match_id: str):
    """
    Bidirectional real-time WebSocket connection for instant chat message delivery.
    Skips echoing back to originator socket to prevent client duplication loops.
    """
    await ws_manager.connect(match_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            await ws_manager.broadcast(match_id, data, sender_ws=websocket)
    except WebSocketDisconnect:
        ws_manager.disconnect(match_id, websocket)
    except Exception:
        ws_manager.disconnect(match_id, websocket)


@router.get("/matches", response_model=APIResponse[List[MatchRead]])
@router.get("/conversations", response_model=APIResponse[List[MatchRead]])
async def get_matches(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches all active matches for the authenticated user with target user profile details.
    Safely excludes blocked users and handles empty matches table with HTTP 200 empty list.
    """
    match_list: List[MatchRead] = []
    try:
        user_uuid = uuid.UUID(current_user_id)

        # Exclude blocked users (both directions)
        blocked_res1 = await db.execute(select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user_uuid))
        blocked_res2 = await db.execute(select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user_uuid))
        blocked_ids = set(blocked_res1.scalars().all()).union(set(blocked_res2.scalars().all()))

        matches_res = await db.execute(
            select(Match).where(
                or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid)
            )
        )
        matches = matches_res.scalars().all()

        for m in matches:
            try:
                target_id = m.user2_id if m.user1_id == user_uuid else m.user1_id
                if target_id in blocked_ids:
                    continue

                target_res = await db.execute(
                    select(User).where(User.id == target_id).options(selectinload(User.photos))
                )
                target_user = target_res.scalars().first()

                target_name = target_user.full_name if target_user else "Matched User"
                target_photo = (
                    target_user.photos[0].photo_url
                    if target_user and target_user.photos
                    else ""
                )

                # Get last message
                last_msg_res = await db.execute(
                    select(ChatMessage)
                    .where(ChatMessage.match_id == m.id)
                    .order_by(ChatMessage.created_at.desc())
                    .limit(1)
                )
                last_msg = last_msg_res.scalars().first()
                last_text = last_msg.content if last_msg else "Matched! Send a message."

                match_list.append(
                    MatchRead(
                        id=str(m.id),
                        target_user_id=str(target_id),
                        target_user_name=target_name,
                        target_user_photo=target_photo,
                        mutual_message_count=m.mutual_message_count,
                        is_whatsapp_unlocked=m.is_whatsapp_unlocked,
                        last_message=last_text,
                        updated_at=m.created_at.isoformat() if m.created_at else "",
                    )
                )
            except Exception:
                pass
    except Exception:
        await db.rollback()
        match_list = []

    return APIResponse(success=True, data=match_list)


@router.get("/messages/{match_id}", response_model=APIResponse[List[ChatMessageRead]])
async def get_chat_messages(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves message history for a specified match ID.
    """
    try:
        match_uuid = uuid.UUID(match_id)
        msgs_res = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.match_id == match_uuid)
            .order_by(ChatMessage.created_at.asc())
        )
        messages = msgs_res.scalars().all()
    except Exception:
        messages = []

    result = [
        ChatMessageRead(
            id=str(msg.id),
            match_id=str(msg.match_id),
            sender_id=str(msg.sender_id),
            content=msg.content,
            media_url=msg.media_url,
            media_type=msg.media_type or "text",
            created_at=msg.created_at.isoformat() if msg.created_at else "",
        )
        for msg in messages
    ]
    return APIResponse(success=True, data=result)


@router.post("/send", response_model=APIResponse[ChatMessageRead])
async def send_chat_message(
    payload: SendMessageRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Sends a new text or media message within an active match.
    Enforces absolute deduplication via unique client_msg_id.
    """
    match_uuid = uuid.UUID(payload.match_id)
    sender_uuid = uuid.UUID(current_user_id)

    # 0. Deduplication Check via client_msg_id
    if payload.client_msg_id:
        existing_res = await db.execute(
            select(ChatMessage).where(ChatMessage.client_msg_id == payload.client_msg_id)
        )
        existing_msg = existing_res.scalars().first()
        if existing_msg:
            return APIResponse(
                success=True,
                data=ChatMessageRead(
                    id=str(existing_msg.id),
                    match_id=str(existing_msg.match_id),
                    sender_id=str(existing_msg.sender_id),
                    content=existing_msg.content,
                    media_url=existing_msg.media_url,
                    media_type=existing_msg.media_type,
                    created_at=existing_msg.created_at.isoformat() if existing_msg.created_at else "",
                )
            )

    new_msg = ChatMessage(
        match_id=match_uuid,
        sender_id=sender_uuid,
        client_msg_id=payload.client_msg_id,
        content=payload.content,
        media_url=payload.media_url,
        media_type=payload.media_type or "text",
    )
    db.add(new_msg)

    # Increment message count on match for WhatsApp bridge unlocking
    match_res = await db.execute(select(Match).where(Match.id == match_uuid))
    match_obj = match_res.scalars().first()
    if match_obj:
        match_obj.mutual_message_count += 1
        if match_obj.mutual_message_count >= 15:
            match_obj.is_whatsapp_unlocked = True

    await db.commit()
    await db.refresh(new_msg)

    # Broadcast message to active WebSocket connection
    try:
        await ws_manager.broadcast(
            payload.match_id,
            {
                "id": str(new_msg.id),
                "match_id": str(new_msg.match_id),
                "sender_id": str(new_msg.sender_id),
                "content": new_msg.content,
                "media_url": new_msg.media_url,
                "media_type": new_msg.media_type,
                "created_at": new_msg.created_at.isoformat() if new_msg.created_at else "",
            }
        )
    except Exception:
        pass

    # Trigger push notification to recipient
    try:
        if match_obj:
            recipient_id = match_obj.user2_id if match_obj.user1_id == sender_uuid else match_obj.user1_id
            recip_res = await db.execute(select(User).where(User.id == recipient_id))
            recip_user = recip_res.scalars().first()
            sender_res = await db.execute(select(User).where(User.id == sender_uuid))
            sender_user = sender_res.scalars().first()
            sender_name = sender_user.full_name if sender_user else "Matched User"

            if recip_user and recip_user.fcm_token:
                NotificationEngineService.send_chat_message_notification(
                    target_fcm_token=recip_user.fcm_token,
                    sender_name=sender_name,
                    message_preview=payload.content or "Sent you a media attachment.",
                )
    except Exception:
        pass

    return APIResponse(
        success=True,
        data=ChatMessageRead(
            id=str(new_msg.id),
            match_id=str(new_msg.match_id),
            sender_id=str(new_msg.sender_id),
            content=new_msg.content,
            media_url=new_msg.media_url,
            media_type=new_msg.media_type,
            created_at=new_msg.created_at.isoformat() if new_msg.created_at else "",
        )
    )


@router.post("/upload-media", response_model=APIResponse[UploadMediaData])
async def upload_chat_media(
    file: UploadFile = File(...),
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Uploads chat media attachment (image/audio) to Supabase Storage bucket ('chat-media').
    """
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Filename is missing."
        )

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    cdn_url = await StorageEngineService.upload_chat_media(
        file_bytes=file_bytes,
        filename=file.filename
    )

    return APIResponse(
        success=True,
        message="Media uploaded to chat-media storage successfully.",
        data=UploadMediaData(media_url=cdn_url, is_view_once=False)
    )


@router.get("/whatsapp-bridge-status/{match_id}", response_model=APIResponse[WhatsAppBridgeStatusData])
async def get_whatsapp_bridge_status(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Checks Safe WhatsApp Bridge status (15 mutual messages threshold).
    Unlocks and retrieves verified phone number from DB when 15 mutual messages are exchanged.
    """
    count = 0
    unlocked = False
    target_phone = None

    try:
        user_uuid = uuid.UUID(current_user_id)
        match_uuid = uuid.UUID(match_id)
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        match_obj = match_res.scalars().first()

        if match_obj:
            count = match_obj.mutual_message_count
            unlocked = match_obj.is_whatsapp_unlocked or (count >= 15)

            target_id = match_obj.user2_id if match_obj.user1_id == user_uuid else match_obj.user1_id
            target_res = await db.execute(select(User).where(User.id == target_id))
            target_user = target_res.scalars().first()
            if target_user and target_user.phone_number:
                target_phone = target_user.phone_number
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        data=WhatsAppBridgeStatusData(
            match_id=match_id,
            mutual_message_count=count,
            required_threshold=15,
            is_whatsapp_unlocked=unlocked,
            phone_number=target_phone if unlocked and target_phone else None,
        )
    )
