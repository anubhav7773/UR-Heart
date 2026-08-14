import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, File, UploadFile, HTTPException, status, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import Match, ChatMessage, User, UserPhoto, BlockedUser
from app.services.notification_engine import NotificationEngineService
from app.services.fcm_service import send_push_notification
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


def _utc_iso(value: Optional[datetime] = None) -> str:
    """Serialize message timestamps as timezone-aware UTC ISO 8601 strings."""
    instant = value or datetime.now(timezone.utc)
    if instant.tzinfo is None:
        instant = instant.replace(tzinfo=timezone.utc)
    else:
        instant = instant.astimezone(timezone.utc)
    return instant.isoformat().replace("+00:00", "Z")


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
                if connection == sender_ws:
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
            client_msg_id=msg.client_msg_id,
            created_at=_utc_iso(msg.created_at),
        )
        for msg in messages
    ]
    return APIResponse(success=True, data=result)


@router.post("/send", response_model=APIResponse[ChatMessageRead])
async def send_chat_message(
    payload: SendMessageRequest,
    background_tasks: BackgroundTasks,
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
                    client_msg_id=existing_msg.client_msg_id,
                    content=existing_msg.content,
                    media_url=existing_msg.media_url,
                    media_type=existing_msg.media_type,
                    created_at=_utc_iso(existing_msg.created_at),
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

    iso_created_at = _utc_iso(new_msg.created_at)

    # Broadcast message to active WebSocket connection
    try:
        await ws_manager.broadcast(
            payload.match_id,
            {
                "id": str(new_msg.id),
                "match_id": str(new_msg.match_id),
                "sender_id": str(new_msg.sender_id),
                "client_msg_id": new_msg.client_msg_id,
                "content": new_msg.content,
                "media_url": new_msg.media_url,
                "media_type": new_msg.media_type,
                "created_at": iso_created_at,
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

            recip_token = getattr(recip_user, 'fcm_token', None) if recip_user else None
            print(f"[FCM] Dispatching push to user: {recipient_id}, token: {recip_token or 'None'}")

            if recip_user and recip_token:
                background_tasks.add_task(
                    send_push_notification,
                    fcm_token=recip_token,
                    title=sender_name,
                    body=payload.content or "Sent you a media attachment.",
                    data={
                        "type": "chat",
                        "sender_id": str(sender_uuid),
                        "match_id": str(payload.match_id),
                        "conversation_id": str(payload.match_id),
                    },
                )
            else:
                print(f"[FCM] Skipped dispatch: recipient user {recipient_id} has no registered FCM token.")
    except Exception as exc:
        print(f"[FCM] Exception while staging chat push notification: {exc}")

    return APIResponse(
        success=True,
        data=ChatMessageRead(
            id=str(new_msg.id),
            match_id=str(new_msg.match_id),
            sender_id=str(new_msg.sender_id),
            client_msg_id=new_msg.client_msg_id,
            content=new_msg.content,
            media_url=new_msg.media_url,
            media_type=new_msg.media_type,
            created_at=_utc_iso(new_msg.created_at),
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
    Checks Safe WhatsApp Bridge double-consent status.
    Unlocks contact number only when at least 15 mutual messages are exchanged
    AND both participants have explicitly provided their consent.
    """
    count = 0
    my_consent = False
    partner_consent = False
    unlocked = False
    target_phone = None

    try:
        user_uuid = uuid.UUID(current_user_id)
        match_uuid = uuid.UUID(match_id)
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        match_obj = match_res.scalars().first()

        if match_obj:
            if match_obj.user1_id != user_uuid and match_obj.user2_id != user_uuid:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You are not a participant in this match."
                )

            count = match_obj.mutual_message_count or 0
            is_user1 = (match_obj.user1_id == user_uuid)

            my_consent = match_obj.user1_whatsapp_consent if is_user1 else match_obj.user2_whatsapp_consent
            partner_consent = match_obj.user2_whatsapp_consent if is_user1 else match_obj.user1_whatsapp_consent

            # Unlocked only when both consented and count >= 15 (or previously marked unlocked)
            unlocked = (my_consent and partner_consent and count >= 15) or match_obj.is_whatsapp_unlocked

            if unlocked:
                target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
                target_res = await db.execute(select(User).where(User.id == target_id))
                target_user = target_res.scalars().first()
                if target_user and target_user.phone_number:
                    target_phone = target_user.phone_number
    except HTTPException:
        raise
    except Exception as err:
        logger.warning(f"[WhatsApp-Bridge] Error checking status for match {match_id}: {err}")
        await db.rollback()

    return APIResponse(
        success=True,
        data=WhatsAppBridgeStatusData(
            match_id=match_id,
            mutual_message_count=count,
            required_threshold=15,
            my_consent=my_consent,
            partner_consent=partner_consent,
            is_whatsapp_unlocked=unlocked,
            phone_number=target_phone if unlocked and target_phone else None,
        )
    )


@router.post("/whatsapp-consent/{match_id}", response_model=APIResponse[WhatsAppBridgeStatusData])
async def give_whatsapp_consent(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits current user's explicit consent to share WhatsApp contact details with match partner.
    Requires at least 15 mutual messages to be exchanged.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        match_uuid = uuid.UUID(match_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid match ID or user ID format."
        )

    match_res = await db.execute(select(Match).where(Match.id == match_uuid))
    match_obj = match_res.scalars().first()

    if not match_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Match conversation not found."
        )

    if match_obj.user1_id != user_uuid and match_obj.user2_id != user_uuid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not an authorized participant in this conversation."
        )

    count = match_obj.mutual_message_count or 0
    if count < 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"At least 15 mutual messages required before unlocking WhatsApp consent. (Current: {count}/15)"
        )

    is_user1 = (match_obj.user1_id == user_uuid)
    if is_user1:
        match_obj.user1_whatsapp_consent = True
    else:
        match_obj.user2_whatsapp_consent = True

    # Check if both have now consented
    both_consented = match_obj.user1_whatsapp_consent and match_obj.user2_whatsapp_consent
    if both_consented:
        match_obj.is_whatsapp_unlocked = True

    await db.commit()
    await db.refresh(match_obj)

    target_phone = None
    if match_obj.is_whatsapp_unlocked:
        target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
        target_res = await db.execute(select(User).where(User.id == target_id))
        target_user = target_res.scalars().first()
        if target_user and target_user.phone_number:
            target_phone = target_user.phone_number

    my_consent = match_obj.user1_whatsapp_consent if is_user1 else match_obj.user2_whatsapp_consent
    partner_consent = match_obj.user2_whatsapp_consent if is_user1 else match_obj.user1_whatsapp_consent

    return APIResponse(
        success=True,
        message="WhatsApp contact sharing consent recorded successfully.",
        data=WhatsAppBridgeStatusData(
            match_id=match_id,
            mutual_message_count=count,
            required_threshold=15,
            my_consent=my_consent,
            partner_consent=partner_consent,
            is_whatsapp_unlocked=match_obj.is_whatsapp_unlocked,
            phone_number=target_phone if match_obj.is_whatsapp_unlocked and target_phone else None,
        )
    )
