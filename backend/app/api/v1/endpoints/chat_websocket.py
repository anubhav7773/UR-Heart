import json
import logging
from uuid import UUID, uuid4
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from app.api.v1.endpoints.ws_ticket import validate_and_consume_ticket
from app.services.chat_manager import manager

logger = logging.getLogger("urheart.chat.ws")
ws_router = APIRouter()


@ws_router.websocket("/ws/chat")
async def secure_chat_websocket_endpoint(websocket: WebSocket):
    """
    Production WSS endpoint authenticated strictly via single-use ephemeral ticket.
    First connection consumes ticket; replay attempt is rejected with WS_1008_POLICY_VIOLATION.
    Real-time routing connects sender directly to recipient with zero lag.
    """
    ticket = websocket.query_params.get("ticket")

    if not ticket:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Cryptographically validate and destroy ticket in RAM
    authenticated_user_id = validate_and_consume_ticket(ticket)
    if not authenticated_user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    await manager.connect(str(authenticated_user_id), websocket)
    logger.info("WebSocket connected: user=%s", authenticated_user_id)

    try:
        while True:
            raw_text = await websocket.receive_text()
            if not raw_text or not raw_text.strip():
                continue

            try:
                data = json.loads(raw_text)
            except Exception:
                # Discard non-JSON payloads safely
                continue

            event_type = data.get("type")

            # 1. Heartbeat ping-pong
            if event_type == "ping":
                await websocket.send_json({
                    "type": "pong",
                    "timestamp": data.get("timestamp")
                })
                continue

            # 2. Dialogue Message Routing (Real-Time E2EE with DB Persistence & Push)
            if event_type == "dialogue_message":
                match_id = str(data.get("match_id", "")).strip()
                raw_recipient = str(data.get("recipient_id") or "").strip()

                # Strictly set true authenticated user as sender_id (eliminates 'user-me' echo drop bug)
                data["sender_id"] = str(authenticated_user_id)

                recipient_uuid = None
                if raw_recipient and raw_recipient not in ("peer", "user-me", "undefined", "null", "None"):
                    try:
                        recipient_uuid = UUID(raw_recipient)
                    except Exception:
                        recipient_uuid = None

                clean_mid = None
                if match_id:
                    for prefix in ("conn_", "conn-", "match-", "match_", "spark_", "spark-"):
                        if match_id.startswith(prefix):
                            match_id = match_id[len(prefix):]
                            break
                    try:
                        clean_mid = UUID(match_id)
                    except Exception:
                        clean_mid = None

                # Look up partner and match dialogue if clean_mid is available
                if clean_mid:
                    try:
                        from app.core.database import async_session_factory
                        from app.models.domain.match import Match
                        from app.models.domain.chat import Message
                        from app.api.v1.endpoints.chat_api import encrypt_message_storage
                        from sqlalchemy import select

                        async with async_session_factory() as session:
                            res = await session.execute(
                                select(Match).where(Match.id == clean_mid)
                            )
                            m = res.scalar_one_or_none()
                            if m:
                                partner_uuid = m.user2_id if str(m.user1_id) == str(authenticated_user_id) else m.user1_id
                                recipient_uuid = partner_uuid

                            # Persist message to PostgreSQL database if not already stored
                            msg_id_raw = data.get("id") or data.get("client_id")
                            target_msg_uuid = None
                            if msg_id_raw:
                                try:
                                    target_msg_uuid = UUID(str(msg_id_raw).strip())
                                except Exception:
                                    target_msg_uuid = None

                            already_saved = False
                            if target_msg_uuid:
                                existing_res = await session.execute(select(Message.id).where(Message.id == target_msg_uuid))
                                if existing_res.scalar_one_or_none():
                                    already_saved = True

                            text_body = data.get("text") or data.get("content") or data.get("ciphertext") or ""
                            if not already_saved and text_body and clean_mid:
                                storage_encrypted = encrypt_message_storage(str(text_body).strip(), str(clean_mid))
                                msg_entry = Message(
                                    id=target_msg_uuid or uuid4(),
                                    match_id=clean_mid,
                                    sender_id=authenticated_user_id,
                                    encrypted_text=storage_encrypted,
                                    status="delivered",
                                )
                                session.add(msg_entry)
                                await session.commit()
                    except Exception as err:
                        logger.warning("WebSocket match/message resolution error: %s", err)

                if recipient_uuid:
                    recipient_str = str(recipient_uuid)
                    data["recipient_id"] = recipient_str
                    # Direct delivery to recipient's live socket
                    await manager.send_direct_message(recipient_str, data)

                    # Trigger outside-the-app notification if recipient is backgrounded
                    try:
                        from app.api.v1.endpoints.notifications import push_notification
                        push_notification(
                            user_id=recipient_str,
                            notif_type="message",
                            title="New Mindful Dialogue 💬",
                            body=str(data.get("text") or "New encrypted dialogue message")[:80],
                            data={
                                "match_id": str(clean_mid) if clean_mid else match_id,
                                "sender_id": str(authenticated_user_id),
                                "target_route": "/chat-dialogue",
                            }
                        )
                    except Exception as notif_err:
                        logger.warning("WS push notification dispatch notice: %s", notif_err)

                # Send transmission ack to sender
                await websocket.send_json({
                    "type": "delivery_ack",
                    "match_id": match_id,
                    "id": data.get("id"),
                    "status": "delivered_to_relay" if recipient_uuid else "queued"
                })

            # 3. Stage advance & Bridge events
            elif event_type in ("STAGE_ADVANCE_REQUEST", "stage_advanced", "bridge_reveal_request", "bridge_consent"):
                match_id = data.get("match_id", "")
                recipient_id = data.get("recipient_id")
                if not recipient_id and match_id:
                    clean_mid = (
                        match_id.replace("conn_", "")
                        .replace("match-", "")
                        .replace("match_", "")
                        .replace("spark_", "")
                    )
                    try:
                        from app.core.database import async_session_factory
                        from app.models.domain.match import Match
                        from sqlalchemy import select
                        async with async_session_factory() as session:
                            res = await session.execute(
                                select(Match).where(Match.id == UUID(clean_mid))
                            )
                            m = res.scalar_one_or_none()
                            if m:
                                partner = m.user2_id if str(m.user1_id) == str(authenticated_user_id) else m.user1_id
                                recipient_id = str(partner)
                    except Exception:
                        pass
                if recipient_id:
                    await manager.send_direct_message(str(recipient_id), data)

    except WebSocketDisconnect:
        manager.disconnect(str(authenticated_user_id), websocket)
        logger.info("WebSocket disconnected: user=%s", authenticated_user_id)
    except Exception as e:
        manager.disconnect(str(authenticated_user_id), websocket)
        logger.warning("WebSocket exception for user=%s: %s", authenticated_user_id, e)
