from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class MessageCreate(BaseModel):
    match_id: Optional[str] = None
    conversation_id: Optional[str] = None
    content: Optional[str] = None
    message_type: str = Field(default="text")  # 'text' | 'meetup_spot'
    media_type: str = "text"
    media_url: Optional[str] = None
    client_msg_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
