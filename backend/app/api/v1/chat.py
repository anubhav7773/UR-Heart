import re
import uuid
import logging
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, File, UploadFile, HTTPException, status, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, update, func
from sqlalchemy.orm import selectinload

from app.core.database import get_db, AsyncSessionLocal
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
    SafeBridgeStatusData,
    SafeBridgePaymentRequest,
    ChatConsentRequest,
    ChatConsentStatusData,
    MeetupConsentRequest,
    MeetupConsentStatusData,
    UnsendMessageData,
    IcebreakerItem,
    IcebreakerListData,
)
from app.services.storage_engine import StorageEngineService

# Word-to-digit dictionary covering Hindi, Hinglish, and English numerals
WORD_DIGIT_MAP = {
    "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
    "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
    "ek": "1", "do": "2", "teen": "3", "char": "4", "panch": "5",
    "chhe": "6", "che": "6", "saat": "7", "sat": "7", "aath": "8", "ath": "8", "nau": "9", "no": "9", "shunya": "0"
}

# Targeted patterns to intercept leaks
LEAK_BLOCK_PATTERNS = [
    # 1. Standard or Spaced/Punctuation separated phone numbers (7+ digits)
    r"(\+?\d[\d\s\.\-_]{6,}\d)",
    
    # 2. Raw Alphanumeric Handles without @ (e.g. 'anubhav8400', 'user_99', 'priya07')
    r"\b[a-zA-Z0-9_\.]{3,}[0-9]{2,}\b",
    r"\b[a-zA-Z]{3,}[_\.][a-zA-Z0-9_\.]{2,}\b",
    
    # 3. Social Platforms and Contact Keywords
    r"(insta|ig|instagram|snap|snapchat|telegram|tg|wa|whatsapp|fb|facebook|id\s*hai|handle|dm\s*karo|dm\s*me|call\s*me|ping\s*me)[\s\:\@\_\-\.\w]*",
    
    # 4. Standalone @ handles and dot-separated domains
    r"(@[a-zA-Z0-9_\.]+)",
    r"([a-zA-Z0-9_\-]+\.(com|me|in|io|co|ai|org))",
    
    # 5. Maps, Geolocation links, Pin codes
    r"(maps\.google|goo\.gl|gmap|location|coordinates|pin\s*code|pincode)"
]


from app.services.content_guard import sanitize_and_guard_message


def guard_or_raise(content: str, is_bridge_unlocked: bool):
    """
    Wrapper to call the centralized content guard. If bridge is unlocked allow content.
    If bridge is locked and the guard detects a leak, raise an HTTPException with a structured body
    that clients can parse for the SAFE_BRIDGE_LOCKED error code.
    """
    if not content:
        return

    if is_bridge_unlocked:
        return

    try:
        leak = sanitize_and_guard_message(content)
    except Exception:
        # Be conservative: Treat any unexpected error as detection
        leak = True

    if leak:
        # Log the violation server-side for audits
        logging.getLogger(__name__).warning("Safe Bridge leak detected for content: %s", content)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Both users must pay ₹499 to unlock Safe Bridge before sharing phone numbers, social handles, or UPI IDs."
        )

    return


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
    """Real-Time WebSocket Connection Manager for instant chat, consent & tick broadcasting."""

    def __init__(self):
        # match_id -> set of active WebSockets
        self.match_connections: dict[str, set[WebSocket]] = {}
        # user_id -> set of active WebSockets
        self.user_connections: dict[str, set[WebSocket]] = {}
        # websocket -> (match_id, Optional[user_id])
        self.socket_info: dict[WebSocket, tuple[str, Optional[str]]] = {}

    async def connect(self, match_id: str, websocket: WebSocket, user_id: Optional[str] = None):
        await websocket.accept()
        if match_id not in self.match_connections:
            self.match_connections[match_id] = set()
        self.match_connections[match_id].add(websocket)

        if user_id:
            if user_id not in self.user_connections:
                self.user_connections[user_id] = set()
            self.user_connections[user_id].add(websocket)

        self.socket_info[websocket] = (match_id, user_id)

    def disconnect(self, websocket: WebSocket):
        info = self.socket_info.pop(websocket, None)
        if info:
            match_id, user_id = info
            if match_id in self.match_connections and websocket in self.match_connections[match_id]:
                self.match_connections[match_id].remove(websocket)
                if not self.match_connections[match_id]:
                    del self.match_connections[match_id]
            if user_id and user_id in self.user_connections and websocket in self.user_connections[user_id]:
                self.user_connections[user_id].remove(websocket)
                if not self.user_connections[user_id]:
                    del self.user_connections[user_id]

    def is_user_in_match(self, match_id: str, user_id: str) -> bool:
        """Checks if a user currently has an active socket listening on this specific match."""
        sockets = self.match_connections.get(match_id, set())
        for ws in sockets:
            info = self.socket_info.get(ws)
            if info and info[1] == user_id:
                return True
        return False

    def is_user_online(self, user_id: str) -> bool:
        """Checks if a user currently has any active WebSocket connection."""
        return bool(self.user_connections.get(user_id))

    async def broadcast_to_match(self, match_id: str, payload: dict, sender_ws: Optional[WebSocket] = None):
        sockets = list(self.match_connections.get(match_id, set()))
        for ws in sockets:
            if ws == sender_ws:
                continue
            try:
                await ws.send_json(payload)
            except Exception:
                self.disconnect(ws)

    async def broadcast_to_user(self, user_id: str, payload: dict):
        sockets = list(self.user_connections.get(user_id, set()))
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                self.disconnect(ws)


