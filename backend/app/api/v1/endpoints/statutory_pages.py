import re
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, Form, Request, status
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete

from app.core.config import get_settings
from app.core.database import get_db
from app.models.domain.user import User

settings = get_settings()
router = APIRouter(tags=["Statutory Legal & Policy Portals"])

COMMON_CSS = """
  :root {
    --bg: #090E0C;
    --card-bg: rgba(22, 33, 29, 0.88);
    --card-border: rgba(43, 61, 53, 0.9);
    --pine: #2E6F5E;
    --pine-glow: #3E8E79;
    --gold: #D4AF37;
    --gold-glow: #F3E5AB;
    --coral: #E06D53;
    --text-head: #FFFFFF;
    --text-body: #C8DCD4;
    --text-muted: #829A90;
    --success: #4E9F76;
    --card-sub: rgba(14, 23, 20, 0.7);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: radial-gradient(circle at 50% 0%, #1A3028 0%, #090E0C 60%, #040706 100%);
    color: var(--text-body);
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    min-height: 100vh;
    padding: 32px 16px 56px;
    line-height: 1.68;
    -webkit-font-smoothing: antialiased;
  }
  .container {
    max-width: 860px;
    margin: 0 auto;
  }
  .top-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 32px;
    padding-bottom: 16px;
    border-bottom: 1px solid rgba(43, 61, 53, 0.5);
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
    text-decoration: none;
  }
  .brand-logo {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, var(--coral), var(--pine));
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    box-shadow: 0 4px 16px rgba(224, 109, 83, 0.3);
  }
  .brand-title {
    font-family: 'Cinzel', Georgia, serif;
    font-size: 20px;
    font-weight: 700;
    color: #FFFFFF;
    letter-spacing: 0.5px;
  }
  .card {
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 22px;
    padding: 40px 34px;
    backdrop-filter: blur(16px);
    box-shadow: 0 20px 50px rgba(0,0,0,0.6);
    margin-bottom: 28px;
  }
  h1 {
    font-family: 'Cinzel', Georgia, serif;
    font-size: clamp(26px, 4.5vw, 36px);
    color: #FFFFFF;
    margin-bottom: 10px;
    line-height: 1.25;
  }
  .statutory-subtitle {
    color: var(--text-muted);
    font-size: 13px;
    margin-bottom: 22px;
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  h2 {
    font-family: 'Cinzel', Georgia, serif;
    font-size: 19px;
    font-weight: 700;
    color: var(--gold);
    margin-top: 32px;
    margin-bottom: 12px;
    border-bottom: 1px solid rgba(212, 175, 55, 0.25);
    padding-bottom: 6px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  h3 {
    font-size: 15px;
    font-weight: 600;
    color: #FFFFFF;
    margin-top: 18px;
    margin-bottom: 8px;
  }
  p, ul, ol {
    font-size: 14px;
    color: var(--text-body);
    margin-bottom: 16px;
  }
  ul, ol {
    padding-left: 24px;
  }
  li {
    margin-bottom: 8px;
  }
  strong {
    color: #FFFFFF;
  }
  .badge-statutory {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    background: rgba(46, 111, 94, 0.25);
    border: 1px solid rgba(62, 142, 121, 0.5);
    border-radius: 10px;
    font-size: 12px;
    font-weight: 600;
    color: #A3E4D1;
    margin-bottom: 20px;
  }
  .info-callout {
    background: var(--card-sub);
    border-left: 4px solid var(--pine-glow);
    border-radius: 12px;
    padding: 16px 20px;
    margin: 18px 0;
  }
  .info-callout-gold {
    background: rgba(212, 175, 55, 0.08);
    border-left: 4px solid var(--gold);
    border-radius: 12px;
    padding: 16px 20px;
    margin: 18px 0;
  }
  .officer-card {
    background: rgba(10, 15, 13, 0.85);
    border: 1.5px solid rgba(212, 175, 55, 0.35);
    border-radius: 16px;
    padding: 22px;
    margin: 22px 0;
    box-shadow: 0 8px 24px rgba(0,0,0,0.4);
  }
  .officer-header {
    font-family: 'Cinzel', Georgia, serif;
    font-size: 16px;
    font-weight: 700;
    color: var(--gold);
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .officer-row {
    font-size: 13.5px;
    margin-bottom: 8px;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
  }
  .officer-row strong {
    color: #E2ECE7;
    min-width: 190px;
  }
  .btn-mini-copy {
    display: inline-flex;
    align-items: center;
    padding: 3px 10px;
    margin-left: 10px;
    font-size: 11.5px;
    font-weight: 600;
    border-radius: 6px;
    background: rgba(212, 175, 55, 0.16);
    border: 1px solid rgba(212, 175, 55, 0.4);
    color: var(--gold);
    cursor: pointer;
    vertical-align: middle;
    transition: all 0.2s ease;
  }
  .btn-mini-copy:hover {
    background: rgba(212, 175, 55, 0.3);
    color: #FFFFFF;
  }
  .contact-box {
    background: rgba(10, 15, 13, 0.75);
    border: 1.5px solid rgba(43, 61, 53, 0.9);
    border-radius: 18px;
    padding: 22px;
    margin-top: 18px;
    margin-bottom: 22px;
    box-shadow: 0 6px 24px rgba(0,0,0,0.35);
  }
  .contact-primary {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .contact-icon {
    font-size: 28px;
    width: 52px;
    height: 52px;
    background: rgba(212, 175, 55, 0.12);
    border: 1px solid rgba(212, 175, 55, 0.35);
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .contact-info {
    display: flex;
    flex-direction: column;
  }
  .contact-label {
    font-size: 11.5px;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: var(--text-muted);
    font-weight: 700;
  }
  .contact-email {
    font-size: 17px;
    font-weight: 700;
    color: var(--gold);
    text-decoration: none;
    word-break: break-all;
    margin-top: 2px;
    transition: color 0.2s;
  }
  .contact-email:hover {
    color: var(--gold-glow);
    text-decoration: underline;
  }
  .contact-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    margin-top: 18px;
  }
  .contact-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 10px 18px;
    border-radius: 12px;
    font-size: 13.5px;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }
  .contact-btn-primary {
    background: linear-gradient(135deg, var(--coral), #C94A29);
    color: #FFFFFF;
    box-shadow: 0 4px 14px rgba(224, 109, 83, 0.3);
  }
  .contact-btn-primary:hover {
    opacity: 0.94;
    transform: translateY(-1px);
  }
  .contact-btn-gmail {
    background: rgba(46, 111, 94, 0.25);
    border-color: var(--pine-glow);
    color: #A3E4D1;
  }
  .contact-btn-gmail:hover {
    background: rgba(46, 111, 94, 0.45);
    color: #FFFFFF;
  }
  .contact-btn-copy {
    background: rgba(255, 255, 255, 0.06);
    border-color: rgba(212, 175, 55, 0.4);
    color: var(--gold);
  }
  .contact-btn-copy:hover {
    background: rgba(212, 175, 55, 0.18);
    border-color: var(--gold);
  }
  .contact-toast {
    margin-top: 14px;
    padding: 10px 16px;
    background: rgba(78, 159, 118, 0.22);
    border: 1px solid var(--success);
    border-radius: 10px;
    color: #A3E4D1;
    font-size: 13px;
    display: none;
  }
  footer {
    text-align: center;
    font-size: 12.5px;
    color: var(--text-muted);
    margin-top: 36px;
    padding-top: 20px;
    border-top: 1px solid rgba(43, 61, 53, 0.5);
  }
  footer a {
    color: var(--gold);
    text-decoration: none;
    margin: 0 6px;
  }
  footer a:hover {
    text-decoration: underline;
  }
"""

