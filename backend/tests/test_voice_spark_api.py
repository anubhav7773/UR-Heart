import io
import uuid
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.api.v1.endpoints.profile import ProfileUpdateRequest


client = TestClient(app)


def test_user_domain_model_has_voice_spark_fields():
    user_id = uuid.uuid4()
    user = User(
        id=user_id,
        email="voice@urheart.app",
        full_name="Aarav Sharma",
        voice_spark_url="https://supabase.co/storage/v1/object/public/ur-heart-media/voices/test.m4a",
        voice_spark_prompt="My sacred sanctuary is...",
        voice_spark_duration=6.8,
        is_voice_verified=True,
    )
    assert user.voice_spark_url == "https://supabase.co/storage/v1/object/public/ur-heart-media/voices/test.m4a"
    assert user.voice_spark_prompt == "My sacred sanctuary is..."
    assert user.voice_spark_duration == 6.8
    assert user.is_voice_verified is True


def test_profile_update_request_accepts_voice_spark():
    req = ProfileUpdateRequest(
        bio="Mindful human",
        voice_spark_url="https://example.com/audio.m4a",
        voice_spark_prompt="What brings you peace?",
        voice_spark_duration=7.0,
        is_voice_verified=True,
    )
    assert req.voice_spark_url == "https://example.com/audio.m4a"
    assert req.voice_spark_prompt == "What brings you peace?"
    assert req.voice_spark_duration == 7.0
    assert req.is_voice_verified is True


def test_voice_spark_upload_invalid_mime():
    mock_user = User(
        id=uuid.uuid4(),
        email="seeker@urheart.app",
        full_name="Tester",
    )
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        files = {"file": ("test.txt", io.BytesIO(b"not audio"), "text/plain")}
        response = client.post(
            "/api/v1/profile/voice-spark",
            files=files,
            data={"prompt": "Hello", "duration": "5.5"},
        )
        assert response.status_code == 400
        assert "audio" in response.json()["detail"].lower()
    finally:
        app.dependency_overrides.clear()


def test_voice_spark_upload_success():
    user_id = uuid.uuid4()
    mock_user = User(
        id=user_id,
        email="seeker@urheart.app",
        full_name="Aarav Sharma",
    )
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        audio_bytes = b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00" + b"A" * 1024
        files = {"file": ("voice_spark.m4a", io.BytesIO(audio_bytes), "audio/m4a")}

        response = client.post(
            "/api/v1/profile/voice-spark",
            files=files,
            data={"prompt": "A song that describes my energy...", "duration": "6.5"},
        )

        assert response.status_code == 200
        data = response.json()
        assert "voice_spark_url" in data
        assert data["voice_spark_duration"] == 6.5
        assert data["voice_spark_prompt"] == "A song that describes my energy..."
        assert data["is_voice_verified"] is True
    finally:
        app.dependency_overrides.clear()


def test_voice_spark_delete_success():
    user_id = uuid.uuid4()
    mock_user = User(
        id=user_id,
        email="seeker@urheart.app",
        full_name="Aarav Sharma",
        voice_spark_url="https://supabase.co/storage/v1/voice.m4a",
        voice_spark_prompt="Prompt",
        voice_spark_duration=5.0,
        is_voice_verified=True,
    )
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        response = client.delete("/api/v1/profile/voice-spark")
        assert response.status_code == 200
        data = response.json()
        assert data["voice_spark_url"] is None
        assert data["is_voice_verified"] is False
    finally:
        app.dependency_overrides.clear()
