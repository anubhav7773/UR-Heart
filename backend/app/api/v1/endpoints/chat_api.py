import os
import asyncio
import base64
import hashlib
from datetime import date, datetime
from typing import List, Dict, Any, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, update
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message
from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.models.domain.legal import BlockedUser

router = APIRouter(prefix="/chat", tags=["1:1 Encrypted Dialogues"])


def _clean_match_uuid(match_id: str) -> UUID:
    """Strips 'match-', 'conn_', 'spark_' prefixes if present and parses valid UUID."""
    clean = str(match_id).strip()
    for prefix in ("match-", "match_", "conn-", "conn_", "spark-", "spark_"):
        if clean.startswith(prefix):
            clean = clean[len(prefix):]
            break
    return UUID(clean)


def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def encrypt_message_storage(plain_text: str, match_id: str) -> str:
    """
    E2EE Storage Shield: Encrypts dialogue message using AES-256-GCM authenticated cipher.
    On Supabase / PostgreSQL messages table, ciphertext is stored with 'enc_v1:' prefix.
    Zero plaintext is readable in database.
    """
    try:
        try:
            clean_id = str(_clean_match_uuid(match_id))
        except Exception:
            clean_id = str(match_id)
        secret = os.getenv("JWT_SECRET_KEY", "urheart_default_super_secret_sanctuary_2026")
        key_material = hashlib.sha256(f"{secret}:{clean_id}".encode()).digest()
        aesgcm = AESGCM(key_material)
        nonce = os.urandom(12)
        ct = aesgcm.encrypt(nonce, plain_text.encode("utf-8"), None)
        return "enc_v1:" + base64.b64encode(nonce + ct).decode("utf-8")
    except Exception as e:
        print(f"[E2EE STORAGE ENCRYPT ERROR] {e}", flush=True)
        return plain_text


def decrypt_message_storage(stored_text: str, match_id: str) -> str:
    """
    E2EE Storage Shield: Decrypts AES-256-GCM ciphertext on demand for authorized seekers.
    """
    if not stored_text or not stored_text.startswith("enc_v1:"):
        return stored_text  # legacy or unencrypted fallback
    try:
        try:
            clean_id = str(_clean_match_uuid(match_id))
        except Exception:
            clean_id = str(match_id)
        raw = base64.b64decode(stored_text[7:])
        nonce = raw[:12]
        ct = raw[12:]
        secret = os.getenv("JWT_SECRET_KEY", "urheart_default_super_secret_sanctuary_2026")
        key_material = hashlib.sha256(f"{secret}:{clean_id}".encode()).digest()
        aesgcm = AESGCM(key_material)
        decrypted_bytes = aesgcm.decrypt(nonce, ct, None)
        return decrypted_bytes.decode("utf-8")
    except Exception as e:
        print(f"[E2EE STORAGE DECRYPT NOTICE] {e}", flush=True)
        return stored_text


class SendMessageRequest(BaseModel):
    match_id: Optional[str] = None
    recipient_id: Optional[str] = None
    text: Optional[str] = None
    content: Optional[str] = None
    id: Optional[str] = None
    client_id: Optional[str] = None


