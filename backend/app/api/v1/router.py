from fastapi import APIRouter
from app.api.v1.endpoints import moderation, health, kyc, ad_verification, auth, chat, user, safety, feed, admin_kyc, swipes, legal

api_router = APIRouter()

# Register endpoints under /api/v1
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(moderation.router, prefix="/moderation", tags=["Moderation"])
api_router.include_router(kyc.router, prefix="/kyc", tags=["KYC"])
api_router.include_router(ad_verification.router, prefix="/ads", tags=["Ad Verification"])
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(chat.router, prefix="/chat", tags=["Chat"])
api_router.include_router(user.router, prefix="/users", tags=["Users"])
api_router.include_router(user.router, prefix="/user", tags=["User"])
api_router.include_router(safety.router, prefix="/safety", tags=["Safety"])
api_router.include_router(feed.router, prefix="/feed", tags=["Discovery Feed"])
api_router.include_router(admin_kyc.router, prefix="/admin/kyc", tags=["Super Admin KYC"])
api_router.include_router(swipes.router, prefix="/swipes", tags=["Swipes & Second Chance"])
api_router.include_router(legal.router, prefix="/legal", tags=["Legal & Grievance Redressal"])



