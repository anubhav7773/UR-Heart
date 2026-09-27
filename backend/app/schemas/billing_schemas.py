from datetime import datetime
from typing import Any, Dict, Optional
from uuid import UUID
from pydantic import BaseModel, Field


class AdVerificationResponse(BaseModel):
    status: str
    message: Optional[str] = None
    transaction_id: Optional[str] = None


class RevenueCatWebhookPayload(BaseModel):
    api_version: Optional[str] = "1.0"
    event: Dict[str, Any] = Field(..., description="RevenueCat lifecycle event payload")


class WebStorePurchasePayload(BaseModel):
    user_id: UUID
    transaction_reference: str = Field(..., min_length=5, max_length=150)
    product_identifier: str = Field(..., min_length=3, max_length=60)
    store: str = Field(..., pattern="^(google_play|web_razorpay_india|web_stripe_global)$")
    currency: str = Field("USD", min_length=3, max_length=10)
    amount_gross: float = Field(..., gt=0.0)
    platform_fee: float = Field(0.0, ge=0.0)
    amount_net: float = Field(..., ge=0.0)


class BillingAuditResponse(BaseModel):
    status: str
    transaction_reference: str
    product_identifier: str
    store: str
    processed_at: datetime
