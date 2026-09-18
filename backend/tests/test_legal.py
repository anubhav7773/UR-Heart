import pytest
from uuid import uuid4
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.grievance_ticket import GrievanceTicket

client = TestClient(app)

def test_get_grievance_officer_details():
    response = client.get("/api/v1/legal/officer-details")
    assert response.status_code == 200
    data = response.json()
    assert data["officer_name"] == "Anubhav Singh"
    assert "Rule 3(2) IT Rules 2021" in data["designation"]
    assert data["entity_name"] == "ASI Verticals"
    assert data["email"] == "kshtriyaanubhav9120@gmail.com"
    assert data["acknowledgement_sla"] == "Within 24 Hours"
    assert "72 Hours for NCII" in data["resolution_sla"]

def test_get_legal_policies():
    # Privacy Notice
    res_privacy = client.get("/api/v1/legal/policies/privacy")
    assert res_privacy.status_code == 200
    assert "DPDP" in res_privacy.json()["title"]

    # Terms / EULA
    res_terms = client.get("/api/v1/legal/policies/terms")
    assert res_terms.status_code == 200
    assert "EULA" in res_terms.json()["title"]

    # Community Guidelines
    res_guidelines = client.get("/api/v1/legal/policies/community_guidelines")
    assert res_guidelines.status_code == 200
    assert "Zero Harassment" in res_guidelines.json()["title"]

def test_file_grievance_ticket_ncii_72h_sla():
    user_id = uuid4()
    user = User(
        id=user_id,
        firebase_uid="fb_legal_1",
        full_name="Pooja Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.post(
            "/api/v1/legal/grievance/file",
            data={
                "category": "ncii_nudity",
                "description": "Non-consensual image shared in violation of policy",
            },
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "ticket_created"
        assert data["ticket_number"].startswith("URH-")
        assert data["acknowledgement_sla"] == "Within 24 Hours"
        assert data["resolution_sla"] == "Within 72 Hours"
        assert mock_db.add.called
        assert mock_db.commit.called
    finally:
        app.dependency_overrides.clear()

def test_file_grievance_ticket_standard_15d_sla():
    user_id = uuid4()
    user = User(
        id=user_id,
        firebase_uid="fb_legal_2",
        full_name="Pooja Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.post(
            "/api/v1/legal/grievance/file",
            data={
                "category": "harassment_abuse",
                "description": "Repeated offensive remarks in direct messages",
            },
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "ticket_created"
        assert data["ticket_number"].startswith("URH-")
        assert data["resolution_sla"] == "Within 15 Days"
    finally:
        app.dependency_overrides.clear()

def test_get_my_grievance_tickets():
    user_id = uuid4()
    user = User(
        id=user_id,
        firebase_uid="fb_legal_3",
        full_name="Pooja Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    now = datetime.now(timezone.utc)
    mock_ticket = GrievanceTicket(
        id=1,
        ticket_number="URH-20260918-1001",
        reporter_id=user_id,
        category="harassment_abuse",
        description="Harassment report",
        status="received",
        sla_acknowledgement_deadline=now + timedelta(hours=24),
        sla_resolution_deadline=now + timedelta(days=15),
        created_at=now,
        updated_at=now,
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = [mock_ticket]
    mock_db.execute.return_value = mock_res

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.get(
            "/api/v1/legal/grievance/my-tickets",
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 200
        tickets = response.json()
        assert len(tickets) == 1
        assert tickets[0]["ticket_number"] == "URH-20260918-1001"
        assert tickets[0]["status"] == "received"
    finally:
        app.dependency_overrides.clear()
