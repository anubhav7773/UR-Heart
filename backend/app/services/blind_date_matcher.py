import random
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Set, Tuple

from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain.blind_date import BlindDateMessage, BlindDateQueueEntry, BlindDateSession
from app.models.domain.match import Match
from app.models.domain.user import User

# Curated, soulful, introspective icebreaker prompts crafted for deep soul connection
EVA_ICEBREAKER_PROMPTS = [
    "What is a quiet dream you hold close to your heart?",
    "If our voices were the only thing in the room right now, what is one truth you'd want me to know about you?",
    "What is a small, quiet moment from your week that brought you unexpected peace?",
    "What song currently feels like a page torn from your journal?",
    "If you could share a cup of chai in total silence with anyone, what would you hope they understand about you?",
    "What is a dream you've held onto since childhood that hasn't changed?",
    "What does genuine emotional safety feel like to you in a single sentence?",
    "What is something kind a stranger once did for you that you never forgot?",
    "If tomorrow was your completely free day with zero expectations, how would you spend the first hour of morning?",
    "What is a lesson love or life taught you that you are deeply grateful for?"
]


def normalize_gender(raw_gender: Optional[str]) -> str:
    """
    Industry-grade normalization for all 3 gender categories:
    'man', 'woman', or 'other' (non-binary / queer / gender-expansive).
    """
    if not raw_gender:
        return "other"
    val = raw_gender.strip().lower()
    if val in ("man", "male", "men", "m"):
        return "man"
    if val in ("woman", "female", "women", "w", "f"):
        return "woman"
    return "other"


def normalize_preference(raw_pref: Optional[str]) -> Set[str]:
    """
    Normalizes interested_in preference into a canonical set of allowed genders:
    Supports single choices ('men', 'women', 'other'), or expansive ('everyone', 'all', 'any').
    """
    if not raw_pref:
        return {"man", "woman", "other"}
    
    val = raw_pref.strip().lower()
    if val in ("everyone", "all", "any", "both", "all genders"):
        return {"man", "woman", "other"}

    # Split by comma or slash if composite
    parts = [p.strip() for p in val.replace("/", ",").split(",") if p.strip()]
    normalized: Set[str] = set()

    for p in parts:
        if p in ("man", "male", "men", "m"):
            normalized.add("man")
        elif p in ("woman", "female", "women", "w", "f"):
            normalized.add("woman")
        elif p in ("other", "non-binary", "queer", "transgender", "nb", "nonbinary"):
            normalized.add("other")
        elif p in ("everyone", "all", "any", "both"):
            normalized.update({"man", "woman", "other"})

    return normalized if normalized else {"man", "woman", "other"}


def calculate_user_age(dob: Optional[date]) -> int:
    """Accurately calculates age from date of birth, safe with default 24."""
    if not dob:
        return 24
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def is_mutually_compatible(
    gender_a: str,
    pref_a: Set[str],
    age_a: int,
    min_age_a: int,
    max_age_a: int,
    gender_b: str,
    pref_b: Set[str],
    age_b: int,
    min_age_b: int,
    max_age_b: int,
) -> bool:
    """
    100% mathematically accurate bidirectional compatibility engine.
    Satisfies:
      1. B's gender is sought by A (gender_b in pref_a)
      2. A's gender is sought by B (gender_a in pref_b)
      3. B's age is within A's bounds (min_age_a <= age_b <= max_age_a)
      4. A's age is within B's bounds (min_age_b <= age_a <= max_age_b)
    """
    if gender_b not in pref_a:
        return False
    if gender_a not in pref_b:
        return False
    if not (min_age_a <= age_b <= max_age_a):
        return False
    if not (min_age_b <= age_a <= max_age_b):
        return False
    return True


