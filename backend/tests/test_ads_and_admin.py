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
            processed_transactions.add(entity.transaction_id)
            user_state["swipes_remaining"] += 10

        mock_session.execute = AsyncMock(side_effect=mock_execute)
        mock_session.add = MagicMock(side_effect=mock_add)
        mock_session.flush = AsyncMock()
        mock_session.commit = AsyncMock()
        yield mock_session

    app.dependency_overrides[get_db] = mock_db_for_ad

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # First request (should succeed)
        params_first = {
            "network": "inmobi",
            "transaction_id": tx_id,
            "custom_data": f"{test_user_id}:quick_reflection:none"
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
        assert data2["status"] == "duplicate"
        assert "already processed" in data2["message"]
        assert user_state["swipes_remaining"] == 35  # NOT double credited!

    app.dependency_overrides.clear()
