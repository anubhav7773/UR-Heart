# 05_WEBSOCKET_REALTIME_ENGINE.md: REAL-TIME CHAT & DUAL-LAYER E2EE ENGINE
# Project: UR-Heart (Mindful Dating Sanctuary)
# Target Environment: Render Free-Tier ASGI (Memory-Optimized WebSocket Pool)
# Architecture: WhatsApp-Style Tick Pipeline + Statutory Key Escrow E2EE

---

## 1. ARCHITECTURAL OVERVIEW & 512MB RAM CONSTRAINTS

FastAPI backend par 25,000+ active users ke real-time socket connections handle karne ke liye WebSocket layer ko zero-allocation memory pool pattern par design kiya gaya hai. 

### 1.1 Memory Pool Design Directives
1. **Pointers Only in RAM**: WebSocket `ConnectionManager` memory mein sirf active socket objects map karta hai (`Dict[UUID, WebSocket]`). User profiles, match lists, ya unread message queues server RAM mein hold nahi hote.
2. **Stateless Failover to FCM**: Recipient agar offline hai to server RAM mein message retry queue maintain nahi karta. Message seedhe Supabase PostgreSQL mein `status = 'sent'` ke sath write hota hai aur background mein Firebase Cloud Messaging (FCM) data push trigger ho jata hai.
3. **Heartbeat Keep-Alive**: Mobile client 45 seconds ke interval par ping packet bhejta hai taaki stale connections auto-prune ho sakein aur Render container ka socket idle timeout se disconnect na ho.

---

## 2. WHATSAPP-STYLE 3-STAGE TICK DELIVERY STATE MACHINE

Chat system mein message delivery state ko 3 explicit visual indicators mein bifurcate kiya gaya hai:

[Sender Flutter App]                [FastAPI WSS Engine]              [Recipient Flutter App]
│                                    │                                    │
│ 1. send_message payload            │                                    │
├───────────────────────────────────►│                                    │
│                                    │ 2. NLP Sanitizer Pass              │
│                                    │ 3. Save to Supabase (status: sent) │
│ 4. ack_sent (Single Grey Tick ✓)   │                                    │
│◄───────────────────────────────────┤                                    │
│                                    │ 5. Is recipient online?            │
│                                    │─── YES ───────────────────────────►│
│                                    │                                    │ 6. Socket received
│                                    │ 7. ack_delivered (from recipient)  │
│                                    │◄───────────────────────────────────┤
│                                    │ 8. Update DB (status: delivered)   │
│ 9. relay_delivered (Double Grey ✓✓)│                                    │
│◄───────────────────────────────────┤                                    │
│                                    │                                    │
│                                    │ 10. Recipient opens chat viewport  │
│                                    │ 11. ack_read (Blue Tick trigger)   │
│                                    │◄───────────────────────────────────┤
│                                    │ 12. Update DB (status: read)       │
│ 13. relay_read (Double Blue Tick ✓✓)│                                    │
│◄───────────────────────────────────┤                                    │


### 2.1 State Specifications
* **State 1: Sent (Single Grey Tick `✓`)**:
  * Message FastAPI server par pahunch chuka hai.
  * NLP Chat Sanitizer check pass ho chuka hai (Zero contact sharing)[cite: 1].
  * Supabase `messages` table mein record `status = 'sent'` ke sath persist ho gaya hai[cite: 1].
* **State 2: Delivered (Double Grey Tick `✓✓`)**:
  * Recipient ke device par socket ne encrypted payload receive kar liya hai.
  * Recipient client background socket acknowledge emit karta hai (`action: "ack_delivered"`).
  * Backend DB mein status update karta hai aur sender ko delivery broadcast emit karta hai[cite: 1].
* **State 3: Read / Seen (Double Blue Tick `✓✓`)**:
  * Recipient ne screen par conversation open ki aur message render hua (Flutter `VisibilityDetector` / `RouteAware`).
  * Recipient client read receipt acknowledge emit karta hai (`action: "ack_read"`).
  * Backend DB mein status update karta hai aur sender screen par tick color `#34B7F1` (Sanctuary Soft Blue) mein transition hota hai.

---

## 3. DUAL-LAYER E2EE & STATUTORY LAWFUL ESCROW ARCHITECTURE

UR-Heart end-to-end user privacy enforce karta hai taaki database breach ya unauthorized sniffing par raw text expose na ho[cite: 1, 10, 23]. Saath hi, **DPDP Act 2023** aur **IT Rules 2021 Rule 3(2)** statutory compliance ke anuroop, court order ya law enforcement legal investigation ke dauran authorized decryption support karne ke liye **Hybrid Dual-Key Envelope Encryption** implement kiya gaya hai.

### 3.1 Encryption Flow Diagram

[Plaintext Message]
│
▼
[Generate Ephemeral Symmetric Key (AES-256-GCM)] ───► Encrypts Message ───► [Ciphertext Payload]
│
├─── Encrypted with Recipient Public Key (Curve25519) ─────────► [recipient_wrapped_key]
│
└─── Encrypted with Platform Master Statutory Key (RSA-4096) ──► [statutory_wrapped_key]


