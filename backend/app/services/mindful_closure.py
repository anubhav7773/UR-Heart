import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain.match import Match
from app.models.domain.message import Message
from app.models.domain.user import User
from app.api.v1.endpoints.notifications import push_notification
from app.services.chat_manager import manager


MINDFUL_CLOSURE_TEMPLATES = [
    {
        "id": "wavelength",
        "key": "wavelength",
        "title": "Gentle Wavelengths",
        "description": "Honor the connection while acknowledging differing paths",
        "text": "It was truly wonderful crossing paths, but I feel our wavelengths didn't quite align. Wishing you warmth and light on your journey! 🌸",
        "message": "It was truly wonderful crossing paths, but I feel our wavelengths didn't quite align. Wishing you warmth and light on your journey! 🌸",
        "icon": "spa",
    },
    {
        "id": "self_focus",
        "key": "self_focus",
        "title": "Self-Reflection & Space",
        "description": "Taking a mindful step back to focus inward",
        "text": "Stepping back to focus on myself and my own space right now. Thank you deeply for the mindful dialogue! ✨",
        "message": "Stepping back to focus on myself and my own space right now. Thank you deeply for the mindful dialogue! ✨",
        "icon": "self_improvement",
    },
    {
        "id": "different_resonance",
        "key": "different_resonance",
        "title": "Seeking Different Resonance",
        "description": "Honest and gentle clarity without pretense",
        "text": "I deeply appreciated our conversations, though I'm seeking a different resonance right now. Wishing you the very best! 🙏",
        "message": "I deeply appreciated our conversations, though I'm seeking a different resonance right now. Wishing you the very best! 🙏",
        "icon": "favorite_border",
    },
    {
        "id": "silent_bow",
        "key": "silent_bow",
        "title": "Silent Mindful Bow",
        "description": "Softly concluding without lingering unsaid words",
        "text": "A respectful silent bow. Softly concluding this dialogue without lingering unsaid words. 🍃",
        "message": "A respectful silent bow. Softly concluding this dialogue without lingering unsaid words. 🍃",
        "icon": "energy_savings_leaf",
    },
]

TEMPLATE_MAP = {t["id"]: t for t in MINDFUL_CLOSURE_TEMPLATES}
for t in MINDFUL_CLOSURE_TEMPLATES:
    TEMPLATE_MAP[t["key"]] = t