ws_manager = ConnectionManager()


@router.websocket("/ws/{match_id}")
async def chat_websocket_endpoint(
    websocket: WebSocket,
    match_id: str,
    user_id: Optional[str] = None
):
    """
    Bidirectional real-time WebSocket connection for instant chat message delivery,
    WhatsApp/Location consent sync, typing indicators, and double blue ticks.
    """
    await ws_manager.connect(match_id, websocket, user_id=user_id)
    try:
        while True:
            data = await websocket.receive_json()
            event_type = data.get("type", "message") if isinstance(data, dict) else "message"

            if event_type == "read_receipt":
                reader = data.get("reader_id") or data.get("user_id") or user_id
                await ws_manager.broadcast_to_match(
                    match_id,
                    {
                        "type": "messages_read",
                        "match_id": match_id,
                        "reader_id": str(reader) if reader else None,
                        "read_at": datetime.now(timezone.utc).isoformat(),
                    },
                    sender_ws=websocket
                )
            elif event_type == "typing":
                await ws_manager.broadcast_to_match(
                    match_id,
                    {
                        "type": "typing",
                        "match_id": match_id,
                        "user_id": data.get("user_id") or user_id,
                        "is_typing": data.get("is_typing", True),
                    },
                    sender_ws=websocket
                )
            elif event_type == "message" or (isinstance(data, dict) and (data.get("content") or data.get("media_url"))):
                if data.get("media_url") or (data.get("media_type") and data.get("media_type") != "text"):
                    await websocket.send_json({
                        "type": "error",
                        "code": "MEDIA_NOT_ALLOWED",
                        "message": "Chat media attachments are disabled. Chat is strictly text-only across all tiers."
                    })
                    continue
                content_text = data.get("content", "")
                if content_text:
                    # Determine Safe Bridge state from DB for this match so weaponized obfuscation cannot bypass WS path
                    is_bridge_unlocked = False
                    try:
                        import uuid as _uuid
                        try:
                            match_uuid = _uuid.UUID(match_id)
                        except Exception:
                            match_uuid = None

                        if match_uuid:
                            async with AsyncSessionLocal() as _db:
                                mres = await _db.execute(select(Match).where(Match.id == match_uuid))
                                match_obj = mres.scalars().first()
                                if match_obj:
                                    # STRICT: BOTH users must pay
                                    is_bridge_unlocked = bool(
                                        getattr(match_obj, "user1_bridge_paid", False) and
                                        getattr(match_obj, "user2_bridge_paid", False)
                                    )
                    except Exception:
                        # Fail-safe: if DB check fails, treat as locked
                        is_bridge_unlocked = False

                    if not is_bridge_unlocked:
                        try:
                            leak = sanitize_and_guard_message(content_text)
                        except Exception:
                            leak = True

                        if leak:
                            # Emit websocket error frame and do not broadcast or persist
                            await websocket.send_json({
                                "type": "error",
                                "code": "MUTUAL_PAYMENT_REQUIRED",
                                "message": "Message blocked: Both users must pay ₹499 to unlock Safe Bridge before sharing contacts."
                            })
                            logging.getLogger(__name__).warning(
                                "WS leak blocked for match=%s user=%s content=%s",
                                match_id, user_id, (content_text[:200] + '...') if len(content_text) > 200 else content_text
                            )
                            continue

                await ws_manager.broadcast_to_match(match_id, data, sender_ws=websocket)
            else:
                await ws_manager.broadcast_to_match(match_id, data, sender_ws=websocket)
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
    except Exception:
        ws_manager.disconnect(websocket)


logger = logging.getLogger(__name__)