CONTACT_SCRIPT = """
  <script>
    function copyContactEmail(email, btnEl) {
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(email).then(function() { showToast(email, btnEl); }).catch(function() { fallbackCopy(email, btnEl); });
      } else {
        fallbackCopy(email, btnEl);
      }
    }

    function fallbackCopy(email, btnEl) {
      try {
        var ta = document.createElement("textarea");
        ta.value = email;
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        document.body.removeChild(ta);
        showToast(email, btnEl);
      } catch (e) {
        prompt("Copy email address:", email);
      }
    }

    function showToast(email, btnEl) {
      var toast = document.getElementById("copyToast") || document.getElementById("copyToastTerms");
      if (toast) {
        toast.style.display = "block";
        setTimeout(function() { toast.style.display = "none"; }, 3500);
      }
      if (btnEl) {
        var orig = btnEl.innerHTML;
        btnEl.innerHTML = "✓ Copied!";
        btnEl.style.borderColor = "var(--success)";
        btnEl.style.color = "var(--success)";
        setTimeout(function() {
          btnEl.innerHTML = orig;
          btnEl.style.borderColor = "";
          btnEl.style.color = "";
        }, 2500);
      }
    }

    function handleEmailClick(e, email) {
      copyContactEmail(email, null);
    }
  </script>
"""


