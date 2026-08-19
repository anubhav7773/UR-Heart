import math
import re
import time
from typing import List, Optional, Tuple, Dict, Any
import httpx
from app.models.schemas import MeetupSpotData, MeetupSpotsResponse


CATEGORY_LABELS = {
    "chai": "Chai & Snacks",
    "cafe": "Cafes & Bakes",
    "restaurant": "Restaurants & Dhabas",
    "hotel": "Hotels & Lounges",
}

# Strict Blacklist Regex: Drop natural, agricultural, drain, and non-commercial generic terms
BLACKLIST_REGEX = re.compile(
    r"(?i)(nadi|nala|nalla|drain|khet|field|canal|sewer|bridge|culvert|plot|jungle|gram\s*sabha|talab|pond|unnamed|\bpoint\b|\bnode\b|\bshop\b|\bdukan\b)",
    re.IGNORECASE,
)

# Blacklisted OSM Tag Keys indicating non-commercial physical features
BLACKLIST_TAG_KEYS = {
    "waterway",
    "natural",
    "landuse",
    "highway",
    "barrier",
    "boundary",
    "man_made",
    "power",
    "railway",
}

# High-Availability Overpass Mirrors with 8.0s timeout
OVERPASS_MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

# In-memory TTL cache (6 Hours)
_CACHE: Dict[str, Dict[str, Any]] = {}
CACHE_TTL_SECONDS = 3600 * 6  # 6 Hours


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates geodesic distance in kilometers between two points."""
    R = 6371.0  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 1)


class PlacesService:
    """
    Tiered Radius & Strict Commercial Quality Places Engine:
    1. 3-Stage Tiered Radius (0-15km -> 15-35km -> 35-50km hard ceiling).
    2. Strict Commercial Quality Filter & Junk Rejection.
    3. In-Memory TTL Caching (6h) & Resilient Multi-Mirror Overpass Fallback.
    """

    @classmethod
    def compute_midpoint(
        cls,
        lat1: float,
        lon1: float,
        lat2: float,
        lon2: float,
    ) -> Tuple[float, float, float, int]:
        """
        Calculates the geodesic midpoint between User A and User B.
        Corridor search radius is bounded up to 50 km hard ceiling.
        """
        mid_lat = (lat1 + lat2) / 2.0
        mid_lon = (lon1 + lon2) / 2.0
        dist_km = haversine(lat1, lon1, lat2, lon2)

        half_dist = (dist_km / 2.0) * 1.2
        radius_m = int(max(5000, min(50000, half_dist * 1000)))

        return round(mid_lat, 6), round(mid_lon, 6), round(dist_km, 2), radius_m

    @classmethod
    async def fetch_nearby_spots(
        cls,
        lat: float,
        lon: float,
        radius_meters: int = 50000,
        category_filter: Optional[str] = None,
        is_midpoint: bool = False,
        user_distance_km: Optional[float] = None,
    ) -> MeetupSpotsResponse:
        """
        Fetches and ranks verified commercial date spots around (lat, lon) within a strict 50 km hard ceiling.
        Employs 3-Stage Tiered Radius (15km -> 35km -> 50km) and in-memory TTL caching.
        """
        cache_key = f"{round(lat, 2)}_{round(lon, 2)}_{category_filter or 'all'}_{is_midpoint}"
        now = time.time()

        if cache_key in _CACHE and (now - _CACHE[cache_key]["time"] < CACHE_TTL_SECONDS):
            cached_spots: List[MeetupSpotData] = _CACHE[cache_key]["data"]
            return MeetupSpotsResponse(
                total=len(cached_spots),
                spots=cached_spots,
                center_lat=lat,
                center_lon=lon,
                is_midpoint=is_midpoint,
                user_distance_km=user_distance_km,
                search_radius_meters=min(radius_meters, 50000),
                notice=None if cached_spots else "No registered commercial meetup spots found within 0-50 km.",
            )

        # 3-Stage Tiered Radius Expansion (15 km -> 35 km -> 50 km max)
        elements: List[Dict[str, Any]] = []
        for tier_radius in [15000, 35000, 50000]:
            tier_elements = await cls._query_overpass(lat, lon, tier_radius)
            if len(tier_elements) >= 3:
                elements = tier_elements
                break
            if tier_elements:
                elements = tier_elements

        spots: List[MeetupSpotData] = []
        seen_names = set()

        for el in elements:
            tags = el.get("tags", {})
            name = (tags.get("name") or tags.get("brand") or "").strip()

            # 1. Reject invalid, empty, or duplicate names (< 3 chars)
            if not name or len(name) < 3 or name.lower() in seen_names:
                continue
            if name.lower() in ("unnamed", "point", "null", "none", "node", "shop", "dukan"):
                continue

            # 2. Strict Blacklist Regex Filter
            if BLACKLIST_REGEX.search(name):
                continue

            # 3. Strict Blacklisted Tag Keys
            if any(k in tags for k in BLACKLIST_TAG_KEYS):
                continue

            # Center coordinates for ways/nodes/relations
            s_lat = el.get("lat") or el.get("center", {}).get("lat")
            s_lon = el.get("lon") or el.get("center", {}).get("lon")
            if s_lat is None or s_lon is None:
                continue

            s_lat = float(s_lat)
            s_lon = float(s_lon)
            if s_lat == 0.0 and s_lon == 0.0:
                continue

            # Strict 50 km Hard Ceiling
            dist_km = haversine(lat, lon, s_lat, s_lon)
            if dist_km > 50.0:
                continue

            # 4. Strict Commercial Whitelist Verification
            amenity = tags.get("amenity", "").lower()
            tourism = tags.get("tourism", "").lower()
            shop = tags.get("shop", "").lower()
            cuisine = tags.get("cuisine", "").lower()
            name_lower = name.lower()

            is_chai = (
                amenity == "cafe"
                or any(w in cuisine for w in ("tea", "chai", "coffee", "bakery", "sweets", "fast_food"))
                or any(w in name_lower for w in ("tea", "chai", "cafe", "bakes", "coffee", "sweets"))
            )
            is_restaurant = amenity in ("restaurant", "food_court")
            is_hotel = tourism in ("hotel", "guest_house", "resort")

            if not (is_chai or is_restaurant or is_hotel or amenity == "fast_food"):
                continue

            seen_names.add(name.lower())
            dist_m = int(dist_km * 1000)

            # Classify category
            if is_hotel:
                cat = "hotel"
            elif is_restaurant:
                cat = "restaurant"
            elif is_chai or amenity == "cafe":
                cat = "chai"
            elif amenity == "fast_food" or shop == "bakery":
                cat = "cafe"
            else:
                cat = "restaurant"

            if is_midpoint:
                dist_label = f"{dist_m}m from mid-way" if dist_m < 1000 else f"{dist_km:.1f} km from mid-way"
            else:
                dist_label = f"{dist_m}m away" if dist_m < 1000 else f"{dist_km:.1f} km away"

            addr_parts = [
                tags.get("addr:street"),
                tags.get("addr:suburb") or tags.get("addr:neighbourhood"),
                tags.get("addr:city"),
            ]
            clean_addr = ", ".join([p for p in addr_parts if p]) or f"Approx. {dist_km:.1f} km away"

            maps_url = f"https://www.google.com/maps/search/?api=1&query={s_lat},{s_lon}"

            spots.append(
                MeetupSpotData(
                    id=f"osm_{el.get('id', '')}",
                    name=name,
                    category=cat,
                    category_label=CATEGORY_LABELS.get(cat, "Spot"),
                    distance_meters=dist_m,
                    distance_km=dist_km,
                    distance_label=dist_label,
                    address=clean_addr,
                    latitude=s_lat,
                    longitude=s_lon,
                    maps_url=maps_url,
                    phone=tags.get("phone") or tags.get("contact:phone"),
                    rating=4.5,
                    place_id=tags.get("place_id"),
                    is_verified=True,
                )
            )

        # Apply category filter if specified
        if category_filter and category_filter.lower() in ("chai", "cafe", "restaurant", "hotel"):
            spots = [s for s in spots if s.category == category_filter.lower()]

        # Sort strictly nearest to furthest
        spots.sort(key=lambda x: x.distance_km)
        result = spots[:20]  # Cap payload to top 20 verified spots

        # Save to cache
        _CACHE[cache_key] = {"time": now, "data": result}

        return MeetupSpotsResponse(
            total=len(result),
            spots=result,
            center_lat=lat,
            center_lon=lon,
            is_midpoint=is_midpoint,
            user_distance_km=user_distance_km,
            search_radius_meters=min(radius_meters, 50000),
            notice=None if result else "No registered commercial meetup spots found within 0-50 km.",
        )

    @classmethod
    async def _query_overpass(
        cls,
        lat: float,
        lon: float,
        radius_m: int,
    ) -> List[Dict[str, Any]]:
        """
        Executes an optimized Overpass query across high-speed mirrors with 8.0s timeout.
        """
        query = f"""
        [out:json][timeout:8];
        (
          nwr["amenity"~"cafe|restaurant|fast_food"]["name"](around:{radius_m},{lat},{lon});
          nwr["tourism"~"hotel|guest_house"]["name"](around:{radius_m},{lat},{lon});
        );
        out center 40;
        """

        async with httpx.AsyncClient(timeout=8.0) as client:
            for mirror in OVERPASS_MIRRORS:
                try:
                    resp = await client.post(mirror, data={"data": query})
                    if resp.status_code == 200:
                        data = resp.json()
                        if data and "elements" in data:
                            return data.get("elements", [])
                except Exception:
                    continue
        return []
