# Legal, DPDP Act 2023 & Intermediary Safe Harbor Specification

**Document Identifier:** URH-LEG-002  
**Parent Corporate Entity:** ASI Verticals  
**Application Platform:** UR-Heart (Urban and Rural Heart)  
**Governing Jurisdiction:** Lucknow Bench of the High Court of Judicature at Allahabad, Uttar Pradesh, India  
**Applicable Legal Frameworks:**  
1. Information Technology Act, 2000 (Section 79 — Intermediary Protection)  
2. IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 (as amended 2023)  
3. Digital Personal Data Protection (DPDP) Act, 2023 (Act No. 22 of 2023)  
4. Bharatiya Nagarik Suraksha Sanhita (BNSS), 2023 (Section 94 — Summons to produce document/data)  
5. Bharatiya Sakshya Adhiniyam (BSA), 2023 (Section 63 — Admissibility of Electronic Evidence)  
6. Indian Computer Emergency Response Team (CERT-In) Cyber Security Directions (No. 20(3)/2022-CERT-In)

---

## 1. Statutory Exemption & Intermediary Safe Harbor (Section 79, IT Act 2000)

### 1.1. Legal Classification
Under Section 2(1)(w) of the Information Technology Act, 2000, **UR-Heart** (and its holding entity **ASI Verticals**) operates strictly as a **Social Media Intermediary (SMI)**. The platform merely facilitates real-time matchmaking and encrypted transmission of user-generated communications between third-party users without initiating, modifying, or selecting the transmitted content.

### 1.2. The Safe Harbor Shield Mandate
To maintain absolute legal immunity from criminal prosecution (under Bharatiya Nyaya Sanhita, 2023 / Indian Penal Code) for unlawful acts committed by users (such as harassment, extortion, defamation, or distribution of non-consensual media), ASI Verticals must strictly fulfill the **Due Diligence Obligations** prescribed under Rule 3 of the IT Rules, 2021.

### 1.3. Mandatory User Rules & EULA Declarations (Rule 3(1)(b))
The onboarding workflow must enforce an un-skippable, affirmative agreement where users acknowledge that they shall not host, display, upload, modify, publish, transmit, store, update, or share any information that:
1. Belongs to another person and to which the user does not have any right.
2. Is obscene, pornographic, pedophilic, invasive of another's privacy, including bodily privacy, insulting or harassing on the basis of gender, racially or ethnically objectionable, or promotes money laundering or gambling.
3. Harmful to child or minor in any manner whatsoever.
4. Infringes any patent, trademark, copyright, or other proprietary rights.
5. Deceives or misleads the addressee about the origin of the message (impersonation) or knowingly communicates any misinformation.
6. Threatens the unity, integrity, defense, security, or sovereignty of India, friendly relations with foreign States, or public order.

---

## 2. Statutory Resident Grievance Redressal Mechanism

Under Rule 3(2) of the IT Rules, 2021, ASI Verticals must establish a functional, transparent grievance mechanism headed by an appointed Indian Resident Officer.

### 2.1. Grievance Officer Statutory Details
This information must be permanently accessible inside the app under:  
`Settings -> Legal, Privacy & Grievance Redressal` and hosted publicly at `https://asiverticals.com/ur-heart/grievance`:

```text
RESIDENT GRIEVANCE OFFICER (RGO)
Name: Grievance Officer, UR-Heart
Corporate Entity: ASI Verticals
Registered Office Address: Lucknow, Uttar Pradesh, PIN: 226001, India
Official Grievance Email: grievance@asiverticals.com
Response SLA: Acknowledgment within 24 hours; Statutory disposal within 15 days
Urgent Takedown Escalation (Rule 3(2)(b)): 24-hour statutory disposal
2.2. Statutory Takedown Service Level Agreements (SLAs)Complaint ClassificationStatutory ProvisionLegal SLA WindowMandatory Backend ActionNon-Consensual Intimate Imagery (NCII) / Nudity / DeepfakesRule 3(2)(b), IT Rules 2021Strictly within 24 Hours of receiptImmediate automated account freeze, storage block, and media unlinkingImpersonation / Fake Profile CreationRule 3(2)(b), IT Rules 2021Strictly within 24 HoursProfile visibility toggled is_banned = TRUE, KYC investigation triggeredHarassment, Threats, ExtortionRule 3(2)(a), IT Rules 2021Acknowledge in 24h, dispose in 15 DaysChat log freeze, algorithmic demotion, or permanent banLaw Enforcement / Court Order TakedownRule 3(1)(d), IT Rules 2021Strictly within 36 HoursComplete data preservation and immediate compliance execution3. Digital Personal Data Protection (DPDP) Act, 2023 ComplianceUnder the DPDP Act 2023, ASI Verticals is designated as a Data Fiduciary, and the user is a Data Principal. Non-compliance carries penalties up to ₹250 Crore (Schedule 1, DPDP Act).3.1. Granular, Unbundled Consent Architecture (Sections 5 & 6)Consent cannot be bundled into a generic privacy policy checkbox. Separate affirmative acts (toggle/click) are legally mandated for each distinct purpose:WhatsApp Mobile Number: Dedicated toggle strictly for account recovery, OTP, and consented mutual revelation. It cannot be sold or used for unsolicited external marketing.5 Profile Photos: Collected solely for matchmaking presentation; processed through local/ephemeral OCR text verification.Live 5-Second Video/Audio KYC: Biometric/identity verification data requiring point-of-collection just-in-time notice.3.2. Mandatory Bilingual Consent Notice (Section 5(3))Before camera and microphone permissions are triggered for the 5-second Live KYC video, the application must display the following exact bilingual card:Plaintext================================================================================
ENGLISH CONSENT NOTICE (DPDP ACT 2023, SECTION 5)
================================================================================
Data Collected: 5-Second Live Video and Audio Stream.
Purpose: One-time identity verification, age validation (18+), and prevention of 
fake profiles or automated bots to maintain user safety on UR-Heart.
Processing & Security: Encrypted using AES-256 at rest. This video stream will 
be permanently purged from storage within 24 to 48 hours of verification approval.
Data Principal Rights: You reserve the statutory right to withdraw consent, request 
summary of personal data, or register a grievance with our Data Protection Officer 
at dpo@asiverticals.com or the Data Protection Board of India.
By tapping "Agree & Proceed", you provide affirmative, unambiguous consent for 
processing your recording for identity validation.

================================================================================
HINDI CONSENT NOTICE (सरल हिंदी सूचना - धारा 5, DPDP अधिनियम 2023)
================================================================================
एकत्रित डेटा: 5-सेकंड का लाइव वीडियो और ऑडियो स्ट्रीम।
उद्देश्य: UR-Heart पर उपयोगकर्ताओं की सुरक्षा सुनिश्चित करने के लिए केवल एक बार 
पहचान सत्यापन, आयु पुष्टि (18+), और फर्जी या नकली प्रोफाइल की रोकथाम।
सुरक्षा व भंडारण: डेटा बैंक-स्तरीय AES-256 एन्क्रिप्शन द्वारा सुरक्षित रहेगा। सत्यापन 
सफल होने के 24 से 48 घंटे के भीतर यह वीडियो हमेशा के लिए मिटा दिया जाएगा।
आपके वैधानिक अधिकार: आपको किसी भी समय सहमति वापस लेने, अपने डेटा का विवरण मांगने, 
या हमारे डेटा सुरक्षा अधिकारी (dpo@asiverticals.com) अथवा भारतीय डेटा संरक्षण बोर्ड 
के पास शिकायत दर्ज करने का कानूनी अधिकार है।
"सहमत हों और आगे बढ़ें" पर टैप करके, आप सत्यापन के लिए अपने वीडियो प्रसंस्करण की 
स्पष्ट और स्वैच्छिक सहमति देते हैं।
================================================================================
3.3. Video KYC Auto-Purge Protocol (Data Minimization - Section 8(7))To avoid maintaining high-liability biometric vaults:Video KYC files are saved to Supabase Storage in an isolated bucket: /kyc_temp/{user_id}_kyc.mp4.Once the verification agent or automated classifier validates human liveness and match with profile photos:Column public.users.kyc_status is updated to TRUE.Column public.users.kyc_verified_at stores the current timestamp.Column public.users.kyc_document_sha256 stores an irreversible SHA-256 hash of the video file (as immutable forensic proof of verification).The physical MP4 video file is immediately and irreversibly deleted from storage.Maximum retention ceiling for unprocessed files in /kyc_temp/ is 48 hours via automated lifecycle rule.4. Reconciling 30-Day Chat Purge with CERT-In 180-Day MandateA common legal paradox for Indian tech platforms is:DPDP Act 2023: Demands data minimization and rapid deletion of personal chats.CERT-In Directions (April 2022) & IT Rules (Rule 3(1)(h)): Demands preserving user activity and access logs for 180 days for cyber-incident forensics.4.1. The Legal Separation ArchitectureUR-Heart resolves this through strict data plane separation:Communication Plane (Private Chats):Encrypted user messages (public.messages) and pass swipes (public.swipes) are hard-deleted after 30 days via PostgreSQL background cleanup cron. This protects user privacy and stays within the 500 MB database free-tier ceiling.Forensic Audit Plane (Access Metadata):No chat content is stored here. It records strictly technical transport metadata (IP address, port, timestamp, user UUID, action type) inside public.legal_audit_logs. This metadata is mathematically compact (~60 bytes per record) and is retained for exactly 180 days before automated rotation.5. Law Enforcement Agency (LEA) Inquiry Handling SOPWhen local police stations, Cyber Crime Cells, or State CID issue notices under Section 94 BNSS, 2023 (formerly Section 91 CrPC) or Section 69 IT Act:5.1. Verification ProtocolNotices must be addressed to parent entity ASI Verticals via official police domain emails (*.gov.in, *.nic.in, *police.gov.in) or physical letter signed by an officer not below the rank of Sub-Inspector.Notices received via private Gmail/Yahoo accounts must be replied to with a standard request for official departmental dispatch before records are released.5.2. Lawful Disclosure PackageASI Verticals provides an automated export package containing:Account registration metadata (Phone number, WhatsApp number, Email, Firebase UID).Account creation timestamp, last known IP address, and device model.180-day network access records from public.legal_audit_logs.Status of KYC verification and SHA-256 verification hash.Active or deleted chat history (if within the 30-day retention window).5.3. Electronic Evidence Certificate (Section 63, BSA 2023)To ensure admissibility in Indian criminal trials, all digital exports must be accompanied by an automated Certificate under Section 63 of Bharatiya Sakshya Adhiniyam, 2023 (formerly Section 65B of Indian Evidence Act), signed by the authorized systems in-charge of ASI Verticals, confirming cryptographic hash integrity and server operating conditions.6. Zero-Tolerance CSAM & Non-Consensual Sexual Imagery ProtocolUnder Section 67B of the IT Act and the Protection of Children from Sexual Offences (POCSO) Act:Instant Account Termination: Any user account transmitting, uploading, or attempting to distribute child sexual abuse material (CSAM) or non-consensual intimate imagery (NCII) is placed in an immediate hard-locked freeze state (is_banned = TRUE).Evidence Preservation: The offending payload, user IP, device hash, and phone number are frozen in an encrypted quarantine table (public.quarantine_evidence) for 180 days.Mandatory Reporting: Automated notification is submitted to the National Cyber Crime Reporting Portal (cybercrime.gov.in) and National Center for Missing & Exploited Children (NCMEC) via API integration.7. Production Database Schema: Legal, Audit & Grievance TablesThe following DDL must be deployed into Supabase to maintain full legal compliance:SQL-- =============================================================================
-- LEGAL COMPLIANCE & FORENSIC AUDIT DDL FOR UR-HEART (ASI VERTICALS)
-- =============================================================================

-- 1. GRIEVANCE TICKETS TABLE (Rule 3(2) IT Rules 2021 Compliance)
CREATE TABLE IF NOT EXISTS public.grievance_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(32) UNIQUE NOT NULL,
    complainant_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    complainant_email VARCHAR(255) NOT NULL,
    complainant_phone VARCHAR(20) DEFAULT NULL,
    reported_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    category VARCHAR(50) NOT NULL CHECK (
        category IN ('ncii_nudity', 'impersonation', 'harassment', 'underage', 'fraud_scam', 'other')
    ),
    incident_description TEXT NOT NULL,
    evidence_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_urgent_24h_sla BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'received' CHECK (
        status IN ('received', 'acknowledged', 'under_investigation', 'resolved', 'rejected')
    ),
    resolution_notes TEXT DEFAULT NULL,
    acknowledged_at TIMESTAMPTZ DEFAULT NULL,
    resolved_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_grievance_status ON public.grievance_tickets(status);
CREATE INDEX idx_grievance_24h_sla ON public.grievance_tickets(is_urgent_24h_sla) WHERE status != 'resolved';

-- 2. STATUTORY LEGAL AUDIT LOGS (CERT-In 180-Day Directive Compliance)
-- Note: Contains strictly technical access metadata, zero message payloads.
CREATE TABLE IF NOT EXISTS public.legal_audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL, -- e.g., 'AUTH_LOGIN', 'KYC_SUBMIT', 'WA_REVEAL_UNLOCK', 'ACCOUNT_PURGE'
    ip_address INET NOT NULL,
    client_port INT4 DEFAULT NULL,
    user_agent TEXT NOT NULL,
    installation_uuid VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial index for rapid querying by law enforcement investigators
CREATE INDEX idx_audit_logs_user ON public.legal_audit_logs(user_id);
CREATE INDEX idx_audit_logs_ip ON public.legal_audit_logs(ip_address);
CREATE INDEX idx_audit_logs_created ON public.legal_audit_logs(created_at);

-- 3. CONSENT AUDIT TRAIL TABLE (Sections 5 & 6 DPDP Act 2023)
CREATE TABLE IF NOT EXISTS public.consent_records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_purpose VARCHAR(50) NOT NULL, -- 'VIDEO_KYC_BIOMETRIC', 'WHATSAPP_DATA_SHARE', 'TERMS_EULA'
    consent_given BOOLEAN NOT NULL DEFAULT TRUE,
    consent_notice_version VARCHAR(20) NOT NULL, -- 'v1.0-2026-SEP'
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    withdrawn_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consent_user ON public.consent_records(user_id);

-- 4. AUTOMATED CERT-In 180-DAY AUDIT PURGE CRON
-- Hard-purges access logs older than 180 days to maintain free-tier database limits
CREATE OR REPLACE FUNCTION purge_cert_in_logs_after_180_days()
RETURNS void AS $$
BEGIN
    DELETE FROM public.legal_audit_logs
    WHERE created_at < NOW() - INTERVAL '180 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
8. Backend Legal Protection Services (FastAPI Microservice)The backend microservice provides an immutable audit interceptor and automated 24-hour grievance prioritization logic:8.1. Audit Logging Interceptor (app/core/legal_audit.py)Pythonfrom fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.domain.legal_audit import LegalAuditLog
from uuid import UUID
from typing import Optional

async def record_legal_audit_event(
    request: Request,
    action_type: str,
    user_id: Optional[UUID],
    db: AsyncSession
) -> None:
    """
    Statutory audit log function fulfilling CERT-In directions.
    Extracts transport metadata and persists to legal_audit_logs table.
    """
    client_ip = request.client.host if request.client else "127.0.0.1"
    client_port = request.client.port if request.client else 0
    user_agent = request.headers.get("User-Agent", "Unknown-Client")
    installation_uuid = request.headers.get("X-Installation-UUID", "UNSPECIFIED")

    audit_entry = LegalAuditLog(
        user_id=user_id,
        action_type=action_type,
        ip_address=client_ip,
        client_port=client_port,
        user_agent=user_agent,
        installation_uuid=installation_uuid
    )
    db.add(audit_entry)
    await db.commit()
8.2. Grievance Router with Automated 24h NCII Flagging (app/api/v1/endpoints/grievance.py)Pythonimport secrets
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.models.domain.grievance import GrievanceTicket
from app.core.legal_audit import record_legal_audit_event

router = APIRouter()

class GrievanceCreateRequest(BaseModel):
    complainant_email: EmailStr
    complainant_phone: str = None
    reported_user_id: str = None
    category: str # 'ncii_nudity', 'impersonation', 'harassment', 'underage', 'fraud_scam', 'other'
    incident_description: str
    evidence_urls: list[str] = []

@router.post("/api/v1/legal/submit-grievance", status_code=status.HTTP_201_CREATED)
async def submit_grievance_ticket(
    req: GrievanceCreateRequest,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    # Rule 3(2)(b) Priority Evaluation
    # NCII, Nudity, and Impersonation complaints require strict 24-hour statutory disposal
    is_urgent = req.category in ('ncii_nudity', 'impersonation')
    
    # Generate unique statutory tracking ticket
    ticket_no = f"URH-{datetime.utcnow().strftime('%Y%m%d')}-{secrets.token_hex(3).upper()}"
    
    ticket = GrievanceTicket(
        ticket_number=ticket_no,
        complainant_email=req.complainant_email,
        complainant_phone=req.complainant_phone,
        reported_user_id=req.reported_user_id,
        category=req.category,
        incident_description=req.incident_description,
        evidence_urls=req.evidence_urls,
        is_urgent_24h_sla=is_urgent,
        status="received",
        acknowledged_at=datetime.utcnow() # Immediate statutory acknowledgment
    )
    
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)
    
    # Record forensic audit entry
    await record_legal_audit_event(
        request=request,
        action_type="GRIEVANCE_FILED",
        user_id=None,
        db=db
    )
    
    sla_notice = (
        "Statutory 24-Hour Urgent Action SLA applied under IT Rules Rule 3(2)(b)."
        if is_urgent
        else "Standard statutory grievance resolution will be completed within 15 days."
    )
    
    return {
        "status": "success",
        "ticket_number": ticket_no,
        "sla_notice": sla_notice,
        "grievance_officer_contact": "grievance@asiverticals.com"
    }
9. Legal Risk Checklist for Antigravity Autonomous AgentThe Antigravity coding agent must satisfy this verification suite before marking the compliance module complete:[ ] EULA Pre-Condition: Registration API rejects any attempt to insert a profile without an active TERMS_EULA record in public.consent_records.[ ] Bilingual KYC Consent: Video upload endpoint /api/v1/storage/presigned-url requires affirmative consent header X-Consent-DPDP: true.[ ] Automated Ephemeral KYC Erasure: Ensure a cron or Supabase Edge function is registered to purge video files from the storage bucket within 48 hours.[ ] 24-Hour NCII Freeze: Verification that any grievance filed with category ncii_nudity triggers an automated administrative flag on the reported profile.[ ] 180-Day CERT-In Logging: Verify that legal_audit_logs records client IP and installation UUID upon every session sync, swipe action, and account deletion request.[ ] Data Erasure Integrity: Confirm that calling the Account Deletion endpoint hard-purges all chat messages and profile photos, leaving only an anonymized audit log in legal_audit_logs for statutory compliance.Certified & Approved for ASI Verticals Legal and Compliance Engineering Pipeline.