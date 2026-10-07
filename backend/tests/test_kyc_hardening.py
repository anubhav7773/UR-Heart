import uuid
from datetime import date
import pytest
from httpx import ASGITransport, AsyncClient, Response
from unittest.mock import AsyncMock, patch, MagicMock

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.services.eva_identity_engine import EvaIdentityEngine, KycAiEvaluation


@pytest.fixture
def mock_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="seeker@urheart.app",
        full_name="Intentional Seeker",
        dob=date(2000, 1, 1),
        gender="man",
        interested_in="all",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="919999988888",
        location_name="Connaught Place, New Delhi",
        referral_code="SANCTUARY-P99999",
        kyc_status=False,  # Initially unverified
        subscription_tier="free",
        reward_balance=50,
        swipes_remaining=10,
        direct_letters_count=1,
        reveal_tokens_count=0,
        is_profile_completed=True,
        night_slumber=False,
        is_incognito=False,
        discreet_mode=False,
        public_encryption_key=None,
        push_notifications_enabled=True,
        role="user",
    )


@pytest.fixture
def mock_db():
    session = AsyncMock()
    session.execute = AsyncMock()
    session.commit = AsyncMock()
    session.refresh = AsyncMock()
    session.rollback = AsyncMock()
    session.add = MagicMock()
    return session


@pytest.mark.asyncio
async def test_eva_identity_engine_fail_closed_when_all_models_rate_limit():
    """
    Verify that when Groq returns 429 and OpenRouter returns 404/429/500,
    EvaIdentityEngine strictly fails closed with pending_manual_review and is_live_human=False.
    """
    user_id = uuid.uuid4()
    # 100 bytes dummy base64 JPEG
    valid_b64 = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

    async def mock_post(url, *args, **kwargs):
        if "api.groq.com" in str(url):
            return Response(429, json={"error": {"message": "Rate limit reached"}})
        elif "openrouter.ai" in str(url):
            return Response(404, json={"error": {"message": "Model not found or requires credits"}})
        return Response(500)

    with patch("httpx.AsyncClient.post", side_effect=mock_post):
        evaluation = await EvaIdentityEngine.verify_kyc_liveness(
            user_id=user_id,
            anchor_b64=valid_b64,
            frames_b64=[valid_b64],
            expected_pose="Peace Sign ✌️"
        )

        assert evaluation.status == "pending_manual_review"
        assert evaluation.is_live_human is False
        assert evaluation.face_match_score == 0
        assert evaluation.pose_matched is False
        assert "temporarily unavailable" in evaluation.rejection_reason or "upstream" in evaluation.rejection_reason


@pytest.mark.asyncio
async def test_eva_identity_engine_detects_text_model_missing_image():
    """
    Verify that if a text-only or broken model hallucination mentions 'no image' or 'cannot see',
    EvaIdentityEngine rejects it instead of accepting hallucinated scores.
    """
    raw_response = '{"is_live_human": true, "face_match_score": 95, "pose_matched": true, "analysis_summary": "I cannot view images as I am a text model", "rejection_reason": "No image available"}'
    eval_obj = EvaIdentityEngine._parse_kyc_json(raw_response, expected_pose="Wave Hello 👋")

    assert eval_obj is not None
    assert eval_obj.status == "rejected"
    assert eval_obj.is_live_human is False
    assert eval_obj.face_match_score == 0
    assert eval_obj.pose_matched is False


@pytest.mark.asyncio
async def test_eva_identity_engine_detects_pose_mismatch():
    """
    Verify that if face matches (score >= 75) but pose challenge failed,
    EvaIdentityEngine rejects or refuses auto-approval.
    """
    raw_response = '{"is_live_human": true, "face_match_score": 88, "pose_matched": false, "analysis_summary": "Face matches well, but user is looking straight without making a peace sign", "rejection_reason": "Pose mismatch"}'
    eval_obj = EvaIdentityEngine._parse_kyc_json(raw_response, expected_pose="Peace Sign ✌️")

    assert eval_obj is not None
    assert eval_obj.pose_matched is False
    assert eval_obj.status == "rejected"


