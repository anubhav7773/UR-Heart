# 15_SCREEN_SPECIFICATIONS_1_TO_13.md: PRODUCTION SCREEN-BY-SCREEN TECHNICAL SPECIFICATION
# Project: UR-Heart (Mindful Dating Sanctuary)
# Visual Scope: 100% Pixel Match with Stitch Imported UI (Dark & Light Sanctuary Modes)
# Architecture: Single-Responsibility Micro-Widgets (Strict < 250 Lines per File Rule)
# Integrations: 360° AI Suite (Groq/OpenRouter), Multi-Platform Sacred Bridge & Dual-Engine Store

---

## 1. GLOBAL NAVIGATION & SCREEN MANIFEST

| Screen # | Module Route | Screen Scaffold Path (`lib/features/...`) | Core Purpose & Architecture |
| :--- | :--- | :--- | :--- |
| **01** | `/consent` | `auth/presentation/screens/consent_screen.dart` | DPDP 2023 Unbundled Consent & Permanent Theme Lock Anchor |
| **02** | `/auth` | `auth/presentation/screens/age_gate_auth_screen.dart` | Neutral 18+ DOB Wheel, Quarantine Interceptor & Auth Entry |
| **03** | `/verify-email` | `auth/presentation/screens/magic_link_screen.dart` | Firebase Auth Deep-Link Listener & 45s Resend Cooldown |
| **04** | `/profile-setup` | `profile_setup/presentation/screens/profile_setup_screen.dart` | 5 Moments, Video KYC, Bio Polish & Multi-Platform Bridge Dropdown |
| **05** | `/feed` | `feed/presentation/screens/feed_screen.dart` | 60fps Card Deck, AI Resonance Insight, Bi-Directional Shield & Swipes |
| **06** | `/ignored` | `feed/presentation/screens/ignored_profiles_screen.dart` | Encrypted Pass Vault & Single-Tap Revisit Deck Restoration |
| **07** | `/resonances` | `resonances/presentation/screens/resonances_screen.dart` | Dual Tabs ("Liked You" vs "Mutual Connections") & Instant Chat CTA |
| **08** | `/chats` | `chat/presentation/screens/chats_list_screen.dart` | Search Bar, Active Dialogue Counter & Recent Sparks Carousel |
| **09** | `/chat-dialogue` | `chat/presentation/screens/chat_dialogue_screen.dart` | FLAG_SECURE, 3 AI Icebreaker Chips, 3-Stage Ticks & Bridge Launch |
| **10** | `/growth` | `rewards/presentation/screens/growth_hub_screen.dart` | Dual-Engine Store (0ms Rewarded Ads vs Sovereign IAP / Web Store) |
| **11** | `/persona` | `profile/presentation/screens/my_persona_screen.dart` | Verified Persona Editor, Locked Credentials & Bridge Manager |
| **12** | `/vault` | `legal_vault/presentation/screens/vault_legal_screen.dart` | DPDP Sec 11 Export, Sec 14 Nominee, IT Rules Grievance & Blocklist |
| **13** | `/settings` | `settings/presentation/screens/sanctuary_settings_screen.dart` | Discreet Mode, Ghost Cloak, Sec 12 Shredder & Superadmin Sentinel |

---

## 2. DETAILED PRODUCTION SCREEN SPECIFICATIONS (1 TO 13)

---

