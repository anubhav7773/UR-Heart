import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services.ai_orchestrator import AiOrchestrator
from app.services.groq_service import GroqAiService
from app.core.security import create_access_token


@pytest.mark.asyncio
async def test_bio_polish_short_input_quality():
    """Verify bio polish takes 2-3 words and crafts an authentic, non-empty, charming bio."""
    raw_input = "gym, chai, sunset"
    bio = await GroqAiService.polish_bio_secure(raw_input)
    assert bio is not None
    assert len(bio.split()) >= 10
    # Must NOT be an unexpanded raw copy
    assert bio.strip() != raw_input
    # Must be non-generic
    assert "Passionate about gym, chai, sunset. Grounded in quiet rituals" not in bio


@pytest.mark.asyncio
async def test_chat_bonding_sparks_generation():
    """Verify in-chat bonding wingmate generates 2-3 contextual suggestions."""
    recent_msgs = [
        {"sender": "partner", "text": "I really enjoy hiking and finding peaceful viewpoints."},
        {"sender": "me", "text": "Same here! There is something special about the stillness."}
    ]
    result = await AiOrchestrator.generate_chat_sparks(
        partner_name="Aarohi",
        partner_bio="Nature lover, bookworm, loves filter coffee",
        recent_messages=recent_msgs
    )
    assert "sparks" in result
    sparks = result["sparks"]
    assert isinstance(sparks, list)
    assert len(sparks) >= 2
    for spark in sparks:
        assert isinstance(spark, str)
        assert len(spark.strip()) > 5


@pytest.mark.asyncio
async def test_chat_sparks_endpoint_authenticated():
    """Verify /api/v1/ai/eva/chat-sparks endpoint returns valid sparks for authenticated seeker."""
    token = create_access_token({"sub": "seeker@urheart.app"})
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/ai/eva/chat-sparks",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "partner_name": "Meera",
                "partner_bio": "Architect & classical singer",
                "recent_messages": [
                    {"sender": "partner", "text": "Do you listen to any classical music?"}
                ]
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "sparks" in data
        assert len(data["sparks"]) >= 1
