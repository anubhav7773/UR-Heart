from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List

class FeedProfileResponse(BaseModel):
    id: str
    name: str
    age: Optional[int] = None
    bio: Optional[str] = None
    photos: List[str] = []
    # 🛡️ ONLY return distance_km, NEVER raw latitude or longitude
    distance_km: float = Field(..., description="Calculated radial distance in km")
    is_online: bool = False

    model_config = ConfigDict(
        from_attributes=True,
        extra='ignore',
    )
