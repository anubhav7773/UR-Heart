import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.models.domain.match import Match
from app.services.chat_manager import manager

async def process_whatsapp_ad_completion(
    user_id: UUID,
    match_id: UUID,
    db: AsyncSession
) -> Optional[WhatsAppRevealToken]:
    """
    Processes verified rewarded ad and executes unlock when both users hit 3 ads.
    Maintains the mutual 6-ad dual completion state machine.
    """
    stmt = (
        select(WhatsAppRevealToken, Match)
        .join(Match, Match.id == WhatsAppRevealToken.match_id)
        .where(WhatsAppRevealToken.match_id == match_id)
    )
    result = await db.execute(stmt)
    row = result.first() if hasattr(result, "first") and callable(result.first) else None

    if row:
        token_rec, match_rec = row
    else:
        match_stmt = select(Match).where(Match.id == match_id)
        match_res = await db.execute(match_stmt)
        match_rec = match_res.scalar_one_or_none() if hasattr(match_res, "scalar_one_or_none") else None
        if not match_rec:
            return None
        token_rec = WhatsAppRevealToken(
            match_id=match_id,
            user1_ads_count=0,
            user2_ads_count=0,
            is_unlocked=False
        )
        db.add(token_rec)
        await db.flush()

    # Increment counter for respective user (capped at 3)
    if match_rec.user1_id == user_id:
        if token_rec.user1_ads_count < 3:
            token_rec.user1_ads_count += 1
    elif match_rec.user2_id == user_id:
        if token_rec.user2_ads_count < 3:
            token_rec.user2_ads_count += 1

    # Check Dual-Completion Threshold (3 Ads Each)
    if token_rec.user1_ads_count >= 3 and token_rec.user2_ads_count >= 3:
        if not token_rec.is_unlocked:
            token_rec.is_unlocked = True
            token_rec.ephemeral_token = secrets.token_urlsafe(32)
            token_rec.expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

            # Broadcast real-time unlock event via WebSockets
            unlock_payload = {
                "event": "whatsapp_unlocked",
                "match_id": str(match_id),
                "ephemeral_token": token_rec.ephemeral_token,
                "expires_at": token_rec.expires_at.isoformat()
            }
            await manager.send_personal_message(unlock_payload, match_rec.user1_id)
            await manager.send_personal_message(unlock_payload, match_rec.user2_id)

    return token_rec
