import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.blind_date import BlindDateMessage, BlindDateSession
from app.models.domain.user import User
from app.services.blind_date_matcher import BlindDateMatcherService

router = APIRouter(prefix="/blind-date", tags=["Blind Date Engine"])


class ResonateDecisionRequest(BaseModel):
    decision: str = Field(..., description="'resonate' or 'pass'")


class BlindDateMessageRequest(BaseModel):
    ciphertext: str = Field(..., min_length=1, max_length=2000)


class JoinQueueRequest(BaseModel):
    is_fast_track: bool = False


@router.get("/eligibility", status_code=status.HTTP_200_OK, summary="Check Blind Date Pass Eligibility")
async def check_blind_date_eligibility(
    current_user: User = Depends(get_current_user),
):
    """
    Checks if seeker has an active daily streak pass (1 pass/day) or stored bonus passes.
    """
    return BlindDateMatcherService.check_eligibility(current_user)


@router.post("/claim-ad-pass", status_code=status.HTTP_200_OK, summary="Claim Blind Date Pass via Rewarded Ad")
async def claim_blind_date_ad_pass(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Unlocks +1 Blind Date pass by watching a 30-sec rewarded ad.
    If the seeker's daily streak is inactive or broken, watching this ad also
    ignites/locks their streak for the day (1:1 Value Parity, viral loop).
    """
    return await BlindDateMatcherService.claim_ad_pass(db, current_user)


@router.post("/queue/join", status_code=status.HTTP_200_OK, summary="Join Blind Date Matchmaking Queue")
async def join_blind_date_queue(
    payload: Optional[JoinQueueRequest] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Enters the 3-gender bidirectional matching queue.
    If a compatible seeker is already waiting, immediately pairs them into a 5-minute timed session.
    Otherwise, enqueues the user in 'waiting' state.
    """
    is_fast_track = payload.is_fast_track if payload else False
    try:
        session, queue_entry = await BlindDateMatcherService.join_or_match_queue(
            db, current_user, is_fast_track=is_fast_track
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "message": str(e),
                "eligibility": BlindDateMatcherService.check_eligibility(current_user)
            }
        )

    if session:
        # Determine partner user ID
        partner_id = session.user2_id if session.user1_id == current_user.id else session.user1_id
        partner_res = await db.execute(select(User).where(User.id == partner_id))
        partner = partner_res.scalars().first()

        partner_payload = {}
        if partner:
            partner_payload = BlindDateMatcherService.mask_partner_for_session(
                session, current_user.id, partner
            )

        now = datetime.now(timezone.utc)
        remaining_seconds = max(0, int((session.expires_at - now).total_seconds()))

        return {
            "status": "matched",
            "session": {
                "id": str(session.id),
                "status": session.status,
                "started_at": session.started_at.isoformat() if session.started_at else None,
                "expires_at": session.expires_at.isoformat() if session.expires_at else None,
                "remaining_seconds": remaining_seconds,
                "icebreaker_prompt": session.icebreaker_prompt,
                "my_decision": session.user1_decision if session.user1_id == current_user.id else session.user2_decision,
                "partner": partner_payload
            }
        }

    return {
        "status": "waiting",
        "message": "Matching with a resonant soul...",
        "queue_entry": {
            "gender": queue_entry.gender,
            "interested_in": queue_entry.interested_in,
            "joined_at": queue_entry.joined_at.isoformat() if queue_entry.joined_at else None,
            "is_fast_track": queue_entry.is_fast_track
        }
    }



