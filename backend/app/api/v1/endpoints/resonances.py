from typing import List, Dict, Any
from fastapi import APIRouter, status

router = APIRouter(prefix="/resonances", tags=["Resonances & Matches"])

INCOMING_LIKES = [
    {
        "id": "like_1",
        "sender_id": "cand_1",
        "full_name": "Devika Roy",
        "age": 25,
        "photo_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80",
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
        "relative_time": "12m ago",
        "shared_interest": "Poetry & Mindfulness",
        "match_score": 91
    },
    {
        "id": "like_2",
        "sender_id": "cand_2",
        "full_name": "Aanya Sen",
        "age": 24,
        "photo_url": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&auto=format&fit=crop&q=80",
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
        "relative_time": "1h ago",
        "shared_interest": "Architecture & Coffee",
        "match_score": 94
    }
]

MUTUAL_CONNECTIONS = [
    {
        "id": "conn_1",
        "match_id": "match_cand_1",
        "partner_id": "cand_1",
        "full_name": "Devika Roy",
        "age": 25,
        "photo_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80",
        "blur_hash": "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
        "matched_time": "Today, 10:15 AM",
        "last_snippet": "I really resonated with your intentional bio...",
        "has_unread": True,
        "bridge_type": "WhatsApp Enclave",
        "bridge_status": "Key 1/3 revealed"
    }
]


@router.get("/incoming", status_code=status.HTTP_200_OK, summary="Get Incoming Likes")
@router.get("/likes", status_code=status.HTTP_200_OK, summary="Get Incoming Likes Alias")
async def get_incoming_likes():
    """Returns incoming admirers who liked the user profile."""
    print(f"[RESONANCES] Serving {len(INCOMING_LIKES)} incoming likes", flush=True)
    return {"likes": INCOMING_LIKES, "data": INCOMING_LIKES}


@router.get("/mutual", status_code=status.HTTP_200_OK, summary="Get Mutual Connections")
async def get_mutual_connections():
    """Returns mutual matches eligible for 1:1 dialogue."""
    print(f"[RESONANCES] Serving {len(MUTUAL_CONNECTIONS)} mutual connections", flush=True)
    return {"connections": MUTUAL_CONNECTIONS, "data": MUTUAL_CONNECTIONS}
