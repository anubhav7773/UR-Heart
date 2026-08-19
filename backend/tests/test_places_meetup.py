from unittest.mock import MagicMock, AsyncMock, patch
import pytest
import httpx
import time
from fastapi.testclient import TestClient
from app.main import app
from app.services.places_service import PlacesService, BLACKLIST_REGEX, _CACHE
from app.services.geo_engine import GeoEngineService
try:
    from tests.test_auth import get_social_login_token
except ImportError:
    from backend.tests.test_auth import get_social_login_token

client = TestClient(app)

SAMPLE_OSM_RESPONSE = {
    "elements": [
        {
            "id": 101,
            "lat": 28.6145,
            "lon": 77.2095,
            "tags": {"name": "Blue Tokai Coffee Roasters", "amenity": "cafe", "addr:city": "New Delhi"}
        },
        {
            "id": 102,
            "lat": 28.6180,
            "lon": 77.2120,
            "tags": {"name": "Saravana Bhavan", "amenity": "restaurant", "addr:city": "Connaught Place"}
        },
        {
            "id": 103,
            "lat": 28.6120,
            "lon": 77.2080,
            "tags": {"name": "Chai Point Express", "amenity": "fast_food", "cuisine": "tea", "addr:city": "New Delhi"}
        },
        {
            "id": 104,
            "lat": 28.6200,
            "lon": 77.2150,
            "tags": {"name": "The Imperial Hotel", "tourism": "hotel", "addr:city": "Janpath"}
        },
        {
            "id": 105,
            "lat": 29.5000,
            "lon": 78.5000,  # ~160km away (Must be discarded by 50km ceiling)
            "tags": {"name": "Far Distant Highway Dhaba", "amenity": "restaurant"}
        },
    ]
}


def make_mock_response():
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = SAMPLE_OSM_RESPONSE
    return mock_resp


@pytest.mark.asyncio
async def test_places_service_aggregation_and_50km_ceiling():
    _CACHE.clear()
    lat, lon = 28.6139, 77.2090
    with patch.object(httpx.AsyncClient, "post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = make_mock_response()

        response = await PlacesService.fetch_nearby_spots(lat, lon, radius_meters=50000)

        assert response.total > 0
        assert len(response.spots) > 0
        assert response.center_lat == lat
        assert response.center_lon == lon

        # Verify strict 50km ceiling: no spot > 50.0 km
        for spot in response.spots:
            assert spot.distance_km <= 50.0

        # Test that results are sorted ascending by distance
        for i in range(len(response.spots) - 1):
            assert response.spots[i].distance_km <= response.spots[i + 1].distance_km

        # Check spot fields
        first_spot = response.spots[0]
        assert first_spot.id.startswith("osm_")
        assert first_spot.name
        assert first_spot.category in ("chai", "cafe", "restaurant", "hotel")
        assert first_spot.category_label
        assert first_spot.distance_km >= 0
        assert "away" in first_spot.distance_label
        assert first_spot.maps_url.startswith("https://www.google.com/maps")
        assert first_spot.is_verified is True


@pytest.mark.asyncio
async def test_places_service_ttl_cache_speedup():
    _CACHE.clear()
    lat, lon = 28.6139, 77.2090
    with patch.object(httpx.AsyncClient, "post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = make_mock_response()

        # 1. Initial hit (populates cache)
        t0 = time.time()
        resp1 = await PlacesService.fetch_nearby_spots(lat, lon)
        duration1 = time.time() - t0

        # 2. Cached hit (should return instantaneously in < 50ms)
        t1 = time.time()
        resp2 = await PlacesService.fetch_nearby_spots(lat, lon)
        duration2 = time.time() - t1

        assert duration2 < 0.05
        assert resp1.total == resp2.total


@pytest.mark.asyncio
async def test_places_service_category_filtering():
    _CACHE.clear()
    lat, lon = 28.6139, 77.2090
    with patch.object(httpx.AsyncClient, "post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = make_mock_response()

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
    # Dynamic radius should be bounded up to 50km
    assert 5000 <= radius_m <= 50000


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
        "Ram Shop",
        "Gita Dukan",
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
    _CACHE.clear()
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}

    lat1, lon1 = 28.6139, 77.2090
    lat2, lon2 = 28.4595, 77.0266

    with patch.object(httpx.AsyncClient, "post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = make_mock_response()

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


def test_api_places_nearby_endpoint():
    _CACHE.clear()
    lat, lon = 28.6139, 77.2090

    with patch.object(httpx.AsyncClient, "post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = make_mock_response()

        res = client.get(f"/api/v1/places/nearby?lat={lat}&lon={lon}")
        assert res.status_code == 200
        json_data = res.json()
        assert json_data["status"] == "success"
        assert "count" in json_data
        assert "data" in json_data
        assert isinstance(json_data["data"], list)
        assert len(json_data["data"]) > 0
        names = [s["name"] for s in json_data["data"]]
        assert "Blue Tokai Coffee Roasters" in names
        assert "Saravana Bhavan" in names



