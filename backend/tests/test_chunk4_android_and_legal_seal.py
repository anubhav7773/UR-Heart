import os
import re
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User

client = TestClient(app)

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


def create_mock_user(user_id=None, email="founder@asiverticals.me"):
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        auth_id=uuid.uuid4(),
        email=email,
        full_name="Anubhav Singh",
        role="superadmin",
        subscription_tier="gold",
        dob=datetime(1995, 5, 20).date(),
        gender="Man",
        interested_in="Woman",
        contact_bridge_encrypted="enc_bridge_founder",
        referral_code="ASIVERTI",
    )


# ==============================================================================
# 1. TEST SEC-HIGH-05: Android Backup Blocker & Hardware Storage Architecture
# ==============================================================================
def test_android_manifest_backup_blocker():
    """
    CRITERIA 1 (SEC-HIGH-05):
    Inspect AndroidManifest.xml and verify that allowBackup is strictly set to false,
    and both legacy and modern backup extraction rules are specified.
    """
    manifest_path = PROJECT_ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    assert manifest_path.exists(), f"AndroidManifest.xml missing at {manifest_path}"

    content = manifest_path.read_text(encoding="utf-8")
    assert 'android:allowBackup="false"' in content, "allowBackup MUST be strictly 'false'"
    assert 'android:fullBackupContent="@xml/backup_rules"' in content, "fullBackupContent rule must be referenced"
    assert 'android:dataExtractionRules="@xml/data_extraction_rules"' in content, "dataExtractionRules must be referenced"

    # Verify backup rules XML files exist and exclude all paths
    data_extraction = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res" / "xml" / "data_extraction_rules.xml"
    assert data_extraction.exists(), "data_extraction_rules.xml missing"
    assert '<exclude path="." />' in data_extraction.read_text(encoding="utf-8")

    backup_rules = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res" / "xml" / "backup_rules.xml"
    assert backup_rules.exists(), "backup_rules.xml missing"
    assert '<exclude path="." />' in backup_rules.read_text(encoding="utf-8")


def test_hardware_secure_storage_wiring():
    """
    CRITERIA 2 (SEC-HIGH-05):
    Verify that SecureSessionStorage uses FlutterSecureStorage with encryptedSharedPreferences,
    and that auth interceptors and repositories route token operations to SecureSessionStorage.
    """
    storage_file = PROJECT_ROOT / "lib" / "core" / "storage" / "secure_session_storage.dart"
    assert storage_file.exists(), "secure_session_storage.dart missing"
    storage_code = storage_file.read_text(encoding="utf-8")

    assert "encryptedSharedPreferences: true" in storage_code, "Must enforce hardware EncryptedSharedPreferences"
    assert "clearAllSessionData" in storage_code, "Must provide atomic session clearing pipeline"
    assert "saveAuthToken" in storage_code, "Must provide secure token persistence"

    # Verify AuthInterceptor connects to SecureSessionStorage
    interceptor_file = PROJECT_ROOT / "lib" / "core" / "network" / "interceptors" / "auth_interceptor.dart"
    interceptor_code = interceptor_file.read_text(encoding="utf-8")
    assert "SecureSessionStorage.instance.getAuthToken()" in interceptor_code, "AuthInterceptor must read from SecureSessionStorage"

    # Verify ApiClient connects to SecureSessionStorage
    client_file = PROJECT_ROOT / "lib" / "core" / "network" / "api_client.dart"
    client_code = client_file.read_text(encoding="utf-8")
    assert "SecureSessionStorage.instance.getAuthToken()" in client_code, "ApiClient must read from SecureSessionStorage"


