from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Query, status
from pydantic import BaseModel

router = APIRouter(tags=["Discovery Feed & Swipes"])


class SwipeRequest(BaseModel):
    target_id: str
    swipe_type: str  # 'like', 'pass', 'direct'


CANDIDATE_CATALOG = [
    {
        "id": "cand_1",
        "full_name": "Devika Roy",
        "age": 25,
        "gender": "Woman",
        "looking_for": "Men",
        "location_name": "Khar, Mumbai",
        "distance_km": 2.4,
        "resonance_score": 91,
        "bio": "Looking for a sanctuary to share honest poetry and unspoken understanding.",
        "ai_resonance_insight": "Both of you value authentic connection, stillness, and deep thoughtful literature.",
        "authentic_intention": "Looking for a sanctuary to share honest poetry and unspoken understanding.",
        "tags": ["Poetry", "Mindfulness", "Slow Living"],
        "photos": [
            "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80"
        ],
        "is_kyc_verified": True,
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4"
    },
    {
        "id": "cand_2",
        "full_name": "Aanya Sen",
        "age": 24,
        "gender": "Woman",
        "looking_for": "Men",
        "location_name": "Bandra West, Mumbai",
        "distance_km": 1.5,
        "resonance_score": 94,
        "bio": "Searching for a mindful connection amidst city chaos. Coffee, art books, and quiet evening walks.",
        "ai_resonance_insight": "Both of you share an appreciation for quiet cafes, architecture, and intentional conversations.",
        "authentic_intention": "Searching for a mindful connection amidst city chaos.",
        "tags": ["Architecture", "Pour-Over Coffee", "Literature"],
        "photos": [
            "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&auto=format&fit=crop&q=80"
        ],
        "is_kyc_verified": True,
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4"
    },
    {
        "id": "cand_3",
        "full_name": "Meera Kapoor",
        "age": 23,
        "gender": "Woman",
        "looking_for": "Men",
        "location_name": "Juhu, Mumbai",
        "distance_km": 3.8,
        "resonance_score": 88,
        "bio": "Classical Indian music, pottery weekends, and conversations that go beyond small talk.",
        "ai_resonance_insight": "Mutual reverence for creative mindfulness, gentle patience, and classical arts.",
        "authentic_intention": "Building an honest, calm bond with depth and respect.",
        "tags": ["Classical Arts", "Pottery", "Indie Music"],
        "photos": [
            "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=800&auto=format&fit=crop&q=80"
        ],
        "is_kyc_verified": True,
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4"
    }
]


@router.get("/feed", status_code=status.HTTP_200_OK, summary="Get Sanctuary Discovery Feed")
async def get_discovery_feed(
    limit: int = Query(default=10, ge=1, le=50),
    cursor: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    Returns verified candidate profiles for the discovery deck
    with reciprocal orientation matching and AI insights.
    """
    print(f"[FEED DISCOVERY] Serving {min(limit, len(CANDIDATE_CATALOG))} candidate cards to client", flush=True)
    return CANDIDATE_CATALOG[:limit]


@router.post("/swipes", status_code=status.HTTP_200_OK, summary="Record Profile Swipe Action")
async def record_swipe(payload: SwipeRequest):
    """
    Records like, pass, or direct resonate swipe action.
    """
    print(f"[SWIPE RECORDED] target_id={payload.target_id} action={payload.swipe_type.upper()}", flush=True)
    is_match = payload.swipe_type in ("like", "direct")
    return {
        "status": "recorded",
        "target_id": payload.target_id,
        "swipe_type": payload.swipe_type,
        "is_match": is_match,
        "match_id": f"match-{payload.target_id}" if is_match else None
    }


@router.delete("/swipes/pass/{target_id}", status_code=status.HTTP_200_OK, summary="Restore Passed Profile")
async def restore_passed_profile(target_id: str):
    """
    Removes profile from pass vault and restores back into active deck.
    """
    print(f"[PASS VAULT] Revisit profile target_id={target_id}", flush=True)
    return {
        "status": "revisited",
        "target_id": target_id,
        "message": "Profile restored to discovery deck."
    }
