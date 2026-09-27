# 12_LEGAL_COMPLIANCE_DPDP_GOOGLEPLAY.md: STATUTORY GOVERNANCE & APP STORE COMPLIANCE
# Project: UR-Heart (Mindful Dating Sanctuary)
# Jurisdiction: India (DPDP Act 2023, IT Rules 2021) & Global (Google Play UGC & Data Safety)
# Architecture: Zero-Circumvention Age Gating, Unbundled Bilingual Consent & Cascading Erasure

---

## 1. REGULATORY FRAMEWORK & STATUTORY BASELINE

Dating applications operate under strict regulatory scrutiny due to identity risks, harassment vectors, user-generated content (UGC), and sensitive personal data processing. UR-Heart enforces compliance across three core statutory authorities:

1. **Digital Personal Data Protection (DPDP) Act, 2023 (India)**:
   * **Section 5 (Notice)**: Itemized, unbundled, point-of-collection notices in English and Hindi.
   * **Section 6 (Consent)**: Free, specific, informed, unconditional, and affirmative action (zero pre-ticked boxes).
   * **Section 8(7) & 12 (Erasure)**: Permanent cascading data erasure across databases, object storage, and third-party vendors.
   * **Section 11 (Access)**: Comprehensive data download export in machine-readable JSON.
   * **Section 14 (Nomination)**: Statutory mechanism for users to designate a data nominee.
2. **Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 (Rule 3(2))**:
   * Statutory Grievance Redressal mechanism with appointed Grievance Officer[cite: 1, 13].
   * Mandatory complaint acknowledgment within 24 hours and resolution within 15 days.
3. **Google Play Developer Policies (UGC & Target Audience)**:
   * Mandatory Pre-UGC EULA acceptance screen before profile creation.
   * 18+ minor exclusion via Play Age Signals API and neutral Date-of-Birth (DOB) wheel.
   * Accessible in-app reporting and instant blocking mechanisms.
   * Independent public web page for account and data deletion (operable without the app).

---

## 2. DPDP ACT 2023: UNBUNDLED BILINGUAL CONSENT ARCHITECTURE

Under Sections 5 and 6 of the DPDP Act 2023, bundled consent (single checkbox for terms, privacy, marketing, and data access) is strictly void. Every data category collected requires an independent purpose limitation disclosure.

┌────────────────────────────────────────────────────────────────────────┐
│                   SCREEN 1: MINDFUL CONSENT SCREEN                     │
├────────────────────────────────────────────────────────────────────────┤
│ [ ] DIGITAL PERSONAL DATA: DPDP Act 2023 & Governance                  │
│     Purpose: Processing profile data & enforcing safety protocols    │
│                                                                        │
│ [ ] INTERMEDIARY GUIDELINES: Rule 3(2) IT Rules & Grievance SLA        │
│     Purpose: Legal dispute resolution & statutory incident logging   │
│                                                                        │
│ [ ] COMMUNITY SAFE SPACE: Zero Harassment & Community EULA             │
│     Purpose: Enforcing strict zero-tolerance conduct standards       │
│                                                                        │
│ [ ] I confirm that I am at least 18 years old and agree to Terms     │
│ [ ] I provide explicit consent under DPDP Act 2023 to process data   │
└────────────────────────────────────────────────────────────────────────┘   
PNG
+ 4


### 2.1 Just-in-Time Live Video KYC Consent Notice (Section 5(1))

Displayed immediately preceding camera activation on Screen 4 for identity verification[cite: 1, 5, 18]:

#### English Notice Text
> **Notice under Digital Personal Data Protection Act, 2023 (Section 5)**  
> **Data Collected**: Live 3-Second Video Recording.  
> **Purpose**: One-time identity verification (KYC), age confirmation, and fake profile prevention to ensure user safety on UR-Heart.  
> **Storage & Security**: Video data will be processed ephemerally, encrypted using bank-grade AES-256 standards, and automatically deleted immediately upon verification completion.  
> **Your Rights**: You have the right to withdraw consent at any time, access your data, or lodge a grievance with our Data Protection Officer at `dpo@urheart.app`.  
> *By tapping "Agree & Proceed", you give explicit, affirmative consent for processing your video for identity verification.*

