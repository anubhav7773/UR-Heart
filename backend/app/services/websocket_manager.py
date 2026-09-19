import json
from uuid import UUID
from typing import Dict, Union, Any
from fastapi import WebSocket

class ChatConnectionManager:
    def __init__(self):
        # Map user_id -> active WebSocket (str keys)
        self.active_connections: Dict[str, WebSocket] = {}

    def __contains__(self, item: Union[str, UUID]) -> bool:
        return str(item) in self.active_connections

    async def connect(self, user_id: Union[str, UUID], websocket: WebSocket):
        await websocket.accept()
        self.active_connections[str(user_id)] = websocket

    def disconnect(self, user_id: Union[str, UUID]):
        self.active_connections.pop(str(user_id), None)

    async def send_personal_message(self, message: dict, user_id: Union[str, UUID]) -> bool:
        """Sends payload if recipient has an active WebSocket. Returns True if delivered."""
        ws = self.active_connections.get(str(user_id))
        if ws:
            try:
                await ws.send_text(json.dumps(message))
                return True
            except Exception:
                self.disconnect(user_id)
        return False

    async def broadcast_to_match(
        self,
        match_id: Union[str, UUID],
        payload: Dict[str, Any],
        user1_id: Union[str, UUID],
        user2_id: Union[str, UUID]
    ):
        await self.send_personal_message(payload, user1_id)
        await self.send_personal_message(payload, user2_id)

chat_manager = ChatConnectionManager()
