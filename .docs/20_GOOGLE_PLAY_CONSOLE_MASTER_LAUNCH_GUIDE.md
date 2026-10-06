# 20. Google Play Console Master Launch & Account Setup Guide

## Executive Overview
This guide provides an exhaustive, section-by-section roadmap for setting up your Google Play Developer Account, declaring compliance policies, filling out every mandatory Play Console form, and uploading your production App Bundle (`.aab`) for **UR-Heart: Mindful Dating** (`com.urheart.app`).

---

## 1. Google Play Developer Account Creation

### 1.1 Account Type: Personal vs. Organization
Google offers two types of developer accounts ($25 one-time registration fee):

| Attribute | Personal Account | Organization Account (Recommended if possible) |
| :--- | :--- | :--- |
| **Requirements** | Govt ID (Passport/Driving License/Aadhaar/PAN) + International Debit/Credit Card | D-U-N-S Number (Dun & Bradstreet) + Official Business Docs |
| **Testing Requirement** | **Mandatory 20 Testers for 14 Days** (since Nov 2023) | **Direct Production Release** (Zero 20-tester requirement) |
| **Display Name** | Your Legal Name | Company Name (e.g., Asiverticals) |

> [!TIP]
> **If choosing Personal Account**: You will need 20 friends/testers to opt into a "Closed Testing Track" for 14 continuous days before Google unlocks the "Publish to Production" button. This is standard for all new personal accounts since late 2023.

