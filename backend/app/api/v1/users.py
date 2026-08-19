import uuid

from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.core.rate_limiter import rate_limit
from app.models.orm import User
from app.models.schemas import APIResponse

router = APIRouter(prefix="/users", tags=["User Location"])


@router.post("/fcm-token")
@router.post("/fcm-token/")
@router.put("/fcm-token")
@router.put("/fcm-token/")
async def update_fcm_token(
    payload: dict = Body(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    token = payload.get("fcm_token") or payload.get("token")
    if not token or not isinstance(token, str) or len(token.strip()) < 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid FCM token payload.")

    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID.")

    try:
        stmt = select(User).where(User.id == user_uuid)
        res = await db.execute(stmt)
        user = res.scalars().first()
        if user:
            user.fcm_token = token.strip()
            await db.commit()
    except Exception as e:
        await db.rollback()
        print(f"[FCM_SAVE] ERROR saving FCM token for user {current_user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save FCM token.")

    return APIResponse(success=True, message="FCM token updated successfully.", data={"fcm_token": token})


@router.post(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.post(
    "/location/",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/location/",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
async def update_user_location(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Persist the authenticated device's latest live GPS coordinates."""
    lat = payload.get("latitude", payload.get("lat"))
    lng = payload.get("longitude", payload.get("lng"))
    if lat is None or lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude are required.",
        )

    try:
        latitude, longitude = float(lat), float(lng)
        if not -90.0 <= latitude <= 90.0 or not -180.0 <= longitude <= 180.0:
            raise ValueError("Coordinates are outside valid GPS bounds.")
        user_id = uuid.UUID(current_user_id)
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalars().first()
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")
        user.latitude = latitude
        user.longitude = longitude
        try:
            await db.execute(
                text("UPDATE users SET location_geom = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography WHERE id = :uid"),
                {"lng": longitude, "lat": latitude, "uid": user_id}
            )
        except Exception:
            pass
        await db.commit()
    except HTTPException:
        raise
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid GPS coordinates.")
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save GPS location.")

    return APIResponse(
        success=True,
        message="Device GPS location updated successfully.",
        data={"latitude": latitude, "longitude": longitude},
    )


def _serialize_user_profile(user: User) -> dict:
    from datetime import date
    today = date.today()
    age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day)) if user.dob else None
    photos = [p.photo_url for p in user.photos] if user.photos else []
    is_approved = bool(user.is_verified and getattr(user, 'verification_status', None) and user.verification_status.value == "APPROVED")
    return {
        "id": str(user.id),
        "user_id": str(user.id),
        "full_name": user.full_name or "UR Heart User",
        "first_name": (user.full_name or "User").split()[0],
        "age": age,
        "bio": user.bio or "",
        "area_name": user.area_name or "Ayodhya",
        "gender": user.gender.value if user.gender else "male",
        "intent": user.intent.value if user.intent else "casual",
        "photos": photos,
        "is_verified": is_approved,
        "is_admin": bool(getattr(user, "is_admin", False)),
    }


@router.get("/activity")
@router.get("/activity/")
async def get_user_activity(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns authenticated user's activity breakdown:
    - Matches (mutual likes/matches)
    - Liked (right swiped users awaiting response)
    - Disliked (left swiped users)
    """
    from sqlalchemy import or_, and_
    from sqlalchemy.orm import selectinload
    from app.models.orm import Match, Swipe, SwipeActionEnum

    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID format.")

    # 1. Fetch Mutual Matches
    match_stmt = (
        select(Match)
        .where(or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid))
        .order_by(Match.created_at.desc())
    )
    match_res = await db.execute(match_stmt)
    matches_list = match_res.scalars().all()

    matched_user_ids = set()
    matches_data = []

    for m in matches_list:
        other_id = m.user2_id if m.user1_id == user_uuid else m.user1_id
        matched_user_ids.add(other_id)

        other_user_res = await db.execute(
            select(User).options(selectinload(User.photos)).where(User.id == other_id)
        )
        other_user = other_user_res.scalars().first()
        if other_user:
            matches_data.append({
                "match_id": str(m.id),
                "user": _serialize_user_profile(other_user),
                "created_at": m.created_at.isoformat() if m.created_at else "",
            })

    # 2. Fetch Swipes (Liked & Disliked)
    swipe_stmt = (
        select(Swipe)
        .where(Swipe.swiper_id == user_uuid)
        .order_by(Swipe.created_at.desc())
    )
    swipe_res = await db.execute(swipe_stmt)
    swipes_list = swipe_res.scalars().all()

    liked_data = []
    disliked_data = []

    for s in swipes_list:
        target_res = await db.execute(
            select(User).options(selectinload(User.photos)).where(User.id == s.swiped_id)
        )
        target_user = target_res.scalars().first()
        if not target_user:
            continue

        serialized = _serialize_user_profile(target_user)
        created_str = s.created_at.isoformat() if s.created_at else ""

        if s.action in (SwipeActionEnum.like, SwipeActionEnum.dm):
            # If already in mutual match, skip or mark
            if s.swiped_id not in matched_user_ids:
                liked_data.append({
                    "user": serialized,
                    "created_at": created_str,
                })
        elif s.action == SwipeActionEnum.reject:
            disliked_data.append({
                "user": serialized,
                "created_at": created_str,
            })

    return APIResponse(
        success=True,
        message="User activity retrieved successfully.",
        data={
            "matches": matches_data,
            "liked": liked_data,
            "disliked": disliked_data,
        }
    )