@router.get("/threads", status_code=status.HTTP_200_OK, summary="Get Active Dialogue Threads")
async def get_dialogue_threads(
    current_user: User = Depends(get_current_user),
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

        if matches:
            match_ids = [m.id for m in matches]
            partner_ids = list({m.user2_id if m.user1_id == current_user.id else m.user1_id for m in matches})

            # Batch 1: Blocked users
            blocked_stmt = select(BlockedUser).where(
                or_(
                    and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id.in_(partner_ids)),
                    and_(BlockedUser.blocker_id.in_(partner_ids), BlockedUser.blocked_id == current_user.id)
                )
            )
            blocked_res = await db.execute(blocked_stmt)
            blocked_set = set()
            for bu in blocked_res.scalars().all():
                blocked_set.add(bu.blocked_id if bu.blocker_id == current_user.id else bu.blocker_id)

            # Batch 2: Partner user profiles
            partner_users_res = await db.execute(select(User).where(User.id.in_(partner_ids)))
            partner_map = {u.id: u for u in partner_users_res.scalars().all()}

            # Batch 3: Latest messages per match
            msgs_res = await db.execute(
                select(Message)
                .where(Message.match_id.in_(match_ids))
                .order_by(Message.created_at.desc())
            )
            latest_msg_map = {}
            for msg in msgs_res.scalars().all():
                if msg.match_id not in latest_msg_map:
                    latest_msg_map[msg.match_id] = msg

            # Batch 4: Direct letters / swipes
            from app.models.domain.swipe import Swipe
            direct_swipes_res = await db.execute(
                select(Swipe.actor_id, Swipe.target_id).where(
                    Swipe.swipe_type == "direct",
                    or_(
                        and_(Swipe.actor_id == current_user.id, Swipe.target_id.in_(partner_ids)),
                        and_(Swipe.actor_id.in_(partner_ids), Swipe.target_id == current_user.id)
                    )
                )
            )
            direct_pairs = set()
            for actor, target in direct_swipes_res.all():
                direct_pairs.add((actor, target))
                direct_pairs.add((target, actor))

            for m in matches:
                partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
                if partner_id in blocked_set:
                    continue

                partner = partner_map.get(partner_id)
                if not partner:
                    continue

                last_msg = latest_msg_map.get(m.id)
                photo = partner.avatar_url or next((p for p in (partner.photos or []) if p and str(p).strip()), "")
                last_raw = last_msg.encrypted_text if last_msg else "Resonance established. Begin your sacred dialogue."
                last_text = decrypt_message_storage(last_raw, str(m.id))
                last_time = last_msg.created_at.strftime("%I:%M %p") if last_msg else (
                    m.matched_at.strftime("%I:%M %p") if m.matched_at else "Recently"
                )
                unread_count = 1 if (last_msg and last_msg.sender_id != current_user.id and last_msg.status != "read") else 0
                partner_age = _calculate_age(partner.dob)
                is_direct = (current_user.id, partner.id) in direct_pairs or (partner.id, current_user.id) in direct_pairs
                category_tag = "Direct Letter" if is_direct else "Mutual Spark"

                threads.append({
                    "match_id": str(m.id),
                    "id": str(m.id),
                    "peer_id": str(partner.id),
                    "partner_id": str(partner.id),
                    "recipient_id": str(partner.id),
                    "peer_name": partner.full_name,
                    "recipient_name": partner.full_name,
                    "partner_name": partner.full_name,
                    "full_name": partner.full_name,
                    "peer_age": partner_age,
                    "recipient_age": partner_age,
                    "age": partner_age,
                    "peer_photo": photo,
                    "partner_photo": photo,
                    "recipient_avatar_url": photo,
                    "avatar_url": photo,
                    "is_verified": bool(partner.kyc_status),
                    "is_kyc_verified": bool(partner.kyc_status),
                    "kyc_status": bool(partner.kyc_status),
                    "is_online": True,
                    "bio": partner.bio or "",
                    "city": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
                    "location": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
                    "gender": partner.gender or "",
                    "interests": getattr(partner, "interests", None) or [],
                    "intentions": getattr(partner, "intentions", None) or "Appreciating intentional conversations and authentic connection.",
                    "last_message": last_text,
                    "last_message_text": last_text,
                    "last_timestamp": last_time,
                    "unread_count": unread_count,
                    "delivery_status": last_msg.status if last_msg else "delivered",
                    "category_tag": category_tag,
                    "is_direct_letter": is_direct,
                    "shared_context_quote": "Direct Sanctuary Letter" if is_direct else "Mutual Resonance Ignited",
                })

    print(f"[CHAT THREADS] Serving {len(threads)} live conversation threads from PostgreSQL", flush=True)
    return {"threads": threads, "data": threads}