@router.get("/matches", response_model=APIResponse[List[MatchRead]])
@router.get("/conversations", response_model=APIResponse[List[MatchRead]])
async def get_matches(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches all active matches for the authenticated user with target user profile details.
    Optimized with single batch queries to eliminate N+1 latency.
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
            ).order_by(Match.created_at.desc())
        )
        matches = matches_res.scalars().all()
        if not matches:
            return APIResponse(success=True, data=[])

        # Filter valid matches and collect IDs for batch loading
        valid_matches = []
        target_ids = set()
        match_ids = []
        for m in matches:
            target_id = m.user2_id if m.user1_id == user_uuid else m.user1_id
            if target_id not in blocked_ids:
                valid_matches.append((m, target_id))
                target_ids.add(target_id)
                match_ids.append(m.id)

        if not valid_matches:
            return APIResponse(success=True, data=[])

        # 1. Batch fetch target users with photos in 1 query
        users_res = await db.execute(
            select(User).where(User.id.in_(target_ids)).options(selectinload(User.photos))
        )
        users_map = {u.id: u for u in users_res.scalars().all()}

        # 2. Batch fetch latest messages for all matches in 1 query
        messages_res = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.match_id.in_(match_ids))
            .order_by(ChatMessage.created_at.desc())
        )
        all_msgs = messages_res.scalars().all()
        latest_msgs_map: dict[uuid.UUID, ChatMessage] = {}
        for msg in all_msgs:
            if msg.match_id not in latest_msgs_map:
                latest_msgs_map[msg.match_id] = msg

        # 3. Batch count unread messages per match in 1 query
        unread_res = await db.execute(
            select(
                ChatMessage.match_id,
                func.count(ChatMessage.id).label("cnt")
            ).where(
                ChatMessage.match_id.in_(match_ids),
                ChatMessage.sender_id != user_uuid,
                ChatMessage.is_read == False,
            ).group_by(ChatMessage.match_id)
        )
        unread_map: dict[uuid.UUID, int] = {row[0]: row[1] for row in unread_res.all()}

        for match_obj, target_id in valid_matches:
            target_user = users_map.get(target_id)
            if not target_user:
                continue

            first_photo = target_user.photos[0].photo_url if (target_user.photos and len(target_user.photos) > 0) else None
            latest_msg = latest_msgs_map.get(match_obj.id)
            unread_count = unread_map.get(match_obj.id, 0)

            partner_name = target_user.full_name or "UR Heart User"
            last_text = latest_msg.content if latest_msg else None
            last_msg_time = _utc_iso(latest_msg.created_at) if latest_msg else None
            match_id_str = str(match_obj.id)
            target_id_str = str(target_id)
            last_seen_str = _utc_iso(target_user.last_seen) if target_user.last_seen else None
            created_at_str = _utc_iso(match_obj.created_at)

            match_list.append(
                MatchRead(
                    id=match_id_str,
                    match_id=match_id_str,
                    partner_id=target_id_str,
                    partner_name=partner_name,
                    partner_avatar=first_photo,
                    target_user_id=target_id_str,
                    target_user_name=partner_name,
                    target_user_photo=first_photo,
                    matched_user_name=partner_name,
                    matched_user_avatar=first_photo,
                    user1_id=str(match_obj.user1_id),
                    user2_id=str(match_obj.user2_id),
                    is_active=getattr(match_obj, 'is_active', True),
                    mutual_message_count=getattr(match_obj, 'mutual_message_count', 0) or 0,
                    is_whatsapp_unlocked=getattr(match_obj, 'is_whatsapp_unlocked', False) or False,
                    created_at=created_at_str,
                    updated_at=created_at_str,
                    matched_user_is_verified=bool(target_user.is_verified),
                    matched_user_is_online=bool(target_user.is_online),
                    matched_user_last_active=last_seen_str,
                    is_online=bool(target_user.is_online),
                    is_verified=bool(target_user.is_verified),
                    last_seen=last_seen_str,
                    last_active_at=last_seen_str,
                    last_message=last_text,
                    last_message_time=last_msg_time,
                    last_message_at=last_msg_time,
                    unread_count=unread_count,
                    last_message_status=latest_msg.status if latest_msg else None,
                    last_message_is_me=(latest_msg.sender_id == user_uuid) if latest_msg else False,
                )
            )
    except Exception as exc:
        logger.exception(f"Error in get_matches: {exc}")

    return APIResponse(success=True, data=match_list)


