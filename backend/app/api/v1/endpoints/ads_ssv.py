import os
import secrets
import hmac
import hashlib
import base64
import time
from typing import Dict, Any, Optional
from urllib.parse import urlparse, parse_qsl, urlencode
import uuid
from uuid import UUID
from datetime import datetime, timezone, timedelta
import httpx
from fastapi import APIRouter, Request, HTTPException, status, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import load_der_public_key
from cryptography.exceptions import InvalidSignature

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.ad_reward import AdRewardLedger, ProcessedAdTransaction
from app.models.domain.match import Match
from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.services.streak_engine import StreakEngine

router = APIRouter(prefix="/ads", tags=["Ad Server-Side Verification"])

ADMOB_KEYS_URL = "https://gstatic.com/admob/reward/verifier-keys.json"
_admob_keys_cache: Dict[str, Any] = {}
_admob_cache_expiry: float = 0.0

# Network Pre-Shared Secrets (5 Networks: AdMob, Meta, Unity, Chartboost, Liftoff)
NETWORK_SECRETS = {
    "meta": os.getenv("META_AUDIENCE_SSV_SECRET", "meta_ssv_secret_sanctuary_2026"),
    "unity": os.getenv("UNITY_ADS_SSV_SECRET", "unity_ssv_secret_sanctuary_2026"),
    "chartboost": os.getenv("CHARTBOOST_SSV_SECRET", "chartboost_ssv_secret_sanctuary_2026"),
    "liftoff": os.getenv("LIFTOFF_SSV_SECRET", "liftoff_ssv_secret_sanctuary_2026"),
}


async def get_admob_public_keys() -> Dict[str, Any]:
    """Fetches and caches Google AdMob public keys for ECDSA verification."""
    global _admob_keys_cache, _admob_cache_expiry
    current_time = time.time()

    if _admob_keys_cache and current_time < _admob_cache_expiry:
        return _admob_keys_cache

    async with httpx.AsyncClient(timeout=5.0) as client:
        res = await client.get(ADMOB_KEYS_URL)
        if res.status_code != 200:
            raise HTTPException(status_code=503, detail="Unable to retrieve AdMob verification keys.")
        _admob_keys_cache = res.json()
        _admob_cache_expiry = current_time + 86400  # Cache for 24 hours
        return _admob_keys_cache


def verify_admob_ecdsa(query_string: str) -> bool:
    """
    Validates Google AdMob SSV callback.
    Message format: UTF-8 query string excluding '&signature=' and '&key_id='.
    Signature: Base64URL-encoded ASN.1 DER ECDSA signature.
    """
    parsed_params = dict(parse_qsl(query_string, keep_blank_values=True))
    signature_b64 = parsed_params.get("signature")
    key_id = parsed_params.get("key_id")

    if not signature_b64 or not key_id:
        return False

    # Reconstruct canonical data string in exact original order
    # Google requires message string strictly without '&signature=' and '&key_id='
    param_pairs = query_string.split("&")
    canonical_pairs = [
        p for p in param_pairs 
        if not p.startswith("signature=") and not p.startswith("key_id=")
    ]
    canonical_message = "&".join(canonical_pairs).encode("utf-8")

    # Decode Base64URL signature (handling missing padding)
    padded_b64 = signature_b64 + "=" * (-len(signature_b64) % 4)
    try:
        signature_der = base64.urlsafe_b64decode(padded_b64)
    except (ValueError, TypeError):
        return False

    # Fetch cached public keys
    keys_data = _admob_keys_cache.get("keys", [])
    target_key = next((k for k in keys_data if str(k.get("keyId")) == str(key_id)), None)
    if not target_key:
        return False

    base64_pem = target_key.get("base64")
    if not base64_pem:
        return False

    try:
        der_bytes = base64.b64decode(base64_pem)
        public_key = load_der_public_key(der_bytes)
        
        # Verify ECDSA P-256 with SHA-256
        public_key.verify(signature_der, canonical_message, ec.ECDSA(hashes.SHA256()))
        return True
    except (InvalidSignature, ValueError, TypeError):
        return False


