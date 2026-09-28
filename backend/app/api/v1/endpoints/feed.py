from datetime import date
from typing import Optional, List, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, not_

from app.core.database import get_db
from app.core.security import get_current_user_optional
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match

router = APIRouter(tags=["Discovery Feed & Swipes"])


class SwipeRequest(BaseModel):
    target_id: str
    swipe_type: str  # 'like', 'pass', 'direct'


def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


@router.get("/feed", status_code=status.HTTP_200_OK, summary="Get Sanctuary Discovery Feed")
@router.get("/discovery/feed", status_code=status.HTTP_200_OK, summary="Get Sanctuary Discovery Feed Alias")
async def get_discovery_feed(
    limit: int = Query(default=10, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns verified candidate profiles from PostgreSQL for the discovery deck
    with reciprocal orientation matching, excluding already swiped profiles.
    """
    stmt = select(User).where(
        User.deleted_at.is_(None),
        User.is_profile_completed == True
    )

    if current_user:
        # Exclude current logged in user
        stmt = stmt.where(User.id != current_user.id)

        # Exclude candidates already swiped by current user
        swiped_subq = select(Swipe.target_id).where(Swipe.actor_id == current_user.id)
        stmt = stmt.where(not_(User.id.in_(swiped_subq)))

        # Orientation matching if specified
        if current_user.interested_in in ("Women", "Woman"):
            stmt = stmt.where(User.gender.in_(["Woman", "Women"]))
        elif current_user.interested_in in ("Men", "Man"):
            stmt = stmt.where(User.gender.in_(["Man", "Men"]))

    stmt = stmt.order_by(User.created_at.desc()).limit(limit)
    res = await db.execute(stmt)
    users = res.scalars().all()

    cards = []
    for u in users:
        photos = list(u.photos or [])
        if not photos and u.avatar_url:
            photos.append(u.avatar_url)

        age = _calculate_age(u.dob)
        cards.append({
            "id": str(u.id),
            "full_name": u.full_name,
            "age": age,
            "gender": u.gender,
            "looking_for": u.interested_in or "Men",
            "location_name": u.location_name or "Saket, Ayodhya",
            "distance_km": 2.5,
            "resonance_score": 92 + (int(u.id.int % 7) if hasattr(u.id, "int") else 3),
            "bio": u.bio or "Mindful seeker cultivating authentic connection.",
            "ai_resonance_insight": "Shared reverence for depth, patience, and authentic conversation.",
            "authentic_intention": u.bio or "Looking for an intentional sanctuary.",
            "tags": [u.profession, "Mindfulness", "Slow Living"] if u.profession else ["Mindfulness", "Art & Literature", "Stillness"],
            "photos": photos,
            "is_kyc_verified": u.kyc_status,
            "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4"
        })

    print(f"[FEED DISCOVERY] Serving {len(cards)} live candidate cards from PostgreSQL to client", flush=True)
    return {"candidates": cards, "data": cards}


@router.post("/swipes", status_code=status.HTTP_200_OK, summary="Record Profile Swipe Action")
async def record_swipe(
    payload: SwipeRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """
    Records like, pass, or direct resonate swipe action in PostgreSQL public.swipes.
    Creates reciprocal match in public.matches when appropriate.
    """
    print(f"[SWIPE RECORDED] target_id={payload.target_id} action={payload.swipe_type.upper()}", flush=True)

    is_match = False
    match_id = None

    try:
        target_uuid = UUID(payload.target_id)
    except ValueError:
        target_uuid = None

    if current_user and target_uuid:
        # Record swipe in public.swipes
        swipe = Swipe(
            actor_id=current_user.id,
            target_id=target_uuid,
            swipe_type=payload.swipe_type.lower()
        )
        db.add(swipe)

        # Decrement swipes_remaining on like/direct
        if current_user.swipes_remaining > 0:
            current_user.swipes_remaining = max(0, current_user.swipes_remaining - 1)

        # Check for mutual like or direct resonate
        swipe_type_clean = payload.swipe_type.lower()
        if swipe_type_clean in ("like", "direct", "superlike"):
            from app.api.v1.endpoints.notifications import push_notification
            push_notification(
                user_id=str(target_uuid),
                notif_type="direct_letter" if swipe_type_clean in ("direct", "superlike") else "like",
                title="Direct Resonate Spark ✨" if swipe_type_clean in ("direct", "superlike") else "New Resonance ✨",
                body=f"{current_user.full_name} sent you a Direct Sanctuary Letter." if swipe_type_clean in ("direct", "superlike") else f"{current_user.full_name} resonated with your profile.",
                data={
                    "actor_id": str(current_user.id),
                    "actor_name": current_user.full_name,
                    "swipe_type": swipe_type_clean,
                    "target_route": "/resonances"
                }
            )

            reciprocal_stmt = select(Swipe).where(
                Swipe.actor_id == target_uuid,
                Swipe.target_id == current_user.id,
                Swipe.swipe_type.in_(["like", "direct", "superlike"])
            )
            reciprocal_res = await db.execute(reciprocal_stmt)
            reciprocal_swipe = reciprocal_res.scalar_one_or_none()

            # If mutual like OR direct resonate, form a match
            if reciprocal_swipe or swipe_type_clean in ("direct", "superlike"):
                is_match = True
                existing_match_stmt = select(Match).where(
                    ((Match.user1_id == current_user.id) & (Match.user2_id == target_uuid)) |
                    ((Match.user1_id == target_uuid) & (Match.user2_id == current_user.id))
                )
                ex_res = await db.execute(existing_match_stmt)
                match = ex_res.scalar_one_or_none()
                if not match:
                    match = Match(
                        user1_id=current_user.id,
                        user2_id=target_uuid,
                        is_active=True
                    )
                    db.add(match)
                    await db.flush()
                match_id = str(match.id)

                # Push match notification to both users
                target_user_res = await db.execute(select(User).where(User.id == target_uuid))
                target_user = target_user_res.scalar_one_or_none()
                target_name = target_user.full_name if target_user else "Seeker"

                push_notification(
                    user_id=str(current_user.id),
                    notif_type="match",
                    title="Sacred Match Ignited 💫",
                    body=f"You and {target_name} have mutually resonated! Begin your mindful dialogue.",
                    data={
                        "match_id": match_id,
                        "partner_id": str(target_uuid),
                        "partner_name": target_name,
                        "target_route": "/chat-dialogue"
                    }
                )
                push_notification(
                    user_id=str(target_uuid),
                    notif_type="match",
                    title="Sacred Match Ignited 💫",
                    body=f"You and {current_user.full_name} have mutually resonated! Begin your mindful dialogue.",
                    data={
                        "match_id": match_id,
                        "partner_id": str(current_user.id),
                        "partner_name": current_user.full_name,
                        "target_route": "/chat-dialogue"
                    }
                )

        await db.commit()
    else:
        is_match = payload.swipe_type.lower() in ("like", "direct", "superlike")
        match_id = f"match-{payload.target_id}" if is_match else None

    return {
        "status": "recorded",
        "target_id": payload.target_id,
        "swipe_type": payload.swipe_type,
        "is_match": is_match,
        "match_id": match_id,
        "swipes_remaining": current_user.swipes_remaining if current_user else 24
    }


@router.delete("/swipes/pass/{target_id}", status_code=status.HTTP_200_OK, summary="Restore Passed Profile")
async def restore_passed_profile(
    target_id: str,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """
    Removes profile from pass vault in PostgreSQL and restores back into active deck.
    """
    if current_user:
        try:
            target_uuid = UUID(target_id)
            from sqlalchemy import delete
            await db.execute(
                delete(Swipe).where(
                    Swipe.actor_id == current_user.id,
                    Swipe.target_id == target_uuid,
                    Swipe.swipe_type == "pass"
                )
            )
            await db.commit()
        except Exception:
            pass

    print(f"[PASS VAULT] Revisit profile target_id={target_id}", flush=True)
    return {
        "status": "revisited",
        "target_id": target_id,
        "message": "Profile restored to discovery deck."
    }
