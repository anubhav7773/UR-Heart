import os
import sys
from unittest.mock import AsyncMock, MagicMock
import pytest

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

# Ensure test session has isolated test secrets for SSV, billing webhooks, and voice STT
if "AD_SSV_SERVER_SECRET" not in os.environ:
    os.environ["AD_SSV_SERVER_SECRET"] = "ad_ssv_test_secret_sanctuary_2026"
if "REVENUECAT_WEBHOOK_SECRET" not in os.environ:
    os.environ["REVENUECAT_WEBHOOK_SECRET"] = "rc_webhook_test_secret_sanctuary_2026"
if not os.environ.get("GROQ_VOICE_API_KEY") or os.environ.get("GROQ_VOICE_API_KEY", "").startswith("placeholder_"):
    os.environ["GROQ_VOICE_API_KEY"] = "gsk_voice_synth_isolated_mock_key"

try:
    from app.core.config import get_settings
    _s = get_settings()
    if not _s.GROQ_VOICE_API_KEY or _s.GROQ_VOICE_API_KEY.startswith("placeholder_"):
        _s.GROQ_VOICE_API_KEY = "gsk_voice_synth_isolated_mock_key"
except Exception:
    pass


async def _default_mock_get_db():
    session = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = []
    mock_res.scalar_one_or_none.return_value = None
    mock_res.scalars.return_value.first.return_value = None
    mock_res.fetchone.return_value = None
    mock_res.fetchall.return_value = []
    mock_res.all.return_value = []
    mock_res.mappings.return_value.one_or_none.return_value = None
    session.execute = AsyncMock(return_value=mock_res)
    session.commit = AsyncMock()
    session.rollback = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    session.add = MagicMock()
    yield session


@pytest.fixture(autouse=True)
def fallback_db_for_sanitized_environment():
    """Provides fallback mock database session when production credentials are sanitized."""
    from app.main import app
    from app.core.database import get_db
    from app.core.config import get_settings

    settings = get_settings()
    is_sanitized = "[SUPABASE_DB_PASSWORD]" in settings.SUPABASE_PGBOUNCER_URL or "placeholder" in settings.SUPABASE_PGBOUNCER_URL

    was_set_by_us = False
    if is_sanitized and get_db not in app.dependency_overrides:
        app.dependency_overrides[get_db] = _default_mock_get_db
        was_set_by_us = True

    yield

    if was_set_by_us and app.dependency_overrides.get(get_db) is _default_mock_get_db:
        app.dependency_overrides.pop(get_db, None)
