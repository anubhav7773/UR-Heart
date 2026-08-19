from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.api.v1.auth import get_current_user_id
from app.models.schemas import APIResponse, MeetupSpotsResponse
from app.services.places_service import PlacesService

router = APIRouter(prefix="/places", tags=["Places & Date Radar"])


@router.get("/meetup-spots", response_model=APIResponse[MeetupSpotsResponse])
async def get_meetup_spots(
    lat: float = Query(..., description="Current user or midpoint latitude (-90 to 90)"),
    lon: float = Query(..., description="Current user or midpoint longitude (-180 to 180)"),
    radius_meters: int = Query(15000, ge=500, le=50000, description="Search radius in meters"),
    category: Optional[str] = Query(None, description="Optional category filter: chai, cafe, restaurant, hotel"),
    current_user_id: str = Depends(get_current_user_id),
):
    """
    Comprehensive Local Meetup Spot Radar endpoint.
    Fetches all nearby spots (Tea tapris, Cafes, Restaurants, Hotels) sorted nearest to furthest.
    """
    if lat < -90 or lat > 90 or lon < -180 or lon > 180:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid coordinates supplied.",
        )

    response = await PlacesService.fetch_nearby_spots(
        lat=lat,
        lon=lon,
        radius_meters=radius_meters,
        category_filter=category,
    )

    return APIResponse(
        success=True,
        data=response,
        message=f"Found {response.total} local date spots nearby.",
    )
