import uuid
import pytest
from datetime import date
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.core.config import Settings, validate_production_env
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User

client = TestClient(app)

def create_mock_user(user_id=None, email="seeker@urheart.in"):
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        auth_id=uuid.uuid4(),
        email=email,
        full_name="Mindful Seeker",
        role="user",
        subscription_tier="free",
        dob=date(2000, 1, 1),
        gender="Man",
        interested_in="Woman",
        contact_bridge_encrypted="enc_bridge",
        referral_code="REF" + uid.hex[:8].upper()
    )


# ==============================================================================
# 1. TEST SEC-HIGH-01: Missing Secret Fail-Fast Test
# ==============================================================================
def test_missing_secret_fail_fast_assertion():
    """
    CRITERIA 1 (SEC-HIGH-01):
    In production environment, unsetting or supplying an insecure (<32 char) JWT_SECRET
    must immediately trigger a fatal validation error and refuse to boot on static defaults.
    """
    # Attempting to instantiate Settings in production with empty JWT_SECRET_KEY
    with pytest.raises((ValueError, RuntimeError)) as excinfo:
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="",
            FIREBASE_PROJECT_ID="ur-heart-44b46",
            SUPABASE_SERVICE_ROLE_KEY="test-supabase-key",
            REVENUECAT_WEBHOOK_SECRET="test-rc-secret"
        )
    assert "FATAL PRODUCTION SECURITY ERROR" in str(excinfo.value)
    assert "JWT_SECRET_KEY" in str(excinfo.value)

    # Insecure short secret (< 32 chars) must also fail fast
    with pytest.raises((ValueError, RuntimeError)) as excinfo_short:
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="short-secret-under-32-bytes",
            FIREBASE_PROJECT_ID="ur-heart-44b46",
            SUPABASE_SERVICE_ROLE_KEY="test-supabase-key",
            REVENUECAT_WEBHOOK_SECRET="test-rc-secret"
        )
    assert "FATAL PRODUCTION SECURITY ERROR" in str(excinfo_short.value)

    # Missing other mandatory secrets (e.g. SUPABASE_SERVICE_ROLE_KEY)
    with pytest.raises((ValueError, RuntimeError)) as excinfo_supa:
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="a" * 32,
            FIREBASE_PROJECT_ID="ur-heart-44b46",
            SUPABASE_SERVICE_ROLE_KEY="",
            REVENUECAT_WEBHOOK_SECRET="test-rc-secret"
        )
    assert "SUPABASE_SERVICE_ROLE_KEY" in str(excinfo_supa.value)


# ==============================================================================
# 2. TEST SEC-HIGH-03: Unauthenticated AI Endpoint Rejection & Quota Protection
# ==============================================================================
def test_unauthenticated_ai_endpoint_rejection():
    """
    CRITERIA 2 (SEC-HIGH-03):
    Requests to AI endpoints without Authorization must be rejected with HTTP 401 Unauthorized.
    Groq service layer must never be invoked by anonymous bots.
    """
    # 1. /api/v1/ai/eva/chat
    chat_res = client.post("/api/v1/ai/eva/chat", json={"message": "Hello Eva"})
    assert chat_res.status_code == 401, f"Expected 401 on unauth /ai/eva/chat, got {chat_res.status_code}"

    # 2. /api/v1/ai/bio-polish
    polish_res = client.post("/api/v1/ai/bio-polish", json={"raw_bio": "Mindful traveler and reader"})
    assert polish_res.status_code == 401, f"Expected 401 on unauth /ai/bio-polish, got {polish_res.status_code}"

    # 3. /api/v1/ai/icebreakers
    ice_res = client.post("/api/v1/ai/icebreakers", json={
        "user_a": {"bio": "Reading and tea"},
        "user_b": {"bio": "Gardening and morning walks"}
    })
    assert ice_res.status_code == 401, f"Expected 401 on unauth /ai/icebreakers, got {ice_res.status_code}"

    # 4. Message length ceiling: authenticated chat request with >300 chars must be rejected with 422
    user = create_mock_user()
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        excessive_message = "A" * 301
        excessive_res = client.post(
            "/api/v1/ai/eva/chat",
            headers={"Authorization": "Bearer test_token"},
            json={"message": excessive_message}
        )
        assert excessive_res.status_code == 422, f"Expected 422 on excessive message length, got {excessive_res.status_code}"
    finally:
        app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 3. TEST SEC-MED-01: Restrictive CORS Isolation & Origin Whitelist
# ==============================================================================
def test_cors_boundary_enforcement():
    """
    CRITERIA 3 (SEC-MED-01):
    Unauthorized origin must not receive Access-Control-Allow-Origin header,
    and wildcard '*' origin must be completely absent.
    Authorized domains receive authentic CORS origin header.
    """
    # 1. Unauthorized origin probe
    evil_headers = {
        "Origin": "https://evil-attacker-site.com",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "Authorization,Content-Type"
    }
    evil_res = client.options("/api/v1/profile/me", headers=evil_headers)
    allow_origin = evil_res.headers.get("access-control-allow-origin")
    # Must NOT be wildcard '*' and must NOT allow evil-attacker-site.com
    assert allow_origin != "*", "Security failure: Wildcard CORS '*' detected!"
    assert allow_origin != "https://evil-attacker-site.com", "Security failure: Evil origin was permitted!"

    # 2. Authorized canonical domain check
    auth_headers = {
        "Origin": "https://urheart.app",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "Authorization"
    }
    auth_res = client.options("/api/v1/profile/me", headers=auth_headers)
    assert auth_res.headers.get("access-control-allow-origin") == "https://urheart.app"


# ==============================================================================
# 4. TEST SEC-MED-05: Geolocation Precision Truncation (DPDP Privacy Shield)
# ==============================================================================
def test_geolocation_precision_truncation():
    """
    CRITERIA 4 (SEC-MED-05):
    Passing 6-decimal high-precision GPS coordinates (e.g. 26.792184, 82.199823)
    must be truncated/rounded strictly to 2 decimal places (26.79, 82.20)
    to enforce statutory DPDP ~1.1km fuzzy radius and prevent home address stalking.
    """
    user = create_mock_user()
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # A. Direct User model validator test
        user.latitude = 26.792184
        user.longitude = 82.199823
        assert float(user.latitude) == 26.79, f"Model failed to truncate latitude: {user.latitude}"
        assert float(user.longitude) == 82.20, f"Model failed to truncate longitude: {user.longitude}"

        # B. API endpoint update test (/api/v1/profile/me)
        payload = {
            "latitude": 26.792184,
            "longitude": 82.199823,
            "location_name": "Saket, Ayodhya"
        }
        res = client.put(
            "/api/v1/profile/me",
            headers={"Authorization": "Bearer mock_token"},
            json=payload
        )
        assert res.status_code == 200

        # Verify that db.execute received values with truncated 2-decimal coordinates
        execute_calls = mock_db.execute.call_args_list
        assert len(execute_calls) > 0
        called_stmt = execute_calls[0][0][0]

        # Check compiled/extracted update parameters
        compiled_params = getattr(called_stmt, "_values", {})
        # Look for latitude/longitude in update parameters
        param_dict = {}
        for col, val in compiled_params.items():
            col_name = getattr(col, "name", str(col))
            raw_val = getattr(val, "value", val)
            param_dict[col_name] = raw_val

        if "latitude" in param_dict:
            assert param_dict["latitude"] == 26.79, f"Expected 26.79, got {param_dict['latitude']}"
        if "longitude" in param_dict:
            assert param_dict["longitude"] == 82.20, f"Expected 82.20, got {param_dict['longitude']}"
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)
