from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from app.api.v1.endpoints.ws_ticket import validate_and_consume_ticket

ws_router = APIRouter()


@ws_router.websocket("/ws/chat")
async def secure_chat_websocket_endpoint(websocket: WebSocket):
    """
    Production WSS endpoint authenticated strictly via single-use ephemeral ticket.
    First connection consumes ticket; replay attempt is rejected with WS_1008_POLICY_VIOLATION.
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

    try:
        while True:
            # Receive strictly encrypted binary or JSON payloads
            data = await websocket.receive_text()
            # Echo / route real-time message
            await websocket.send_text(data)
    except WebSocketDisconnect:
        pass
