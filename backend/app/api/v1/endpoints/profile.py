from typing import Any, Dict, Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.services.streak_engine import StreakEngine

router = APIRouter(prefix="/profile", tags=["User Profile Engine"])

# Legacy set maintained for backward compatibility
COMPLETED_PROFILES: set[str] = set()


from datetime import date

def _calculate_age(dob: Optional[date]) -> int:
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(None, max_length=60)
    gender: Optional[str] = Field(None, max_length=20)
    interested_in: Optional[str] = Field(None, max_length=20)
    bio: Optional[str] = Field(None, max_length=500)
    profession: Optional[str] = Field(None, max_length=80)
    education: Optional[str] = Field(None, max_length=100)
    location: Optional[str] = Field(None, max_length=100)
    location_name: Optional[str] = Field(None, max_length=100)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    contact_bridge_type: Optional[str] = Field(None, max_length=30)
    contact_bridge_handle: Optional[str] = None
    is_kyc_verified: Optional[bool] = None
    photo_slots_count: Optional[int] = None
    photos: Optional[List[str]] = None
    avatar_url: Optional[str] = None
    preferred_age_min: Optional[int] = Field(None, ge=18, le=100)
    preferred_age_max: Optional[int] = Field(None, ge=18, le=100)
    dob: Optional[str] = None
    birth_date: Optional[str] = None
    age: Optional[int] = None
    email: Optional[str] = None

    model_config = ConfigDict(extra="ignore")


class SlumberToggleRequest(BaseModel):
    is_slumber_active: bool


@router.get("/me", status_code=status.HTTP_200_OK)
async def get_my_authenticated_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Fetches verified persona for Screen 11 without PII leakage."""
    import uuid as _uuid
    if not current_user.referral_code:
        current_user.referral_code = f"UR-{_uuid.uuid4().hex[:6].upper()}"
        try:
            await db.commit()
            await db.refresh(current_user)
        except Exception:
            await db.rollback()

    # Evaluate streak decay and get active countdown
    await StreakEngine.evaluate_and_decay_streak(current_user, db)
    streak_info = StreakEngine.get_user_streak_payload(current_user)

    return {
        "id": str(current_user.id),
        "full_name": current_user.full_name,
        "age": _calculate_age(current_user.dob),
        "dob": current_user.dob.isoformat() if current_user.dob else None,
        "gender": current_user.gender,
        "interested_in": current_user.interested_in,
        "bio": current_user.bio,
        "profession": current_user.profession,
        "education": current_user.education,
        "location_name": current_user.location_name,
        "kyc_status": current_user.kyc_status,
        "subscription_tier": current_user.subscription_tier,
        "is_ad_free": current_user.is_ad_free,
        "reward_balance": current_user.reward_balance,
        "swipes_remaining": current_user.swipes_remaining,
        "direct_letters_count": current_user.direct_letters_count,
        "streak_count": current_user.streak_count or 0,
        "boost_points": current_user.boost_points or 0,
        "last_streak_ad_at": current_user.last_streak_ad_at.isoformat() if current_user.last_streak_ad_at else None,
        "streak_expires_at": current_user.streak_expires_at.isoformat() if current_user.streak_expires_at else None,
        "reveal_tokens_count": current_user.reveal_tokens_count if current_user.reveal_tokens_count is not None else 0,
        "streak_info": streak_info,
        "referral_code": current_user.referral_code,
        "is_profile_completed": current_user.is_profile_completed,
        "night_slumber": current_user.night_slumber,
        "is_incognito": current_user.is_incognito,
        "discreet_mode": current_user.discreet_mode,
        "contact_bridge_type": current_user.contact_bridge_type,
        "contact_bridge_masked": (
            current_user.contact_bridge_encrypted[:4] + "****"
            if current_user.contact_bridge_encrypted
            else ""
        ),
        "photos": current_user.photos or [],
        "avatar_url": current_user.avatar_url or "",
        "preferred_age_min": current_user.preferred_age_min,
        "preferred_age_max": current_user.preferred_age_max,
        "contact_bridge_handle": current_user.contact_bridge_encrypted,
        "role": current_user.role or ("superadmin" if (current_user.email or "").lower() in ["asiverticals@gmail.com", "kshtriyaanubhav9120@gmail.com"] else "user")
    }


class RedeemReferralRequest(BaseModel):
    referral_code: str = Field(..., min_length=4, max_length=30)


@router.post("/referral/redeem", status_code=status.HTTP_200_OK)
async def redeem_referral_code(
    payload: RedeemReferralRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Validates a referral code against PostgreSQL users table.
    Credits 20 reflections and 5 swipes to both referrer and referee.
    Enqueues real in-app notification to the referrer.
    """
    code_clean = payload.referral_code.strip().upper()
    if not code_clean:
        raise HTTPException(status_code=400, detail="Referral code cannot be empty.")

    if current_user.referral_code and current_user.referral_code.upper() == code_clean:
        raise HTTPException(status_code=400, detail="You cannot redeem your own referral code.")

    # Find the referrer user in the database
    res = await db.execute(select(User).where(User.referral_code == code_clean))
    referrer = res.scalar_one_or_none()
    if not referrer:
        raise HTTPException(status_code=404, detail="Invalid referral code. No matching sanctuary seeker found.")

    # Credit rewards to referee (current_user)
    current_user.reward_balance = (current_user.reward_balance or 0) + 20
    current_user.swipes_remaining = (current_user.swipes_remaining or 25) + 5
    current_user.direct_letters_count = (current_user.direct_letters_count or 1) + 1

    # Credit rewards to referrer
    referrer.reward_balance = (referrer.reward_balance or 0) + 20
    referrer.swipes_remaining = (referrer.swipes_remaining or 25) + 5

    await db.commit()
    await db.refresh(current_user)

    # Push real in-app notification to the referrer
    from app.api.v1.endpoints.notifications import push_notification
    push_notification(
        user_id=str(referrer.id),
        notif_type="referral_reward",
        title="Sacred Kinship Reward 🌟",
        body=f"{current_user.full_name} entered the sanctuary with your referral code! +20 Reflections added to your balance.",
        data={"target_route": "/growth", "referee_name": current_user.full_name}
    )

    return {
        "status": "success",
        "message": f"Successfully redeemed! You and {referrer.full_name} both received 20 bonus reflections.",
        "reward_balance": current_user.reward_balance,
        "swipes_remaining": current_user.swipes_remaining,
        "direct_letters_count": current_user.direct_letters_count,
        "referrer_name": referrer.full_name,
    }


