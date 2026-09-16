import json
from uuid import UUID
from typing import Dict, Any, Optional
from fastapi import WebSocket

class ConnectionManager:
    """
    In-memory connection manager for WebSocket clients.
    Optimized for Render's 512MB RAM ceiling by holding light references
    and handling disconnected sockets proactively.
    """
    def __init__(self):
        self.active_connections: Dict[UUID, WebSocket] = {}

    async def connect(self, user_id: UUID, websocket: WebSocket):
        """Registers an active WebSocket connection for a user."""
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: UUID):
        """Removes a user's active WebSocket connection."""
        self.active_connections.pop(user_id, None)

    async def send_personal_message(self, message: Dict[str, Any], recipient_id: UUID) -> bool:
        """
        Sends a JSON message to recipient if connected.
        Returns True if sent, False if recipient is offline.
        """
        websocket = self.active_connections.get(recipient_id)
        if websocket:
            try:
                await websocket.send_text(json.dumps(message))
                return True
            except Exception:
                self.disconnect(recipient_id)
                return False
        return False

    async def broadcast_to_match(
        self,
        match_id: UUID,
        payload: Dict[str, Any],
        user1_id: UUID,
        user2_id: UUID
    ):
        """Broadcasts match-level notifications to both match participants."""
        await self.send_personal_message(payload, user1_id)
        await self.send_personal_message(payload, user2_id)

manager = ConnectionManager()
