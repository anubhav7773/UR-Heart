# UI/UX Design System, Vernacular Tokens & Google Stitch MCP Prompts

**Document Identifier:** URH-UIX-009  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Design Philosophy:** "Desi-Modern, High-Affordance Romanticism"  
**Target Demographics:** Tier-2, Tier-3 Cities & Semi-Urban India (Ages 18–32)  
**Primary Tooling:** Google Stitch MCP (Model Context Protocol)  
**Accessibility Level:** WCAG 2.1 AA Compliant (High Contrast, Large Touch Targets $\ge 48\times48$ dp)

---

## 1. Visual Identity, Psychological Cues & Tier-2/3 Dynamics

### 1.1. Psychological Design Pillars
Dating apps in Tier-2 and Tier-3 Indian cities (e.g., Gorakhpur, Lucknow, Patna, Indore, Meerut) require a design language fundamentally different from Western-centric apps:
1. **Unambiguous Affordance:** Users must not guess gestures. Every swipe action has a paired explicit circular button with bold visual indicators.
2. **Privacy Reassurance:** Due to heightened social stigma and fear of doxxing, persistent subtle badges (`🔒 Screen Recording & Screenshots Blocked`) must be visibly present to instill confidence, especially among female users.
3. **Value Transparency:** Because the app is 100% free and monetized via video ads, ad checkpoints must feel like legitimate rewards rather than spam. Rewarded actions are styled with golden/neon token iconography.
4. **Bilingual Clarity:** Technical English phrases (like *"Server-side verification"* or *"End-to-End Encryption"*) must be accompanied by intuitive, conversational Hindi subtitles.

---

## 2. Design Tokens & Color System

The interface uses a **Dark Romantic Palette** designed to look premium on budget OLED/AMOLED and low-contrast LCD screens while reducing battery drain on mobile devices.

### 2.1. Color Tokens (Hex & Semantic Application)

| Token Name | Hex Code | Purpose & Usage |
| :--- | :--- | :--- |
| `color-bg-canvas` | `#0A0A0D` | Master background canvas (Deep Obsidian) |
| `color-surface-card` | `#16161D` | Elevation Level 1 (Profile cards, bottom sheets) |
| `color-surface-raised` | `#22222C` | Elevation Level 2 (Input fields, chip containers) |
| `color-brand-primary` | `#FF2E63` | Electric Crimson (Primary CTA, Like button, active hearts) |
| `color-brand-secondary`| `#08D9D6` | Cyber Turquoise (Direct DM actions, verified badges) |
| `color-accent-gold` | `#FFD166` | Flame Streaks, Ad Reward Tokens, Crown Badges |
| `color-status-danger` | `#FF334B` | Anti-Leak red banners, report/block actions, delete warnings |
| `color-status-success`| `#06D6A0` | WhatsApp unlock status, KYC approved checkpoints |
| `color-text-primary` | `#FFFFFF` | Hero titles, profile names, prominent button text |
| `color-text-secondary`| `#A0A0B2` | Subtitles, bios, bilingual explanatory microcopy |
| `color-text-muted` | `#636375` | Timestamps, inactive tabs, unselected states |

### 2.2. Typography Scale (Inter / Hind Bilingual Pair)
- **Display 1 (Splash / Streaks):** `28px` SemiBold / Line-height `36px`
- **Headline (Card Profile Name):** `22px` Bold / Line-height `28px`
- **Title (Modal / Sheet Headers):** `18px` SemiBold / Line-height `24px`
- **Body Large (Chat Messages, Bios):** `15px` Regular / Line-height `22px`
- **Body Small (Bilingual Hindi Notes):** `13px` Regular / Line-height `18px`
- **Caption / Pill (Ad Countdown HUD):** `11px` Medium / Line-height `14px`

### 2.3. Radii, Elevation & Touch Targets
- **Card Radius:** `24px` (Rounded pebble aesthetic for feed profiles)
- **Modal / Sheet Radius:** `28px` (Top corners for bottom sheets)
- **Button Radius:** `999px` (Full pill shape for all action buttons)
- **Minimum Tap Target:** `48 × 48` dp (Ensures zero mis-clicks on 5.5" to 6.7" screens)

---

## 3. Screen-by-Screen Specifications & Exact Stitch Prompts

Copy and paste these exact prompts into **Google Stitch MCP** to generate the screens:

---

