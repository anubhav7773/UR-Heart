from typing import Any, Dict, List
from uuid import UUID
from fastapi import WebSocket


class ConnectionManager:
    """In-memory active WebSocket connection manager."""

    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, user_id: Any, websocket: WebSocket) -> None:
        user_key = str(user_id)
        if user_key not in self.active_connections:
            self.active_connections[user_key] = []
        if websocket not in self.active_connections[user_key]:
            self.active_connections[user_key].append(websocket)

    def disconnect(self, user_id: Any, websocket: WebSocket) -> None:
        user_key = str(user_id)
        if user_key in self.active_connections:
            if websocket in self.active_connections[user_key]:
                self.active_connections[user_key].remove(websocket)
            if not self.active_connections[user_key]:
                del self.active_connections[user_key]

    def is_user_online(self, user_id: Any) -> bool:
        user_key = str(user_id)
        return user_key in self.active_connections and len(self.active_connections[user_key]) > 0

    async def send_direct_message(self, user_id: Any, payload: Dict[str, Any]) -> None:
        user_key = str(user_id)
        if user_key in self.active_connections:
            dead_connections = []
            for connection in self.active_connections[user_key]:
                try:
                    await connection.send_json(payload)
                except Exception:
                    dead_connections.append(connection)
            for dead in dead_connections:
                self.disconnect(user_key, dead)


manager = ConnectionManager()
