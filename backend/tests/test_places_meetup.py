import pytest
from app.services.places_service import PlacesService
from app.services.geo_engine import GeoEngineService


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