### SCREEN 01: MINDFUL CONSENT SCREEN
* **Visual Reference**: `screenshot.png` (Dark Sanctuary) & `screenshot21.png` / `screenshot21_2.png` (Light Sanctuary).
* **Route**: `/consent` | **Controller**: `consent_controller.dart`.
* **Component Architecture**:
  ```text
  ConsentScreen (Scaffold)
  ├── SanctuaryHeaderBar
  │   ├── HeaderTagline ("More than swipes")
  │   ├── ThemeSelectorPill (Center: "Light Mode ▾" -> Dialog on Tap)
  │   └── HeaderTagline ("Safer · Kinder · Real")
  ├── SingleChildScrollView
  │   └── MindfulConsentCard
  │       ├── SanctuaryCrestIcon
  │       ├── H1SerifTitle ("Mindful consent.")
  │       ├── H1ItalicAccent ("Real trust.")
  │       ├── SubtitleParagraph
  │       ├── ConsentAccordionGroup
  │       │   ├── AccordionCard (DPDP Act 2023 Statutory Privacy & Sovereign Rights)
  │       │   ├── AccordionCard (IT Rules 2021 Rule 3(2) Grievance & 24h SLA)
  │       │   └── AccordionCard (Zero-Harassment Community Enclave EULA)
  │       └── UnbundledCheckboxGroup
  │           ├── CheckboxRow ("I confirm I am strictly 18 years of age or older")
  │           └── CheckboxRow ("I grant explicit affirmative consent under DPDP Act 2023")
  └── BottomFixedBar
      └── MindfulPrimaryButton ("I Agree & Continue ➔", disabled until both checked)
Permanent Theme Lock Behavior:

On fresh install, themeProvider defaults to SanctuaryTheme.light.

Tapping ThemeSelectorPill opens PermanentThemeLockDialog:
"UR-Heart enforces an unhurried, permanent visual mode. Once chosen, this mode cannot be changed ever on this device."

User can switch to Dark Mode and tap "Confirm & Lock", freezing is_theme_locked = true in local storage.

Tapping "I Agree & Continue ➔" irrevocably locks whichever theme is currently active.

Navigation Action: Calls consentController.recordConsent() and transitions to /auth via context.go('/auth').

SCREEN 02: SANCTUARY AGE GATE & AUTHENTICATION
Visual Reference: screenshot2.png (Dark Sanctuary) & screenshot22.png (Light Sanctuary).

Route: /auth | Controller: auth_controller.dart.

Component Architecture:

Plaintext


AgeGateAuthScreen (Scaffold, resizeToAvoidBottomInset: true)
├── EditorialAuthHeader
│   ├── H2SerifTitle ("Real people. Real resonance.")
│   └── SubtitleText ("Connection starts with showing up as yourself.")
├── AuthSegmentedControl ("Create Sanctuary" | "Sign In")
├── NeutralDobWheelPicker
│   ├── Strictly18Badge ("STRICTLY 18+" in Terracotta Pill)
│   ├── CupertinoWheelRow (Day: 1-31, Month: Jan-Dec, Year: Neutral unselected)
│   └── LiveAgeCalculationBadge (e.g. "14 Oct 2002 · 22 yrs old · Verified Adult" in Teal)
├── CredentialsInputFieldGroup
│   ├── SanctuaryTextField (Email Address, validation regex)
│   └── SanctuaryPasswordField (Password with eye toggle visibility)
├── PrimaryActionButton ("Enter Sanctuary ➔")
├── SubtleDividerWithText ("or quietly with")
└── SocialAuthButton ("Continue with Google" Pill)
Underage Quarantine Protection:

Year picker is initialized to a neutral blank state (no pre-selected adult year).

If calculated age < 18, LiveAgeCalculationBadge turns crimson ("Underage Restricted"), primary button is disabled, and device hash is logged to underage_quarantine_registry (180-day hardware lock).

Backend Endpoint:

POST /api/v1/auth/register-intent: Validates DOB, hashes password, triggers Firebase email verification, returns installation sync status.

SCREEN 03: MAGIC LINK VERIFICATION PASSAGE
Visual Reference: screenshot3.png (Dark Sanctuary) & screenshot23.png (Light Sanctuary).

Route: /verify-email | Controller: magic_link_controller.dart.

Component Architecture:

Plaintext


MagicLinkScreen (Scaffold)
├── GlowingLetterIconWithSparkle
├── H2Headline ("Almost home. Verify your sanctuary.")
├── VerifiedEmailDisplayCard
│   ├── EmailTextDisplay ("user@example.com")
│   └── EditEmailTextButton ("Edit")
├── MindfulPassageGuideBox
│   ├── StepTile (1, "Open your email inbox")
│   ├── StepTile (2, "Tap the secure verification passage link")
│   └── StepTile (3, "Return quietly to your sanctuary")
├── NativeEmailLauncherButton ("Open Email App ➔")
└── ResendCooldownTimer ("Resend link in 45s", auto-ticks down to 0s)
Deep Link Listener & Intent Launcher:

NativeEmailLauncherButton invokes android_intent_plus to launch default email app (ACTION_MAIN with CATEGORY_APP_EMAIL).

app_links listener catches incoming Firebase Auth verification token (urheart.app/verify?...).

On verified callback, controller updates local auth state and automatically pushes to /profile-setup.

SCREEN 04: SANCTUARY PROFILE BUILDER & LIVE KYC
Visual Reference: screenshot4.png (Dark Sanctuary) & screenshot24.png (Light Sanctuary).

Route: /profile-setup | Controller: profile_setup_controller.dart.

Component Architecture:

Plaintext


ProfileSetupScreen (Scaffold, SingleChildScrollView)
├── FiveSlotMediaGrid
│   ├── Slot1_PrimaryAnchor (Large portrait, required for Video KYC match)
│   └── Slots2to5_CandidMoments (4 grid thumbnails with add/edit icons)
├── ProfileFormFields
│   ├── FullNameField (Max 60 chars)
│   ├── LockedDobBadge (Immutable, carried from Screen 2 with padlock icon)
│   ├── GenderDropdownSelector ('Woman', 'Man', 'Non-Binary', 'Other')
│   ├── OrientationPillSelector ('Men', 'Women', 'Everyone')
│   │
│   ├── SACRED_CONTACT_BRIDGE_PICKER
│   │   ├── BridgeDropdownSelector (WhatsApp | Instagram | Snapchat | Telegram | Signal)
│   │   └── BridgeInputContainer (Dynamic placeholder based on selection)
│   │       ├── If WhatsApp: "+91 Mobile Number" (Masked input)
│   │       ├── If Instagram: "@username Handle"
│   │       ├── If Snapchat: "Snapchat ID"
│   │       └── If Telegram: "@t_user Username"
│   │
│   ├── LocationPickerWithGpsButton ("Saket, Ayodhya", "Update GPS" CTA)
│   ├── MindfulBioEditor
│   │   ├── BioTextField (500 chars limit)
│   │   └── GroqBioPolishButton ("Mindful Polish ✨" -> Triggers Groq Llama-3.3-70b)
│   ├── ProfessionAndEducationFields
│   └── AgePreferenceRangeSlider (Dual slider: 18 to 35 default)
├── LiveVideoKycBannerCard
│   ├── CrestIcon
│   ├── Title ("Claim the Verified Sanctuary Crest")
│   ├── Subtitle ("Complete a gentle 3-second live reflection to verify your presence.")
│   └── StartKycButton ("Start Video KYC (Instant ✨)")
└── CompleteSetupButton ("Complete Sanctuary Setup ➔")
Direct Client Media Pipeline:

Photos are compressed client-side to WebP (<35KB, 800x1066), EXIF stripped, and uploaded directly to Firebase Storage (users/{uuid}/moments/slot_{x}.webp) via firebase_storage.

Live Video KYC Flow:

Tapping KYC opens modal camera recording 3 seconds of front-facing video.

Direct upload to kyc_ephemeral/{uuid}/kyc_video.mp4.

FastAPI /api/v1/kyc/verify-live extracts 3 frames in RAM, calls Groq Vision, evaluates liveness and face match against Slot 1, and immediately purges the video file from storage.

SCREEN 05: SANCTUARY DISCOVERY FEED
Visual Reference: screenshot5.png (Dark Sanctuary) & screenshot25.png (Light Sanctuary).

Route: /feed | Controller: feed_controller.dart.

Component Architecture:

Plaintext


SanctuaryFeedScreen (Scaffold)
├── SanctuaryTopAppBar
│   ├── SanctuaryCrestIcon (Left)
│   ├── StatusBadgeWithSparkle (Center: "Sanctuary Active")
│   └── DiscoveryFilterIconButton (Right: routes to discovery radius & age preferences)
├── MainCardDeckContainer (Interactive gesture stack)
│   └── CandidateProfileCard (Smooth 60fps drag physics, -15 to +15 deg tilt)
│       ├── HorizontalPhotoCarousel (WebP images with BlurHash 200ms cross-fade)
│       │   ├── PaginationIndicatorDots
│       │   ├── VerifiedArchitectBadge (Teal crest if kyc_status = true)
│       │   └── DistanceAndLocationChip ("Saket, Ayodhya · 1.5 km away")
│       ├── PersonaDetailsContainer
│       │   ├── NameAndAgeRow ("Ananya, 22", Verified crest)
│       │   ├── GenderAndSeekingPill ("Woman seeking Men")
│       │   ├── ResonanceScorePill ("94% RESONANCE" in Gold)
│       │   │
│       │   ├── AI_RESONANCE_INSIGHT_BOX
│       │   │   └── OneLineInsight ("Both of you share a reverence for midnight solitude and Murakami.")
│       │   │
│       │   ├── MindfulIntentQuoteCard (Editorial Serif quote: "Finding peace in slow mornings...")
│       │   └── InterestTagsWrap (Chips: "Literature", "Pour-Over Coffee", "Architecture")
│       └── CardDeckOverlayGradients (Red tint on drag left, Green tint on drag right)
├── FloatingActionBar
│   ├── CircularPassButton ("✕" - Dark/Light border)
│   ├── CenterDirectLetterPill ("✉ Direct Resonate ✨" - Terracotta coral/pine glow)
│   └── CircularLikeButton ("♡" - Terracotta/green accent)
└── OutOfSwipesAdModal (Triggered when swipes_remaining <= 0)
    ├── Headline ("Daily Mindful Quota Exhausted")
    ├── WatchAdButton ("Watch 10s Reflection (+10 Swipes)")
    └── GetSovereignPassButton ("Get Sovereign Pass (Unlimited Swipes ➔)")
Bi-Directional Orientation Shield:

Discovery query strictly enforces reciprocal match: (user.gender = target.interested_in) AND (target.gender = user.interested_in).

Incognito users (is_incognito = true) are 100% hidden from the public deck.

SCREEN 06: IGNORED PROFILES (PASS VAULT)
Visual Reference: screenshot6.png (Dark Sanctuary) & screenshot26.png (Light Sanctuary).

Route: /ignored | Controller: ignored_profiles_controller.dart.

Component Architecture:

Plaintext


IgnoredProfilesScreen (Scaffold)
├── EditorialVaultHeader
│   ├── BackArrowButton
│   └── H2Title ("Ignored Profiles · PASSED RESONANCES")
├── EmptyVaultPlaceholder ("Your pass vault is currently peaceful and empty.")
├── PassProfilesStreamList
│   └── IgnoredProfileTile (ListView item)
│       ├── AvatarWithBlurHashFallback (60x60 circular)
│       ├── ProfileMetaColumn
│       │   ├── NameAndAgeText ("Rohan, 24")
│       │   ├── LocationAndDistanceText ("Civil Lines · 3.2 km away")
│       │   └── PassedTimestampText ("Passed yesterday")
│       └── RevisitActionButton ("Revisit" button in Coral/Pine)
└── StatutoryPrivacyFooter
    └── LegalNoticeText ("Passed profiles are preserved in your encrypted local enclave under DPDP Act 2023.")
Revisit Action:

Tapping "Revisit" calls DELETE /api/v1/swipes/pass/{target_id}.

Profile is smoothly removed from the pass vault list and prepended to the top of feedController deck for immediate reconsideration.

SCREEN 07: RESONANCES (LIKES & MATCHES)
Visual Reference: screenshot7.png (Dark Sanctuary) & screenshot27.png (Light Sanctuary).

Route: /resonances | Controller: resonances_controller.dart.

Component Architecture:

Plaintext


ResonancesScreen (Scaffold)
├── ResonancesSegmentedBar ("Liked You (12)" | "Mutual Connections (8)")
├── TabView_1_LikedYou
│   ├── FreeUserPreviewBanner ("Upgrade to Sovereign Pass to unmask all admirers instantly")
│   └── LikedYouGrid
│       └── IncomingLikeCard
│           ├── BlurHashImageThumbnail (Unmasked for Sovereign users, blurred for free)
│           ├── NameAndAgeRow ("Pooja, 23", Heart icon)
│           ├── RelativeTimeText ("Liked you 15m ago")
│           ├── SharedInterestChip ("Both love Ceramics")
│           └── InstantChatCtaButton ("💬 Chat" - triggers reciprocal like & opens Screen 9)
├── TabView_2_MutualConnections
│   └── MutualConnectionsList
│       └── MutualConnectionTile
│           ├── AvatarThumbnail (With green online activity dot)
│           ├── NameAndAgeText ("Simran, 22")
│           ├── MatchTimestampText ("Matched today at 2:15 PM")
│           ├── ActiveBridgeBadge (Pill indicating: "WhatsApp Enclave", "Instagram Bridge", etc.)
│           └── EnterDialogueButton ("Enter Dialogue ➔")
└── StatutoryFooterText ("Incoming resonances are end-to-end shielded under DPDP Act 2023.")
Instant Match Flow:

Tapping "💬 Chat" immediately calls POST /api/v1/swipes with swipe_type='like'.

Match is generated on backend; client transitions seamlessly to /chat-dialogue?match_id={id}.

SCREEN 08: CHATS HUB & RECENT SPARKS
Visual Reference: screenshot8.png (Dark Sanctuary) & screenshot28.png (Light Sanctuary).

Route: /chats | Controller: chats_list_controller.dart.

Component Architecture:

Plaintext


ChatsHubScreen (Scaffold)
├── ChatsHubAppBar
│   ├── H1SerifTitle ("Chats Hub")
│   └── MindfulSearchBar ("Search heartfelt conversations...")
├── ActiveDialoguesCounterPill ("14 ACTIVE DIALOGUES · 3 Direct · 11 Mutual")
├── RecentSparksSection
│   ├── SectionHeaderTitle ("Recent Sparks ✨")
│   └── RecentSparksHorizontalCarousel
│       └── SparkAvatarItem
│           ├── CircularAvatarWithOnlineDot (72x72)
│           ├── CandidateFirstName ("Tanvi")
│           └── SparkTypePill ("MUTUAL" in Pine or "DIRECT MSG" in Gold)
├── ActiveConversationsListView
│   └── ConversationDialogueTile
│       ├── AvatarWithOnlineDot
│       ├── DialogueDetailsColumn
│       │   ├── NameAgeAndRelativeTime ("Kavya, 23 · 12m ago")
│       │   ├── MatchCategoryTag ("Mutual Match · Architecture & Chai")
│       │   └── LastMessageSnippetText ("I really resonated with that thought...")
│       └── DeliveryStatusIndicator
│           ├── SingleGreyTick (Sent ✓)
│           ├── DoubleGreyTick (Delivered ✓✓)
│           ├── DoubleBlueTick (Read ✓✓)
│           └── UnreadCounterBadge (Terracotta pill if unread messages exist)
└── BottomNavigationBar (Feed | Resonances | Chats | Growth | Persona)
Real-Time Data Pipeline:

Bound to chatsListStreamProvider over WebSocket (wss://<domain>/ws/chat?token=...).

Heartbeat ping-pong every 25 seconds ensures persistent live socket connection.

SCREEN 09: 1:1 ENCRYPTED DIALOGUE SCREEN
Visual Reference: screenshot9.png (Dark Sanctuary) & screenshot29.png (Light Sanctuary).

Route: /chat-dialogue | Controller: chat_dialogue_controller.dart.

Component Architecture:

Plaintext


ChatDialogueScreen (Scaffold, resizeToAvoidBottomInset: true)
├── SecureDialogueAppBar
│   ├── BackArrowButton
│   ├── AvatarWithOnlineDot
│   ├── NameAndOnlineStatusColumn ("Meera, 23", "Quietly online")
│   └── SACRED_BRIDGE_STATUS_ACTION
│       ├── If Locked: EnclaveProgressBadge ("WA Key 2/3" or "Insta 1/3" -> Opens Reveal Modal)
│       └── If Unlocked: GlowingBridgeBadge ("Bridge Unlocked ✓" -> Direct Launcher)
│
├── SharedContextPromptCard (Anchored below app bar)
│   └── QuoteBox ("I loved that Haruki Murakami passage on quiet spaces...")
│
├── AI_BESPOKE_ICEBREAKERS_ROW (Groq Llama-3.1-8b Generated)
│   └── HorizontalScrollablePills (Visible for new matches with 0 messages)
│       ├── IcebreakerChip ("What is a quiet ritual that keeps you grounded? ✨")
│       ├── IcebreakerChip ("I noticed we both love pour-over coffee. ✨")
│       └── IcebreakerChip ("What was the last book that genuinely moved you? ✨")
│
├── DialogueMessagesStream (ReverseListView)
│   └── MessageBubbleWidget
│       ├── UserBubble (Right-aligned, Sanctuary Pine/Dark Green)
│       ├── PeerBubble (Left-aligned, Slate/Dark card surface)
│       ├── MessageTimestampText ("10:42 PM")
│       └── ThreeStageTickIndicator (✓ Sent, ✓✓ Delivered, ✓✓ Read)
│
└── TextOnlyInputBar
    ├── MindfulTextField ("Write a heartfelt message...", maxLines: 4)
    └── SendMessageIconButton (Circular coral/pine button)
Strict Security, Hardware & NLP Directives:

FlutterWindowManager.addFlags(FLAG_SECURE) in initState(), cleared in dispose(). Physical screenshots and screen recordings produce a 100% black screen.

Strictly 100% Text-Only: No camera icon, no photo picker, no audio note recorder, no file attachment widgets exist in code.

Local NLP Gatekeeper: Client checks input text for 10-digit Indian numbers, spelled-out Hindi numbers, social media handles, or URLs. Violations trigger PolicyViolationToast and abort send.

Sacred Bridge Single-Tap Deep Link Launcher:

Once bilateral 3/3 reveal ritual is complete or Instant Key is redeemed, app bar action triggers native platform intent:

WhatsApp → https://wa.me/<number>

Instagram → instagram://user?username=<handle>

Snapchat → snapchat://add/<handle>

Telegram → https://t.me/<handle>

Signal → sgnl://send?recipient=<id>

SCREEN 10: GROWTH PRO & SOVEREIGN VAULT (DUAL-ENGINE MONETIZATION)
Visual Reference: screenshot10.png (Dark Sanctuary) & screenshot30.png (Light Sanctuary).

Route: /growth | Controller: growth_hub_controller.dart.

Component Architecture:

Plaintext


GrowthHubScreen (Scaffold, SingleChildScrollView)
├── EditorialHeaderTitle ("Growth PRO & Sovereign Vault")
├── ResourceCounterMetricsBar
│   ├── MetricPill ("25 Swipes Left")
│   ├── MetricPill ("1 Direct Letter")
│   └── MetricPill ("Bridge Key 2/3")
│
├── MonetizationModeSegmentedToggle ("🎁 Free Mindful Ads" | "👑 Sovereign Pass")
│
├── TAB_VIEW_A_FREE_MINDFUL_ADS (100% Free / India Focus)
│   ├── ZeroPaywallPhilosophyBanner ("100% FREE SANCTUARY · ZERO PAYWALLS. Replenish in balance.")
│   ├── RewardedPlacementCard_1
│   │   ├── Title ("Quick Reflection (10s Sponsor)")
│   │   ├── RewardText ("+10 Profile Skips / Swipes")
│   │   └── WatchAdButton ("Watch 10s Reflection" -> Triggers 0ms Double-Buffer Ad)
│   ├── RewardedPlacementCard_2
│   │   ├── Title ("Deep Resonance (20s Sponsor)")
│   │   ├── RewardText ("+1 Direct Letter (Message before match)")
│   │   └── WatchAdButton ("Watch 20s Sponsor")
│   ├── RewardedPlacementCard_3
│   │   ├── Title ("Sacred Bridge Reveal Ritual (30s Sponsor)")
│   │   ├── RewardText ("+1 Step towards unmasking Contact Bridge (Bilateral 3/3)")
│   │   └── WatchAdButton ("Watch 30s Ritual")
│   ├── NightSanctuarySlumberCard
│   │   ├── SlumberToggleSwitch ("Night Sanctuary Slumber")
│   │   └── SubtitleText ("Rest device face-down overnight. Wake up to Morning Harvest (+20 Swipes).")
│   └── SacredKinshipReferralCard
│       ├── ReferralCodePill ("SANCTUARY-09")
│       ├── CopyCodeButton ("Copy Code")
│       └── InviteViaWhatsAppButton ("Invite via WhatsApp ➔")
│
└── TAB_VIEW_B_SOVEREIGN_PASS (Google Play v7 + Sanctuary Web Store)
    ├── SovereignPerksBanner ("Pure Silence · Infinite Resonances · Zero Ads")
    ├── WebStoreDiscountNoticeBox
    │   └── Text ("Visiting urheart.app/store grants 10% Extra Passes & Instant Web Checkout!")
    ├── SubscriptionPassCardsGroup
    │   ├── PassCard_Weekly ("1-Week Sovereign Sprint", "$4.99 / ₹49")
    │   ├── PassCard_Monthly ("1-Month Sovereign Pass", "$14.99 / ₹149", "Most Mindful Badge")
    │   └── PassCard_Lifetime ("Lifetime Sovereign Crest", "$59.99 / ₹799", "One-Time Forever")
    ├── ALaCarteMicroStoreGroup
    │   ├── MicroTile ("Instant Bridge Key", "$1.49 / ₹29", "Skip 3-ad ritual instantly")
    │   ├── MicroTile ("3 Direct Letters Pack", "$1.99 / ₹49", "Reach private inbox")
    │   └── MicroTile ("48h Global Passport", "$2.99 / ₹79", "Teleport to London / NYC")
    ├── GooglePlayOneTapPurchaseButton ("Acquire Sovereign Privilege ➔")
    └── RestorePurchasesButton ("Restore Purchases (Google Play)")
Ad Preloading Engine:

Free users experience 0ms video loading delay via RewardedAdManager FIFO double-buffering.

Night Slumber mode does NOT auto-loop video ads in background (100% AdMob IVT policy compliant); morning device pickup triggers interactive wake-up claim dialog.

SCREEN 11: MY PERSONA VIEW & EDITOR
Visual Reference: screenshot11.png (Dark Sanctuary) & screenshot31.png (Light Sanctuary).

Route: /persona | Controller: persona_controller.dart.

Component Architecture:

Plaintext


MyPersonaScreen (Scaffold, SingleChildScrollView)
├── PersonaTopBar ("My Persona", SettingsIcon routing to Screen 13)
├── PersonaSegmentedNavTabs ("1. My Persona" | "2. Growth PRO" | "3. Vault & Legal")
├── ProfileHeroOverviewCard
│   ├── AvatarWithEditPill (Pencil badge opens camera/gallery)
│   ├── FullNameAndAge ("Anubhav, 23")
│   ├── VerifiedSanctuaryCrestBadge
│   └── MemberJoinDate ("Sanctuary Member since Oct 2024")
├── FourSlotMomentsGrid
│   └── MomentsSlotItem (1 to 4) (In-place WebP overwrite directly to Firebase Storage)
├── LockedCredentialsSection
│   ├── DobPill ("14 Oct 2002 · LOCKED & VERIFIED", Padlock icon)
│   ├── OrientationPill ("Man seeking Women")
│   │
│   └── SACRED_CONTACT_BRIDGE_CONTAINER
│       ├── PlatformSelectorDropdown (WhatsApp | Instagram | Snapchat | Telegram | Signal)
│       ├── EncryptedValueDisplay ("+91 98765 ***** · ENCRYPTED" or "@insta_handle · ENCRYPTED")
│       └── UpdateBridgePencilAction (Opens bottom sheet modal to update handle)
│
├── EditorialBioAndPreferencesSection
│   ├── LocationDisplayRow ("Saket, Ayodhya", "Update GPS" button)
│   ├── BioTextFieldWithGroqRewrite ("Mindful Polish ✨" button)
│   ├── ProfessionAndEducationRows
│   └── PreferredAgeRangeSlider (18–35 years)
└── SavePersonaChangesButton ("Save Sanctuary Updates ➔")
SCREEN 12: STATUTORY VAULT & GOVERNANCE
Visual Reference: screenshot12.png (Dark Sanctuary) & screenshot32.png (Light Sanctuary).

Route: /vault | Controller: statutory_vault_controller.dart.

Component Architecture:

Plaintext


StatutoryVaultScreen (Scaffold, SingleChildScrollView)
├── SecurityBadgesRow
│   ├── BadgeChip ("E2E Encrypted (Curve25519)")
│   ├── BadgeChip ("Zero Logs (Statutory Vault)")
│   └── BadgeChip ("DPDP Act 2023 Compliant")
├── StatutoryDataRightsSection (DPDP Act 2023)
│   ├── DownloadDataCard (Sec 11)
│   │   ├── Title ("Download My Data")
│   │   ├── Subtitle ("Request a cryptographically signed JSON archive of your account.")
│   │   └── RequestExportButton ("Request Export ➔" -> Triggers 7-day signed URL)
│   └── NomineeDesignationCard (Sec 14)
│       ├── Title ("Designate Data Nominee")
│       ├── Subtitle ("Appoint a trusted person to manage your presence in unforeseen events.")
│       └── DesignateButton ("Designate ➔" -> Opens Nominee Form Modal)
├── GrievanceRedressalSection (IT Rules 2021)
│   ├── GrievanceDossierCard (Rule 3(2))
│   │   ├── Title ("Grievance Redressal Dossier")
│   │   ├── Subtitle ("File a priority statutory grievance. SLA: 24h ack, 15d resolution.")
│   │   └── FileDossierButton ("File Dossier ➔" -> Opens complaint modal)
│   └── BlockedPerimeterCard
│       ├── Title ("Privacy & Blocked Users")
│       └── ManageBlockedButton ("Manage (14) ➔" -> Opens BlockedPerimeterList)
└── StatutoryFooterBadge ("UR-HEART STATUTORY AUDIT ID: IND-DPDP-2023-VAULT")
SCREEN 13: SANCTUARY PREFERENCES & GOVERNANCE
Visual Reference: screenshot13.png (Dark Sanctuary) & screenshot33.png (Light Sanctuary).

Route: /settings | Controller: settings_controller.dart.

Component Architecture:

Plaintext


SanctuarySettingsScreen (Scaffold, SingleChildScrollView)
├── SettingsTopBar ("Sanctuary Preferences · Settings", ShieldBadge: "E2E Shielded")
├── AlertsAndQuietSection
│   ├── SwitchRow ("Master Resonance", "Receive mindful notifications")
│   ├── SwitchRow ("Discreet Mode", "Masks sender names and previews on lock screen")
│   └── SwitchRow ("Night Sanctuary Slumber", "Silences chimes between 11 PM and 7 AM")
├── PrivacyAndDiscoveryVault
│   ├── IncognitoGhostCloakRow
│   │   ├── Title ("Incognito Stream Radius")
│   │   └── DropdownSelector ("Visible to Sanctuary" | "Ghost Cloak (Hidden from Public Deck)")
│   └── CryptographicKeyRotationRow
│       ├── Title ("Cryptographic Key Rotation")
│       └── RekeyButton ("Re-key ⟳" -> Generates fresh ephemeral Curve25519 keypair)
├── SovereignBillingManagementRow ("Manage Sovereign Subscription ➔" -> Opens Google Play)
├── SovereignControlAndExitSection
│   ├── LogOutButton ("Log Out of Sanctuary" -> Purges session tokens and RAM buffers)
│   └── IrrevocableAccountDeletionBox (Crimson Warning Container)
│       ├── Title ("Delete Account & Erase All Data")
│       ├── Subtitle ("Statutory DPDP Act Sec 12 cryptographic incinerator. All records shredded.")
│       └── EraseButton ("Erase Everything Irrevocably ➔" -> Requires typing 'ERASE')
│
└── RESTRICTED_SUPERADMIN_SENTINEL_TILE
    └── ConditionalRender:
        ├── IF currentUser.email == 'kshtriyaanubhav9120@gmail.com':
        │   └── GoldSentinelCard ("👑 Superadmin KYC Sentinel Desk ➔", routes to /admin/kyc-desk)
        └── ELSE:
            └── SizedBox.shrink() (100% invisible to all regular users)
Cascading Shredding Execution:

Typing "ERASE" triggers DELETE /api/v1/auth/incinerate-account.

FastAPI cascades deletion across Supabase tables via foreign key ON DELETE CASCADE, calls Firebase Admin SDK to delete users/{uuid}/ storage files, wipes local SharedPreferences and installation UUID, and terminates the session.

3. ANTIGRAVITY VERIFICATION & IMPLEMENTATION ASSERTIONS
Antigravity agent ko Screens 1 se 13 build karte waqt nimn specifications check karni hain:

Strict 250-Line Ceiling: Koi bhi Dart file 250 lines exceed nahi karegi. Har screen micro-widgets aur dedicated Riverpod controllers mein decomposed honi chahiye.

Multi-Platform Contact Bridge: Confirm karein ki Screen 4 aur Screen 11 par Dropdown 5 platforms (WhatsApp, Instagram, Snapchat, Telegram, Signal) support kare, aur Screen 9 par unmask hone par respective deep-link launch kare.

360° AI Triggers: Verify karein ki Screen 4/11 par Bio Polish Groq API ko hit kare, Screen 5 par AI Resonance Insight render ho, aur Screen 9 par 3 Bespoke AI Icebreaker chips display hon.

Hardware Screenshot Shield: Verify karein ki Screen 9 par FLAG_SECURE active ho aur real device par screenshot block ho.

Superadmin Sentinel Gate: Verify karein ki Screen 13 ke bottom par KYC Sentinel Desk sirf aur sirf kshtriyaanubhav9120@gmail.com ke liye render ho.

