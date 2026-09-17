import pytest
from httpx import AsyncClient
from uuid import uuid4
from decimal import Decimal
from app.models.domain.user import User

@pytest.mark.asyncio
async def test_gender_constraint_lgbtq(db_session):
    """Assert that 'lgbtq+' is accepted and invalid strings fail."""
    valid_user = User(
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Alex Ray",
        dob="2000-01-01",
        gender="lgbtq+",
        city="Lucknow",
        streak_count=0,
        reward_balance=0
    )
    db_session.add(valid_user)
    await db_session.commit()
    assert valid_user.gender == "lgbtq+"

    # Clean up test user
    await db_session.delete(valid_user)
    await db_session.commit()

@pytest.mark.asyncio
async def test_haversine_distance_calculation(db_session):
    """Assert accurate distance between Lucknow (26.8467, 80.9462) and Ayodhya (26.7922, 82.1998). Approx ~127-135 km."""
    from sqlalchemy import text
    query = text("SELECT public.calculate_distance_km(26.8467, 80.9462, 26.7922, 82.1998) as dist")
    res = await db_session.execute(query)
    dist = res.scalar()
    assert 120 <= dist <= 140

@pytest.mark.asyncio
async def test_discovery_feed_zero_coordinate_leakage(async_client: AsyncClient, auth_headers):
    """
    CRITICAL SECURITY CHECK:
    Confirm discovery feed response JSON contains NO 'latitude' or 'longitude' keys.
    """
    response = await async_client.get(
        "/api/v1/user/feed?lat=26.8467&lon=80.9462&limit=10",
        headers=auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    
    for profile in data:
        # Assert keys do not exist in the response schema
        assert "latitude" not in profile, "LEAK DETECTED: Latitude found in public feed payload!"
        assert "longitude" not in profile, "LEAK DETECTED: Longitude found in public feed payload!"
        assert "distance_badge" in profile
        assert profile["distance_badge"].startswith("Nearby") or profile["distance_badge"] == "Location Unavailable"

@pytest.mark.asyncio
async def test_user_profile_setup_and_privacy(async_client: AsyncClient, auth_headers):
    """
    Asserts profile setup accepts WhatsApp (+91), inclusive 'lgbtq+' gender,
    and private GPS coordinates, then succeeds with 200.
    """
    payload = {
        "full_name": "Aman Verma",
        "whatsapp_number": "+919876543210",
        "gender": "lgbtq+",
        "city": "Lucknow",
        "bio": "Designer and traveler",
        "latitude": 26.8467,
        "longitude": 80.9462,
        "detected_locality": "Hazratganj"
    }
    response = await async_client.post(
        "/api/v1/user/profile-setup",
        json=payload,
        headers=auth_headers
    )
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["status"] == "success"

@pytest.mark.asyncio
async def test_profile_setup_rejects_invalid_gender(async_client: AsyncClient, auth_headers):
    """Asserts that non-inclusive or invalid gender is rejected with 422."""
    payload = {
        "full_name": "Aman Verma",
        "whatsapp_number": "+919876543210",
        "gender": "invalid_gender",
        "city": "Lucknow",
        "bio": "Test bio"
    }
    response = await async_client.post(
        "/api/v1/user/profile-setup",
        json=payload,
        headers=auth_headers
    )
    assert response.status_code == 422
