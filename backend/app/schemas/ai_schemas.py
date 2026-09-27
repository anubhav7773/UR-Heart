from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class BioPolishRequest(BaseModel):
    raw_bio: str = Field(..., min_length=5, max_length=500)
    intent: Optional[str] = Field("mindful", description="Stylistic direction (mindful, poetic, concise)")


class BioPolishResponse(BaseModel):
    polished_bio: str
    original_bio: str


class IcebreakerRequest(BaseModel):
    user_a: Dict[str, Any] = Field(..., description="First user profile and interests")
    user_b: Dict[str, Any] = Field(..., description="Second user profile and interests")


class IcebreakerResponse(BaseModel):
    icebreakers: List[str]


class ResonanceScoreRequest(BaseModel):
    profile_a: Dict[str, Any]
    profile_b: Dict[str, Any]


class ResonanceScoreResponse(BaseModel):
    resonance_percentage: int = Field(..., ge=0, le=100)
    harmony_summary: str
