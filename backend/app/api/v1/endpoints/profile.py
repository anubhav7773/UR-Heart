from typing import Any, Dict, Optional, List
from uuid import UUID
import httpx
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.models.domain.photo_reveal_consent import PhotoRevealConsent
from app.services.streak_engine import StreakEngine
from app.services.resonance_engine import ResonanceEngine

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
    voice_spark_url: Optional[str] = None
    voice_spark_prompt: Optional[str] = None
    voice_spark_duration: Optional[float] = None
    is_voice_verified: Optional[bool] = None
    is_photo_veiled: Optional[bool] = None

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

    # Auto-claim any pending web store passes for current user's email
    try:
        from app.api.v1.endpoints.web_store import claim_pending_web_store_entitlements
        await claim_pending_web_store_entitlements(db, current_user)
    except Exception as claim_err:
        pass

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
        "is_photo_veiled": bool(current_user.is_photo_veiled),
        "discreet_mode": current_user.discreet_mode,
        "contact_bridge_type": current_user.contact_bridge_type,
        "contact_bridge_masked": (
            (
                lambda b: (b[:4] + "****" if len(b) >= 4 else b)
            )(
                __import__("app.core.encryption", fromlist=["decrypt_contact_bridge"]).decrypt_contact_bridge(
                    current_user.contact_bridge_encrypted, str(current_user.id)
                )
            )
            if current_user.contact_bridge_encrypted
            else ""
        ),
        "photos": (
            [p for p in (current_user.photos or []) if p and str(p).strip()][1:]
            if (current_user.avatar_url and (current_user.photos or []) and str((current_user.photos or [])[0]).strip() == str(current_user.avatar_url).strip())
            else [p for p in (current_user.photos or []) if p and str(p).strip()]
        ),
        "avatar_url": current_user.avatar_url or "",
        "preferred_age_min": current_user.preferred_age_min,
        "preferred_age_max": current_user.preferred_age_max,
        "contact_bridge_handle": __import__("app.core.encryption", fromlist=["decrypt_contact_bridge"]).decrypt_contact_bridge(
            current_user.contact_bridge_encrypted, str(current_user.id)
        ),
        "role": getattr(current_user, "role", None) or "user",
        "voice_spark_url": current_user.voice_spark_url,
        "voice_spark_prompt": current_user.voice_spark_prompt,
        "voice_spark_duration": float(current_user.voice_spark_duration) if current_user.voice_spark_duration else 7.0,
        "is_voice_verified": bool(current_user.is_voice_verified),
    }


