import secrets
import time
from typing import Dict, Tuple, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/chat", tags=["Real-Time Secure WebSocket"])

# In-memory ticket storage: {ticket_str: (user_id, expiry_timestamp)}
_active_ws_tickets: Dict[str, Tuple[UUID, float]] = {}


@router.post("/ws-ticket", status_code=status.HTTP_201_CREATED)
async def generate_ephemeral_websocket_ticket(
    current_user: User = Depends(get_current_user)
):
    """
    Issues a cryptographically random, single-use, 60-second ticket for WSS handshake.
    Eliminates passing long-lived JWT tokens inside URL query strings.
    """
    _cleanup_expired_tickets()

    ticket_token = secrets.token_urlsafe(32)
    expiry = time.time() + 60.0  # Strictly valid for 60 seconds

    _active_ws_tickets[ticket_token] = (current_user.id, expiry)

    return {
        "ticket": ticket_token,
        "expires_in_seconds": 60,
        "protocol": "wss"
    }


def validate_and_consume_ticket(ticket_token: str) -> Optional[UUID]:
    """Validates ticket and consumes it immediately to prevent replay attacks."""
    _cleanup_expired_tickets()

    record = _active_ws_tickets.pop(ticket_token, None)
    if not record:
        return None

    user_id, expiry = record
    if time.time() > expiry:
        return None

    return user_id


def _cleanup_expired_tickets() -> None:
    """Removes dangling tickets older than their expiry."""
    now = time.time()
    expired = [t for t, (_, exp) in _active_ws_tickets.items() if now > exp]
    for t in expired:
        _active_ws_tickets.pop(t, None)