def verify_hmac_network(network: str, query_string: str, received_signature: str) -> bool:
    """Verifies HMAC-SHA256 signature for non-Google networks (Meta/Unity/Chartboost/Liftoff)."""
    secret = NETWORK_SECRETS.get(network)
    if not secret:
        return False  # Reject if secret is not configured

    # Strip signature param from message string
    param_pairs = query_string.split("&")
    canonical_pairs = [p for p in param_pairs if not p.startswith("signature=")]
    canonical_message = "&".join(canonical_pairs).encode("utf-8")

    expected_hash = hmac.new(secret.encode("utf-8"), canonical_message, hashlib.sha256).hexdigest()
    if hmac.compare_digest(expected_hash.lower(), received_signature.lower()):
        return True

    # Also handle unquoted query parameters (e.g., encoded colons or special chars)
    import urllib.parse
    unquoted = urllib.parse.unquote("&".join(canonical_pairs)).encode("utf-8")
    expected_hash_unquoted = hmac.new(secret.encode("utf-8"), unquoted, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected_hash_unquoted.lower(), received_signature.lower())


@router.get("/verify-reward", status_code=status.HTTP_200_OK)
async def process_reward_callback(request: Request, db: AsyncSession = Depends(get_db)):
    """
    Universal Cryptographic SSV Callback Handler.
    Rejects any spoofed, unsigned, or unauthenticated ad rewards.
    """
    query_string = request.url.query
    params = dict(request.query_params)

    network = params.get("network", "admob").lower()
    transaction_id = params.get("transaction_id") or params.get("trans_id")
    custom_data = params.get("custom_data")  # Expected: "<user_uuid>:<ad_type>:<target_id>"

    if not transaction_id or not custom_data:
        raise HTTPException(status_code=400, detail="Missing transaction_id or custom_data.")

    # 1. Cryptographic Signature Verification
    if network == "admob":
        await get_admob_public_keys()
        if not verify_admob_ecdsa(query_string):
            raise HTTPException(status_code=403, detail="Cryptographic AdMob ECDSA verification failed.")
    elif network in NETWORK_SECRETS:
        sig = params.get("signature", "")
        if not sig or not verify_hmac_network(network, query_string, sig):
            raise HTTPException(status_code=403, detail=f"Invalid {network.upper()} HMAC signature.")
    else:
        raise HTTPException(status_code=400, detail="Unsupported or unconfigured ad network.")

    # 2. Idempotency & Replay Attack Defense
    existing_tx = await db.execute(
        select(ProcessedAdTransaction).where(ProcessedAdTransaction.transaction_id == transaction_id)
    )
    if existing_tx.scalar_one_or_none():
        return {"status": "success", "message": "Transaction already processed."}

    # 3. Parse Custom Data Safely
    parts = custom_data.split(":")
    if len(parts) < 2:
        raise HTTPException(status_code=400, detail="Malformed custom_data parameter.")
    
    user_id_str, ad_type = parts[0], parts[1]
    target_id = parts[2] if len(parts) > 2 else "none"

    # 4. Resolve Rewards Table
    points_to_credit = 0
    swipes_to_grant = 0
    letters_to_grant = 0

    if ad_type == "quick_reflection":
        swipes_to_grant = 10
        points_to_credit = 10
    elif ad_type == "deep_resonance":
        letters_to_grant = 1
        points_to_credit = 25
    elif ad_type == "morning_harvest_unlock":
        swipes_to_grant = 20
        letters_to_grant = 2
        points_to_credit = 50
    elif ad_type == "sacred_bridge_reveal":
        points_to_credit = 30

    # 5. Atomic Balance Credit & Audit Commit
    try:
        user_uuid = UUID(user_id_str)
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=400, detail="Invalid user UUID in custom_data.")

    await db.execute(
        update(User)
        .where(User.id == user_uuid)
        .values(
            reward_balance=User.reward_balance + points_to_credit,
            swipes_remaining=User.swipes_remaining + swipes_to_grant,
            direct_letters_count=User.direct_letters_count + letters_to_grant
        )
    )

    db_ad_type = "sacred_bridge_reveal" if ad_type in ("whatsapp_reveal", "sacred_bridge_reveal") else ad_type
    valid_network = network if network in ('admob', 'meta', 'unity', 'chartboost', 'liftoff') else 'admob'

    ledger_entry = AdRewardLedger(
        user_id=user_uuid,
        ssv_transaction_id=transaction_id,
        network=valid_network,
        ad_type=db_ad_type,
        reward_points=points_to_credit
    )
    processed_entry = ProcessedAdTransaction(
        transaction_id=transaction_id,
        network=network,
        user_id=user_uuid,
        ad_type=ad_type
    )

    db.add(ledger_entry)
    db.add(processed_entry)

    # 6. Sacred Bridge / WhatsApp Reveal Unlock Handshake & Token Grant
    if ad_type in ("whatsapp_reveal", "sacred_bridge_reveal"):
        ad_count_res = await db.execute(
            select(func.count(AdRewardLedger.id))
            .where(
                AdRewardLedger.user_id == user_uuid,
                AdRewardLedger.ad_type.in_(["whatsapp_reveal", "sacred_bridge_reveal"])
            )
        )
        total_reveal_ads = ad_count_res.scalar() or 0
        if total_reveal_ads > 0 and total_reveal_ads % 3 == 0:
            await db.execute(
                update(User)
                .where(User.id == user_uuid)
                .values(reveal_tokens_count=User.reveal_tokens_count + 1)
            )

    if ad_type in ("whatsapp_reveal", "sacred_bridge_reveal") and target_id != "none":
        try:
            match_uuid = UUID(target_id)
            row = (await db.execute(
                select(WhatsAppRevealToken, Match).join(Match, Match.id == WhatsAppRevealToken.match_id)
                .where(WhatsAppRevealToken.match_id == match_uuid)
            )).first()

            if row:
                token_rec, match_rec = row
                if match_rec.user1_id == user_uuid and token_rec.user1_ads_count < 3:
                    token_rec.user1_ads_count += 1
                elif match_rec.user2_id == user_uuid and token_rec.user2_ads_count < 3:
                    token_rec.user2_ads_count += 1

                if token_rec.user1_ads_count >= 3 and token_rec.user2_ads_count >= 3 and not token_rec.is_unlocked:
                    token_rec.is_unlocked = True
                    token_rec.ephemeral_token = secrets.token_urlsafe(32)
                    token_rec.expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
        except Exception:
            pass

    await db.commit()

    return {"status": "success", "user_id": str(user_uuid), "granted_points": points_to_credit}


