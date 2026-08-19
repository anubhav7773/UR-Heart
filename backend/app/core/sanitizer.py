import html
import re

def sanitize_user_input(text: str, max_length: int = 1000) -> str:
    """
    Escapes HTML/scripts and trims excessive whitespaces to defend against XSS and injection.
    """
    if not text:
        return ""

    # 1. Escape HTML special chars (<, >, &, ", ')
    clean_text = html.escape(text.strip())

    # 2. Prevent control characters & null byte injection
    clean_text = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', clean_text)

    # 3. Limit length
    return clean_text[:max_length]
