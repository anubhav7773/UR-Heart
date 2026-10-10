import re
import uuid
import secrets
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends, Form, Request, status, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, text

from app.core.config import get_settings
from app.core.database import get_db
from app.models.domain.user import User
from app.services.data_incinerator_service import DataIncineratorService
from app.services.email_service import EmailService

settings = get_settings()
logger = logging.getLogger(__name__)
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
  .statutory-table-wrap {
    overflow-x: auto;
    margin: 20px 0;
    border-radius: 14px;
    border: 1px solid var(--card-border);
    background: rgba(14, 23, 20, 0.6);
  }
  .statutory-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    min-width: 620px;
  }
  .statutory-table th {
    background: rgba(46, 111, 94, 0.35);
    color: var(--gold);
    font-family: 'Cinzel', Georgia, serif;
    font-weight: 700;
    padding: 12px 14px;
    text-align: left;
    border-bottom: 1px solid var(--card-border);
    white-space: nowrap;
  }
  .statutory-table td {
    padding: 12px 14px;
    border-bottom: 1px solid rgba(43, 61, 53, 0.45);
    color: var(--text-body);
    vertical-align: top;
    line-height: 1.55;
  }
  .statutory-table tr:last-child td {
    border-bottom: none;
  }
  .statutory-table tr:nth-child(even) td {
    background: rgba(22, 33, 29, 0.35);
  }
  .tag {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.3px;
    white-space: nowrap;
  }
  .tag-green { background: rgba(78, 159, 118, 0.2); color: #A3E4D1; border: 1px solid var(--success); }
  .tag-gold { background: rgba(212, 175, 55, 0.15); color: var(--gold); border: 1px solid rgba(212, 175, 55, 0.4); }
  .tag-coral { background: rgba(224, 109, 83, 0.15); color: #FFB3A3; border: 1px solid var(--coral); }
  .tag-blue { background: rgba(56, 148, 255, 0.15); color: #99CAFF; border: 1px solid rgba(56, 148, 255, 0.4); }
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


@router.get("/appinfo", response_class=HTMLResponse)
@router.get("/overview", response_class=HTMLResponse)
async def serve_statutory_appinfo():
    """Serves the complete UR-Heart platform overview on statutory routes."""
    from app.main import get_sanctuary_overview_html
    return HTMLResponse(content=get_sanctuary_overview_html(), status_code=200)


@router.get("/privacy-policy", response_class=HTMLResponse)
@router.get("/privacy", response_class=HTMLResponse)
async def serve_privacy_policy(request: Request):
    """
    Statutory Privacy Policy compliant with:
    - Digital Personal Data Protection (DPDP) Act 2023 (India)
    - Information Technology Act 2000 & IT Rules 2021 (Rule 3(2))
    - Google Play Developer Content Policy & Data Safety Requirements
    - Consumer Protection (E-Commerce) Rules 2020
    """
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy | UR-Heart Mindful Dating Sanctuary</title>
  <meta name="description" content="Statutory Privacy Policy for UR-Heart, operated by Asiverticals (Proprietor: Anubhav Singh). Full statutory compliance with DPDP Act 2023, IT Rules 2021, and Google Play Data Safety standards.">
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
        <span>Published & Legally Effective: October 2026</span>
        <span>•</span>
        <span>Data Fiduciary: <strong>Asiverticals</strong></span>
        <span>•</span>
        <span>Sole Proprietor: <strong>Anubhav Singh</strong></span>
        <span>•</span>
        <span>Jurisdiction: <strong>District Court, Ayodhya, India</strong></span>
      </div>

      <div class="info-callout">
        <strong>Preamble & Sovereign Commitment:</strong> Welcome to <strong>UR-Heart</strong> ("App", "Sanctuary", "Service", "Platform"), conceived, engineered, and operated by <strong>Asiverticals</strong> (Sole Proprietorship, Proprietor: <strong>Anubhav Singh</strong>, Operational Desk: <strong>District Court, Ayodhya, Uttar Pradesh - 224001, India</strong>). We reject surveillance capitalism, manipulative dark patterns, and clandestine ad-tech brokering. Our platform is strictly architected on the foundational principles of <em>Data Minimization, Purpose Limitation, Ephemeral Processing, and User Sovereignty</em>, governed in strict adherence with India's <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong>, the <strong>Information Technology Act, 2000</strong>, the <strong>Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021</strong>, and <strong>Google Play Store Developer Policies</strong>.
      </div>

      <h2>1. Mandatory Age Gating & Minor Protection (DPDP Act Sec 9)</h2>
      <p>UR-Heart is an adult dating and conscious social sanctuary exclusively intended and lawful only for individuals who are <strong>18 years of age or older</strong>. In strict compliance with Section 9 of the DPDP Act 2023 and the Indian Contract Act, 1872, we enforce unbending protocols to exclude minors:</p>
      <ul>
        <li><strong>Zero Minor Processing:</strong> We do not intentionally solicit, process, index, profile, or track any personal data from individuals under 18 years of age. Processing data of a child without verified parental consent is unlawful, and because UR-Heart is an adult dating platform, parental consent for minor access is not accepted.</li>
        <li><strong>Neutral Date-of-Birth (DOB) Selector:</strong> During registration, age verification requires interaction with a neutral date wheel with zero pre-selected adult years, preventing inadvertent or automated bypass. Where supported, the Google Play Age Signals API provides hardware-level age validation.</li>
        <li><strong>180-Day Underage Quarantine Protocol:</strong> If an individual attempts registration with a date of birth below 18 years, the system immediately records an irreversible cryptographic hash of the device and IP subnet in the <code>underage_quarantine_registry</code>, locking out repeated brute-force attempts from that device for 180 days.</li>
        <li><strong>Automated 60-Minute Underage Incineration:</strong> If an existing account is discovered or verified to belong to a minor, our automated quarantine protocol executes irrevocable permanent destruction of all associated photographs, tokens, dialogue histories, and database records within 60 minutes.</li>
        <li><strong>Zero Behavioral Profiling or Advertising Targeted at Children:</strong> Under Section 9(2) and 9(3) of the DPDP Act 2023, we undertake zero tracking or behavioral monitoring of children and serve zero targeted advertisements to minors.</li>
      </ul>

      <h2>2. Itemized Categories of Personal Data Collected & Processed</h2>
      <p>Under Section 5(1) of the DPDP Act 2023, Data Principals are entitled to an exact, itemized disclosure of every category of personal data collected, along with its specific operational purpose. We process only data strictly essential for genuine human connection:</p>

      <div class="statutory-table-wrap">
        <table class="statutory-table">
          <thead>
            <tr>
              <th>Data Category</th>
              <th>Specific Items Collected</th>
              <th>Statutory Purpose & Storage Mechanism</th>
              <th>Retention Standard</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Identity & Authentication</strong></td>
              <td>Chosen Display Name (<code>full_name</code>), Date of Birth (<code>dob</code>), Gender, Romantic Interest (<code>interested_in</code>), Email Address, Google One Tap ID, Installation UUID, Referral Code.</td>
              <td>Account creation, adult age validation, session management via Google One Tap, Brevo & Gmail SMTP transactional passkeys, fraud mitigation.</td>
              <td>Retained during active account lifecycle; wiped on account deletion.</td>
            </tr>
            <tr>
              <td><strong>Persona & Intentional Reflections</strong></td>
              <td>Bio reflection (up to 500 characters), Profession, Education, Preferred Age Range (Min/Max), Values & Lifestyle Prompts.</td>
              <td>Profile discovery feed rendering and compatibility scoring in the 10-daily intentional swipe deck.</td>
              <td>Retained during active account lifecycle; user-editable at any time.</td>
            </tr>
            <tr>
              <td><strong>Photographs & Visual Moments</strong></td>
              <td>Up to 5 authentic moment photographs, Primary Avatar URL.</td>
              <td>Visual identity presentation. Uploaded via signed URLs directly to private Cloudflare R2 object storage (<code>ur-heart-media</code>). Zero public raw bucket access.</td>
              <td>Retained until user updates photo or permanently incinerates account.</td>
            </tr>
            <tr>
              <td><strong>Voice Sparks</strong></td>
              <td>Up to 7.0-second authentic voice recording, Voice Prompt Key, Duration.</td>
              <td>Authentic acoustic presence on discovery profiles. Stored in Cloudflare R2 with signed playback URLs. Never used to train generative AI voice models.</td>
              <td>Retained during active profile lifecycle; replaceable or deletable by user.</td>
            </tr>
            <tr>
              <td><strong>3-Second Biometric KYC Liveness</strong></td>
              <td>Active 3-second live video stream with randomized micro-gestures (blink, smile, head turn).</td>
              <td>Anti-catfish, anti-bot, and authentic seeker verification. Processed in volatile memory by Eva Identity Engine (Groq / OpenRouter Vision / OpenCV). Face-match threshold &ge; 75%.</td>
              <td><strong>Ephemeral Purge Guarantee:</strong> Raw video frames are permanently shredded in &lt; 60 seconds. Only a persistent boolean flag (<code>kyc_status = True</code>) is retained.</td>
            </tr>
            <tr>
              <td><strong>Fuzzy Geolocation (1.1 km Shield)</strong></td>
              <td>Approximate Latitude and Longitude (truncated to 2 decimal places), Broad Location Name.</td>
              <td>Proximity matching. Native hardware telemetry verifies genuine GPS satellite constellation and rejects fake-GPS mock providers. Truncated with a 1.1 km spatial fuzzing offset.</td>
              <td>Exact real-time coordinates are NEVER stored, tracked, or broadcast. Only truncated city/area names displayed.</td>
            </tr>
            <tr>
              <td><strong>Blind Pulse (Sanctuary Blind Date)</strong></td>
              <td>5-minute veiled chat dialogues, session timestamps, bilateral resonance decisions.</td>
              <td>Soul-first matchmaking. Photos are masked with a 35-pixel bilateral blur (<code>sigmaX: 35, sigmaY: 35</code>) and real names hidden until bilateral "Resonate" agreement.</td>
              <td>Ephemeral messages archived or purged upon session conclusion; revealed only on mutual consent.</td>
            </tr>
            <tr>
              <td><strong>1:1 In-App Dialogues & Mindful Closure</strong></td>
              <td>Text-only chat messages, delivery status, 48-hour stagnation flags, "Pass with Grace" closure reflections.</td>
              <td>Private reciprocal communication between matched seekers. Pre-storage neural filtering screens against phone leaks, slurs, and fraud. Zero media/photo sending in chats to prevent cyberflashing.</td>
              <td>Encrypted at rest with per-match keys and in transit (TLS 1.3 / WSS). Stagnant threads after 48h archived gently.</td>
            </tr>
            <tr>
              <td><strong>Sacred Contact Bridge (WhatsApp / Direct Handle)</strong></td>
              <td>Private contact handle (such as WhatsApp phone number).</td>
              <td>Graduated Stage 3 contact reveal. Stored strictly under <strong>AES-256 cryptographic encryption</strong>. Concealed in Stages 1 & 2. Revealed ONLY upon mutual bilateral consent (3 reflection ads each or 1 Reveal Token each).</td>
              <td>Retained encrypted until bilateral reveal or account incineration. Never disclosed unilaterally.</td>
            </tr>
            <tr>
              <td><strong>Billing & Sovereign Entitlements</strong></td>
              <td>Transaction reference ID, product identifier, currency, amount, platform fee, statutory tax invoice hash.</td>
              <td>Digital pass delivery (Google Play Billing & Sovereign Web Store via Razorpay). Raw credit card credentials, CVVs, or UPI PINs never touch our servers.</td>
              <td>Anonymized transaction IDs retained strictly as required by Indian taxation (GST) and audit statutes.</td>
            </tr>
            <tr>
              <td><strong>Device Push Notifications & Telemetry</strong></td>
              <td>Firebase Cloud Messaging (FCM) device registration tokens, installation timestamp, error traces.</td>
              <td>Dispatching intentional notifications (slumber alerts, mindful closures, match alarms). Crash telemetry in Sentry.</td>
              <td>Tokens overwritten on app reinstall; purged on account deletion.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2>3. Purpose of Processing & Unbundled Affirmative Consent (DPDP Act Sec 6)</h2>
      <p>Under Section 6 of the DPDP Act 2023, consent must be free, specific, informed, unconditional, and unambiguous with clear affirmative action. Bundled consent is strictly void. UR-Heart enforces unbundled consent architecture across all touchpoints:</p>
      <ul>
        <li><strong>Independent Consent Notices:</strong> Prior to account creation, seekers are presented with distinct, unbundled consent items covering Digital Personal Data processing, Intermediary Guidelines compliance, and Community Standards. No checkboxes are pre-selected.</li>
        <li><strong>Strict Purpose Limitation:</strong> Your data is used exclusively to deliver the UR-Heart service: calculating resonance scores, curating the 10-daily swipe deck, routing ephemeral blind date sessions, and safeguarding personal boundaries.</li>
        <li><strong>Right to Withdraw Consent (Sec 6(4)):</strong> You may withdraw your consent at any time through the in-app Statutory Legal Vault or by requesting account incineration. Upon withdrawal, processing stops and all data is permanently purged, except where statutory retention is mandated by law.</li>
        <li><strong>Absolute Non-Surveillance Guarantee:</strong> We do NOT sell, rent, monetize, trade, or broker your personal data, photographs, voice recordings, or chat logs to any third-party marketing broker or advertising exchange.</li>
      </ul>

      <h2>4. Artificial Intelligence (AI) Architecture & Processing Disclosures</h2>
      <p>UR-Heart deploys proprietary artificial intelligence orchestrations designed to protect user boundaries, elevate authentic connection, and provide round-the-clock guidance. In full transparency, our Three-Engine AI Architecture operates as follows:</p>
      <ul>
        <li><strong>Engine 1: Eva Identity & Persona Engine:</strong> Specializes in biometric KYC liveness evaluation and profile polishing. Analyzes 3-second micro-gestures against profile portraits using Groq Vision and OpenRouter Vision with local OpenCV safeguards. Transforms minimal seeker prompts into poetic, authentic sanctuary bios. All vision inference is ephemeral; raw image vectors are discarded immediately post-evaluation.</li>
        <li><strong>Engine 2: Eva Companion & 24/7 Concierge:</strong> Serves as your mindful dating wingmate and sanctuary concierge. Capable of answering questions regarding sanctuary features, slumber mode, swipe quotas, streak preservation, and statutory grievance tracking. Governed by strict domain guardrails: Eva strictly declines requests for computer programming, academic homework, politics, financial advice, or hacking, focusing exclusively on intentional dating and emotional wellbeing.</li>
        <li><strong>Engine 3: Gemini Wingman Engine:</strong> Provides realtime, in-dialogue conversational coaching in active 1-on-1 chats. Powered by the Google Gemini API (with seamless failover to OpenRouter and Groq). Synthesizes both seekers' declared values and recent dialogue flow to suggest 3 magnetic reply options: <em>Playful Spark</em> (charm & banter), <em>Deep Resonance</em> (values & depth), and <em>Smooth Segue</em> (low-pressure bridge), along with actionable coach insight.</li>
        <li><strong>Zero Public Model Training Guarantee:</strong> All AI interactions are sandboxed in isolated API inference sessions. User messages, prompts, reflections, and photographs are <strong>NEVER used to train, fine-tune, or reinforce public foundation models</strong> operated by OpenAI, Meta, Google, Groq, or Anthropic.</li>
      </ul>

      <h2>5. Rewarded Ad Networks & Cryptographic Server-Side Verification (SSV)</h2>
      <p>To keep UR-Heart accessible without intrusive paywalls, users may voluntarily watch brief rewarded sponsor advertisements (e.g. 10-second mindful reflection ads to replenish daily swipes, maintain 24-hour streaks, or progress towards contact reveals). We protect your privacy during ad engagement through rigorous safeguards:</p>
      <ul>
        <li><strong>Authorized Ad Networks:</strong> We integrate exclusively with certified digital sellers compliant with the IAB Tech Lab app-ads.txt specification: Google AdMob, Meta Audience Network, Unity Ads, Chartboost, and Liftoff Monetize (Vungle). Our official verification record is published at <a href="/app-ads.txt" style="color:var(--gold); font-weight:600;">urheart.asiverticals.me/app-ads.txt</a>.</li>
        <li><strong>Non-Personalized Ads Mandatory:</strong> All ad requests specify the <code>nonPersonalizedAds: true</code> flag. We do not transmit advertising identifiers (GAID), device fingerprints, or browsing history to ad brokers. Ads are served contextually without cross-app tracking.</li>
        <li><strong>Cryptographic Server-Side Verification (SSV):</strong> In-app rewards are never granted by client-side triggers. All rewards require cryptographic server-side validation using ECDSA keypairs (for Google AdMob) or HMAC-SHA256 pre-shared secrets (for Meta, Unity, Chartboost, Liftoff). Fraudulent or replay callback requests are rejected.</li>
      </ul>

      <h2>6. Hardware-Level Screen Privacy Shield & Client Defense</h2>
      <p>To shield personal moments, private dialogues, and contact credentials from non-consensual capture or distribution, UR-Heart implements comprehensive hardware-level defenses:</p>
      <ul>
        <li><strong>Android FLAG_SECURE Enforcement:</strong> Hardware-level window security is enforced across all 15 sensitive application routes (Profile, Gallery, Vault, 1:1 Chat, Blind Pulse, Direct Letters, KYC Verification) via <code>window_security_service.dart</code>. Android completely blocks screenshots, screen recording, HDMI mirroring, and OS multitasking app previews.</li>
        <li><strong>Web Privacy Veil:</strong> On our web portals, active blur veils and screenshot interception scripts prevent unauthorized capturing of user interfaces.</li>
        <li><strong>Hardware Keystore Token Encryption:</strong> Authentication tokens and cryptographic keys are stored using hardware-backed keystores via <code>FlutterSecureStorage</code> with <code>encryptedSharedPreferences: true</code> on Android and Keychain Access on iOS.</li>
      </ul>

      <h2>7. Statutory Rights of Data Principals (DPDP Act Chapter III)</h2>
      <p>Under Chapter III of the DPDP Act 2023, you hold absolute, sovereign control over your personal data. You may exercise these rights at any time directly through the in-app Statutory Legal Vault or via our official web portals:</p>
      <ul>
        <li><strong>Right to Access & Data Portability (Sec 11):</strong> You have the right to obtain a comprehensive summary of your personal data. You may request an instant, machine-readable JSON archive or a cryptographically signed PDF dossier directly from the in-app Legal Vault (<code>/vault/export-data</code> and <code>/vault/export-pdf</code>).</li>
        <li><strong>Right to Correction & Updating (Sec 12):</strong> You may correct, complete, or update any inaccurate or obsolete personal data, photos, reflections, or preferences directly in your profile settings.</li>
        <li><strong>Right to Irrevocable Erasure / Account Incinerator (Sec 12):</strong> You have the sovereign right to permanently incinerate your account and delete all associated data. This can be executed instantly in-app (Settings &rarr; Statutory Vault) or via our public, app-independent deletion portal at <a href="/delete-account" style="color:var(--gold); font-weight:600;">urheart.asiverticals.me/delete-account</a>. All profile rows, photos in Cloudflare R2, messages, and authentication identities are permanently destroyed within 24 hours.</li>
        <li><strong>Right of Grievance Redressal (Sec 13):</strong> You may register grievances regarding data handling, boundary violations, or harassment directly with our designated Grievance Officer and track resolution status in real time.</li>
        <li><strong>Right to Nominate (Sec 14):</strong> You may designate a trusted legal nominee via the in-app Statutory Vault (<code>/vault/designate-nominee</code>) who will be lawfully authorized to access, manage, or incinerate your sanctuary account in the event of death or permanent incapacity.</li>
      </ul>

      <h2>8. Comprehensive Third-Party Sub-Processors Matrix</h2>
      <p>In accordance with Section 8 of the DPDP Act 2023 and Google Play Data Safety policies, we disclose our complete matrix of technical sub-processors. All sub-processors are bound by strict contractual data protection agreements (DPAs):</p>

      <div class="statutory-table-wrap">
        <table class="statutory-table">
          <thead>
            <tr>
              <th>Sub-Processor & Entity</th>
              <th>Service Provided</th>
              <th>Jurisdiction</th>
              <th>Data Categories Processed</th>
              <th>Security & Safeguards</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Cloudflare, Inc.</strong></td>
              <td>R2 Object Storage & Global CDN / DDoS Mitigation</td>
              <td>USA / Global Edge</td>
              <td>Moment photos, Voice Sparks audio files, static assets.</td>
              <td>AES-256 encryption at rest, private signed ephemeral URLs only, TLS 1.3 in transit.</td>
            </tr>
            <tr>
              <td><strong>Render Services, Inc.</strong></td>
              <td>FastAPI Application Cloud Hosting</td>
              <td>USA (Oregon)</td>
              <td>API requests, transient memory execution of application logic.</td>
              <td>SOC 2 Type II certified, isolated container runtime, TLS 1.3 termination.</td>
            </tr>
            <tr>
              <td><strong>Supabase, Inc. / AWS</strong></td>
              <td>Managed PostgreSQL Relational Database</td>
              <td>Germany / Singapore</td>
              <td>User profiles, matches, encrypted chats, billing hashes, audit logs.</td>
              <td>AES-256 at rest, strict Row-Level Security (RLS) enclaves, TLS 1.3.</td>
            </tr>
            <tr>
              <td><strong>Google LLC (Firebase)</strong></td>
              <td>Authentication & Cloud Messaging (FCM)</td>
              <td>USA / Global</td>
              <td>Phone/Google auth credentials, device push notification tokens.</td>
              <td>ISO 27001, SOC 2 Type II, encrypted token dispatch.</td>
            </tr>
            <tr>
              <td><strong>Google LLC (AdMob & Play Billing)</strong></td>
              <td>Rewarded Video Ads & In-App Purchases</td>
              <td>USA</td>
              <td>Anonymized purchase transaction tokens, non-personalized ad delivery tokens.</td>
              <td>PCI-DSS Level 1 compliant, ECDSA cryptographic SSV.</td>
            </tr>
            <tr>
              <td><strong>Google LLC (Gemini API)</strong></td>
              <td>Engine 3 Dialogue Wingman Coaching</td>
              <td>USA</td>
              <td>Transient dialogue flow snippets and profile interest prompts.</td>
              <td>Enterprise API agreement: zero retention for training public foundation models.</td>
            </tr>
            <tr>
              <td><strong>Brevo (Sendinblue SAS) & Gmail SMTP</strong></td>
              <td>Transactional Email Delivery</td>
              <td>France (EU) / USA</td>
              <td>Registered email, single-use passkeys, deletion verification links, statutory notices.</td>
              <td>GDPR compliant, ISO 27001, TLS-encrypted SMTP delivery.</td>
            </tr>
            <tr>
              <td><strong>Groq, Inc.</strong></td>
              <td>LPU Inference for Eva Identity & KYC</td>
              <td>USA</td>
              <td>Ephemeral KYC liveness frames, bio polishing text prompts.</td>
              <td>Zero persistent model storage; ephemeral stream processing.</td>
            </tr>
            <tr>
              <td><strong>OpenRouter, Inc.</strong></td>
              <td>Failover AI Inference Router</td>
              <td>USA</td>
              <td>Encrypted transient prompts for Eva Companion and Wingman fallback.</td>
              <td>Zero data retention; privacy-preserving routing.</td>
            </tr>
            <tr>
              <td><strong>Razorpay Software Pvt. Ltd.</strong></td>
              <td>Web Store Payment Gateway (UPI / Cards / NetBanking)</td>
              <td>India</td>
              <td>Payment method identifiers, order IDs, billing name (web store only).</td>
              <td>RBI regulated, PCI-DSS Level 1 compliant, 256-bit encryption.</td>
            </tr>
            <tr>
              <td><strong>Meta Platforms, Inc.</strong></td>
              <td>Meta Audience Network Rewarded Ads</td>
              <td>USA</td>
              <td>Non-personalized rewarded video ad impressions.</td>
              <td>HMAC-SHA256 cryptographic SSV, contextual ad delivery.</td>
            </tr>
            <tr>
              <td><strong>Unity Technologies SF</strong></td>
              <td>Unity Ads Rewarded Ads</td>
              <td>USA</td>
              <td>Non-personalized rewarded video ad impressions.</td>
              <td>HMAC-SHA256 cryptographic SSV.</td>
            </tr>
            <tr>
              <td><strong>Chartboost, Inc. & Liftoff Mobile</strong></td>
              <td>Rewarded Video Ads</td>
              <td>USA</td>
              <td>Non-personalized rewarded video ad impressions.</td>
              <td>HMAC-SHA256 cryptographic SSV.</td>
            </tr>
            <tr>
              <td><strong>Functional Software, Inc. (Sentry)</strong></td>
              <td>Application Performance & Crash Diagnostics</td>
              <td>USA</td>
              <td>Strictly Pseudonymized Stack Traces & Error Logs</td>
              <td>Zero PII retention policy, SOC 2 Type II, TLS 1.3 in transit.</td>
            </tr>
            <tr>
              <td><strong>ipwho.is / ip-api.com</strong></td>
              <td>Approximate City-Level IP Geolocation</td>
              <td>Global / CDN</td>
              <td>Ephemeral IP Address (No persistent storage)</td>
              <td>Non-persistent real-time resolution, coarse city level only.</td>
            </tr>
            <tr>
              <td><strong>BigDataCloud Pty Ltd</strong></td>
              <td>Coarse Locality Reverse Geocoding</td>
              <td>Australia</td>
              <td>Fuzzed Coordinate Truncation Vectors</td>
              <td>Fuzzed coordinate resolution, zero persistent user identity.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2>9. Data Retention & Automated Disposal Schedule</h2>
      <p>In accordance with Section 8(7) of the DPDP Act 2023, personal data is retained only for the duration necessary to satisfy the specific purpose for which it was collected. Our automated retention and disposal schedules are set forth below:</p>
      <ul>
        <li><strong>Active Sanctuary Profiles:</strong> Retained for the duration of active use. Accounts dormant for 12 consecutive months receive notice and are queued for automated archiving.</li>
        <li><strong>Biometric Video KYC Frames:</strong> Processed ephemerally in volatile memory. All temporary video blobs and facial frames are permanently shredded in <strong>&lt; 60 seconds</strong> post-verification (<code>kyc_purge.py</code>).</li>
        <li><strong>Blind Pulse Ephemeral Messages:</strong> Maintained in volatile database tables strictly for the 5-minute session duration; archived or purged upon session conclusion.</li>
        <li><strong>Stagnant Chat Dialogues:</strong> Threads with zero messages for 48 hours are flagged as stagnant. If closed via Mindful Closure, the dialogue is archived cleanly without continuous sync overhead.</li>
        <li><strong>Account Incineration (Erasure):</strong> When triggered in-app or via the web portal, cascading permanent deletion across PostgreSQL, Cloudflare R2, and Firebase Auth completes within <strong>24 hours</strong>.</li>
        <li><strong>Statutory Retention Exception:</strong> Anonymized financial transaction reference IDs, order numbers, and tax invoice hashes are retained strictly for the statutory limitation period required by Indian taxation statutes (Section 128 of the Companies Act, 2013 and Section 36 of the Central Goods and Services Tax Act, 2017). These records contain zero chat logs, photos, or biometric data.</li>
      </ul>

      <h2>10. Security Safeguards & Breach Notification Protocol (DPDP Act Sec 8)</h2>
      <p>We deploy defense-in-depth technical and organizational measures to safeguard your personal data:</p>
      <ul>
        <li><strong>Cryptographic Transport Security:</strong> Mandatory TLS 1.3 / HTTPS across all REST API endpoints and WSS across WebSocket channels.</li>
        <li><strong>Database Row-Level Security:</strong> Strict PostgreSQL RLS policies enforce tenant isolation so that no user can query or modify another user's private data.</li>
        <li><strong>Parameterization & SQL Injection Defense:</strong> All database queries use SQLAlchemy parameterized object-relational mapping, rendering SQL injection vectors impossible.</li>
        <li><strong>Strict HTTP Security Headers:</strong> Production servers transmit Strict-Transport-Security (HSTS), X-Content-Type-Options: nosniff, X-Frame-Options: DENY, and granular Content-Security-Policy (CSP) headers.</li>
        <li><strong>Breach Notification Protocol (Sec 8(6)):</strong> In the event of an unavoidable security breach affecting personal data, Asiverticals will inform the Data Protection Board of India (DPBI) and all affected Data Principals in the form and manner prescribed by statutory rules, alongside statutory incident reporting to CERT-In.</li>
      </ul>

      <h2>11. International Data Transfers (DPDP Act Sec 16)</h2>
      <p>UR-Heart is engineered and operated from India. Certain cloud infrastructure services (such as Cloudflare R2 object storage, Render application servers, and Google APIs) maintain global edge networks. In compliance with Section 16 of the DPDP Act 2023, personal data is transferred only to countries and territories that are not blacklisted by the Central Government of India, under strict standard contractual clauses and end-to-end cryptographic encryption.</p>

      <h2>12. Statutory Grievance Redressal Officer (IT Rules 2021 Rule 3(2) & DPDP Act Sec 13)</h2>
      <p>In strict compliance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 and Section 13 of the Digital Personal Data Protection Act, 2023, the full details of our designated Grievance Officer and operational desk are published below:</p>

      <div class="officer-card">
        <div class="officer-header">⚖️ Statutory Grievance Redressal Desk</div>
        <div class="officer-row">
          <strong>Designated Grievance Officer:</strong> 
          <span>Anubhav Singh</span>
        </div>
        <div class="officer-row">
          <strong>Operating Entity:</strong> 
          <span>Asiverticals (Sole Proprietorship, Proprietor: Anubhav Singh)</span>
        </div>
        <div class="officer-row">
          <strong>Registered Operational & Legal Desk:</strong> 
          <span>District Court, Ayodhya, Uttar Pradesh - 224001, India</span>
        </div>
        <div class="officer-row">
          <strong>Statutory Grievance Email:</strong> 
          <a href="mailto:asiverticals@gmail.com?subject=DPDP%202023%20and%20IT%20Rules%202021%20Grievance%20Notice" style="color:var(--gold); font-weight:700; text-decoration:underline;">asiverticals@gmail.com</a>
          <button type="button" onclick="copyContactEmail('asiverticals@gmail.com', this)" class="btn-mini-copy">📋 Copy</button>
        </div>
        <div class="officer-row">
          <strong>Statutory Mandated SLAs:</strong> 
          <span>Formal acknowledgment within <strong>24 hours</strong>; comprehensive investigation and disposal within <strong>15 days</strong> (Internal expedited target: 24 to 48 hours).</span>
        </div>
        <div class="officer-row">
          <strong>In-App Grievance Tracking:</strong> 
          <span>Users may file and monitor formal grievance dossiers with unique reference numbers (e.g. <code>GRV-YYYYMMDD-XXXXXX</code>) directly from the in-app Statutory Legal Vault.</span>
        </div>
      </div>

      <h2>13. Governing Law & Exclusive Jurisdiction</h2>
      <p>This Privacy Policy and all matters arising out of or related to data processing, privacy disputes, or statutory rights shall be governed by and construed in accordance with the laws of the Republic of India. You irrevocably agree that the competent courts situated in <strong>Ayodhya, Uttar Pradesh, India (District Court, Ayodhya)</strong> shall have exclusive jurisdiction over any legal suit, claim, or controversy arising under this Policy.</p>

      <h2>14. Amendments to this Privacy Policy</h2>
      <p>We may update this Privacy Policy periodically to reflect technological advancements, statutory rule enactments by the Data Protection Board of India, or updates to Google Play Developer policies. When material updates are published, we will display an in-app sanctuary notice and dispatch a notification to your registered email address. Continued use of UR-Heart following statutory notice constitutes affirmative acknowledgement of the revised terms.</p>

      <h2>15. Official Regulatory & User Communication Desk</h2>
      <p>For inquiries regarding this Privacy Policy, compliance audits, regulatory correspondence, or exercise of statutory rights, please contact our desk:</p>

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
      <p>© 2026 Asiverticals (Proprietor: Anubhav Singh). All rights reserved. • <a href="/terms">Terms of Service & EULA</a> • <a href="/delete-account">Account Deletion Portal</a> • <a href="/store">Web Sanctuary Store</a> • <a href="/">Web Sanctuary</a></p>
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

      <div id="successBox" class="alert-box alert-success" style="display:none;">
        <strong>✓ Verification Link Dispatched:</strong> If an account exists for this email address, a confirmation email with a secure link has been sent. Please open the link in your inbox within 24 hours to confirm permanent incineration.
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
        <li><strong>Profile & Persona:</strong> Display name, bio reflections, preferences, and age records are deleted from active databases immediately upon confirmation.</li>
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


WEB_DELETION_TOKENS: Dict[str, Dict[str, Any]] = {}


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
    SEC-CRIT-01: Initiates 2-step verification for web account deletion.
    Prevents unauthenticated third-party mass erasure by dispatching a single-use
    cryptographic verification token to the registered email address.
    """
    clean_email = payload.email.strip().lower()
    stmt = select(User).where(User.email == clean_email)
    user = (await db.execute(stmt)).scalar_one_or_none()

    if user:
        token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
        auth_id_val = str(user.auth_id) if getattr(user, "auth_id", None) else None

        # PERSIST TO POSTGRESQL (Survives container restarts - SEC-13 / COMP-01)
        try:
            await db.execute(
                text("""
                    INSERT INTO public.web_deletion_tokens (token, email, user_id, auth_id, expires_at, reason)
                    VALUES (:token, :email, :user_id, :auth_id, :expires_at, :reason)
                    ON CONFLICT (email) DO UPDATE 
                    SET token = :token, expires_at = :expires_at, reason = :reason
                """),
                {
                    "token": token,
                    "email": clean_email,
                    "user_id": user.id,
                    "auth_id": auth_id_val,
                    "expires_at": expires_at,
                    "reason": payload.reason or "Web Statutory Deletion Portal"
                }
            )
            await db.commit()
        except Exception as e:
            await db.rollback()
            logger.warning("DB insert for web_deletion_tokens failed, rolling back session: %s", e)
            # In-memory resilience fallback if database table is unavailable
            WEB_DELETION_TOKENS[token] = {
                "email": clean_email,
                "user_id": str(user.id),
                "auth_id": auth_id_val,
                "expires_at": expires_at,
                "reason": payload.reason or "Web Statutory Deletion Portal"
            }

        base_url = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")
        confirm_url = f"{base_url}/confirm-web-deletion?token={token}"
        await EmailService.dispatch_account_deletion_confirmation(clean_email, confirm_url)
        print(f"[DATA INCINERATOR] Dispatched 2-step confirmation email to {clean_email}", flush=True)

    return {
        "status": "pending_verification",
        "message": "If an account exists for this email address, a verification link has been dispatched to confirm permanent incineration."
    }


@router.get("/confirm-web-deletion", response_class=HTMLResponse)
async def confirm_web_deletion(token: str, db: AsyncSession = Depends(get_db)):
    """
    SEC-CRIT-01 Confirm: Validates single-use cryptographic deletion token and irrevocably incinerates account.
    """
    clean_token = token.strip()
    record: Optional[Dict[str, Any]] = None

    # 1. ATOMIC READ AND CONSUMPTION FROM POSTGRESQL (SEC-13 / COMP-01)
    try:
        token_stmt = text("""
            DELETE FROM public.web_deletion_tokens 
            WHERE token = :token
            RETURNING email, user_id, auth_id, expires_at, reason
        """)
        res = await db.execute(token_stmt, {"token": clean_token})
        row = res.mappings().one_or_none()
        await db.commit()
        if row:
            record = dict(row)
    except Exception as e:
        await db.rollback()
        logger.warning("DB lookup for web_deletion_tokens failed, rolling back session: %s", e)

    if not record:
        record = WEB_DELETION_TOKENS.pop(clean_token, None)
    if not record:
        html = f"""<!DOCTYPE html>
<html>
<head><title>Invalid Link — UR-Heart</title><style>{COMMON_CSS}</style></head>
<body>
  <div class="container" style="max-width: 600px; text-align: center; padding-top: 60px;">
    <div class="card">
      <div style="font-size: 48px; margin-bottom: 16px;">❌</div>
      <h1>Invalid or Expired Link</h1>
      <p style="color: var(--coral);">This account deletion link is invalid or has already been used.</p>
      <p>If you still wish to incinerate your account, please submit a new request at <a href="/delete-account" style="color: var(--gold);">Account Deletion</a>.</p>
    </div>
  </div>
</body>
</html>"""
        return HTMLResponse(content=html, status_code=400)

    if datetime.now(timezone.utc) > record["expires_at"]:
        html = f"""<!DOCTYPE html>
<html>
<head><title>Expired Link — UR-Heart</title><style>{COMMON_CSS}</style></head>
<body>
  <div class="container" style="max-width: 600px; text-align: center; padding-top: 60px;">
    <div class="card">
      <div style="font-size: 48px; margin-bottom: 16px;">⏳</div>
      <h1>Link Expired</h1>
      <p style="color: var(--coral);">This deletion confirmation link expired after 24 hours.</p>
      <p>Please submit a new request at <a href="/delete-account" style="color: var(--gold);">Account Deletion</a>.</p>
    </div>
  </div>
</body>
</html>"""
        return HTMLResponse(content=html, status_code=410)

    clean_email = record["email"]
    audit = await DataIncineratorService.incinerate_user(
        email=clean_email,
        user_id=record.get("user_id"),
        auth_id=record.get("auth_id"),
        db=db
    )
    print(f"[DATA INCINERATOR] Verified 2-step web erasure executed for: {clean_email} | Audit: {audit}", flush=True)

    html = f"""<!DOCTYPE html>
<html>
<head><title>Account Incinerated — UR-Heart</title><style>{COMMON_CSS}</style></head>
<body>
  <div class="container" style="max-width: 600px; text-align: center; padding-top: 60px;">
    <div class="card">
      <div style="font-size: 48px; margin-bottom: 16px;">🕊️</div>
      <h1>Account Permanently Incinerated</h1>
      <p style="color: var(--success); font-weight: 600;">DPDP Act 2023 Section 12 & Google Play Policy Compliance</p>
      <p>All data, moment photographs, 1:1 chat messages, mutual matches, and identity credentials associated with <strong>{clean_email}</strong> have been permanently and irrevocably erased from UR-Heart systems.</p>
      <p style="color: var(--text-muted); font-size: 13px; margin-top: 24px;">Thank you for walking an intentional path with us. You may close this window.</p>
    </div>
  </div>
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)
