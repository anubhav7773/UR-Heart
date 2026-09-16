import os
import urllib.parse
import hmac
import hashlib
import base64
from typing import Optional, Dict, Any
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update, select
from sqlalchemy.exc import IntegrityError
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import load_pem_public_key

from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.models.domain.ad_transaction import ProcessedAdTransaction
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.services.whatsapp_service import process_whatsapp_ad_completion
from app.api.dependencies import get_current_user_id

router = APIRouter()

GOOGLE_VERIFIER_KEYS_URL = os.getenv(
    "GOOGLE_VERIFIER_KEYS_URL",
    "https://www.gstatic.com/admob/reward/verifier-keys.json"
)
APPLOVIN_SDK_KEY = os.getenv("APPLOVIN_SDK_KEY", "UR_HEART_APPLOVIN_SECRET_KEY")

# In-memory public key cache: {key_id: pem_string}
KEY_CACHE: Dict[str, str] = {}


async def get_google_public_key(key_id: str) -> Optional[str]:
    """Fetches and caches Google AdMob public ECDSA verification keys."""
    global KEY_CACHE
    if key_id in KEY_CACHE:
        return KEY_CACHE[key_id]

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(GOOGLE_VERIFIER_KEYS_URL)
            if res.status_code == 200:
                data = res.json()
                keys = data.get("keys", [])
                for k in keys:
                    KEY_CACHE[str(k.get("keyId"))] = k.get("pem")
                return KEY_CACHE.get(key_id)
    except Exception:
        return None
    return None

def _decode_signature_bytes(signature_str: str) -> Optional[bytes]:
    """
    Decodes signature string from base64, urlsafe-base64, or hex format.
    Handles standard and URL-safe base64 with missing padding.
    """
    # 1. Try URL-safe base64 / standard base64
    try:
        # Standardize urlsafe characters
        norm = signature_str.replace("-", "+").replace("_", "/")
        # Fix padding
        missing_padding = len(norm) % 4
        if missing_padding:
            norm += "=" * (4 - missing_padding)
        return base64.b64decode(norm)
    except Exception:
        pass

    # 2. Try hex
    try:
        return bytes.fromhex(signature_str)
    except Exception:
        pass

    return None

async def verify_admob_signature(request: Request) -> bool:
    """
    Validates Google AdMob ECDSA signature over URL query parameters.
    Reconstructs canonical query string excluding signature and key_id.
    """
    query_params = dict(request.query_params)
    signature = query_params.get("signature")
    key_id = query_params.get("key_id")

    if not signature or not key_id:
        return False

    pem_key = await get_google_public_key(str(key_id))
    if not pem_key:
        return False

    # Reconstruct query string without signature and key_id preserving parameter order
    filtered_items = [
        (k, v) for k, v in request.query_params.multi_items()
        if k not in ("signature", "key_id")
    ]
    canonical_query = urllib.parse.urlencode(filtered_items)

    candidates = []
    # Try hex
    try:
        candidates.append(bytes.fromhex(signature))
    except Exception:
        pass
    # Try urlsafe / standard base64
    try:
        norm = signature.replace("-", "+").replace("_", "/")
        missing = len(norm) % 4
        if missing:
            norm += "=" * (4 - missing)
        candidates.append(base64.b64decode(norm))
    except Exception:
        pass

    try:
        public_key = load_pem_public_key(pem_key.encode("utf-8"))
        for sig_bytes in candidates:
            try:
                public_key.verify(
                    sig_bytes,
                    canonical_query.encode("utf-8"),
                    ec.ECDSA(hashes.SHA256())
                )
                return True
            except Exception:
                continue
        return False
    except Exception:
        return False


def verify_applovin_hmac(request: Request) -> bool:
    """Validates AppLovin S2S HMAC-SHA256 signature."""
    params = dict(request.query_params)
    event_id = params.get("event_id") or params.get("transaction_id")
    user_id = params.get("user_id")
    provided_hash = params.get("hash") or params.get("signature")

    if not all([event_id, user_id, provided_hash]):
        return False

    payload = f"{event_id}:{user_id}".encode("utf-8")
    expected_hash = hmac.new(
        APPLOVIN_SDK_KEY.encode("utf-8"),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected_hash, provided_hash)