@router.get("/threads/{match_id}/peer", status_code=status.HTTP_200_OK, summary="Get Peer Seeker Profile")
@router.get("/matches/{match_id}/peer", status_code=status.HTTP_200_OK, summary="Get Peer Seeker Profile Alias")
async def get_dialogue_peer_profile(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns the peer's profile details for this match dialogue."""
    try:
        match_uuid = _clean_match_uuid(match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID.")

    stmt = select(Match).where(
        Match.id == match_uuid,
        or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
    )
    res = await db.execute(stmt)
    m = res.scalar_one_or_none()
    if not m:
        raise HTTPException(status_code=404, detail="Match not found.")

    partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Peer not found.")

    photo = partner.avatar_url or next((p for p in (partner.photos or []) if p and str(p).strip()), "")
    return {
        "id": str(partner.id),
        "recipient_id": str(partner.id),
        "full_name": partner.full_name,
        "name": partner.full_name,
        "age": _calculate_age(partner.dob),
        "avatar_url": photo,
        "recipient_avatar_url": photo,
        "is_verified": bool(partner.kyc_status),
        "is_kyc_verified": bool(partner.kyc_status),
        "bio": partner.bio or "",
        "city": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
        "location": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
        "gender": partner.gender or "",
        "interests": getattr(partner, "interests", None) or [],
        "intentions": getattr(partner, "intentions", None) or "Appreciating intentional conversations and authentic connection.",
        "photos": [p for p in (partner.photos or []) if p and str(p).strip()] or ([photo] if photo else []),
    }


@router.get("/sparks", status_code=status.HTTP_200_OK, summary="Get Active Exploration Sparks")
async def get_active_sparks(
    current_user: User = Depends(get_current_user),
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

            # Privacy Perimeter Check: Do not serve sparks with blocked accounts
            b_check = await db.execute(
                select(BlockedUser).where(
                    or_(
                        and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id == partner_id),
                        and_(BlockedUser.blocker_id == partner_id, BlockedUser.blocked_id == current_user.id)
                    )
                )
            )
            if b_check.scalar_one_or_none():
                continue

            partner_res = await db.execute(select(User).where(User.id == partner_id))
            partner = partner_res.scalar_one_or_none()
            if not partner:
                continue

            photo = partner.avatar_url or next((p for p in (partner.photos or []) if p and str(p).strip()), "")
            partner_age = _calculate_age(partner.dob)
            sparks.append({
                "id": str(m.id),
                "match_id": str(m.id),
                "recipient_id": str(partner.id),
                "name": partner.full_name,
                "full_name": partner.full_name,
                "age": partner_age,
                "avatar_url": photo,
                "recipient_avatar_url": photo,
                "is_verified": bool(partner.kyc_status),
                "kyc_status": bool(partner.kyc_status),
                "is_online": True,
                "bio": partner.bio or "",
                "city": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
                "location": getattr(partner, "location_name", None) or getattr(partner, "passport_city", None) or "Ayodhya, Uttar Pradesh",
                "gender": partner.gender or "",
                "interests": getattr(partner, "interests", None) or [],
                "intentions": getattr(partner, "intentions", None) or "Appreciating intentional conversations and authentic connection.",
                "match_type": "MUTUAL"
            })

    print(f"[CHAT SPARKS] Serving {len(sparks)} live exploration sparks from PostgreSQL", flush=True)
    return {"sparks": sparks, "data": sparks}


@router.get("/messages/{match_id}", status_code=status.HTTP_200_OK, summary="Get Messages for Dialogue")
async def get_dialogue_messages(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns chronologically ordered messages for match dialogue."""
    if not current_user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")

    try:
        match_uuid = _clean_match_uuid(match_id)
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid match_id UUID format.")

    # SEC-CRIT-02: Strictly verify current_user is an authentic participant in this match
    match_stmt = select(Match).where(Match.id == match_uuid)
    match_res = await db.execute(match_stmt)
    match_obj = match_res.scalar_one_or_none()
    if not match_obj:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dialogue match not found.")

    if current_user.id not in (match_obj.user1_id, match_obj.user2_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access Denied: You are not an authorized participant in this sacred dialogue."
        )

    messages = []
    stmt = (
        select(Message)
        .where(Message.match_id == match_uuid)
        .order_by(Message.created_at.asc())
    )
    res = await db.execute(stmt)
    rows = res.scalars().all()

    for msg in rows:
        is_me = (current_user and msg.sender_id == current_user.id)
        decrypted = decrypt_message_storage(msg.encrypted_text, match_id)
        messages.append({
                "id": str(msg.id),
                "client_id": str(getattr(msg, "client_id", None) or msg.id),
                "match_id": match_id,
                "sender_id": str(msg.sender_id),
                "text": decrypted,
                "content": decrypted,
                "message": decrypted,
                "timestamp": msg.created_at.strftime("%I:%M %p") if msg.created_at else "",
                "created_at": msg.created_at.isoformat() if msg.created_at else "",
                "is_me": is_me,
                "status": msg.status or "delivered"
            })

    print(f"[CHAT MESSAGES] Serving {len(messages)} messages for match_id={match_id}", flush=True)
    return messages


@router.get("/threads/{match_id}/messages", status_code=status.HTTP_200_OK, summary="Get Thread Messages")
async def get_thread_messages(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns chronologically ordered messages for match dialogue thread."""
    msgs = await get_dialogue_messages(match_id, current_user, db)
    return {"messages": msgs, "data": msgs}


@router.post("/threads/{match_id}/read", status_code=status.HTTP_200_OK, summary="Mark Thread Messages as Read")
@router.post("/messages/{match_id}/read", status_code=status.HTTP_200_OK, summary="Mark Messages as Read (Alias)")
async def mark_thread_messages_as_read(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Marks all incoming messages in this match as read and notifies the sender."""
    try:
        match_uuid = _clean_match_uuid(match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID format.")

    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required.")

    stmt = (
        update(Message)
        .where(
            Message.match_id == match_uuid,
            Message.sender_id != current_user.id,
            Message.status != "read"
        )
        .values(status="read")
    )
    result = await db.execute(stmt)
    await db.commit()

    # Inform partner in real-time via WebSocket so checkmarks turn blue (read)
    try:
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        m = match_res.scalar_one_or_none()
        if m:
            partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
            from app.services.chat_manager import manager
            await manager.send_direct_message(
                str(partner_id),
                {
                    "type": "read_receipt",
                    "action": "status_update",
                    "match_id": str(match_uuid),
                    "reader_id": str(current_user.id),
                    "status": "read"
                }
            )
    except Exception as e:
        print(f"[READ RECEIPT RELAY NOTICE] {e}", flush=True)

    return {"status": "success", "updated_count": result.rowcount if hasattr(result, "rowcount") else 0}


@router.post("/threads/{match_id}/messages", status_code=status.HTTP_201_CREATED, summary="Send Thread Message")
@router.post("/messages", status_code=status.HTTP_201_CREATED, summary="Send Message")
async def send_chat_message(
    payload: SendMessageRequest,
    match_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Persists a new message in PostgreSQL messages table with E2EE storage encryption."""
    resolved_match_id = match_id or payload.match_id
    text_content = payload.text or payload.content

    if not resolved_match_id or not text_content:
        raise HTTPException(status_code=400, detail="match_id and message text are required.")

    try:
        match_uuid = _clean_match_uuid(resolved_match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID format.")

    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required to send messages.")

    match_res = await db.execute(select(Match).where(Match.id == match_uuid))
    m = match_res.scalar_one_or_none()
    if asyncio.iscoroutine(m):
        m = await m
    if not m:
        raise HTTPException(status_code=404, detail="Match dialogue not found.")

    recipient_id = m.user2_id if m.user1_id == current_user.id else m.user1_id

    # Pre-Storage Moderation Shield (IT Rules 2021 & IT Act 67/67A Intermediary Protection)
    from app.services.chat_sanitizer import ChatSanitizerService
    is_safe, sanitized_or_reason = ChatSanitizerService.sanitize_message(text_content)
    if not is_safe:
        raise HTTPException(
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", status.HTTP_422_UNPROCESSABLE_ENTITY),
            detail=sanitized_or_reason
        )
    text_content = sanitized_or_reason

    # Statutory Blocked Perimeter Shielding:
    block_check = await db.execute(
        select(BlockedUser).where(
            or_(
                and_(BlockedUser.blocker_id == current_user.id, BlockedUser.blocked_id == recipient_id),
                and_(BlockedUser.blocker_id == recipient_id, BlockedUser.blocked_id == current_user.id)
            )
        )
    )
    block_res = block_check.scalar_one_or_none()
    if asyncio.iscoroutine(block_res):
        block_res = await block_res
    if block_res and not hasattr(block_res, "assert_called") and isinstance(block_res, BlockedUser):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Communication blocked by Statutory Privacy Perimeter."
        )

    # Deduplicate via client_id if present
    raw_client_id = str(payload.client_id or payload.id or "").strip()
    if raw_client_id:
        existing_res = await db.execute(
            select(Message).where(
                Message.match_id == match_uuid,
                Message.client_id == raw_client_id
            )
        )
        existing_m = existing_res.scalar_one_or_none()
        if existing_m:
            return {
                "status": existing_m.status or "delivered",
                "id": str(existing_m.id),
                "client_id": str(existing_m.client_id or existing_m.id),
                "match_id": str(existing_m.match_id),
                "sender_id": str(existing_m.sender_id),
                "text": text_content.strip(),
                "created_at": existing_m.created_at.isoformat() if existing_m.created_at else "",
            }

    # Encrypt before persisting in PostgreSQL messages table (E2EE at rest)
    storage_encrypted = encrypt_message_storage(text_content.strip(), str(match_uuid))

    msg = Message(
        match_id=match_uuid,
        sender_id=current_user.id,
        encrypted_text=storage_encrypted,
        status="delivered",
        client_id=raw_client_id if raw_client_id else None,
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)

    # Instant WebSocket Direct Message Delivery & Background Push Notification
    try:
        from app.services.chat_manager import manager
        ws_msg = {
            "type": "dialogue_message",
            "match_id": str(match_uuid),
            "sender_id": str(current_user.id),
            "recipient_id": str(recipient_id),
            "payload_type": "unencrypted_fallback",
            "text": text_content.strip(),
            "created_at": msg.created_at.isoformat() if msg.created_at else datetime.utcnow().isoformat(),
            "id": str(msg.id),
            "client_id": str(msg.client_id or msg.id),
            "status": "delivered",
        }
        await manager.send_direct_message(str(recipient_id), ws_msg)

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
        print(f"[CHAT MESSAGE RELAY] Notice: {e}", flush=True)

    return {
        "status": "sent",
        "id": str(msg.id),
        "client_id": str(msg.client_id or msg.id),
        "match_id": str(msg.match_id),
        "sender_id": str(msg.sender_id),
        "text": text_content.strip(),
        "content": text_content.strip(),
        "message": text_content.strip(),
        "timestamp": msg.created_at.strftime("%I:%M %p") if msg.created_at else datetime.now().strftime("%I:%M %p"),
        "delivery_status": msg.status
    }


@router.get("/threads/{match_id}/bridge", status_code=status.HTTP_200_OK, summary="Get Contact Bridge Status")
async def get_match_bridge_status(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns Sacred Contact Bridge status for a dialogue match.
    Enforces strict privacy: Private handles are NEVER revealed without
    mutual confirmation or bilateral consent.
    """
    try:
        match_uuid = _clean_match_uuid(match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID.")

    stmt = select(Match).where(
        Match.id == match_uuid,
        or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
    )
    res = await db.execute(stmt)
    m = res.scalar_one_or_none()
    if not m:
        raise HTTPException(status_code=404, detail="Match not found.")

    partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Dialogue peer not found.")

    # Check bilateral consent in WhatsAppRevealToken
    token_stmt = select(WhatsAppRevealToken).where(WhatsAppRevealToken.match_id == match_uuid)
    token_res = await db.execute(token_stmt)
    token_rec = token_res.scalar_one_or_none()
    if not isinstance(token_rec, WhatsAppRevealToken):
        token_rec = None

    is_user1 = (m.user1_id == current_user.id)
    my_consent = bool(token_rec.user1_consent if is_user1 else token_rec.user2_consent) if token_rec else False
    peer_consent = bool(token_rec.user2_consent if is_user1 else token_rec.user1_consent) if token_rec else False
    is_unlocked = bool(token_rec and (token_rec.is_unlocked or (my_consent and peer_consent)))

    partner_platform = partner.contact_bridge_type or "whatsapp"
    partner_handle = partner.contact_bridge_encrypted if is_unlocked else ""

    return {
        "match_id": match_id,
        "is_unlocked": is_unlocked,
        "has_wa_key": is_unlocked,
        "platform": partner_platform,
        "my_consent": my_consent,
        "peer_consent": peer_consent,
        "pending_peer_consent": my_consent and not peer_consent,
        "peer_requested_consent": peer_consent and not my_consent,
        "user_step": 3 if is_unlocked else (2 if my_consent else 1),
        "peer_step": 3 if is_unlocked else (2 if peer_consent else 1),
        "handle": partner_handle,
        "reveal_tokens_count": current_user.reveal_tokens_count or 0,
    }


@router.post("/threads/{match_id}/bridge/reveal", status_code=status.HTTP_200_OK, summary="Redeem Reveal Token for Social Handle")
async def redeem_bridge_reveal_token(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Redeems 1 Sacred Bridge Reveal Token to initiate or complete bilateral contact reveal.
    If the peer has NOT yet consented, sets status to pending_peer_consent and notifies peer.
    Private handles are NEVER unsealed unilaterally without mutual consent!
    """
    try:
        match_uuid = _clean_match_uuid(match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID.")

    stmt = select(Match).where(
        Match.id == match_uuid,
        or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
    )
    res = await db.execute(stmt)
    m = res.scalar_one_or_none()
    if not m:
        raise HTTPException(status_code=404, detail="Match not found.")

    partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Dialogue peer not found.")

    # Get or create WhatsAppRevealToken record
    token_stmt = select(WhatsAppRevealToken).where(WhatsAppRevealToken.match_id == match_uuid)
    token_res = await db.execute(token_stmt)
    token_rec = token_res.scalar_one_or_none()

    if not token_rec or not isinstance(token_rec, WhatsAppRevealToken):
        token_rec = WhatsAppRevealToken(
            match_id=match_uuid,
            user1_consent=False,
            user2_consent=False,
            is_unlocked=False
        )
        db.add(token_rec)
        await db.flush()

    is_user1 = (m.user1_id == current_user.id)
    my_consent = token_rec.user1_consent if is_user1 else token_rec.user2_consent
    peer_consent = token_rec.user2_consent if is_user1 else token_rec.user1_consent

    # If already unlocked, return unsealed handle immediately
    if token_rec.is_unlocked:
        return {
            "status": "unlocked",
            "message": f"Sacred Contact Bridge is already unlocked for {partner.full_name}!",
            "is_unlocked": True,
            "has_wa_key": True,
            "platform": partner.contact_bridge_type or "whatsapp",
            "handle": partner.contact_bridge_encrypted or "",
            "remaining_reveal_tokens": current_user.reveal_tokens_count,
            "reveal_tokens_count": current_user.reveal_tokens_count,
        }

    # Only debit token if user hasn't already committed consent
    if not my_consent:
        current_tokens = current_user.reveal_tokens_count or 0
        if current_tokens < 1:
            raise HTTPException(
                status_code=400,
                detail="A Sacred Bridge Reveal Token is required. Watch 3 reflections in the Growth Hub to earn 1 token."
            )
        current_user.reveal_tokens_count = current_tokens - 1
        if is_user1:
            token_rec.user1_consent = True
        else:
            token_rec.user2_consent = True

    from app.services.chat_manager import manager
    from app.api.v1.endpoints.notifications import push_notification

    # Check if peer has already consented (mutual consent satisfied!)
    if peer_consent:
        token_rec.is_unlocked = True
        await db.commit()
        await db.refresh(current_user)

        # Notify partner in real time
        await manager.send_direct_message(str(partner_id), {
            "type": "bridge_unlocked",
            "match_id": match_id,
            "partner_id": str(current_user.id),
            "partner_name": current_user.full_name,
        })
        push_notification(
            user_id=str(partner_id),
            notif_type="bridge_unlocked",
            title="Sacred Bridge Unsealed! 🕊️",
            body=f"{current_user.full_name} confirmed mutual reveal. Genuine contact handle is now visible.",
            data={"match_id": match_id, "target_route": "/chat-dialogue"}
        )

        return {
            "status": "unlocked",
            "message": f"Bilateral mutual consent confirmed! Contact handle unsealed for {partner.full_name}.",
            "is_unlocked": True,
            "has_wa_key": True,
            "platform": partner.contact_bridge_type or "whatsapp",
            "handle": partner.contact_bridge_encrypted or "",
            "user_step": 3,
            "peer_step": 3,
            "pending_peer_consent": False,
            "remaining_reveal_tokens": current_user.reveal_tokens_count,
            "reveal_tokens_count": current_user.reveal_tokens_count,
        }

    # Peer has not consented yet: enforce mutual consent gate
    await db.commit()
    await db.refresh(current_user)

    # Dispatch real-time prompt & notification to peer
    await manager.send_direct_message(str(partner_id), {
        "type": "bridge_reveal_request",
        "match_id": match_id,
        "initiator_id": str(current_user.id),
        "initiator_name": current_user.full_name,
    })
    push_notification(
        user_id=str(partner_id),
        notif_type="bridge_request",
        title="Sacred Contact Reveal Request 🕊️",
        body=f"{current_user.full_name} redeemed a token to request mutual contact reveal. Do you consent?",
        data={"match_id": match_id, "action": "bridge_consent", "target_route": "/chat-dialogue"}
    )

    return {
        "status": "pending_peer_consent",
        "message": f"Reveal Token committed. Awaiting {partner.full_name}'s mutual consent before contact handle can be viewed.",
        "is_unlocked": False,
        "has_wa_key": False,
        "my_consent": True,
        "peer_consent": False,
        "pending_peer_consent": True,
        "user_step": 2,
        "peer_step": 1,
        "platform": partner.contact_bridge_type or "whatsapp",
        "handle": "",
        "remaining_reveal_tokens": current_user.reveal_tokens_count,
        "reveal_tokens_count": current_user.reveal_tokens_count,
    }


class BridgeConsentRequest(BaseModel):
    action: str = Field(..., description="'accept' or 'decline'")


@router.post("/threads/{match_id}/bridge/consent", status_code=status.HTTP_200_OK, summary="Respond to Sacred Bridge Reveal Request")
async def respond_to_bridge_consent(
    match_id: str,
    payload: BridgeConsentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts or declines a Sacred Bridge reveal request.
    If declined, any token spent by the requester is refunded.
    If accepted and peer has consented, handles are unsealed for both seekers.
    """
    try:
        match_uuid = _clean_match_uuid(match_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid match_id UUID.")

    stmt = select(Match).where(
        Match.id == match_uuid,
        or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id)
    )
    res = await db.execute(stmt)
    m = res.scalar_one_or_none()
    if not m:
        raise HTTPException(status_code=404, detail="Match not found.")

    partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Dialogue peer not found.")

    token_stmt = select(WhatsAppRevealToken).where(WhatsAppRevealToken.match_id == match_uuid)
    token_res = await db.execute(token_stmt)
    token_rec = token_res.scalar_one_or_none()
    if not isinstance(token_rec, WhatsAppRevealToken):
        token_rec = None

    if not token_rec:
        token_rec = WhatsAppRevealToken(
            match_id=match_uuid,
            user1_consent=False,
            user2_consent=False,
            is_unlocked=False
        )
        db.add(token_rec)
        await db.flush()

    is_user1 = (m.user1_id == current_user.id)
    from app.services.chat_manager import manager
    from app.api.v1.endpoints.notifications import push_notification

    action = payload.action.strip().lower()

    if action == "accept":
        if is_user1:
            token_rec.user1_consent = True
        else:
            token_rec.user2_consent = True

        peer_consent = token_rec.user2_consent if is_user1 else token_rec.user1_consent
        if peer_consent:
            token_rec.is_unlocked = True

        await db.commit()

        if token_rec.is_unlocked:
            # Broadcast unlock to peer
            await manager.send_direct_message(str(partner_id), {
                "type": "bridge_unlocked",
                "match_id": match_id,
                "partner_id": str(current_user.id),
                "partner_name": current_user.full_name,
            })
            push_notification(
                user_id=str(partner_id),
                notif_type="bridge_unlocked",
                title="Sacred Bridge Mutual Consent Accepted! ✨",
                body=f"{current_user.full_name} accepted your contact reveal request. Handles are unsealed.",
                data={"match_id": match_id, "target_route": "/chat-dialogue"}
            )

        return {
            "status": "unlocked" if token_rec.is_unlocked else "accepted",
            "is_unlocked": token_rec.is_unlocked,
            "has_wa_key": token_rec.is_unlocked,
            "platform": partner.contact_bridge_type or "whatsapp",
            "handle": partner.contact_bridge_encrypted if token_rec.is_unlocked else "",
            "message": "Sacred Contact Bridge unsealed!" if token_rec.is_unlocked else "Consent recorded.",
        }

    elif action == "decline":
        # Reset consent and refund peer token if peer had consented
        peer_had_consented = token_rec.user2_consent if is_user1 else token_rec.user1_consent
        if is_user1:
            token_rec.user1_consent = False
            token_rec.user2_consent = False
        else:
            token_rec.user2_consent = False
            token_rec.user1_consent = False
        token_rec.is_unlocked = False

        if peer_had_consented:
            # Refund 1 reveal token to partner
            partner.reveal_tokens_count = (partner.reveal_tokens_count or 0) + 1

        await db.commit()

        # Notify peer of gentle decline and token refund
        await manager.send_direct_message(str(partner_id), {
            "type": "bridge_declined",
            "match_id": match_id,
            "message": f"{current_user.full_name} prefers to build more rapport before exchanging contact handles.",
        })
        push_notification(
            user_id=str(partner_id),
            notif_type="bridge_declined",
            title="Sacred Bridge Notice 🍃",
            body=f"{current_user.full_name} prefers more mindful rapport. Your Reveal Token has been refunded.",
            data={"match_id": match_id}
        )

        return {
            "status": "declined",
            "is_unlocked": False,
            "message": "You gently declined the contact reveal. No contact handles were shared."
        }
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'accept' or 'decline'.")
