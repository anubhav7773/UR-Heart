import json
import logging
from uuid import UUID
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

            # 2. Dialogue Message Routing (Real-Time E2EE)
            if event_type == "dialogue_message":
                match_id = data.get("match_id", "")
                recipient_id = data.get("recipient_id")

                # Resolve recipient if not directly passed in payload
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
                    except Exception as err:
                        logger.warning("Recipient lookup notice: %s", err)

                if recipient_id:
                    # Instant direct delivery to recipient's live socket
                    await manager.send_direct_message(str(recipient_id), data)

                # Send transmission ack to sender
                await websocket.send_json({
                    "type": "delivery_ack",
                    "match_id": match_id,
                    "status": "delivered_to_relay" if recipient_id else "queued"
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
