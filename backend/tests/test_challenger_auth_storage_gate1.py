"""
Adversarial Challenger 1 Test Suite - Auth & Storage Perimeter Validation (Gate 1).
Empirically attacks:
1. Zero-token superadmin account takeover on /api/v1/auth/verify-magic-link
2. Unauthenticated candidate profile scraping on /api/v1/feed and /api/v1/discovery/feed
3. Path traversal and unauthorized file access on /api/v1/media/voice/{user_id}/{filename}
4. Google sync dev auth bypass with spoofed email and missing/tampered id_token
"""
import uuid
import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.core.database import get_db
from app.models.domain.user import User

client = TestClient(app)


# ==============================================================================
# PERIMETER ATTACK 1: ZERO-TOKEN SUPERADMIN TAKEOVER (/api/v1/auth/verify-magic-link)
# ==============================================================================
class TestPerimeterAttack1ZeroTokenTakeover:
    """
    Adversarial simulation attempting to claim founder/superadmin account
    (asiverticals@gmail.com) with empty, whitespace, null, or fabricated tokens.
    """

    def test_attack_empty_token_with_superadmin_email_blocked(self):
        """Attacker sends token="" with asiverticals@gmail.com -> MUST yield 400 Bad Request."""
        payload = {
            "token": "",
            "email": "asiverticals@gmail.com"
        }
        res = client.post("/api/v1/auth/verify-magic-link", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Invalid, expired, or missing magic link token" in data.get("detail", "")
        assert "access_token" not in data
        assert "token" not in data

    def test_attack_whitespace_token_with_superadmin_email_blocked(self):
        """Attacker sends token="   " with asiverticals@gmail.com -> MUST yield 400 Bad Request."""
        payload = {
            "token": "   ",
            "email": "asiverticals@gmail.com"
        }
        res = client.post("/api/v1/auth/verify-magic-link", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Invalid, expired, or missing magic link token" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_none_token_with_superadmin_email_blocked(self):
        """Attacker sends token=None with asiverticals@gmail.com -> MUST yield 400 Bad Request."""
        payload = {
            "token": None,
            "email": "asiverticals@gmail.com"
        }
        res = client.post("/api/v1/auth/verify-magic-link", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Invalid, expired, or missing magic link token" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_fabricated_token_with_superadmin_email_blocked(self):
        """Attacker sends fabricated token="forged_founder_token_999" -> MUST yield 400 Bad Request."""
        payload = {
            "token": "forged_founder_token_999",
            "email": "asiverticals@gmail.com"
        }
        res = client.post("/api/v1/auth/verify-magic-link", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Invalid, expired, or missing magic link token" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_passkey_empty_with_superadmin_email_blocked(self):
        """Attacker uses passkey field instead of token with empty string -> MUST yield 400 Bad Request."""
        payload = {
            "token": None,
            "passkey": "   ",
            "email": "asiverticals@gmail.com"
        }
        res = client.post("/api/v1/auth/verify-magic-link", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Invalid, expired, or missing magic link token" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_empty_payload_blocked(self):
        """Attacker sends empty body {} -> MUST yield 400 or 422."""
        res = client.post("/api/v1/auth/verify-magic-link", json={})
        assert res.status_code in [400, 422], f"Expected 400 or 422, got {res.status_code}"


# ==============================================================================
# PERIMETER ATTACK 2: UNAUTHENTICATED FEED SCRAPING (/api/v1/feed, /api/v1/discovery/feed)
# ==============================================================================
class TestPerimeterAttack2FeedScraping:
    """
    Adversarial simulation attempting to harvest candidate dating profiles,
    biometrics, locations, and personal bios without valid credentials.
    """

    def test_attack_unauthenticated_get_feed_blocked(self):
        """Direct anonymous GET /api/v1/feed without auth header -> MUST yield 401."""
        res = client.get("/api/v1/feed")
        assert res.status_code == 401, f"Expected 401 on /feed, got {res.status_code}: {res.text}"
        assert "candidates" not in res.json()
        assert "feed" not in res.json()

    def test_attack_unauthenticated_get_discovery_feed_blocked(self):
        """Direct anonymous GET /api/v1/discovery/feed alias without auth header -> MUST yield 401."""
        res = client.get("/api/v1/discovery/feed")
        assert res.status_code == 401, f"Expected 401 on /discovery/feed, got {res.status_code}: {res.text}"
        assert "candidates" not in res.json()
        assert "feed" not in res.json()

    def test_attack_empty_bearer_token_blocked(self):
        """Authorization: Bearer <empty> on /api/v1/feed -> MUST yield 401."""
        res = client.get("/api/v1/feed", headers={"Authorization": "Bearer "})
        assert res.status_code == 401, f"Expected 401 with empty bearer, got {res.status_code}"

    def test_attack_bogus_jwt_token_blocked(self):
        """Authorization: Bearer <forged_jwt> on /api/v1/feed -> MUST yield 401."""
        res = client.get("/api/v1/feed", headers={"Authorization": "Bearer forged.token.signature"})
        assert res.status_code == 401, f"Expected 401 with forged JWT, got {res.status_code}"

    def test_attack_header_injection_spoofing_blocked(self):
        """Attacker attempts X-User-Id / X-Forwarded-User spoofing without Bearer auth -> MUST yield 401."""
        headers = {
            "X-User-Id": str(uuid.uuid4()),
            "X-Forwarded-User": "asiverticals@gmail.com",
            "X-Admin-Role": "superadmin"
        }
        res_feed = client.get("/api/v1/feed", headers=headers)
        assert res_feed.status_code == 401, f"Expected 401 on /feed with spoofed headers, got {res_feed.status_code}"

        res_disc = client.get("/api/v1/discovery/feed", headers=headers)
        assert res_disc.status_code == 401, f"Expected 401 on /discovery/feed with spoofed headers, got {res_disc.status_code}"


# ==============================================================================
# PERIMETER ATTACK 3: PATH TRAVERSAL ON MEDIA ENDPOINT (/api/v1/media/voice)
# ==============================================================================
class TestPerimeterAttack3PathTraversal:
    """
    Adversarial simulation attempting arbitrary local file reads, directory escapes,
    disallowed file extensions (.py, .sh, .exe, .env), and path traversal payloads.
    """

    def test_attack_user_id_dot_dot_slash_traversal_blocked(self):
        """Attacker supplies user_id='..' or '../' -> MUST yield 400 or 404."""
        res = client.get("/api/v1/media/voice/../test.m4a")
        assert res.status_code in [400, 404], f"Expected 400 or 404, got {res.status_code}"

    def test_attack_user_id_url_encoded_traversal_blocked(self):
        """Attacker supplies user_id='%2e%2e%2f%2e%2e%2fetc' -> MUST yield 400 or 404."""
        res = client.get("/api/v1/media/voice/%2e%2e%2f%2e%2e%2fetc/test.m4a")
        assert res.status_code in [400, 404], f"Expected 400 or 404, got {res.status_code}"

    def test_attack_user_id_non_uuid_blocked(self):
        """Attacker supplies non-UUID strings (admin, root, ../passwd) -> MUST yield 400 Bad Request."""
        bad_ids = [
            "admin",
            "root",
            "12345",
            "not-a-valid-uuid",
            "00000000-0000-0000-0000-00000000000Z",
            "../../etc"
        ]
        for bad_id in bad_ids:
            res = client.get(f"/api/v1/media/voice/{bad_id}/test.m4a")
            assert res.status_code in [400, 404], f"User ID '{bad_id}' was not rejected with 400/404, got {res.status_code}"

    def test_attack_disallowed_file_extensions_blocked(self):
        """Attacker requests executable, script, or configuration files (.py, .sh, .exe, .env) -> MUST yield 400."""
        valid_user_id = str(uuid.uuid4())
        forbidden_files = [
            "main.py",
            "payload.sh",
            "malware.exe",
            ".env",
            "settings.json",
            "id_rsa",
            "voice.m4a.py",
            "voice.py.m4a.exe"
        ]
        for bad_file in forbidden_files:
            res = client.get(f"/api/v1/media/voice/{valid_user_id}/{bad_file}")
            assert res.status_code == 400, f"File '{bad_file}' was not rejected with 400, got {res.status_code}"
            assert "Invalid audio file extension" in res.json().get("detail", "")

    def test_attack_filename_relative_traversal_escape_blocked(self):
        """Attacker attempts filename='../../../uploads/voice_spark.m4a' boundary escape -> MUST yield 400, 403, or 404."""
        valid_user_id = str(uuid.uuid4())
        traversal_filenames = [
            "../../../uploads/voice_spark.m4a",
            "..%2f..%2fuploads%2fvoice.m4a",
            "....//....//uploads//voice.m4a"
        ]
        for t_file in traversal_filenames:
            res = client.get(f"/api/v1/media/voice/{valid_user_id}/{t_file}")
            assert res.status_code in [400, 403, 404], f"Traversal '{t_file}' got unexpected {res.status_code}"


# ==============================================================================
# PERIMETER ATTACK 4: GOOGLE SYNC DEV AUTH BYPASS (/api/v1/auth/google-sync)
# ==============================================================================
class TestPerimeterAttack4GoogleSyncBypass:
    """
    Adversarial simulation attempting to register or log into an account
    (including founder/superadmin) by spoofing email without a verified Google id_token.
    """

    def test_attack_google_sync_spoofed_email_without_id_token_blocked(self):
        """Attacker sends email='asiverticals@gmail.com' with id_token=None -> MUST yield 400 Bad Request."""
        payload = {
            "email": "asiverticals@gmail.com",
            "id_token": None,
            "display_name": "Attacker Impersonator"
        }
        res = client.post("/api/v1/auth/google-sync", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Google id_token is required" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_google_sync_spoofed_email_with_empty_id_token_blocked(self):
        """Attacker sends email='victim@urheart.app' with id_token='' -> MUST yield 400 Bad Request."""
        payload = {
            "email": "victim@urheart.app",
            "id_token": "   ",
            "display_name": "Attacker Impersonator"
        }
        res = client.post("/api/v1/auth/google-sync", json=payload)
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Google id_token is required" in data.get("detail", "")
        assert "access_token" not in data

    def test_attack_google_sync_forged_id_token_blocked(self):
        """Attacker sends email='asiverticals@gmail.com' with forged RS256 id_token -> MUST yield 401 Unauthorized."""
        payload = {
            "email": "asiverticals@gmail.com",
            "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImFzaXZlcnRpY2Fsc0BnbWFpbC5jb20ifQ.fake_signature",
            "display_name": "Attacker Impersonator"
        }
        res = client.post("/api/v1/auth/google-sync", json=payload)
        assert res.status_code == 401, f"Expected 401 with forged id_token, got {res.status_code}: {res.text}"
        data = res.json()
        assert "Google ID token signature verification failed" in data.get("detail", "")
        assert "access_token" not in data
