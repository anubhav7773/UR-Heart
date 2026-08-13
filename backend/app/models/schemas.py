from datetime import date, datetime, timezone
from enum import Enum
from typing import Generic, List, Optional, TypeVar, Any
from pydantic import BaseModel, Field, ConfigDict, field_validator

T = TypeVar("T")


# 1. Standard API Envelope Models (API_SPEC.md Standard)
class ErrorDetails(BaseModel):
    code: str = Field(..., description="Machine-readable error code")
    message: str = Field(..., description="Human-readable error explanation")
    details: Optional[Any] = Field(None, description="Optional extra diagnostic payload")


class APIResponse(BaseModel, Generic[T]):
    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None
    error: Optional[ErrorDetails] = None
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    model_config = ConfigDict(arbitrary_types_allowed=True)


# 2. Domain Enums
class GenderEnum(str, Enum):
    MALE = "male"
    FEMALE = "female"
    NON_BINARY = "non_binary"
    OTHER = "other"


class IntentEnum(str, Enum):
    CASUAL = "casual"
    SERIOUS = "serious"
    FRIENDSHIP = "friendship"
    NETWORKING = "networking"


class SwipeActionEnum(str, Enum):
    REJECT = "reject"
    LIKE = "like"
    DM = "dm"


class AdEventTypeEnum(str, Enum):
    IMPRESSION = "impression"
    CLICK = "click"
    SKIP = "skip"
    REWARD_EARNED = "reward_earned"


# 3. Auth & Social Login Schemas
class SocialLoginRequest(BaseModel):
    provider: str = Field(..., description="OAuth provider: 'google' or 'meta'")
    id_token: str = Field(..., description="Social OAuth ID Token or Access Token")
    device_id: str = Field(..., description="Unique mobile device identifier")
    fcm_token: Optional[str] = Field(None, description="Firebase Cloud Messaging push token")


class SocialLoginData(BaseModel):
    user_id: str
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 1296000
    is_profile_complete: bool
    is_premium: bool


class FirebaseLoginRequest(BaseModel):
    id_token: str = Field(..., description="Firebase Auth User ID Token")
    device_id: str = Field(..., description="Unique mobile device identifier")
    fcm_token: Optional[str] = Field(None, description="Firebase Cloud Messaging push token")


class FirebaseLoginData(BaseModel):
    user_id: str
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 1296000
    is_profile_complete: bool
    is_premium: bool


# Phone OTP Schemas
class SendOTPRequest(BaseModel):
    phone_number: str = Field(..., min_length=10, max_length=15, description="Mobile number with +91 country code")


class SendOTPData(BaseModel):
    session_id: str
    resend_in_seconds: int = 30
    message: str = "OTP sent successfully via Firebase SMS."


class VerifyOTPRequest(BaseModel):
    phone_number: str = Field(..., min_length=10, max_length=15)
    otp_code: str = Field(..., min_length=4, max_length=6, description="4 or 6 digit verification code")
    device_id: str = Field(..., description="Unique mobile device identifier")
    fcm_token: Optional[str] = Field(None, description="Firebase Cloud Messaging push token")


class VerifyOTPData(BaseModel):
    user_id: str
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 1296000
    is_profile_complete: bool
    is_premium: bool


# Email Password Firebase Schemas
class EmailSignupRequest(BaseModel):
    id_token: str = Field(..., description="Firebase Auth User ID Token")
    full_name: str = Field(..., min_length=2, max_length=100, description="Full Name")
    device_id: str = Field(..., description="Unique mobile device identifier")
    fcm_token: Optional[str] = Field(None, description="Firebase Cloud Messaging push token")


class EmailSignupData(BaseModel):
    user_id: str
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 1296000
    is_profile_complete: bool = False
    is_premium: bool = False


class EmailLoginTokenRequest(BaseModel):
    id_token: Optional[str] = Field(None, description="Firebase Auth User ID Token")
    email: Optional[str] = Field(None, description="User registered email address")
    password: Optional[str] = Field(None, description="User password")
    device_id: str = Field(..., description="Unique mobile device identifier")
    fcm_token: Optional[str] = Field(None, description="Firebase Cloud Messaging push token")


class EmailLoginTokenData(BaseModel):
    user_id: str
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 1296000
    is_profile_complete: bool
    is_premium: bool


class EmailPasswordLoginRequest(BaseModel):
    email: str = Field(..., description="User registered email address")
    password: str = Field(..., min_length=6, description="User password")
    device_id: str = Field(..., description="Unique mobile device identifier")