class BlindDateMatcherService:
    @staticmethod
    def get_random_icebreaker() -> str:
        return random.choice(EVA_ICEBREAKER_PROMPTS)

    @staticmethod
    async def get_active_session_for_user(
        db: AsyncSession,
        user_id: uuid.UUID
    ) -> Optional[BlindDateSession]:
        """Finds any currently running or unexpired session for user."""
        now = datetime.now(timezone.utc)
        result = await db.execute(
            select(BlindDateSession).where(
                or_(
                    BlindDateSession.user1_id == user_id,
                    BlindDateSession.user2_id == user_id
                ),
                BlindDateSession.status.in_(["active", "revealed"]),
                BlindDateSession.expires_at > now
            )
        )
        return result.scalars().first()

    @staticmethod
    async def join_or_match_queue(
        db: AsyncSession,
        user: User
    ) -> Tuple[Optional[BlindDateSession], BlindDateQueueEntry]:
        """
        Attempts to find a mutually compatible soul in the PostgreSQL queue.
        If found, immediately creates a 5-minute Blind Date Session.
        If not found, enqueues the user in 'waiting' status with ACID isolation.
        """
        now = datetime.now(timezone.utc)

        # 1. First verify if user already has an active session
        existing_session = await BlindDateMatcherService.get_active_session_for_user(db, user.id)
        if existing_session:
            # Query or make stub queue entry
            q_res = await db.execute(
                select(BlindDateQueueEntry).where(BlindDateQueueEntry.user_id == user.id)
            )
            q_entry = q_res.scalars().first()
            if not q_entry:
                q_entry = BlindDateQueueEntry(
                    user_id=user.id,
                    gender=normalize_gender(user.gender),
                    interested_in=user.interested_in or "everyone",
                    age=calculate_user_age(user.dob),
                    status="paired",
                    paired_session_id=existing_session.id
                )
            return existing_session, q_entry

        # 2. Extract normalized demographics
        gender_a = normalize_gender(user.gender)
        pref_a = normalize_preference(user.interested_in)
        age_a = calculate_user_age(user.dob)
        min_age_a = getattr(user, "preferred_age_min", 18) or 18
        max_age_a = getattr(user, "preferred_age_max", 45) or 45

        # 3. Fetch waiting candidates from queue (excluding self)
        # We query candidates ordered by joined_at for fair FIFO matchmaking
        candidates_query = (
            select(BlindDateQueueEntry)
            .where(
                BlindDateQueueEntry.status == "waiting",
                BlindDateQueueEntry.user_id != user.id
            )
            .order_by(BlindDateQueueEntry.joined_at.asc())
        )
        candidates_res = await db.execute(candidates_query)
        candidates: List[BlindDateQueueEntry] = list(candidates_res.scalars().all())

        compatible_candidate: Optional[BlindDateQueueEntry] = None
        for candidate in candidates:
            cand_pref = normalize_preference(candidate.interested_in)
            if is_mutually_compatible(
                gender_a=gender_a,
                pref_a=pref_a,
                age_a=age_a,
                min_age_a=min_age_a,
                max_age_a=max_age_a,
                gender_b=candidate.gender,
                pref_b=cand_pref,
                age_b=candidate.age,
                min_age_b=candidate.preferred_age_min,
                max_age_b=candidate.preferred_age_max,
            ):
                compatible_candidate = candidate
                break

        if compatible_candidate:
            # MATCH FOUND: Instantiate 5-minute timed session
            session_id = uuid.uuid4()
            expires_at = now + timedelta(minutes=5)
            icebreaker = BlindDateMatcherService.get_random_icebreaker()

            session = BlindDateSession(
                id=session_id,
                user1_id=user.id,
                user2_id=compatible_candidate.user_id,
                status="active",
                started_at=now,
                expires_at=expires_at,
                user1_decision="pending",
                user2_decision="pending",
                icebreaker_prompt=icebreaker
            )
            db.add(session)

            # Update candidate entry
            compatible_candidate.status = "paired"
            compatible_candidate.paired_session_id = session_id

            # Upsert current user entry
            q_res = await db.execute(
                select(BlindDateQueueEntry).where(BlindDateQueueEntry.user_id == user.id)
            )
            user_entry = q_res.scalars().first()
            if not user_entry:
                user_entry = BlindDateQueueEntry(
                    user_id=user.id,
                    gender=gender_a,
                    interested_in=user.interested_in or "everyone",
                    age=age_a,
                    preferred_age_min=min_age_a,
                    preferred_age_max=max_age_a,
                    status="paired",
                    paired_session_id=session_id
                )
                db.add(user_entry)
            else:
                user_entry.gender = gender_a
                user_entry.interested_in = user.interested_in or "everyone"
                user_entry.age = age_a
                user_entry.status = "paired"
                user_entry.paired_session_id = session_id

            await db.commit()
            await db.refresh(session)
            await db.refresh(user_entry)
            return session, user_entry

        # NO COMPATIBLE CANDIDATE FOUND YET: Enqueue in waiting state
        q_res = await db.execute(
            select(BlindDateQueueEntry).where(BlindDateQueueEntry.user_id == user.id)
        )
        user_entry = q_res.scalars().first()
        if not user_entry:
            user_entry = BlindDateQueueEntry(
                user_id=user.id,
                gender=gender_a,
                interested_in=user.interested_in or "everyone",
                age=age_a,
                preferred_age_min=min_age_a,
                preferred_age_max=max_age_a,
                status="waiting",
                joined_at=now,
                paired_session_id=None
            )
            db.add(user_entry)
        else:
            user_entry.gender = gender_a
            user_entry.interested_in = user.interested_in or "everyone"
            user_entry.age = age_a
            user_entry.preferred_age_min = min_age_a
            user_entry.preferred_age_max = max_age_a
            user_entry.status = "waiting"
            user_entry.joined_at = now
            user_entry.paired_session_id = None

        await db.commit()
        await db.refresh(user_entry)
        return None, user_entry

    @staticmethod
    async def check_queue_status(
        db: AsyncSession,
        user_id: uuid.UUID
    ) -> Tuple[Optional[BlindDateSession], Optional[BlindDateQueueEntry]]:
        """Polls current status for a waiting seeker in the queue."""
        q_res = await db.execute(
            select(BlindDateQueueEntry).where(BlindDateQueueEntry.user_id == user_id)
        )
        user_entry = q_res.scalars().first()
        if not user_entry:
            return None, None

        if user_entry.status == "paired" and user_entry.paired_session_id:
            s_res = await db.execute(
                select(BlindDateSession).where(BlindDateSession.id == user_entry.paired_session_id)
            )
            session = s_res.scalars().first()
            return session, user_entry

        return None, user_entry

    @staticmethod
    async def cancel_queue_entry(db: AsyncSession, user_id: uuid.UUID) -> bool:
        """Removes or cancels user from blind date queue."""
        res = await db.execute(
            delete(BlindDateQueueEntry).where(BlindDateQueueEntry.user_id == user_id)
        )
        await db.commit()
        return res.rowcount > 0

    @staticmethod
    async def submit_decision(
        db: AsyncSession,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        decision: str  # 'resonate' or 'pass'
    ) -> BlindDateSession:
        """
        Processes mutual consent decision at Resonance Gate.
        If both resonate -> status becomes 'revealed' and Match row created.
        If either passes -> status becomes 'passed' with zero residual liability.
        """
        res = await db.execute(
            select(BlindDateSession).where(BlindDateSession.id == session_id)
        )
        session = res.scalars().first()
        if not session:
            raise ValueError("Blind date session not found.")

        if user_id == session.user1_id:
            session.user1_decision = decision
        elif user_id == session.user2_id:
            session.user2_decision = decision
        else:
            raise ValueError("User is not a participant in this session.")

        # Mutual evaluation
        if session.user1_decision == "resonate" and session.user2_decision == "resonate":
            session.status = "revealed"
            # Create match if not already created
            if not session.match_id:
                # Ensure ordered IDs for uniqueness
                u1 = min(session.user1_id, session.user2_id)
                u2 = max(session.user1_id, session.user2_id)
                existing_match_res = await db.execute(
                    select(Match).where(Match.user1_id == u1, Match.user2_id == u2)
                )
                match = existing_match_res.scalars().first()
                if not match:
                    match = Match(
                        id=uuid.uuid4(),
                        user1_id=u1,
                        user2_id=u2,
                        is_active=True
                    )
                    db.add(match)
                    await db.flush()
                session.match_id = match.id
        elif session.user1_decision == "pass" or session.user2_decision == "pass":
            session.status = "passed"

        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    def mask_partner_for_session(
        session: BlindDateSession,
        viewer_id: uuid.UUID,
        partner: User
    ) -> dict:
        """
        STATUTORY DPDP ACT 2023 PRIVACY SHIELD:
        Guarantees ZERO raw photo URLs, zero full names, zero phone/email leakage
        over the network during the active blind date session.
        Only unmasks if and only if both parties mutually tapped 'Resonate' ('revealed').
        """
        is_revealed = session.status == "revealed"
        partner_age = calculate_user_age(partner.dob)
        
        # Privacy-conscious first name extraction
        first_name = "Soul Seeker"
        if partner.full_name:
            first_name = partner.full_name.strip().split()[0]

        if not is_revealed:
            return {
                "id": str(partner.id),
                "name": f"{first_name}",
                "age": partner_age,
                "gender": partner.gender,
                "location": partner.location_name.split(",")[0].strip() if partner.location_name else "Sanctuary",
                "bio": "Veiled in Sanctuary mystery...",
                "photos": [],  # STRICTLY EMPTY: ZERO raw photo URLs on network
                "avatar_url": None,  # Veiled placeholder
                "voice_spark_url": partner.voice_spark_url,
                "voice_spark_prompt": partner.voice_spark_prompt,
                "voice_spark_duration": float(partner.voice_spark_duration or 7.0),
                "is_voice_verified": bool(partner.is_voice_verified),
                "is_revealed": False,
                "blur_radius": 35.0
            }
        else:
            return {
                "id": str(partner.id),
                "name": partner.full_name,
                "age": partner_age,
                "gender": partner.gender,
                "location": partner.location_name,
                "bio": partner.bio or "",
                "photos": partner.photos or [],
                "avatar_url": partner.avatar_url,
                "voice_spark_url": partner.voice_spark_url,
                "voice_spark_prompt": partner.voice_spark_prompt,
                "voice_spark_duration": float(partner.voice_spark_duration or 7.0),
                "is_voice_verified": bool(partner.is_voice_verified),
                "is_revealed": True,
                "blur_radius": 0.0
            }
