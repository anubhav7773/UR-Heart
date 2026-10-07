import uuid
from datetime import date, datetime, timedelta, timezone
import pytest
from app.services.blind_date_matcher import (
    normalize_gender,
    normalize_preference,
    is_mutually_compatible,
    BlindDateMatcherService,
    calculate_user_age
)
from app.models.domain.blind_date import BlindDateSession
from app.models.domain.user import User


def test_gender_normalization_three_genders():
    """Verifies that all 3 genders are accurately normalized without bias."""
    assert normalize_gender("Man") == "man"
    assert normalize_gender("male") == "man"
    assert normalize_gender("MEN") == "man"
    
    assert normalize_gender("Woman") == "woman"
    assert normalize_gender("female") == "woman"
    assert normalize_gender("women") == "woman"

    assert normalize_gender("non-binary") == "other"
    assert normalize_gender("Queer") == "other"
    assert normalize_gender("Other") == "other"
    assert normalize_gender(None) == "other"


def test_preference_normalization():
    """Verifies that preferences correctly map into sets of allowable genders."""
    assert normalize_preference("men") == {"man"}
    assert normalize_preference("women") == {"woman"}
    assert normalize_preference("other") == {"other"}
    assert normalize_preference("everyone") == {"man", "woman", "other"}
    assert normalize_preference("all") == {"man", "woman", "other"}
    assert normalize_preference("men, other") == {"man", "other"}


def test_bidirectional_compatibility_straight_pair():
    """Man seeking Woman + Woman seeking Man -> True."""
    res = is_mutually_compatible(
        gender_a="man",
        pref_a={"woman"},
        age_a=25,
        min_age_a=20,
        max_age_a=30,
        gender_b="woman",
        pref_b={"man"},
        age_b=24,
        min_age_b=22,
        max_age_b=28,
    )
    assert res is True


def test_bidirectional_compatibility_mismatch_gender():
    """Straight Man seeking Woman should NEVER match with Straight Man."""
    res = is_mutually_compatible(
        gender_a="man",
        pref_a={"woman"},
        age_a=25,
        min_age_a=20,
        max_age_a=30,
        gender_b="man",
        pref_b={"woman"},
        age_b=26,
        min_age_b=20,
        max_age_b=30,
    )
    assert res is False


def test_bidirectional_compatibility_non_binary_inclusion():
    """Non-binary user seeking everyone matches with woman seeking everyone."""
    res = is_mutually_compatible(
        gender_a="other",
        pref_a={"man", "woman", "other"},
        age_a=23,
        min_age_a=20,
        max_age_a=30,
        gender_b="woman",
        pref_b={"man", "woman", "other"},
        age_b=24,
        min_age_b=20,
        max_age_b=30,
    )
    assert res is True


def test_bidirectional_compatibility_one_way_rejection():
    """Non-binary user seeking men does NOT match with straight man seeking women only."""
    res = is_mutually_compatible(
        gender_a="other",
        pref_a={"man"},
        age_a=23,
        min_age_a=20,
        max_age_a=30,
        gender_b="man",
        pref_b={"woman"},
        age_b=24,
        min_age_b=20,
        max_age_b=30,
    )
    assert res is False


def test_bidirectional_compatibility_age_filter():
    """Candidate is outside preferred age boundary."""
    res = is_mutually_compatible(
        gender_a="woman",
        pref_a={"man"},
        age_a=22,
        min_age_a=23,  # Seeker wants 23-30
        max_age_a=30,
        gender_b="man",
        pref_b={"woman"},
        age_b=21,      # Candidate is 21 (under 23)
        min_age_b=18,
        max_age_b=25,
    )
    assert res is False


