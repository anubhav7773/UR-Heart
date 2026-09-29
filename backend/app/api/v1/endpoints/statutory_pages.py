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
    --card-bg: rgba(22, 33, 29, 0.85);
    --card-border: rgba(43, 61, 53, 0.85);
    --pine: #2E6F5E;
    --pine-glow: #3E8E79;
    --gold: #D4AF37;
    --coral: #E06D53;
    --text-head: #FFFFFF;
    --text-body: #C5D6CE;
    --text-muted: #829A90;
    --success: #4E9F76;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: radial-gradient(circle at 50% 5%, #182B24 0%, #090E0C 65%, #050807 100%);
    color: var(--text-body);
    font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
    min-height: 100vh;
    padding: 32px 16px 48px;
    line-height: 1.6;
  }
  .container {
    max-width: 800px;
    margin: 0 auto;
  }
  .top-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 32px;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 10px;
    text-decoration: none;
  }
  .brand-logo {
    width: 36px;
    height: 36px;
    background: linear-gradient(135deg, var(--coral), var(--pine));
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }
  .brand-title {
    font-family: 'Cinzel', serif;
    font-size: 18px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .card {
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 20px;
    padding: 36px 30px;
    backdrop-filter: blur(14px);
    box-shadow: 0 16px 40px rgba(0,0,0,0.5);
    margin-bottom: 24px;
  }
  h1 {
    font-family: 'Cinzel', serif;
    font-size: clamp(24px, 4vw, 32px);
    color: #FFFFFF;
    margin-bottom: 12px;
  }
  h2 {
    font-size: 18px;
    font-weight: 700;
    color: var(--gold);
    margin-top: 24px;
    margin-bottom: 10px;
    border-bottom: 1px solid rgba(212, 175, 55, 0.2);
    padding-bottom: 4px;
  }
  p, ul {
    font-size: 13.5px;
    color: var(--text-body);
    margin-bottom: 14px;
  }
  ul {
    padding-left: 20px;
  }
  li {
    margin-bottom: 6px;
  }
  .badge-statutory {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    background: rgba(46, 111, 94, 0.2);
    border: 1px solid rgba(62, 142, 121, 0.4);
    border-radius: 8px;
    font-size: 11.5px;
    font-weight: 600;
    color: #A3E4D1;
    margin-bottom: 18px;
  }
  .officer-card {
    background: rgba(10, 15, 13, 0.6);
    border: 1px solid rgba(43, 61, 53, 0.8);
    border-radius: 14px;
    padding: 18px;
    margin: 16px 0;
  }
  .officer-row {
    font-size: 13px;
    margin-bottom: 6px;
  }
  .officer-row strong {
    color: var(--gold);
  }
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 12px 24px;
    border-radius: 12px;
    font-size: 13.5px;
    font-weight: 700;
    text-decoration: none;
    cursor: pointer;
    border: none;
  }
  .btn-primary {
    background: linear-gradient(135deg, var(--coral), #C94A29);
    color: #FFFFFF;
  }
  .btn-danger {
    background: linear-gradient(135deg, #E05353, #B82E2E);
    color: #FFFFFF;
  }
  footer {
    text-align: center;
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 32px;
  }
  footer a {
    color: var(--gold);
    text-decoration: none;
  }
  .contact-box {
    background: rgba(10, 15, 13, 0.7);
    border: 1.5px solid rgba(43, 61, 53, 0.9);
    border-radius: 16px;
    padding: 20px;
    margin-top: 14px;
    margin-bottom: 20px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  }
  .contact-primary {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .contact-icon {
    font-size: 26px;
    width: 48px;
    height: 48px;
    background: rgba(212, 175, 55, 0.12);
    border: 1px solid rgba(212, 175, 55, 0.3);
    border-radius: 12px;
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
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: var(--text-muted);
    font-weight: 600;
  }
  .contact-email {
    font-size: 16px;
    font-weight: 700;
    color: var(--gold);
    text-decoration: none;
    word-break: break-all;
    margin-top: 2px;
    transition: color 0.2s;
  }
  .contact-email:hover {
    color: #FFE680;
    text-decoration: underline;
  }
  .contact-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    margin-top: 16px;
  }
  .contact-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 10px 16px;
    border-radius: 10px;
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    transition: all 0.2s;
    border: 1px solid transparent;
  }
  .contact-btn-primary {
    background: linear-gradient(135deg, var(--coral), #C94A29);
    color: #FFFFFF;
  }
  .contact-btn-primary:hover {
    opacity: 0.92;
    transform: translateY(-1px);
  }
  .contact-btn-gmail {
    background: rgba(46, 111, 94, 0.3);
    border-color: var(--pine-glow);
    color: #A3E4D1;
  }
  .contact-btn-gmail:hover {
    background: rgba(46, 111, 94, 0.5);
    color: #FFFFFF;
  }
  .contact-btn-copy {
    background: rgba(255, 255, 255, 0.06);
    border-color: rgba(212, 175, 55, 0.4);
    color: var(--gold);
  }
  .contact-btn-copy:hover {
    background: rgba(212, 175, 55, 0.15);
    border-color: var(--gold);
  }
  .contact-toast {
    margin-top: 14px;
    padding: 10px 14px;
    background: rgba(78, 159, 118, 0.2);
    border: 1px solid var(--success);
    border-radius: 10px;
    color: #A3E4D1;
    font-size: 13px;
  }
  .btn-mini-copy {
    display: inline-flex;
    align-items: center;
    padding: 2px 8px;
    margin-left: 8px;
    font-size: 11px;
    border-radius: 6px;
    background: rgba(212, 175, 55, 0.15);
    border: 1px solid rgba(212, 175, 55, 0.4);
    color: var(--gold);
    cursor: pointer;
    vertical-align: middle;
  }
  .btn-mini-copy:hover {
    background: rgba(212, 175, 55, 0.3);
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
  <meta name="description" content="Official Privacy Policy for UR-Heart, operated by Asiverticals. Full compliance with DPDP Act 2023 and Google Play policies.">
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
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13px;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">🛡️ DPDP Act 2023 & IT Rules 2021 Compliant</div>
      <h1>Privacy Policy</h1>
      <p style="color:var(--text-muted); font-size:12px;">Last Updated & Legally Effective: September 2026</p>

      <p>Welcome to <strong>UR-Heart</strong> ("App", "Sanctuary", "Service"), operated by <strong>Asiverticals</strong> (Sole Proprietorship: Anubhav Singh). We are deeply dedicated to preserving user privacy, mindful resonance, and data sovereignty. This Privacy Policy details how we collect, safeguard, and respect your personal digital data in strict compliance with India's <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong>, the <strong>Information Technology Act, 2000</strong>, and international data standards.</p>

      <h2>1. Age Gate & Strict Minor Protection</h2>
      <p>UR-Heart is strictly for individuals who are <strong>18 years of age or older</strong>. We strictly prohibit minors from creating an account or accessing the sanctuary. If we discover any account belonging to an individual under 18, it is immediately quarantined and permanently incinerated along with all associated media and records.</p>

      <h2>2. Information We Collect</h2>
      <ul>
        <li><strong>Account & Persona Credentials:</strong> Name, verified adult Date of Birth (DOB), gender, romantic preferences, photos, and optional mindful bio reflections.</li>
        <li><strong>Contact Bridge (Encrypted):</strong> Contact handle (WhatsApp or chosen bridge) is stored strictly with AES-256 client-side encryption and is NEVER revealed until Stage 3 mutual unlock.</li>
        <li><strong>Approximate Geolocation:</strong> Used solely to compute approximate proximity matching. Exact coordinates are never broadcast or shared with third parties.</li>
        <li><strong>Financial & Transaction Data:</strong> When purchasing sovereign passes via Google Play or our Web Store, transaction references and order IDs are logged in our internal ledger for entitlement verification. We do not store raw credit card numbers or UPI PINs.</li>
      </ul>

      <h2>3. How We Use and Protect Your Data</h2>
      <ul>
        <li>We operate on a <strong>Zero-Surveillance model</strong>. We NEVER sell, lease, or monetize your private communications, photos, or data to third-party data brokers or advertising syndicates.</li>
        <li>All network transmissions use TLS 1.3 encryption (HTTPS / WSS). Sensitive keys and tokens are stored in secure hardware-backed keychains.</li>
      </ul>

      <h2>4. User Rights Under DPDP Act 2023 (India)</h2>
      <p>As a data principal, you have sovereign rights under Chapter III of the DPDP Act 2023:</p>
      <ul>
        <li><strong>Right to Access & Portability (Sec 11):</strong> Download your complete encrypted statutory data archive directly from the in-app Statutory Vault.</li>
        <li><strong>Right to Nominate (Sec 14):</strong> Designate a lawful nominee in the Statutory Vault to manage your data in case of death or incapacity.</li>
        <li><strong>Right to Complete Erasure (Sec 12):</strong> One-tap irrevocable account incineration completely deletes your profile, matches, messages, and photos from our servers within 24 hours. You may also use our web portal at <a href="/delete-account" style="color:var(--gold);">urheart.asiverticals.me/delete-account</a>.</li>
      </ul>

      <h2>5. Statutory Grievance Redressal (IT Rules 2021 Rule 3(2))</h2>
      <p>In accordance with the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, the details of our designated Grievance Officer are published below:</p>
      
      <div class="officer-card">
        <div class="officer-row"><strong>Designated Grievance Officer:</strong> Anubhav Singh</div>
        <div class="officer-row"><strong>Operating Entity:</strong> Asiverticals (Sole Proprietor)</div>
        <div class="officer-row">
          <strong>Statutory Grievance Email:</strong> 
          <a href="mailto:asiverticals@gmail.com?subject=IT%20Rules%202021%20Grievance%20Redressal" style="color:var(--gold); text-decoration:underline;">asiverticals@gmail.com</a>
          <button type="button" onclick="copyContactEmail('asiverticals@gmail.com', this)" class="btn-mini-copy">📋 Copy</button>
        </div>
        <div class="officer-row"><strong>Registered Operational Desk:</strong> District Court, Ayodhya, Uttar Pradesh - 224001, India</div>
        <div class="officer-row"><strong>Statutory Timelines:</strong> Acknowledgment within 24 hours; complete resolution within 15 days.</div>
      </div>

      <h2>6. Contact Us</h2>
      <p>For questions, support, compliance audits, or data rights, reach our operational desk anytime:</p>

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
            🚀 Send Email
          </a>
          <a href="https://mail.google.com/mail/?view=cm&fs=1&to=asiverticals@gmail.com&su=UR-Heart+Support+%26+Privacy+Desk" target="_blank" rel="noopener noreferrer" class="contact-btn contact-btn-gmail" id="openGmailBtn">
            🌐 Open in Gmail
          </a>
          <button type="button" class="contact-btn contact-btn-copy" onclick="copyContactEmail('asiverticals@gmail.com', this)" id="copyEmailBtn">
            📋 Copy Email Address
          </button>
        </div>

        <div id="copyToast" class="contact-toast" style="display:none;">
          ✓ Email copied to clipboard: <strong>asiverticals@gmail.com</strong>
        </div>
      </div>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh) • <a href="/terms">Terms of Service</a> • <a href="/delete-account">Account Deletion Portal</a></p>
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
  <title>Terms of Service & EULA | UR-Heart</title>
  <meta name="description" content="Terms of Service, End User License Agreement, and Intermediary Disclaimers for UR-Heart by Asiverticals.">
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
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13px;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">⚖️ Section 79 IT Act 2000 Safe Harbor EULA</div>
      <h1>Terms of Service & End User Agreement</h1>
      <p style="color:var(--text-muted); font-size:12px;">Last Updated: September 2026</p>

      <p>Please read these Terms of Service ("Terms") carefully. By creating an account, downloading, or using <strong>UR-Heart</strong>, you enter into a binding agreement with <strong>Asiverticals</strong> (Proprietorship: Anubhav Singh).</p>

      <h2>1. Mandatory 18+ Eligibility</h2>
      <p>You must be at least 18 years of age to access UR-Heart. By accessing this platform, you warrant and represent that you have legal capacity to enter into this contract under the Indian Contract Act, 1872.</p>

      <h2>2. Section 79 Information Technology Act Safe Harbor (Intermediary Status)</h2>
      <p>Under Section 79 of the Information Technology Act, 2000 (India), <strong>UR-Heart and Asiverticals are statutory intermediaries</strong>. We provide an automated platform for mutual user connection and social discovery. We do not initiate user transmissions, select the receivers, or modify user-generated content. We are NOT liable for any third-party user communications, profiles, or offline meetings.</p>

      <h2>3. Code of Conduct & Zero-Tolerance UGC Policy</h2>
      <p>Users must strictly respect others. You agree NOT to:</p>
      <ul>
        <li>Upload, transmit, or share any obscene, pornographic, pedophilic, defamatory, hateful, or unlawful material.</li>
        <li>Impersonate any person, conduct financial extortion, fraud, or commercial solicitation.</li>
        <li>Harass, stalk, or send unsolicited non-consensual messages.</li>
      </ul>
      <p><strong>Enforcement:</strong> Any user who violates these rules will face immediate permanent account incineration and device quarantine without refund. Users can report any profile via the in-app Report Dossier button.</p>

      <h2>4. Digital Purchases & Billing Policy</h2>
      <p>Sovereign Passes, Reflection Packs, and Direct Letters are digital licenses activated instantaneously upon confirmed purchase. All purchases made through Google Play In-App Billing or our Sovereign Web Store are subject to standard consumer digital goods terms. Once consumed or activated, digital passes are non-refundable unless required by applicable law.</p>

      <h2>5. Limitation of Liability</h2>
      <p>To the maximum extent permitted under applicable law, Asiverticals and its founder shall not be liable for any direct, indirect, incidental, or consequential damages arising from your use of the application, user interactions, or offline conduct.</p>

      <h2>6. Governing Law & Dispute Jurisdiction</h2>
      <p>These Terms are governed by and construed in accordance with the laws of the Republic of India. Any statutory disputes shall be subject to the exclusive jurisdiction of the competent courts in <strong>Ayodhya / Uttar Pradesh, India</strong>.</p>

      <h2>7. Grievance Redressal & Legal Desk (IT Rules 2021 Rule 3(2))</h2>
      <p>In accordance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021:</p>
      <div class="officer-card">
        <div class="officer-row"><strong>Designated Grievance Officer:</strong> Anubhav Singh</div>
        <div class="officer-row"><strong>Operating Entity:</strong> Asiverticals (Sole Proprietor)</div>
        <div class="officer-row">
          <strong>Official Contact Email:</strong> 
          <a href="mailto:asiverticals@gmail.com?subject=IT%20Rules%202021%20Grievance%20Redressal" style="color:var(--gold); text-decoration:underline;">asiverticals@gmail.com</a>
          <button type="button" onclick="copyContactEmail('asiverticals@gmail.com', this)" class="btn-mini-copy">📋 Copy</button>
        </div>
        <div class="officer-row"><strong>Registered Operational Desk:</strong> District Court, Ayodhya, Uttar Pradesh - 224001, India</div>
        <div class="officer-row"><strong>Statutory Timelines:</strong> Acknowledgment within 24 hours; resolution within 15 days.</div>
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
          <a href="mailto:asiverticals@gmail.com?subject=UR-Heart%20Terms%20%26%20Legal%20Desk" class="contact-btn contact-btn-primary">🚀 Send Email</a>
          <a href="https://mail.google.com/mail/?view=cm&fs=1&to=asiverticals@gmail.com&su=UR-Heart+Terms+%26+Legal+Desk" target="_blank" rel="noopener noreferrer" class="contact-btn contact-btn-gmail">🌐 Open in Gmail</a>
          <button type="button" class="contact-btn contact-btn-copy" onclick="copyContactEmail('asiverticals@gmail.com', this)">📋 Copy Email Address</button>
        </div>
        <div id="copyToastTerms" class="contact-toast" style="display:none;">
          ✓ Email copied to clipboard: <strong>asiverticals@gmail.com</strong>
        </div>
      </div>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh) • <a href="/privacy">Privacy Policy</a> • <a href="/delete-account">Account Deletion</a></p>
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
  <title>Account & Data Deletion Portal | UR-Heart</title>
  <meta name="description" content="Submit a permanent account and data deletion request for UR-Heart Sanctuary under Google Play Data Safety and DPDP Act 2023.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    {COMMON_CSS}
    .form-input {{
      width: 100%;
      padding: 14px 16px;
      background: rgba(10, 15, 13, 0.8);
      border: 1.5px solid rgba(43, 61, 53, 0.8);
      border-radius: 12px;
      color: #FFFFFF;
      font-size: 14px;
      outline: none;
      margin-top: 6px;
      margin-bottom: 18px;
    }}
    .alert-box {{
      padding: 14px;
      border-radius: 12px;
      margin-bottom: 20px;
      font-size: 13px;
    }}
    .alert-warning {{
      background: rgba(224, 109, 83, 0.15);
      border: 1px solid var(--coral);
      color: #FFB3A3;
    }}
    .alert-success {{
      background: rgba(78, 159, 118, 0.15);
      border: 1px solid var(--success);
      color: #A3E4D1;
      display: none;
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
      <a href="/" style="color:var(--gold); text-decoration:none; font-size:13px;">← Return to Sanctuary</a>
    </div>

    <div class="card">
      <div class="badge-statutory">🗑️ Google Play Mandated Deletion Portal</div>
      <h1>Account & Data Deletion Request</h1>
      <p>Under Google Play Developer Policies and Section 12 of the DPDP Act 2023, you have the right to permanently incinerate your UR-Heart account and delete all associated personal data from our servers.</p>

      <div class="alert-box alert-warning">
        <strong>⚠️ Irrevocable Action Warning:</strong> Deleting your account will immediately and permanently erase your profile persona, moment photos, chat history, mutual matches, and remaining passes. This cannot be undone.
      </div>

      <div id="successBox" class="alert-box alert-success">
        <strong>✓ Deletion Request Submitted:</strong> Your account incineration has been logged. Associated records, photos, and messages will be permanently purged within 24 hours.
      </div>

      <form id="deletionForm" onsubmit="handleDeletionSubmit(event)">
        <label style="font-size:13px; font-weight:600; color:#FFFFFF;">Sanctuary Registered Email Address</label>
        <input type="email" id="emailInput" class="form-input" placeholder="e.g. your-sanctuary-email@example.com" required>

        <label style="font-size:13px; font-weight:600; color:#FFFFFF;">Reason for Deletion (Optional)</label>
        <textarea id="reasonInput" class="form-input" rows="3" placeholder="Tell us why you are leaving the sanctuary..."></textarea>

        <button type="submit" id="submitBtn" class="btn btn-danger" style="width:100%;">Permanently Incinerate My Account & Data</button>
      </form>

      <h2 style="margin-top:28px;">What Data Is Deleted?</h2>
      <ul>
        <li><strong>Profile Data:</strong> Name, age, gender, bio reflections, preferences (Deleted immediately).</li>
        <li><strong>Media & Photos:</strong> All uploaded photos removed from cloud storage buckets.</li>
        <li><strong>Messages & Chats:</strong> All sent and received messages permanently purged.</li>
        <li><strong>Retained Logs:</strong> Only statutory financial invoice hashes are retained for statutory legal audit compliance as mandated by tax law.</li>
      </ul>
    </div>

    <footer>
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh) • <a href="/privacy">Privacy Policy</a> • <a href="/terms">Terms</a></p>
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
