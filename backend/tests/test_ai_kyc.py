import os
import tempfile
from uuid import uuid4
from unittest.mock import patch, AsyncMock, MagicMock
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import get_db

from app.core.rate_limiter import limiter

client = TestClient(app)

VALID_MP4_BYTES = b"\x00\x00\x00\x1cftypisom\x00\x00\x02\x00isomiso2mp41" + b"\x00" * 100
DUMMY_VIDEO_BYTES = VALID_MP4_BYTES

@pytest.fixture(autouse=True)
def mock_db_dependency():
    app.state.limiter.enabled = False
    limiter.enabled = False
    dummy_user = MagicMock()
    dummy_user.id = uuid4()
    dummy_user.full_name = "Aman Gupta"
    dummy_user.city = "Lucknow"
    dummy_user.kyc_status = False

    mock_session = AsyncMock()
    result_mock = MagicMock()
    result_mock.scalar_one_or_none.return_value = dummy_user
    mock_session.execute.return_value = result_mock
    mock_session.commit.return_value = None
    mock_session.add = lambda x: None

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.pop(get_db, None)
    app.state.limiter.enabled = True
    limiter.enabled = True

# ==============================================================================
# TEST CASE 1: Auto-Approval Success Branch
# ==============================================================================
def test_kyc_auto_approval_success():
    """
    Simulates video with valid human face, matching spoken transcript,
    and high AI confidence score (>= 0.80).
    Asserts auto_verified status and storage purge invocation.
    """
    user_id = str(uuid4())
    headers = {"X-Consent-DPDP": "true"}
    files = {"file": ("kyc_clip.mp4", DUMMY_VIDEO_BYTES, "video/mp4")}
    data = {
        "user_id": user_id,
        "user_name": "Aman Gupta",
        "user_city": "Lucknow"
    }

    with patch("app.services.ai_kyc_service.verify_face_in_video", return_value=True), \
         patch("app.services.ai_kyc_service.extract_audio_track", return_value=True), \
         patch("app.services.ai_kyc_service.transcribe_audio_groq", new_callable=AsyncMock) as mock_whisper, \
         patch("app.services.ai_kyc_service.evaluate_semantic_match_groq", new_callable=AsyncMock) as mock_llama, \
         patch("app.services.ai_kyc_service.purge_user_storage_assets", new_callable=AsyncMock) as mock_purge:

        mock_whisper.return_value = "Mera naam Aman Gupta hai aur main Lucknow se hoon"
        mock_llama.return_value = {
            "name_match": True,
            "city_match": True,
            "confidence": 0.95
        }

        response = client.post("/api/v1/kyc/submit-video", headers=headers, files=files, data=data)

    assert response.status_code == 200, response.text
    res_data = response.json()
    assert res_data["status"] == "auto_verified"
    assert res_data["confidence"] == 0.95
    assert res_data["has_valid_face"] is True

    # Assert Section 8(7) DPDP Act 2023 purge routine was triggered
    mock_purge.assert_awaited_once()

# ==============================================================================
# TEST CASE 2: Mismatched Details -> Queue Fallback Branch
# ==============================================================================
def test_kyc_mismatch_routes_to_admin_queue():
    """
    Simulates video where spoken transcript fails semantic name/city validation (< 0.80).
    Asserts fallback to queued_for_admin_review and admin email assignment.
    """
    user_id = str(uuid4())
    headers = {"X-Consent-DPDP": "true"}
    files = {"file": ("kyc_clip.mp4", DUMMY_VIDEO_BYTES, "video/mp4")}
    data = {
        "user_id": user_id,
        "user_name": "Aman Gupta",
        "user_city": "Lucknow"
    }

    with patch("app.services.ai_kyc_service.verify_face_in_video", return_value=True), \
         patch("app.services.ai_kyc_service.extract_audio_track", return_value=True), \
         patch("app.services.ai_kyc_service.transcribe_audio_groq", new_callable=AsyncMock) as mock_whisper, \
         patch("app.services.ai_kyc_service.evaluate_semantic_match_groq", new_callable=AsyncMock) as mock_llama:

        mock_whisper.return_value = "Main Rahul Sharma bol raha hoon Delhi se"
        mock_llama.return_value = {
            "name_match": False,
            "city_match": False,
            "confidence": 0.20
        }

        response = client.post("/api/v1/kyc/submit-video", headers=headers, files=files, data=data)

    assert response.status_code == 200, response.text
    res_data = response.json()
    assert res_data["status"] == "queued_for_admin_review"
    assert res_data["assigned_admin"] == "kshtriyaanubhav9120@gmail.com"
    assert "transcript_mismatch" in res_data["ai_flags"]

