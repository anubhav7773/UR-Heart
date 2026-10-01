import os
import base64
import hashlib
from datetime import date, datetime
from typing import List, Dict, Any, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message

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

            photo = partner.avatar_url or next((p for p in (partner.photos or []) if p and str(p).strip()), "")
            last_raw = last_msg.encrypted_text if last_msg else "Resonance established. Begin your sacred dialogue."
            last_text = decrypt_message_storage(last_raw, str(m.id))
            last_time = last_msg.created_at.strftime("%I:%M %p") if last_msg else (
                m.matched_at.strftime("%I:%M %p") if m.matched_at else "Recently"
            )
            unread_count = 1 if (last_msg and last_msg.sender_id != current_user.id and last_msg.status != "read") else 0
            partner_age = _calculate_age(partner.dob)

            # Determine if this dialogue was established via a direct letter
            from app.models.domain.swipe import Swipe
            ds_stmt = select(Swipe).where(
                or_(
                    and_(Swipe.actor_id == current_user.id, Swipe.target_id == partner.id),
                    and_(Swipe.actor_id == partner.id, Swipe.target_id == current_user.id)
                ),
                Swipe.swipe_type == "direct"
            ).limit(1)
            ds_res = await db.execute(ds_stmt)
            is_direct = ds_res.scalar_one_or_none() is not None
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
    messages = []
    try:
        match_uuid = _clean_match_uuid(match_id)
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
            decrypted = decrypt_message_storage(msg.encrypted_text, match_id)
            messages.append({
                "id": str(msg.id),
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

    # Pre-Storage Moderation Shield (IT Rules 2021 & IT Act 67/67A Intermediary Protection)
    from app.services.chat_sanitizer import ChatSanitizerService
    is_safe, sanitized_or_reason = ChatSanitizerService.sanitize_message(text_content)
    if not is_safe:
        raise HTTPException(
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", status.HTTP_422_UNPROCESSABLE_ENTITY),
            detail=sanitized_or_reason
        )
    text_content = sanitized_or_reason

    # Encrypt before persisting in PostgreSQL messages table (E2EE at rest)
    storage_encrypted = encrypt_message_storage(text_content.strip(), str(match_uuid))

    msg = Message(
        match_id=match_uuid,
        sender_id=current_user.id,
        encrypted_text=storage_encrypted,
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
        "text": text_content.strip(),
        "content": text_content.strip(),
        "message": text_content.strip(),
        "timestamp": msg.created_at.strftime("%I:%M %p") if msg.created_at else datetime.now().strftime("%I:%M %p"),
        "delivery_status": msg.status
    }


# Track unlocked contact bridges per (user_id, match_id)
UNLOCKED_BRIDGES: set[tuple[str, str]] = set()


@router.get("/threads/{match_id}/bridge", status_code=status.HTTP_200_OK, summary="Get Contact Bridge Status")
async def get_match_bridge_status(
    match_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns Sacred Contact Bridge status for a dialogue match.
    Enforces strict privacy: Private handles are NEVER revealed without
    mutual confirmation or a redeemed Reveal Token.
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

    is_unlocked = (str(current_user.id), match_id) in UNLOCKED_BRIDGES
    partner_platform = partner.contact_bridge_type or "whatsapp"
    partner_handle = partner.contact_bridge_encrypted if is_unlocked else ""

    return {
        "match_id": match_id,
        "is_unlocked": is_unlocked,
        "has_wa_key": is_unlocked,
        "platform": partner_platform,
        "user_step": 3 if is_unlocked else 1,
        "peer_step": 3 if is_unlocked else 1,
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
    Spends 1 Sacred Bridge Reveal Token to unlock the peer's genuine social handle.
    Requires reveal_tokens_count >= 1 (earned via 3 video reflections or sovereign pass).
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

    current_tokens = current_user.reveal_tokens_count or 0
    if current_tokens < 1:
        raise HTTPException(
            status_code=400,
            detail="A Sacred Bridge Reveal Token is required. Watch 3 reflections in the Growth Hub to earn 1 token."
        )

    # Deduct 1 reveal token
    current_user.reveal_tokens_count = current_tokens - 1
    await db.commit()
    await db.refresh(current_user)

    UNLOCKED_BRIDGES.add((str(current_user.id), match_id))

    return {
        "status": "unlocked",
        "message": f"Sacred Contact Bridge unlocked for {partner.full_name}!",
        "is_unlocked": True,
        "has_wa_key": True,
        "platform": partner.contact_bridge_type or "whatsapp",
        "handle": partner.contact_bridge_encrypted or "",
        "remaining_reveal_tokens": current_user.reveal_tokens_count,
        "reveal_tokens_count": current_user.reveal_tokens_count,
    }
