from datetime import date, datetime
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, not_, func

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match
from app.models.domain.message import Message

router = APIRouter(prefix="/resonances", tags=["Resonances & Matches"])


def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return max(18, today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day)))


@router.get("/incoming", status_code=status.HTTP_200_OK, summary="Get Incoming Likes")
@router.get("/likes", status_code=status.HTTP_200_OK, summary="Get Incoming Likes Alias")
async def get_incoming_likes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns incoming admirers who liked the user profile from PostgreSQL.
    Excludes candidates who are ALREADY active mutual matches so profiles are never duplicated across tabs.
    """
    likes = []
    if current_user:
        # Check active match existence via NOT EXISTS to avoid SQL NULL subquery traps
        active_match_exists = select(Match.id).where(
            or_(
                and_(Match.user1_id == current_user.id, Match.user2_id == User.id),
                and_(Match.user2_id == current_user.id, Match.user1_id == User.id)
            ),
            Match.is_active == True
        ).exists()

        stmt = (
            select(Swipe, User)
            .join(User, User.id == Swipe.actor_id)
            .where(
                Swipe.target_id == current_user.id,
                func.lower(Swipe.swipe_type).in_(["like", "direct", "superlike"]),
                User.deleted_at.is_(None),
                not_(active_match_exists)
            )
            .order_by(Swipe.created_at.desc())
            .limit(50)
        )
        res = await db.execute(stmt)
        rows = res.all()

        for swipe, sender in rows:
            photo = sender.avatar_url or next((p for p in (sender.photos or []) if p and str(p).strip()), "")
            is_direct = (swipe.swipe_type == "direct")
            likes.append({
                "id": f"like_{swipe.id}",
                "sender_id": str(sender.id),
                "user_id": str(sender.id),
                "full_name": sender.full_name,
                "name": sender.full_name,
                "age": _calculate_age(sender.dob),
                "photo_url": photo,
                "avatar_url": photo,
                "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
                "relative_time": "Recently",
                "shared_interest": sender.profession or "Mindful Connection",
                "match_score": 93,
                "swipe_type": swipe.swipe_type or "like",
                "is_direct_letter": is_direct,
                "category_tag": "Direct Letter" if is_direct else "Liked You",
                "letter_snippet": "Direct Sanctuary Letter 💌" if is_direct else None,
                "bio": sender.bio or "",
                "location": getattr(sender, "location_name", None) or "Ayodhya, Uttar Pradesh",
                "is_verified": bool(sender.kyc_status),
            })

    print(f"[RESONANCES] Serving {len(likes)} live incoming un-matched likes from PostgreSQL", flush=True)
    return {"likes": likes, "data": likes}


@router.get("/mutual", status_code=status.HTTP_200_OK, summary="Get Mutual Connections")
async def get_mutual_connections(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns mutual matches eligible for 1:1 dialogue from PostgreSQL.
    Categorizes whether the match was established via a Direct Sanctuary Letter or a Mutual Like.
    """
    connections = []
    if current_user:
        stmt = (
            select(Match)
            .where(
                or_(Match.user1_id == current_user.id, Match.user2_id == current_user.id),
                Match.is_active == True
            )
            .order_by(Match.matched_at.desc())
            .limit(20)
        )
        res = await db.execute(stmt)
        matches = res.scalars().all()

        for m in matches:
            partner_id = m.user2_id if m.user1_id == current_user.id else m.user1_id
            partner_res = await db.execute(select(User).where(User.id == partner_id))
            partner = partner_res.scalar_one_or_none()
            if not partner:
                continue

            # Determine whether this match was created via Direct Letter
            ds_stmt = select(Swipe).where(
                or_(
                    and_(Swipe.actor_id == current_user.id, Swipe.target_id == partner.id),
                    and_(Swipe.actor_id == partner.id, Swipe.target_id == current_user.id)
                ),
                Swipe.swipe_type == "direct"
            ).limit(1)
            ds_res = await db.execute(ds_stmt)
            is_direct = ds_res.scalar_one_or_none() is not None
            category_tag = "Direct Letter" if is_direct else "Mutual Resonance"

            # Fetch last message from PostgreSQL messages table
            msg_stmt = (
                select(Message)
                .where(Message.match_id == m.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            msg_res = await db.execute(msg_stmt)
            last_msg = msg_res.scalar_one_or_none()

            from app.api.v1.endpoints.chat_api import decrypt_message_storage
            last_text = decrypt_message_storage(last_msg.encrypted_text, str(m.id)) if last_msg else (
                "Direct Sanctuary Letter received. Open to reply." if is_direct else "Resonance established. Begin your sacred dialogue."
            )

            photo = partner.avatar_url or next((p for p in (partner.photos or []) if p and str(p).strip()), "")
            partner_age = _calculate_age(partner.dob)
            connections.append({
                "id": f"conn_{m.id}",
                "match_id": str(m.id),
                "partner_id": str(partner.id),
                "recipient_id": str(partner.id),
                "full_name": partner.full_name,
                "name": partner.full_name,
                "age": partner_age,
                "photo_url": photo,
                "avatar_url": photo,
                "recipient_avatar_url": photo,
                "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
                "matched_time": m.matched_at.strftime("%I:%M %p") if m.matched_at else "Today",
                "last_snippet": last_text,
                "has_unread": True if (last_msg and last_msg.sender_id != current_user.id and last_msg.status != "read") else False,
                "bridge_type": "WhatsApp Enclave",
                "bridge_status": "Key 1/3 revealed",
                "category_tag": category_tag,
                "is_direct_letter": is_direct,
                "is_verified": bool(partner.kyc_status),
                "bio": partner.bio or "",
                "location": getattr(partner, "location_name", None) or "Ayodhya, Uttar Pradesh",
                "gender": partner.gender or "",
                "interests": getattr(partner, "interests", None) or [],
            })

    print(f"[RESONANCES] Serving {len(connections)} live mutual connections from PostgreSQL", flush=True)
    return {"connections": connections, "data": connections}