# ==============================================================================
# TEST CASE 3: Missing DPDP Consent Header Verification
# ==============================================================================
def test_missing_dpdp_consent_header_rejected():
    """
    Submitting KYC video without explicit X-Consent-DPDP header must return HTTP 400 Bad Request.
    """
    files = {"file": ("kyc_clip.mp4", DUMMY_VIDEO_BYTES, "video/mp4")}
    data = {"user_name": "Aman Gupta"}

    # Omit X-Consent-DPDP header
    response = client.post("/api/v1/kyc/submit-video", files=files, data=data)
    assert response.status_code == 400
    assert "DPDP consent notice must be affirmatively accepted" in response.json()["detail"]

# ==============================================================================
# TEST CASE 4: File Cleanup Verification
# ==============================================================================
def test_temporary_files_wiped_after_execution():
    """
    Verifies that all temporary video and audio files in temp directory are wiped.
    """
    user_id = uuid4()
    temp_dir = tempfile.gettempdir()
    video_path = os.path.join(temp_dir, f"{user_id}_kyc.mp4")
    audio_path = os.path.join(temp_dir, f"{user_id}_kyc.wav")

    headers = {"X-Consent-DPDP": "true"}
    files = {"file": ("kyc_clip.mp4", DUMMY_VIDEO_BYTES, "video/mp4")}
    data = {"user_id": str(user_id)}

    with patch("app.services.ai_kyc_service.verify_face_in_video", return_value=False):
        _ = client.post("/api/v1/kyc/submit-video", headers=headers, files=files, data=data)

    assert not os.path.exists(video_path), f"Temp video file was not cleaned up: {video_path}"
    assert not os.path.exists(audio_path), f"Temp audio file was not cleaned up: {audio_path}"

# ==============================================================================
# TEST CASE 5: Submit Video Without user_id (Resolves via Auth / Auto-Provision)
# ==============================================================================
def test_kyc_submit_without_user_id_succeeds():
    """
    Verifies that calling /submit-video without a user_id form parameter
    (standard mobile app flow) succeeds and does not throw 400 account missing error.
    """
    headers = {
        "X-Consent-DPDP": "true",
        "Authorization": "Bearer mock_user_token"
    }
    files = {"file": ("kyc_clip.mp4", DUMMY_VIDEO_BYTES, "video/mp4")}
    data = {
        "user_name": "Aman Gupta",
        "user_city": "Lucknow"
    }

    with patch("app.services.ai_kyc_service.verify_face_in_video", return_value=True), \
         patch("app.services.ai_kyc_service.extract_audio_track", return_value=True), \
         patch("app.services.ai_kyc_service.transcribe_audio_groq", new_callable=AsyncMock) as mock_whisper, \
         patch("app.services.ai_kyc_service.evaluate_semantic_match_groq", new_callable=AsyncMock) as mock_llama, \
         patch("app.services.ai_kyc_service.purge_user_storage_assets", new_callable=AsyncMock):

        mock_whisper.return_value = "Mera naam Aman Gupta hai aur main Lucknow se hoon"
        mock_llama.return_value = {
            "name_match": True,
            "city_match": True,
            "confidence": 0.92
        }

        response = client.post("/api/v1/kyc/submit-video", headers=headers, files=files, data=data)

    assert response.status_code == 200, response.text
    res_data = response.json()
    assert res_data["status"] in ("auto_verified", "queued_for_admin_review")