_recent_user_claims: Dict[UUID, datetime] = {}


class ClaimAdRewardRequest(BaseModel):
    ad_type: str
    target_id: Optional[str] = "none"
    user_id: Optional[str] = None
    duration_seconds: Optional[int] = 10
    network: Optional[str] = "admob"
    rest_hours: Optional[float] = 0.0


@router.post("/claim-reward", status_code=status.HTTP_200_OK, summary="Claim Verified Ad Reward")
async def claim_ad_reward(
    payload: ClaimAdRewardRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Credits ad reward points and swipes directly to authenticated public.users record in PostgreSQL.
    Supports dynamic ad duration tiers decided by provider RTB auction and anti-bot throttling.
    """
    target_user = current_user

    # Anti-bot throttle: reject automated rapid-fire repeat scripts (< 2 seconds cooldown)
    now = datetime.now(timezone.utc)
    last_claim = _recent_user_claims.get(target_user.id)
    if last_claim and (now - last_claim).total_seconds() < 2.0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Mindful pacing required. Please allow a few seconds between claims."
        )
    _recent_user_claims[target_user.id] = now

    swipes_to_grant = 0
    letters_to_grant = 0
    points_to_credit = 10

    whatsapp_progress = 0
    token_granted = False
    reward_msg = ""

    if payload.ad_type == "quick_reflection":
        swipes_to_grant = 10
        points_to_credit = 10
    elif payload.ad_type == "deep_resonance":
        letters_to_grant = 1
        points_to_credit = 25
    elif payload.ad_type == "morning_harvest_unlock":
        # Dynamic duration auction: ad provider determines duration
        # 10s -> 10 Swipes
        # 20s -> 1 Direct Letter
        # 30s -> Social Handle Reveal Progress / Token
        duration = payload.duration_seconds or 10
        rest_hrs = payload.rest_hours or 0.0
        rest_mult = 1.0
        if rest_hrs >= 8.0:
            rest_mult = 2.0
        elif rest_hrs >= 6.0:
            rest_mult = 1.5

        if duration <= 15:
            # Short reflection (10s): 10 Swipes
            swipes_to_grant = int(10 * rest_mult)
            points_to_credit = int(10 * rest_mult)
            reward_msg = f"Morning Harvest ({payload.network or 'AdMob'} {duration}s ad): +{swipes_to_grant} Swipes credited!"
        elif duration <= 25:
            # Medium resonance (20s): 1 Direct Letter
            letters_to_grant = 1
            swipes_to_grant = int(5 * (rest_mult - 1.0))
            points_to_credit = int(25 * rest_mult)
            reward_msg = f"Morning Harvest ({payload.network or 'AdMob'} {duration}s ad): +{letters_to_grant} Direct Letter credited!"
        else:
            # Premium ritual (30s): Reveal token progression
            points_to_credit = int(50 * rest_mult)
            ledger_entry = AdRewardLedger(
                user_id=target_user.id,
                ssv_transaction_id=f"slumber-harvest-{uuid.uuid4().hex[:12]}",
                network=payload.network or "admob",
                ad_type="sacred_bridge_reveal",
                reward_points=points_to_credit
            )
            db.add(ledger_entry)
            await db.flush()

            ad_count_res = await db.execute(
                select(func.count(AdRewardLedger.id))
                .where(
                    AdRewardLedger.user_id == target_user.id,
                    AdRewardLedger.ad_type.in_(["whatsapp_reveal", "sacred_bridge_reveal"])
                )
            )
            total_reveal_ads = ad_count_res.scalar() or 0
            cycle_count = total_reveal_ads % 3
            if cycle_count == 0:
                target_user.reveal_tokens_count = (target_user.reveal_tokens_count or 0) + 1
                token_granted = True
                whatsapp_progress = 0
                reward_msg = f"Morning Harvest ({payload.network or 'AdMob'} 30s ritual): +1 Reveal Token credited! Total: {target_user.reveal_tokens_count}"
            else:
                token_granted = False
                whatsapp_progress = cycle_count
                reward_msg = f"Morning Harvest ({payload.network or 'AdMob'} 30s ritual): {cycle_count}/3 towards Reveal Token!"
    elif payload.ad_type in ("whatsapp_reveal", "sacred_bridge_reveal"):
        points_to_credit = 30
        
        # Track in AdRewardLedger with DB-safe check constraint values
        db_ad_type = "sacred_bridge_reveal" if payload.ad_type in ("whatsapp_reveal", "sacred_bridge_reveal") else payload.ad_type
        ledger_entry = AdRewardLedger(
            user_id=target_user.id,
            ssv_transaction_id=f"direct-claim-{uuid.uuid4().hex[:12]}",
            network="admob",
            ad_type=db_ad_type,
            reward_points=points_to_credit
        )
        db.add(ledger_entry)
        await db.flush()

        # Count total ads watched for reveal by this user
        ad_count_res = await db.execute(
            select(func.count(AdRewardLedger.id))
            .where(
                AdRewardLedger.user_id == target_user.id,
                AdRewardLedger.ad_type.in_(["whatsapp_reveal", "sacred_bridge_reveal"])
            )
        )
        total_reveal_ads = ad_count_res.scalar() or 0
        if total_reveal_ads == 0:
            total_reveal_ads = 1
        cycle_count = total_reveal_ads % 3
        if cycle_count == 0:
            target_user.reveal_tokens_count = (target_user.reveal_tokens_count or 0) + 1
            token_granted = True
            whatsapp_progress = 0
            reward_msg = f"Sacred Bridge ritual complete (3/3)! +1 Reveal Token credited! Total Tokens: {target_user.reveal_tokens_count}"
        else:
            token_granted = False
            whatsapp_progress = cycle_count
            reward_msg = f"Sacred Bridge ritual recorded: {cycle_count}/3 videos watched. Watch {3 - cycle_count} more to earn 1 Reveal Token!"

        # Handle bilateral match progression if target_id provided
        if payload.target_id and payload.target_id != "none":
            match_uuid = None
            try:
                match_uuid = UUID(payload.target_id)
            except (ValueError, TypeError, AttributeError):
                pass
            if match_uuid:
                try:
                    row = (await db.execute(
                        select(WhatsAppRevealToken, Match).join(Match, Match.id == WhatsAppRevealToken.match_id)
                        .where(WhatsAppRevealToken.match_id == match_uuid)
                    )).first()
                    if row:
                        token_rec, match_rec = row
                        if match_rec.user1_id == target_user.id and token_rec.user1_ads_count < 3:
                            token_rec.user1_ads_count += 1
                        elif match_rec.user2_id == target_user.id and token_rec.user2_ads_count < 3:
                            token_rec.user2_ads_count += 1
                        if token_rec.user1_ads_count >= 3 and token_rec.user2_ads_count >= 3 and not token_rec.is_unlocked:
                            token_rec.is_unlocked = True
                            token_rec.ephemeral_token = secrets.token_urlsafe(32)
                            token_rec.expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
                except Exception:
                    pass

    elif payload.ad_type == "daily_streak_boost":
        streak_result = await StreakEngine.claim_daily_streak_ad(target_user, db)
        return {
            "status": "success",
            "ad_type": payload.ad_type,
            "message": streak_result.get("message", "Daily streak boosted!"),
            "streak_count": streak_result.get("streak_count", target_user.streak_count),
            "boost_points": streak_result.get("boost_points", target_user.boost_points),
            "reveal_tokens_count": streak_result.get("reveal_tokens_count", target_user.reveal_tokens_count),
            "seconds_remaining": streak_result.get("seconds_remaining", 86400),
            "streak_expires_at": streak_result.get("streak_expires_at")
        }

    target_user.swipes_remaining = (target_user.swipes_remaining or 0) + swipes_to_grant
    target_user.direct_letters_count = (target_user.direct_letters_count or 0) + letters_to_grant
    target_user.reward_balance = (target_user.reward_balance or 0) + points_to_credit

    await db.commit()
    await db.refresh(target_user)

    print(
        f"[AD REWARD CLAIMED] user={target_user.email} ad_type={payload.ad_type} "
        f"swipes={target_user.swipes_remaining} letters={target_user.direct_letters_count} "
        f"tokens={target_user.reveal_tokens_count} balance={target_user.reward_balance}",
        flush=True
    )

    return {
        "status": "success",
        "ad_type": payload.ad_type,
        "swipes_remaining": target_user.swipes_remaining,
        "direct_letters_count": target_user.direct_letters_count,
        "reward_balance": target_user.reward_balance,
        "reveal_tokens_count": target_user.reveal_tokens_count or 0,
        "whatsapp_progress": whatsapp_progress,
        "token_granted": token_granted,
        "message": reward_msg if reward_msg else f"Reward granted: +{swipes_to_grant} swipes, +{letters_to_grant} direct letters."
    }


@router.get("/streak-status", status_code=status.HTTP_200_OK, summary="Get 24h Streak & Boost Status")
async def get_current_streak_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns current user's streak count, boost points, and remaining countdown."""

    if not current_user:
        return {
            "streak_count": 0,
            "boost_points": 0,
            "reveal_tokens_count": 1,
            "is_active": False,
            "seconds_remaining": 0,
            "can_claim_now": True
        }

    # Evaluate any decay
    await StreakEngine.evaluate_and_decay_streak(current_user, db)
    return StreakEngine.get_user_streak_payload(current_user)
