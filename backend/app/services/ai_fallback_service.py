import json
import logging
from typing import Any, Dict, List, Optional
import httpx
from app.core.config import get_settings

logger = logging.getLogger("ai_fallback")
settings = get_settings()

OPENROUTER_TEXT_MODEL = "meta-llama/llama-3.3-70b-instruct:free"
OPENROUTER_VISION_MODEL = "meta-llama/llama-3.2-11b-vision-instruct:free"


class AiFallbackService:
    @classmethod
    def _headers(cls) -> Dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Mindful Sanctuary",
        }
        if settings.OPENROUTER_API_KEY:
            headers["Authorization"] = f"Bearer {settings.OPENROUTER_API_KEY}"
        return headers

    @classmethod
    async def chat_completion(
        cls,
        prompt: str,
        temperature: float = 0.7,
        json_output: bool = True
    ) -> Optional[Dict[str, Any]]:
        """Executes fallback chat completion via OpenRouter Free Tier."""
        payload = {
            "model": OPENROUTER_TEXT_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": temperature,
        }
        if json_output:
            payload["response_format"] = {"type": "json_object"}

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                res = await client.post(
                    settings.OPENROUTER_API_URL,
                    headers=cls._headers(),
                    json=payload
                )
                if res.status_code == 200:
                    content = res.json()["choices"][0]["message"]["content"]
                    if json_output:
                        return json.loads(content)
                    return {"text": content}
        except Exception as e:
            logger.warning("OpenRouter text fallback note: %s", str(e))
        return None

    @classmethod
    async def vision_liveness_check(
        cls,
        anchor_b64: str,
        frames_b64: List[str]
    ) -> Optional[Dict[str, Any]]:
        """Executes multimodal vision failover using OpenRouter free vision model."""
        prompt = (
            "Analyze portrait vs 3 video frames. Output JSON: "
            '{"is_live_human": true, "face_match_score": 92, "estimated_age_bracket": "22-26", "is_underage": false, "rejection_reason": ""}'
        )
        content_items: List[Dict[str, Any]] = [{"type": "text", "text": prompt}]
        content_items.append({"type": "image_url", "image_url": {"url": f"data:image/webp;base64,{anchor_b64}"}})
        for f in frames_b64[:3]:
            content_items.append({"type": "image_url", "image_url": {"url": f"data:image/webp;base64,{f}"}})

        payload = {
            "model": OPENROUTER_VISION_MODEL,
            "messages": [{"role": "user", "content": content_items}],
            "temperature": 0.2,
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.post(
                    settings.OPENROUTER_API_URL,
                    headers=cls._headers(),
                    json=payload
                )
                if res.status_code == 200:
                    return json.loads(res.json()["choices"][0]["message"]["content"])
        except Exception as e:
            logger.warning("OpenRouter vision fallback note: %s", str(e))
        return None
