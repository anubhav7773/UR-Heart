# 🎨 UR-Heart — Comprehensive UI/UX Design System & Architectural Specification

**Document File:** `docs/UI_UX_REVAMP_SPECIFICATION.md`  
**Target Platform:** Flutter 3.x (Android minSdk 24+, targetSdk 34+)  
**App Identifier:** `com.ruralheart.app`  
**Design Philosophy:** Obsidian Dark Theme, High-Contrast Micro-Monetization, Regional Trust Vectors & Ergonomic Thumb Reach.

---

## 1. Design System & Global Token Hierarchy

### 1.1 Color Palette Tokens
* **Background & Surfaces:**
  * `surface_root`: `#0A0B10` (Pure Obsidian Slate root scaffold background)
  * `surface_card`: `#14161F` (Elevated container surface with 4% blue undertone)
  * `surface_interactive`: `#1C1F2E` (Higher elevation for input fields, buttons, and tap targets)
  * `border_subtle`: `#272A3D` (1px subtle border stroke for cards and dividers)
* **Brand Accents & Trust Vectors:**
  * `accent_primary`: `#FF3366` (Neon Coral Heart for primary actions and active navigation items)
  * `accent_boost_gold`: `#FFB800` (Electric Amber Gold for ₹29 Super Boost and monetization passes)
  * `accent_verified_blue`: `#00B4D8` (Cyber Cerulean Blue for verified selfie badges and read receipts)
  * `status_online`: `#00E676` (Mint Green indicator dot for active users)
  * `status_destructive`: `#FF4D4D` (Soft Crimson for block, report, and delete account actions)
* **Typography Hierarchy:**
  * `text_primary`: `#FFFFFF` (100% white, high-contrast readability)
  * `text_secondary`: `#8E92A8` (Muted slate grey for timestamps, subtitles, and distance tags)
  * `text_tertiary`: `#5E6278` (Dark slate for placeholder text and disabled states)

### 1.2 Layout & Elevation Standards
* **Card Corner Radii:**
  * `radius_sm`: `8.0` (Tags, chips, and small badges)
  * `radius_md`: `14.0` (Action cards, list items, and modal dialogs)
  * `radius_lg`: `20.0` (Discovery cards and main bottom sheets)
* **Haptic Feedback Tokens:**
  * Light impact on standard tab switches.
  * Medium impact on swipe and like triggers.
  * Heavy/Success pattern on successful payment and verified badge unlocks.

---

## 2. Screen-by-Screen UI/UX Specifications

### 2.1 Splash Screen (`mobile_app/lib/features/splash/splash_screen.dart`)
* **Current State Defect:**
  * Subtitle text repeats redundant phrases ("Genuine Connections Across Rural & Urban" combined with "Genuine Connections Across Rural & Bharat").
* **Target UI/UX Implementation:**
  * **Brand Tagline:** Clean single-line text: `"Genuine Connections Across Bharat"` styled in `13sp, color: #8E92A8, letterSpacing: 0.5`.
  * **Central Hero Glyph:** Pinned coral heart icon inside a glowing radial container. Add an ambient pulsing breath animation using `AnimationController` with a repeating `BoxShadow(blurRadius: 32, spreadRadius: 4, color: Color(0x55FF3366))`.
  * **Bottom Trust Watermark:** Bottom-pinned security label displaying a lock icon + `"Protected by Hardware-Level Privacy"` (`11sp, color: #5E6278`).

---

### 2.2 Discovery Feed Empty State (`mobile_app/lib/features/feed/feed_screen.dart`)
* **Current State Defect:**
  * Displays a static, lifeless empty box with plain text when no users are found within the active radius.
* **Target UI/UX Implementation:**
  * **Animated Radar Sweep Engine:** Replace the static center icon with an animated concentric radar wave (3 expanding rings fading from opacity 0.6 to 0.0) signaling live spatial scanning.
  * **Header Typography:** Change headline to `"Scanning Nearby Horizons..."` (`18sp, FontWeight.bold, color: #FFFFFF`).
  * **Monetization & Action Cards Layout:**
    * **Card 1 (Ad Reward Swipes):** Container with `#14161F` background, `#00E676` mint green border, featuring `"Watch short video (+5 free swipes)"` with an emerald play icon.
    * **Card 2 (Sachet Super Boost):** Container with `#14161F` background, `#FFB800` electric gold border, featuring `"Super Boost Profile (₹29)"` with an animated lightning icon.
  * **State Preservation:** Enforce `AutomaticKeepAliveClientMixin` on `FeedScreen` so switching tabs does not reset or reload the radar state.

