from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.api.v1.auth import get_current_user_id
from app.models.schemas import APIResponse, MeetupSpotsResponse
from app.services.places_service import PlacesService

router = APIRouter(prefix="/places", tags=["Places & Date Radar"])


@router.get("/meetup-spots", response_model=APIResponse[MeetupSpotsResponse])
async def get_meetup_spots(
    lat: Optional[float] = Query(None, description="Current user or midpoint latitude (-90 to 90)"),
    lon: Optional[float] = Query(None, description="Current user or midpoint longitude (-180 to 180)"),
    lat1: Optional[float] = Query(None, description="User A latitude (-90 to 90) for midpoint calculation"),
    lon1: Optional[float] = Query(None, description="User A longitude (-180 to 180) for midpoint calculation"),
    lat2: Optional[float] = Query(None, description="User B latitude (-90 to 90) for midpoint calculation"),
    lon2: Optional[float] = Query(None, description="User B longitude (-180 to 180) for midpoint calculation"),
    radius_meters: Optional[int] = Query(None, ge=500, le=50000, description="Optional search radius in meters"),
    category: Optional[str] = Query(None, description="Optional category filter: chai, cafe, restaurant, hotel"),
    current_user_id: str = Depends(get_current_user_id),
):
    """
    Precision Geo-Filtering & Midpoint Meetup Spots Aggregator:
    - If (lat1, lon1) and (lat2, lon2) are supplied: Computes geodesic midpoint and dynamic corridor radius.
    - If (lat, lon) is supplied: Uses the provided center point.
    - Applies strict zero-garbage commercial filtering (OSM whitelist, regex blacklists).
    - Produces high-reliability Google Maps direct business search URLs.
    """
    is_midpoint = False
    user_dist_km: Optional[float] = None
    target_radius = radius_meters or 15000

    if lat1 is not None and lon1 is not None and lat2 is not None and lon2 is not None:
        # Validate coordinates
        for c_lat, c_lon in [(lat1, lon1), (lat2, lon2)]:
            if c_lat < -90 or c_lat > 90 or c_lon < -180 or c_lon > 180:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid coordinate values supplied for midpoint calculation.",
                )
        center_lat, center_lon, user_dist_km, dynamic_radius = PlacesService.compute_midpoint(
            lat1, lon1, lat2, lon2
        )
        is_midpoint = True
        target_radius = radius_meters or dynamic_radius
    elif lat is not None and lon is not None:
        if lat < -90 or lat > 90 or lon < -180 or lon > 180:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid coordinates supplied.",
            )
        center_lat = lat
        center_lon = lon
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must supply either (lat, lon) or both (lat1, lon1) and (lat2, lon2).",
        )

    response = await PlacesService.fetch_nearby_spots(
        lat=center_lat,
        lon=center_lon,
        radius_meters=target_radius,
        category_filter=category,
        is_midpoint=is_midpoint,
        user_distance_km=user_dist_km,
    )

    return APIResponse(
        success=True,
        data=response,
        message=f"Found {response.total} verified date spots {'around midpoint' if is_midpoint else 'nearby'}.",
    )