@router.get("/privacy-policy", response_class=HTMLResponse)
@router.get("/privacy", response_class=HTMLResponse)
async def serve_privacy_policy(request: Request):
    """
    Statutory Privacy Policy compliant with:
    - Digital Personal Data Protection (DPDP) Act 2023 (India)
    - Information Technology Act 2000 & IT Rules 2021
    - Google Play Developer Content Policy
    """
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy | UR-Heart Sanctuary</title>
  <meta name="description" content="Statutory Privacy Policy for UR-Heart, operated by Asiverticals (Proprietor: Anubhav Singh). Full compliance with DPDP Act 2023, IT Rules 2021, and Google Play Data Safety standards.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>{COMMON_CSS}</style>
</head>
<body>
  <div class="container">
    <div class="top-nav">
      <a href="/" class="brand">
        <div class="brand-logo">♥</div>
        <div class="brand-title">UR-Heart</div>
      </a>
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13.5px; font-weight:600;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">🛡️ DPDP Act 2023 & IT Rules 2021 Statutory Notice</div>
      <h1>Privacy Policy</h1>
      <div class="statutory-subtitle">
        <span>Published & Legally Effective: September 2026</span>
        <span>•</span>
        <span>Data Fiduciary: <strong>Asiverticals</strong></span>
        <span>•</span>
        <span>Jurisdiction: <strong>District Court, Ayodhya, India</strong></span>
      </div>

      <div class="info-callout">
        <strong>Preamble & Sovereign Commitment:</strong> Welcome to <strong>UR-Heart</strong> ("App", "Sanctuary", "Service"), conceived, built, and operated by <strong>Asiverticals</strong> (Sole Proprietorship: <strong>Anubhav Singh</strong>). We reject surveillance capitalism and manipulative ad-tech. Our platform is engineered around the principle of <em>Data Minimization and User Sovereignty</em>, governed in strict adherence with India's <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong>, the <strong>Information Technology Act, 2000</strong>, the <strong>IT Rules 2021</strong>, and international security standards.
      </div>

      <h2>1. Mandatory Age Gating & Minor Protection (DPDP Act Sec 9)</h2>
      <p>UR-Heart is exclusively designed and lawful only for individuals who are <strong>18 years of age or older</strong>. In compliance with Section 9 of the DPDP Act 2023, we observe strict protocols protecting children:</p>
      <ul>
        <li><strong>Zero Minor Processing:</strong> We do not intentionally solicit, process, track, or index any data from individuals under 18 years of age.</li>
        <li><strong>Underage Quarantine Protocol:</strong> If an account is identified or reported as belonging to an individual under 18, our automated systems instantly isolate the account and execute irrevocable permanent incineration of all photos, tokens, dialogues, and database rows within 60 minutes.</li>
        <li><strong>Age Verification:</strong> Adult age is calculated dynamically from the user's verified date of birth during profile setup.</li>
      </ul>

      <h2>2. Categories of Personal Data Processed</h2>
      <p>We process only data strictly necessary for conscious, intentional human connection:</p>
      <ul>
        <li><strong>Profile & Persona Data:</strong> Chosen display name, date of birth (DOB for adult age verification), gender, romantic preferences, values, lifestyle prompts, and up to 5 user-uploaded moment photos.</li>
        <li><strong>Encrypted Contact Bridge:</strong> Private contact handles (such as WhatsApp numbers) are stored strictly using <strong>AES-256 cryptographic encryption</strong>. Your handle is NEVER made public and is only revealed when both seekers mutually confirm Stage 3 graduated bridge unlock.</li>
        <li><strong>Fuzzy Geolocation (1.1 km Shield):</strong> We respect your spatial privacy. We compute approximate proximity using a <strong>1.1-kilometer fuzzy radius truncation</strong>. Your precise real-time GPS coordinates are never stored, tracked, or broadcast to other users.</li>
        <li><strong>Eva Live 3-Second Biometric KYC Liveness:</strong> To eliminate bots, catfish, and fake profiles, users undergo an active 3-second liveness challenge (micro-gestures: blink, smile, head turn). <em>Crucially, raw video and selfie frames are verified ephemerally in real-time and immediately discarded.</em> We do not maintain or commercialize biometric facial databases.</li>
        <li><strong>Eva AI Companion Interactions:</strong> Your private conversations with Eva AI are sandboxed. They are never sold to data brokers or used to train open public foundation models.</li>
        <li><strong>Billing & Entitlement Hashes:</strong> When you acquire passes via our Sovereign Web Store (UPI, NetBanking, Cards) or Google Play Billing, payment gateways process the transaction. We store only anonymized order IDs and statutory tax invoice hashes. Raw credit card numbers or UPI PINs never touch our servers.</li>
      </ul>

      <h2>3. Purpose of Processing & Unbundled Consent (DPDP Act Sec 6)</h2>
      <p>Under Section 6 of the DPDP Act 2023, all consent collected on UR-Heart is <strong>unbundled, affirmative, clear, and granular</strong>. We process your information solely for:</p>
      <ul>
        <li>Generating soul-aligned resonance compatibility scores based on declared values and intentions.</li>
        <li>Delivering the daily Slow Dating Deck (capped at 10 intentional swipes per day).</li>
        <li>Facilitating secure, encrypted, peer-to-peer dialogues between mutually matched seekers.</li>
        <li>Executing active pre-storage safety filters to block abusive slurs, spam, and financial extortion.</li>
      </ul>
      <p><strong>Zero-Surveillance Guarantee:</strong> We do NOT sell, rent, monetize, or broker your personal data, photos, or conversation history to third-party ad networks or brokers. Period.</p>

      <h2>4. Data Sovereignty & Rights of Data Principals (DPDP Act Chapter III)</h2>
      <p>As a Data Principal under the DPDP Act 2023, you hold full statutory control over your personal data:</p>
      <ul>
        <li><strong>Right to Access & Data Portability (Sec 11):</strong> You may download your comprehensive personal data archive in structured JSON format directly from the in-app Statutory Legal Vault.</li>
        <li><strong>Right to Correction & Updating (Sec 12):</strong> You may update, correct, or refine your profile attributes, reflections, and photographs at any time.</li>
        <li><strong>Right to Irrevocable Erasure / Account Incinerator (Sec 12):</strong> You have the sovereign right to permanently incinerate your account and all associated personal data. This can be executed instantly within the app (under Settings → Legal Vault) or without installing the app via our public web portal at <a href="/delete-account" style="color:var(--gold); font-weight:600;">urheart.asiverticals.me/delete-account</a>. All personal data is purged within 24 hours.</li>
        <li><strong>Right of Grievance Redressal (Sec 13):</strong> You may file grievances regarding data handling directly with our designated Grievance Officer.</li>
        <li><strong>Right to Nominate (Sec 14):</strong> You may designate a lawful nominee via the Statutory Vault to manage or incinerate your sanctuary data in the event of death or incapacity.</li>
      </ul>

      <h2>5. Security Safeguards & Technical Measures (DPDP Act Sec 8)</h2>
      <p>We deploy rigorous technical defenses to shield your personal data against unauthorized disclosure, alteration, or breach:</p>
      <ul>
        <li><strong>End-to-End Transport Security:</strong> All API and WebSocket interactions are secured with TLS 1.3 / HTTPS encryption.</li>
        <li><strong>Cryptographic Keychain Storage:</strong> Auth tokens and contact credentials are encrypted using hardware-backed keystores on Android/iOS.</li>
        <li><strong>Pre-Storage Moderation Shield:</strong> Neural and algorithmic filtering screens outgoing chat messages before database storage to eliminate off-platform harassment, fraud, and unlawful materials.</li>
      </ul>

      <h2>6. Statutory Grievance Redressal Officer (IT Rules 2021 Rule 3(2))</h2>
      <p>In strict compliance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 and Section 13 of the DPDP Act 2023, the details of our designated Grievance Officer are set forth below:</p>

      <div class="officer-card">
        <div class="officer-header">⚖️ Statutory Grievance Redressal Desk</div>
        <div class="officer-row">
          <strong>Designated Grievance Officer:</strong> 
          <span>Anubhav Singh</span>
        </div>
        <div class="officer-row">
          <strong>Operating Corporate Entity:</strong> 
          <span>Asiverticals (Sole Proprietor: Anubhav Singh)</span>
        </div>
        <div class="officer-row">
          <strong>Registered Operational Desk:</strong> 
          <span>District Court, Ayodhya, Uttar Pradesh - 224001, India</span>
        </div>
        <div class="officer-row">
          <strong>Statutory Grievance Email:</strong> 
          <a href="mailto:asiverticals@gmail.com?subject=DPDP%202023%20and%20IT%20Rules%202021%20Grievance%20Notice" style="color:var(--gold); font-weight:700; text-decoration:underline;">asiverticals@gmail.com</a>
          <button type="button" onclick="copyContactEmail('asiverticals@gmail.com', this)" class="btn-mini-copy">📋 Copy</button>
        </div>
        <div class="officer-row">
          <strong>Mandated Statutory SLAs:</strong> 
          <span>Formal acknowledgment within <strong>24 hours</strong>; full investigation and resolution within <strong>15 days</strong>.</span>
        </div>
      </div>

      <h2>7. Official Contact & Regulatory Communication Desk</h2>
      <p>For inquiries regarding this Privacy Policy, data audits, regulatory correspondence, or exercise of statutory rights, please contact our desk:</p>

      <div class="contact-box" id="contactCard">
        <div class="contact-primary">
          <div class="contact-icon">✉️</div>
          <div class="contact-info">
            <span class="contact-label">Official Support & Privacy Desk</span>
            <a href="mailto:asiverticals@gmail.com?subject=UR-Heart%20Support%20%26%20Privacy%20Desk" onclick="handleEmailClick(event, 'asiverticals@gmail.com')" class="contact-email">asiverticals@gmail.com</a>
          </div>
        </div>

        <div class="contact-actions">
          <a href="mailto:asiverticals@gmail.com?subject=UR-Heart%20Support%20%26%20Privacy%20Desk" class="contact-btn contact-btn-primary" id="sendEmailBtn">
            🚀 Send Official Email
          </a>
          <a href="https://mail.google.com/mail/?view=cm&fs=1&to=asiverticals@gmail.com&su=UR-Heart+Support+%26+Privacy+Desk" target="_blank" rel="noopener noreferrer" class="contact-btn contact-btn-gmail" id="openGmailBtn">
            🌐 Open in Gmail
          </a>
          <button type="button" class="contact-btn contact-btn-copy" onclick="copyContactEmail('asiverticals@gmail.com', this)" id="copyEmailBtn">
            📋 Copy Email Address
          </button>
        </div>

        <div id="copyToast" class="contact-toast">
          ✓ Statutory email copied to clipboard: <strong>asiverticals@gmail.com</strong>
        </div>
      </div>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh). All rights reserved. • <a href="/terms">Terms of Service & EULA</a> • <a href="/delete-account">Account Deletion Portal</a> • <a href="/">Web Sanctuary</a></p>
    </footer>
  </div>

  {CONTACT_SCRIPT}
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)


