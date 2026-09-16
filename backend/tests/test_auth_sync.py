import hashlib
from datetime import date, datetime, timedelta, timezone
from uuid import uuid4, UUID
from unittest.mock import patch, AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.underage_quarantine import UnderageQuarantine
from app.models.domain.legal_audit import LegalAuditLog

client = TestClient(app)

MOCK_FIREBASE_UID = "firebase_test_user_uid_12345"
VALID_AUTH_HEADER = {"Authorization": "Bearer fake_valid_token_xyz"}

# ==============================================================================
# TEST 1: New User Registration (Age >= 18)
# ==============================================================================
def test_new_user_registration():
    """
    Valid Firebase token and user age >= 18 (e.g. 24 years old).
    Asserts HTTP 200 with status 'created', streak_count = 1, reward_balance = 0.
    Asserts user record is added and statutory CERT-In audit log is created.
    """
    install_uuid = str(uuid4())
    headers = {
        "Authorization": "Bearer mock_valid_firebase_token",
        "X-Installation-UUID": install_uuid
    }
    dob_24 = (date.today() - timedelta(days=24 * 365 + 6)).isoformat()
    payload = {
        "phone_number": "+919876543210",
        "whatsapp_number": "+919876543210",
        "full_name": "Aman Verma",
        "dob": dob_24,
        "gender": "male",
        "city": "Lucknow",
        "bio": "Software engineer",
        "android_id": "test_android_id_1"
    }

    # Track objects added to DB
    added_objects = []

    mock_session = AsyncMock()
    mock_session.add = MagicMock(side_effect=lambda x: added_objects.append(x))
    mock_session.commit = AsyncMock(return_value=None)
    mock_session.refresh = AsyncMock(return_value=None)

    # First query is quarantine check (None), second is user lookup (None)
    mock_quarantine_res = AsyncMock()
    mock_quarantine_res.scalar_one_or_none = lambda: None

    mock_user_res = AsyncMock()
    mock_user_res.scalar_one_or_none = lambda: None

    mock_session.execute = AsyncMock(side_effect=[mock_quarantine_res, mock_user_res])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    mock_token_payload = {"uid": MOCK_FIREBASE_UID, "email": "aman@example.com"}

    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        response = client.post("/api/v1/auth/session-sync", json=payload, headers=headers)

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "created"
    assert data["streak_count"] == 1
    assert data["reward_balance"] == 0
    assert data["user"]["full_name"] == "Aman Verma"

    # Assert User model was created and added
    user_records = [obj for obj in added_objects if isinstance(obj, User)]
    assert len(user_records) == 1
    assert user_records[0].firebase_uid == MOCK_FIREBASE_UID
    assert user_records[0].last_installation_uuid == install_uuid

    # Assert CERT-In audit log was created with AUTH_REGISTER action
    audit_records = [obj for obj in added_objects if isinstance(obj, LegalAuditLog)]
    assert len(audit_records) == 1
    assert audit_records[0].action_type == "AUTH_REGISTER"
    assert audit_records[0].installation_uuid == install_uuid