### SCREEN 1: Splash, Google One-Tap & Neutral Age-Gate Screen
```text
Generate a production mobile screen for a dating app named "UR-Heart" (Parent: ASI Verticals) tailored for Indian Tier-2/Tier-3 audiences.
Theme: Deep Obsidian background (#0A0A0D).
- Header: Minimalist glowing neon heart icon centered at the top, followed by bold headline "UR-Heart" and sub-headline "100% Free Desi Dating / मुफ़्त और सुरक्षित मेल-जोल".
- Center Card (#16161D, radius 24px):
  * Age Verification Section: Prominent "18+ Only" yellow shield badge.
  * Neutral Date of Birth Selector: Wheel picker initialized with no pre-selected date (blank day/month/year).
  * Hindi microcopy below wheel: "केवल 18 वर्ष या उससे अधिक उम्र के लिए".
- Bottom Actions:
  * Primary Button (Full Width, Pill Radius): "Continue with Google" featuring the official Google 'G' icon on a clean white background with dark typography.
  * Secondary Text Button: "Use Phone Number / मोबाइल नंबर से लॉगिन".
- Legal Footer: Compact 11px muted grey text: "By joining UR-Heart, you agree to our EULA Terms of Service, DPDP Privacy Notice, and Zero-Harassment Policy. Operated by ASI Verticals."
Layout must feel trustworthy, modern, and legally rock-solid.
SCREEN 2: 5-Photo Upload, Live OCR Warning & KYC ViewfinderPlaintextGenerate a mobile screen for the profile onboarding photo verification flow of "UR-Heart".
Theme: Dark Romantic (#0A0A0D).
- Top App Bar: "Upload 5 Profile Photos / 5 फ़ोटो अपलोड करें" with step indicator "Step 2 of 3".
- High-Visibility Anti-Leak Banner (#FF334B at 15% opacity, border 1px solid #FF334B, radius 16px):
  * Amber warning icon on the left.
  * Text (Bilingual): "⚠️ Important: Photos containing phone numbers, Instagram IDs (@, IG), WhatsApp, or QR codes will be rejected automatically by our AI."
- Photo Grid Layout:
  * Slot 1 (Hero Slot, spans full width, 220px height): Large dashed border with camera icon, label "Main Display Picture (Profile Hero)", and "AI OCR Verified" green tag.
  * Slots 2 to 5 (2x2 Grid below Slot 1): Smaller square slots (100x100px) with subtle "+" icons and labels "Slot 2", "Slot 3", "Slot 4", "Slot 5".
- 5-Second Video KYC Viewfinder Card (#16161D, radius 20px, margin top 16px):
  * Circular selfie preview area (80x80px) showing camera feed.
  * Headline: "5-Second Safety Video / 5-सेकंड की सेल्फ़ी वीडियो".
  * Subtext: "Say your name and city to confirm identity. Deleted in 24 hours per DPDP Act."
  * Button: "Start Quick Recording (5s)" with red record dot.
- Floating Bottom CTA: Glowing Electric Crimson (#FF2E63) pill button: "Verify & Continue".
SCREEN 3: Discovery Swipe Feed with Rewarded DM & Ad Countdown HUDPlaintextGenerate the core Discovery Swipe Feed screen for "UR-Heart" dating app.
Theme: Dark Obsidian (#0A0A0D).
- Top App Bar:
  * Left: Brand title "UR-Heart" with a subtle red flame.
  * Right: Streak badge (#FFD166, flame icon + "7 Days") and Ad Reward Token balance (🪙 "12 DMs").
- Paced Ad Countdown Pill (Positioned right below Top Bar, centered):
  * Translucent dark pill with glowing cyan border: "Ad in 4 swipes / 4 स्वाइप बाद विज्ञापन".
- Main Card Stack (#16161D, radius 28px, fills 70% of screen height):
  * Hero Image of user with soft gradient fade at the bottom.
  * Top Left of Image: Small frosted-glass privacy pill: "🔒 Protected by FLAG_SECURE".
  * Top Right of Image: City Pill: "📍 Lucknow (4 km away)".
  * Bottom Overlay on Card: Profile name "Priya, 23" with blue verified tick, bio snippet "Lover of chai, old Hindi songs, and digital painting", and 3 interest chips (#22222C).
- Bottom Action Dock (3 Floating Circular Buttons with high contrast):
  * Left Button (Diameter 56px, #22222C): Large red "X" icon (Pass).
  * Center Button (Diameter 68px, gradient #08D9D6 to #0081C9, raised elevation): Star icon with attached floating badge "Watch 10s Ad -> 3 Direct DMs".
  * Right Button (Diameter 56px, #FF2E63): Large white Heart icon (Like).
Clean, distraction-free, and optimized for one-thumb mobile swiping.
SCREEN 4: Protected Chat Room with Anti-Leak Rejection AlertPlaintextGenerate a 1-on-1 private messaging screen for "UR-Heart" demonstrating the anti-leak violation state.
Theme: Dark Canvas (#0A0A0D).
- Custom App Bar:
  * Avatar of match (circle 40px) with green online indicator dot.
  * Name: "Rahul Verma" with subtext "🔒 Screenshots & Recording Blocked".
  * Right Action: 3-dot overflow menu for "Report / Block" and a prominent Gold Button: "Unlock WhatsApp 💬".
- Chat Bubble Stream:
  * Match Bubble (Left, #22222C, radius 18px): "Hey! Nice to meet you here. How was your day?" with timestamp "08:14 PM".
  * User Bubble (Right, #FF2E63, radius 18px): "Hi Rahul! It was good, just finished work." with blue double ticks "08:16 PM".
- ACTIVE ERROR STATE (Anti-Leak Gatekeeper Triggered):
  * Rejected User Bubble (Right): Greyed-out bubble with red dashed border containing "Call me at 9876543210 or check my insta @rahul_01". A red exclamation triangle icon is affixed to the side.
  * High-Alert Bottom Banner (Directly above input dock, #FF334B, radius 12px, padding 12px):
    - Title: "🚫 Contact Sharing Blocked / संपर्क साझा करना वर्जित है"
    - Subtext: "Sharing phone numbers, Instagram, or external links is strictly forbidden. Tap 'Unlock WhatsApp' above to reveal contacts safely via sponsored ads."
- Bottom Input Dock:
  * Rounded text field (#16161D) with placeholder "Type a message..." (red highlight on border).
  * Send button (disabled state with red tint).
SCREEN 5: Mutual WhatsApp Reveal 3-Ad Checkpoint Bottom SheetPlaintextGenerate a bottom sheet modal for the "Mutual WhatsApp Reveal" feature in "UR-Heart".
Theme: Deep Charcoal (#16161D, top corner radius 28px).
- Header Drag Handle: Subtle grey pill (40x4px).
- Title Area:
  * Centered bold headline: "Unlock Mutual WhatsApp Contact"
  * Sub-headline (#A0A0B2): "100% Free forever. Both you and Rahul must watch 3 short video clips to reveal numbers."
- Dual-Sided Progress Tracker Card (#22222C, radius 20px, padding 16px):
  * Column 1 (Your Progress - "You / आप"):
    - Three circular video badges in a row:
      [✓ Completed] (Green fill)  
      [✓ Completed] (Green fill)  
      [▶ Ad 3 (30s)] (Active glowing gold border)
    - Subtext: "2 of 3 Watched"
  * Vertical Divider Line.
  * Column 2 (Match Progress - "Rahul"):
    - Three circular video badges in a row:
      [✓ Completed] (Green fill)  
      [⏳ Waiting] (Grey outline)  
      [⏳ Waiting] (Grey outline)
    - Subtext: "1 of 3 Watched"
- Action Button (Full width, height 54px, gradient #06D6A0 to #00B4D8, radius 999px):
  * Text: "Watch Video Ad (30s) to Progress [2/3]" with play icon.
- Disclaimer Footer (#636375, 11px): "Contact is revealed only when both users reach 3/3. No spam, no subscription ever."
SCREEN 6: Profile, Streak Vault & One-Tap Account Erase CenterPlaintextGenerate the user profile and gamification screen for "UR-Heart".
Theme: Dark Obsidian (#0A0A0D).
- Header Section:
  * Profile Photo (100x100px, circular, glowing gold border) with "Verified KYC" blue tick badge.
  * User Name: "Aman Gupta, 24" (Lucknow, UP).
  * Tier Badge Pill (#FFD166 with flame icon): "Level 2: Silver Spark 🔥".
- Streak & Reward Vault (#16161D, radius 24px, padding 18px):
  * Big Flame Icon with animated glow: "14 Days Active Streak".
  * Stat Grid (2 columns):
    - "Direct DMs Available": 🪙 9 Credits (Earned via 10s Ads).
    - "Total Ads Supported": 42 Sponsored Views.
  * Persistence Warning Notice (#FFB703 at 10% opacity, border 1px solid #FFB703, radius 12px, padding 10px):
    - Text: "⚠️ Keep UR-Heart installed! Uninstalling or clearing app data resets your streak and rewards to 0."
- Account & Safety Settings List (#16161D, radius 20px):
  * Row 1: "Edit Profile & 5 Photos" with chevron.
  * Row 2: "Grievance Redressal & Legal (ASI Verticals)" with external link icon.
  * Row 3: "Privacy & Blocked Users" with lock icon.
- Danger Zone (Separated at bottom):
  * One-Tap Data Erase Button (Full width, transparent background, solid red border #FF334B, radius 999px):
    - Text: "🗑️ One-Tap Data Erase / खाता और डेटा हमेशा के लिए मिटाएं"
    - Subtext below button: "Instantly deletes all photos, messages, and KYC files per DPDP Act 2023."
4. Bilingual Microcopy Matrix (English + Hindi)The following table maps the exact strings to be used in UI components across English and Hindi:UI KeyEnglish TextHindi Vernacular TextContext / Placementbtn_google_authContinue with Googleगूगल से आगे बढ़ेंOnboarding Authage_gate_noticeStrictly 18+ years onlyकेवल 18+ वर्ष के लिएDate of Birth Wheelfeed_ad_counterAd in {x} swipes{x} स्वाइप बाद विज्ञापनFeed Progress Pilldirect_dm_ctaWatch 10s Ad -> 3 Direct DMs10s विज्ञापन देखें -> 3 डायरेक्ट मैसेजFeed Action Buttonscreenshot_blocked🔒 Protected by FLAG_SECURE🔒 स्क्रीनशॉट और रिकॉर्डिंग ब्लॉक हैFeed / Chat Headeranti_leak_errorContact sharing is prohibitedसंपर्क नंबर शेयर करना वर्जित हैChat Red Alert Bannerwa_reveal_buttonUnlock WhatsApp 💬व्हाट्सएप अनलॉक करें 💬Chat AppBar Buttonwa_reveal_progressBoth must watch 3 video clipsदोनों को 3 वीडियो देखना आवश्यक हैWhatsApp Reveal Sheetstreak_titleActive Fire Streakसक्रिय लपट स्ट्रीकProfile Vaultuninstall_warningUninstalling resets streak to 0ऐप हटाने पर स्ट्रीक 0 हो जाएगीProfile Warning Carddata_erase_buttonDelete Account & Erase All Dataखाता और डेटा हमेशा के लिए मिटाएंProfile Danger Zone5. Component Hierarchy & Micro-InteractionsApp Scaffold (Root)
│
├── Top Navigation Overlay
│   ├── Brand Wordmark & Flame Icon
│   ├── Streak Counter Pill (#FFD166)
│   └── Paced Ad Countdown HUD (Progressive fill every swipe)
│
├── Feed Discovery Core
│   ├── Card Stack Swiper (Dismiss threshold: 35% screen width)
│   │   ├── Progressive BlurHash Placeholder (0ms)
│   │   ├── High-Res WebP Fade-In (200ms cubic-bezier)
│   │   └── Frosted Privacy Pill ("FLAG_SECURE Active")
│   └── Floating Action Dock (Pass, Direct DM Rewarded, Like)
│
├── Real-Time Chat Surface
│   ├── Hardware Secure Viewport (Blacks out screenshots)
│   ├── Double-Check Message Bubble Delivery
│   └── Anti-Leak Red Error Banner (Slides down on HTTP 422)
│
└── Mutual WhatsApp Reveal Modal
    ├── Dual Progress Checkpoint Grid ([✓][✓][▶])
    └── Server-Side Verified Video Action Button
6. Antigravity Agent Verification SuiteThe Antigravity coding engine must ensure that generated Flutter UI widgets match these exact design tokens:[ ] Contrast Verification: Verify that color-text-primary (#FFFFFF) against color-bg-canvas (#0A0A0D) achieves a contrast ratio $> 15:1$ (exceeding WCAG AAA).[ ] Touch Target Check: Verify all action buttons (Like, Pass, Direct DM, Watch Ad) have a minimum tap area of $48\times48$ dp.[ ] Visual BlurHash Transition: Verify that feed image widgets use flutter_blurhash to render immediate placeholders before network WebP images finish loading.[ ] Dynamic Flag Toggling: Verify that entering ChatScreen renders the 🔒 Protected by FLAG_SECURE subtext and activates FlutterWindowManager.FLAG_SECURE.[ ] Bilingual String Mapping: Verify that switching the app language immediately updates all buttons and banners using VernacularStrings.Authorized & Validated for ASI Verticals / UR-Heart UI/UX Design System.