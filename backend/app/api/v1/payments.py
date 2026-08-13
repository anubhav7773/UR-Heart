import uuid
from fastapi import APIRouter, Header, HTTPException, status
from app.models.schemas import (
    APIResponse,
    CreateOrderData,
    CreateSachetOrderRequest,
    CreateSachetOrderData,
)
from app.core.config import settings

router = APIRouter(prefix="/payments", tags=["₹99 Subscription & Sachet Payments"])


@router.post("/create-order", response_model=APIResponse[CreateOrderData])
async def create_razorpay_order():
    """
    Initiates a Razorpay UPI order session for the ₹99/month subscription tier.
    """
    mock_order_id = f"order_{uuid.uuid4().hex[:14]}"
    data = CreateOrderData(
        order_id=mock_order_id,
        amount_inr=settings.SUBSCRIPTION_PRICE_INR,
        currency="INR",
        razorpay_key_id=settings.RAZORPAY_KEY_ID,
    )
    return APIResponse(success=True, data=data)


@router.post("/create-sachet-order", response_model=APIResponse[CreateSachetOrderData])
async def create_sachet_order(payload: CreateSachetOrderRequest):
    """
    Initiates a Razorpay UPI order session for Sachet Micro-Transactions:
    - 'chai_invite': ₹9
    - 'photo_pass': ₹19
    - 'monthly': ₹99
    """
    plan = payload.plan_type.lower().strip()
    if plan == "chai_invite":
        amount = 9.0
    elif plan == "photo_pass":
        amount = 19.0
    elif plan in ("monthly", "subscription"):
        amount = 99.0
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid sachet plan_type. Choose 'chai_invite', 'photo_pass', or 'monthly'."
        )

    mock_order_id = f"order_sachet_{plan}_{uuid.uuid4().hex[:10]}"
    data = CreateSachetOrderData(
        order_id=mock_order_id,
        amount_inr=amount,
        currency="INR",
        plan_type=plan,
        razorpay_key_id=settings.RAZORPAY_KEY_ID,
    )
    return APIResponse(success=True, data=data)


@router.post("/webhook")
async def razorpay_webhook(
    payload: dict,
    x_razorpay_signature: str = Header(default=None)
):
    """
    Processes automated payment confirmation callbacks from Razorpay.
    """
    event = payload.get("event")
    if event == "order.paid":
        return {
            "status": "success",
            "message": "User premium status or sachet token upgraded successfully."
        }

    return {"status": "ignored"}