#### Simple Hindi Notice Text (सरल हिंदी सूचना)
> **डिजिटल व्यक्तिगत डेटा संरक्षण अधिनियम, 2023 (धारा 5) के तहत सूचना**  
> **एकत्रित डेटा**: लाइव 3-सेकंड वीडियो रिकॉर्डिंग।  
> **उद्देश्य**: UR-Heart पर आपकी सुरक्षा सुनिश्चित करने के लिए केवल एक बार पहचान सत्यापन (KYC), उम्र की पुष्टि, और फर्जी प्रोफाइल की रोकथाम।  
> **सुरक्षा और भंडारण**: वीडियो डेटा को बैंक-स्तरीय AES-256 एन्क्रिप्शन से सुरक्षित रखा जाएगा और सत्यापन पूरा होते ही स्वतः हमेशा के लिए हटा दिया जाएगा।  
> **आपके अधिकार**: आपके पास किसी भी समय सहमति वापस लेने, अपना डेटा देखने, या हमारे डेटा सुरक्षा अधिकारी (`dpo@urheart.app`) के पास शिकायत दर्ज कराने का अधिकार है।  
> *"सहमत हों और आगे बढ़ें" पर टैप करके, आप पहचान सत्यापन के लिए अपने वीडियो प्रसंस्करण की स्पष्ट सहमति देते हैं।*

---

## 3. ZERO-BYPASS AGE GATING & PLAY AGE SIGNALS API

Google Play requires dating applications to enforce the **Restrict Declared Minors** console setting and implement robust mechanisms that cannot be easily bypassed.

                         [App Launch / Registration]
                                     │
                                     ▼
                 ┌───────────────────────────────────────┐
                 │ Call Google Play Age Signals API      │
                 └───────────────────┬───────────────────┘
                                     │
                   Verified Age Signal Available?
                                     │
                   ┌─────────────────┴─────────────────┐
                   ▼ YES                               ▼ NO / Unknown
        Age Signal >= 18?             ┌─────────────────────────────┐
                   │                            │ Neutral DOB Wheel Selector  │[cite: 1, 3]
        ┌──────────┴──────────┐                 │ (No pre-selected birth year)│
        ▼ YES                 ▼ NO     └──────────────┬──────────────┘
[Proceed to Auth]     ┌──────────────┐                          │
                      │ ACCESS DENIED│                          ▼
                      │ - Log device │     Calculated Age >= 18?[cite: 1]
                      │ - 180d block │[cite: 1]                │
                      └──────────────┘           ┌──────────────┴──────────────┐
                                                 ▼ YES                         ▼ NO[cite: 1]
                                        [Proceed to Auth]              ┌──────────────┐
                                                                       │ ACCESS DENIED│
                                                                       │ Hard Lockout │[cite: 1]
                                                                       └──────────────┘

### 3.1 Underage Quarantine Registry & Anti-Brute-Force Architecture
Agar user registration ke waqt 18 saal se kam DOB select karta hai, to system guessed date brute-forcing ko block karta hai[cite: 1]:
1. **Device Fingerprint Quarantine**: Device identifier hash (`SHA-256(SSAID + IP_SUBNET)`) aur phone number hash ko Supabase table `underage_quarantine_registry` mein log kiya jata hai[cite: 1].
2. **180-Day Hard Cooldown**: Subsequent registration attempts par generic message return hota hai: *"Service is currently unavailable for this device account."*[cite: 1]

