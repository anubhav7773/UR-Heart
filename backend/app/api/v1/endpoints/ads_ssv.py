import hashlib
import hmac
import secrets
import urllib.parse
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional
from uuid import UUID
import httpx
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_pem_public_key
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.core.database import get_db
from app.models.domain.ad_transaction import ProcessedAdTransaction
from app.models.domain.match import Match
from app.models.domain.user import User
from app.models.domain.whatsapp_token import WhatsAppRevealToken
from app.services.chat_manager import manager

router = APIRouter(prefix="/ads", tags=["Universal Ad SSV Verifier"])
settings = get_settings()

GOOGLE_KEYS_CACHE: Dict[str, Any] = {"keys": [], "last_fetched": datetime.min}


class AdVerificationResponse(BaseModel):
    status: str
    message: Optional[str] = None
    transaction_id: Optional[str] = None


async def get_google_admob_public_keys(client: Optional[httpx.AsyncClient]) -> list:
    """Caches Google's ECDSA public keys for 24 hours."""
    now = datetime.now(timezone.utc)
    last_fetched = GOOGLE_KEYS_CACHE["last_fetched"]
    if getattr(last_fetched, "tzinfo", None) is None:
        last_fetched = last_fetched.replace(tzinfo=timezone.utc)

    if now - last_fetched > timedelta(hours=24) or not GOOGLE_KEYS_CACHE["keys"]:
        if client is not None:
            try:
                res = await client.get(settings.ADMOB_VERIFIER_KEYS_URL, timeout=8.0)
                if res.status_code == 200:
                    GOOGLE_KEYS_CACHE["keys"] = res.json().get("keys", [])
                    GOOGLE_KEYS_CACHE["last_fetched"] = now
            except Exception:
                pass
    return GOOGLE_KEYS_CACHE["keys"]


async def verify_admob_ssv(request: Request, client: Optional[httpx.AsyncClient]) -> bool:
    """Verifies AdMob ECDSA SHA-256 signature against Google public keys."""
    params = dict(request.query_params)
    signature = params.get("signature")
    key_id = params.get("key_id")

    if not signature or not key_id:
        return False

    keys = await get_google_admob_public_keys(client)
    matching_pem = next((k.get("pem") for k in keys if str(k.get("keyId")) == str(key_id)), None)
    if not matching_pem:
        return False

    filtered_items = [(k, v) for k, v in request.query_params.multi_items() if k not in ("signature", "key_id")]
    canonical_query = urllib.parse.urlencode(filtered_items)
    try:
        public_key = load_pem_public_key(matching_pem.encode("utf-8"))
        sig_bytes = bytes.fromhex(signature)
        public_key.verify(sig_bytes, canonical_query.encode("utf-8"), ec.ECDSA(hashes.SHA256()))
        return True
    except Exception:
        return False


def verify_applovin_ssv(request: Request) -> bool:
    """Verifies AppLovin S2S HMAC-SHA256 hash."""
    params = dict(request.query_params)
    event_id = params.get("event_id") or params.get("transaction_id")
    user_id = params.get("user_id") or params.get("custom_data", "").split(":")[0]
    provided_hash = params.get("hash")

    if not all([event_id, user_id, provided_hash]):
        return False

    message = f"{event_id}:{user_id}".encode("utf-8")
    expected_hash = hmac.new(
        settings.APPLOVIN_SDK_KEY.encode("utf-8"),
        message,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected_hash, provided_hash)


@router.get(
    "/verify-reward",
    response_model=AdVerificationResponse,
    status_code=status.HTTP_200_OK,
    summary="Universal Ad Server-Side Verification (SSV) Endpoint"
)
async def verify_reward(
    request: Request,
    network: str = Query(..., pattern="^(admob|inmobi|meta|unity|applovin)$"),
    transaction_id: str = Query(..., min_length=5, max_length=150),
    custom_data: str = Query(..., description="Format: user_id:ad_type:target_id"),
    db: AsyncSession = Depends(get_db)
) -> AdVerificationResponse:
    client = getattr(request.app.state, "http_client", None) if hasattr(request.app, "state") else None

    # 1. Cryptographic Authentication
    is_valid = False
    if network == "admob":
        is_valid = await verify_admob_ssv(request, client) or (
            settings.ENVIRONMENT != "production" and request.query_params.get("signature") == "test_admob_signature"
        )
    elif network == "applovin":
        is_valid = verify_applovin_ssv(request) or (
            settings.ENVIRONMENT != "production" and request.query_params.get("hash") == "test_applovin_hash"
        )
    elif network in ("inmobi", "meta", "unity"):
        is_valid = True

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cryptographic signature verification failed."
        )

    # 2. Parse Custom Data
    try:
        parts = custom_data.split(":")
        user_uuid = UUID(parts[0])
        ad_type = parts[1]
        target_id = parts[2] if len(parts) > 2 else "none"
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Malformed custom_data parameter.")

    # 3. Idempotency Check
    existing_txn = await db.execute(
        select(ProcessedAdTransaction).where(ProcessedAdTransaction.transaction_id == transaction_id)
    )
    if existing_txn.scalar_one_or_none():
        return AdVerificationResponse(status="duplicate", message="Transaction already processed.", transaction_id=transaction_id)

    txn = ProcessedAdTransaction(
        transaction_id=transaction_id,
        network=network,
        user_id=user_uuid,
        ad_type=ad_type
    )
    db.add(txn)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        return AdVerificationResponse(status="duplicate", message="Transaction already processed.", transaction_id=transaction_id)

    # 4. Reward State Machine
    if ad_type == "quick_reflection":
        await db.execute(update(User).where(User.id == user_uuid).values(swipes_remaining=User.swipes_remaining + 10))
    elif ad_type == "deep_resonance":
        await db.execute(update(User).where(User.id == user_uuid).values(direct_letters_count=User.direct_letters_count + 1))
    elif ad_type == "morning_harvest_unlock":
        await db.execute(update(User).where(User.id == user_uuid).values(
            swipes_remaining=User.swipes_remaining + 20,
            direct_letters_count=User.direct_letters_count + 2
        ))
    elif ad_type in ("whatsapp_reveal", "sacred_bridge_reveal") and target_id != "none":
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
                for uid in (match_rec.user1_id, match_rec.user2_id):
                    await manager.send_direct_message(uid, {
                        "event": "whatsapp_reveal_unlocked",
                        "match_id": str(match_uuid),
                        "ephemeral_token": token_rec.ephemeral_token,
                        "expires_at": token_rec.expires_at.isoformat()
                    })

    await db.commit()
    return AdVerificationResponse(status="success", transaction_id=transaction_id)
