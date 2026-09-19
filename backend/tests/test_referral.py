import pytest
import pytest_asyncio
from uuid import uuid4
from datetime import date
from httpx import AsyncClient
from sqlalchemy import text, select
from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import async_session_factory
from app.models.domain.user import User

@pytest.fixture
def test_auth_headers(auth_headers):
    return auth_headers

@pytest.mark.asyncio
async def test_get_referral_code(async_client: AsyncClient, test_auth_headers):
    response = await async_client.get("/api/v1/referral/my-code", headers=test_auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "referral_code" in data
    assert data["referral_code"].startswith("UR-")
    assert data["reward_per_invite"]["dm_credits"] == 5
    assert data["reward_per_invite"]["wa_reveals"] == 2

@pytest.mark.asyncio
async def test_self_referral_is_blocked(async_client: AsyncClient, test_auth_headers):
    code_res = await async_client.get("/api/v1/referral/my-code", headers=test_auth_headers)
    my_code = code_res.json()["referral_code"]

    # Attempt self-referral
    redeem_res = await async_client.post(
        "/api/v1/referral/redeem",
        json={"referral_code": my_code},
        headers=test_auth_headers
    )
    assert redeem_res.status_code == 400
    assert "cannot redeem your own" in redeem_res.json()["detail"]

@pytest.mark.asyncio
async def test_redeem_invalid_code(async_client: AsyncClient, test_auth_headers):
    redeem_res = await async_client.post(
        "/api/v1/referral/redeem",
        json={"referral_code": "UR-INVALID"},
        headers=test_auth_headers
    )
    assert redeem_res.status_code == 404
    assert "Invalid referral code" in redeem_res.json()["detail"]

@pytest.mark.asyncio
async def test_dual_wallet_referral_redemption(async_client: AsyncClient, test_user: User):
    # 1. Ensure test_user (referrer) has a referral code
    async with async_session_factory() as session:
        referrer = await session.get(User, test_user.id)
        if not referrer.referral_code:
            referrer.referral_code = f"UR-T{str(uuid4().hex)[:4].upper()}"
            await session.commit()
            await session.refresh(referrer)
        referrer_code = referrer.referral_code

    # 2. Create a referee user
    referee = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Referee User",
        dob=date(2000, 1, 1),
        gender="female",
        city="Lucknow",
        bio="Referee test user",
        is_banned=False,
    )
    async with async_session_factory() as session:
        session.add(referee)
        await session.commit()

    referee_headers = {"Authorization": "Bearer mock_referee_token"}
    app.dependency_overrides[get_current_user] = lambda: referee

    try:
        # 3. Redeem referrer's code as referee
        redeem_res = await async_client.post(
            "/api/v1/referral/redeem",
            json={"referral_code": referrer_code},
            headers=referee_headers
        )
        assert redeem_res.status_code == 200
        res_data = redeem_res.json()
        assert res_data["status"] == "success"
        assert res_data["reward_credited"]["dm_credits"] == 5
        assert res_data["reward_credited"]["wa_reveals"] == 2

        # 4. Attempt double redemption - must fail with 400
        double_redeem = await async_client.post(
            "/api/v1/referral/redeem",
            json={"referral_code": referrer_code},
            headers=referee_headers
        )
        assert double_redeem.status_code == 400
        assert "already redeemed" in double_redeem.json()["detail"]

        # 5. Verify database ledger state in user_wallets
        async with async_session_factory() as session:
            # Check referee wallet
            referee_wallet_res = await session.execute(
                text("SELECT dm_credits, wa_reveal_tokens FROM public.user_wallets WHERE user_id = :uid"),
                {"uid": referee.id}
            )
            rw = referee_wallet_res.first()
            assert rw is not None
            assert rw.dm_credits >= 5
            assert rw.wa_reveal_tokens >= 2

            # Check referrer wallet
            referrer_wallet_res = await session.execute(
                text("SELECT dm_credits, wa_reveal_tokens FROM public.user_wallets WHERE user_id = :uid"),
                {"uid": test_user.id}
            )
            rfw = referrer_wallet_res.first()
            assert rfw is not None
            assert rfw.dm_credits >= 5
            assert rfw.wa_reveal_tokens >= 2

            # Check referral log
            log_res = await session.execute(
                text("SELECT * FROM public.referral_logs WHERE referee_id = :uid"),
                {"uid": referee.id}
            )
            log = log_res.first()
            assert log is not None
            assert log.referrer_id == test_user.id
            assert log.referral_code_used == referrer_code

    finally:
        app.dependency_overrides.pop(get_current_user, None)
        async with async_session_factory() as session:
            await session.execute(text("DELETE FROM public.referral_logs WHERE referee_id = :uid"), {"uid": referee.id})
            db_referee = await session.get(User, referee.id)
            if db_referee:
                await session.delete(db_referee)
            await session.commit()
