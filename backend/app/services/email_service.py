import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Dict, Any, Optional
import httpx
from app.core.config import get_settings

def _parse_email_address(full_from: str) -> str:
    if "<" in full_from and ">" in full_from:
        return full_from.split("<")[1].split(">")[0].strip()
    return full_from.strip()

class EmailService:
    @staticmethod
    def send_smtp_payload(
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None
    ) -> bool:
        """
        Dispatches email via Google Gmail SMTP Relay (or configured SMTP_HOST),
        with automatic failover to Brevo SMTP Relay if configured.
        """
        settings = get_settings()
        clean_to = to_email.strip().lower()
        smtp_host = os.getenv("SMTP_HOST") or getattr(settings, "SMTP_HOST", "smtp.gmail.com")
        smtp_port = int(os.getenv("SMTP_PORT") or getattr(settings, "SMTP_PORT", 587))
        smtp_user = os.getenv("SMTP_USER") or getattr(settings, "SMTP_USER", "")
        smtp_password = os.getenv("SMTP_PASSWORD") or getattr(settings, "SMTP_PASSWORD", "")
        smtp_from = os.getenv("SMTP_FROM") or getattr(settings, "SMTP_FROM", "") or f"UR-Heart Sanctuary <{smtp_user}>"
        envelope_from = _parse_email_address(smtp_from) if smtp_from else smtp_user

        # Automated test isolation: Never dispatch real outbound SMTP during tests or for mock domains
        if (
            os.getenv("PYTEST_CURRENT_TEST")
            or clean_to.endswith("@example.com")
            or clean_to.endswith("@test.com")
            or "chall_" in clean_to
        ):
            print(f"[EMAIL SERVICE TEST MOCK] Suppressed outbound SMTP for test address {clean_to}", flush=True)
            return True

        if smtp_host and smtp_user and smtp_password:
            try:
                msg = MIMEMultipart("alternative")
                msg["Subject"] = subject
                msg["From"] = smtp_from
                msg["To"] = clean_to
                if text_body:
                    msg.attach(MIMEText(text_body, "plain"))
                msg.attach(MIMEText(html_body, "html"))

                server = smtplib.SMTP(smtp_host, smtp_port, timeout=12)
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.sendmail(envelope_from, [clean_to], msg.as_string())
                server.quit()
                print(f"[EMAIL SERVICE] Successfully sent email via SMTP ({smtp_host}) to {clean_to}", flush=True)
                return True
            except Exception as e:
                print(f"[EMAIL SERVICE] Primary SMTP error ({smtp_host}): {e}", flush=True)

        # Secondary Brevo SMTP fallback if configured
        brevo_host = os.getenv("BREVO_SMTP_HOST") or getattr(settings, "BREVO_SMTP_HOST", "")
        brevo_user = os.getenv("BREVO_SMTP_USER") or getattr(settings, "BREVO_SMTP_USER", "")
        brevo_pass = os.getenv("BREVO_SMTP_PASSWORD") or getattr(settings, "BREVO_SMTP_PASSWORD", "")
        if brevo_host and brevo_user and brevo_pass:
            try:
                msg = MIMEMultipart("alternative")
                msg["Subject"] = subject
                msg["From"] = f"UR-Heart Sanctuary <{brevo_user}>"
                msg["To"] = clean_to
                if text_body:
                    msg.attach(MIMEText(text_body, "plain"))
                msg.attach(MIMEText(html_body, "html"))

                server = smtplib.SMTP(brevo_host, int(os.getenv("BREVO_SMTP_PORT", "587")), timeout=12)
                server.starttls()
                server.login(brevo_user, brevo_pass)
                server.sendmail(brevo_user, [clean_to], msg.as_string())
                server.quit()
                print(f"[EMAIL SERVICE] Successfully sent email via Brevo SMTP fallback to {clean_to}", flush=True)
                return True
            except Exception as be:
                print(f"[EMAIL SERVICE] Brevo SMTP fallback error: {be}", flush=True)

        return False

    @staticmethod
    async def dispatch_magic_link(
        email: str,
        magic_link: str,
        deep_link: str,
        token: str
    ) -> Dict[str, Any]:
        """
        Dispatches verification email with multi-layer resilience:
        1. Google Gmail SMTP Relay (smtp.gmail.com:587) or Brevo SMTP
        2. Resend REST API if RESEND_API_KEY is configured
        3. Brevo REST API v3 if BREVO_API_KEY is configured
        4. Supabase Auth OTP (with 429 rate limit detection)
        5. Supabase Admin generate_link fallback (zero rate limit)
        """
        clean_email = email.strip().lower()
        if (
            os.getenv("PYTEST_CURRENT_TEST")
            or clean_email.endswith("@example.com")
            or clean_email.endswith("@test.com")
            or "chall_" in clean_email
        ):
            print(f"[EMAIL SERVICE TEST MOCK] Suppressed magic link outbound dispatch for test address {clean_email}", flush=True)
            return {"dispatched": True, "provider": "test_mock", "rate_limited": False}

        settings = get_settings()
        base_web = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")
        store_url = f"{base_web}/store?email={clean_email}"
        subject_line = "✨ Your Sacred Verification Link & Welcome to UR-Heart Sanctuary"

        text_content = f"Welcome to UR-Heart Sanctuary!\nTap this sacred link to verify your space:\n{magic_link}\n\nDeep link: {deep_link}\n\nWeb Store (+10% Bonus): {store_url}"
        html_unified = f"""<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 24px; background-color: #0A0F0D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E8EDE9;">
  <div style="max-width: 540px; margin: 0 auto; background: #131F19; border: 1px solid #22362C; border-radius: 24px; padding: 32px 24px; text-align: center;">
    
    <div style="font-size: 38px; margin-bottom: 10px;">✨</div>
    <h1 style="color: #FFFFFF; font-size: 24px; font-weight: 700; margin: 0 0 8px 0; letter-spacing: 0.5px;">Welcome to UR-Heart Sanctuary</h1>
    <p style="color: #4E9F76; font-style: italic; font-size: 15px; margin: 0 0 18px 0;">Verify your email to enter your genuine space.</p>
    
    <p style="color: #9DB3A8; font-size: 13.5px; line-height: 1.5; margin: 0 0 20px 0;">
      We received a request to access UR-Heart for <strong>{clean_email}</strong>.<br>Tap the sacred key below to verify and enter immediately:
    </p>

    <!-- PROMINENT VERIFICATION ACTION BUTTON -->
    <a href="{magic_link}" style="display: block; background: #C94A29; color: #FFFFFF; text-decoration: none; padding: 16px 24px; border-radius: 26px; font-weight: bold; font-size: 15px; margin-bottom: 12px; box-shadow: 0 4px 16px rgba(201, 74, 41, 0.4);">
      Verify & Enter Sanctuary ➔
    </a>
    <p style="color: #61786D; font-size: 11.5px; margin: 0 0 24px 0;">
      ⏳ This sacred link expires in 15 minutes. If you did not request this, you can safely ignore this email.
    </p>

    <!-- DIVIDER -->
    <div style="border-top: 1px solid #1F2E26; margin-bottom: 22px;"></div>

    <!-- FREE SEEKER GIFTS -->
    <div style="background: rgba(46, 111, 94, 0.15); border: 1px solid rgba(46, 111, 94, 0.4); border-radius: 16px; padding: 18px; margin-bottom: 22px; text-align: left;">
      <div style="color: #A3E4D1; font-weight: bold; font-size: 13px; margin-bottom: 8px;">🎁 YOUR DAILY SEEKER GIFTS</div>
      <div style="font-size: 13px; color: #C8DCD4; line-height: 1.6;">
        • <strong>10 Daily Intentional Swipes</strong> — Refreshed automatically every 24 hours.<br>
        • <strong>AI Liveness KYC Crest</strong> — Free blue tick verification for authentic seekers.<br>
        • <strong>Eva AI Wingman</strong> — Real-time psychological guidance in dialogues.
      </div>
    </div>

    <!-- SOVEREIGN WEB PASSES WITH +10% BONUS -->
    <div style="text-align: left; margin-bottom: 22px;">
      <div style="color: #D4AF37; font-weight: bold; font-size: 13px; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 12px;">
        👑 Sovereign Web Store (+10% Bonus Swipes & Direct Letters)
      </div>
      <p style="color: #829A90; font-size: 12px; margin: 0 0 12px 0; line-height: 1.5;">
        Purchasing passes directly on our official Web Sanctuary gives you <strong>10% extra passes</strong> with instant UPI checkout:
      </p>

      <!-- WEEKLY PASS -->
      <div style="background: #0E1714; border: 1px solid #1F2E26; border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Week Sovereign Sprint</strong>
          <span style="color: #D4AF37; font-weight: bold; font-size: 14px; float: right;">₹49 <small style="color: #829A90; font-size: 11px;">/ 7 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #9DB3A8; clear: both; padding-top: 4px;">• <strong>110 Swipes</strong> (+10% Web Bonus) & 100% Ad-Free Silence</div>
      </div>

      <!-- MONTHLY PASS -->
      <div style="background: rgba(201, 74, 41, 0.12); border: 1px solid rgba(201, 74, 41, 0.4); border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Month Sovereign Pass <span style="background: #C94A29; color: #fff; font-size: 9px; padding: 2px 6px; border-radius: 6px; margin-left: 6px;">MOST POPULAR</span></strong>
          <span style="color: #E06D53; font-weight: bold; font-size: 14px; float: right;">₹149 <small style="color: #829A90; font-size: 11px;">/ 30 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #C8DCD4; clear: both; padding-top: 4px;">• <strong>550 Swipes</strong> (+10% Web Bonus) & <strong>6 Guaranteed Direct Letters</strong><br>• Eva AI Priority Counsel & Sovereign Gold Crest</div>
      </div>

      <!-- 1-YEAR PASS -->
      <div style="background: #0E1714; border: 1px solid #1F2E26; border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Year Sovereign Pass</strong>
          <span style="color: #D4AF37; font-weight: bold; font-size: 14px; float: right;">₹1499 <small style="color: #829A90; font-size: 11px;">/ 365 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #9DB3A8; clear: both; padding-top: 4px;">• 365 Days Sovereign Crest & Unlimited Resonances + 11 Direct Letters</div>
      </div>
    </div>

    <!-- WEB STORE LINK -->
    <a href="{store_url}" style="display: block; background: rgba(201, 74, 41, 0.15); color: #E06D53; border: 1.5px solid #C94A29; text-decoration: none; padding: 12px 20px; border-radius: 22px; font-weight: 600; font-size: 13.5px; margin-bottom: 18px;">
      Explore Sovereign Web Store (+10% Bonus) ➔
    </a>

    <div style="border-top: 1px solid #1F2E26; padding-top: 16px; font-size: 11px; color: #50665B;">
      UR-Heart Sanctuary • Asiverticals (Sole Proprietor: Anubhav Singh)<br>
      Saket, Ayodhya, Uttar Pradesh, India • <a href="{base_web}/privacy" style="color: #829A90;">Privacy Policy</a> • <a href="{base_web}/terms" style="color: #829A90;">Terms</a>
    </div>

  </div>
</body>
</html>"""

        # 1. Google Gmail SMTP Relay / Dedicated SMTP
        smtp_success = EmailService.send_smtp_payload(
            to_email=clean_email,
            subject=subject_line,
            html_body=html_unified,
            text_body=text_content
        )
        if smtp_success:
            return {
                "dispatched": True,
                "provider": "gmail_smtp",
                "rate_limited": False,
                "magic_link": magic_link,
                "message": "Sacred verification & welcome email delivered via Gmail SMTP."
            }

        # 2. Resend API Dispatch (Production-grade transactional delivery)
        resend_key = os.getenv("RESEND_API_KEY") or getattr(settings, "RESEND_API_KEY", "")
        if resend_key:
            from_sender = os.getenv("RESEND_FROM") or getattr(settings, "RESEND_FROM", "") or "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    res = await client.post(
                        "https://api.resend.com/emails",
                        headers={
                            "Authorization": f"Bearer {resend_key}",
                            "Content-Type": "application/json"
                        },
                        json={
                            "from": from_sender,
                            "to": [clean_email],
                            "subject": subject_line,
                            "html": html_unified
                        }
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Successfully sent email via Resend to {clean_email} (id={res.json().get('id')})", flush=True)
                        return {
                            "dispatched": True,
                            "provider": "resend",
                            "rate_limited": False,
                            "magic_link": magic_link,
                            "deep_link": deep_link,
                            "message": "Sacred verification & welcome email delivered via Resend."
                        }
                    else:
                        print(f"[EMAIL SERVICE] Resend notice ({res.status_code}): {res.text}", flush=True)
            except Exception as e:
                print(f"[EMAIL SERVICE] Resend dispatch error: {e}", flush=True)

        base_web = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")

        # 3. Firebase Auth Direct Email Dispatch via Identity Toolkit API
        from app.services.firebase_auth_service import FirebaseAuthService
        firebase_sent = await FirebaseAuthService.dispatch_firebase_email(clean_email)
        if firebase_sent:
            return {
                "dispatched": True,
                "provider": "firebase",
                "rate_limited": False,
                "magic_link": magic_link,
                "deep_link": deep_link,
                "message": "Sacred Firebase verification link dispatched to your email."
            }

        # 4. Supabase OTP Email Dispatch Fallback (when Firebase hits QUOTA_EXCEEDED)
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if supabase_url and supabase_key:
            try:
                headers = {
                    "apikey": supabase_key,
                    "Authorization": f"Bearer {supabase_key}",
                    "Content-Type": "application/json"
                }
                otp_payload = {
                    "email": clean_email,
                    "create_user": True,
                    "options": {
                        "email_redirect_to": f"{base_web}/api/v1/auth/verify?email={clean_email}"
                    }
                }
                async with httpx.AsyncClient(timeout=10.0) as client:
                    res = await client.post(f"{supabase_url}/auth/v1/otp", headers=headers, json=otp_payload)
                    if res.status_code == 200:
                        print(f"[EMAIL SERVICE] Dispatched via Supabase fallback to {clean_email}", flush=True)
                        return {
                            "dispatched": True,
                            "provider": "supabase",
                            "rate_limited": False,
                            "magic_link": magic_link,
                            "deep_link": deep_link,
                            "message": "Sacred verification email dispatched via Supabase fallback."
                        }
                    else:
                        print(f"[EMAIL SERVICE] Supabase fallback notice ({res.status_code}): {res.text}", flush=True)
            except Exception as e:
                print(f"[EMAIL SERVICE] Supabase fallback error: {e}", flush=True)

        # 5. Direct verification link (fallback)
        return {
            "dispatched": False,
            "provider": "direct_link",
            "rate_limited": True,
            "magic_link": magic_link,
            "deep_link": deep_link,
            "message": "Verification link generated. Email providers temporarily rate-limited."
        }

    @staticmethod
    async def dispatch_escalation_alert(
        ticket_id: str,
        category: str,
        user_name: str,
        user_id: str,
        user_message: str,
        recipient_email: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Dispatches real-time statutory support escalation email to the Founder
        (asiverticals@gmail.com) via Resend or SMTP.
        """
        settings = get_settings()
        dest_email = (recipient_email or getattr(settings, "SUPERADMIN_EMAIL", "") or "asiverticals@gmail.com").strip().lower()
        resend_key = os.getenv("RESEND_API_KEY") or getattr(settings, "RESEND_API_KEY", "")
        from_sender = os.getenv("RESEND_FROM") or getattr(settings, "RESEND_FROM", "") or "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"

        html_body = f"""<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 24px; background-color: #0A0F0D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #E8EDE9;">
  <div style="max-width: 560px; margin: 0 auto; background: #131F19; border: 1.5px solid #C5A059; border-radius: 16px; padding: 28px 24px;">
    <div style="display: flex; align-items: center; margin-bottom: 16px;">
      <span style="font-size: 26px; margin-right: 10px;">🚨</span>
      <h2 style="color: #C5A059; font-size: 20px; font-weight: 700; margin: 0;">UR-Heart Critical Support Escalation</h2>
    </div>
    <p style="color: #9DB3A8; font-size: 13px; line-height: 1.5; margin: 0 0 18px 0;">
      A seeker inquiry reached the 10% critical escalation threshold. A formal dossier has been recorded.
    </p>

    <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 13px;">
      <tr>
        <td style="padding: 6px 0; color: #61786D; width: 140px;">Ticket Reference:</td>
        <td style="padding: 6px 0; color: #FFFFFF; font-weight: bold;">{ticket_id}</td>
      </tr>
      <tr>
        <td style="padding: 6px 0; color: #61786D;">Category:</td>
        <td style="padding: 6px 0; color: #E57373; font-weight: bold;">{category}</td>
      </tr>
      <tr>
        <td style="padding: 6px 0; color: #61786D;">Seeker Name:</td>
        <td style="padding: 6px 0; color: #FFFFFF;">{user_name}</td>
      </tr>
      <tr>
        <td style="padding: 6px 0; color: #61786D;">User ID:</td>
        <td style="padding: 6px 0; color: #9DB3A8; font-family: monospace;">{user_id}</td>
      </tr>
      <tr>
        <td style="padding: 6px 0; color: #61786D;">Statutory SLA:</td>
        <td style="padding: 6px 0; color: #4E9F76;">24-48h Expedited Review (IT Rules 2021)</td>
      </tr>
    </table>

    <div style="background: #0A0F0D; border-left: 3px solid #C5A059; padding: 12px 16px; border-radius: 6px; margin-bottom: 24px;">
      <p style="color: #61786D; font-size: 11px; margin: 0 0 4px 0; text-transform: uppercase; letter-spacing: 0.5px;">User Inquiry / Evidence Summary</p>
      <p style="color: #D1E7DD; font-size: 13.5px; line-height: 1.45; margin: 0;">{user_message}</p>
    </div>

    <div style="text-align: center; margin-bottom: 16px;">
      <a href="https://urheart.asiverticals.me/settings" style="display: inline-block; background: #C5A059; color: #0A0F0D; text-decoration: none; padding: 12px 24px; border-radius: 20px; font-weight: bold; font-size: 13px;">Open Sovereign Sentinel Desk ➔</a>
    </div>

    <p style="color: #61786D; font-size: 11px; text-align: center; margin: 0;">
      Automated dispatch by Eva Sovereign Support Engine · Asiverticals Pvt Ltd
    </p>
  </div>
</body>
</html>"""

        # 1. Resend API
        if resend_key:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    res = await client.post(
                        "https://api.resend.com/emails",
                        headers={
                            "Authorization": f"Bearer {resend_key}",
                            "Content-Type": "application/json"
                        },
                        json={
                            "from": from_sender,
                            "to": [dest_email],
                            "subject": f"🚨 [UR-Heart Support Escalation] #{ticket_id} ({category})",
                            "html": html_body
                        }
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Escalation alert emailed via Resend to {dest_email} (id={res.json().get('id')})", flush=True)
                        return {"dispatched": True, "provider": "resend", "id": res.json().get("id")}
                    else:
                        print(f"[EMAIL SERVICE] Resend alert error ({res.status_code}): {res.text}", flush=True)
            except Exception as e:
                print(f"[EMAIL SERVICE] Resend alert exception: {e}", flush=True)

        # 2. SMTP fallback (Google Gmail SMTP or Brevo SMTP)
        smtp_success = EmailService.send_smtp_payload(
            to_email=dest_email,
            subject=f"🚨 [UR-Heart Support Escalation] #{ticket_id} ({category})",
            html_body=html_body
        )
        if smtp_success:
            return {"dispatched": True, "provider": "gmail_smtp"}

        return {"dispatched": False, "provider": "none"}

    @staticmethod
    async def dispatch_account_deletion_confirmation(
        email: str,
        confirmation_link: str
    ) -> Dict[str, Any]:
        """
        Dispatches mandatory 2-step verification email for public web account deletion.
        Prevents unauthorized deletion of user accounts by unauthenticated third parties.
        """
        clean_email = email.strip().lower()
        settings = get_settings()

        html_body = f"""<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 24px; background-color: #0A0F0D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E8EDE9;">
  <div style="max-width: 520px; margin: 0 auto; background: #131F19; border: 1px solid #C94A29; border-radius: 20px; padding: 32px 24px; text-align: center;">
    <div style="font-size: 36px; margin-bottom: 12px;">⚠️</div>
    <h1 style="color: #FFFFFF; font-size: 22px; font-weight: 700; margin: 0 0 10px 0;">Permanent Account Deletion Request</h1>
    <p style="color: #E06D53; font-weight: 600; font-size: 15px; margin: 0 0 18px 0;">UR-Heart Sanctuary Identity Incinerator</p>
    <p style="color: #9DB3A8; font-size: 13px; line-height: 1.6; margin: 0 0 24px 0; text-align: left;">
      We received a formal request to permanently delete the UR-Heart account associated with <strong>{clean_email}</strong>.<br><br>
      <strong>What happens when confirmed:</strong><br>
      • All profile photos and moments in cloud storage will be permanently wiped.<br>
      • All 1:1 chat dialogue histories and matches will be incinerated.<br>
      • Your account identity across Firebase, Supabase, and PostgreSQL will be irrevocably destroyed.<br><br>
      <em>If you submitted this request, click the button below to confirm permanent deletion within 24 hours:</em>
    </p>
    <a href="{confirmation_link}" style="display: block; background: #C94A29; color: #FFFFFF; text-decoration: none; padding: 14px 24px; border-radius: 24px; font-weight: bold; font-size: 14px; margin-bottom: 20px;">Confirm & Permanently Delete Account ➔</a>
    <p style="color: #61786D; font-size: 11px; margin: 0; line-height: 1.5;">
      🛡️ <strong>Did not request this?</strong> Ignore this message. Your account remains fully secure and active. No data will be deleted without this confirmation link.
    </p>
  </div>
</body>
</html>"""

        # 1. Resend API Dispatch
        resend_key = os.getenv("RESEND_API_KEY") or getattr(settings, "RESEND_API_KEY", "")
        if resend_key:
            from_sender = os.getenv("RESEND_FROM") or getattr(settings, "RESEND_FROM", "") or "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    res = await client.post(
                        "https://api.resend.com/emails",
                        headers={
                            "Authorization": f"Bearer {resend_key}",
                            "Content-Type": "application/json"
                        },
                        json={
                            "from": from_sender,
                            "to": [clean_email],
                            "subject": "⚠️ Confirm Permanent Account Deletion — UR-Heart",
                            "html": html_body
                        }
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Deletion confirmation emailed via Resend to {clean_email}", flush=True)
                        return {"dispatched": True, "provider": "resend"}
            except Exception as e:
                print(f"[EMAIL SERVICE] Resend deletion notice error: {e}", flush=True)

        # 2. SMTP Fallback (Google Gmail SMTP or Brevo SMTP)
        smtp_success = EmailService.send_smtp_payload(
            to_email=clean_email,
            subject="⚠️ Confirm Permanent Account Deletion — UR-Heart",
            html_body=html_body
        )
        if smtp_success:
            return {"dispatched": True, "provider": "gmail_smtp"}

        return {"dispatched": False, "provider": "none"}

    @staticmethod
    async def dispatch_welcome_sanctuary_email(
        email: str,
        full_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Dispatches luxury Welcome to UR-Heart email to newly registered seekers.
        Educates the user on 10 free daily swipes, KYC verification, and showcases
        the Sovereign Web Store passes with +10% bonus perks and zero Google commission.
        Implements dual-provider cascade: Resend API -> Brevo SMTP.
        """
        clean_email = email.strip().lower()
        if (
            os.getenv("PYTEST_CURRENT_TEST")
            or clean_email.endswith("@example.com")
            or clean_email.endswith("@test.com")
            or "chall_" in clean_email
        ):
            print(f"[EMAIL SERVICE TEST MOCK] Suppressed welcome email outbound dispatch for test address {clean_email}", flush=True)
            return {"dispatched": True, "provider": "test_mock"}

        settings = get_settings()
        display_name = full_name.strip() if (full_name and full_name.strip()) else "Seeker"
        base_web = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")
        store_url = f"{base_web}/store?email={clean_email}"

        html_body = f"""<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 24px; background-color: #0A0F0D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E8EDE9;">
  <div style="max-width: 540px; margin: 0 auto; background: #131F19; border: 1px solid #22362C; border-radius: 24px; padding: 32px 24px; text-align: center;">
    
    <div style="font-size: 38px; margin-bottom: 10px;">✨</div>
    <h1 style="color: #FFFFFF; font-size: 24px; font-weight: 700; margin: 0 0 8px 0; letter-spacing: 0.5px;">Welcome to UR-Heart Sanctuary</h1>
    <p style="color: #4E9F76; font-style: italic; font-size: 15px; margin: 0 0 20px 0;">Mindful, authentic connection starts here, {display_name}.</p>
    
    <p style="color: #9DB3A8; font-size: 13.5px; line-height: 1.6; margin: 0 0 24px 0; text-align: left;">
      You have entered a conscious sanctuary built for slow, genuine human connection — far away from superficial swipe culture.
    </p>

    <!-- FREE SEEKER PERKS -->
    <div style="background: rgba(46, 111, 94, 0.15); border: 1px solid rgba(46, 111, 94, 0.4); border-radius: 16px; padding: 18px; margin-bottom: 24px; text-align: left;">
      <div style="color: #A3E4D1; font-weight: bold; font-size: 13px; margin-bottom: 8px;">🎁 YOUR DAILY SEEKER GIFTS</div>
      <div style="font-size: 13px; color: #C8DCD4; line-height: 1.6;">
        • <strong>10 Daily Intentional Swipes</strong> — Refreshed automatically every 24 hours.<br>
        • <strong>AI Liveness KYC Crest</strong> — Free blue tick verification for authentic seekers.<br>
        • <strong>Eva AI Wingman</strong> — Real-time psychological guidance in dialogues.
      </div>
    </div>

    <!-- SOVEREIGN WEB PASSES WITH +10% BONUS -->
    <div style="text-align: left; margin-bottom: 24px;">
      <div style="color: #D4AF37; font-weight: bold; font-size: 13px; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 12px;">
        👑 Sovereign Web Store (+10% Bonus Swipes & Direct Letters)
      </div>
      <p style="color: #829A90; font-size: 12px; margin: 0 0 14px 0; line-height: 1.5;">
        Purchasing passes directly on our official Web Sanctuary gives you <strong>10% extra passes</strong> with instant UPI checkout:
      </p>

      <!-- WEEKLY PASS -->
      <div style="background: #0E1714; border: 1px solid #1F2E26; border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Week Sovereign Sprint</strong>
          <span style="color: #D4AF37; font-weight: bold; font-size: 14px; float: right;">₹49 <small style="color: #829A90; font-size: 11px;">/ 7 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #9DB3A8; clear: both; padding-top: 4px;">• <strong>110 Swipes</strong> (+10% Web Bonus) & 100% Ad-Free Silence</div>
      </div>

      <!-- MONTHLY PASS -->
      <div style="background: rgba(201, 74, 41, 0.12); border: 1px solid rgba(201, 74, 41, 0.4); border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Month Sovereign Pass <span style="background: #C94A29; color: #fff; font-size: 9px; padding: 2px 6px; border-radius: 6px; margin-left: 6px;">MOST POPULAR</span></strong>
          <span style="color: #E06D53; font-weight: bold; font-size: 14px; float: right;">₹149 <small style="color: #829A90; font-size: 11px;">/ 30 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #C8DCD4; clear: both; padding-top: 4px;">• <strong>550 Swipes</strong> (+10% Web Bonus) & <strong>6 Guaranteed Direct Letters</strong><br>• Eva AI Priority Counsel & Sovereign Gold Crest</div>
      </div>

      <!-- 1-YEAR PASS -->
      <div style="background: #0E1714; border: 1px solid #1F2E26; border-radius: 12px; padding: 14px; margin-bottom: 10px;">
        <div style="margin-bottom: 4px;">
          <strong style="color: #FFFFFF; font-size: 14px;">1-Year Sovereign Pass</strong>
          <span style="color: #D4AF37; font-weight: bold; font-size: 14px; float: right;">₹1499 <small style="color: #829A90; font-size: 11px;">/ 365 Days</small></span>
        </div>
        <div style="font-size: 12px; color: #9DB3A8; clear: both; padding-top: 4px;">• 365 Days Sovereign Crest & Unlimited Resonances + 11 Direct Letters</div>
      </div>
    </div>

    <!-- CTA BUTTON -->
    <a href="{store_url}" style="display: block; background: #C94A29; color: #FFFFFF; text-decoration: none; padding: 15px 24px; border-radius: 26px; font-weight: bold; font-size: 14.5px; margin-bottom: 16px;">
      Visit Web Store & Claim +10% Bonus Passes ➔
    </a>

    <p style="color: #829A90; font-size: 11px; margin: 0 0 16px 0; line-height: 1.5;">
      💳 Instant checkout via UPI (GPay, PhonePe, Paytm), Cards, & NetBanking.<br>
      <em>Passes purchased on the Web Store automatically activate in your app within 2 seconds.</em>
    </p>

    <div style="border-top: 1px solid #1F2E26; padding-top: 16px; font-size: 11px; color: #50665B;">
      UR-Heart Sanctuary • Asiverticals (Sole Proprietor: Anubhav Singh)<br>
      Saket, Ayodhya, Uttar Pradesh, India • <a href="{base_web}/privacy" style="color: #829A90;">Privacy Policy</a> • <a href="{base_web}/terms" style="color: #829A90;">Terms</a>
    </div>

  </div>
</body>
</html>"""

        # 1. Primary Dispatch: Resend REST API
        resend_key = os.getenv("RESEND_API_KEY") or getattr(settings, "RESEND_API_KEY", "")
        if resend_key:
            from_sender = os.getenv("RESEND_FROM") or getattr(settings, "RESEND_FROM", "") or "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    res = await client.post(
                        "https://api.resend.com/emails",
                        headers={
                            "Authorization": f"Bearer {resend_key}",
                            "Content-Type": "application/json"
                        },
                        json={
                            "from": from_sender,
                            "to": [clean_email],
                            "subject": "✨ Welcome to UR-Heart Sanctuary (+10% Bonus Web Passes)",
                            "html": html_body
                        }
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Welcome email sent via Resend to {clean_email}", flush=True)
                        return {"dispatched": True, "provider": "resend"}
                    else:
                        print(f"[EMAIL SERVICE] Resend welcome email error ({res.status_code}): {res.text}", flush=True)
            except Exception as e:
                print(f"[EMAIL SERVICE] Resend welcome email exception: {e}", flush=True)

        # 2. Secondary Dispatch: Google Gmail SMTP Relay (or Brevo SMTP fallback)
        smtp_success = EmailService.send_smtp_payload(
            to_email=clean_email,
            subject="✨ Welcome to UR-Heart Sanctuary (+10% Bonus Web Passes)",
            html_body=html_body
        )
        if smtp_success:
            return {"dispatched": True, "provider": "gmail_smtp"}

        # 3. Tertiary Dispatch: Brevo REST API v3
        brevo_key = os.getenv("BREVO_API_KEY")
        if brevo_key:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    brevo_payload = {
                        "sender": {"name": "UR-Heart Sanctuary", "email": "asiverticals@gmail.com"},
                        "to": [{"email": clean_email, "name": display_name}],
                        "subject": "✨ Welcome to UR-Heart Sanctuary (+10% Bonus Web Passes)",
                        "htmlContent": html_body
                    }
                    res = await client.post(
                        "https://api.brevo.com/v3/smtp/email",
                        headers={
                            "api-key": brevo_key,
                            "Content-Type": "application/json",
                            "Accept": "application/json"
                        },
                        json=brevo_payload
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Welcome email sent via Brevo API v3 to {clean_email}", flush=True)
                        return {"dispatched": True, "provider": "brevo_api"}
                    else:
                        print(f"[EMAIL SERVICE] Brevo API welcome notice ({res.status_code}): {res.text}", flush=True)
            except Exception as e:
                print(f"[EMAIL SERVICE] Brevo API welcome exception: {e}", flush=True)

        return {"dispatched": False, "provider": "none"}