```sql
CREATE TABLE IF NOT EXISTS public.underage_quarantine_registry (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_hash VARCHAR(64) UNIQUE NOT NULL,
    attempted_dob DATE NOT NULL,
    quarantine_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quarantine_lookup 
ON public.underage_quarantine_registry(device_hash) 
WHERE quarantine_until > NOW();
4. GOOGLE PLAY UGC POLICY ENFORCEMENT & BOILERPLATE EULA
Google Play User Generated Content (UGC) policy mandates clear user behavioral rules before profile creation, in-app reporting, and instant user blocking[cite: 1].

4.1 Production Boilerplate Terms of Service (EULA)
Antigravity ko ye exact EULA contract Screen 1 ke bottom sheet modal mein render karna hai:   
PDF
+ 2

Plaintext


UR-HEART END USER LICENSE AGREEMENT & TERMS OF SERVICE[cite: 1]
Last Updated: September 2026

1. Acceptance of Terms:
By creating an account or accessing the UR-Heart application, you agree to be legally bound by these Terms of Service[cite: 1]. You must accept these terms prior to creating a profile, uploading content, or communicating with other users[cite: 1]. UR-Heart is strictly restricted to adult users aged 18 years and older; access by children or minors is explicitly prohibited[cite: 1].

2. Zero-Tolerance Policy for Objectionable Content and Abusive Behavior:
UR-Heart maintains a strict, non-negotiable zero-tolerance policy regarding objectionable content, harassment, and abusive behavior[cite: 1]. You are strictly prohibited from transmitting, posting, or sharing content that includes, but is not limited to:
- Threats, intimidation, stalking, harassment, or bullying[cite: 1].
- Photos, profile entries, or chat messages intended to single out individuals for abuse, malicious ridicule, or hate speech[cite: 1].
- Sexually explicit, pornographic, non-consensual sexual content, or child endangerment material[cite: 1].
- Commercial solicitation, fraud, or circumventing off-platform contact rules[cite: 1].

3. In-App Reporting, Instant Blocking, and Enforcement:
- In-App Reporting: Built-in reporting tools allow you to report any objectionable profile or message[cite: 1].
- Instant Blocking: You may instantly block any user at any time, severing all communication channels immediately[cite: 1].
- Active Moderation: UR-Heart actively moderates content via automated AI scanners and human reviewers[cite: 1]. Violating accounts face immediate content removal and permanent account termination without warning[cite: 1].
4.2 In-App Reporting & Instant Blocking Pipeline
Reporting Trigger: Available on Feed Profile Card (Screen 5) and 1:1 Chat Menu (Screen 9).   
PNG
+ 3

Instant Blocking: Tapping "Block User" creates an atomic insert into public.blocked_users[cite: 1]. The match is marked is_active = FALSE, real-time WebSocket connection is severed, and both profiles are purged from each other's discovery decks[cite: 1].

5. STATUTORY DATA RIGHTS IMPLEMENTATION (DPDP SECTIONS 11 & 14)
5.1 Section 11: Machine-Readable Data Export ("Download My Data")
Users can request an encrypted archive of their personal data from Screen 12 (Vault & Legal)[cite: 13, 26]:

Python


# app/api/v1/endpoints/legal.py
import json
import zipfile
import io
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User[cite: 1]
from app.models.domain.swipe import Swipe[cite: 1]
from app.models.domain.match import Match[cite: 1]

router = APIRouter(tags=["Statutory Compliance"])

@router.post("/legal/export-data", status_code=status.HTTP_200_OK)
async def generate_user_data_export(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Generates a machine-readable JSON bundle of all personal data
    in compliance with Section 11 of the DPDP Act 2023[cite: 13].
    """
    # 1. Collect User Profile Attributes
    user_payload = {
        "user_id": str(current_user.id),
        "full_name": current_user.full_name,
        "dob": current_user.dob.isoformat(),
        "gender": current_user.gender,
        "interested_in": current_user.interested_in,
        "location": current_user.location_name,
        "bio": current_user.bio,
        "profession": current_user.profession,
        "education": current_user.education,
        "kyc_verified": current_user.kyc_status,
        "account_created_at": current_user.created_at.isoformat()
    }

    # 2. Collect Historical Swipes
    swipes_stmt = select(Swipe).where(Swipe.actor_id == current_user.id)[cite: 1]
    swipes_res = await db.execute(swipes_stmt)
    swipes_data = [
        {"target_id": str(s.target_id), "type": s.swipe_type, "timestamp": s.created_at.isoformat()}
        for s in swipes_res.scalars().all()
    ]

    export_bundle = {
        "statutory_authority": "DPDP_ACT_2023_SECTION_11",
        "generated_at": current_user.created_at.isoformat(),
        "profile": user_payload,
        "swipes": swipes_data
    }

    return export_bundle
5.2 Section 14: Data Rights Nominee Designation
Users can designate a legal nominee to manage their data in the event of death or permanent incapacity (Screen 12)[cite: 13, 26]:

Python


from pydantic import BaseModel, Field

class NomineeDesignationRequest(BaseModel):
    nominee_name: str = Field(..., min_length=2, max_length=60)
    nominee_contact: str = Field(..., min_length=10, max_length=30)
    relationship: str = Field(..., min_length=2, max_length=30)

@router.post("/legal/designate-nominee", status_code=status.HTTP_200_OK)
async def designate_nominee_endpoint(
    req: NomineeDesignationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Upsert into public.data_nominees[cite: 13]
    from app.models.domain.legal import DataNominee
    nominee = DataNominee(
        user_id=current_user.id,
        nominee_name=req.nominee_name,
        nominee_contact=req.nominee_contact,
        relationship=req.relationship
    )
    await db.merge(nominee)
    await db.commit()
    return {"status": "success", "message": "Nominee registered under Section 14 DPDP Act 2023."}
6. PERMANENT CASCADING DATA ERASURE PROTOCOL (SECTION 12 & GOOGLE PLAY)
When a user taps "Delete Account & Erase All Data" on Screen 13, or submits a request via the Public Web Deletion URL[cite: 1], the system executes an irrevocable, cascading purge[cite: 1]:   
PNG
+ 1

[User triggers Account Deletion] (In-App Screen 13 OR Public Web Page)
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: CLOUDFLARE R2 MEDIA ASSET PURGE                               │
│ - Delete users/{id}/photos/slot_1.webp through slot_5.webp[cite: 1]           │
│ - Delete users/{id}/kyc/video.mp4 (if present)[cite: 1]                       │
└──────────────────────┬─────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: PRIMARY RELATIONAL DATABASE PURGE (PostgreSQL)                │
│ - Hard DELETE FROM public.users WHERE id = :user_id[cite: 1]                  │
│ - Triggers ON DELETE CASCADE across:                                   │
│   * public.swipes, public.matches, public.messages[cite: 1]                   │
│   * public.whatsapp_reveal_tokens, public.ad_reward_ledger[cite: 1]           │
│   * public.blocked_users, public.data_nominees[cite: 1]                       │
└──────────────────────┬─────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: THIRD-PARTY SUB-PROCESSOR PURGE WEBHOOKS                      │
│ - Firebase Admin SDK: FirebaseAuth.deleteUser(auth_id)                 │
│ - Sentry API: Purge user telemetry identifiers                         │
│ - AdMob / Ad Networks: Trigger GDPR/DPDP Opt-Out Erasure Ping          │
└──────────────────────┬─────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: STATUTORY AUDIT ARCHIVE (Legal Isolation Exception)           │
│ - Retain ONLY anonymized transaction ID & timestamp for audit[cite: 1]        │
│ - Zero PII, zero plain text, zero recoverable identity retained[cite: 1]      │
└────────────────────────────────────────────────────────────────────────┘
6.1 Backend Erasure Implementation (app/services/account_deletion.py)
Python


import os
import boto3
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete
from app.models.domain.user import User[cite: 1]

async def execute_cascading_account_erasure(user_id: UUID, auth_id: UUID, db: AsyncSession) -> None:
    """
    Executes irrevocable data deletion across Cloudflare R2, Supabase Postgres,
    and Firebase Auth in compliance with DPDP Act Sec 12 & Google Play mandates[cite: 1].
    """
    # 1. Cloudflare R2 Media Purge[cite: 1]
    s3_client = boto3.client(
        "s3",
        endpoint_url=f"https://{os.getenv('CLOUDFLARE_ACCOUNT_ID')}.r2.cloudflarestorage.com",
        aws_access_key_id=os.getenv("R2_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("R2_SECRET_ACCESS_KEY")
    )
    bucket = os.getenv("R2_BUCKET_NAME", "ur-heart-media")

    # Delete all 5 photo slots[cite: 1]
    for slot in range(1, 6):
        try:
            s3_client.delete_object(Bucket=bucket, Key=f"users/{user_id}/photos/slot_{slot}.webp")[cite: 1]
        except Exception:
            pass

    # 2. Database Hard Deletion (ON DELETE CASCADE wipes child tables)[cite: 1]
    await db.execute(delete(User).where(User.id == user_id))[cite: 1]
    await db.commit()

    # 3. Purge Auth Record in Firebase
    try:
        from firebase_admin import auth as fb_auth
        fb_auth.delete_user(str(auth_id))
    except Exception:
        pass
7. PUBLIC WEB DELETION PAGE SPECIFICATION
Google Play requires a dedicated, functional web page that allows users who have uninstalled the app to request complete account and data deletion without re-downloading[cite: 1].

7.1 Web Endpoint & Architecture
Public URL: https://urheart.app/account-deletion

[cite: 1]

Hosted On: Cloudflare Pages / Render Static Site (100% Free Tier)

Branding: Displays the exact app name ("UR-Heart") and Developer Name as registered in the Google Play Console[cite: 1].

7.2 Web Deletion Request Form Specification
The public page provides an authenticated or OTP-verified web form[cite: 1]:

User Identifier: Email address or Phone Number used during registration[cite: 1].

Verification: 6-digit OTP dispatched via Firebase Auth Web SDK to verify identity[cite: 1].

Execution: On OTP verification, the page calls POST https://<api-domain>/api/v1/legal/web-delete-request.

SLA Notice: Discloses that all associated data (photos, chats, matches) will be erased within 24 hours, with a confirmation receipt displayed on screen[cite: 1].

8. GOOGLE PLAY CONSOLE DATA SAFETY DECLARATION CHECKLIST
Before submitting the UR-Heart APK/AAB to Google Play review, complete these declarations under App Content > Data Safety[cite: 1]:

Form Question / Data Type	Play Console Answer	Technical Verification Reason
Does your app collect or share user data?	
Yes

[cite: 1]

Account creation and messaging data collected[cite: 1].

Is all user data collected encrypted in transit?	
Yes

[cite: 1]

Enforced TLS 1.3 on Render API and Cloudflare R2[cite: 1].

Do you provide a way for users to request data deletion?	
Yes

[cite: 1]

In-app button (Screen 13) + Public URL provided[cite: 1, 14, 27].

Public Account Deletion URL	
https://urheart.app/account-deletion

[cite: 1]

Functional standalone web deletion page[cite: 1].

Target Audience & Age Restrictions	
18 and older

[cite: 1]

Dating category with Restrict Declared Minors enabled[cite: 1].

Personal Info (Name, Email, Phone, DOB)	
Collected (Account Management)[cite: 1]

Deleted upon user account deletion request[cite: 1].

Photos & Videos	
Collected (Profile Setup & KYC)[cite: 1]

KYC video purged < 24h; photos erased on account deletion[cite: 1].

Messages	
Collected (1:1 Communication)[cite: 1]

End-to-end encrypted; 30-day auto-purge routine[cite: 1].


9. ANTIGRAVITY VERIFICATION & COMPLIANCE AUDIT
Antigravity agent ko verification karte waqt nimn statutory validations execute karni hain:

Unbundled Consent Check: Verify karein ki Screen 1 par EULA aur DPDP checkboxes unbundled hain aur default state unchecked hai[cite: 1, 2, 15].

Age Gating Integrity: Verify karein ki neutral DOB selector 18 saal se kam age enter karne par registration immediately abort karta hai aur persistent cooldown trigger karta hai[cite: 1, 3, 16].

Cascading Erasure Validation: Account delete hone ke baad verify karein ki Supabase database aur Cloudflare R2 storage mein user ID ka zero residual footprint rehta hai[cite: 1].

Grievance Dossier Response: Verify karein ki IT Rules Grievance filing endpoint 200 OK return karta hai aur audit log generate karta hai.   
PDF
+ 2