# ==============================================================================
# TEST 2: Underage Hard-Lock & Quarantine (Age < 18)
# ==============================================================================
def test_underage_hardlock_and_quarantine():
    """
    Attempt 1: User with DOB indicating 16 years old.
    Asserts HTTP 403, user is NOT created, device_phone_hash is quarantined for 180 days.
    Attempt 2: Subsequent request with age 20 using same device/phone is immediately rejected with 403.
    """
    install_uuid = str(uuid4())
    headers = {
        "Authorization": "Bearer mock_valid_firebase_token",
        "X-Installation-UUID": install_uuid
    }
    dob_16 = (date.today() - timedelta(days=16 * 365 + 4)).isoformat()
    payload_underage = {
        "phone_number": "+919988776655",
        "whatsapp_number": "+919988776655",
        "full_name": "Minor User",
        "dob": dob_16,
        "gender": "female",
        "city": "Kanpur",
        "bio": "High school student",
        "android_id": "device_minor_xyz"
    }

    added_objects = []
    mock_session = AsyncMock()
    mock_session.add = MagicMock(side_effect=lambda x: added_objects.append(x))
    mock_session.commit = AsyncMock(return_value=None)

    # 1. First attempt: No quarantine in DB initially
    mock_quarantine_res = AsyncMock()
    mock_quarantine_res.scalar_one_or_none = lambda: None
    mock_session.execute = AsyncMock(return_value=mock_quarantine_res)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    mock_token_payload = {"uid": "minor_firebase_uid_999", "email": "minor@example.com"}

    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        resp1 = client.post("/api/v1/auth/session-sync", json=payload_underage, headers=headers)

    assert resp1.status_code == 403, resp1.text
    assert "strictly for adults aged 18 and older" in resp1.json()["detail"]

    # Verify UnderageQuarantine record added
    quarantine_records = [obj for obj in added_objects if isinstance(obj, UnderageQuarantine)]
    assert len(quarantine_records) == 1
    expected_hash = hashlib.sha256(b"device_minor_xyz:+919988776655").hexdigest()
    assert quarantine_records[0].device_phone_hash == expected_hash

    # Verify audit log recorded AUTH_UNDERAGE_QUARANTINED
    audit_records = [obj for obj in added_objects if isinstance(obj, LegalAuditLog)]
    assert len(audit_records) == 1
    assert audit_records[0].action_type == "AUTH_UNDERAGE_QUARANTINED"

    # 2. Second attempt: Same device & phone, but forged age 20 (lying about DOB)
    dob_20 = (date.today() - timedelta(days=20 * 365 + 5)).isoformat()
    payload_forged = dict(payload_underage)
    payload_forged["dob"] = dob_20

    # DB now returns existing active quarantine entry
    active_quarantine = UnderageQuarantine(
        device_phone_hash=expected_hash,
        quarantined_until=datetime.now(timezone.utc) + timedelta(days=179),
        attempt_count=1
    )
    mock_quarantine_res2 = AsyncMock()
    mock_quarantine_res2.scalar_one_or_none = lambda: active_quarantine
    mock_session.execute = AsyncMock(return_value=mock_quarantine_res2)

    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        resp2 = client.post("/api/v1/auth/session-sync", json=payload_forged, headers=headers)

    assert resp2.status_code == 403, resp2.text
    assert "minor safety policies" in resp2.json()["detail"]

# ==============================================================================
# TEST 3: 'Zero on Delete' Uninstall Reset Verification
# ==============================================================================
def test_zero_on_delete_uninstall_reset():
    """
    Existing user with streak_count = 15, reward_balance = 12, last_installation_uuid = 'UUID_OLD'.
    Sync sent with X-Installation-UUID: 'UUID_NEW'.
    Asserts status 'reset_executed', streak_count == 0, reward_balance == 0,
    and audit log records AUTH_REINSTALL_SYNC_WIPE.
    """
    old_uuid = "UUID_OLD_INSTALL_123"
    new_uuid = "UUID_NEW_INSTALL_456"

    headers = {
        "Authorization": "Bearer mock_valid_firebase_token",
        "X-Installation-UUID": new_uuid
    }
    dob_22 = (date.today() - timedelta(days=22 * 365 + 5)).isoformat()
    payload = {
        "phone_number": "+919811122233",
        "whatsapp_number": "+919811122233",
        "full_name": "Priya Sharma",
        "dob": dob_22,
        "gender": "female",
        "city": "Patna",
        "bio": "Artist",
        "android_id": "android_dev_p"
    }

    existing_user = User(
        id=uuid4(),
        firebase_uid=MOCK_FIREBASE_UID,
        phone_number="+919811122233",
        whatsapp_number="+919811122233",
        full_name="Priya Sharma",
        dob=date(2002, 1, 1),
        gender="female",
        city="Patna",
        streak_count=15,
        reward_balance=12,
        last_installation_uuid=old_uuid,
        is_banned=False
    )

    added_objects = []
    mock_session = AsyncMock()
    mock_session.add = MagicMock(side_effect=lambda x: added_objects.append(x))
    mock_session.commit = AsyncMock(return_value=None)
    mock_session.refresh = AsyncMock(return_value=None)

    mock_quarantine_res = AsyncMock()
    mock_quarantine_res.scalar_one_or_none = lambda: None

    mock_user_res = AsyncMock()
    mock_user_res.scalar_one_or_none = lambda: existing_user

    mock_session.execute = AsyncMock(side_effect=[mock_quarantine_res, mock_user_res])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    mock_token_payload = {"uid": MOCK_FIREBASE_UID, "email": "priya@example.com"}

    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        response = client.post("/api/v1/auth/session-sync", json=payload, headers=headers)

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "reset_executed"
    assert data["streak_count"] == 0
    assert data["reward_balance"] == 0

    # Assert user state wiped
    assert existing_user.streak_count == 0
    assert existing_user.reward_balance == 0
    assert existing_user.last_installation_uuid == new_uuid

    # Assert statutory CERT-In audit log
    audit_records = [obj for obj in added_objects if isinstance(obj, LegalAuditLog)]
    assert len(audit_records) == 1
    assert audit_records[0].action_type == "AUTH_REINSTALL_SYNC_WIPE"
    assert audit_records[0].installation_uuid == new_uuid

