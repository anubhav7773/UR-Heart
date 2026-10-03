import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock
from app.main import app
from app.api.dependencies import get_current_user, get_db
from app.models.domain.user import User


@pytest.mark.asyncio
async def test_admin_kyc_security_check():
    """
    Superadmin Security Gate Test:
    Ensures that authenticated users WITHOUT asiverticals@gmail.com receive HTTP 403 Forbidden.
    """
    # 1. Non-admin user simulation (including previously old admin email)
    fake_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Regular User",
        email="kshtriyaanubhav9120@gmail.com"
    )

    async def mock_get_current_user_non_admin():
        return fake_user

    app.dependency_overrides[get_current_user] = mock_get_current_user_non_admin

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/api/v1/admin/kyc/pending-queue",
            headers={"Authorization": "Bearer fake", "x-installation-uuid": "uuid-1"}
        )
        assert response.status_code == 403
        data = response.json()
        assert "Sanctuary Sovereign privileges" in data.get("message", "")

    # 2. Superadmin user simulation
    superadmin_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Asi Verticals Sovereign",
        email="asiverticals@gmail.com"
    )

    async def mock_get_current_user_admin():
        return superadmin_user

    async def mock_db_session():
        mock_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_session.execute.return_value = mock_result
        yield mock_session

    app.dependency_overrides[get_current_user] = mock_get_current_user_admin
    app.dependency_overrides[get_db] = mock_db_session

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/api/v1/admin/kyc/pending-queue",
            headers={"Authorization": "Bearer fake", "x-installation-uuid": "uuid-1"}
        )
        assert response.status_code == 200
        assert response.json() == []

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_ad_ssv_idempotency_workflow():
    """
    Exit Criteria 4: Ad Idempotency Test.
    Same transaction_id hit twice; second request returns duplicate without double crediting.
    """
    processed_transactions = set()
    user_state = {"swipes_remaining": 25}

    test_user_id = uuid.uuid4()
    tx_id = f"tx_unique_{uuid.uuid4().hex[:12]}"

    async def mock_db_for_ad():
        mock_session = AsyncMock()

        async def mock_execute(stmt):
            # Check if stmt is checking ProcessedAdTransaction
            mock_res = MagicMock()
            if tx_id in processed_transactions:
                mock_res.scalar_one_or_none.return_value = MagicMock()
            else:
                mock_res.scalar_one_or_none.return_value = None
            return mock_res

        def mock_add(entity):
            tx = getattr(entity, "transaction_id", None) or getattr(entity, "ssv_transaction_id", None)
            if tx and tx not in processed_transactions:
                processed_transactions.add(tx)
                user_state["swipes_remaining"] += 10

        mock_session.execute = AsyncMock(side_effect=mock_execute)
        mock_session.add = MagicMock(side_effect=mock_add)
        mock_session.flush = AsyncMock()
        mock_session.commit = AsyncMock()
        yield mock_session

    app.dependency_overrides[get_db] = mock_db_for_ad

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        import hmac
        import hashlib
        from app.api.v1.endpoints.ads_ssv import NETWORK_SECRETS
        secret = NETWORK_SECRETS.get("chartboost", "chartboost_ssv_secret_sanctuary_2026")
        canonical_query = f"network=chartboost&transaction_id={tx_id}&custom_data={test_user_id}:quick_reflection:none"
        sig = hmac.new(secret.encode("utf-8"), canonical_query.encode("utf-8"), hashlib.sha256).hexdigest()

        # First request (should succeed)
        params_first = {
            "network": "chartboost",
            "transaction_id": tx_id,
            "custom_data": f"{test_user_id}:quick_reflection:none",
            "signature": sig
        }
        res1 = await client.get("/api/v1/ads/verify-reward", params=params_first)
        assert res1.status_code == 200
        data1 = res1.json()
        assert data1["status"] == "success"
        assert user_state["swipes_remaining"] == 35  # Credited once

        # Second request with identical transaction_id (duplicate)
        res2 = await client.get("/api/v1/ads/verify-reward", params=params_first)
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["status"] in ("duplicate", "success")
        assert "already processed" in data2["message"]
        assert user_state["swipes_remaining"] == 35  # NOT double credited!

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_ad_claim_reward_whatsapp_reveal_cycle():
    """
    Test POST /api/v1/ads/claim-reward for whatsapp_reveal.
    Verifies that uuid, func, and datetime execute cleanly without 500 NameError,
    and increments reveal_tokens_count when 3 ads are reached.
    """
    test_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Mindful Seeker",
        email="seeker@example.com",
        reveal_tokens_count=0,
        reward_balance=0,
        swipes_remaining=10,
        direct_letters_count=0
    )

    recorded_ads = []

    async def mock_get_current_user():
        return test_user

    async def mock_db():
        mock_session = AsyncMock()

        async def mock_exec(stmt):
            mock_res = MagicMock()
            # For select(func.count(AdRewardLedger.id))
            mock_res.scalar.return_value = len(recorded_ads)
            return mock_res

        def mock_add(entity):
            recorded_ads.append(entity)

        mock_session.execute = AsyncMock(side_effect=mock_exec)
        mock_session.add = MagicMock(side_effect=mock_add)
        mock_session.commit = AsyncMock()
        mock_session.refresh = AsyncMock()
        yield mock_session

    from app.core.security import get_current_user as core_get_current_user
    app.dependency_overrides[get_current_user] = mock_get_current_user
    app.dependency_overrides[core_get_current_user] = mock_get_current_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        from app.api.v1.endpoints.ads_ssv import _recent_user_claims
        _recent_user_claims.clear()

        # Ad 1
        res1 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res1.status_code == 200, f"Error: {res1.text}"
        data1 = res1.json()
        assert data1["status"] == "success"
        assert data1["whatsapp_progress"] == 1
        assert data1["reveal_tokens_count"] == 0

        # Ad 2
        _recent_user_claims.clear()
        res2 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["whatsapp_progress"] == 2
        assert data2["reveal_tokens_count"] == 0

        # Ad 3 (completes cycle -> grants 1 token)
        _recent_user_claims.clear()
        res3 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res3.status_code == 200
        data3 = res3.json()
        assert data3["token_granted"] is True
        assert data3["reveal_tokens_count"] == 1

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_web_admin_portal_html_routes():
    """
    Dedicated Web Admin URL Verification:
    Ensures /admin and /admin/portal render the luxury sovereign admin portal,
    strictly locking to asiverticals@gmail.com with zero leaks of legacy credentials.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res1 = await client.get("/admin")
        assert res1.status_code == 200
        assert "text/html" in res1.headers["content-type"]
        assert "asiverticals@gmail.com" in res1.text
        assert "kshtriyaanubhav9120@gmail.com" not in res1.text
        assert "UR-Heart Sovereign Command" in res1.text

        res2 = await client.get("/admin/portal")
        assert res2.status_code == 200
        assert "asiverticals@gmail.com" in res2.text


@pytest.mark.asyncio
async def test_admin_portal_security_and_operations():
    """
    Superadmin Portal Operations Gate:
    1. Rejects non-admin / legacy email (kshtriyaanubhav9120@gmail.com) with 403 Forbidden.
    2. Allows asiverticals@gmail.com to access stats, users, config, and audit logs.
    """
    # 1. Non-admin test
    unauth_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Former Admin",
        email="kshtriyaanubhav9120@gmail.com"
    )
    app.dependency_overrides[get_current_user] = lambda: unauth_user

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res_fail = await client.get("/api/v1/admin/portal/stats")
        assert res_fail.status_code == 403
        assert "Sanctuary Sovereign privileges" in res_fail.json().get("message", "")

    # 2. Authorized asiverticals@gmail.com Superadmin test
    sovereign_admin = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Asi Verticals Sovereign",
        email="asiverticals@gmail.com"
    )

    async def mock_db():
        mock_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar.return_value = 10
        mock_result.scalars.return_value.all.return_value = []
        mock_session.execute.return_value = mock_result
        mock_session.commit = AsyncMock()
        yield mock_session

    app.dependency_overrides[get_current_user] = lambda: sovereign_admin
    app.dependency_overrides[get_db] = mock_db

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # A. Stats
        res_stats = await client.get("/api/v1/admin/portal/stats")
        assert res_stats.status_code == 200
        stats = res_stats.json()
        assert stats["superadmin"] == "asiverticals@gmail.com"
        assert stats["status"] == "healthy"

        # B. Users
        res_users = await client.get("/api/v1/admin/portal/users")
        assert res_users.status_code == 200
        assert isinstance(res_users.json(), list)

        # C. Config Read
        res_cfg = await client.get("/api/v1/admin/portal/config")
        assert res_cfg.status_code == 200
        assert res_cfg.json()["superadmin_email"] == "asiverticals@gmail.com"

        # D. Config Update
        res_cfg_up = await client.put(
            "/api/v1/admin/portal/config",
            json={"config": {"maintenance_mode": False, "strict_ai_moderation": True}}
        )
        assert res_cfg_up.status_code == 200
        assert res_cfg_up.json()["status"] == "success"

        # E. Audit Logs
        res_audit = await client.get("/api/v1/admin/portal/audit-logs")
        assert res_audit.status_code == 200
        assert isinstance(res_audit.json(), list)

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_admin_portal_sovereign_login():
    """
    Direct Sovereign Master Key Login Gate Test:
    1. Forbids non-superadmin emails (403 Forbidden).
    2. Rejects invalid secret keys (401 Unauthorized).
    3. Issues 7-day signed JWT access token for asiverticals@gmail.com with correct key.
    """
    transport = ASGITransport(app=app)

    async def mock_db():
        mock_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result
        mock_session.commit = AsyncMock()
        mock_session.refresh = AsyncMock()
        yield mock_session

    from app.core.database import get_db
    app.dependency_overrides[get_db] = mock_db

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Invalid email attempt
        res_wrong_email = await client.post(
            "/api/v1/admin/portal/auth/login",
            json={"email": "kshtriyaanubhav9120@gmail.com", "secret_key": "asiverticals_sovereign_sanctuary_2026"}
        )
        assert res_wrong_email.status_code == 403

        # 2. Invalid secret key attempt
        res_wrong_key = await client.post(
            "/api/v1/admin/portal/auth/login",
            json={"email": "asiverticals@gmail.com", "secret_key": "wrong_key_attempt"}
        )
        assert res_wrong_key.status_code == 401

        # 3. Successful Sovereign login
        res_success = await client.post(
            "/api/v1/admin/portal/auth/login",
            json={"email": "asiverticals@gmail.com", "secret_key": "asiverticals_sovereign_sanctuary_2026"}
        )
        assert res_success.status_code == 200
        data = res_success.json()
        assert data["status"] == "success"
        assert "access_token" in data
        assert data["role"] == "superadmin"
        assert data["email"] == "asiverticals@gmail.com"

    app.dependency_overrides.clear()

