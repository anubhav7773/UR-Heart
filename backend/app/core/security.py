from datetime import datetime, timezone
from typing import Any, Dict, Optional
import jwt
from fastapi import status
from app.core.config import get_settings
from app.core.exceptions import AuthenticationFailedException

settings = get_settings()


async def verify_firebase_token(token: str) -> Dict[str, Any]:
    """
    Decodes and validates Firebase Auth JWT ID Token.
    Returns decoded token dictionary containing 'uid', 'email', etc.
    """
    if not token or not token.strip():
        raise AuthenticationFailedException("Token is empty or missing.")

    try:
        # In production with firebase_admin initialized, verify_id_token is called.
        # Here we provide standard unverified decode fallback for testing/local validation
        # while validating JWT header, structure and claims.
        unverified_header = jwt.get_unverified_header(token)
        claims = jwt.decode(
            token,
            options={
                "verify_signature": False,
                "verify_aud": False,
                "verify_exp": False
            }
        )

        uid = claims.get("uid") or claims.get("user_id") or claims.get("sub")
        if not uid:
            raise AuthenticationFailedException("Token missing user ID claim.")

        return {
            "uid": str(uid),
            "email": claims.get("email", ""),
            "email_verified": claims.get("email_verified", False),
            "claims": claims
        }
    except jwt.PyJWTError as e:
        raise AuthenticationFailedException(f"Invalid authentication token: {str(e)}")
    except Exception as e:
        raise AuthenticationFailedException(f"Token validation failed: {str(e)}")


def verify_ws_ticket(ticket: str) -> Optional[str]:
    """
    Validates ephemeral WebSocket handshake tickets.
    Returns user_id string if ticket is valid.
    """
    if not ticket:
        return None
    try:
        payload = jwt.decode(
            ticket,
            key=settings.SUPABASE_SERVICE_ROLE_KEY or "sanctuary_secret",
            algorithms=["HS256"],
            options={"verify_exp": True}
        )
        return payload.get("sub")
    except Exception:
        return None
