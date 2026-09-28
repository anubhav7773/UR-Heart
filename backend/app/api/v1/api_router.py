from fastapi import APIRouter
from app.api.v1.endpoints import (
    account_incinerator,
    admin_kyc,
    ads_ssv,
    ai_cluster,
    auth,
    billing_webhook,
    billing_verification,
    chat_api,
    crypto_registry,
    feed,
    health,
    legal_compliance,
    moderation,
    preferences,
    profile,
    resonances,
    telemetry,
    underage_quarantine,
    ws_ticket,
    kyc_verification,
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
api_router.include_router(billing_verification.router)

# 7. Authentication Router (Including Google Sync)
api_router.include_router(auth.router)
api_router.include_router(auth.users_router)

# 8. User Profile Creation & Management
api_router.include_router(profile.router)

# 8b. User Preferences & Privacy Settings (DIS-04 FIX)
api_router.include_router(preferences.router)

# 8c. Cryptographic Key Registry (DIS-05 FIX)
api_router.include_router(crypto_registry.router)

# 9. Discovery Feed & Swipes Actions
api_router.include_router(feed.router)

# 10. Resonances & Mutual Matches
api_router.include_router(resonances.router)

# 11. 1:1 Encrypted Dialogues & Message History
api_router.include_router(chat_api.router)

# 12. Statutory Legal & DPDP Compliance (SEC-09)
api_router.include_router(legal_compliance.router)

# 13. Irrevocable Account Incinerator (SEC-06)
api_router.include_router(account_incinerator.router)

# 14. Hardware-Level Underage Quarantine Engine (SEC-08)
api_router.include_router(underage_quarantine.router)

# 15. Ephemeral WSS Handshake Ticket (SEC-13)
api_router.include_router(ws_ticket.router)

# 16. Secure Fail-Closed KYC Verification (SEC-11)
api_router.include_router(kyc_verification.router)


