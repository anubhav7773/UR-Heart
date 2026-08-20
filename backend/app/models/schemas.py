from datetime import date, datetime, timezone
from enum import Enum
from typing import Generic, List, Optional, TypeVar, Any, Dict
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


class VerificationStatusEnum(str, Enum):
    UNVERIFIED = "UNVERIFIED"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"


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
    is_admin: bool = False


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
    is_admin: bool = False


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
    is_admin: bool = False


# Email Password Firebase & Direct Schemas
class EmailSignupRequest(BaseModel):
    id_token: Optional[str] = Field(None, description="Firebase Auth User ID Token")
    email: Optional[str] = Field(None, description="User registered email address")
    password: Optional[str] = Field(None, description="User password")
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
    is_admin: bool = False


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
    is_admin: bool = False


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


def calculate_dynamic_age(born: Optional[date]) -> Optional[int]:
    if not born:
        return None
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


class CompleteProfileRequest(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    dob: Optional[date] = None
    date_of_birth: Optional[date] = None
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

    @field_validator("dob", "date_of_birth", mode="before")
    @classmethod
    def validate_dob(cls, v):
        if not v or v == "":
            return None
        if isinstance(v, str):
            try:
                return date.fromisoformat(v.split("T")[0])
            except Exception:
                return None
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
            return None
        try:
            val = float(v)
            if -90.0 <= val <= 90.0:
                return val
            return None
        except Exception:
            return None

    @field_validator("longitude", mode="before")
    @classmethod
    def validate_lng(cls, v):
        if v is None or v == "":
            return None
        try:
            val = float(v)
            if -180.0 <= val <= 180.0:
                return val
            return None
        except Exception:
            return None

    @field_validator("photos", mode="before")
    @classmethod
    def validate_photos(cls, v):
        if v is None or not isinstance(v, list):
            return []
        return v


class CompleteProfileData(BaseModel):
    user_id: str
    is_profile_complete: bool
    bio: Optional[str] = None
    full_name: Optional[str] = None


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
    phone_number: Optional[str] = None
    dob: Optional[date] = None
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    gender: GenderEnum
    interested_in: GenderEnum
    intent: IntentEnum
    bio: Optional[str] = None
    area_name: Optional[str] = None
    village_pin_code: Optional[str] = None
    is_premium: bool = False
    is_boosted: bool = False
    boosted_until: Optional[datetime] = None
    direct_dm_until: Optional[datetime] = None
    ad_free_until: Optional[datetime] = None
    photo_pass_until: Optional[datetime] = None
    bonus_swipes: int = 0
    is_verified: bool = False
    is_admin: bool = False
    verification_status: VerificationStatusEnum = VerificationStatusEnum.UNVERIFIED
    verification_video_url: Optional[str] = None
    voice_bio_url: Optional[str] = None
    voice_bio_duration_seconds: Optional[int] = 0
    is_active: bool = True
    is_online: bool = False
    last_seen: Optional[datetime] = None
    last_active_at: Optional[datetime] = None
    photos: List[PhotoRead] = []

    model_config = ConfigDict(from_attributes=True)


UserResponse = UserRead


# 6. Feed & Swiping Schemas
class ProfileCardData(BaseModel):
    user_id: str
    first_name: str
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    age: Optional[int] = None
    date_of_birth: Optional[date] = None
    distance_km: Optional[float] = None
    distance_label: str
    bio: str
    area_name: str
    intent: IntentEnum
    photos: List[str]
    is_verified: bool = False
    is_admin: bool = False
    verification_status: VerificationStatusEnum = VerificationStatusEnum.UNVERIFIED
    is_verified_local: bool = False
    is_boosted: bool = False
    boosted_until: Optional[datetime] = None
    voice_bio_url: Optional[str] = None
    voice_bio_duration_seconds: Optional[int] = 0
    is_online: bool = False
    last_seen: Optional[datetime] = None
    last_active_at: Optional[datetime] = None


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
    match_id: Optional[str] = None
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


class ClaimAdRewardRequest(BaseModel):
    reward_type: str = Field("swipes", description="'swipes' (+5 swipes) or 'photo_pass' (2-hour pass)")


class ClaimAdRewardData(BaseModel):
    success: bool = True
    reward_type: str
    bonus_swipes_granted: int = 0
    photo_pass_granted_hours: int = 0
    photo_pass_until: Optional[str] = None
    remaining_ad_claims_today: int = 2
    message: str = "Reward claimed successfully."


# 8. Chat & Payment Schemas
class UploadMediaData(BaseModel):
    media_url: str
    is_view_once: bool
    expires_at: Optional[datetime] = None


class CreateOrderData(BaseModel):
    order_id: str
    amount: float = 199.0
    amount_inr: float = 199.0
    amount_in_paise: int = 19900
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
    receiver_id: Optional[str] = Field(None, description="Target user ID to invite for tea")
    match_id: Optional[str] = Field(None, description="Match ID if sending invite from chat")
    message: Optional[str] = Field("Chai date ke liye kab chalein? ☕", description="Invite message")


class SendChaiInviteData(BaseModel):
    invite_id: str
    status: str = "pending"
    message: str = "₹9 Chai Invite sent successfully!"


# 10. Safe WhatsApp Bridge & Two-Way Consent Schemas
class ChatConsentRequest(BaseModel):
    share_whatsapp: bool = False
    share_location: bool = False


class ChatConsentStatusData(BaseModel):
    whatsapp_unlocked: bool = False
    location_unlocked: bool = False
    my_whatsapp_consent: bool = False
    my_location_consent: bool = False
    partner_whatsapp_consent: bool = False
    partner_location_consent: bool = False
    my_payment_done: bool = False
    partner_payment_done: bool = False
    is_fully_unlocked: bool = False
    total_messages: int = 0
    is_milestone_reached: bool = False
    partner_phone: Optional[str] = None
    partner_maps_url: Optional[str] = None


class SafeBridgeStatusData(BaseModel):
    match_id: str
    total_messages: int = 0
    is_milestone_reached: bool = False
    required_messages: int = 15
    my_consent: bool = False
    my_whatsapp_consent: bool = False
    my_location_consent: bool = False
    partner_consent: bool = False
    partner_whatsapp_consent: bool = False
    partner_location_consent: bool = False
    my_payment_done: bool = False
    partner_payment_done: bool = False
    is_fully_unlocked: bool = False
    whatsapp_unlocked: bool = False
    location_unlocked: bool = False
    my_meetup_consent: bool = False
    partner_meetup_consent: bool = False
    is_meetup_unlocked: bool = False
    partner_phone: Optional[str] = None
    partner_maps_url: Optional[str] = None


class SafeBridgePaymentRequest(BaseModel):
    match_id: str
    payment_id: str
    amount: float = 499.0


class MeetupConsentRequest(BaseModel):
    agree: bool


class MeetupConsentStatusData(BaseModel):
    match_id: str
    my_meetup_consent: bool
    partner_meetup_consent: bool
    is_meetup_unlocked: bool
    message: str


class MeetupSpotData(BaseModel):
    id: str
    name: str
    category: str  # chai, cafe, restaurant, hotel
    category_label: str  # Chai & Snacks, Cafes, Restaurants, Hotels
    distance_meters: int
    distance_km: float
    distance_label: str  # e.g., "350m away", "1.2 km away", "2.4 km from mid-way"
    address: str
    latitude: float
    longitude: float
    maps_url: str
    phone: Optional[str] = None
    rating: Optional[float] = None
    place_id: Optional[str] = None
    is_verified: bool = True


class MeetupSpotsResponse(BaseModel):
    total: int
    spots: List[MeetupSpotData]
    center_lat: float
    center_lon: float
    is_midpoint: bool = False
    user_distance_km: Optional[float] = None
    search_radius_meters: int = 15000
    notice: Optional[str] = None


class WhatsAppBridgeStatusData(BaseModel):
    match_id: str
    mutual_message_count: int
    required_threshold: int = 15
    my_consent: bool = False
    partner_consent: bool = False
    is_whatsapp_unlocked: bool = False
    my_payment_done: bool = False
    partner_payment_done: bool = False
    is_fully_unlocked: bool = False
    phone_number: Optional[str] = Field(None, description="Unlocked WhatsApp phone number when both users have consented & paid")


# 11. Sachet Micro-Transaction Schemas
class CreateSachetOrderRequest(BaseModel):
    plan_type: str = Field(
        ...,
        description="'PLAN_BOOST_29' (₹29), 'PLAN_DIRECT_DM_49' (₹49), 'PLAN_AD_FREE_199' (₹199), 'PLAN_SAFE_BRIDGE_499' (₹499)"
    )


class CreateSachetOrderData(BaseModel):
    order_id: str
    amount: float
    amount_inr: float
    amount_in_paise: int
    currency: str = "INR"
    plan_type: str
    plan_name: Optional[str] = None
    razorpay_key_id: str


class DirectDMRequest(BaseModel):
    target_user_id: str = Field(..., description="Target user ID to send direct message without matching")
    message: str = Field(..., min_length=1, max_length=2000, description="Direct message text content")


class DirectDMData(BaseModel):
    match_id: str
    target_user_id: str
    message_id: str
    content: str
    created_at: str
    message: str = "Direct DM sent successfully!"


# 12. Storage Photo Upload Schema
class UploadPhotoData(BaseModel):
    photo_url: str = Field(..., description="Public Supabase CDN WebP image URL")


# 13. Chat & Matches Schemas
class MatchRead(BaseModel):
    id: str
    match_id: Optional[str] = None
    partner_id: Optional[str] = None
    partner_name: Optional[str] = None
    partner_avatar: Optional[str] = None
    target_user_id: Optional[str] = None
    target_user_name: Optional[str] = None
    target_user_photo: Optional[str] = None
    matched_user_name: Optional[str] = None
    matched_user_avatar: Optional[str] = None
    user1_id: Optional[str] = None
    user2_id: Optional[str] = None
    is_active: bool = True
    mutual_message_count: int = 0
    is_whatsapp_unlocked: bool = False
    is_online: bool = False
    is_verified: bool = False
    matched_user_is_verified: bool = False
    matched_user_is_online: bool = False
    matched_user_last_active: Optional[str] = None
    last_seen: Optional[str] = None
    last_active_at: Optional[str] = None
    last_message: Optional[str] = None
    last_message_time: Optional[str] = None
    last_message_at: Optional[str] = None
    last_message_status: Optional[str] = None
    last_message_is_me: bool = False
    unread_count: int = 0
    updated_at: Optional[str] = None
    created_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ChatMessageRead(BaseModel):
    id: str
    match_id: str
    sender_id: str
    client_msg_id: Optional[str] = None
    content: Optional[str] = None
    media_url: Optional[str] = None
    media_type: str = "text"
    message_type: str = "text"
    metadata: Optional[Dict[str, Any]] = None
    extra_metadata: Optional[Dict[str, Any]] = None
    status: str = "sent"  # 'sent', 'delivered', 'read'
    is_sent: bool = True
    is_delivered: bool = False
    is_read: bool = False
    read_at: Optional[str] = None
    is_deleted: bool = False
    deleted_at: Optional[str] = None
    created_at: str

    model_config = ConfigDict(from_attributes=True)


class UnsendMessageData(BaseModel):
    message_id: str
    match_id: str
    is_deleted: bool = True
    message: str = "Message unsent successfully."


class SendMessageRequest(BaseModel):
    match_id: Optional[str] = None
    conversation_id: Optional[str] = None
    client_msg_id: Optional[str] = None
    content: Optional[str] = None
    media_url: Optional[str] = None
    media_type: str = "text"
    message_type: str = "text"
    metadata: Optional[Dict[str, Any]] = None


class MessageCreate(SendMessageRequest):
    pass


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


# 16. Video Verification Schemas
class VideoVerificationResponse(BaseModel):
    verification_status: VerificationStatusEnum
    verification_video_url: Optional[str] = None
    is_verified: bool = False
    message: str


class AdminVerificationReviewRequest(BaseModel):
    action: str = Field(..., description="'APPROVE' or 'REJECT'")


# 17. Voice Bio & Icebreaker Schemas
class VoiceBioUploadData(BaseModel):
    voice_bio_url: str
    duration_seconds: int = 15
    message: str = "Voice Bio uploaded successfully!"


class IcebreakerItem(BaseModel):
    id: str
    emoji: str
    text: str
    category: str = "general"


# 18. Profile Visitors & Ghost Passers Schemas
class VisitorItem(BaseModel):
    user_id: str
    name: str
    age: Optional[int] = None
    city: Optional[str] = None
    photo_url: Optional[str] = None
    photos: List[str] = Field(default_factory=list)
    distance_km: Optional[float] = None
    distance_label: str = "Nearby"
    action_type: str = "pass"
    is_verified: bool = False
    visited_at: str
    time_ago: str = "Recently"


class VisitorsListResponse(BaseModel):
    total_count: int
    unread_count: int = 0
    visitors: List[VisitorItem]


class DirectDMSachetRequest(BaseModel):
    target_user_id: str = Field(..., description="Target user ID to unlock direct DM for")


class DirectDMSachetResponse(BaseModel):
    conversation_id: str
    match_id: str
    target_user_id: str
    success: bool = True
    message: str = "Direct DM Unlocked via ₹49 Sachet"


class IcebreakerListData(BaseModel):
    icebreakers: List[IcebreakerItem]