@router.get("/queue/status", status_code=status.HTTP_200_OK, summary="Poll Queue Status")
async def check_queue_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Polls current status of the seeker in the matchmaking queue.
    """
    session, queue_entry = await BlindDateMatcherService.check_queue_status(db, current_user.id)

    if session:
        partner_id = session.user2_id if session.user1_id == current_user.id else session.user1_id
        partner_res = await db.execute(select(User).where(User.id == partner_id))
        partner = partner_res.scalars().first()

        partner_payload = {}
        if partner:
            partner_payload = BlindDateMatcherService.mask_partner_for_session(
                session, current_user.id, partner
            )

        now = datetime.now(timezone.utc)
        remaining_seconds = max(0, int((session.expires_at - now).total_seconds()))

        return {
            "status": "matched",
            "session": {
                "id": str(session.id),
                "status": session.status,
                "started_at": session.started_at.isoformat() if session.started_at else None,
                "expires_at": session.expires_at.isoformat() if session.expires_at else None,
                "remaining_seconds": remaining_seconds,
                "icebreaker_prompt": session.icebreaker_prompt,
                "my_decision": session.user1_decision if session.user1_id == current_user.id else session.user2_decision,
                "partner": partner_payload
            }
        }

    if queue_entry and queue_entry.status == "waiting":
        return {
            "status": "waiting",
            "joined_at": queue_entry.joined_at.isoformat() if queue_entry.joined_at else None
        }

    return {"status": "idle"}


@router.post("/queue/cancel", status_code=status.HTTP_200_OK, summary="Cancel / Leave Queue")
async def cancel_queue(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    cancelled = await BlindDateMatcherService.cancel_queue_entry(db, current_user.id)
    return {"status": "cancelled", "success": cancelled}


@router.get("/session/{session_id}", status_code=status.HTTP_200_OK, summary="Get Active Blind Date Session")
async def get_blind_date_session(
    session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    s_res = await db.execute(select(BlindDateSession).where(BlindDateSession.id == session_id))
    session = s_res.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Blind date session not found.")

    if current_user.id not in (session.user1_id, session.user2_id):
        raise HTTPException(status_code=403, detail="Not authorized to access this blind date session.")

    now = datetime.now(timezone.utc)
    # Check expiration
    if session.status == "active" and session.expires_at < now:
        session.status = "expired"
        await db.commit()
        await db.refresh(session)

    partner_id = session.user2_id if session.user1_id == current_user.id else session.user1_id
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalars().first()

    partner_payload = {}
    if partner:
        partner_payload = BlindDateMatcherService.mask_partner_for_session(
            session, current_user.id, partner
        )

    remaining_seconds = max(0, int((session.expires_at - now).total_seconds()))

    my_decision = session.user1_decision if session.user1_id == current_user.id else session.user2_decision
    partner_decision = session.user2_decision if session.user1_id == current_user.id else session.user1_decision

    return {
        "id": str(session.id),
        "status": session.status,
        "started_at": session.started_at.isoformat() if session.started_at else None,
        "expires_at": session.expires_at.isoformat() if session.expires_at else None,
        "remaining_seconds": remaining_seconds,
        "icebreaker_prompt": session.icebreaker_prompt,
        "my_decision": my_decision,
        "partner_decision": partner_decision if session.status == "revealed" else "hidden",
        "match_id": str(session.match_id) if session.match_id else None,
        "partner": partner_payload
    }


@router.post("/session/{session_id}/message", status_code=status.HTTP_201_CREATED, summary="Send Session Message")
async def send_blind_date_message(
    session_id: uuid.UUID,
    payload: BlindDateMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    s_res = await db.execute(select(BlindDateSession).where(BlindDateSession.id == session_id))
    session = s_res.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Blind date session not found.")

    if current_user.id not in (session.user1_id, session.user2_id):
        raise HTTPException(status_code=403, detail="Not authorized to participate in this session.")

    now = datetime.now(timezone.utc)
    if session.status != "active" and session.status != "revealed":
        raise HTTPException(status_code=400, detail="Cannot send message in an inactive or closed session.")

    if session.status == "active" and session.expires_at < now:
        session.status = "expired"
        await db.commit()
        raise HTTPException(status_code=400, detail="Blind date session has expired.")

    message = BlindDateMessage(
        id=uuid.uuid4(),
        session_id=session.id,
        sender_id=current_user.id,
        ciphertext=payload.ciphertext.strip(),
        created_at=now
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)

    return {
        "id": str(message.id),
        "session_id": str(message.session_id),
        "sender_id": str(message.sender_id),
        "ciphertext": message.ciphertext,
        "created_at": message.created_at.isoformat(),
        "is_me": True
    }


@router.get("/session/{session_id}/messages", status_code=status.HTTP_200_OK, summary="Get Session Messages")
async def get_blind_date_messages(
    session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    s_res = await db.execute(select(BlindDateSession).where(BlindDateSession.id == session_id))
    session = s_res.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Blind date session not found.")

    if current_user.id not in (session.user1_id, session.user2_id):
        raise HTTPException(status_code=403, detail="Not authorized to access messages.")

    msg_res = await db.execute(
        select(BlindDateMessage)
        .where(BlindDateMessage.session_id == session.id)
        .order_by(BlindDateMessage.created_at.asc())
    )
    messages = msg_res.scalars().all()

    return [
        {
            "id": str(m.id),
            "session_id": str(m.session_id),
            "sender_id": str(m.sender_id),
            "ciphertext": m.ciphertext,
            "created_at": m.created_at.isoformat() if m.created_at else None,
            "is_me": m.sender_id == current_user.id
        }
        for m in messages
    ]


@router.post("/session/{session_id}/resonate", status_code=status.HTTP_200_OK, summary="Submit Resonance Decision")
async def submit_resonance_decision(
    session_id: uuid.UUID,
    payload: ResonateDecisionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    decision_clean = payload.decision.strip().lower()
    if decision_clean not in ("resonate", "pass"):
        raise HTTPException(status_code=400, detail="Decision must be 'resonate' or 'pass'.")

    try:
        updated_session = await BlindDateMatcherService.submit_decision(
            db, session_id, current_user.id, decision_clean
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    partner_id = (
        updated_session.user2_id
        if updated_session.user1_id == current_user.id
        else updated_session.user1_id
    )
    partner_res = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_res.scalars().first()

    partner_payload = {}
    if partner:
        partner_payload = BlindDateMatcherService.mask_partner_for_session(
            updated_session, current_user.id, partner
        )

    my_decision = (
        updated_session.user1_decision
        if updated_session.user1_id == current_user.id
        else updated_session.user2_decision
    )

    return {
        "status": updated_session.status,
        "my_decision": my_decision,
        "is_revealed": updated_session.status == "revealed",
        "match_id": str(updated_session.match_id) if updated_session.match_id else None,
        "partner": partner_payload
    }


@router.post("/session/{session_id}/extend", status_code=status.HTTP_200_OK, summary="Extend Blind Date Session (+3 Mins)")
async def extend_blind_date_session(
    session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Equal Perks: Extends active blind date dialogue by +3 minutes (180 seconds).
    Unlocked either via watching a 30s rewarded ad or via ₹29 perk (Zero class divide).
    """
    try:
        session = await BlindDateMatcherService.extend_session(db, session_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    now = datetime.now(timezone.utc)
    remaining_seconds = max(0, int((session.expires_at - now).total_seconds()))
    return {
        "status": session.status,
        "expires_at": session.expires_at.isoformat(),
        "remaining_seconds": remaining_seconds,
        "extension_count": session.extension_count or 0,
        "message": "Session extended by 3 minutes."
    }