@pytest.mark.asyncio
async def test_kyc_verify_live_endpoint_fails_closed_in_db(mock_user, mock_db):
    """
    Test that when /api/v1/kyc/verify-live is called and models return fail-closed evaluation,
    mock_user.kyc_status remains False in the database.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Mock GroqAiService.verify_kyc_liveness_secure returning fail-closed result
        fail_closed_eval = KycAiEvaluation(
            is_live_human=False,
            face_match_score=0,
            pose_matched=False,
            status="pending_manual_review",
            rejection_reason="Rate limit exceeded on upstream AI providers."
        )

        with patch("app.services.groq_service.GroqAiService.verify_kyc_liveness_secure", return_value=fail_closed_eval):
            res = await client.post(
                "/api/v1/kyc/verify-live",
                json={
                    "anchor_b64": "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
                    "selfie_b64": "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
                    "expected_pose": "Peace Sign ✌️"
                }
            )

            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "pending_manual_review"
            assert data["is_live_human"] is False
            assert data["face_match_score"] == 0

            # Crucial check: User kyc_status MUST remain False
            assert mock_user.kyc_status is False

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_kyc_verify_live_endpoint_approves_only_when_fully_passing(mock_user, mock_db):
    """
    Test that /api/v1/kyc/verify-live sets kyc_status=True ONLY when
    status='approved', is_live_human=True, face_match_score>=75, and pose_matched=True.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        approved_eval = KycAiEvaluation(
            is_live_human=True,
            face_match_score=85,
            pose_matched=True,
            is_underage=False,
            status="approved",
            analysis_summary="Clear match with peace sign pose."
        )

        with patch("app.services.groq_service.GroqAiService.verify_kyc_liveness_secure", return_value=approved_eval):
            res = await client.post(
                "/api/v1/kyc/verify-live",
                json={
                    "anchor_b64": "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
                    "selfie_b64": "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
                    "expected_pose": "Peace Sign ✌️"
                }
            )

            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "approved"
            assert data["is_live_human"] is True
            assert data["face_match_score"] == 85
            assert data["pose_matched"] is True

            # Successfully verified
            assert mock_user.kyc_status is True

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_client_cannot_spoof_kyc_status_via_profile_endpoints(mock_user, mock_db):
    """
    Verify security sealing: clients cannot send is_kyc_verified=True or kyc_status=True
    to PUT /api/v1/profile/me or POST /api/v1/profile/create.
    """
    mock_user.kyc_status = False
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Attempt spoofing via PUT /api/v1/profile/me
        res_put = await client.put(
            "/api/v1/profile/me",
            json={
                "is_kyc_verified": True,
                "kyc_status": True,
                "full_name": "Tampered Name"
            }
        )
        assert res_put.status_code == 200
        # kyc_status must strictly remain False on current_user
        assert mock_user.kyc_status is False
        
        # Verify executed DB update values did not include kyc_status or is_kyc_verified
        update_stmt = mock_db.execute.call_args[0][0]
        # In SQLAlchemy update statement, parameters are in compile or parameters dict
        params = update_stmt.compile().params
        assert "kyc_status" not in params
        assert "is_kyc_verified" not in params
        assert params.get("full_name") == "Tampered Name"

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_kyc_rejected_when_profile_photos_missing(mock_user, mock_db):
    """
    Anti-Catfish Rule 1:
    If a user attempts to submit a KYC selfie without uploading profile photos,
    the system must strictly reject it with status='rejected'.
    Self-matching is completely prohibited.
    """
    mock_user.kyc_status = False
    mock_user.avatar_url = None
    mock_user.photos = []
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    valid_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/api/v1/kyc/verify-live",
            json={
                "selfie_b64": valid_png_b64,
                "anchor_b64": "",
                "profile_photos_b64": [],
                "expected_pose": "Peace Sign ✌️"
            }
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "rejected"
        assert data["is_live_human"] is False
        assert data["face_match_score"] == 0
        assert "Profile photos missing" in data["rejection_reason"]
        assert mock_user.kyc_status is False

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_kyc_rejected_when_impersonator_faces_mismatch(mock_user, mock_db):
    """
    Anti-Catfish Rule 2:
    If an impersonator uploads someone else's pictures in their profile slots (1 to 5)
    and submits their own selfie for KYC, Eva AI returns is_identity_match=False and low score.
    The endpoint must strictly reject and leave kyc_status=False.
    """
    mock_user.kyc_status = False
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    valid_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    catfish_eval = KycAiEvaluation(
        is_live_human=True,
        face_match_score=22,
        is_identity_match=False,
        gallery_consistent=True,
        pose_matched=True,
        is_underage=False,
        status="rejected",
        rejection_reason="Identity mismatch: Live selfie does not match the person in the profile photos."
    )

    with patch("app.services.groq_service.GroqAiService.verify_kyc_liveness_secure", return_value=catfish_eval):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/api/v1/kyc/verify-live",
                json={
                    "anchor_b64": valid_png_b64,
                    "profile_photos_b64": [valid_png_b64, valid_png_b64],
                    "selfie_b64": valid_png_b64,
                    "expected_pose": "Peace Sign ✌️"
                }
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "rejected"
            assert data["is_identity_match"] is False
            assert data["face_match_score"] == 22
            assert "Identity mismatch" in data["rejection_reason"]
            assert mock_user.kyc_status is False

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_kyc_rejected_when_gallery_is_inconsistent(mock_user, mock_db):
    """
    Anti-Catfish Rule 3:
    If profile photos depict multiple different individuals (inconsistent gallery),
    the endpoint must reject verification.
    """
    mock_user.kyc_status = False
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    valid_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    inconsistent_eval = KycAiEvaluation(
        is_live_human=True,
        face_match_score=45,
        is_identity_match=True,
        gallery_consistent=False,
        pose_matched=True,
        is_underage=False,
        status="rejected",
        rejection_reason="Inconsistent profile photos: Uploaded profile photos must depict the same person."
    )

    with patch("app.services.groq_service.GroqAiService.verify_kyc_liveness_secure", return_value=inconsistent_eval):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/api/v1/kyc/verify-live",
                json={
                    "anchor_b64": valid_png_b64,
                    "profile_photos_b64": [valid_png_b64, valid_png_b64],
                    "selfie_b64": valid_png_b64,
                }
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "rejected"
            assert data["gallery_consistent"] is False
            assert mock_user.kyc_status is False

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_synthetic_self_comparison_fallback_is_eliminated():
    """
    Anti-Catfish Rule 4:
    Verify that when calling EvaIdentityEngine directly with missing/empty anchor
    and empty profile photos, it NEVER synthesizes the anchor from the live selfie.
    It must fail closed with rejection.
    """
    valid_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    evaluation = await EvaIdentityEngine.verify_kyc_liveness(
        user_id=uuid.uuid4(),
        anchor_b64="",
        frames_b64=[valid_png_b64],
        profile_photos_b64=[],
        expected_pose="Peace Sign ✌️"
    )

    assert evaluation.status == "rejected"
    assert evaluation.is_identity_match is False
    assert evaluation.face_match_score == 0
    assert "Profile photos missing" in evaluation.rejection_reason
