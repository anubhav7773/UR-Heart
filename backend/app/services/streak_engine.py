from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.models.domain.user import User
from app.api.v1.endpoints.notifications import push_notification


_WARNED_STREAK_CACHE = set()


class StreakEngine:
    """
    24-Hour Mindful Streak & Profile Boosting Engine.
    Handles variable rewards, loss aversion decay penalties, and notifications.
    """

    @staticmethod
    async def evaluate_all_active_streaks(db: AsyncSession) -> int:
        """
        Runs on background server worker.
        1. Checks expired streaks (now > streak_expires_at), resets streak and sends streak_broken FCM push.
        2. Checks streaks expiring within 4 hours and sends streak_expiring FCM push.
        """
        now = datetime.now(timezone.utc)
        count = 0
        try:
            # 1. Decayed streaks
            stmt_decay = select(User).where(
                User.streak_expires_at.isnot(None),
                User.streak_expires_at < now,
                User.deleted_at.is_(None)
            )
            res_decay = await db.execute(stmt_decay)
            expired_users = res_decay.scalars().all()
            for user in expired_users:
                if (user.streak_count or 0) > 0:
                    prev_streak = user.streak_count
                    user.streak_count = 0
                    user.boost_points = max(0, (user.boost_points or 0) - 2)
                    user.reveal_tokens_count = max(0, (user.reveal_tokens_count or 0) - 1)
                    user.streak_expires_at = None
                    push_notification(
                        user_id=str(user.id),
                        notif_type="streak_broken",
                        title="🥀 Streak Broken & Profile Downgraded",
                        body=f"Your {prev_streak}-day sanctuary streak expired. Your profile discovery ranking was downgraded.",
                        data={
                            "action": "open_growth_hub",
                            "tab": "free_ads",
                            "streak_count": 0,
                            "boost_points": user.boost_points,
                            "reveal_tokens_count": user.reveal_tokens_count
                        }
                    )
                    count += 1
            if count > 0:
                await db.commit()

            # 2. Expiring soon warnings (T-4h)
            stmt_expiring = select(User).where(
                User.streak_expires_at.isnot(None),
                User.streak_expires_at >= now,
                User.streak_expires_at <= now + timedelta(hours=4),
                User.deleted_at.is_(None)
            )
            res_expiring = await db.execute(stmt_expiring)
            expiring_users = res_expiring.scalars().all()
            for user in expiring_users:
                warn_key = f"{user.id}_{user.streak_expires_at.isoformat()}"
                if warn_key not in _WARNED_STREAK_CACHE:
                    _WARNED_STREAK_CACHE.add(warn_key)
                    seconds_left = (user.streak_expires_at - now).total_seconds()
                    push_notification(
                        user_id=str(user.id),
                        notif_type="streak_expiring",
                        title="🔥 Mindful Streak Expiring Soon!",
                        body="Only a few hours remain to lock your daily streak. Watch your 30s reflection to keep top profile placement and protect your reveal token.",
                        data={
                            "action": "open_growth_hub",
                            "tab": "free_ads",
                            "hours_left": max(1, int(seconds_left / 3600)),
                            "streak_count": user.streak_count or 0
                        }
                    )
        except Exception as e:
            print(f"[STREAK BACKGROUND CHECK ERROR] {e}", flush=True)

        # 3. Anti-Ghosting: Mindful closure stale conversation evaluation pass
        try:
            from app.services.mindful_closure import MindfulClosureService
            await MindfulClosureService.evaluate_stale_conversations(db)
        except Exception as e:
            print(f"[MINDFUL CLOSURE STALE CHECK ERROR] {e}", flush=True)

        return count


    @staticmethod
    async def evaluate_and_decay_streak(user: User, db: AsyncSession) -> bool:
        """
        Evaluates streak expiry. If user missed the 24-hour window:
        - Streak count resets to 0
        - Boost points are penalized (-2)
        - 1 Reveal Token is deducted / incinerated
        - An in-app downgrade alert is pushed
        """
        now = datetime.now(timezone.utc)
        if not user.streak_expires_at:
            return False

        # Expiry Check
        if now > user.streak_expires_at:
            if (user.streak_count or 0) > 0:
                prev_streak = user.streak_count
                user.streak_count = 0
                user.boost_points = max(0, (user.boost_points or 0) - 2)
                user.reveal_tokens_count = max(0, (user.reveal_tokens_count or 0) - 1)
                user.streak_expires_at = None

                try:
                    await db.commit()
                    await db.refresh(user)
                    push_notification(
                        user_id=str(user.id),
                        notif_type="streak_broken",
                        title="🥀 Streak Broken & Profile Downgraded",
                        body=f"Your {prev_streak}-day sanctuary streak expired. Your profile discovery ranking was downgraded.",
                        data={
                            "action": "open_growth_hub",
                            "tab": "free_ads",
                            "streak_count": 0,
                            "boost_points": user.boost_points,
                            "reveal_tokens_count": user.reveal_tokens_count
                        }
                    )
                    print(f"[STREAK ENGINE] User {user.id} streak decayed. Token deducted.", flush=True)
                    return True
                except Exception as e:
                    await db.rollback()
                    print(f"[STREAK ENGINE ERROR] Decay commit failed: {e}", flush=True)
                    return False
        else:
            # Check T-4h warning threshold
            seconds_left = (user.streak_expires_at - now).total_seconds()
            if 0 < seconds_left <= 4 * 3600:
                # Proactive reminder
                push_notification(
                    user_id=str(user.id),
                    notif_type="streak_expiring",
                    title="🔥 Mindful Streak Expiring Soon!",
                    body="Only a few hours remain to lock your daily streak. Watch your 30s reflection to keep top profile placement and protect your reveal token.",
                    data={
                        "action": "open_growth_hub",
                        "tab": "free_ads",
                        "hours_left": max(1, int(seconds_left / 3600)),
                        "streak_count": user.streak_count or 0
                    }
                )

        return False

    @staticmethod
    async def claim_daily_streak_ad(user: User, db: AsyncSession) -> Dict[str, Any]:
        """
        Claims the daily 30-second rewarded sponsor ad.
        Increments streak, grants +1 Boost Point, and locks 24-hour protection timer.
        """
        now = datetime.now(timezone.utc)

        # Check if already completed recently (minimum 4h cooldown between new streak claims)
        if user.last_streak_ad_at:
            elapsed = (now - user.last_streak_ad_at).total_seconds()
            # If claimed less than 4 hours ago and streak is already active
            if elapsed < 4 * 3600 and user.streak_expires_at and user.streak_expires_at > now:
                return {
                    "status": "already_active",
                    "message": "Streak is currently secured. Next ritual unlocks shortly.",
                    "streak_count": user.streak_count or 1,
                    "boost_points": user.boost_points or 1,
                    "reveal_tokens_count": user.reveal_tokens_count if user.reveal_tokens_count is not None else 0,
                    "seconds_remaining": int((user.streak_expires_at - now).total_seconds()),
                    "streak_expires_at": user.streak_expires_at.isoformat()
                }

        # Increment streak & boost
        user.streak_count = (user.streak_count or 0) + 1
        user.boost_points = (user.boost_points or 0) + 1
        user.last_streak_ad_at = now
        user.streak_expires_at = now + timedelta(hours=24)

        try:
            db.add(user)
            await db.commit()
            await db.refresh(user)
        except Exception as e:
            await db.rollback()
            print(f"[STREAK ENGINE DB NOTICE] {e}", flush=True)

        push_notification(
            user_id=str(user.id),
            notif_type="streak_claimed",
            title=f"🔥 Day {user.streak_count} Streak Secured!",
            body=f"You earned +1 Boost Point! Your profile is prioritized at the top of the discovery deck for 24 hours.",
            data={
                "streak_count": user.streak_count,
                "boost_points": user.boost_points,
                "reveal_tokens_count": user.reveal_tokens_count if user.reveal_tokens_count is not None else 0
            }
        )

        return {
            "status": "success",
            "message": f"Day {user.streak_count} streak locked! +1 Boost Point credited.",
            "streak_count": user.streak_count,
            "boost_points": user.boost_points,
            "reveal_tokens_count": user.reveal_tokens_count if user.reveal_tokens_count is not None else 0,
            "seconds_remaining": 86400,
            "streak_expires_at": user.streak_expires_at.isoformat() if user.streak_expires_at else None
        }

    @staticmethod
    def get_user_streak_payload(user: User) -> Dict[str, Any]:
        """Calculates client-ready streak status & live countdown."""
        now = datetime.now(timezone.utc)
        streak_count = user.streak_count or 0
        boost_points = user.boost_points or 0
        tokens_count = user.reveal_tokens_count if user.reveal_tokens_count is not None else 0

        is_active = bool(user.streak_expires_at and user.streak_expires_at > now and streak_count > 0)
        seconds_remaining = 0
        if is_active and user.streak_expires_at:
            seconds_remaining = max(0, int((user.streak_expires_at - now).total_seconds()))

        # Discovery deck multiplier
        multiplier_percent = min(300, boost_points * 25)

        return {
            "streak_count": streak_count,
            "boost_points": boost_points,
            "reveal_tokens_count": tokens_count,
            "is_active": is_active,
            "seconds_remaining": seconds_remaining,
            "streak_expires_at": user.streak_expires_at.isoformat() if user.streak_expires_at else None,
            "last_streak_ad_at": user.last_streak_ad_at.isoformat() if user.last_streak_ad_at else None,
            "visibility_multiplier_label": f"+{multiplier_percent}% Discovery Priority",
            "can_claim_now": (not is_active) or (user.last_streak_ad_at and (now - user.last_streak_ad_at).total_seconds() >= 20 * 3600)
        }