# 4. Profile Completion Schemas
class PhotoInput(BaseModel):
    photo_url: str = Field(..., description="Compressed WebP photo URL")
    is_first_impression: bool = Field(False, description="Primary verified facial photo #1")
    display_order: Optional[int] = Field(1, ge=1, le=50, description="Display order position 1 to 50")

    @field_validator("display_order", mode="before")
    @classmethod
    def validate_display_order(cls, v):
        if v is None or v == "":
            return 1
        try:
            val = int(v)
            return max(1, min(val, 50))
        except Exception:
            return 1


class CompleteProfileRequest(BaseModel):
    full_name: Optional[str] = None
    dob: Optional[date] = None
    gender: Optional[GenderEnum] = None
    interested_in: Optional[GenderEnum] = None
    intent: Optional[IntentEnum] = None
    bio: Optional[str] = None
    area_name: Optional[str] = None
    village_pin_code: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    photos: Optional[List[PhotoInput]] = None

    @field_validator("full_name", mode="before")
    @classmethod
    def validate_full_name(cls, v):
        if v is None or v == "":
            return "User"
        return str(v)

    @field_validator("dob", mode="before")
    @classmethod
    def validate_dob(cls, v):
        if not v or v == "":
            return date(2000, 1, 1)
        if isinstance(v, str):
            try:
                return date.fromisoformat(v.split("T")[0])
            except Exception:
                return date(2000, 1, 1)
        return v

    @field_validator("gender", mode="before")
    @classmethod
    def validate_gender(cls, v):
        if not v or v == "":
            return GenderEnum.MALE
        try:
            return GenderEnum(str(v).lower())
        except Exception:
            return GenderEnum.MALE

    @field_validator("interested_in", mode="before")
    @classmethod
    def validate_interested_in(cls, v):
        if not v or v == "":
            return GenderEnum.FEMALE
        try:
            return GenderEnum(str(v).lower())
        except Exception:
            return GenderEnum.FEMALE

    @field_validator("intent", mode="before")
    @classmethod
    def validate_intent(cls, v):
        if not v or v == "":
            return IntentEnum.CASUAL
        try:
            return IntentEnum(str(v).lower())
        except Exception:
            return IntentEnum.CASUAL

    @field_validator("bio", "area_name", "village_pin_code", mode="before")
    @classmethod
    def validate_strings(cls, v):
        if v is None:
            return ""
        return str(v)

    @field_validator("latitude", mode="before")
    @classmethod
    def validate_lat(cls, v):
        if v is None or v == "":
            return 26.7880
        try:
            val = float(v)
            if -90.0 <= val <= 90.0:
                return val
            return 26.7880
        except Exception:
            return 26.7880

    @field_validator("longitude", mode="before")
    @classmethod
    def validate_lng(cls, v):
        if v is None or v == "":
            return 82.1300
        try:
            val = float(v)
            if -180.0 <= val <= 180.0:
                return val
            return 82.1300
        except Exception:
            return 82.1300

    @field_validator("photos", mode="before")
    @classmethod
    def validate_photos(cls, v):
        if v is None or not isinstance(v, list):
            return []
        return v


class CompleteProfileData(BaseModel):
    user_id: str
    is_profile_complete: bool


# 5. User Response & Profile Schemas
class PhotoRead(BaseModel):
    id: str
    photo_url: str
    is_first_impression: bool
    display_order: int

    model_config = ConfigDict(from_attributes=True)


class UserRead(BaseModel):
    id: str
    full_name: str
    dob: date
    gender: GenderEnum
    interested_in: GenderEnum
    intent: IntentEnum
    bio: Optional[str] = None
    area_name: Optional[str] = None
    village_pin_code: Optional[str] = None
    is_premium: bool = False
    is_verified: bool = False
    is_active: bool = True
    photos: List[PhotoRead] = []

    model_config = ConfigDict(from_attributes=True)


# 6. Feed & Swiping Schemas
class ProfileCardData(BaseModel):
    user_id: str
    first_name: str
    full_name: Optional[str] = None
    age: int
    distance_label: str
    bio: str
    area_name: str
    intent: IntentEnum
    photos: List[str]
    is_verified_local: bool = True


class AdConfigSlot(BaseModel):
    ad_unit_id: str
    format: str = "native_card"
    max_duration_sec: int = 5


class FeedCardItem(BaseModel):
    type: str
    profile: Optional[ProfileCardData] = None
    ad_config: Optional[AdConfigSlot] = None


