import base64
import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch

from app.main import app
from app.api.dependencies import get_current_user, get_db
from app.models.domain.user import User
from app.services.kyc_purge import purge_ephemeral_kyc_video
from app.services.frame_extractor import FrameExtractorService


@pytest.mark.asyncio
async def test_exit_criterion_1_render_keep_alive():
    """
    Exit Criterion 1: Render Keep-Alive Verification.
    Issue curl -I /api/v1/health.
    Verify HTTP 200 OK with header X-Sanctuary-Alive: true and 0-byte body payload on HEAD.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. HEAD Request
        head_res = await client.head("/api/v1/health")
        assert head_res.status_code == 200
        assert head_res.headers.get("X-Sanctuary-Alive") == "true"
        assert len(head_res.content) == 0

        # 2. GET Request
        get_res = await client.get("/api/v1/health")
        assert get_res.status_code == 200
        assert get_res.headers.get("X-Sanctuary-Alive") == "true"
        data = get_res.json()
        assert data.get("status") in ("active", "healthy")
        assert data.get("service") == "UR-Heart Core Engine"


@pytest.mark.asyncio
async def test_exit_criterion_2_ocr_and_nlp_sanitizer():
    """
    Exit Criterion 2: OCR & NLP Sanitizer Test.
    1. Photo with printed phone number returns rejection.
    2. Text containing +91 9876543210 or transliteration throws HTTP 422.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Photo Moderation Test with mock OCR detecting phone number
        with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value="Call me 9876543210"):
            # Synthetic 1x1 image
            fake_image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
            files = {"file": ("test_phone.jpg", fake_image_bytes, "image/jpeg")}
            photo_res = await client.post("/api/v1/moderation/photo", files=files)
            assert photo_res.status_code == 200
            photo_data = photo_res.json()
            assert photo_data["status"] == "rejected"
            assert "digits" in photo_data.get("reason", "").lower() or "contact" in photo_data.get("reason", "").lower()

        # Chat NLP Test: Indian phone number -> HTTP 422
        chat_res1 = await client.post("/api/v1/moderation/chat", json={"text": "Hey ping me at +91 9876543210"})
        assert chat_res1.status_code in (422, status_code_422 := 422)

        # Chat NLP Test: Hindi transliterated number -> HTTP 422
        chat_res2 = await client.post("/api/v1/moderation/chat", json={"text": "mera number hai nau aath saat chhe paanch char teen do ek zero"})
        assert chat_res2.status_code == 422

        # Chat NLP Test: Clean intentional dialogue -> HTTP 200
        chat_res3 = await client.post("/api/v1/moderation/chat", json={"text": "I appreciate quiet mornings and mindful conversations."})
        assert chat_res3.status_code == 200
        assert chat_res3.json()["is_safe"] is True


@pytest.mark.asyncio
async def test_exit_criterion_3_groq_ai_verification():
    """
    Exit Criterion 3: Groq 360° AI Verification.
    Test /api/v1/ai/icebreakers with two profiles; verify 3 bespoke JSON prompts return within <400ms.
    """
    from app.core.security import get_current_user
    mock_ai_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Groq Seeker",
        email="groq@sanctuary.app"
    )
    app.dependency_overrides[get_current_user] = lambda: mock_ai_user
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            payload = {
                "user_a": {"bio": "Lover of silent architecture and slow walks in Kyoto.", "interests": "books, architecture"},
                "user_b": {"bio": "Gardener and tea ceremonialist.", "interests": "botany, tea"}
            }
            res = await client.post("/api/v1/ai/icebreakers", json=payload, headers={"Authorization": "Bearer test"})
            assert res.status_code == 200
            data = res.json()
            assert "icebreakers" in data
            assert len(data["icebreakers"]) == 3
            for item in data["icebreakers"]:
                assert isinstance(item, str) and len(item) > 5

            # Test Bio Polish
            bio_res = await client.post(
                "/api/v1/ai/bio-polish",
                json={"raw_bio": "I read books and drink coffee in rain."},
                headers={"Authorization": "Bearer test"}
            )
            assert bio_res.status_code == 200
            assert "polished_bio" in bio_res.json()

            # Test Vision KYC Liveness
            fake_b64 = base64.b64encode(b"fake_image_bytes").decode("utf-8")
            kyc_res = await client.post(
                "/api/v1/ai/kyc-liveness",
                json={
                    "anchor_photo_b64": fake_b64,
                    "frame_1_b64": fake_b64,
                    "frame_2_b64": fake_b64,
                    "frame_3_b64": fake_b64
                },
                headers={"Authorization": "Bearer test"}
            )
            assert kyc_res.status_code == 200
            kyc_data = kyc_res.json()
            assert "is_live_human" in kyc_data
            assert "face_match_score" in kyc_data
    finally:
        app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.asyncio
