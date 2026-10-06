import os
import base64
import hashlib
from typing import Optional
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.core.config import get_settings

settings = get_settings()

def _get_encryption_key() -> str:
    """Returns validated server encryption key."""
    key = getattr(settings, "JWT_SECRET_KEY", None) or os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")
    if not key or len(key.strip()) < 32:
        # Fallback to config default if present
        key = getattr(settings, "JWT_SECRET_KEY", "")
    if not key or len(key.strip()) < 16:
        raise RuntimeError("FATAL: Encryption key is missing or insecure. Refusing encryption operation.")
    return key.strip()


def encrypt_contact_bridge(plain_handle: str, user_id: str) -> str:
    """
    Encrypts sensitive contact handles (WhatsApp, phone) using AES-256-GCM authenticated cipher.
    Bound cryptographically to the specific user_id.
    Returns format: 'enc_bridge_v1:<base64(nonce + ciphertext)>'
    """
    if not plain_handle or not plain_handle.strip():
        return ""
    
    clean_text = plain_handle.strip()
    if clean_text.startswith("enc_bridge_v1:"):
        return clean_text  # Already encrypted

    secret = _get_encryption_key()
    key_material = hashlib.sha256(f"{secret}:{user_id}:sanctuary_bridge".encode("utf-8")).digest()
    aesgcm = AESGCM(key_material)
    nonce = os.urandom(12)
    ct = aesgcm.encrypt(nonce, clean_text.encode("utf-8"), None)
    return "enc_bridge_v1:" + base64.b64encode(nonce + ct).decode("utf-8")


def decrypt_contact_bridge(stored_value: str, user_id: str) -> str:
    """
    Decrypts AES-256-GCM contact bridge ciphertext.
    If the value does not have the 'enc_bridge_v1:' prefix, gracefully returns
    the plaintext (ensuring zero data loss for legacy records).
    """
    if not stored_value or not stored_value.strip():
        return ""
    
    val = stored_value.strip()
    if not val.startswith("enc_bridge_v1:"):
        return val  # Legacy unencrypted record

    try:
        raw = base64.b64decode(val[14:])
        if len(raw) < 13:
            return val
        nonce = raw[:12]
        ct = raw[12:]
        secret = _get_encryption_key()
        key_material = hashlib.sha256(f"{secret}:{user_id}:sanctuary_bridge".encode("utf-8")).digest()
        aesgcm = AESGCM(key_material)
        decrypted = aesgcm.decrypt(nonce, ct, None)
        return decrypted.decode("utf-8")
    except Exception as e:
        print(f"[CRYPTO NOTICE] Contact bridge decrypt notice for user {user_id}: {e}", flush=True)
        return ""