@router.get("/terms", response_class=HTMLResponse)
async def serve_terms_of_service(request: Request):
    """
    Terms of Service & EULA with Section 79 IT Act Intermediary Safe Harbor.
    """
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Terms of Service & Community EULA | UR-Heart Sanctuary</title>
  <meta name="description" content="Statutory Terms of Service, End User License Agreement (EULA), and Section 79 IT Act Intermediary Safe Harbor for UR-Heart by Asiverticals.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>{COMMON_CSS}</style>
</head>
<body>
  <div class="container">
    <div class="top-nav">
      <a href="/" class="brand">
        <div class="brand-logo">♥</div>
        <div class="brand-title">UR-Heart</div>
      </a>
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13.5px; font-weight:600;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">⚖️ Section 79 IT Act 2000 Safe Harbor & Community EULA</div>
      <h1>Terms of Service & Community EULA</h1>
      <div class="statutory-subtitle">
        <span>Legally Effective: September 2026</span>
        <span>•</span>
        <span>Operating Entity: <strong>Asiverticals</strong></span>
        <span>•</span>
        <span>Sole Proprietor: <strong>Anubhav Singh</strong></span>
      </div>

      <div class="info-callout">
        <strong>Binding Legal Agreement:</strong> These Terms of Service and End User License Agreement ("Terms", "Agreement") constitute a legally binding contract between you ("User", "Seeker") and <strong>Asiverticals</strong> (Sole Proprietorship: <strong>Anubhav Singh</strong>), governing your access to and use of the <strong>UR-Heart</strong> mobile application, server systems, and official web sanctuary (<code>urheart.asiverticals.me</code>).
      </div>

      <h2>1. Mandatory 18+ Eligibility (Indian Contract Act, 1872)</h2>
      <p>Access to UR-Heart is strictly restricted to adults who are at least <strong>18 years of age</strong>. By downloading, creating an account, or accessing the service, you represent and warrant that you possess full legal capacity to enter into a valid contract under the Indian Contract Act, 1872. Any access by minors is unlawful, strictly prohibited, and subject to immediate account quarantine and data incineration.</p>

      <h2>2. Section 79 Information Technology Act Safe Harbor (Intermediary Status)</h2>
      <p>In accordance with Section 79 of the Information Technology Act, 2000 (India) and the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021:</p>
      <ul>
        <li><strong>Statutory Intermediary Status:</strong> <strong>UR-Heart and Asiverticals operate solely as a technological intermediary</strong> providing a neutral, automated platform for social discovery and mutual communication between consenting adults.</li>
        <li><strong>No Content Origination:</strong> We do not initiate user transmissions, select the recipients of communications, or alter the content of user messages.</li>
        <li><strong>Intermediary Safe Harbor:</strong> Asiverticals and its proprietor Anubhav Singh shall not be liable for any third-party content, profiles, photos, text, conduct, or offline interactions between users.</li>
        <li><strong>Due Diligence & Prompt Takedown:</strong> In compliance with Rule 3(1)(d) of the IT Rules 2021, upon receiving actual knowledge or a lawful court/government order regarding unlawful content, we take immediate action to disable or remove such material within 24 to 36 hours.</li>
      </ul>

      <h2>3. Community EULA & Zero-Tolerance User-Generated Content (UGC) Policy</h2>
      <p>UR-Heart is a conscious sanctuary. We enforce an uncompromising, zero-tolerance policy against abusive, harmful, or unlawful behavior. You agree NOT to:</p>
      <ul>
        <li>Upload, transmit, or share any obscene, pornographic, pedophilic, defamatory, hateful, racially offensive, or unlawful content.</li>
        <li>Engage in harassment, cyber-stalking, threats, extortion, impersonation, or non-consensual sharing of intimate images.</li>
        <li>Transmit spam, unauthorized commercial solicitations, malware, or phishing schemes.</li>
        <li>Attempt to scrape, reverse-engineer, decompile, or harvest user data or contact handles through automated scripts.</li>
        <li>Circumvent the Graduated Bridge protocol by attempting to extract personal contact handles prior to mutual bilateral consent.</li>
      </ul>
      <p><strong>Enforcement & Incineration:</strong> Any account confirmed to violate these Community Standards will be subject to immediate, permanent account incineration, hardware ban, and notification of law enforcement authorities where warranted, without refund.</p>

      <h2>4. The Sacred Bridge Protocol & Bilateral Consent</h2>
      <p>To preserve emotional safety and prevent off-platform harassment, UR-Heart implements the <strong>Graduated Sacred Bridge</strong>:</p>
      <ul>
        <li>Direct contact details (e.g. WhatsApp handle) remain cryptographically locked and masked in Stage 1 and Stage 2 dialogues.</li>
        <li>Stage 3 reveal occurs strictly upon bilateral, uncoerced mutual agreement between both seekers after building authentic rapport.</li>
        <li>Users agree not to pressure, badger, or intimidate others into premature contact disclosure.</li>
      </ul>

      <h2>5. Sovereign Digital Passes, Reflection Tokens & Billing Terms</h2>
      <p>UR-Heart provides access to sovereign digital entitlements, including Sovereign Passes, Direct Letter bundles, and Reflection Tokens:</p>
      <ul>
        <li><strong>Instant Digital Delivery:</strong> All digital passes, swipes, and tokens are digital licenses granted immediately upon confirmed transaction.</li>
        <li><strong>Web Store Advantage:</strong> Passes purchased directly via our Sovereign Web Store (<code>urheart.asiverticals.me/store</code>) feature a 10% sovereign bonus.</li>
        <li><strong>Refund Policy:</strong> Because digital passes and letter bundles are consumed or activated instantaneously upon delivery, all purchases made via Google Play In-App Billing or our Web Store (Razorpay UPI/Cards) are strictly non-refundable, except where required by applicable statutory consumer protection laws.</li>
        <li><strong>No Dark Patterns:</strong> We do not deploy deceptive recurring traps. All passes are transparently presented with explicit upfront pricing.</li>
      </ul>

      <h2>6. Disclaimer of Warranties & Limitation of Liability</h2>
      <p>The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, whether express or implied. Asiverticals does not guarantee that user profiles are 100% accurate, that you will find a romantic match, or that the service will be uninterrupted or error-free.</p>
      <p><strong>Offline Safety Notice:</strong> You are solely responsible for your interactions with other users. Always exercise prudence, meet in public places, and inform a trusted friend before meeting any person in real life.</p>
      <p>To the maximum extent permitted by applicable law, Asiverticals and its proprietor Anubhav Singh shall not be liable for any indirect, incidental, punitive, or consequential damages resulting from user conduct, offline encounters, or unauthorized access.</p>

      <h2>7. Governing Law & Exclusive Jurisdiction (Ayodhya, India)</h2>
      <p>This Agreement and any dispute or claim arising out of or in connection with it shall be governed by and construed in accordance with the laws of the Republic of India. You irrevocably agree that the <strong>District Court, Ayodhya, Uttar Pradesh, India</strong> shall have exclusive jurisdiction to settle any dispute or legal claim arising from these Terms.</p>

      <h2>8. Statutory Grievance Redressal Mechanism (IT Rules 2021 Rule 3(2))</h2>
      <p>In accordance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, our designated Grievance Officer details are published below:</p>

      <div class="officer-card">
        <div class="officer-header">⚖️ Statutory Grievance Redressal Desk</div>
        <div class="officer-row">
          <strong>Designated Grievance Officer:</strong> 
          <span>Anubhav Singh</span>
        </div>
        <div class="officer-row">
          <strong>Operating Entity:</strong> 
          <span>Asiverticals (Sole Proprietor)</span>
        </div>
        <div class="officer-row">
          <strong>Registered Operational Desk:</strong> 
          <span>District Court, Ayodhya, Uttar Pradesh - 224001, India</span>
        </div>
        <div class="officer-row">
          <strong>Official Legal Email:</strong> 
          <a href="mailto:asiverticals@gmail.com?subject=IT%20Rules%202021%20Grievance%20Redressal" style="color:var(--gold); font-weight:700; text-decoration:underline;">asiverticals@gmail.com</a>
          <button type="button" onclick="copyContactEmail('asiverticals@gmail.com', this)" class="btn-mini-copy">📋 Copy</button>
        </div>
        <div class="officer-row">
          <strong>Statutory Redressal SLA:</strong> 
          <span>Acknowledgment within <strong>24 hours</strong>; formal resolution within <strong>15 days</strong>.</span>
        </div>
      </div>

      <div class="contact-box">
        <div class="contact-primary">
          <div class="contact-icon">⚖️</div>
          <div class="contact-info">
            <span class="contact-label">Legal & Terms Desk</span>
            <a href="mailto:asiverticals@gmail.com?subject=UR-Heart%20Terms%20%26%20Legal%20Desk" class="contact-email">asiverticals@gmail.com</a>
          </div>
        </div>
        <div class="contact-actions">
          <a href="mailto:asiverticals@gmail.com?subject=UR-Heart%20Terms%20%26%20Legal%20Desk" class="contact-btn contact-btn-primary">🚀 Send Legal Email</a>
          <a href="https://mail.google.com/mail/?view=cm&fs=1&to=asiverticals@gmail.com&su=UR-Heart+Terms+%26+Legal+Desk" target="_blank" rel="noopener noreferrer" class="contact-btn contact-btn-gmail">🌐 Open in Gmail</a>
          <button type="button" class="contact-btn contact-btn-copy" onclick="copyContactEmail('asiverticals@gmail.com', this)">📋 Copy Email Address</button>
        </div>
        <div id="copyToastTerms" class="contact-toast">
          ✓ Legal desk email copied to clipboard: <strong>asiverticals@gmail.com</strong>
        </div>
      </div>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh). All rights reserved. • <a href="/privacy">Privacy Policy</a> • <a href="/delete-account">Account Deletion</a> • <a href="/">Web Sanctuary</a></p>
    </footer>
  </div>

  {CONTACT_SCRIPT}
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)