# ==============================================================================
# 2. TEST SEC-MED-03 & SEC-MED-04: Release Signing & R8 Minification
# ==============================================================================
def test_production_keystore_isolation():
    """
    CRITERIA 3 (SEC-MED-03):
    Inspect android/app/build.gradle.kts to verify debug keystore is detached from
    release build type, key.properties is loaded dynamically, and gitignore excludes secrets.
    """
    gradle_file = PROJECT_ROOT / "android" / "app" / "build.gradle.kts"
    assert gradle_file.exists(), "build.gradle.kts missing"
    gradle_code = gradle_file.read_text(encoding="utf-8")

    # Debug keystore must NOT be directly assigned to release
    assert 'signingConfig = signingConfigs.getByName("debug")' not in gradle_code, "Release must not use debug signing config"
    assert 'key.properties' in gradle_code, "Must dynamically parse key.properties"
    assert 'create("release")' in gradle_code, "Must create dedicated release signingConfig"

    # Verify gitignore excludes key.properties
    root_gitignore = (PROJECT_ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "key.properties" in root_gitignore, "Root .gitignore must ignore key.properties"
    android_gitignore = (PROJECT_ROOT / "android" / ".gitignore").read_text(encoding="utf-8")
    assert "key.properties" in android_gitignore, "Android .gitignore must ignore key.properties"


def test_r8_code_shrinking_and_proguard():
    """
    CRITERIA 4 (SEC-MED-04):
    Verify that R8 isMinifyEnabled and isShrinkResources are enabled for release,
    and proguard-rules.pro defines protection rules for Flutter, crypto, ads, and obfuscation.
    """
    gradle_file = PROJECT_ROOT / "android" / "app" / "build.gradle.kts"
    gradle_code = gradle_file.read_text(encoding="utf-8")
    assert "isMinifyEnabled = true" in gradle_code, "R8 minify must be enabled in release build"
    assert "isShrinkResources = true" in gradle_code, "Resource shrinking must be enabled in release build"

    proguard_file = PROJECT_ROOT / "android" / "app" / "proguard-rules.pro"
    assert proguard_file.exists(), "proguard-rules.pro missing"
    rules = proguard_file.read_text(encoding="utf-8")
    assert "androidx.security.crypto" in rules, "ProGuard must preserve AndroidX security crypto"
    assert "com.it_nomads.fluttersecurestorage" in rules, "ProGuard must preserve flutter secure storage"
    assert "com.google.android.gms.ads" in rules, "ProGuard must preserve Google Mobile Ads"
    assert "-repackageclasses" in rules, "ProGuard must configure class repackaging / obfuscation"


# ==============================================================================
# 3. TEST STATUTORY SAFE HARBOR & LEGAL SEAL (IT ACT 79 & DPDP 2023)
# ==============================================================================
def test_statutory_safe_harbor_and_grievance_officer_transparency():
    """
    CRITERIA 5 (Statutory Safe Harbor):
    Verify Grievance Officer details (Anubhav Singh, Ayodhya desk, asiverticals@gmail.com)
    are present in both statutory web endpoints and Flutter Legal Vault UI.
    """
    # 1. Backend Statutory Terms / Privacy Page
    res = client.get("/api/v1/statutory/privacy-policy")
    assert res.status_code == 200
    html = res.text
    assert "Anubhav Singh" in html, "Grievance Officer name must be published"
    assert "Ayodhya" in html, "Ayodhya registered desk must be published"
    assert "asiverticals@gmail.com" in html, "Statutory email must be published"
    assert "24 hours" in html and "15 days" in html, "Statutory SLA must be transparently disclosed"

    # 2. Flutter Vault UI Section
    vault_file = PROJECT_ROOT / "lib" / "features" / "legal_vault" / "presentation" / "widgets" / "grievance_compliance_section.dart"
    assert vault_file.exists(), "grievance_compliance_section.dart missing"
    vault_code = vault_file.read_text(encoding="utf-8")
    assert "Anubhav Singh" in vault_code, "Flutter UI must display Grievance Officer Anubhav Singh"
    assert "Ayodhya" in vault_code, "Flutter UI must display Ayodhya desk"
    assert "asiverticals@gmail.com" in vault_code, "Flutter UI must display official grievance email"


def test_statutory_grievance_sla_lock():
    """
    CRITERIA 6 (24h SLA & 15-day resolution clock):
    Submitting a grievance must emit a formal 24h statutory acknowledgment and
    compute the 15-day resolution due date.
    """
    mock_user = create_mock_user()
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        response = client.post(
            "/api/v1/legal/grievance",
            json={
                "violation_category": "harassment",
                "evidence_text": "Offensive language detected in chat.",
            }
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "acknowledged"
        assert "24-hour SLA" in data["sla_acknowledgment"]
        assert "statutory_resolution_deadline" in data
        assert data["support_desk_contact"] == "asiverticals@gmail.com"
        assert "dossier_reference_id" in data
    finally:
        app.dependency_overrides.clear()


def test_chat_pre_storage_moderation_shield():
    """
    CRITERIA 7 (Pre-Storage Moderation Shield):
    Sending dialogue messages containing phone numbers, social handles, or off-platform
    leak indicators must be blocked with HTTP 422 before touching the database.
    """
    mock_user = create_mock_user()
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # Off-platform phone number leak attempt
        response = client.post(
            "/api/v1/chat/messages",
            json={
                "match_id": str(uuid.uuid4()),
                "text": "Call me on WhatsApp +91 9876543210 tonight",
            }
        )
        assert response.status_code == 422, f"Expected 422, got {response.status_code}: {response.text}"
        assert "phone" in response.text.lower() or "off-platform" in response.text.lower() or "digits" in response.text.lower() or "contact" in response.text.lower()

        # Clean mindful dialogue must pass
        with patch("app.api.v1.endpoints.notifications.push_notification"):
            clean_res = client.post(
                "/api/v1/chat/messages",
                json={
                    "match_id": str(uuid.uuid4()),
                    "text": "Hello, thank you for connecting in this mindful sanctuary.",
                }
            )
            assert clean_res.status_code == 201
            assert clean_res.json()["status"] == "sent"
    finally:
        app.dependency_overrides.clear()


def test_cascading_account_incinerator():
    """
    CRITERIA 8 (DPDP Act 2023 Section 12):
    Verify that the account incinerator accepts the irrevocable confirmation token 'ERASE'
    and triggers atomic deletion of remote blobs, PostgreSQL records, and Auth user.
    """
    mock_user = create_mock_user()
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch("app.api.v1.endpoints.account_incinerator._purge_remote_user_storage", new=AsyncMock()) as mock_purge_storage, \
             patch("app.api.v1.endpoints.account_incinerator._delete_auth_identity", new=AsyncMock()) as mock_delete_auth:

            # Invalid confirmation token must be rejected
            bad_res = client.request(
                "DELETE",
                "/api/v1/auth/incinerate-account",
                json={"confirmation_token": "DELETE"}
            )
            assert bad_res.status_code == 422

            # Valid 'ERASE' token executes cascading shredding
            res = client.request(
                "DELETE",
                "/api/v1/auth/incinerate-account",
                json={"confirmation_token": "ERASE", "reason": "user_requested_erasure"}
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "incinerated"
            assert "DPDP Act 2023 Section 12" in data["compliance"]

            # Assert atomic purge calls were dispatched
            mock_purge_storage.assert_awaited_once_with(str(mock_user.id))
            mock_delete_auth.assert_awaited_once_with(str(mock_user.auth_id))
    finally:
        app.dependency_overrides.clear()
