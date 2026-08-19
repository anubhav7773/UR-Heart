import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.places_service import PlacesService, BLACKLIST_REGEX
from app.services.geo_engine import GeoEngineService
try:
    from tests.test_auth import get_social_login_token
except ImportError:
    from backend.tests.test_auth import get_social_login_token

client = TestClient(app)


@pytest.mark.asyncio
async def test_places_service_aggregation():
    # Test nearby spots around Delhi (28.6139, 77.2090)
    lat, lon = 28.6139, 77.2090
    response = await PlacesService.fetch_nearby_spots(lat, lon, radius_meters=15000)

    assert response.total > 0
    assert len(response.spots) > 0
    assert response.center_lat == lat
    assert response.center_lon == lon

    # Test that results are sorted ascending by distance
    for i in range(len(response.spots) - 1):
        assert response.spots[i].distance_meters <= response.spots[i + 1].distance_meters

    # Check spot fields
    first_spot = response.spots[0]
    assert first_spot.id
    assert first_spot.name
    assert first_spot.category in ("chai", "cafe", "restaurant", "hotel")
    assert first_spot.category_label
    assert first_spot.distance_meters >= 0
    assert first_spot.distance_km >= 0
    assert "away" in first_spot.distance_label
    assert first_spot.maps_url.startswith("https://www.google.com/maps")
    assert first_spot.is_verified is True


@pytest.mark.asyncio
async def test_places_service_category_filtering():
    lat, lon = 28.6139, 77.2090

    chai_response = await PlacesService.fetch_nearby_spots(lat, lon, category_filter="chai")
    assert all(s.category == "chai" for s in chai_response.spots)

    cafe_response = await PlacesService.fetch_nearby_spots(lat, lon, category_filter="cafe")
    assert all(s.category == "cafe" for s in cafe_response.spots)

    restaurant_response = await PlacesService.fetch_nearby_spots(lat, lon, category_filter="restaurant")
    assert all(s.category == "restaurant" for s in restaurant_response.spots)

    hotel_response = await PlacesService.fetch_nearby_spots(lat, lon, category_filter="hotel")
    assert all(s.category == "hotel" for s in hotel_response.spots)


def test_geo_engine_haversine():
    # Distance between CP (28.6304, 77.2177) and India Gate (28.6129, 77.2295) is ~2.3 km
    dist = GeoEngineService.calculate_haversine_distance(28.6304, 77.2177, 28.6129, 77.2295)
    assert 1.8 < dist < 2.8


def test_midpoint_computation_and_dynamic_corridor():
    # Test 2 users spaced ~25 km apart (Delhi to Gurgaon)
    lat1, lon1 = 28.6139, 77.2090  # Delhi
    lat2, lon2 = 28.4595, 77.0266  # Gurgaon

    mid_lat, mid_lon, dist_km, radius_m = PlacesService.compute_midpoint(lat1, lon1, lat2, lon2)

    # Validate midpoint coordinates
    assert abs(mid_lat - ((lat1 + lat2) / 2.0)) < 0.0001
    assert abs(mid_lon - ((lon1 + lon2) / 2.0)) < 0.0001
    assert 20.0 <= dist_km <= 30.0
    # Dynamic radius should be capped appropriately (between 5km and 20km)
    assert 5000 <= radius_m <= 20000


def test_strict_zero_garbage_blacklist_regex():
    # Test that blacklisted natural/geographic features match regex
    garbage_names = [
        "Yamuna Nadi",
        "Ganda Nala Drainage",
        "Ramu Ka Khet",
        "Canal Bridge 4",
        "Gram Sabha Land",
        "Sewer Culvert",
        "Jungle Area",
        "Pond water body",
        "Unnamed node",
        "Point 23",
    ]
    for name in garbage_names:
        assert BLACKLIST_REGEX.search(name) is not None, f"Expected '{name}' to match blacklist regex"

    # Test that legitimate commercial names do not match
    legit_names = [
        "Sharma Chai Tapri",
        "The Royal Spice Restaurant",
        "Cafe Velvet Brew",
        "Hotel Grand Skyline",
        "Pind Punjabi Dhaba",
    ]
    for name in legit_names:
        assert BLACKLIST_REGEX.search(name) is None, f"Did not expect '{name}' to match blacklist regex"


def test_api_places_midpoint_endpoint():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}

    lat1, lon1 = 28.6139, 77.2090
    lat2, lon2 = 28.4595, 77.0266

    res = client.get(
        f"/api/v1/places/meetup-spots?lat1={lat1}&lon1={lon1}&lat2={lat2}&lon2={lon2}",
        headers=headers,
    )
    assert res.status_code == 200
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]
    assert data["is_midpoint"] is True
    assert data["user_distance_km"] is not None
    assert len(data["spots"]) > 0
    assert all(s["is_verified"] is True for s in data["spots"])
    assert all("mid-way" in s["distance_label"] for s in data["spots"])