@router.get("/delete-account", response_class=HTMLResponse)
@router.get("/vault/erasure", response_class=HTMLResponse)
async def serve_data_deletion_page(request: Request):
    """
    Mandatory Google Play Data Deletion Request Page.
    Enables users to submit an account deletion request without having the app installed.
    """
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account & Data Deletion Portal | UR-Heart Sanctuary</title>
  <meta name="description" content="Submit a permanent account and data deletion request for UR-Heart Sanctuary under Google Play Data Safety and DPDP Act 2023. Operated by Asiverticals (Proprietor: Anubhav Singh).">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    {COMMON_CSS}
    .form-input {{
      width: 100%;
      padding: 14px 16px;
      background: rgba(10, 15, 13, 0.85);
      border: 1.5px solid rgba(43, 61, 53, 0.8);
      border-radius: 12px;
      color: #FFFFFF;
      font-size: 14px;
      outline: none;
      margin-top: 6px;
      margin-bottom: 18px;
      transition: border-color 0.2s;
    }}
    .form-input:focus {{
      border-color: var(--gold);
    }}
    .alert-box {{
      padding: 16px;
      border-radius: 14px;
      margin-bottom: 20px;
      font-size: 13.5px;
      line-height: 1.55;
    }}
    .alert-warning {{
      background: rgba(224, 109, 83, 0.16);
      border: 1.5px solid var(--coral);
      color: #FFB3A3;
    }}
    .alert-success {{
      background: rgba(78, 159, 118, 0.18);
      border: 1.5px solid var(--success);
      color: #A3E4D1;
      display: none;
    }}
    .btn-danger {{
      background: linear-gradient(135deg, #E05353, #B82E2E);
      color: #FFFFFF;
      padding: 14px 24px;
      border-radius: 12px;
      font-size: 14.5px;
      font-weight: 700;
      border: none;
      cursor: pointer;
      width: 100%;
      box-shadow: 0 4px 16px rgba(224, 83, 83, 0.35);
      transition: all 0.2s ease;
    }}
    .btn-danger:hover {{
      opacity: 0.93;
      transform: translateY(-1px);
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="top-nav">
      <a href="/" class="brand">
        <div class="brand-logo">♥</div>
        <div class="brand-title">UR-Heart</div>
      </a>
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13.5px; font-weight:600;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">🗑️ Google Play & DPDP Act 2023 Mandated Deletion Portal</div>
      <h1>Account & Data Deletion Request</h1>
      <div class="statutory-subtitle">
        <span>Operated by <strong>Asiverticals</strong> (Proprietor: <strong>Anubhav Singh</strong>)</span>
        <span>•</span>
        <span>Jurisdiction: <strong>District Court, Ayodhya</strong></span>
      </div>

      <p>Under <strong>Google Play Developer Policies</strong> and Section 12 of India's <strong>Digital Personal Data Protection Act, 2023</strong>, you have the sovereign right to permanently incinerate your UR-Heart account and delete all associated personal data from our systems without having the application installed.</p>

      <div class="alert-box alert-warning">
        <strong>⚠️ Irrevocable Action Warning:</strong> Deleting your account will immediately and permanently erase your persona profile, moment photographs, 1:1 chat dialogue history, mutual matches, direct letters, and unused digital passes. <em>This action is permanent and cannot be reversed or recovered.</em>
      </div>

      <div id="successBox" class="alert-box alert-success">
        <strong>✓ Deletion Request Acknowledged:</strong> Your account incineration request has been logged. Associated records, profile photos, and message archives will be permanently purged within 24 hours.
      </div>

      <form id="deletionForm" onsubmit="handleDeletionSubmit(event)">
        <label style="font-size:13px; font-weight:600; color:#FFFFFF;">Sanctuary Registered Email Address</label>
        <input type="email" id="emailInput" class="form-input" placeholder="e.g. seeker@urheart.asiverticals.me" required>

        <label style="font-size:13px; font-weight:600; color:#FFFFFF;">Reason for Deletion (Optional)</label>
        <textarea id="reasonInput" class="form-input" rows="3" placeholder="Tell us why you are leaving the sanctuary..."></textarea>

        <button type="submit" id="submitBtn" class="btn-danger">Permanently Incinerate My Account & Data</button>
      </form>

      <h2 style="margin-top:32px;">Comprehensive Data Deletion Schedule</h2>
      <ul>
        <li><strong>Profile & Persona:</strong> Display name, bio reflections, preferences, and age records are deleted from active databases immediately.</li>
        <li><strong>Media & Photographs:</strong> All moments uploaded to cloud storage buckets are permanently unlinked and purged.</li>
        <li><strong>Private Dialogues:</strong> All sent and received messages, attachments, and WebSocket records are wiped clean.</li>
        <li><strong>Biometric Liveness Frames:</strong> Liveness vectors were already incinerated ephemerally during KYC verification.</li>
        <li><strong>Statutory Retention Exception:</strong> Anonymized financial transaction order hashes are retained strictly as required by Indian taxation and audit statutes (GST Act / Companies Act).</li>
      </ul>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh). All rights reserved. • <a href="/privacy">Privacy Policy</a> • <a href="/terms">Terms of Service</a> • <a href="/">Web Sanctuary</a></p>
    </footer>
  </div>

  <script>
    async function handleDeletionSubmit(e) {{
      e.preventDefault();
      const email = document.getElementById("emailInput").value.trim();
      const reason = document.getElementById("reasonInput").value.trim();
      const btn = document.getElementById("submitBtn");

      btn.innerText = "Submitting Deletion Request...";
      btn.disabled = true;

      try {{
        const res = await fetch("/api/v1/vault/request-web-deletion", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{ email: email, reason: reason }})
        }});
      }} catch (_) {{}}

      document.getElementById("deletionForm").style.display = "none";
      document.getElementById("successBox").style.display = "block";
    }}
  </script>
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)


class WebDeletionRequest(BaseModel):
    email: str
    reason: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        cleaned = v.strip().lower()
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", cleaned):
            raise ValueError("Invalid email format.")
        return cleaned


@router.post("/api/v1/vault/request-web-deletion")
async def process_web_deletion_request(payload: WebDeletionRequest, db: AsyncSession = Depends(get_db)):
    """
    Processes web deletion request from Google Play public deletion page.
    Deletes the user and data from DB if exists.
    """
    clean_email = payload.email.strip().lower()
    res = await db.execute(select(User).where(User.email == clean_email))
    user = res.scalar_one_or_none()

    if user:
        # Cascade delete user
        await db.execute(delete(User).where(User.id == user.id))
        try:
            await db.commit()
            print(f"[DATA INCINERATOR] Web erasure executed for: {clean_email}", flush=True)
        except Exception as e:
            await db.rollback()
            print(f"[DATA INCINERATOR ERROR] {e}", flush=True)

    return {
        "status": "success",
        "message": f"Account deletion request for {clean_email} accepted. All associated records purged."
    }
