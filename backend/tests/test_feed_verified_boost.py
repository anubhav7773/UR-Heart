import pytest
import pytest_asyncio
from uuid import uuid4
from datetime import date
from httpx import AsyncClient
from sqlalchemy import text
from app.core.database import async_session_factory
from app.models.domain.user import User

@pytest.fixture
def test_auth_headers(auth_headers):
    return auth_headers

@pytest.mark.asyncio
async def test_feed_prioritizes_verified_profiles(async_client: AsyncClient, test_auth_headers, test_user: User):
    """
    Verifies that candidates with kyc_status = True are sorted ahead of unverified profiles.
    """
    # Seed 1 verified and 1 unverified candidate in the database
    v_id = uuid4()
    u_id = uuid4()

    async with async_session_factory() as session:
        verified_candidate = User(
            id=v_id,
            firebase_uid=str(uuid4()),
            phone_number=f"+9198{str(uuid4().int)[:8]}",
            whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
            full_name="Verified Model Candidate",
            dob=date(1998, 1, 1),
            gender="female",
            city="Lucknow",
            bio="Verified profile bio",
            kyc_status=True,
            is_banned=False,
        )
        unverified_candidate = User(
            id=u_id,
            firebase_uid=str(uuid4()),
            phone_number=f"+9198{str(uuid4().int)[:8]}",
            whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
            full_name="Unverified Model Candidate",
            dob=date(1999, 1, 1),
            gender="female",
            city="Lucknow",
            bio="Unverified profile bio",
            kyc_status=False,
            is_banned=False,
        )
        session.add_all([verified_candidate, unverified_candidate])
        await session.commit()

    try:
        response = await async_client.get("/api/v1/feed?limit=20", headers=test_auth_headers)
        assert response.status_code == 200
        candidates = response.json()
        assert len(candidates) >= 2

        # Check that verified profiles lead the returned batch
        verified_statuses = [c.get("is_verified", False) for c in candidates]
        seen_unverified = False
        for is_v in verified_statuses:
            if not is_v:
                seen_unverified = True
            if seen_unverified and is_v:
                pytest.fail("Unverified candidate ranked higher than a verified candidate in discovery feed.")

        # Ensure our verified test candidate has is_verified == True
        matched_verified = [c for c in candidates if c.get("user_id") == str(v_id)]
        if matched_verified:
            assert matched_verified[0]["is_verified"] is True
    finally:
        async with async_session_factory() as session:
            db_v = await session.get(User, v_id)
            if db_v:
                await session.delete(db_v)
            db_u = await session.get(User, u_id)
            if db_u:
                await session.delete(db_u)
            await session.commit()