### 1.2 Step-by-Step Account Registration
1. Go to [play.google.com/console/signup](https://play.google.com/console/signup).
2. Sign in with your dedicated Google Account (`asiverticals@gmail.com` or your primary founder email).
3. Select **Account Type**: Choose *Personal* or *Organization*.
4. Enter Developer Details:
   - **Developer Name**: `Asiverticals` or `Anubhav Singh` (This is displayed to public on Play Store).
   - **Contact Email**: `asiverticals@gmail.com` (Must verify via 6-digit OTP).
   - **Contact Phone Number**: Enter your Indian mobile number (+91) with SMS OTP verification.
   - **Website**: `https://urheart.asiverticals.me`.
5. **Pay $25 Registration Fee**: Use a Visa/Mastercard/Amex card with **International Transactions Enabled** in your banking app.
6. **Identity Verification**: Upload a clear photo of your Indian Driving License, Passport, or Voter ID. Verification usually takes 2 to 24 hours.

---

## 2. App Creation & Store Identity

Once inside Play Console, click **"Create App"** (Blue button top-right):

| Field Name | Exact Value to Enter | Notes / Best Practice |
| :--- | :--- | :--- |
| **App Name** | `UR-Heart: Mindful Dating` | Max 30 characters. Clean and brand-focused. |
| **Default Language** | `English (United States)` or `English (India)` | Can add Hindi translations later. |
| **App or Game** | `App` | Radio button. |
| **Free or Paid** | `Free` | App is free to download (with rewarded ads & in-app purchases). |
| **Declarations** | Check all mandatory agreement boxes | Developer Program Policies & US Export Laws. |

Click **Create App**.

---

## 3. Store Listing & Metadata Copy

Navigate to **Grow $\rightarrow$ Store Presence $\rightarrow$ Main Store Listing**:

### 3.1 App Details Text
* **App Name (30 chars)**: `UR-Heart: Mindful Dating`
* **Short Description (80 chars)**:  
  `Mindful connections, intentional dialogues, and dating without swipe fatigue.`
* **Full Description (Max 4000 chars)**:  
```text
Welcome to UR-Heart — India's premier Mindful Dating Sanctuary.

Tired of endless, mindless swiping, catfishing, and conversations that lead nowhere? UR-Heart is intentionally designed to bring depth, mutual respect, and authentic chemistry back to dating.

✨ WHY UR-HEART IS DIFFERENT:

1. MINDFUL DAILY PACING (10 PASSES/DAY)
Say goodbye to dating app burnout. We limit daily passes to 10 meaningful candidates, encouraging thoughtful consideration rather than mindless dopamine browsing.

2. EVA — YOUR 24/7 MINDFUL DATING COMPANION
Never struggle with awkward first messages. Eva provides mindful icebreakers, bio polish, and conversational guidance with zero creepy AI generation.

3. 100% TEXT-ONLY RESPECTFUL CHAT
To protect our users from unsolicited explicit media, dialogues are strictly text-only. Screenshot blocking (FLAG_SECURE) ensures your private words remain private.

4. REAL AI KYC & VERIFICATION
Every sanctuary member undergoes multi-step identity verification. No bots, no stock photos, and no deceptive profiles.

5. ZERO COMPULSIVE ADVERTISING
Enjoy clean, unobtrusive experiences. Watch optional rewarded reflections only when you choose to replenish your mindful passes.

6. SOVEREIGN PRIVACY & DPDP COMPLIANCE
Full compliance with Digital Personal Data Protection (DPDP) Act 2023. Encrypted end-to-end with single-tap irrevocable account incineration.

Join a sanctuary where hearts connect with intentionality.
Created with mindful care by Asiverticals.
```

### 3.2 Graphic Assets Requirements
* **App Icon**: `512 x 512 px`, 32-bit PNG, max 1MB. (Located in `assets/icon/app_icon.png`).
* **Feature Graphic**: `1024 x 500 px`, PNG or JPEG, max 15MB. (A banner with your sanctuary logo and calming coral/pine aesthetic).
* **Phone Screenshots**: Minimum 2, recommended 4-6 screenshots:
  - 1: Mindful Discovery Deck (Candidate Card).
  - 2: Eva AI Dialogue Coach.
  - 3: 1:1 Encrypted Chat Screen.
  - 4: Atmosphere Theme Picker (Light & Dark Sanctuary).

---

## 4. Mandatory Policy Declarations (App Content Section)

In left sidebar, go to **Policy $\rightarrow$ App Content**. Complete each task:

### 4.1 Privacy Policy
* **URL**: `https://urheart.asiverticals.me/privacy`
* *Note: Live, DPDP Act 2023 compliant, hosted directly by our backend.*

### 4.2 App Access (Reviewer Credentials)
Google reviewers test the app from their Mountain View/Dublin offices. Because UR-Heart requires login:
* Select: **"All or some functionality is restricted"**
* Click **Add instructions**:
  - **Title**: `Reviewer Test Account Access`
  - **Account name / Username**: `reviewer@urheart.app` (or test phone number)
  - **Password / OTP**: `123456`
  - **Explanation**:  
    `Please use Google Sign-In or input reviewer@urheart.app on the sign-in screen. The account is pre-approved for KYC and ready with a completed profile to inspect the discovery feed and chat without delay.`

### 4.3 Ads Declaration
* Select: **"Yes, my app contains ads"**
* *(We use Google AdMob rewarded passes).*

### 4.4 Content Rating (IARC Questionnaire)
Click **Start Questionnaire**:
1. **Email address**: `asiverticals@gmail.com`
2. **Category**: Select **"Social, Communication, or Dating"** (or *Utility, Productivity, Communication, or Other* $\rightarrow$ *Social networking*).
3. **Questionnaire answers**:
   - Violence: **No**
   - Sexuality / Nudity: **No**
   - Offensive Language: **No**
   - Controlled Substances: **No**
   - Does app allow users to interact or exchange content: **Yes**
   - Does app share physical location: **Yes** (Approximate/Coarse location for distance).
   - Does app allow purchasing digital goods: **Yes** (Sovereign Passes).
4. **Resulting Rating**: Will assign **18+ / Mature (PEGI 18 / ESRB Mature)**. This is normal and mandatory for all dating apps.

### 4.5 Target Audience and Content
* Target Age Groups: Select **ONLY "18 and over"** (Leave all boxes below 18 unchecked).
* Appeal to children: Select **"No"**.

### 4.6 News App
* Select: **"No"**.

### 4.7 COVID-19 Contact Tracing
* Select: **"My app is not a publicly available COVID-19 contact tracing or status app"**.

### 4.8 Financial Features
* Select: **"My app does not provide any financial features"** (or declare In-App Billing).

### 4.9 Advertising ID (AAID)
* Select: **"Yes, my app uses Advertising ID"**
* Check: **"Advertising or marketing"** and **"Analytics"** (Required for AdMob SDK).

---

## 5. Data Safety Form Blueprint (Crucial & Exact Answers)

Under **Policy $\rightarrow$ App Content $\rightarrow$ Data Safety**:

1. **Does your app collect or share any of the required user data types?**  
   $\rightarrow$ **Yes**
2. **Is all user data collected by your app encrypted in transit?**  
   $\rightarrow$ **Yes** (All HTTPS/TLS 1.3 + WSS).
3. **Do you provide a way for users to request that their data be deleted?**  
   $\rightarrow$ **Yes**
4. **Add deletion link**:  
   $\rightarrow$ `https://urheart.asiverticals.me/delete-account`

### Exact Data Type Breakdown:
* **Location**:
  - *Approximate Location*: Collected: **Yes** | Shared: **No** | Ephemeral: **No** | Required: **Yes** | Purpose: **App functionality**.
  - *Precise Location*: Collected: **Yes** | Shared: **No** | Purpose: **App functionality**.
* **Personal Info**:
  - *Name*: Collected: **Yes** | Shared: **No** | Purpose: **App functionality, Account management**.
  - *Email Address*: Collected: **Yes** | Shared: **No** | Purpose: **Account management**.
  - *User IDs*: Collected: **Yes** | Shared: **No** | Purpose: **App functionality**.
* **Photos & Videos**:
  - *Photos*: Collected: **Yes** | Shared: **No** | Purpose: **App functionality (Profile photos)**.
  - *Videos*: Collected: **Yes** (3s KYC live check) | Shared: **No** | Ephemeral: **Yes** (purged after verification).
* **Messages**:
  - *In-app messages*: Collected: **Yes** | Shared: **No** | Purpose: **App functionality**.
* **App Info & Performance**:
  - *Crash logs & Diagnostics*: Collected: **Yes** | Shared: **No** | Purpose: **Analytics & Developer Diagnostics (Sentry)**.
* **Device or Other IDs**:
  - *Device ID*: Collected: **Yes** | Shared: **No** | Purpose: **Push Notifications (FCM) & Anti-Fraud**.

---

## 6. Production Keystore & Release AAB Build

### 6.1 Generate Release Keystore
Run this one command in your Windows terminal:
```powershell
keytool -genkey -v -keystore c:\Project\UR-Heart\android\app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias urheart_production_key
```
*(Enter a memorable password like `UrHeart@2026!`, answer your name and org as Asiverticals).*

### 6.2 Configure `key.properties`
Create `c:\Project\UR-Heart\android\key.properties`:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEYSTORE_PASSWORD
keyAlias=urheart_production_key
storeFile=upload-keystore.jks
```

### 6.3 Build the Production App Bundle (`.aab`)
```powershell
flutter build appbundle --release
```
Your compiled bundle will be saved at:
`c:\Project\UR-Heart\build\app\outputs\bundle\release\app-release.aab`

---

## 7. Closed Testing & The 20-Testers Strategy

If your Google Play account is a **Personal Account**:
1. Go to **Testing $\rightarrow$ Closed testing**.
2. Create an **Alpha Track**.
3. Create an **Email List** of 20 friends, colleagues, or student community members.
4. Upload `app-release.aab` and click **Start Rollout to Closed Testing**.
5. Copy the **"Join on the web"** / **"Join on Android"** link and share it with your 20 testers.
6. **Important**: Testers must keep the app installed on their phones for **14 consecutive days**.
7. On Day 15, an option in Play Console **"Apply for Production Access"** lights up $\rightarrow$ Submit brief answers $\rightarrow$ Production is unlocked within 48 hours!