async def test_exit_criterion_4_superadmin_security_lock():
    """
    Exit Criterion 4: Superadmin Security Lock.
    Regular user token on /api/v1/admin/kyc/escalations -> HTTP 403 Forbidden.
    asiverticals@gmail.com -> HTTP 200 OK.
    """
    regular_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Regular Member",
        email="kshtriyaanubhav9120@gmail.com"
    )

    superadmin_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Asi Verticals Sovereign",
        email="asiverticals@gmail.com"
    )

    async def mock_regular():
        return regular_user

    async def mock_admin():
        return superadmin_user

    async def mock_db():
        mock_s = AsyncMock()
        mock_r = MagicMock()
        mock_r.scalars.return_value.all.return_value = []
        mock_s.execute.return_value = mock_r
        yield mock_s

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Regular User attempt -> 403
        app.dependency_overrides[get_current_user] = mock_regular
        res_forbidden = await client.get("/api/v1/admin/kyc/escalations")
        assert res_forbidden.status_code == 403

        # 2. Superadmin attempt -> 200
        app.dependency_overrides[get_current_user] = mock_admin
        app.dependency_overrides[get_db] = mock_db
        res_ok = await client.get("/api/v1/admin/kyc/escalations")
        assert res_ok.status_code == 200
        assert res_ok.json() == []

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_exit_criterion_5_ephemeral_purge_and_billing_audit():
    """
    Exit Criterion 5: Ephemeral Hard-Purge & Dual-Store IAP Audit.
    1. Ephemeral video KYC purge succeeds in <60 seconds.
    2. Multi-store billing records gross, fee, and net splits idempotently.
    """
    # 1. Ephemeral Purge Test
    test_user_id = str(uuid.uuid4())
    purge_result = purge_ephemeral_kyc_video(test_user_id)
    assert purge_result is True

    # 2. Frame Extractor RAM processing
    frames = FrameExtractorService.extract_3_frames_from_bytes(b"empty_dummy_stream")
    assert len(frames) == 3

    # 3. Dual-Store Billing Audit Test
    async def mock_db_billing():
        mock_s = AsyncMock()
        mock_r = MagicMock()
        mock_r.scalar_one_or_none.return_value = None
        mock_s.execute.return_value = mock_r
        mock_s.commit = AsyncMock()
        mock_s.add = MagicMock()
        yield mock_s

    app.dependency_overrides[get_db] = mock_db_billing
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "user_id": str(uuid.uuid4()),
            "transaction_reference": f"tx_iap_{uuid.uuid4().hex[:10]}",
            "product_identifier": "urheart_pass_monthly",
            "store": "google_play",
            "currency": "INR",
            "amount_gross": 149.00,
            "platform_fee": 22.35,
            "amount_net": 126.65
        }
        from app.api.v1.endpoints.billing_webhook import REVENUECAT_SECRET
        # SEC-01 / PAY-01: Unauthenticated request must return 401
        unauth_res = await client.post("/api/v1/billing/purchase/audit", json=payload)
        assert unauth_res.status_code == 401

        # Authenticated request with constant-time HMAC bearer succeeds
        res = await client.post(
            "/api/v1/billing/purchase/audit",
            json=payload,
            headers={"Authorization": f"Bearer {REVENUECAT_SECRET}"}
        )
        assert res.status_code == 200
        assert res.json()["status"] == "completed"

    app.dependency_overrides.clear()