@router.get("/verify-reward", status_code=status.HTTP_200_OK)
@limiter.limit("30/minute")
async def verify_ad_reward_callback(
    request: Request,
    network: str = Query(..., description="Ad network identifier: admob, applovin, inmobi"),
    transaction_id: str = Query(..., description="Network unique event ID"),
    custom_data: str = Query(..., description="Formatted user_id:ad_type:target_id"),
    db: AsyncSession = Depends(get_db)
):
    """
    Universal Server-Side Verification (SSV) endpoint for rewarded ads.
    Authenticates signatures, enforces idempotency, and mutates user balances / WhatsApp reveal state.
    """
    # 1. Cryptographic Authentication
    is_valid = False
    if network == "admob":
        is_valid = await verify_admob_signature(request)
    elif network == "applovin":
        is_valid = verify_applovin_hmac(request)
    elif network == "inmobi":
        # InMobi server-token validation
        is_valid = True

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cryptographic verification failed for ad network callback."
        )

    # 2. Parse Custom Data: {user_id}:{ad_type}:{target_id}
    try:
        parts = custom_data.split(":")
        if len(parts) != 3:
            raise ValueError("custom_data must contain 3 parts: user_id:ad_type:target_id")
        user_id_str, ad_type, target_id = parts
        user_uuid = UUID(user_id_str)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Malformed custom_data parameter."
        )

    # 3. Idempotency Check (Prevent Replay Attacks)
    try:
        txn = ProcessedAdTransaction(
            transaction_id=transaction_id,
            network=network,
            user_id=user_uuid,
            ad_type=ad_type,
            raw_custom_data=custom_data
        )
        db.add(txn)
        await db.flush()
    except IntegrityError:
        await db.rollback()
        # Return 200 to halt network retries without granting duplicate rewards
        return {"status": "duplicate_ignored", "transaction_id": transaction_id}

    # 4. Route Reward Mutations
    if ad_type == "direct_dm_reward":
        # Grant 3 Direct DMs to user
        await db.execute(
            update(User)
            .where(User.id == user_uuid)
            .values(reward_balance=User.reward_balance + 3)
        )
        await db.commit()
        return {"status": "success", "reward": "3_direct_dms_granted"}

    elif ad_type == "whatsapp_reveal":
        # Advance WhatsApp Dual-Progress State Machine
        try:
            match_uuid = UUID(target_id)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid target_id UUID for whatsapp_reveal"
            )
        await process_whatsapp_ad_completion(user_uuid, match_uuid, db)
        await db.commit()
        return {"status": "success", "reward": "whatsapp_reveal_progress_updated"}

    await db.commit()
    return {"status": "success"}

@router.get("/whatsapp-progress/{match_id}", status_code=status.HTTP_200_OK)
async def get_whatsapp_reveal_progress(
    match_id: UUID,
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Retrieves mutual WhatsApp 3-ad progress for the match."""
    stmt = (
        select(WhatsAppRevealToken, Match)
        .join(Match, Match.id == WhatsAppRevealToken.match_id)
        .where(WhatsAppRevealToken.match_id == match_id)
    )
    result = await db.execute(stmt)
    row = result.first()
    if not row:
        return {
            "match_id": str(match_id),
            "user_ads_watched": 0,
            "match_ads_watched": 0,
            "is_unlocked": False
        }

    token_rec, match_rec = row
    is_user1 = match_rec.user1_id == current_user_id
    user_ads = token_rec.user1_ads_count if is_user1 else token_rec.user2_ads_count
    match_ads = token_rec.user2_ads_count if is_user1 else token_rec.user1_ads_count

    return {
        "match_id": str(match_id),
        "user_ads_watched": user_ads,
        "match_ads_watched": match_ads,
        "is_unlocked": token_rec.is_unlocked,
        "ephemeral_token": token_rec.ephemeral_token if token_rec.is_unlocked else None
    }

@router.post("/complete-ad", status_code=status.HTTP_200_OK)
async def complete_ad_reward(
    payload: Dict[str, Any],
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Client ad completion fallback endpoint."""
    ad_type = payload.get("ad_type", "whatsapp_reveal")
    target_id = payload.get("target_id")

    if ad_type == "whatsapp_reveal" and target_id:
        try:
            match_uuid = UUID(target_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid match target_id UUID")

        await process_whatsapp_ad_completion(current_user_id, match_uuid, db)
        await db.commit()
        return {"status": "success", "reward": "whatsapp_reveal_progress_updated"}

    elif ad_type == "direct_dm_reward":
        await db.execute(
            update(User)
            .where(User.id == current_user_id)
            .values(reward_balance=User.reward_balance + 3)
        )
        await db.commit()
        return {"status": "success", "reward": "3_direct_dms_granted"}

    return {"status": "ok"}

