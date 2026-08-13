import math
from typing import Optional


class GeoEngineService:
    """Service handling distance calculation and rural location obfuscation."""

    @staticmethod
    def obfuscate_distance(distance_in_km: float) -> str:
        """
        Converts exact distance into clean, readable labels:
        < 1.0 km  -> "Less than 1 km away"
        <= 2.0 km -> "Within 2 km"
        <= 5.0 km -> "Within 5 km"
        <= 10.0 km -> "Within 10 km"
        > 10.0 km -> f"Within {int(math.ceil(distance_in_km))} km"
        """
        if distance_in_km < 1.0:
            return "Less than 1 km away"
        elif distance_in_km <= 2.0:
            return "Within 2 km"
        elif distance_in_km <= 5.0:
            return "Within 5 km"
        elif distance_in_km <= 10.0:
            return "Within 10 km"
        else:
            return f"Within {int(math.ceil(distance_in_km))} km"

    @staticmethod
    def calculate_haversine_distance(
        lat1: float, lon1: float, lat2: float, lon2: float
    ) -> float:
        """
        Calculates distance in kilometers between two GPS points using Haversine formula.
        """
        R = 6371.0  # Earth radius in kilometers

        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)

        a = (
            math.sin(dlat / 2) ** 2
            + math.cos(math.radians(lat1))
            * math.cos(math.radians(lat2))
            * math.sin(dlon / 2) ** 2
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    @classmethod
    def distance_between_users(cls, user_a: object, user_b: object) -> Optional[float]:
        """Return live GPS distance, or None when either user has no GPS fix."""
        a_lat, a_lon = getattr(user_a, "latitude", None), getattr(user_a, "longitude", None)
        b_lat, b_lon = getattr(user_b, "latitude", None), getattr(user_b, "longitude", None)
        if None in (a_lat, a_lon, b_lat, b_lon):
            return None
        return cls.calculate_haversine_distance(float(a_lat), float(a_lon), float(b_lat), float(b_lon))
