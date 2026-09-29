import uuid
from datetime import datetime, date, timedelta
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch

from app.main import app
from app.api.dependencies import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.legal import (
    DataExportRequest,
    DataNominee,
    GrievanceDossier,
    UnderageQuarantineRegistry,
    ConsentAuditLog,
)


@pytest.fixture
def mock_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Anubhav Legal Test",
        dob=date(1998, 5, 20),
        gender="male",
        interested_in="female",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="encrypted_phone",
        location_name="Saket, Ayodhya",
        bio="Mindful human",
        profession="Engineer",
        education="B.Tech",
        kyc_status=True,
        subscription_tier="gold",
        referral_code="REF1234",
    )


@pytest.mark.asyncio
async def test_sec06_account_incinerator_atomic_wipe(mock_user):
    """
    Test 1: Irrevocable Account Incineration Verification (SEC-06 Test)
    Valid ERASE confirmation token triggers atomic DB cascade, storage shredding, and auth wipe.
    """
    async def mock_db():
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        yield session

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Invalid confirmation token
        bad_res = await client.request(
            "DELETE",
            "/api/v1/auth/incinerate-account",
            json={"confirmation_token": "DELETE", "reason": "user_cancelled"}
        )
        assert bad_res.status_code == 422

        # Valid confirmation token ERASE
        with patch("app.api.v1.endpoints.account_incinerator._purge_remote_user_storage", new_callable=AsyncMock) as mock_purge, \
             patch("app.api.v1.endpoints.account_incinerator._delete_auth_identity", new_callable=AsyncMock) as mock_del_auth:
            res = await client.request(
                "DELETE",
                "/api/v1/auth/incinerate-account",
                json={"confirmation_token": "ERASE", "reason": "dpdp_sec12_erasure"}
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "incinerated"
            assert "DPDP Act 2023 Section 12" in data["compliance"]
            assert mock_purge.called
            assert mock_del_auth.called

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sec08_underage_quarantine_engine():
    """
    Test 2: Hardware Underage Quarantine Bypass Test (SEC-08 Test)
    Underage input triggers 180-day hardware quarantine; check-quarantine blocks device with HTTP 403.
    """
    device_fp = f"ANDROID_HW_ID_{uuid.uuid4().hex[:8]}"
    quarantined_record = None

    async def mock_db():
        session = AsyncMock()
        def mock_exec(stmt):
            res = MagicMock()
            # If checking quarantine, return existing quarantined record if set
            res.scalar_one_or_none.return_value = quarantined_record
            return res

        session.execute = AsyncMock(side_effect=mock_exec)
        session.add = MagicMock()
        session.commit = AsyncMock()
        yield session

    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Adult DOB should be rejected by quarantine endpoint
        adult_res = await client.post(
            "/api/v1/auth/quarantine-device",
            json={"device_hardware_fingerprint": device_fp, "attempted_dob": "1995-01-01"}
        )
        assert adult_res.status_code == 400
        assert "adult threshold" in adult_res.json()["detail"]

        # 2. Minor DOB registers quarantine
        minor_res = await client.post(
            "/api/v1/auth/quarantine-device",
            json={"device_hardware_fingerprint": device_fp, "attempted_dob": "2012-05-14"}
        )
        assert minor_res.status_code == 201
        data = minor_res.json()
        assert data["status"] == "quarantined"
        assert data["lockout_days"] == 180

        # 3. Simulate device is found in quarantine registry
        quarantined_record = UnderageQuarantineRegistry(
            device_hash="some_hash",
            attempted_dob=date(2012, 5, 14),
            quarantine_until=datetime.utcnow() + timedelta(days=180)
        )

        check_res = await client.get(f"/api/v1/auth/check-quarantine/{device_fp}")
        assert check_res.status_code == 403
        assert "quarantined under DPDP Act Section 9" in check_res.json()["detail"]

        # 4. Non-quarantined device returns is_quarantined: False
        quarantined_record = None
        clean_res = await client.get("/api/v1/auth/check-quarantine/CLEAN_DEVICE_12345678")
        assert clean_res.status_code == 200
        assert clean_res.json()["is_quarantined"] is False

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sec09_dpdp_sec11_data_portability(mock_user):
    """
    Test 3: DPDP Sec 11 Data Portability Archive Test (SEC-09 Test)
    Initiates export and retrieves structured JSON payload with SHA-256 checksum.
    """
    request_id = uuid.uuid4()
    mock_export = DataExportRequest(
        id=request_id,
        user_id=mock_user.id,
        status="completed",
        export_payload={"statutory_authority": "Digital Personal Data Protection Act, 2023 (India)"},
        checksum_sha256="abc123sha256mockedchecksum",
        expires_at=datetime.utcnow() + timedelta(days=7)
    )

    async def mock_db():
        session = AsyncMock()
        def mock_exec(stmt):
            res = MagicMock()
            res.scalar_one_or_none.return_value = None  # No pending request
            return res

        session.execute = AsyncMock(side_effect=mock_exec)
        session.add = MagicMock()
        session.commit = AsyncMock()
        session.refresh = AsyncMock()
        yield session

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Request export
        with patch("app.api.v1.endpoints.legal_compliance._compile_user_export_bundle", new_callable=AsyncMock):
            export_res = await client.post("/api/v1/vault/export-data")
            assert export_res.status_code == 202
            export_data = export_res.json()
            assert export_data["status"] == "processing"
            assert "DPDP Act 2023 Sec 11" in export_data["message"]
            assert export_data["valid_days"] == 7

        # Check export status
        async def mock_db_status():
            session = AsyncMock()
            res = MagicMock()
            res.scalar_one_or_none.return_value = mock_export
            session.execute = AsyncMock(return_value=res)
            yield session

        app.dependency_overrides[get_db] = mock_db_status

        status_res = await client.get(f"/api/v1/vault/export-status/{request_id}")
        assert status_res.status_code == 200
        status_data = status_res.json()
        assert status_data["status"] == "completed"
        assert status_data["checksum_sha256"] == "abc123sha256mockedchecksum"
        assert status_data["payload"]["statutory_authority"] == "Digital Personal Data Protection Act, 2023 (India)"

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sec09_it_rules_2021_grievance_filing(mock_user):
    """
    Test 4: IT Rules 2021 Grievance Dossier Filing Test (SEC-09 Test)
    Logs complaint, generates dossier_reference_id, and calculates 15-day statutory resolution SLA.
    """
    target_user_id = uuid.uuid4()

    async def mock_db():
        session = AsyncMock()
        session.add = MagicMock()
        session.commit = AsyncMock()
        session.refresh = AsyncMock()
        yield session

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Cannot file against oneself
        self_res = await client.post(
            "/api/v1/vault/grievance",
            json={
                "reported_user_id": str(mock_user.id),
                "violation_category": "harassment",
                "evidence_text": "testing self report"
            }
        )
        assert self_res.status_code == 400
        assert "Cannot file grievance against yourself" in self_res.json()["detail"]

        # Valid grievance filing
        res = await client.post(
            "/api/v1/vault/grievance",
            json={
                "reported_user_id": str(target_user_id),
                "violation_category": "harassment",
                "evidence_text": "Unsolicited offensive remark"
            }
        )
        assert res.status_code == 201
        data = res.json()
        assert data["status"] == "acknowledged"
        assert "IT Rules 2021 Rule 3(2)" in data["sla_acknowledgment"]
        assert "statutory_resolution_deadline" in data
        assert data["support_desk_contact"] == "asiverticals@gmail.com"

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sec09_data_nominee_registration_and_fetch(mock_user):
    """
    Test 5: DPDP Act 2023 Sec 14 Data Nominee Designation
    """
    nominee = None

    async def mock_db():
        session = AsyncMock()
        def mock_exec(stmt):
            res = MagicMock()
            res.scalar_one_or_none.return_value = nominee
            return res
        session.execute = AsyncMock(side_effect=mock_exec)
        session.add = MagicMock()
        session.commit = AsyncMock()
        yield session

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Register nominee
        reg_res = await client.post(
            "/api/v1/vault/nominee",
            json={
                "nominee_name": "Aarav Sharma",
                "nominee_contact": "+919876543210",
                "relationship": "Brother"
            }
        )
        assert reg_res.status_code == 200
        assert reg_res.json()["status"] == "success"

        # 2. Fetch nominee (masked contact)
        nominee = DataNominee(
            user_id=mock_user.id,
            nominee_name="Aarav Sharma",
            nominee_contact="+919876543210",
            relationship="Brother"
        )
        get_res = await client.get("/api/v1/vault/nominee")
        assert get_res.status_code == 200
        get_data = get_res.json()
        assert get_data["has_nominee"] is True
        assert get_data["nominee"]["name"] == "Aarav Sharma"
        assert get_data["nominee"]["contact_masked"] == "+919****"

    app.dependency_overrides.clear()