class MindfulClosureService:
    @staticmethod
    def get_templates() -> List[Dict]:
        return MINDFUL_CLOSURE_TEMPLATES

    @staticmethod
    async def evaluate_stale_conversations(db: AsyncSession) -> int:
        """
        Inactivity Detection (48 Hours):
        Evaluates active matches where no message has been sent for 48 consecutive hours.
        Switches status to 'stagnant' so Eva AI can offer mindful intercession.
        """
        now = datetime.now(timezone.utc)
        threshold = now - timedelta(hours=48)
        stmt = (
            select(Match)
            .where(
                Match.is_active == True,
                Match.closure_status.is_(None),
                or_(
                    Match.last_message_at < threshold,
                    and_(Match.last_message_at.is_(None), Match.matched_at < threshold),
                )
            )
        )
        res = await db.execute(stmt)
        stale_matches = res.scalars().all()
        count = 0
        for match in stale_matches:
            match.closure_status = "stagnant"
            count += 1
        if count > 0:
            await db.commit()
            print(f"[MINDFUL CLOSURE] Flagged {count} stagnant threads for mindful intercession.", flush=True)
        return count

    @staticmethod
    async def send_mindful_closure(
        db: AsyncSession,
        match_id: uuid.UUID,
        user_id: uuid.UUID,
        template_key: str,
        custom_note: Optional[str] = None
    ) -> Dict:
        """
        Executes 'Pass with Grace' mindful closure.
        - Updates Match closure_status to 'closed_with_grace'
        - Persists compassionate closing message into messages table (encrypted)
        - Dispatches gentle, non-punitive FCM notification & real-time WebSocket event
        - Soft-archives thread to 'Past Reflections'
        """
        stmt = select(Match).where(Match.id == match_id)
        res = await db.execute(stmt)
        match_obj = res.scalar_one_or_none()
        if not match_obj:
            raise ValueError("Dialogue match not found.")

        if user_id not in (match_obj.user1_id, match_obj.user2_id):
            raise ValueError("You are not an authorized participant in this dialogue.")

        if match_obj.closure_status == "closed_with_grace":
            raise ValueError("This dialogue has already been concluded with mindful grace.")

        partner_id = match_obj.user2_id if match_obj.user1_id == user_id else match_obj.user1_id

        # Determine closure note text
        if custom_note and custom_note.strip():
            closure_text = custom_note.strip()
        elif template_key in TEMPLATE_MAP:
            closure_text = TEMPLATE_MAP[template_key]["text"]
        else:
            closure_text = TEMPLATE_MAP["wavelength"]["text"]

        now = datetime.now(timezone.utc)
        match_obj.closure_status = "closed_with_grace"
        match_obj.closed_by_user_id = user_id
        match_obj.closed_at = now
        match_obj.closure_template_key = template_key
        match_obj.closure_note = closure_text
        match_obj.last_message_at = now

        # Insert closing message into messages table so it stays in transcript
        from app.api.v1.endpoints.chat_api import encrypt_message_storage
        encrypted_farewell = encrypt_message_storage(f"🍃 Mindful Closure: {closure_text}", str(match_id))
        msg = Message(
            match_id=match_id,
            sender_id=user_id,
            encrypted_text=encrypted_farewell,
            status="delivered",
            created_at=now
        )
        db.add(msg)
        await db.commit()
        await db.refresh(match_obj)

        # Retrieve sender profile
        sender_res = await db.execute(select(User).where(User.id == user_id))
        sender = sender_res.scalar_one_or_none()
        sender_name = sender.full_name if sender else "Soul Seeker"

        # Push peaceful notification to partner (zero negative shock / non-punitive)
        push_notification(
            user_id=str(partner_id),
            notif_type="mindful_closure",
            title=f"Gentle note from {sender_name} 🍃",
            body="A mindful closure was shared with you. Wishing you warmth on your path.",
            data={
                "match_id": str(match_id),
                "action": "open_chat",
                "type": "mindful_closure",
                "route": "/chat-dialogue"
            }
        )

        # Notify via real-time WebSocket if partner is active
        try:
            await manager.send_direct_message(str(partner_id), {
                "type": "mindful_closure",
                "match_id": str(match_id),
                "closed_by": str(user_id),
                "closed_by_user_id": str(user_id),
                "closure_status": "closed_with_grace",
                "note": closure_text,
                "closure_note": closure_text,
                "farewell_note": closure_text,
                "closed_at": now.isoformat()
            })
        except Exception as e:
            print(f"[MINDFUL CLOSURE WSS NOTICE] {e}", flush=True)

        return {
            "status": "closed_with_grace",
            "match_id": str(match_id),
            "closed_by_user_id": str(user_id),
            "closed_at": now.isoformat(),
            "closure_template_key": template_key,
            "closure_note": closure_text,
            "message": "Dialogue concluded with mindful grace."
        }

    @staticmethod
    async def get_closure_status(
        db: AsyncSession,
        match_id: uuid.UUID,
        user_id: uuid.UUID
    ) -> Dict:
        stmt = select(Match).where(Match.id == match_id)
        res = await db.execute(stmt)
        match_obj = res.scalar_one_or_none()
        if not match_obj:
            raise ValueError("Dialogue match not found.")

        if user_id not in (match_obj.user1_id, match_obj.user2_id):
            raise ValueError("You are not an authorized participant in this dialogue.")

        now = datetime.now(timezone.utc)
        last_time = match_obj.last_message_at or match_obj.matched_at
        hours_since_last = (now - last_time).total_seconds() / 3600 if last_time else 0
        is_stagnant = (match_obj.closure_status == "stagnant") or (
            match_obj.closure_status is None and hours_since_last >= 48
        )
        is_closed = match_obj.closure_status == "closed_with_grace"

        return {
            "match_id": str(match_id),
            "closure_status": match_obj.closure_status,
            "is_stagnant": is_stagnant,
            "is_closed": is_closed,
            "hours_since_last_message": round(hours_since_last, 1),
            "closed_by_user_id": str(match_obj.closed_by_user_id) if match_obj.closed_by_user_id else None,
            "closed_at": match_obj.closed_at.isoformat() if match_obj.closed_at else None,
            "closure_template_key": match_obj.closure_template_key,
            "closure_note": match_obj.closure_note,
            "templates": MINDFUL_CLOSURE_TEMPLATES
        }
