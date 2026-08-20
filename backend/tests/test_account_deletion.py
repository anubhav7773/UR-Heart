import uuid
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import select
from app.main import app
from app.core.database import AsyncSessionLocal
from app.core.security import create_access_token
from app.models.orm import User, UserPhoto, Match, ChatMessage, Swipe, ProfileImpression, GenderEnum, IntentEnum


@pytest.mark.asyncio
async def test_cascade_delete_account():
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()

    async with AsyncSessionLocal() as session:
        # Create User 1
        user1 = User(
            id=user1_id,
            email=f"delete_test_{uuid.uuid4().hex[:6]}@test.com",
            phone_number=f"+9198765{uuid.uuid4().hex[:5]}",
            full_name="Delete Test User 1",
            gender=GenderEnum.male,
            interested_in=GenderEnum.female,
            intent=IntentEnum.casual,
            is_active=True,
        )
        session.add(user1)

        # Create User 2
        user2 = User(
            id=user2_id,
            email=f"partner_test_{uuid.uuid4().hex[:6]}@test.com",
            phone_number=f"+9198764{uuid.uuid4().hex[:5]}",
            full_name="Partner User 2",
            gender=GenderEnum.female,
            interested_in=GenderEnum.male,
            intent=IntentEnum.casual,
            is_active=True,
        )
        session.add(user2)
        await session.flush()

        # Add photo for User 1
        photo = UserPhoto(
            id=uuid.uuid4(),
            user_id=user1_id,
            photo_url="https://mock.supabase.co/storage/v1/object/public/profile-photos/mock_photo.webp",
            is_first_impression=True,
            display_order=0,
        )
        session.add(photo)

        # Add match between User 1 and User 2
        match = Match(
            id=match_id,
            user1_id=user1_id,
            user2_id=user2_id,
        )
        session.add(match)
        await session.flush()

        # Add chat message from User 1
        msg = ChatMessage(
            id=uuid.uuid4(),
            match_id=match_id,
            sender_id=user1_id,
            content="Hello from user 1",
        )
        session.add(msg)

        # Add swipe from User 1
        swipe = Swipe(
            id=uuid.uuid4(),
            swiper_id=user1_id,
            swiped_id=user2_id,
            action=Swipe.action.type.enums[1] if hasattr(Swipe, 'action') and hasattr(Swipe.action, 'type') else "like",
        )
        session.add(swipe)

        # Add profile impression
        impression = ProfileImpression(
            id=uuid.uuid4(),
            visitor_id=user1_id,
            target_id=user2_id,
            action_type="view",
        )
        session.add(impression)

        await session.commit()

    token = create_access_token(subject=str(user1_id))
    headers = {"Authorization": f"Bearer {token}"}

    # Call DELETE /api/v1/users/me
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.delete("/api/v1/users/me", headers=headers)

    assert res.status_code == 200, res.text
    data = res.json()
    assert data["success"] is True
    assert "Account successfully deleted" in data["message"]

    # Verify DB cascade
    async with AsyncSessionLocal() as session:
        # User 1 should be gone
        u1 = (await session.execute(select(User).where(User.id == user1_id))).scalars().first()
        assert u1 is None

        # User 1's photos should be gone
        photos = (await session.execute(select(UserPhoto).where(UserPhoto.user_id == user1_id))).scalars().all()
        assert len(photos) == 0

        # Matches involving User 1 should be gone
        matches = (await session.execute(select(Match).where(Match.id == match_id))).scalars().all()
        assert len(matches) == 0

        # Messages in that match should be gone
        msgs = (await session.execute(select(ChatMessage).where(ChatMessage.match_id == match_id))).scalars().all()
        assert len(msgs) == 0

        # User 2 should still exist
        u2 = (await session.execute(select(User).where(User.id == user2_id))).scalars().first()
        assert u2 is not None

        # Clean up User 2
        await session.delete(u2)
        await session.commit()