def test_dpdp_privacy_shield_veiled_session():
    """Ensures raw photos are EMPTY and full name is masked during active session."""
    session = BlindDateSession(
        id=uuid.uuid4(),
        user1_id=uuid.uuid4(),
        user2_id=uuid.uuid4(),
        status="active",
        started_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5)
    )

    partner = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Pooja Sharma",
        dob=date(2000, 1, 1),
        gender="Woman",
        interested_in="Men",
        contact_bridge_encrypted="enc_bridge",
        location_name="Indore, Madhya Pradesh",
        photos=["https://r2.urheart.app/secret1.jpg", "https://r2.urheart.app/secret2.jpg"],
        avatar_url="https://r2.urheart.app/avatar.jpg",
        referral_code="POOJAS12"
    )

    masked = BlindDateMatcherService.mask_partner_for_session(
        session=session,
        viewer_id=session.user1_id,
        partner=partner
    )

    # ZERO RAW PHOTOS LEAKED
    assert masked["photos"] == []
    assert masked["avatar_url"] is None
    # First name only for safe conversational warmth
    assert masked["name"] == "Pooja"
    assert masked["is_revealed"] is False
    assert masked["blur_radius"] == 35.0


def test_dpdp_privacy_shield_revealed_session():
    """Ensures photos and full identity unlock only when mutually resonated ('revealed')."""
    session = BlindDateSession(
        id=uuid.uuid4(),
        user1_id=uuid.uuid4(),
        user2_id=uuid.uuid4(),
        status="revealed",
        started_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5)
    )

    partner = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Pooja Sharma",
        dob=date(2000, 1, 1),
        gender="Woman",
        interested_in="Men",
        contact_bridge_encrypted="enc_bridge",
        location_name="Indore, Madhya Pradesh",
        photos=["https://r2.urheart.app/secret1.jpg"],
        avatar_url="https://r2.urheart.app/avatar.jpg",
        referral_code="POOJAS12"
    )

    unmasked = BlindDateMatcherService.mask_partner_for_session(
        session=session,
        viewer_id=session.user1_id,
        partner=partner
    )

    assert unmasked["photos"] == ["https://r2.urheart.app/secret1.jpg"]
    assert unmasked["avatar_url"] == "https://r2.urheart.app/avatar.jpg"
    assert unmasked["name"] == "Pooja Sharma"
    assert unmasked["is_revealed"] is True
    assert unmasked["blur_radius"] == 0.0


@pytest.mark.asyncio
async def test_submit_decision_mutual_resonate_creates_match():
    """When both users submit 'resonate', status becomes 'revealed' and match is created."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    session_id = uuid.uuid4()
    session = BlindDateSession(
        id=session_id,
        user1_id=user1_id,
        user2_id=user2_id,
        status="active",
        user1_decision="resonate",
        user2_decision="pending",
        match_id=None
    )

    from unittest.mock import AsyncMock, MagicMock
    mock_db = AsyncMock()
    mock_session_res = MagicMock()
    mock_session_res.scalars.return_value.first.return_value = session
    mock_match_res = MagicMock()
    mock_match_res.scalars.return_value.first.return_value = None  # No prior match
    mock_db.execute.side_effect = [mock_session_res, mock_match_res]

    updated = await BlindDateMatcherService.submit_decision(
        mock_db, session_id, user2_id, "resonate"
    )

    assert updated.status == "revealed"
    assert updated.user2_decision == "resonate"
    assert updated.match_id is not None
    assert mock_db.commit.called


@pytest.mark.asyncio
async def test_submit_decision_pass_sets_status_passed():
    """When either user submits 'pass', status becomes 'passed'."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    session_id = uuid.uuid4()
    session = BlindDateSession(
        id=session_id,
        user1_id=user1_id,
        user2_id=user2_id,
        status="active",
        user1_decision="pending",
        user2_decision="pending",
    )

    from unittest.mock import AsyncMock, MagicMock
    mock_db = AsyncMock()
    mock_session_res = MagicMock()
    mock_session_res.scalars.return_value.first.return_value = session
    mock_db.execute.return_value = mock_session_res

    updated = await BlindDateMatcherService.submit_decision(
        mock_db, session_id, user1_id, "pass"
    )

    assert updated.status == "passed"
    assert updated.user1_decision == "pass"
    assert mock_db.commit.called

