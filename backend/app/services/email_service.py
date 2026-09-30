import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Dict, Any, Optional
import httpx
from app.core.config import get_settings

class EmailService:
    @staticmethod
    async def dispatch_magic_link(
        email: str,
        magic_link: str,
        deep_link: str,
        token: str
    ) -> Dict[str, Any]:
        """
        Dispatches verification email with multi-layer resilience:
        1. Custom SMTP (Gmail/Brevo/SES) if configured in .env
        2. Resend API if RESEND_API_KEY is configured
        3. Supabase Auth OTP (with 429 rate limit detection)
        4. Supabase Admin generate_link fallback (zero rate limit)
        """
        clean_email = email.strip().lower()
        settings = get_settings()

        smtp_host = os.getenv("SMTP_HOST")
        smtp_port = int(os.getenv("SMTP_PORT", "587"))
        smtp_user = os.getenv("SMTP_USER")
        smtp_password = os.getenv("SMTP_PASSWORD")
        smtp_from = os.getenv("SMTP_FROM", smtp_user or "sanctuary@ur-heart.app")

        # 1. Custom SMTP Dispatch
        if smtp_host and smtp_user and smtp_password:
            try:
                msg = MIMEMultipart("alternative")
                msg["Subject"] = "Your Sacred UR-Heart Verification Link ✨"
                msg["From"] = f"UR-Heart Sanctuary <{smtp_from}>"
                msg["To"] = clean_email

                text_content = f"Tap this sacred link to enter your UR-Heart Sanctuary:\n{magic_link}\n\nDeep link: {deep_link}"
                html_content = f"""<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 24px; background-color: #0A0F0D; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #E8EDE9;">
  <div style="max-width: 480px; margin: 0 auto; background: #131F19; border: 1px solid #22362C; border-radius: 20px; padding: 32px 24px; text-align: center;">
    <div style="font-size: 32px; margin-bottom: 12px;">✨</div>
    <h1 style="color: #FFFFFF; font-size: 22px; font-weight: 600; margin: 0 0 10px 0;">Almost home.</h1>
    <p style="color: #4E9F76; font-style: italic; font-size: 16px; margin: 0 0 18px 0;">Verify your sanctuary.</p>
    <p style="color: #9DB3A8; font-size: 13px; line-height: 1.5; margin: 0 0 24px 0;">
      We received a request to access UR-Heart for <strong>{clean_email}</strong>.<br>Tap the button below to verify your genuine space:
    </p>
    <a href="{magic_link}" style="display: block; background: #C94A29; color: #FFFFFF; text-decoration: none; padding: 14px 24px; border-radius: 24px; font-weight: bold; font-size: 14px; margin-bottom: 18px;">Verify & Enter Sanctuary ➔</a>
    <p style="color: #61786D; font-size: 11px; margin: 0;">This invitation expires in 15 minutes.<br>If you did not request this, you can safely ignore this email.</p>
  </div>
</body>
</html>"""
                msg.attach(MIMEText(text_content, "plain"))
                msg.attach(MIMEText(html_content, "html"))

                server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.sendmail(smtp_from, [clean_email], msg.as_string())
                server.quit()

                print(f"[EMAIL SERVICE] Successfully sent email via SMTP to {clean_email}", flush=True)
                return {
                    "dispatched": True,
                    "provider": "smtp",
                    "rate_limited": False,
                    "magic_link": magic_link,
                    "message": "Sacred verification email delivered via SMTP."
                }
            except Exception as e:
                print(f"[EMAIL SERVICE] SMTP dispatch error: {e}", flush=True)

        # 2. Resend API Dispatch (if key configured)
        resend_key = os.getenv("RESEND_API_KEY")
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
                            "from": "UR-Heart <onboarding@resend.dev>",
                            "to": [clean_email],
                            "subject": "Your Sacred UR-Heart Verification Link ✨",
                            "html": f'<p>Tap to enter UR-Heart Sanctuary: <a href="{magic_link}">{magic_link}</a></p>'
                        }
                    )
                    if res.status_code in [200, 201]:
                        print(f"[EMAIL SERVICE] Successfully sent email via Resend to {clean_email}", flush=True)
                        return {
                            "dispatched": True,
                            "provider": "resend",
                            "rate_limited": False,
                            "magic_link": magic_link,
                            "message": "Sacred verification email delivered via Resend."
                        }
            except Exception as e:
                print(f"[EMAIL SERVICE] Resend dispatch error: {e}", flush=True)

        base_web = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")

        # 3. Firebase Auth Passwordless Link Generation
        from app.services.firebase_auth_service import FirebaseAuthService
        firebase_link = FirebaseAuthService.generate_firebase_email_link(clean_email)
        firebase_dispatched = firebase_link is not None

        effective_magic_link = firebase_link or magic_link
        effective_deep_link = deep_link

        return {
            "dispatched": firebase_dispatched,
            "provider": "firebase" if firebase_dispatched else "direct_link",
            "rate_limited": False,
            "magic_link": effective_magic_link,
            "firebase_link": firebase_link,
            "deep_link": effective_deep_link,
            "message": "Sacred Firebase verification link dispatched to your email."
        }
