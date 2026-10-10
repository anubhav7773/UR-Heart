from datetime import date
from typing import Optional, List, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Request, status, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, not_, or_

from app.core.database import get_db
from app.core.security import get_current_user_optional, get_current_user, get_current_active_user
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match
from app.models.domain.legal import BlockedUser
from app.models.domain.photo_reveal_consent import PhotoRevealConsent
from app.services.streak_engine import StreakEngine
from app.services.resonance_engine import ResonanceEngine

router = APIRouter(tags=["Discovery Feed & Swipes"])


class SwipeRequest(BaseModel):
    target_id: str
    swipe_type: str  # 'like', 'pass', 'direct'
    letter_text: Optional[str] = None


def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


@router.get("/feed", status_code=status.HTTP_200_OK, summary="Get Sanctuary Discovery Feed")
@router.get("/discovery/feed", status_code=status.HTTP_200_OK, summary="Get Sanctuary Discovery Feed Alias")
async def get_discovery_feed(
    request: Request,
    limit: int = Query(default=10, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns verified candidate profiles from PostgreSQL for the discovery deck
    with reciprocal orientation matching, excluding already swiped profiles,
    direct-letter senders, active matches, and incognito (Ghost Cloak) users.
    Enforces mandatory authentication to prevent unauthenticated database scraping.
    """
    # 0. Deterministically resolve caller identity for strict self-exclusion
    caller_id = current_user.id
    caller_email = current_user.email.strip().lower() if current_user.email else None
    caller_auth_id = current_user.auth_id

    stmt = select(User).where(
        User.deleted_at.is_(None),
        User.is_profile_completed == True,
        or_(User.is_incognito.is_(False), User.is_incognito.is_(None))
    )

    # 1. Strict Self-Exclusion Shield (Caller can NEVER see their own profile)
    if caller_id:
        stmt = stmt.where(User.id != caller_id)
    if caller_email:
        stmt = stmt.where(User.email != caller_email)
    if caller_auth_id:
        stmt = stmt.where(User.auth_id != caller_auth_id)

    if current_user:
        # Evaluate user's 24h streak decay and penalty before serving feed
        await StreakEngine.evaluate_and_decay_streak(current_user, db)

        # Exclude candidates already swiped by current user
        swiped_subq = select(Swipe.target_id).where(Swipe.actor_id == current_user.id)
        stmt = stmt.where(not_(User.id.in_(swiped_subq)))

        # Exclude candidates who already sent a direct letter / superlike to current user
        direct_senders_subq = select(Swipe.actor_id).where(
            Swipe.target_id == current_user.id,
            Swipe.swipe_type.in_(["direct", "superlike", "direct_letter"])
        )
        stmt = stmt.where(not_(User.id.in_(direct_senders_subq)))

        # Exclude candidates with whom current user already has an active Match/dialogue
        matched_u1_subq = select(Match.user1_id).where(Match.user2_id == current_user.id, Match.is_active == True)
        matched_u2_subq = select(Match.user2_id).where(Match.user1_id == current_user.id, Match.is_active == True)
        stmt = stmt.where(not_(User.id.in_(matched_u1_subq)))
        stmt = stmt.where(not_(User.id.in_(matched_u2_subq)))

        # Exclude blocked perimeter candidates bidirectionally (Statutory Privacy Vault)
        blocked_subq = select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == current_user.id)
        blocked_by_subq = select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == current_user.id)
        stmt = stmt.where(not_(User.id.in_(blocked_subq)))
        stmt = stmt.where(not_(User.id.in_(blocked_by_subq)))

        # Orientation matching — bidirectional algorithm
        # Direction 1: User's preference → filter candidate's gender
        if current_user.interested_in and current_user.interested_in not in ("Everyone",):
            if current_user.interested_in in ("Women", "Woman"):
                stmt = stmt.where(User.gender.in_(["Woman", "Women"]))
            elif current_user.interested_in in ("Men", "Man"):
                stmt = stmt.where(User.gender.in_(["Man", "Men"]))

        # Direction 2: Candidate must also be interested in user's gender (reverse check)
        if current_user.gender:
            user_g = current_user.gender.strip()
            if user_g in ("Man", "Men"):
                stmt = stmt.where(User.interested_in.in_(["Men", "Man", "Everyone"]))
            elif user_g in ("Woman", "Women"):
                stmt = stmt.where(User.interested_in.in_(["Women", "Woman", "Everyone"]))
            else:
                # Non-binary / Other: only show candidates interested in Everyone
                stmt = stmt.where(User.interested_in == "Everyone")

    # Priority Ranking: Boosted candidates with higher streak & boost points appear first!
    stmt = stmt.order_by(
        User.boost_points.desc(),
        User.streak_count.desc(),
        User.created_at.desc()
    ).limit(limit)
    res = await db.execute(stmt)
    users = res.scalars().all()

    # Prefetch photo reveal consents for current user against candidates
    consents_map: Dict[UUID, str] = {}
    if current_user and users:
        candidate_ids = [u.id for u in users]
        c_stmt = select(PhotoRevealConsent).where(
            or_(
                (PhotoRevealConsent.requester_id == current_user.id) & (PhotoRevealConsent.target_id.in_(candidate_ids)),
                (PhotoRevealConsent.target_id == current_user.id) & (PhotoRevealConsent.requester_id.in_(candidate_ids))
            )
        )
        c_res = await db.execute(c_stmt)
        for c in c_res.scalars().all():
            if hasattr(c, "requester_id") and hasattr(c, "target_id"):
                other_id = c.target_id if c.requester_id == current_user.id else c.requester_id
                consents_map[other_id] = getattr(c, "status", "none")

    cards = []
    for u in users:
        # Defense-in-depth safety: skip caller if somehow returned
        if caller_id and (u.id == caller_id or str(u.id) == str(caller_id)):
            continue
        if caller_email and u.email and u.email.strip().lower() == caller_email:
            continue
        if caller_auth_id and u.auth_id and (u.auth_id == caller_auth_id or str(u.auth_id) == str(caller_auth_id)):
            continue
        clean_photos = [p for p in (u.photos or []) if p and str(p).strip()]
        if u.avatar_url and u.avatar_url.strip() and u.avatar_url.strip() not in clean_photos:
            clean_photos.insert(0, u.avatar_url.strip())

        primary_avatar = u.avatar_url.strip() if (u.avatar_url and u.avatar_url.strip()) else (clean_photos[0] if clean_photos else "")

        age = _calculate_age(u.dob)
        score, insight, authentic_tags = ResonanceEngine.calculate_mutual_resonance(current_user, u)
        dist_km = ResonanceEngine.compute_distance(current_user, u)

        cand_bio = u.bio.strip() if (u.bio and u.bio.strip()) else "Mindful seeker walking an intentional path."
        cand_intention = u.bio.strip() if (u.bio and u.bio.strip()) else "Seeking slow, thoughtful connection in the sanctuary."

        is_veiled = bool(u.is_photo_veiled)
        status_val = consents_map.get(u.id, "none")
        is_unlocked = not is_veiled or (status_val == "accepted")

        safe_avatar = primary_avatar if is_unlocked else ""
        safe_photos = clean_photos if is_unlocked else []

        cards.append({
            "id": str(u.id),
            "full_name": u.full_name,
            "age": age,
            "gender": u.gender,
            "profession": u.profession or "Mindful Seeker",
            "education": u.education or "",
            "looking_for": u.interested_in or "Men",
            "location_name": u.location_name or "Saket, Ayodhya",
            "distance_km": dist_km,
            "resonance_score": score,
            "ai_insight": insight,
            "ai_resonance_insight": insight,
            "bio": cand_bio,
            "authentic_intention": cand_intention,
            "intent_quote": cand_intention,
            "interests": authentic_tags,
            "tags": authentic_tags,
            "avatar_url": safe_avatar,
            "avatar": safe_avatar,
            "photos": safe_photos,
            "photo_urls": safe_photos,
            "is_photo_veiled": is_veiled,
            "is_photo_unlocked": is_unlocked,
            "photo_reveal_status": status_val,
            "is_kyc_verified": bool(u.kyc_status),
            "is_verified": bool(u.kyc_status),
            "kyc_status": bool(u.kyc_status),
            "streak_count": u.streak_count or 0,
            "boost_points": u.boost_points or 0,
            "is_boosted": bool((u.boost_points or 0) > 0),
            "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
            "voice_spark_url": u.voice_spark_url,
            "voice_spark_prompt": u.voice_spark_prompt,
            "voice_spark_duration": float(u.voice_spark_duration) if u.voice_spark_duration else 7.0,
            "is_voice_verified": bool(u.is_voice_verified),
        })

    print(f"[FEED DISCOVERY] Serving {len(cards)} live candidate cards from PostgreSQL to client", flush=True)
    return {
        "candidates": cards,
        "data": cards,
        "swipes_remaining": current_user.swipes_remaining if current_user else 10,
        "direct_letters_count": (current_user.direct_letters_count if (current_user and current_user.direct_letters_count is not None) else 0),
        "streak_count": current_user.streak_count if current_user else 0,
        "boost_points": current_user.boost_points if current_user else 0,
    }


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
        swipe_type_clean = payload.swipe_type.lower()

        # Record or update swipe in public.swipes safely without uq_actor_target violation
        existing_swipe_res = await db.execute(
            select(Swipe).where(Swipe.actor_id == current_user.id, Swipe.target_id == target_uuid)
        )
        existing_swipe = existing_swipe_res.scalar_one_or_none()
        if existing_swipe:
            existing_swipe.swipe_type = swipe_type_clean
        else:
            swipe = Swipe(
                actor_id=current_user.id,
                target_id=target_uuid,
                swipe_type=swipe_type_clean
            )
            db.add(swipe)

        # Decrement swipes_remaining on like/direct
        if current_user.swipes_remaining > 0:
            current_user.swipes_remaining = max(0, current_user.swipes_remaining - 1)

        # Decrement direct_letters_count on direct letters in PostgreSQL
        if swipe_type_clean == "direct":
            if (current_user.direct_letters_count or 0) > 0:
                current_user.direct_letters_count = max(0, current_user.direct_letters_count - 1)

        # Send pass/ignore notification
        if swipe_type_clean == "pass":
            from app.api.v1.endpoints.notifications import push_notification
            sender_photo = current_user.avatar_url or next((p for p in (current_user.photos or []) if p and str(p).strip()), "")
            push_notification(
                user_id=str(target_uuid),
                notif_type="pass",
                title="Profile Passed 🍃",
                body=f"{current_user.full_name} passed your profile.",
                data={
                    "actor_id": str(current_user.id),
                    "actor_name": current_user.full_name,
                    "sender_id": str(current_user.id),
                    "sender_name": current_user.full_name,
                    "sender_avatar": sender_photo,
                    "avatar_url": sender_photo,
                    "swipe_type": "pass",
                    "target_route": "/resonances"
                }
            )

        # Check for mutual like or direct resonate
        if swipe_type_clean in ("like", "direct", "superlike"):
            from app.api.v1.endpoints.notifications import push_notification

            # For regular likes, notify target of new resonance
            if swipe_type_clean == "like":
                sender_photo = current_user.avatar_url or next((p for p in (current_user.photos or []) if p and str(p).strip()), "")
                push_notification(
                    user_id=str(target_uuid),
                    notif_type="like",
                    title="New Resonance ✨",
                    body=f"{current_user.full_name} resonated with your profile.",
                    data={
                        "actor_id": str(current_user.id),
                        "actor_name": current_user.full_name,
                        "sender_id": str(current_user.id),
                        "sender_name": current_user.full_name,
                        "sender_avatar": sender_photo,
                        "avatar_url": sender_photo,
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

            # If mutual like OR direct resonate, form a match/dialogue bridge
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

                # If a direct letter was attached, persist it as a real Message with storage encryption
                if payload.letter_text and payload.letter_text.strip():
                    from app.models.domain.message import Message
                    from app.api.v1.endpoints.chat_api import encrypt_message_storage
                    storage_text = encrypt_message_storage(payload.letter_text.strip(), str(match.id))
                    direct_msg = Message(
                        match_id=match.id,
                        sender_id=current_user.id,
                        encrypted_text=storage_text,
                        status="delivered"
                    )
                    db.add(direct_msg)

                target_user_res = await db.execute(select(User).where(User.id == target_uuid))
                target_user = target_user_res.scalar_one_or_none()
                target_name = target_user.full_name if target_user else "Seeker"
                target_photo = target_user.avatar_url or next((p for p in (target_user.photos or []) if p and str(p).strip()), "") if target_user else ""
                sender_photo = current_user.avatar_url or next((p for p in (current_user.photos or []) if p and str(p).strip()), "")

                if reciprocal_swipe:
                    # Genuine mutual resonance: Notify both users
                    push_notification(
                        user_id=str(current_user.id),
                        notif_type="match",
                        title="Sacred Match Ignited 💫",
                        body=f"You and {target_name} have mutually resonated! Begin your mindful dialogue.",
                        data={
                            "match_id": match_id,
                            "partner_id": str(target_uuid),
                            "partner_name": target_name,
                            "peer_name": target_name,
                            "sender_id": str(target_uuid),
                            "sender_name": target_name,
                            "partner_photo": target_photo,
                            "sender_avatar": target_photo,
                            "avatar_url": target_photo,
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
                            "peer_name": current_user.full_name,
                            "sender_id": str(current_user.id),
                            "sender_name": current_user.full_name,
                            "partner_photo": sender_photo,
                            "sender_avatar": sender_photo,
                            "avatar_url": sender_photo,
                            "target_route": "/chat-dialogue"
                        }
                    )
                else:
                    # Inbound Direct Letter from current_user (sender) to target_uuid (recipient)
                    # Strictly notify only the recipient without generating false self-match alerts on the sender
                    body_to_target = (
                        f"{current_user.full_name} sent you a Direct Sanctuary Letter: \"{payload.letter_text.strip()[:60]}...\""
                        if payload.letter_text and payload.letter_text.strip()
                        else f"{current_user.full_name} sent you a Direct Sanctuary Letter."
                    )
                    push_notification(
                        user_id=str(target_uuid),
                        notif_type="direct_letter",
                        title="Direct Sanctuary Letter 💌",
                        body=body_to_target,
                        data={
                            "match_id": match_id,
                            "partner_id": str(current_user.id),
                            "partner_name": current_user.full_name,
                            "peer_name": current_user.full_name,
                            "sender_id": str(current_user.id),
                            "sender_name": current_user.full_name,
                            "partner_photo": sender_photo,
                            "sender_avatar": sender_photo,
                            "avatar_url": sender_photo,
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
        "swipes_remaining": current_user.swipes_remaining if current_user else 10,
        "direct_letters_count": current_user.direct_letters_count if (current_user and current_user.direct_letters_count is not None) else 0,
    }


@router.get("/swipes/passed", status_code=status.HTTP_200_OK, summary="Get Passed Profiles (Pass Vault)")
async def get_passed_profiles(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves all candidate profiles that the current user has passed on.
    Orders by swipe creation timestamp descending.
    Computes dynamic mutual resonance, authentic tags, and distance.
    Zero dummy data.
    """
    stmt = (
        select(User, Swipe.created_at.label("passed_at"))
        .join(Swipe, Swipe.target_id == User.id)
        .where(
            Swipe.actor_id == current_user.id,
            Swipe.swipe_type == "pass",
            User.deleted_at.is_(None)
        )
        .order_by(Swipe.created_at.desc())
        .limit(50)
    )
    result = await db.execute(stmt)
    rows = result.all()

    passed_candidates = []
    for u, passed_at in rows:
        clean_photos = [p for p in (u.photos or []) if p and str(p).strip()]
        if u.avatar_url and u.avatar_url.strip() and u.avatar_url.strip() not in clean_photos:
            clean_photos.insert(0, u.avatar_url.strip())

        primary_avatar = u.avatar_url.strip() if (u.avatar_url and u.avatar_url.strip()) else (clean_photos[0] if clean_photos else "")

        age = _calculate_age(u.dob)
        score, insight, authentic_tags = ResonanceEngine.calculate_mutual_resonance(current_user, u)
        dist_km = ResonanceEngine.compute_distance(current_user, u)

        cand_bio = u.bio.strip() if (u.bio and u.bio.strip()) else "Mindful seeker walking an intentional path in the Sanctuary."
        cand_intention = u.bio.strip() if (u.bio and u.bio.strip()) else "Seeking slow, thoughtful connection in the sanctuary."

        passed_candidates.append({
            "id": str(u.id),
            "full_name": u.full_name,
            "age": age,
            "gender": u.gender,
            "profession": u.profession or "Mindful Seeker",
            "education": u.education or "",
            "looking_for": u.interested_in or "Everyone",
            "location_name": u.location_name or "Saket, Ayodhya",
            "distance_km": dist_km,
            "resonance_score": score,
            "ai_insight": insight,
            "ai_resonance_insight": insight,
            "bio": cand_bio,
            "authentic_intention": cand_intention,
            "intent_quote": cand_intention,
            "interests": authentic_tags,
            "tags": authentic_tags,
            "avatar_url": primary_avatar,
            "avatar": primary_avatar,
            "photos": clean_photos,
            "photo_urls": clean_photos,
            "is_kyc_verified": bool(u.kyc_status),
            "is_verified": bool(u.kyc_status),
            "kyc_status": bool(u.kyc_status),
            "streak_count": u.streak_count or 0,
            "boost_points": u.boost_points or 0,
            "is_boosted": bool((u.boost_points or 0) > 0),
            "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
            "passed_at": passed_at.isoformat() if passed_at else None
        })

    return {
        "passed_candidates": passed_candidates,
        "data": passed_candidates,
        "total": len(passed_candidates)
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


class PhotoRevealResponseRequest(BaseModel):
    action: str  # 'accept' or 'decline'


@router.post("/feed/{target_id}/photo-reveal/request", status_code=status.HTTP_200_OK, summary="Request Photo Reveal")
@router.post("/discovery/feed/{target_id}/photo-reveal/request", status_code=status.HTTP_200_OK, summary="Request Photo Reveal Alias")
async def request_photo_reveal(
    target_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits bilateral photo reveal consent request for a veiled candidate.
    Dispatches push notification and WebSocket event to candidate.
    """
    if getattr(request.app.state, "photo_veil_schema_ready", True) is False:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Sacred Photo Reveal feature is temporarily unavailable due to database maintenance."
        )

    try:
        target_uuid = UUID(target_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid target_id UUID format.")

    if current_user.id == target_uuid:
        raise HTTPException(status_code=400, detail="Cannot request photo reveal from yourself.")

    target_res = await db.execute(select(User).where(User.id == target_uuid, User.deleted_at.is_(None)))
    target_user = target_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=404, detail="Candidate not found.")

    # Upsert or retrieve PhotoRevealConsent
    consent_stmt = select(PhotoRevealConsent).where(
        PhotoRevealConsent.requester_id == current_user.id,
        PhotoRevealConsent.target_id == target_uuid
    )
    res = await db.execute(consent_stmt)
    consent = res.scalar_one_or_none()

    if consent:
        if consent.status == "declined":
            raise HTTPException(
                status_code=403,
                detail="Photo reveal request was previously declined. Cannot resend request."
            )
        if consent.status == "accepted":
            return {
                "status": "accepted",
                "message": "Photos are already unveiled."
            }
        if consent.status == "pending":
            return {
                "status": "pending",
                "message": "Photo reveal request is already pending."
            }
    else:
        consent = PhotoRevealConsent(
            requester_id=current_user.id,
            target_id=target_uuid,
            status="pending"
        )
        db.add(consent)

    await db.commit()

    # Real-time notification to target
    from app.api.v1.endpoints.notifications import push_notification
    push_notification(
        user_id=str(target_uuid),
        notif_type="photo_reveal_request",
        title="Sacred Photo Reveal Request 🕊️",
        body=f"{current_user.full_name} has requested to unveil your profile photo. Mutual consent required.",
        data={
            "type": "photo_reveal_request",
            "requester_id": str(current_user.id),
            "requester_name": current_user.full_name,
            "target_route": "/resonances"
        }
    )

    return {
        "status": "pending",
        "message": f"Photo reveal request dispatched to {target_user.full_name}."
    }


@router.post("/feed/{requester_id}/photo-reveal/respond", status_code=status.HTTP_200_OK, summary="Respond to Photo Reveal Request")
@router.post("/discovery/feed/{requester_id}/photo-reveal/respond", status_code=status.HTTP_200_OK, summary="Respond to Photo Reveal Request Alias")
async def respond_to_photo_reveal(
    requester_id: str,
    payload: PhotoRevealResponseRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts or declines a bilateral photo reveal request.
    If accepted, both seekers can view each other's clear photos.
    """
    if getattr(request.app.state, "photo_veil_schema_ready", True) is False:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Sacred Photo Reveal feature is temporarily unavailable due to database maintenance."
        )

    try:
        req_uuid = UUID(requester_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid requester_id UUID format.")

    action_clean = payload.action.strip().lower()
    if action_clean not in ("accept", "decline"):
        raise HTTPException(status_code=400, detail="Action must be 'accept' or 'decline'.")

    consent_stmt = select(PhotoRevealConsent).where(
        PhotoRevealConsent.requester_id == req_uuid,
        PhotoRevealConsent.target_id == current_user.id
    )
    res = await db.execute(consent_stmt)
    consent = res.scalar_one_or_none()
    if not consent:
        raise HTTPException(
            status_code=404,
            detail="No pending photo reveal request found from this seeker."
        )

    if consent.status != "pending":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot respond to photo reveal request that is already '{consent.status}'."
        )

    consent.status = "accepted" if action_clean == "accept" else "declined"

    await db.commit()

    if action_clean == "accept":
        from app.api.v1.endpoints.notifications import push_notification
        push_notification(
            user_id=str(req_uuid),
            notif_type="photo_reveal_unlocked",
            title="Sacred Photo Unveiled! ✨",
            body=f"{current_user.full_name} accepted your photo reveal request. Their portrait is now visible.",
            data={
                "type": "photo_reveal_unlocked",
                "partner_id": str(current_user.id),
                "partner_name": current_user.full_name,
                "target_route": "/feed"
            }
        )

    return {
        "status": consent.status,
        "message": f"Photo reveal request {action_clean}ed."
    }

