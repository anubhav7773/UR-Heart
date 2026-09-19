import pytest
import io
import numpy as np
from PIL import Image
from uuid import uuid4
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select

from app.main import app
from app.core.database import async_session_factory
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.services.image_moderation_service import detect_explicit_content


def create_mock_skin_image(skin_ratio_target: float = 0.8) -> bytes:
    """Helper to create an in-memory image with controlled skin ratio in YCbCr."""
    # Skin tone in YCbCr: Y ~ 150, Cb in [77, 127], Cr in [133, 173]
    # In RGB: approx (210, 160, 140)
    width, height = 128, 128
    total_pixels = width * height
    skin_pixels = int(total_pixels * skin_ratio_target)

    # Base image with non-skin color (blue: RGB 0, 0, 200)
    arr = np.zeros((height, width, 3), dtype=np.uint8)
    arr[:, :] = [0, 0, 200]

    # Fill portion with human skin tone (RGB 210, 160, 140)
    rows = int(skin_pixels / width)
    arr[:rows, :] = [210, 160, 140]

    img = Image.fromarray(arr, mode="RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_nsfw_detection_skin_ratio():
    """Validates that detect_explicit_content flags high skin ratio and passes normal images."""
    high_skin_img = create_mock_skin_image(0.85)
    assert detect_explicit_content(high_skin_img) is True

    normal_img = create_mock_skin_image(0.10)
    assert detect_explicit_content(normal_img) is False


@pytest.mark.asyncio
async def test_3_strikes_trigger_account_freeze(async_client: AsyncClient):
    """
    Simulates 3 distinct users filing violation reports against a target user.
    Asserts automated account freezing at 3 strikes.
    """
    # 1. Create target user and 3 reporting users
    target_user = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Reported Target User",
        dob=date(1998, 5, 20),
        gender="female",
        city="Delhi",
        bio="Target user profile",
        is_banned=False,
        is_frozen=False,
    )

    reporters = [
        User(
            id=uuid4(),
            firebase_uid=str(uuid4()),
            phone_number=f"+9198{str(uuid4().int)[:8]}",
            whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
            full_name=f"Reporter {i}",
            dob=date(1997, 1, 1),
            gender="male",
            city="Delhi",
            bio="Reporter profile",
            is_banned=False,
        )
        for i in range(1, 4)
    ]

    async with async_session_factory() as session:
        session.add(target_user)
        for r in reporters:
            session.add(r)
        await session.commit()

    try:
        # Submit reports sequentially from distinct reporters
        for i, reporter in enumerate(reporters):
            app.dependency_overrides[get_current_user] = lambda rep=reporter: rep

            res = await async_client.post(
                "/api/v1/safety/report-user",
                json={
                    "target_user_id": str(target_user.id),
                    "reason": "harassment",
                    "details": f"Repeated abuse strike {i+1}"
                },
                headers={
                    "Authorization": f"Bearer mock_token_{i}",
                    "x-device-id": f"device-hash-{i}",
                    "x-forwarded-for": f"192.168.1.{10+i}"
                }
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "success"
            assert data["distinct_reports"] == i + 1

            if i < 2:
                assert data["account_frozen"] is False
            else:
                assert data["account_frozen"] is True

        # Verify DB state of target user
        async with async_session_factory() as session:
            stmt = select(User).where(User.id == target_user.id)
            res = await session.execute(stmt)
            updated_user = res.scalar_one()

            assert updated_user.is_frozen is True
            assert updated_user.is_banned is True
            assert updated_user.report_count >= 3
            assert updated_user.frozen_at is not None
            assert "Automated Bannery: 3 distinct violation reports received." in updated_user.freeze_reason

    finally:
        app.dependency_overrides.pop(get_current_user, None)
        # Cleanup
        async with async_session_factory() as session:
            db_target = await session.get(User, target_user.id)
            if db_target:
                await session.delete(db_target)
            for r in reporters:
                db_r = await session.get(User, r.id)
                if db_r:
                    await session.delete(db_r)
            await session.commit()


@pytest.mark.asyncio
async def test_crpc_91_statutory_dossier(async_client: AsyncClient):
    """
    Validates Section 91 CrPC law enforcement statutory dossier generation.
    """
    # 1. Create a frozen user with legal audit logs
    target_user = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Statutory Audit User",
        dob=date(1996, 3, 15),
        gender="male",
        city="Mumbai",
        bio="User under investigation",
        is_banned=True,
        is_frozen=True,
        freeze_reason="Automated Bannery test",
    )

    reporter = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Reporting Witness",
        dob=date(1997, 2, 2),
        gender="female",
        city="Mumbai",
        bio="Witness",
        is_banned=False,
    )

    async with async_session_factory() as session:
        session.add(target_user)
        session.add(reporter)
        await session.commit()

    try:
        # File a report to generate audit logs
        app.dependency_overrides[get_current_user] = lambda: reporter
        rep_res = await async_client.post(
            "/api/v1/safety/report-user",
            json={
                "target_user_id": str(target_user.id),
                "reason": "scam_and_fraud",
                "details": "Section 91 CrPC investigation reference"
            },
            headers={
                "Authorization": "Bearer mock_rep_token",
                "x-device-id": "device-statutory-01",
                "x-forwarded-for": "203.0.113.195"
            }
        )
        assert rep_res.status_code == 200

        # Now query statutory dossier as master admin
        master_admin = User(
            id=uuid4(),
            firebase_uid=str(uuid4()),
            phone_number="+919811111111",
            whatsapp_number="+919811111111",
            full_name="Anubhav Singh",
            dob=date(1995, 1, 1),
            gender="male",
            city="Lucknow",
            bio="ASI Verticals Master Admin",
            is_super_admin=True,
            is_banned=False,
        )
        master_admin.email = "kshtriyaanubhav9120@gmail.com"
        app.dependency_overrides[get_current_user] = lambda: master_admin

        dossier_res = await async_client.get(
            f"/api/v1/admin/legal/crpc-91-dossier/{target_user.id}",
            headers={"Authorization": "Bearer mock_master_token"}
        )
        assert dossier_res.status_code == 200
        dossier = dossier_res.json()

        assert "statutory_header" in dossier
        header = dossier["statutory_header"]
        assert header["issuing_entity"] == "UR-Heart Intermediary Grievance & Legal Division (ASI Verticals)"
        assert "Section 91 CrPC" in header["statutory_mandate"]
        assert header["target_user_id"] == str(target_user.id)
        assert header["account_status"] == "FROZEN"

        assert dossier["total_audit_events"] >= 0
        assert isinstance(dossier["audit_trail"], list)

    finally:
        app.dependency_overrides.pop(get_current_user, None)
        async with async_session_factory() as session:
            db_t = await session.get(User, target_user.id)
            if db_t:
                await session.delete(db_t)
            db_r = await session.get(User, reporter.id)
            if db_r:
                await session.delete(db_r)
            await session.commit()
