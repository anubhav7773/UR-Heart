import os
import base64
from typing import Optional
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.core.config import settings

def get_encryption_key() -> bytes:
    """
    Retrieves and decodes the AES-256 GCM 32-byte key from environment or settings.
    Falls back to a deterministic 32-byte test key if unset in local/test environments.
    """
    key_b64 = os.getenv("DATA_ENCRYPTION_KEY_BASE64") or settings.DATA_ENCRYPTION_KEY_BASE64
    if not key_b64:
        # 32-byte fallback key for local dev/testing
        return b"01234567890123456789012345678901"
    try:
        key = base64.b64decode(key_b64)
        if len(key) != 32:
            raise ValueError(f"DATA_ENCRYPTION_KEY_BASE64 must decode to exactly 32 bytes (256 bits), got {len(key)} bytes.")
        return key
    except Exception as e:
        if isinstance(e, ValueError):
            raise
        raise ValueError(f"Invalid base64 in DATA_ENCRYPTION_KEY_BASE64: {e}")

def encrypt_data(plaintext: str) -> str:
    """
    Encrypts plaintext using AES-256-GCM.
    Prefixes a 12-byte cryptographically secure random nonce to the ciphertext.
    Returns the standard base64-encoded string: base64(nonce || ciphertext || tag).
    """
    if plaintext is None:
        return ""
    key = get_encryption_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 96-bit nonce standard for GCM
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    return base64.b64encode(nonce + ciphertext).decode("utf-8")

def decrypt_data(ciphertext_b64: str) -> str:
    """
    Decrypts base64-encoded ciphertext using AES-256-GCM.
    Extracts the 12-byte nonce from the prefix and decrypts the remaining payload.
    Returns the original UTF-8 plaintext string.
    """
    if not ciphertext_b64:
        return ""
    key = get_encryption_key()
    aesgcm = AESGCM(key)
    raw = base64.b64decode(ciphertext_b64)
    if len(raw) < 28:  # 12 bytes nonce + 16 bytes auth tag minimum
        raise ValueError("Ciphertext payload too short to contain valid nonce and GCM tag.")
    nonce = raw[:12]
    ciphertext = raw[12:]
    plaintext_bytes = aesgcm.decrypt(nonce, ciphertext, None)
    return plaintext_bytes.decode("utf-8")

# Aliases for field-level usage
encrypt_field = encrypt_data
decrypt_field = decrypt_data
