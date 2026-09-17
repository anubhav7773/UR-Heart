import pytest
import pytest_asyncio
import httpx
from uuid import uuid4
from datetime import date
from app.main import app
from app.core.database import async_session_factory, engine
from app.api.dependencies import get_current_user
from app.models.domain.user import User

@pytest_asyncio.fixture
async def db_session():
    async with async_session_factory() as session:
        yield session

@pytest_asyncio.fixture
async def async_client():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

@pytest_asyncio.fixture
async def test_user():
    u = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Current Test User",
        dob=date(1999, 1, 1),
        gender="male",
        city="Lucknow",
        bio="Test current user",
        is_banned=False,
    )
    async with async_session_factory() as session:
        session.add(u)
        await session.commit()
    
    yield u

    async with async_session_factory() as session:
        db_u = await session.get(User, u.id)
        if db_u:
            await session.delete(db_u)
            await session.commit()

@pytest_asyncio.fixture
async def auth_headers(test_user):
    app.dependency_overrides[get_current_user] = lambda: test_user
    yield {"Authorization": "Bearer mock_valid_test_token"}
    app.dependency_overrides.pop(get_current_user, None)