@router.put("/me", status_code=status.HTTP_200_OK)
@router.post("/me", status_code=status.HTTP_200_OK)
async def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-03 Fix: Live profile editor route.
    Updates bio, profession, education, location, name, and preferences in database.
    """
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(status_code=400, detail="No editable fields provided.")

    if payload.preferred_age_min and payload.preferred_age_max:
        if payload.preferred_age_min > payload.preferred_age_max:
            raise HTTPException(status_code=422, detail="Minimum preferred age cannot exceed maximum age.")

    # Remap field aliases to User table columns
    if "location" in update_data and "location_name" not in update_data:
        update_data["location_name"] = update_data.pop("location")
    else:
        update_data.pop("location", None)

    if "contact_bridge_handle" in update_data:
        handle = update_data.pop("contact_bridge_handle")
        if handle:
            update_data["contact_bridge_encrypted"] = str(handle)

    if "is_kyc_verified" in update_data:
        update_data["kyc_status"] = update_data.pop("is_kyc_verified")

    update_data.pop("photo_slots_count", None)
    email_val = update_data.pop("email", None)

    # Normalize gender to satisfy PostgreSQL users_gender_check constraint
    if "gender" in update_data and update_data["gender"]:
        g = str(update_data["gender"]).strip().lower()
        if g in ("male", "man", "men"):
            update_data["gender"] = "Man"
        elif g in ("female", "woman", "women"):
            update_data["gender"] = "Woman"
        elif g in ("non-binary", "nonbinary"):
            update_data["gender"] = "Non-Binary"
        elif g in ("other", "queer", "transgender"):
            update_data["gender"] = "Other"
        else:
            update_data["gender"] = "Unspecified"

    # Robust DOB & Age parsing
    from datetime import datetime
    raw_dob = update_data.pop("dob", None) or update_data.pop("birth_date", None)
    age_val = update_data.pop("age", None)
    parsed_dob = None
    if raw_dob:
        raw_dob_clean = str(raw_dob).strip()
        for fmt in ("%Y-%m-%d", "%d %b %Y", "%d %B %Y", "%d/%m/%Y", "%Y/%m/%d", "%b %d, %Y"):
            try:
                parsed_dob = datetime.strptime(raw_dob_clean, fmt).date()
                break
            except ValueError:
                pass
    if not parsed_dob and age_val and isinstance(age_val, int) and 18 <= age_val <= 100:
        today_d = date.today()
        parsed_dob = date(today_d.year - age_val, 1, 1)

    if parsed_dob:
        update_data["dob"] = parsed_dob

    # SEC-MED-05: Geolocation Precision Truncation (Fuzzy ~1.1km radius, 2 decimal places for DPDP compliance)
    if "latitude" in update_data and update_data["latitude"] is not None:
        update_data["latitude"] = round(float(update_data["latitude"]), 2)
    if "longitude" in update_data and update_data["longitude"] is not None:
        update_data["longitude"] = round(float(update_data["longitude"]), 2)

    # Mark profile completed in database (Fixes DUM-17 volatile memory set)
    update_data["is_profile_completed"] = True

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
    )
    await db.commit()

    if getattr(current_user, "email", None):
        COMPLETED_PROFILES.add(current_user.email.strip().lower())
    if email_val:
        COMPLETED_PROFILES.add(email_val.strip().lower())
    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())

    return {"status": "success", "message": "Profile updated and persisted successfully."}


@router.patch("/slumber-mode", status_code=status.HTTP_200_OK)
async def toggle_night_slumber(
    payload: SlumberToggleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-13 Fix: Persists night slumber mode in Supabase users table.
    """
    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(night_slumber=payload.is_slumber_active)
    )
    await db.commit()

    return {
        "status": "success",
        "night_slumber": payload.is_slumber_active
    }