# ==============================================================================
# TEST 4: Normal Session Resume (Identical Installation UUID)
# ==============================================================================
def test_normal_session_resume():
    """
    Existing user with streak_count = 15, reward_balance = 12, last_installation_uuid = 'SAME_UUID'.
    Sync sent with identical X-Installation-UUID: 'SAME_UUID'.
    Asserts status 'ok', streak_count == 15, reward_balance == 12 are preserved.
    Asserts audit log records AUTH_LOGIN_SYNC.
    """
    same_uuid = "SAME_UUID_INSTALL_789"

    headers = {
        "Authorization": "Bearer mock_valid_firebase_token",
        "X-Installation-UUID": same_uuid
    }
    dob_22 = (date.today() - timedelta(days=22 * 365 + 5)).isoformat()
    payload = {
        "phone_number": "+919811122233",
        "whatsapp_number": "+919811122233",
        "full_name": "Priya Sharma",
        "dob": dob_22,
        "gender": "female",
        "city": "Patna",
        "bio": "Artist",
        "android_id": "android_dev_p"
    }

    existing_user = User(
        id=uuid4(),
        firebase_uid=MOCK_FIREBASE_UID,
        phone_number="+919811122233",
        whatsapp_number="+919811122233",
        full_name="Priya Sharma",
        dob=date(2002, 1, 1),
        gender="female",
        city="Patna",
        streak_count=15,
        reward_balance=12,
        last_installation_uuid=same_uuid,
        is_banned=False
    )

    added_objects = []
    mock_session = AsyncMock()
    mock_session.add = MagicMock(side_effect=lambda x: added_objects.append(x))
    mock_session.commit = AsyncMock(return_value=None)
    mock_session.refresh = AsyncMock(return_value=None)

    mock_quarantine_res = AsyncMock()
    mock_quarantine_res.scalar_one_or_none = lambda: None

    mock_user_res = AsyncMock()
    mock_user_res.scalar_one_or_none = lambda: existing_user

    mock_session.execute = AsyncMock(side_effect=[mock_quarantine_res, mock_user_res])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    mock_token_payload = {"uid": MOCK_FIREBASE_UID, "email": "priya@example.com"}

    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        response = client.post("/api/v1/auth/session-sync", json=payload, headers=headers)

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "ok"
    assert data["streak_count"] == 15
    assert data["reward_balance"] == 12

    # Assert user state was NOT wiped
    assert existing_user.streak_count == 15
    assert existing_user.reward_balance == 12

    # Assert statutory CERT-In audit log
    audit_records = [obj for obj in added_objects if isinstance(obj, LegalAuditLog)]
    assert len(audit_records) == 1
    assert audit_records[0].action_type == "AUTH_LOGIN_SYNC"
    assert audit_records[0].installation_uuid == same_uuid
