from typing import Tuple
from app.core.config import settings

AD_UNIT_INTERSTITIAL = "ca-app-pub-3940256099942544/1033173712"


class AdEngineService:
    """Service handling persistent skip counting, frequency caps, and ad injection triggers."""

    @staticmethod
    def process_skip_action(
        current_skip_count: int,
        is_premium: bool
    ) -> Tuple[int, bool, str | None]:
        """
        Process a swipe reject/skip action.

        Args:
            current_skip_count: User's stored persistent skip count.
            is_premium: Whether user has active ₹99 subscription.

        Returns:
            Tuple of (new_skip_count, trigger_interstitial_ad, ad_unit_id)
        """
        # Subscriber Bypass: Premium users never see interstitial skip ads
        if is_premium:
            return current_skip_count, False, None

        new_count = current_skip_count + 1

        if new_count >= settings.SKIP_INTERSTITIAL_THRESHOLD:
            # Reset counter upon reaching threshold and trigger ad
            return 0, True, AD_UNIT_INTERSTITIAL
        
        return new_count, False, None
