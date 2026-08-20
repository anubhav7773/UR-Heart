from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from datetime import date


class ProfileUpdateRequest(BaseModel):
    display_name: Optional[str] = Field(None, min_length=2, max_length=50)
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    birthdate: Optional[date] = None
    dob: Optional[date] = None
    gender: Optional[str] = Field(None, max_length=20)
    gender_preference: Optional[str] = Field(None, max_length=20)
    interested_in: Optional[str] = Field(None, max_length=20)
    intent: Optional[str] = Field(None, max_length=30)
    area_name: Optional[str] = Field(None, max_length=100)
    village_pin_code: Optional[str] = Field(None, max_length=10)
    interests: Optional[List[str]] = Field(None, max_length=10)
    height: Optional[int] = Field(None, ge=100, le=250)
    relationship_goal: Optional[str] = Field(None, max_length=50)
    smoking: Optional[str] = Field(None, max_length=30)
    drinking: Optional[str] = Field(None, max_length=30)
    is_location_masked: Optional[bool] = None

    # Forbid or ignore any injection of privileged fields
    model_config = ConfigDict(extra="ignore")
