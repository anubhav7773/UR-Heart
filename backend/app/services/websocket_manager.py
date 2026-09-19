import json
from uuid import UUID
from typing import Dict, Optional, Union, Any
from fastapi import WebSocket

class ChatConnectionManager:
    def __init__(self):
        # Maps user_id -> active WebSocket
        self.active_connections: Dict[str, WebSocket] = {}
        # Maps user_id -> match_id actively open on their screen
        self.active_rooms: Dict[str, str] = {}

    def __contains__(self, item: Union[str, UUID]) -> bool:
        return str(item) in self.active_connections

    async def connect(self, user_id: Union[str, UUID], websocket: WebSocket):
        await websocket.accept()
        self.active_connections[str(user_id)] = websocket

    def disconnect(self, user_id: Union[str, UUID]):
        self.active_connections.pop(str(user_id), None)
        self.active_rooms.pop(str(user_id), None)

    def focus_room(self, user_id: Union[str, UUID], match_id: Union[str, UUID]):
        """User actively navigated into this chat screen."""
        self.active_rooms[str(user_id)] = str(match_id)

    def blur_room(self, user_id: Union[str, UUID]):
        """User navigated away from the chat screen."""
        self.active_rooms.pop(str(user_id), None)

    def is_user_actively_reading(self, user_id: Union[str, UUID], match_id: Union[str, UUID]) -> bool:
        """Returns True ONLY if user is connected AND on this specific match screen."""
        return self.active_rooms.get(str(user_id)) == str(match_id)

    async def send_personal_message(self, message: dict, user_id: Union[str, UUID]) -> bool:
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
