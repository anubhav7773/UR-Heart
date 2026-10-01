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
    Ensures that authenticated users WITHOUT kshtriyaanubhav9120@gmail.com receive HTTP 403 Forbidden.
    """
    # 1. Non-admin user simulation
    fake_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Regular User",
        email="regular_user@example.com"
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
        full_name="Kshtriya Anubhav",
        email="kshtriyaanubhav9120@gmail.com"
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
        secret = NETWORK_SECRETS.get("inmobi", "inmobi_ssv_secret_sanctuary_2026")
        canonical_query = f"network=inmobi&transaction_id={tx_id}&custom_data={test_user_id}:quick_reflection:none"
        sig = hmac.new(secret.encode("utf-8"), canonical_query.encode("utf-8"), hashlib.sha256).hexdigest()

        # First request (should succeed)
        params_first = {
            "network": "inmobi",
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
        # Ad 1
        res1 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res1.status_code == 200, f"Error: {res1.text}"
        data1 = res1.json()
        assert data1["status"] == "success"
        assert data1["whatsapp_progress"] == 1
        assert data1["reveal_tokens_count"] == 0

        # Ad 2
        res2 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["whatsapp_progress"] == 2
        assert data2["reveal_tokens_count"] == 0

        # Ad 3 (completes cycle -> grants 1 token)
        res3 = await client.post("/api/v1/ads/claim-reward", json={"ad_type": "whatsapp_reveal"})
        assert res3.status_code == 200
        data3 = res3.json()
        assert data3["token_granted"] is True
        assert data3["reveal_tokens_count"] == 1

    app.dependency_overrides.clear()