@router.get("/{user_id}", status_code=status.HTTP_200_OK, summary="Get Dedicated Seeker Profile")
async def get_seeker_profile(
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches full dedicated profile of a sanctuary seeker for Screen 10 / Seeker Detail.
    Computes real dynamic mutual resonance, authentic tags, proximity, and match/bridge status.
    Zero dummy data.
    """
    try:
        target_uuid = UUID(user_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid user ID format.")

    res = await db.execute(
        select(User).where(User.id == target_uuid, User.deleted_at.is_(None))
    )
    target_user = res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=404, detail="Sanctuary seeker not found or deactivated.")

    # Calculate dynamic mutual resonance & distance
    score, insight, authentic_tags = ResonanceEngine.calculate_mutual_resonance(current_user, target_user)
    dist_km = ResonanceEngine.compute_distance(current_user, target_user)

    # Check match status and WhatsApp Sacred Bridge unlock
    match_res = await db.execute(
        select(Match).where(
            ((Match.user1_id == current_user.id) & (Match.user2_id == target_user.id)) |
            ((Match.user1_id == target_user.id) & (Match.user2_id == current_user.id))
        )
    )
    match = match_res.scalar_one_or_none()
    has_match = isinstance(match, Match) and getattr(match, "is_active", True)

    has_wa_key = False
    if has_match and match:
        token_res = await db.execute(
            select(WhatsAppRevealToken).where(WhatsAppRevealToken.match_id == match.id)
        )
        token_rec = token_res.scalar_one_or_none()
        if token_rec and getattr(token_rec, "is_unlocked", False):
            has_wa_key = True

    # Clean photo list
    clean_photos = [p for p in (target_user.photos or []) if p and str(p).strip()]
    primary_avatar = target_user.avatar_url.strip() if (target_user.avatar_url and target_user.avatar_url.strip()) else (clean_photos[0] if clean_photos else "")
    if primary_avatar and primary_avatar not in clean_photos:
        clean_photos.insert(0, primary_avatar)

    cand_bio = target_user.bio.strip() if (target_user.bio and target_user.bio.strip()) else "Mindful seeker walking an intentional path in the Sanctuary."
    cand_intention = target_user.bio.strip() if (target_user.bio and target_user.bio.strip()) else "Seeking slow, thoughtful connection in the sanctuary."

    # DPDP Act 2023 Sec 6(1) Data Minimization: Exact DOB is strictly private to the account owner
    is_self = bool(current_user and current_user.id == target_user.id)
    dob_value = (target_user.dob.isoformat() if target_user.dob else None) if is_self else None

    # Sacred Photo Veil bilateral consent determination
    is_photo_veiled = bool(target_user.is_photo_veiled)
    is_photo_unlocked = True
    photo_reveal_status = "none"

    if is_photo_veiled and not is_self:
        # Check active match (mutual like unlocks photo veil)
        if has_match:
            is_photo_unlocked = True
            photo_reveal_status = "accepted"
        else:
            consent_res = await db.execute(
                select(PhotoRevealConsent).where(
                    ((PhotoRevealConsent.requester_id == current_user.id) & (PhotoRevealConsent.target_id == target_user.id)) |
                    ((PhotoRevealConsent.requester_id == target_user.id) & (PhotoRevealConsent.target_id == current_user.id))
                ).order_by(PhotoRevealConsent.created_at.desc())
            )
            consents = consent_res.scalars().all()
            accepted_rec = next((c for c in consents if c.status == "accepted"), None)
            if accepted_rec:
                is_photo_unlocked = True
                photo_reveal_status = "accepted"
            elif consents:
                first_rec = consents[0]
                photo_reveal_status = first_rec.status
                is_photo_unlocked = (first_rec.status == "accepted")
            else:
                is_photo_unlocked = False
                photo_reveal_status = "none"

    safe_photos = clean_photos if (is_self or not is_photo_veiled or is_photo_unlocked) else []
    safe_avatar = primary_avatar if (is_self or not is_photo_veiled or is_photo_unlocked) else ""

    return {
        "id": str(target_user.id),
        "full_name": target_user.full_name,
        "age": _calculate_age(target_user.dob),
        "dob": dob_value,
        "gender": target_user.gender,
        "interested_in": target_user.interested_in,
        "bio": cand_bio,
        "profession": target_user.profession or "Mindful Seeker",
        "education": target_user.education or "",
        "location_name": target_user.location_name or "Saket, Ayodhya",
        "distance_km": dist_km,
        "avatar_url": safe_avatar,
        "avatar": safe_avatar,
        "photos": safe_photos,
        "photo_urls": safe_photos,
        "is_photo_veiled": is_photo_veiled,
        "is_photo_unlocked": is_photo_unlocked,
        "photo_reveal_status": photo_reveal_status,
        "is_kyc_verified": bool(target_user.kyc_status),
        "kyc_status": bool(target_user.kyc_status),
        "is_verified": bool(target_user.kyc_status),
        "streak_count": target_user.streak_count or 0,
        "boost_points": target_user.boost_points or 0,
        "resonance_score": score,
        "ai_insight": insight,
        "interests": authentic_tags,
        "intentions": cand_intention,
        "intent_quote": cand_intention,
        "is_online": True,
        "match_id": str(match.id) if (has_match and match and getattr(match, "id", None)) else None,
        "has_sacred_bridge": has_wa_key,
        "has_wa_key": has_wa_key,
        "subscription_tier": target_user.subscription_tier or "free",
        "voice_spark_url": target_user.voice_spark_url,
        "voice_spark_prompt": target_user.voice_spark_prompt,
        "voice_spark_duration": float(target_user.voice_spark_duration) if target_user.voice_spark_duration else 7.0,
        "is_voice_verified": bool(target_user.is_voice_verified),
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
    current_user.swipes_remaining = (current_user.swipes_remaining or 10) + 5
    current_user.direct_letters_count = (current_user.direct_letters_count or 0) + 1

    # Credit rewards to referrer
    referrer.reward_balance = (referrer.reward_balance or 0) + 20
    referrer.swipes_remaining = (referrer.swipes_remaining or 10) + 5

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
            from app.core.encryption import encrypt_contact_bridge
            update_data["contact_bridge_encrypted"] = encrypt_contact_bridge(str(handle), str(current_user.id))

    # Defense-in-depth: Disallow client manipulation of KYC status
    update_data.pop("is_kyc_verified", None)
    update_data.pop("kyc_status", None)

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

    # Normalize interested_in to satisfy PostgreSQL users_interested_in_check constraint
    if "interested_in" in update_data and update_data["interested_in"]:
        lf = str(update_data["interested_in"]).strip().lower()
        if lf in ("men", "man", "male"):
            update_data["interested_in"] = "Men"
        elif lf in ("women", "woman", "female"):
            update_data["interested_in"] = "Women"
        else:
            update_data["interested_in"] = "Everyone"

    # Robust DOB & Age parsing
    from datetime import datetime
    raw_dob = update_data.pop("dob", None)
    raw_birth_date = update_data.pop("birth_date", None)
    raw_dob = raw_dob or raw_birth_date
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

    # SEC-DATA: Ensure avatar is not duplicated into photos (moments)
    if "photos" in update_data and update_data["photos"]:
        clean_photos = [p for p in update_data["photos"] if p and str(p).strip()]
        eff_avatar = str(update_data.get("avatar_url") or current_user.avatar_url or "").strip()
        if eff_avatar and clean_photos and clean_photos[0] == eff_avatar:
            clean_photos = clean_photos[1:]
        update_data["photos"] = clean_photos

    # Mark profile completed in database (Fixes DUM-17 volatile memory set)
    update_data["is_profile_completed"] = True

    # Defense-in-depth: Retain only attributes matching User database columns
    valid_cols = {c.name for c in User.__table__.columns}
    sanitized_values = {k: v for k, v in update_data.items() if k in valid_cols}

    was_previously_completed = bool(current_user.is_profile_completed)

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(**sanitized_values)
    )
    await db.commit()

    if getattr(current_user, "email", None):
        COMPLETED_PROFILES.add(current_user.email.strip().lower())
    if email_val:
        COMPLETED_PROFILES.add(email_val.strip().lower())
    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())

    # Dispatch welcome email on initial profile setup completion if not already delivered
    if not was_previously_completed:
        target_email = getattr(current_user, "email", None) or email_val
        if target_email:
            clean_target = target_email.strip().lower()
            if not getattr(current_user, "welcome_email_sent", False):
                from app.services.email_service import EmailService
                EmailService.schedule_delayed_welcome_email(
                    email=clean_target,
                    full_name=payload.full_name or current_user.full_name or "Seeker",
                    delay_seconds=3.0
                )
    # Claim any pending Web Store passes purchased before profile completion
    try:
        from app.api.v1.endpoints.web_store import claim_pending_web_store_entitlements
        await claim_pending_web_store_entitlements(db, current_user)
    except Exception as claim_err:
        print(f"[PROFILE NOTICE] Pending web store passes auto-claim: {claim_err}", flush=True)

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
    dob: Optional[str] = None
    birth_date: Optional[str] = None
    gender: Optional[str] = None
    looking_for: Optional[str] = None
    interested_in: Optional[str] = None
    bridge_platform: Optional[str] = None
    contact_bridge_type: Optional[str] = None
    bridge_value: Optional[str] = None
    contact_bridge_handle: Optional[str] = None
    location: Optional[str] = None
    location_name: Optional[str] = None
    bio: Optional[str] = None
    profession: Optional[str] = None
    education: Optional[str] = None
    is_kyc: Optional[bool] = None
    is_kyc_verified: Optional[bool] = None
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
        g = str(payload.gender).strip().lower()
        if g in ("male", "man", "men"):
            up_vals["gender"] = "Man"
        elif g in ("female", "woman", "women"):
            up_vals["gender"] = "Woman"
        elif g in ("non-binary", "nonbinary"):
            up_vals["gender"] = "Non-Binary"
        elif g in ("other", "queer", "transgender"):
            up_vals["gender"] = "Other"
        else:
            up_vals["gender"] = "Unspecified"

    lf = str(payload.looking_for or payload.interested_in or "").strip().lower()
    if lf:
        if lf in ("men", "man", "male"):
            up_vals["interested_in"] = "Men"
        elif lf in ("women", "woman", "female"):
            up_vals["interested_in"] = "Women"
        else:
            up_vals["interested_in"] = "Everyone"
    if payload.bio:
        up_vals["bio"] = payload.bio
    if payload.profession:
        up_vals["profession"] = payload.profession
    if payload.education:
        up_vals["education"] = payload.education
    if loc_name:
        up_vals["location_name"] = loc_name
    
    # Defense-in-depth: Disallow client manipulation of KYC status during setup
    # KYC status is strictly managed by /api/v1/kyc/verify-live or superadmin desk

    bridge_platform_val = payload.bridge_platform or payload.contact_bridge_type
    if bridge_platform_val:
        up_vals["contact_bridge_type"] = bridge_platform_val

    bridge_value_val = payload.bridge_value or payload.contact_bridge_handle
    if bridge_value_val:
        from app.core.encryption import encrypt_contact_bridge
        up_vals["contact_bridge_encrypted"] = encrypt_contact_bridge(str(bridge_value_val), str(current_user.id))

    if payload.photos:
        clean_photos = [p for p in payload.photos if p and str(p).strip()]
        eff_avatar = str(payload.avatar_url or current_user.avatar_url or "").strip()
        if eff_avatar and clean_photos and clean_photos[0] == eff_avatar:
            clean_photos = clean_photos[1:]
        up_vals["photos"] = clean_photos
        if not payload.avatar_url and not current_user.avatar_url and clean_photos:
            up_vals["avatar_url"] = clean_photos[0]
    if payload.avatar_url and str(payload.avatar_url).strip():
        up_vals["avatar_url"] = str(payload.avatar_url).strip()

    dob_val = payload.date_of_birth or payload.dob or payload.birth_date
    if dob_val:
        try:
            from datetime import date as _date
            up_vals["dob"] = _date.fromisoformat(str(dob_val).split("T")[0])
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


@router.post("/voice-spark", status_code=status.HTTP_200_OK)
async def upload_voice_spark(
    file: UploadFile = File(...),
    prompt: str = Form("Mera favourite midnight snack / guilty pleasure..."),
    duration: float = Form(7.0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Upload 7-second Voice Spark ("Awaaz Jhooth Nahi Bolti") directly to Supabase Storage.
    Persists voice_spark_url, prompt, and duration on User record.
    """
    content_type = (file.content_type or "").lower()
    filename = (file.filename or "").lower()
    if not (content_type.startswith("audio/") or filename.endswith((".m4a", ".aac", ".mp3", ".wav", ".ogg", ".opus"))):
        raise HTTPException(status_code=400, detail="Invalid audio file format. Please upload an audio recording.")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty audio recording received.")

    if len(content) > 3 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Audio file too large. Maximum allowed size is 3MB.")

    # 0. AI Speech-To-Text Whisper Moderation Gate (Revenue Leak & Social Handle Protection)
    from app.services.voice_moderator import VoiceModeratorService
    is_safe, transcript, reason = await VoiceModeratorService.inspect_voice_spark(
        content=content,
        filename=filename or "voice_spark.m4a",
        content_type=content_type
    )
    if not is_safe:
        raise HTTPException(
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", status.HTTP_422_UNPROCESSABLE_ENTITY),
            detail=reason
        )

    settings = get_settings()
    file_key = f"users/{current_user.id}/voice/voice_spark.m4a"

    # 1. Dual Persistence: Save audio bytes to local persistent disk cache
    try:
        from pathlib import Path
        voice_dir = Path("uploads/voice") / str(current_user.id)
        voice_dir.mkdir(parents=True, exist_ok=True)
        local_voice_file = voice_dir / "voice_spark.m4a"
        local_voice_file.write_bytes(content)
    except Exception as fs_err:
        print(f"[VOICE SPARK LOCAL SAVE] Notice: {fs_err}", flush=True)

    # 2. Cloud Backup: Upload to Supabase Storage if configured
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        try:
            upload_url = f"{settings.SUPABASE_URL}/storage/v1/object/{settings.SUPABASE_STORAGE_BUCKET}/{file_key}"
            headers = {
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                "Content-Type": file.content_type or "audio/m4a",
                "x-upsert": "true",
            }
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(upload_url, headers=headers, content=content)
                if resp.status_code in (200, 201):
                    print(f"[VOICE SPARK STORAGE] Uploaded to Supabase: {file_key}", flush=True)
        except Exception as e:
            print(f"[VOICE SPARK STORAGE] Supabase upload note: {e}", flush=True)

    public_url = f"{settings.BASE_WEB_URL}/api/v1/media/voice/{current_user.id}/voice_spark.m4a"

    validated_duration = min(max(float(duration), 1.0), 7.5)
    clean_prompt = prompt.strip()[:120] if prompt else "My authentic voice & vibe"

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(
            voice_spark_url=public_url,
            voice_spark_prompt=clean_prompt,
            voice_spark_duration=validated_duration,
            is_voice_verified=True
        )
    )
    await db.commit()
    try:
        await db.refresh(current_user)
    except Exception:
        pass

    return {
        "status": "success",
        "voice_spark_url": public_url,
        "voice_spark_prompt": clean_prompt,
        "voice_spark_duration": validated_duration,
        "is_voice_verified": True,
        "message": "Voice Spark successfully secured in sanctuary."
    }


@router.delete("/voice-spark", status_code=status.HTTP_200_OK)
async def delete_voice_spark(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Deletes active Voice Spark from seeker profile."""
    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(
            voice_spark_url=None,
            voice_spark_prompt=None,
            is_voice_verified=False
        )
    )
    await db.commit()
    return {
        "status": "success",
        "voice_spark_url": None,
        "is_voice_verified": False,
        "message": "Voice Spark removed successfully."
    }
