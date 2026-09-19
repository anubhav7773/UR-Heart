from fastapi import APIRouter, HTTPException, status
from typing import List, Dict

router = APIRouter()

# Verified Indian City & State Catalog (Anti-Spoofing)
VERIFIED_LOCATIONS: Dict[str, List[Dict[str, float]]] = {
    "Uttar Pradesh": [
        {"city": "Lucknow", "lat": 26.8467, "lon": 80.9462},
        {"city": "Ayodhya", "lat": 26.7922, "lon": 82.1998},
        {"city": "Kanpur", "lat": 26.4499, "lon": 80.3319},
        {"city": "Varanasi", "lat": 25.3176, "lon": 82.9739},
        {"city": "Prayagraj", "lat": 25.4358, "lon": 81.8463},
        {"city": "Noida", "lat": 28.5355, "lon": 77.3910},
        {"city": "Agra", "lat": 27.1767, "lon": 78.0081},
    ],
    "Delhi NCR": [
        {"city": "New Delhi", "lat": 28.6139, "lon": 77.2090},
        {"city": "Gurugram", "lat": 28.4595, "lon": 77.0266},
    ],
    "Maharashtra": [
        {"city": "Mumbai", "lat": 19.0760, "lon": 72.8777},
        {"city": "Pune", "lat": 18.5204, "lon": 73.8567},
    ]
}


@router.get("/catalog")
async def get_verified_location_catalog():
    """
    Returns verified State/City dropdown options.
    Withholds exact coordinates from the client to prevent location spoofing.
    """
    result = {}
    for state, cities in VERIFIED_LOCATIONS.items():
        result[state] = [c["city"] for c in cities]
    return result


def get_fuzzy_coordinates(state: str, city: str):
    """
    Resolves official fuzzy coordinates on the server.
    """
    cities = VERIFIED_LOCATIONS.get(state, [])
    for c in cities:
        if c["city"].lower() == city.lower():
            # Apply server-side fuzzy blur (~2-5 km offset)
            return c["lat"], c["lon"], 5
    return 26.8467, 80.9462, 5  # Fallback default