---

### 2.3 Matches & Conversations List (`mobile_app/lib/features/chat/chat_screen.dart`)
* **Current State Defect:**
  * Plain text list tiles with unaligned read ticks and basic typography lacking depth.
* **Target UI/UX Implementation:**
  * **Top Active Matches Tray:** Horizontal list displaying 60dp circular avatars. Unread matches display a glowing `#FF3366` outer border ring; online matches display an overlapping 10dp `#00E676` green presence dot.
  * **Conversation List Row Architecture:**
    * **Avatar:** 52dp rounded avatar with an overlapping 16dp Cyber Cerulean verified blue check badge pinned at the bottom-right corner.
    * **Header Line:** Contact name in `15sp, FontWeight.w600, color: #FFFFFF`, right-aligned timestamp in `11sp, color: #8E92A8`.
    * **Message Preview Line:** Double blue tick icon (`#00B4D8`) inline with truncated message snippet text (`13sp, color: #8E92A8`).
    * **Unread Pill Badge:** High-contrast coral capsule (`#FF3366`, white text, `height: 18dp, padding: 6dp horizontal`) right-aligned.
  * **Divider:** `1px` subtle stroke using `#272A3D` with `72dp` left inset to maintain avatar separation.

---

### 2.4 Activity & Swipes Grid (`mobile_app/lib/screens/activity_screen.dart`)
* **Current State Defect:**
  * Boxy 2x2 grid with sharp card corners, uneven image aspect ratios, and misplaced blue checkmarks.
* **Target UI/UX Implementation:**
  * **Card Geometry:** Enforce a strict `9:13` aspect ratio across all grid items inside `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.69, crossAxisSpacing: 12, mainAxisSpacing: 12)`.
  * **Corner Radius & Shadows:** `BorderRadius.circular(16)` with an inner bottom dark gradient overlay (`rgba(0,0,0,0.85)` at bottom to transparent at top 40%) for text readability.
  * **Verified Badge Placement:** Absolute top-right floating badge encased in a glassmorphic pill container (`background: rgba(0,0,0,0.55)`, `backdropFilter: ImageFilter.blur(4, 4)`).
  * **Direct Action CTA:** Card bottom features an integrated `"Message"` button with a solid gradient background (`#FF3366` to `#FF5E7E`), rounded corners (`10dp`), and a subtle tap bounce animation.

---

### 2.5 User Profile & Gallery Screen (`mobile_app/lib/features/profile/profile_screen.dart`)
* **Current State Defect:**
  * Bottom photo thumbnails appear squeezed and narrow; navigation settings tiles lack visual grouping.
* **Target UI/UX Implementation:**
  * **Avatar Hero Unit:** Centered 96dp circular avatar surrounded by a 3dp gradient ring (`#FF3366` to `#FFB800`) with a prominent verified shield icon.
  * **Feature Banner Hierarchy:**
    * **Banner 1:** *Monetization & VIP Passes* card with dark wine background, left-aligned pass badge icon, and an active subscription status indicator.
    * **Banner 2:** *Profile Verified* banner in dark slate with `#00B4D8` cyan outline and check shield, displaying video selfie approval status.
  * **Photos Gallery Grid:**
    * Structured 3-column square grid (`crossAxisCount: 3, spacing: 8, childAspectRatio: 1.0`).
    * Each image tile wrapped in `BorderRadius.circular(12)`.
    * If uploaded photos < max allowed (6), the last slot renders as a dashed border tile (`#272A3D`) with a centered coral `+ Add Photo` icon.
  * **Settings Grouping:** Group account actions (Edit Profile, Blocked Users, App Updates, Delete Account) into rounded card sections with standard `16dp` padding and distinct chevron indicators (`#5E6278`).

---

## 3. Implementation Checklist & Verification Gates

1. **Static Analysis:** Zero errors or styling warnings reported by `flutter analyze`.
2. **Layout Adaptability:** Verify visual responsiveness across standard aspect ratios (18:9, 19.5:9, 20:9) on physical Android devices.
3. **Hardware Shield Compatibility:** Confirm that `FLAG_SECURE` window protection functions reliably across updated themes without causing canvas redraw artifacts.