import math


class GeoEngineService:
    """Service handling distance calculation and rural location obfuscation."""

    @staticmethod
    def obfuscate_distance(distance_in_km: float) -> str:
        """
        Converts exact distance into generalized obfuscated label for rural privacy.

        < 2.0 km  -> "Within 2 km"
        <= 5.0 km -> "Within 5 km"
        > 5.0 km  -> "Within 10 km"
        """
        if distance_in_km < 2.0:
            return "Within 2 km"
        elif distance_in_km <= 5.0:
            return "Within 5 km"
        else:
            return "Within 10 km"

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
