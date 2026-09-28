from fastapi import APIRouter
from app.api.v1.endpoints import (
    admin_kyc,
    ads_ssv,
    ai_cluster,
    auth,
    billing_webhook,
    chat_api,
    feed,
    health,
    moderation,
    profile,
    resonances,
    telemetry,
)

api_router = APIRouter()

# 0. Live Activity Telemetry (Immediate Render Stream)
api_router.include_router(telemetry.router)

# 1. Health & Sleepless Keep-Alive Router
api_router.include_router(health.router)

# 2. Safety & Moderation Router (Photo OCR, Torso Skin & Chat NLP)
api_router.include_router(moderation.router)

# 3. 360° AI Suite Router (Icebreakers, Bio Polish, Vision KYC)
api_router.include_router(ai_cluster.router)

# 4. Superadmin KYC Sentinel Desk
api_router.include_router(admin_kyc.router)

# 5. Ad SSV Verifier Router
api_router.include_router(ads_ssv.router)

# 6. Billing, IAP & Store Webhooks
api_router.include_router(billing_webhook.router)

# 7. Authentication Router (Including Google Sync)
api_router.include_router(auth.router)

# 8. User Profile Creation & Management
api_router.include_router(profile.router)

# 9. Discovery Feed & Swipes Actions
api_router.include_router(feed.router)

# 10. Resonances & Mutual Matches
api_router.include_router(resonances.router)

# 11. 1:1 Encrypted Dialogues & Message History
api_router.include_router(chat_api.router)
