from typing import List, Dict, Any, Optional
from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter(prefix="/chat", tags=["1:1 Encrypted Dialogues"])

CHAT_THREADS = [
    {
        "match_id": "match_cand_1",
        "peer_id": "cand_1",
        "peer_name": "Devika Roy",
        "peer_age": 25,
        "peer_photo": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80",
        "is_online": True,
        "last_message": "Looking forward to our thoughtful conversation ✨",
        "last_timestamp": "10:20 AM",
        "unread_count": 1,
        "delivery_status": "delivered"
    }
]

SAMPLE_MESSAGES = [
    {
        "id": "msg_1",
        "match_id": "match_cand_1",
        "sender_id": "cand_1",
        "content": "Hello! I saw your profile and loved that you appreciate quiet, honest conversations.",
        "timestamp": "10:15 AM",
        "is_me": False,
        "status": "read"
    },
    {
        "id": "msg_2",
        "match_id": "match_cand_1",
        "sender_id": "user_me",
        "content": "Thank you! I really resonated with your poetry quote.",
        "timestamp": "10:18 AM",
        "is_me": True,
        "status": "delivered"
    }
]


@router.get("/threads", status_code=status.HTTP_200_OK, summary="Get Active Dialogue Threads")
async def get_dialogue_threads() -> List[Dict[str, Any]]:
    """Returns active dialogue threads with delivery indicators."""
    print(f"[CHAT THREADS] Serving {len(CHAT_THREADS)} active conversation threads", flush=True)
    return CHAT_THREADS


@router.get("/messages/{match_id}", status_code=status.HTTP_200_OK, summary="Get Messages for Dialogue")
async def get_dialogue_messages(match_id: str) -> List[Dict[str, Any]]:
    """Returns chronologically ordered messages for match dialogue."""
    print(f"[CHAT MESSAGES] Serving messages for match_id={match_id}", flush=True)
    return SAMPLE_MESSAGES