class FeedData(BaseModel):
    cards: List[FeedCardItem]


class SwipeRequest(BaseModel):
    target_user_id: str
    action: SwipeActionEnum


class SwipeData(BaseModel):
    is_match: bool
    persistent_skip_count: int
    trigger_interstitial_ad: bool
    ad_unit_id: Optional[str] = None


# 7. Dynamic Ad & Monetization Schemas
class AdConfigData(BaseModel):
    in_feed_ad_interval: int
    skip_interstitial_threshold: int
    app_open_ad_cap_minutes: int
    in_chat_ad_interval_seconds: int
    in_chat_ad_duration_seconds: int
    free_daily_dm_limit: int


class LogAdEventRequest(BaseModel):
    ad_unit_type: str
    event_type: AdEventTypeEnum
    network_provider: str = "AdMob"
    ecpm_estimate: float = 0.0


# 8. Chat & Payment Schemas
class UploadMediaData(BaseModel):
    media_url: str
    is_view_once: bool
    expires_at: Optional[datetime] = None


class CreateOrderData(BaseModel):
    order_id: str
    amount_inr: float
    currency: str = "INR"
    razorpay_key_id: str


# 9. Chai Status & Chai Invite Schemas
class ChaiStatusRequest(BaseModel):
    is_free_for_chai: bool = True
    status_badge: str = Field("☕ Free for Chai", max_length=100)
    location_landmark: Optional[str] = Field(None, max_length=100)


class ChaiStatusData(BaseModel):
    is_free_for_chai: bool
    status_badge: str
    location_landmark: Optional[str] = None


class SendChaiInviteRequest(BaseModel):
    receiver_id: str = Field(..., description="Target user ID to invite for tea")


class SendChaiInviteData(BaseModel):
    invite_id: str
    status: str = "pending"
    message: str = "₹9 Chai Invite sent successfully!"


# 10. Safe WhatsApp Bridge Schemas
class WhatsAppBridgeStatusData(BaseModel):
    match_id: str
    mutual_message_count: int
    required_threshold: int = 15
    is_whatsapp_unlocked: bool
    phone_number: Optional[str] = Field(None, description="Unlocked WhatsApp phone number when count >= 15")


# 11. Sachet Micro-Transaction Schemas
class CreateSachetOrderRequest(BaseModel):
    plan_type: str = Field(..., description="'chai_invite' (₹9), 'photo_pass' (₹19), or 'monthly' (₹99)")


class CreateSachetOrderData(BaseModel):
    order_id: str
    amount_inr: float
    currency: str = "INR"
    plan_type: str
    razorpay_key_id: str


# 12. Storage Photo Upload Schema
class UploadPhotoData(BaseModel):
    photo_url: str = Field(..., description="Public Supabase CDN WebP image URL")


# 13. Chat & Matches Schemas
class MatchRead(BaseModel):
    id: str
    target_user_id: str
    target_user_name: str
    target_user_photo: str
    mutual_message_count: int = 0
    is_whatsapp_unlocked: bool = False
    last_message: Optional[str] = None
    updated_at: str

    model_config = ConfigDict(from_attributes=True)


class ChatMessageRead(BaseModel):
    id: str
    match_id: str
    sender_id: str
    content: Optional[str] = None
    media_url: Optional[str] = None
    media_type: str = "text"
    created_at: str

    model_config = ConfigDict(from_attributes=True)


class SendMessageRequest(BaseModel):
    match_id: str
    client_msg_id: Optional[str] = None
    content: Optional[str] = None
    media_url: Optional[str] = None
    media_type: str = "text"


# 14. Safety & Moderation Schemas
class BlockUserRequest(BaseModel):
    blocked_user_id: str = Field(..., description="Target user ID to block")


class BlockUserData(BaseModel):
    blocked_user_id: str
    message: str = "User blocked successfully."


class ReportUserRequest(BaseModel):
    reported_user_id: str = Field(..., description="Target user ID to report")
    reason: str = Field(..., description="Reason for report")
    details: Optional[str] = Field(None, max_length=1000)


class ReportUserData(BaseModel):
    report_id: str
    message: str = "Report submitted successfully."


# 15. Payment Verification Schemas
class VerifyPaymentRequest(BaseModel):
    razorpay_payment_id: str
    razorpay_order_id: str
    razorpay_signature: str
    plan_type: Optional[str] = "monthly"


class VerifyPaymentData(BaseModel):
    verified: bool = True
    plan_type: str
    message: str = "Payment verified successfully."
