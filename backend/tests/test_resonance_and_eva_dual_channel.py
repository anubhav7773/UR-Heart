import pytest
import uuid
from datetime import date
from pydantic import ValidationError

from app.models.domain.user import User
from app.services.resonance_engine import ResonanceEngine
from app.services.eva_identity_engine import EvaIdentityEngine, KycAiEvaluation as IdentityKycEval
from app.services.groq_service import KycAiEvaluation as GroqKycEval
from app.services.eva_companion_engine import EvaCompanionEngine
from app.services.eva_guardrails import EvaGuardrails


def test_resonance_engine_calculation():
    user1 = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Anubhav Singh",
        dob=date(2000, 1, 1),
        gender="Man",
        interested_in="Woman",
        bio="Mindful designer seeking deep reflection, art, and stillness.",
        profession="Architectural Designer",
        education="B.Arch",
        latitude=26.7922,
        longitude=82.1998,
        preferred_age_min=20,
        preferred_age_max=28,
        streak_count=5,
        kyc_status=True,
        referral_code="ANUBHAV1"
    )

    candidate1 = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Priya Sharma",
        dob=date(2001, 5, 15),
        gender="Woman",
        interested_in="Man",
        bio="Coffee lover, morning walks, literature and contemplative conversations.",
        profession="Writer & Researcher",
        education="M.A. Literature",
        latitude=26.8010,
        longitude=82.2050,
        preferred_age_min=22,
        preferred_age_max=30,
        streak_count=3,
        kyc_status=True,
        referral_code="PRIYA101"
    )

    score, insight, tags = ResonanceEngine.calculate_mutual_resonance(user1, candidate1)

    assert isinstance(score, int)
    assert 60 <= score <= 100
    assert isinstance(insight, str)
    assert len(insight) > 15
    assert isinstance(tags, list)
    assert len(tags) >= 2
    assert "Architecture" not in tags or "Writer" in str(tags) or "Literature" in str(tags)

    dist = ResonanceEngine.compute_distance(user1, candidate1)
    assert isinstance(dist, float)
    assert dist > 0.0


def test_kyc_rejection_reason_null_safety():
    """Verifies that rejection_reason=None or empty never throws Pydantic ValidationError."""
    eval1 = IdentityKycEval(
        is_live_human=True,
        face_match_score=85,
        estimated_age_bracket="22-28",
        is_underage=False,
        rejection_reason=None,
        status="approved"
    )
    assert eval1.status == "approved"

    eval2 = GroqKycEval(
        is_live_human=True,
        face_match_score=85,
        estimated_age_bracket="22-28",
        is_underage=False,
        rejection_reason=None,
        status="approved"
    )
    assert eval2.status == "approved"

    parsed = EvaIdentityEngine._parse_kyc_json(None)
    assert parsed is None

    parsed_empty = EvaIdentityEngine._parse_kyc_json("")
    assert parsed_empty is None


def test_eva_guardrails_out_of_app_defense():
    """Verifies strict app boundaries: coding, trivia, politics, math are rejected."""
    code_query = "Can you write a python script to scrape twitter?"
    is_safe, denial = EvaGuardrails.check_message(code_query)
    assert not is_safe
    assert denial is not None

    politics_query = "Who will win the upcoming election?"
    is_safe_pol, denial_pol = EvaGuardrails.check_message(politics_query)
    assert not is_safe_pol

    sanctuary_query = "I feel anxious about opening my heart in modern dating."
    is_safe_heart, _ = EvaGuardrails.check_message(sanctuary_query)
    assert is_safe_heart