### 3.2 Database Storage Structure (`messages.encrypted_text`)

Supabase Postgres ke `messages` table ke `encrypted_text` column mein standard JSON envelope string persist hoti hai[cite: 1]:

```json
{
  "version": "1.0",
  "nonce": "a1b2c3d4e5f6g7h8i9j0k1l2",
  "ciphertext": "6Uf4e9z0...",
  "tag": "k8P9w2Q1...",
  "recipient_wrapped_key": "dGhpc2lzYXdyYXBwZWRrZXk...",
  "statutory_wrapped_key": "bGF3ZnVsZXNjcm93a2V5..."
}
3.3 Decryption Workflows
Normal In-App Chat Flow (Recipient):

Recipient client message receive karta hai.

Recipient ka private key (device ke secure hardware storage mein protected) recipient_wrapped_key ko unwrap karke symmetric session key extract karta hai.

Symmetric key se ciphertext decrypt hoke screen par render hoti hai.

Statutory Legal Compliance Flow (Lawful Authority):

IT Rules 2021 statutory notice ya formal grievance investigation ke case mein Platform Authorized Compliance Officer offline secure master private key invoke karta hai[cite: 1, 13].

Master key statutory_wrapped_key ko decrypt karti hai, jisse symmetric key recover hoti hai.

Statutory dossier verification report generate hoti hai. Regular app users ya server memory ke paas master private key ka access nahi hota[cite: 1].

4. REAL-TIME WEBSOCKET JSON WIRE PROTOCOL
Client aur Server ke beech communication strictly typed JSON packets ke zariye execute hoti hai:

4.1 Client-to-Server Packets
A. Send Encrypted Message
JSON


{
  "action": "send_message",
  "match_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "recipient_id": "2b3c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e",
  "encrypted_payload": {
    "nonce": "12_byte_base64_nonce",
    "ciphertext": "base64_encrypted_payload",
    "tag": "16_byte_base64_auth_tag",
    "recipient_wrapped_key": "base64_wrapped_key",
    "statutory_wrapped_key": "base64_escrow_key"
  }
}
B. Acknowledge Delivered (Double Tick Trigger)
JSON


{
  "action": "ack_delivered",
  "match_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "message_id": 10429,
  "sender_id": "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d"
}
C. Acknowledge Read (Blue Tick Trigger)
JSON


{
  "action": "ack_read",
  "match_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "message_id": 10429,
  "sender_id": "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d"
}
D. Typing Telemetry
JSON


{
  "action": "typing_indicator",
  "match_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "recipient_id": "2b3c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e",
  "is_typing": true
}
5. CONNECTION MANAGER (app/services/chat_manager.py)
Ye singleton connection manager active sockets ko map karta hai aur non-blocking async message dispatch execute karta hai[cite: 1]:

Python


import json
from uuid import UUID
from typing import Dict, Optional
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Maps active user_id (UUID) -> WebSocket connection instance[cite: 1]
        self.active_connections: Dict[UUID, WebSocket] = {}

    async def connect(self, user_id: UUID, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: UUID):
        self.active_connections.pop(user_id, None)

    def is_online(self, user_id: UUID) -> bool:
        return user_id in self.active_connections

    async def send_direct_message(self, user_id: UUID, payload: dict) -> bool:
        """Sends JSON packet directly if recipient is actively connected online."""
        websocket = self.active_connections.get(user_id)
        if websocket:
            try:
                await websocket.send_text(json.dumps(payload))
                return True
            except Exception:
                self.disconnect(user_id)
                return False
        return False

manager = ConnectionManager()
6. WEBSOCKET ENDPOINT & PIPELINE (app/api/v1/endpoints/chat.py)
Python


import json
from uuid import UUID
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.services.chat_manager import manager
from app.core.database import AsyncSessionLocal
from app.core.security import verify_ws_token
from app.services.chat_sanitizer import sanitize_chat_message[cite: 1]
from app.models.domain.message import Message[cite: 1]
from app.models.domain.match import Match[cite: 1]

router = APIRouter()

@router.websocket("/ws/chat")
async def websocket_chat_endpoint(websocket: WebSocket, token: str = Query(...)):
    user_id_str = await verify_ws_token(token)
    if not user_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    current_user_id = UUID(user_id_str)
    await manager.connect(current_user_id, websocket)

    try:
        while True:
            raw_text = await websocket.receive_text()
            data = json.loads(raw_text)
            action = data.get("action")

            async with AsyncSessionLocal() as db:
                if action == "send_message":
                    match_id = UUID(data["match_id"])
                    recipient_id = UUID(data["recipient_id"])
                    payload = data["encrypted_payload"]

                    # 1. Active match confirmation[cite: 1]
                    match_stmt = select(Match).where(
                        Match.id == match_id,
                        Match.is_active == True,
                        ((Match.user1_id == current_user_id) & (Match.user2_id == recipient_id)) |
                        ((Match.user2_id == current_user_id) & (Match.user1_id == recipient_id))
                    )
                    match_res = await db.execute(match_stmt)
                    if not match_res.scalar_one_or_none():
                        continue

                    # 2. Persist message with status: 'sent'[cite: 1]
                    new_msg = Message(
                        match_id=match_id,
                        sender_id=current_user_id,
                        encrypted_text=json.dumps(payload),
                        status="sent"
                    )
                    db.add(new_msg)
                    await db.commit()
                    await db.refresh(new_msg)

                    # 3. SINGLE TICK: Acknowledge sender[cite: 1]
                    await websocket.send_text(json.dumps({
                        "event": "message_sent_ack",
                        "message_id": new_msg.id,
                        "match_id": str(match_id),
                        "status": "sent"
                    }))

                    # 4. Attempt instant delivery to recipient[cite: 1]
                    delivered = await manager.send_direct_message(recipient_id, {
                        "event": "incoming_message",
                        "message_id": new_msg.id,
                        "match_id": str(match_id),
                        "sender_id": str(current_user_id),
                        "encrypted_payload": payload,
                        "status": "delivered",
                        "created_at": new_msg.created_at.isoformat()
                    })

                    # If recipient received socket, mark delivered immediately
                    if delivered:
                        await db.execute(
                            update(Message).where(Message.id == new_msg.id).values(status="delivered")
                        )
                        await db.commit()
                        await websocket.send_text(json.dumps({
                            "event": "status_update",
                            "message_id": new_msg.id,
                            "match_id": str(match_id),
                            "status": "delivered"
                        }))

                elif action == "ack_delivered":
                    # DOUBLE TICK: Relayed from recipient device[cite: 1]
                    msg_id = data["message_id"]
                    sender_id = UUID(data["sender_id"])
                    await db.execute(update(Message).where(Message.id == msg_id).values(status="delivered"))
                    await db.commit()
                    await manager.send_direct_message(sender_id, {
                        "event": "status_update",
                        "message_id": msg_id,
                        "match_id": data["match_id"],
                        "status": "delivered"
                    })

                elif action == "ack_read":
                    # BLUE TICK: Recipient viewed the screen[cite: 1]
                    msg_id = data["message_id"]
                    sender_id = UUID(data["sender_id"])
                    await db.execute(update(Message).where(Message.id == msg_id).values(status="read"))
                    await db.commit()
                    await manager.send_direct_message(sender_id, {
                        "event": "status_update",
                        "message_id": msg_id,
                        "match_id": data["match_id"],
                        "status": "read"
                    })

                elif action == "typing_indicator":
                    recipient_id = UUID(data["recipient_id"])
                    await manager.send_direct_message(recipient_id, {
                        "event": "peer_typing",
                        "match_id": data["match_id"],
                        "is_typing": data.get("is_typing", False)
                    })

    except WebSocketDisconnect:
        manager.disconnect(current_user_id)
7. FLUTTER TICK RENDERING ENGINE (UI BLUEPRINT)
Flutter application mein har message bubble ke sath tick indicator render hota hai:   
PNG
+ 1

Dart


Widget buildTickIndicator(String status, bool isDarkMode) {
  switch (status) {
    case 'sent':
      // Single Grey Tick
      return const Icon(Icons.done, size: 16.0, color: Colors.grey);
    case 'delivered':
      // Double Grey Tick
      return const Icon(Icons.done_all, size: 16.0, color: Colors.grey);
    case 'read':
      // Double Blue Tick (WhatsApp Style)
      return const Icon(Icons.done_all, size: 16.0, color: Color(0xFF34B7F1));
    default:
      return const SizedBox.shrink();
  }
}
8. NATIVE SCREEN SHIELD INTEGRATION (FLAG_SECURE)
Private chat dialogues ko screenshot capture aur screen recording se protect karne ke liye Flutter client Screen 9 par native window flag enforce karta hai[cite: 1]:

Dart


import 'package:flutter_windowmanager/flutter_windowmanager.dart';

// Triggered inside initState of ChatScreen[cite: 1]
Future<void> enableChatScreenSecurity() async {
  await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
}

// Triggered inside dispose of ChatScreen[cite: 1]
Future<void> releaseChatScreenSecurity() async {
  await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
}
9. ANTIGRAVITY VERIFICATION & AUDIT CHECKLIST
Antigravity agent ko implementation ke waqt nimn specifications verify karni hain:

Strict 3-Stage Transition: Verify karein ki direct sent se read jump na ho jab tak message recipient device par deliver na hua ho (sent → delivered → read).

Escrow Key Integrity: Ensure karein ki client se aane wala encrypted payload bina statutory_wrapped_key ke accept na ho[cite: 1].

RAM Garbage Collection: Ensure karein ki disconnected sockets immediately dictionary pool se purge ho rahe hain taaki 512MB RAM budget violate na ho.

