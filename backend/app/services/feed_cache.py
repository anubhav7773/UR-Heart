import time
from typing import Dict, Any, Optional

class DiscoveryFeedCache:
    """
    In-memory TTL cache designed for high-concurrency feed reads.
    Caches candidate arrays per locality/cluster for 45 seconds to shield the database.
    """
    def __init__(self, ttl_seconds: int = 45):
        self.ttl = ttl_seconds
        self._cache: Dict[str, Dict[str, Any]] = {}

    def _get_key(self, city: str, limit: int, offset: int) -> str:
        clean_city = (city or "global").strip().lower()
        return f"feed:{clean_city}:{limit}:{offset}"

    def get(self, city: str, limit: int, offset: int) -> Optional[list]:
        key = self._get_key(city, limit, offset)
        entry = self._cache.get(key)
        if entry:
            if time.time() - entry["timestamp"] < self.ttl:
                return entry["data"]
            else:
                self._cache.pop(key, None)
        return None

    def set(self, city: str, limit: int, offset: int, data: list):
        # Prevent cache ballooning on 512 MB RAM
        if len(self._cache) > 100:
            self._evict_expired()

        key = self._get_key(city, limit, offset)
        self._cache[key] = {
            "data": data,
            "timestamp": time.time()
        }

    def _evict_expired(self):
        now = time.time()
        keys_to_delete = [k for k, v in self._cache.items() if now - v["timestamp"] >= self.ttl]
        for k in keys_to_delete:
            self._cache.pop(k, None)

feed_cache = DiscoveryFeedCache(ttl_seconds=45)