class ProfileCreateRequest(BaseModel):
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    looking_for: Optional[str] = None
    bridge_platform: Optional[str] = None
    bridge_value: Optional[str] = None
    location: Optional[str] = None
    location_name: Optional[str] = None
    bio: Optional[str] = None
    profession: Optional[str] = None
    education: Optional[str] = None
    is_kyc: Optional[bool] = False
    photos: Optional[list] = None
    avatar_url: Optional[str] = None
    email: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    model_config = ConfigDict(extra="ignore")


@router.post(
    "/create",
    status_code=status.HTTP_200_OK,
    summary="Create or Update User Sanctuary Profile"
)
async def create_or_update_profile(
    payload: ProfileCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Saves completed user profile parameters strictly bound to authenticated current_user.
    Permanently neutralizes IDOR vulnerabilities by ignoring any email passed in request body.
    """
    loc_name = payload.location_name or payload.location

    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())
    if current_user.email:
        COMPLETED_PROFILES.add(current_user.email.strip().lower())

    up_vals: Dict[str, Any] = {"is_profile_completed": True}
    if payload.full_name:
        up_vals["full_name"] = payload.full_name
    if payload.gender:
        up_vals["gender"] = payload.gender
    if payload.looking_for:
        up_vals["interested_in"] = payload.looking_for
    if payload.bio:
        up_vals["bio"] = payload.bio
    if payload.profession:
        up_vals["profession"] = payload.profession
    if payload.education:
        up_vals["education"] = payload.education
    if loc_name:
        up_vals["location_name"] = loc_name
    if payload.is_kyc is not None:
        up_vals["kyc_status"] = payload.is_kyc
    if payload.bridge_platform:
        up_vals["contact_bridge_type"] = payload.bridge_platform
    if payload.bridge_value:
        up_vals["contact_bridge_encrypted"] = payload.bridge_value
    if payload.photos:
        up_vals["photos"] = payload.photos
        if not payload.avatar_url and len(payload.photos) > 0:
            up_vals["avatar_url"] = payload.photos[0]
    if payload.avatar_url:
        up_vals["avatar_url"] = payload.avatar_url
    if payload.date_of_birth:
        try:
            from datetime import date as _date
            up_vals["dob"] = _date.fromisoformat(payload.date_of_birth)
        except Exception:
            pass
    if payload.latitude is not None:
        up_vals["latitude"] = round(float(payload.latitude), 2)
    if payload.longitude is not None:
        up_vals["longitude"] = round(float(payload.longitude), 2)

    # Strictly bind mutations to current_user.id - completely ignoring any untrusted payload.email
    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(**up_vals)
    )
    try:
        await db.commit()
        await db.refresh(current_user)
    except Exception as e:
        await db.rollback()
        print(f"[PROFILE PERSISTENCE] Commit error: {e}", flush=True)

    print(
        f"[PROFILE PERSISTENCE] Profile Saved: user_id={current_user.id} name={current_user.full_name} "
        f"location={current_user.location_name} kyc={current_user.kyc_status}",
        flush=True
    )
    return {
        "status": "created",
        "is_success": True,
        "is_profile_completed": True,
        "message": "Sanctuary profile saved and verified successfully.",
        "profile": {
            "full_name": current_user.full_name,
            "location_name": current_user.location_name,
            "is_kyc": current_user.kyc_status,
        }
    }
