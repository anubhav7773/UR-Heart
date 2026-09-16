import html
from typing import Optional

def sanitize_user_html(text: Optional[str]) -> Optional[str]:
    """
    Escapes HTML special characters (<, >, &, ", ') using html.escape(quote=True)
    to neutralize Cross-Site Scripting (XSS) payloads before storage or output.
    """
    if text is None:
        return None
    return html.escape(text.strip(), quote=True)

def strip_null_bytes(text: Optional[str]) -> Optional[str]:
    """
    Strips or rejects null bytes (\0) to prevent null-byte poisoning attacks.
    """
    if text is None:
        return None
    if "\0" in text or "\x00" in text:
        raise ValueError("Null-byte injection detected.")
    return text

escape_xss = sanitize_user_html