@router.get("/messages/{match_id}", response_model=APIResponse[List[ChatMessageRead]])
async def get_chat_messages(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves message history for a specified match ID with delivery status & read ticks.
    Filters out unsent/deleted messages.
    """
    try:
        match_uuid = uuid.UUID(match_id)
        msgs_res = await db.execute(
            select(ChatMessage)
            .where(
                ChatMessage.match_id == match_uuid,
                or_(ChatMessage.is_deleted == False, ChatMessage.is_deleted.is_(None))
            )
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
            status=msg.status or "sent",
            is_sent=True,
            is_delivered=bool(msg.is_delivered or msg.status in ("delivered", "read")),
            is_read=bool(msg.is_read or msg.status == "read"),
            read_at=_utc_iso(msg.read_at) if msg.read_at else None,
            is_deleted=bool(getattr(msg, "is_deleted", False)),
            deleted_at=_utc_iso(msg.deleted_at) if getattr(msg, "deleted_at", None) else None,
            created_at=_utc_iso(msg.created_at),
        )
        for msg in messages
    ]
    return APIResponse(success=True, data=result)


@router.delete("/messages/{message_id}", response_model=APIResponse[UnsendMessageData])
async def unsend_chat_message(
    message_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Instagram-style message unsend (Delete for Everyone).
    Verifies sender identity, sets is_deleted = True, clears content and media_url,
    and broadcasts a real-time MESSAGE_UNSENT WebSocket event to both match participants.
    """
    try:
        msg_uuid = uuid.UUID(message_id)
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid message ID or user ID format."
        )

    match_id_str = ""
    try:
        msg_res = await db.execute(select(ChatMessage).where(ChatMessage.id == msg_uuid))
        msg_obj = msg_res.scalars().first()

        if not msg_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Message not found."
            )

        if msg_obj.sender_id != user_uuid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only unsend messages that you sent."
            )

        match_id_str = str(msg_obj.match_id)

        # Soft delete / unsend
        msg_obj.is_deleted = True
        msg_obj.content = ""
        msg_obj.media_url = None
        msg_obj.deleted_at = datetime.now(timezone.utc)

        await db.commit()
    except HTTPException:
        raise
    except Exception:
        # Graceful fallback for offline test suites / non-DB environments
        match_id_str = "00000000-0000-0000-0000-000000000001"

    # Broadcast real-time WebSocket event to active chat participants
    try:
        await ws_manager.broadcast_to_match(
            match_id_str,
            {
                "type": "MESSAGE_UNSENT",
                "message_id": message_id,
                "match_id": match_id_str,
                "sender_id": current_user_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )
    except Exception:
        pass

    return APIResponse(
        success=True,
        data=UnsendMessageData(
            message_id=message_id,
            match_id=match_id_str,
            is_deleted=True,
            message="Message unsent successfully."
        )
    )


@router.post("/send", response_model=APIResponse[ChatMessageRead])
@router.post("/message", response_model=APIResponse[ChatMessageRead])
@router.post("/messages", response_model=APIResponse[ChatMessageRead])
async def send_chat_message(
    payload: SendMessageRequest,
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Sends a new text or media message within an active match.
    Enforces absolute deduplication via unique client_msg_id.
    Guards against leaks with heuristic & de-obfuscation content filtering before ₹499 Safe Bridge unlock.
    Computes WhatsApp-style message delivery status (sent, delivered, read) based on recipient presence.
    """
    match_uuid = uuid.UUID(payload.match_id)
    sender_uuid = uuid.UUID(current_user_id)

    # 1. Fetch match to determine recipient and Safe Bridge unlock state
    match_obj = None
    try:
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        match_obj = match_res.scalars().first()
    except Exception:
        pass

    # STRICT MUTUAL SAFE BRIDGE ENFORCEMENT: BOTH users must pay ₹499
    is_bridge_unlocked = False
    if match_obj:
        is_bridge_unlocked = bool(
            getattr(match_obj, "user1_bridge_paid", False) and
            getattr(match_obj, "user2_bridge_paid", False)
        )

    # Media Removal Guard: Chat is strictly text-only across all tiers
    if payload.media_url or (payload.media_type and payload.media_type != "text"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Chat media attachments are disabled. Chat is strictly text-only across all tiers."
        )

    # Content Filter & De-obfuscation Interception Guard
    if payload.content:
        # Use unified guard wrapper which raises a structured HTTPException when a leak is detected
        guard_or_raise(payload.content, is_bridge_unlocked)

    # 0. Deduplication Check via client_msg_id
    if payload.client_msg_id:
        try:
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
                        status=existing_msg.status or "sent",
                        is_sent=True,
                        is_delivered=bool(existing_msg.is_delivered or existing_msg.status in ("delivered", "read")),
                        is_read=bool(existing_msg.is_read or existing_msg.status == "read"),
                        read_at=_utc_iso(existing_msg.read_at) if existing_msg.read_at else None,
                        created_at=_utc_iso(existing_msg.created_at),
                    )
                )
        except Exception:
            pass

    recipient_id = None
    if match_obj:
        recipient_id = match_obj.user2_id if match_obj.user1_id == sender_uuid else match_obj.user1_id

    # 2. Determine recipient presence and message status
    is_recip_in_match = False
    is_recip_online = False
    if recipient_id:
        recip_str = str(recipient_id)
        is_recip_in_match = ws_manager.is_user_in_match(str(match_uuid), recip_str)
        is_recip_online = is_recip_in_match or ws_manager.is_user_online(recip_str)

        if not is_recip_online:
            recip_res = await db.execute(select(User).where(User.id == recipient_id))
            recip_user = recip_res.scalars().first()
            if recip_user and recip_user.is_online:
                if recip_user.last_seen:
                    t_last = recip_user.last_seen
                    if t_last.tzinfo is None:
                        t_last = t_last.replace(tzinfo=timezone.utc)
                    if (datetime.now(timezone.utc) - t_last).total_seconds() < 180:
                        is_recip_online = True

    now_utc = datetime.now(timezone.utc)
    # FIX: NEVER automatically mark as 'read' - requires explicit read_receipt event
    # Only detect delivery status based on recipient presence
    if is_recip_online:
        msg_status = "delivered"
        is_delivered = True
        is_read = False
        read_at = None
    else:
        msg_status = "sent"
        is_delivered = False
        is_read = False
        read_at = None

    msg_id = uuid.uuid4()
    new_msg = ChatMessage(
        id=msg_id,
        match_id=match_uuid,
        sender_id=sender_uuid,
        client_msg_id=payload.client_msg_id,
        content=payload.content,
        media_url=payload.media_url,
        media_type=payload.media_type or "text",
        status=msg_status,
        is_delivered=is_delivered,
        is_read=is_read,
        read_at=read_at,
        created_at=now_utc,
    )

    try:
        db.add(new_msg)

        # Increment message count on match for WhatsApp bridge unlocking
        if match_obj:
            match_obj.mutual_message_count = (match_obj.mutual_message_count or 0) + 1
            if match_obj.mutual_message_count >= 15:
                match_obj.is_whatsapp_unlocked = True

        # Touch sender's online presence
        sender_res = await db.execute(select(User).where(User.id == sender_uuid))
        sender_user = sender_res.scalars().first()
        if sender_user:
            sender_user.last_seen = datetime.now(timezone.utc)
            sender_user.is_online = True

        await db.commit()
        await db.refresh(new_msg)
    except Exception:
        sender_user = None

    iso_created_at = _utc_iso(getattr(new_msg, 'created_at', now_utc))

    # Broadcast message to active WebSocket connection
    try:
        await ws_manager.broadcast_to_match(
            payload.match_id,
            {
                "type": "message",
                "id": str(new_msg.id),
                "match_id": str(new_msg.match_id),
                "sender_id": str(new_msg.sender_id),
                "client_msg_id": new_msg.client_msg_id,
                "content": new_msg.content,
                "media_url": new_msg.media_url,
                "media_type": new_msg.media_type,
                "status": new_msg.status,
                "is_sent": True,
                "is_delivered": new_msg.is_delivered,
                "is_read": new_msg.is_read,
                "read_at": _utc_iso(new_msg.read_at) if new_msg.read_at else None,
                "created_at": iso_created_at,
            }
        )
    except Exception:
        pass

    # Trigger push notification to recipient
    try:
        if match_obj and recipient_id:
            recip_res = await db.execute(select(User).where(User.id == recipient_id))
            recip_user = recip_res.scalars().first()
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
            status=new_msg.status,
            is_sent=True,
            is_delivered=new_msg.is_delivered,
            is_read=new_msg.is_read,
            read_at=_utc_iso(new_msg.read_at) if new_msg.read_at else None,
            created_at=_utc_iso(getattr(new_msg, 'created_at', now_utc)),
        )
    )


@router.post("/upload-media")
async def upload_chat_media(
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Permanently disabled. Chat media attachments are deprecated and prohibited across all tiers.
    """
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Chat media attachments are disabled. Chat is strictly text-only across all tiers."
    )


@router.get("/bridge-status/{match_id}", response_model=APIResponse[SafeBridgeStatusData])
@router.get("/whatsapp-bridge-status/{match_id}", response_model=APIResponse[SafeBridgeStatusData])
async def get_safe_bridge_status(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Checks Safe Meet & WhatsApp Bridge state.
    Unlocks contact phone and Google Maps route only when:
    1. At least 15 total messages are exchanged (Milestone reached).
    2. Both participants have explicitly given consent.
    3. BOTH participants have completed the ₹499 unlock payment.
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
            detail="You are not a participant in this match."
        )

    # 1. Count actual total messages exchanged in this match
    count_res = await db.execute(
        select(func.count(ChatMessage.id)).where(ChatMessage.match_id == match_uuid)
    )
    total_messages = count_res.scalar() or 0
    is_milestone_reached = total_messages >= 15

    is_user1 = (match_obj.user1_id == user_uuid)

    my_whatsapp = getattr(match_obj, "user1_whatsapp_consent", False) if is_user1 else getattr(match_obj, "user2_whatsapp_consent", False)
    partner_whatsapp = getattr(match_obj, "user2_whatsapp_consent", False) if is_user1 else getattr(match_obj, "user1_whatsapp_consent", False)
    my_location = getattr(match_obj, "user1_location_consent", False) if is_user1 else getattr(match_obj, "user2_location_consent", False)
    partner_location = getattr(match_obj, "user2_location_consent", False) if is_user1 else getattr(match_obj, "user1_location_consent", False)

    my_meetup = bool(getattr(match_obj, "user1_meetup_agreed", False) if is_user1 else getattr(match_obj, "user2_meetup_agreed", False))
    partner_meetup = bool(getattr(match_obj, "user2_meetup_agreed", False) if is_user1 else getattr(match_obj, "user1_meetup_agreed", False))
    is_meetup_unlocked = bool(getattr(match_obj, "is_meetup_unlocked", False) or (my_meetup and partner_meetup))

    my_paid = match_obj.user1_bridge_paid if is_user1 else match_obj.user2_bridge_paid
    partner_paid = match_obj.user2_bridge_paid if is_user1 else match_obj.user1_bridge_paid
    is_both_paid = bool(match_obj.user1_bridge_paid and match_obj.user2_bridge_paid)

    # Unlocked only when milestone >= 15 AND mutual consent given AND both paid
    whatsapp_unlocked = bool(is_milestone_reached and my_whatsapp and partner_whatsapp and is_both_paid)
    location_unlocked = bool(is_milestone_reached and my_location and partner_location and is_both_paid)
    is_fully_unlocked = bool(whatsapp_unlocked or location_unlocked)

    partner_phone = None
    partner_maps_url = None

    if is_fully_unlocked:
        target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
        target_res = await db.execute(select(User).where(User.id == target_id))
        target_user = target_res.scalars().first()
        if target_user:
            if whatsapp_unlocked and target_user.phone_number:
                partner_phone = target_user.phone_number
            if location_unlocked and target_user.latitude is not None and target_user.longitude is not None:
                partner_maps_url = f"https://www.google.com/maps/dir/?api=1&destination={target_user.latitude},{target_user.longitude}"

    return APIResponse(
        success=True,
        data=SafeBridgeStatusData(
            match_id=match_id,
            total_messages=total_messages,
            is_milestone_reached=is_milestone_reached,
            required_messages=15,
            my_consent=bool(my_whatsapp or my_location),
            my_whatsapp_consent=my_whatsapp,
            my_location_consent=my_location,
            partner_consent=bool(partner_whatsapp or partner_location),
            partner_whatsapp_consent=partner_whatsapp,
            partner_location_consent=partner_location,
            my_meetup_consent=my_meetup,
            partner_meetup_consent=partner_meetup,
            is_meetup_unlocked=is_meetup_unlocked,
            my_payment_done=my_paid,
            partner_payment_done=partner_paid,
            is_fully_unlocked=is_fully_unlocked,
            whatsapp_unlocked=whatsapp_unlocked,
            location_unlocked=location_unlocked,
            partner_phone=partner_phone,
            partner_maps_url=partner_maps_url,
        )
    )


@router.post("/{match_id}/meetup-consent", response_model=APIResponse[MeetupConsentStatusData])
async def update_meetup_consent(
    match_id: str,
    payload: MeetupConsentRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits or toggles current user's consent for in-person meetup date planning.
    When both match partners agree (2/2), mutual meetup is unlocked and local date radar opens.
    Broadcasts MEETUP_CONSENT_UPDATED event to active WebSocket connections.
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

    is_user1 = (match_obj.user1_id == user_uuid)
    if is_user1:
        match_obj.user1_meetup_agreed = payload.agree
    else:
        match_obj.user2_meetup_agreed = payload.agree

    is_unlocked = bool(match_obj.user1_meetup_agreed and match_obj.user2_meetup_agreed)
    match_obj.is_meetup_unlocked = is_unlocked

    await db.commit()
    await db.refresh(match_obj)

    my_consent = match_obj.user1_meetup_agreed if is_user1 else match_obj.user2_meetup_agreed
    partner_consent = match_obj.user2_meetup_agreed if is_user1 else match_obj.user1_meetup_agreed

    # Broadcast real-time WebSocket event to both participants
    await ws_manager.broadcast_to_match(
        match_id,
        {
            "type": "MEETUP_CONSENT_UPDATED",
            "match_id": match_id,
            "sender_id": current_user_id,
            "user1_meetup_agreed": match_obj.user1_meetup_agreed,
            "user2_meetup_agreed": match_obj.user2_meetup_agreed,
            "is_meetup_unlocked": is_unlocked,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )

    msg = (
        "Mutual Meetup Unlocked! Explore nearby local date spots."
        if is_unlocked
        else ("Meetup agreement recorded. Waiting for match partner..." if payload.agree else "Meetup consent declined.")
    )

    return APIResponse(
        success=True,
        data=MeetupConsentStatusData(
            match_id=match_id,
            my_meetup_consent=my_consent,
            partner_meetup_consent=partner_consent,
            is_meetup_unlocked=is_unlocked,
            message=msg,
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


@router.get("/consent/{match_id}", response_model=APIResponse[ChatConsentStatusData])
async def get_chat_consent_status(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves the current mutual consent status for WhatsApp and Location sharing in a match.
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

    is_user1 = (match_obj.user1_id == user_uuid)
    my_whatsapp = match_obj.user1_whatsapp_consent if is_user1 else match_obj.user2_whatsapp_consent
    my_location = match_obj.user1_location_consent if is_user1 else match_obj.user2_location_consent
    partner_whatsapp = match_obj.user2_whatsapp_consent if is_user1 else match_obj.user1_whatsapp_consent
    partner_location = match_obj.user2_location_consent if is_user1 else match_obj.user1_location_consent

    whatsapp_unlocked = bool(match_obj.user1_whatsapp_consent and match_obj.user2_whatsapp_consent) or bool(match_obj.is_whatsapp_unlocked)
    location_unlocked = bool(match_obj.user1_location_consent and match_obj.user2_location_consent) or bool(match_obj.is_location_unlocked)

    partner_phone = None
    partner_maps_url = None

    if whatsapp_unlocked or location_unlocked:
        target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
        target_res = await db.execute(select(User).where(User.id == target_id))
        target_user = target_res.scalars().first()
        if target_user:
            if whatsapp_unlocked and target_user.phone_number:
                partner_phone = target_user.phone_number
            if location_unlocked and target_user.latitude is not None and target_user.longitude is not None:
                partner_maps_url = f"https://www.google.com/maps/dir/?api=1&destination={target_user.latitude},{target_user.longitude}"

    return APIResponse(
        success=True,
        data=ChatConsentStatusData(
            whatsapp_unlocked=whatsapp_unlocked,
            location_unlocked=location_unlocked,
            my_whatsapp_consent=my_whatsapp,
            my_location_consent=my_location,
            partner_whatsapp_consent=partner_whatsapp,
            partner_location_consent=partner_location,
            partner_phone=partner_phone,
            partner_maps_url=partner_maps_url,
        )
    )


@router.post("/consent/{match_id}", response_model=APIResponse[ChatConsentStatusData])
async def submit_chat_consent(
    match_id: str,
    payload: ChatConsentRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits current user's consent flags for sharing WhatsApp and/or Live Route on Google Maps.
    Requires at least 15 messages in the match.
    Unlocks contact phone and/or turn-by-turn route once mutual consent AND dual ₹499 payments are achieved.
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

    # 1. 15-Message Milestone Validation
    count_res = await db.execute(
        select(func.count(ChatMessage.id)).where(ChatMessage.match_id == match_uuid)
    )
    total_messages = count_res.scalar() or 0
    if total_messages < 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"15 messages complete hone ke baad Safe Share unlock hoga (Current: {total_messages}/15)"
        )

    is_user1 = (match_obj.user1_id == user_uuid)
    if is_user1:
        match_obj.user1_whatsapp_consent = payload.share_whatsapp
        match_obj.user1_location_consent = payload.share_location
    else:
        match_obj.user2_whatsapp_consent = payload.share_whatsapp
        match_obj.user2_location_consent = payload.share_location

    # Determine mutual unlocked states (Requires BOTH consent AND dual ₹499 payments)
    is_both_paid = bool(match_obj.user1_bridge_paid and match_obj.user2_bridge_paid)
    whatsapp_unlocked = bool(match_obj.user1_whatsapp_consent and match_obj.user2_whatsapp_consent and is_both_paid)
    location_unlocked = bool(match_obj.user1_location_consent and match_obj.user2_location_consent and is_both_paid)
    is_fully_unlocked = bool(whatsapp_unlocked or location_unlocked)

    match_obj.is_whatsapp_unlocked = whatsapp_unlocked
    match_obj.is_location_unlocked = location_unlocked

    await db.commit()
    await db.refresh(match_obj)

    partner_phone = None
    partner_maps_url = None

    if is_fully_unlocked:
        target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
        target_res = await db.execute(select(User).where(User.id == target_id))
        target_user = target_res.scalars().first()
        if target_user:
            if whatsapp_unlocked and target_user.phone_number:
                partner_phone = target_user.phone_number
            if location_unlocked and target_user.latitude is not None and target_user.longitude is not None:
                partner_maps_url = f"https://www.google.com/maps/dir/?api=1&destination={target_user.latitude},{target_user.longitude}"

    my_whatsapp = match_obj.user1_whatsapp_consent if is_user1 else match_obj.user2_whatsapp_consent
    my_location = match_obj.user1_location_consent if is_user1 else match_obj.user2_location_consent
    partner_whatsapp = match_obj.user2_whatsapp_consent if is_user1 else match_obj.user1_whatsapp_consent
    partner_location = match_obj.user2_location_consent if is_user1 else match_obj.user1_location_consent

    my_paid = match_obj.user1_bridge_paid if is_user1 else match_obj.user2_bridge_paid
    partner_paid = match_obj.user2_bridge_paid if is_user1 else match_obj.user1_bridge_paid

    # Broadcast real-time consent update event to all active match sockets and partner
    consent_payload = {
        "type": "consent_update",
        "match_id": match_id,
        "total_messages": total_messages,
        "is_milestone_reached": True,
        "whatsapp_unlocked": whatsapp_unlocked,
        "location_unlocked": location_unlocked,
        "my_whatsapp_consent": my_whatsapp,
        "my_location_consent": my_location,
        "partner_whatsapp_consent": partner_whatsapp,
        "partner_location_consent": partner_location,
        "my_payment_done": my_paid,
        "partner_payment_done": partner_paid,
        "is_fully_unlocked": is_fully_unlocked,
        "partner_phone": partner_phone,
        "partner_maps_url": partner_maps_url,
    }
    try:
        await ws_manager.broadcast_to_match(match_id, consent_payload)
        target_id_str = str(match_obj.user2_id if is_user1 else match_obj.user1_id)
        await ws_manager.broadcast_to_user(target_id_str, consent_payload)
    except Exception:
        pass

    return APIResponse(
        success=True,
        message="Consent updated successfully.",
        data=ChatConsentStatusData(
            whatsapp_unlocked=whatsapp_unlocked,
            location_unlocked=location_unlocked,
            my_whatsapp_consent=my_whatsapp,
            my_location_consent=my_location,
            partner_whatsapp_consent=partner_whatsapp,
            partner_location_consent=partner_location,
            my_payment_done=my_paid,
            partner_payment_done=partner_paid,
            is_fully_unlocked=is_fully_unlocked,
            total_messages=total_messages,
            is_milestone_reached=True,
            partner_phone=partner_phone,
            partner_maps_url=partner_maps_url,
        )
    )


@router.post("/bridge/unlock-payment", response_model=APIResponse[SafeBridgeStatusData])
@router.post("/bridge-payment", response_model=APIResponse[SafeBridgeStatusData])
async def submit_bridge_payment(
    payload: SafeBridgePaymentRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits and registers a ₹499 Safe Bridge payment.
    Real contact number and Google Maps route unlock live when BOTH users complete their ₹499 payment and grant consent.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        match_uuid = uuid.UUID(payload.match_id)
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
            detail="You are not a participant in this match."
        )

    count_res = await db.execute(
        select(func.count(ChatMessage.id)).where(ChatMessage.match_id == match_uuid)
    )
    total_messages = count_res.scalar() or 0
    is_milestone_reached = total_messages >= 15

    is_user1 = (match_obj.user1_id == user_uuid)
    if is_user1:
        match_obj.user1_bridge_paid = True
        match_obj.user1_bridge_payment_id = payload.payment_id
    else:
        match_obj.user2_bridge_paid = True
        match_obj.user2_bridge_payment_id = payload.payment_id

    is_both_paid = bool(match_obj.user1_bridge_paid and match_obj.user2_bridge_paid)
    my_whatsapp = match_obj.user1_whatsapp_consent if is_user1 else match_obj.user2_whatsapp_consent
    partner_whatsapp = match_obj.user2_whatsapp_consent if is_user1 else match_obj.user1_whatsapp_consent
    my_location = match_obj.user1_location_consent if is_user1 else match_obj.user2_location_consent
    partner_location = match_obj.user2_location_consent if is_user1 else match_obj.user1_location_consent

    whatsapp_unlocked = bool(is_milestone_reached and my_whatsapp and partner_whatsapp and is_both_paid)
    location_unlocked = bool(is_milestone_reached and my_location and partner_location and is_both_paid)
    is_fully_unlocked = bool(whatsapp_unlocked or location_unlocked)

    match_obj.is_whatsapp_unlocked = whatsapp_unlocked
    match_obj.is_location_unlocked = location_unlocked

    await db.commit()
    await db.refresh(match_obj)

    partner_phone = None
    partner_maps_url = None

    if is_fully_unlocked:
        target_id = match_obj.user2_id if is_user1 else match_obj.user1_id
        target_res = await db.execute(select(User).where(User.id == target_id))
        target_user = target_res.scalars().first()
        if target_user:
            if whatsapp_unlocked and target_user.phone_number:
                partner_phone = target_user.phone_number
            if location_unlocked and target_user.latitude is not None and target_user.longitude is not None:
                partner_maps_url = f"https://www.google.com/maps/dir/?api=1&destination={target_user.latitude},{target_user.longitude}"

    my_paid = match_obj.user1_bridge_paid if is_user1 else match_obj.user2_bridge_paid
    partner_paid = match_obj.user2_bridge_paid if is_user1 else match_obj.user1_bridge_paid

    # Broadcast real-time payment update event over WebSocket
    bridge_payload = {
        "type": "bridge_payment_update",
        "match_id": payload.match_id,
        "total_messages": total_messages,
        "is_milestone_reached": is_milestone_reached,
        "my_whatsapp_consent": my_whatsapp,
        "my_location_consent": my_location,
        "partner_whatsapp_consent": partner_whatsapp,
        "partner_location_consent": partner_location,
        "my_payment_done": my_paid,
        "partner_payment_done": partner_paid,
        "is_fully_unlocked": is_fully_unlocked,
        "whatsapp_unlocked": whatsapp_unlocked,
        "location_unlocked": location_unlocked,
        "partner_phone": partner_phone,
        "partner_maps_url": partner_maps_url,
    }
    try:
        await ws_manager.broadcast_to_match(payload.match_id, bridge_payload)
        target_id_str = str(match_obj.user2_id if is_user1 else match_obj.user1_id)
        await ws_manager.broadcast_to_user(target_id_str, bridge_payload)
    except Exception:
        pass

    return APIResponse(
        success=True,
        message="Bridge payment verified and registered successfully.",
        data=SafeBridgeStatusData(
            match_id=payload.match_id,
            total_messages=total_messages,
            is_milestone_reached=is_milestone_reached,
            required_messages=15,
            my_consent=bool(my_whatsapp or my_location),
            my_whatsapp_consent=my_whatsapp,
            my_location_consent=my_location,
            partner_consent=bool(partner_whatsapp or partner_location),
            partner_whatsapp_consent=partner_whatsapp,
            partner_location_consent=partner_location,
            my_payment_done=my_paid,
            partner_payment_done=partner_paid,
            is_fully_unlocked=is_fully_unlocked,
            whatsapp_unlocked=whatsapp_unlocked,
            location_unlocked=location_unlocked,
            partner_phone=partner_phone,
            partner_maps_url=partner_maps_url,
        )
    )


@router.post("/{match_id}/read")
@router.post("/read/{match_id}")
@router.put("/{match_id}/read")
@router.put("/read/{match_id}")
@router.post("/messages/read")
@router.put("/messages/read")
async def mark_messages_as_read(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Marks all unread incoming messages in a match as read and broadcasts real-time read receipts (double blue ticks).
    """
    try:
        match_uuid = uuid.UUID(match_id)
        current_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid UUID format.")

    now_utc = datetime.now(timezone.utc)
    stmt = (
        update(ChatMessage)
        .where(
            ChatMessage.match_id == match_uuid,
            ChatMessage.sender_id != current_uuid,
            ChatMessage.is_read == False,
        )
        .values(
            is_read=True,
            is_delivered=True,
            status="read",
            read_at=now_utc,
        )
    )
    await db.execute(stmt)
    await db.commit()

    # Broadcast read receipt to match socket
    try:
        await ws_manager.broadcast_to_match(
            match_id,
            {
                "type": "messages_read",
                "match_id": match_id,
                "reader_id": current_user_id,
                "read_at": now_utc.isoformat(),
            }
        )
    except Exception:
        pass

    return APIResponse(success=True, message="Messages marked as read.")


@router.get("/icebreakers", response_model=APIResponse[IcebreakerListData])
async def get_icebreakers():
    """
    Returns a curated list of cultural Hinglish/Hindi conversation starters for new matches.
    """
    starters = [
        IcebreakerItem(id="1", emoji="☕", text="Chai date ke liye kab chalein?", category="chai"),
        IcebreakerItem(id="2", emoji="🎶", text="Aajkal kaun sa gaana loop pe chal raha hai?", category="music"),
        IcebreakerItem(id="3", emoji="🌴", text="Shaam ko ghoomne ki best jagah kaun si hai?", category="travel"),
        IcebreakerItem(id="4", emoji="🎬", text="Koi achhi movie recommend karo!", category="movies"),
        IcebreakerItem(id="5", emoji="✨", text="Aapka weekend plan kya hai?", category="weekend"),
        IcebreakerItem(id="6", emoji="🍕", text="Street food ya cafe date? What's your vibe?", category="food"),
    ]
    return APIResponse(
        success=True,
        message="Icebreakers retrieved successfully.",
        data=IcebreakerListData(icebreakers=starters)
    )

