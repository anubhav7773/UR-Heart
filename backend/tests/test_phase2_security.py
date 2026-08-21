import pytest
from starlette.testclient import TestClient
from app.main import app
from app.core.rate_limiter import limiter

try:
    from tests.test_security_audit import create_test_user_session, setup_match_between_users
except ImportError:
    try:
        from backend.tests.test_security_audit import create_test_user_session, setup_match_between_users
    except ImportError:
        def create_test_user_session(identifier: str):
            res = client.post("/api/v1/auth/social-login", json={
                "provider": "google",
                "id_token": f"mock_token_{identifier}",
                "device_id": f"device_{identifier}",
                "fcm_token": f"fcm_{identifier}"
            })
            data = res.json()["data"]
            return data["access_token"], data["user_id"]

        def setup_match_between_users(sender_token: str, recipient_user_id: str) -> str:
            import hmac
            import hashlib
            from app.core.config import settings
            headers = {"Authorization": f"Bearer {sender_token}"}
            pay_id = f"pay_test_{recipient_user_id[:8]}"
            order_id = f"order_test_{recipient_user_id[:8]}"
            secret = settings.RAZORPAY_KEY_SECRET or "sample_secret"
            sig = hmac.new(secret.encode("utf-8"), f"{order_id}|{pay_id}".encode("utf-8"), hashlib.sha256).hexdigest()
            verify_payload = {
                "razorpay_payment_id": pay_id,
                "razorpay_order_id": order_id,
                "razorpay_signature": sig,
                "plan_type": "PLAN_DIRECT_DM_49"
            }
            client.post("/api/v1/payments/verify", json=verify_payload, headers=headers)
            dm_payload = {
                "target_user_id": recipient_user_id,
                "message": "Private direct conversation message"
            }
            dm_res = client.post("/api/v1/feed/direct-dm", json=dm_payload, headers=headers)
            return dm_res.json()["data"]["match_id"]

client = TestClient(app)


def test_websocket_rejects_unauthenticated_connection():
    """Verify WebSocket refuses connection when token is invalid or missing."""
    with pytest.raises(Exception):
        with client.websocket_connect("/api/v1/chat/ws/00000000-0000-0000-0000-000000000001?token=bad_invalid_token") as ws:
            pass


def test_websocket_rejects_eavesdropper():
    """Verify User A (Attacker) cannot connect to conversation between User B and C."""
    token_a, user_a_id = create_test_user_session("attacker_alpha_ws")
    token_b, user_b_id = create_test_user_session("victim_beta_ws")
    token_c, user_c_id = create_test_user_session("victim_gamma_ws")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    with pytest.raises(Exception):
        with client.websocket_connect(
            f"/api/v1/chat/ws/{match_bc_id}?token={token_a}"
        ) as ws:
            pass


def test_websocket_accepts_valid_participant():
    """Verify authorized participant connects successfully."""
    token_b, user_b_id = create_test_user_session("victim_beta_ws2")
    token_c, user_c_id = create_test_user_session("victim_gamma_ws2")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    with client.websocket_connect(f"/api/v1/chat/ws/{match_bc_id}?token={token_b}") as ws:
        ws.send_json({"type": "typing", "is_typing": True})


@pytest.mark.asyncio
async def test_rate_limiting_chat_flood():
    """Verify sending >5 rapid messages triggers 429 Too Many Requests."""
    from httpx import AsyncClient, ASGITransport
    limiter.reset()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res_b = await ac.post("/api/v1/auth/social-login", json={
            "provider": "google",
            "id_token": "mock_token_rate_limit_user_b",
            "device_id": "device_rate_limit_user_b",
            "fcm_token": "fcm_rate_limit_user_b"
        })
        token_b = res_b.json()["data"]["access_token"]

        res_c = await ac.post("/api/v1/auth/social-login", json={
            "provider": "google",
            "id_token": "mock_token_rate_limit_user_c",
            "device_id": "device_rate_limit_user_c",
            "fcm_token": "fcm_rate_limit_user_c"
        })
        user_c_id = res_c.json()["data"]["user_id"]

        headers = {"Authorization": f"Bearer {token_b}"}
        import hmac
        import hashlib
        from app.core.config import settings
        pay_id = f"pay_test_{user_c_id[:8]}"
        order_id = f"order_test_{user_c_id[:8]}"
        secret = settings.RAZORPAY_KEY_SECRET or "sample_secret"
        sig = hmac.new(secret.encode("utf-8"), f"{order_id}|{pay_id}".encode("utf-8"), hashlib.sha256).hexdigest()
        verify_payload = {
            "razorpay_payment_id": pay_id,
            "razorpay_order_id": order_id,
            "razorpay_signature": sig,
            "plan_type": "PLAN_DIRECT_DM_49"
        }
        await ac.post("/api/v1/payments/verify", json=verify_payload, headers=headers)
        dm_payload = {
            "target_user_id": user_c_id,
            "message": "Private direct conversation message"
        }
        dm_res = await ac.post("/api/v1/feed/direct-dm", json=dm_payload, headers=headers)
        match_bc_id = dm_res.json()["data"]["match_id"]

        payload = {
            "match_id": match_bc_id,
            "content": "Rapid chat message",
        }

        status_codes = []
        for _ in range(8):
            res = await ac.post("/api/v1/chat/send", json=payload, headers=headers)
            status_codes.append(res.status_code)

        assert 429 in status_codes, f"Security Alert: Rate limiter failed to block rapid chat spam! Got codes: {status_codes}"

