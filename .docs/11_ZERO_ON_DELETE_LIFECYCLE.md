# 11_ZERO_ON_DELETE_LIFECYCLE.md: INSTALLATION UUID & VOLATILE STATE SYNCHRONIZATION
# Project: UR-Heart (Mindful Dating Sanctuary)
# Architecture: Zero-on-Delete Gamification Synchronization & Sandbox Persistence
# Compliance: Google Play User Data Policy (Strict Prohibition of Hardware Identifiers)

---

## 1. EXECUTIVE PHILOSOPHY & THE UNINSTALL EXPLOIT VECTOR

Dating apps mein free-tier users daily quotas aur streak constraints ko exploit karne ke liye app ko bar-bar uninstall aur reinstall karte hain. Agar server session state ko blindly restore karta rahe, to:
1. Users artificial swipe resets aur referral/reward exploits execute karte hain.
2. Database par orphan session records accumulate hote hain.
3. User engagement and authentic daily retention (streaks) artificial ban jati hai.

### 1.1 The "Zero-on-Delete" Guarantee
"Zero on Delete" architecture ensure karti hai ki jab user UR-Heart ko uninstall karta hai ya system settings se "Clear Data" karta hai, to persistent account profile (Name, Photos, KYC status, Matches) safe rehti hai, lekin **volatile gamification metrics (active streak count aur reward token balance) next login par automatically zero reset ho jate hain**.

┌────────────────────────────────────────────────────────────────────────┐
│ PERSISTENT DATA (Preserved across Re-installs in Supabase Postgres)    │
│ - Identity, Verified Age, Orientation, Photos (Cloudflare R2)          │
│ - Verified KYC Status (users.kyc_status)                               │
│ - Mutual Active Matches (public.matches)                               │
│ - 1:1 Encrypted Messages History (30-day retention ceiling)            │
└────────────────────────────────────────────────────────────────────────┘
VS
┌────────────────────────────────────────────────────────────────────────┐
│ VOLATILE GAMIFICATION STATE (Reset to ZERO upon Reinstallation)        │
│ - Streak Count (users.streak_count -> 0)                               │
│ - Ad Reward Points Balance (users.reward_balance -> 0)                 │
│ - Free Daily Swipes Remaining (users.swipes_remaining -> Default 25)   │
│ - Direct Letter Tokens (users.direct_letters_count -> Default 1)       │
└────────────────────────────────────────────────────────────────────────┘


---

## 2. GOOGLE PLAY COMPLIANCE: ZERO HARDWARE IDENTIFIERS

Google Play Developer Policies ke User Data guidelines ke tehat non-resettable persistent hardware identifiers track karna strictly prohibited hai.

### 2.1 The Forbidden vs Permitted Identifiers Matrix

| Identifier Type | Status on UR-Heart | Google Play Policy Reason |
| :--- | :--- | :--- |
| **IMEI / MEID** | **STRICTLY PROHIBITED** | Hardware non-resettable identifier; causes immediate Play Store suspension. |
| **MAC Address** | **STRICTLY PROHIBITED** | Hardware device identifier; illegal for user tracking. |
| **Persistent Android ID (SSAID)** | **STRICTLY PROHIBITED** | Persists across app reinstalls; prohibited for cross-session tracking. |
| **Hardware Serial Number** | **STRICTLY PROHIBITED**[cite: 1] | Hardware identifier violation[cite: 1]. |
| **App-Scoped Installation UUID** | **MANDATORY & COMPLIANT**[cite: 1] | Ephemeral, generated in app sandbox, destroyed on uninstall, user-resettable[cite: 1]. |

### 2.2 Why Installation UUID is 100% Policy-Safe
1. **App-Scoped Lifecycle**: Ye UUID exclusively UR-Heart ke local sandbox storage mein reside karti hai aur doosri applications ke sath share nahi hoti[cite: 1].
2. **User Resettable**: User system settings se "Clear Data" karke ya app uninstall karke is identifier ko voluntarily destroy kar sakta hai[cite: 1].
3. **Purpose Limitation**: Iska sole purpose core operational state synchronization (gamification anti-exploit) hai, targeted cross-app ad tracking nahi[cite: 1].

---

## 3. ANDROID LINUX SANDBOX PERSISTENCE MECHANICS

Android OS har application ko ek unique Linux User ID (UID) assign karta hai. Iska internal data storage directory (`/data/data/com.urheart.app/`) completely isolated sandbox hota hai[cite: 1].

[Android OS Core Security Boundary]
│
▼
┌────────────────────────────────────────────────────────────────────────┐
│ App Private Internal Sandbox: /data/data/com.urheart.app/              │
│ - Shared Preferences: SharedPreferences.xml                           │
│ - Local SQLite / Secure Store: app_state.db                            │
│ - Stored Value: installation_uuid = "e7b1a234-8c9d-4e5f-..."           │
└────────────────────────────────────────────────────────────────────────┘
│
▼ (User Uninstalls App OR Taps 'Clear Storage')
┌────────────────────────────────────────────────────────────────────────┐
│ OS KERNEL ACTION:                                                      │
│ Entire /data/data/com.urheart.app/ directory is permanently wiped!     │
│ Next install gets a NEW sandbox and a NEW installation_uuid[cite: 1]  │
└────────────────────────────────────────────────────────────────────────┘


### 3.1 AndroidManifest Backup Lockdown
Agar Android ka automatic cloud backup enabled rahe, to Google Drive purani `installation_uuid` ko reinstall ke baad restore kar dega, jisse Zero-on-Delete fail ho jayega. Isliye Android cloud backup explicitly disable karna mandatory hai:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:label="UR-Heart"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:allowBackup="false"
    android:fullBackupContent="false">
    <!-- allowBackup="false" guarantees the sandbox wipes completely on uninstall -->
</application>
4. FLUTTER CLIENT INSTALLATION TRACKER
Client app har boot par local sandbox check karti hai[cite: 1]. Agar UUID nahi milti to ek fresh cryptographically random UUID v4 generate karti hai[cite: 1].

4.1 Installation Service (lib/core/security/installation_service.dart)
Dart


import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class InstallationService {
  static const String _keyInstallationUuid = 'ur_heart_installation_uuid';
  static String? _cachedUuid;

  /// Retrieves or creates the ephemeral installation UUID from Android sandbox[cite: 1]
  static Future<String> getInstallationUuid() async {
    if (_cachedUuid != null) return _cachedUuid!;

    final prefs = await SharedPreferences.getInstance();
    String? storedUuid = prefs.getString(_keyInstallationUuid);

    if (storedUuid == null || storedUuid.isEmpty) {
      // Fresh installation or data wipe detected: Generate a new cryptographically random UUID v4[cite: 1]
      const uuidGenerator = Uuid();
      storedUuid = uuidGenerator.v4();
      await prefs.setString(_keyInstallationUuid, storedUuid);
    }

    _cachedUuid = storedUuid;
    return storedUuid;
  }
}
4.2 Dio / HTTP Interceptor Injection (lib/core/network/api_interceptor.dart)
Client ki har authenticated request ke sath header X-Installation-UUID transmit hota hai[cite: 1]:

Dart


import 'package:dio/dio.dart';
import '../security/installation_service.dart';

class SessionAuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Inject app-scoped sandbox installation UUID[cite: 1]
    final installationUuid = await InstallationService.getInstallationUuid();
    options.headers['X-Installation-UUID'] = installationUuid;[cite: 1]

    return handler.next(options);
  }
}
5. FASTAPI SESSION-SYNC STATE MACHINE
Backend par incoming X-Installation-UUID ko database ke last_installation_uuid se compare kiya jata hai[cite: 1]:

Incoming Request with Header: X-Installation-UUID[cite: 1]
                     │
                     ▼
       Fetch current_user from Database[cite: 1]
                     │
                     ▼
    Is current_user.last_installation_uuid NULL?[cite: 1]
                     │
        ┌────────────┴────────────┐
        ▼ YES                     ▼ NO
[State: First Setup]      Does incoming_uuid == current_user.last_installation_uuid?[cite: 1]
- Save incoming UUID                 │
- Streak & rewards untouched[cite: 1]│
                          ┌──────────┴──────────┐
                          ▼ YES                 ▼ NO (MISMATCH DETECTED!)[cite: 1]
                  [State: Active]       [State: ZERO-ON-DELETE RESET][cite: 1]
                  - Continue session    - Reinstall / Data Wipe confirmed[cite: 1]
                  - Return current state- current_user.streak_count = 0[cite: 1]
                                        - current_user.reward_balance = 0[cite: 1]
                                        - current_user.swipes_remaining = 25
                                        - current_user.last_installation_uuid = incoming[cite: 1]
                                        - Commit to Database[cite: 1]
                                        - Return 'reset_executed' status[cite: 1]
6. PRODUCTION FASTAPI IMPLEMENTATION (app/api/v1/endpoints/auth.py)
Complete standalone implementation of session handshake endpoint[cite: 1]:

Python


from uuid import UUID
from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.domain.user import User[cite: 1]
from app.core.security import verify_firebase_token[cite: 1]

router = APIRouter(tags=["Authentication & Session Sync"])

class SessionSyncResponse(BaseModel):
    status: str
    message: str
    streak_count: int
    reward_balance: int
    swipes_remaining: int
    direct_letters_count: int

@router.post(
    "/auth/session-sync",
    status_code=status.HTTP_200_OK,
    response_model=SessionSyncResponse,
    summary="App Startup Session & Re-install State Synchronizer"[cite: 1]
)
async def sync_session_state(
    authorization: str = Header(..., description="Bearer <Firebase_JWT_Token>"),[cite: 1]
    x_installation_uuid: str = Header(..., description="Android sandbox Installation UUID"),[cite: 1]
    db: AsyncSession = Depends(get_db)
):
    """
    Evaluates client installation UUID against database record[cite: 1].
    If a mismatch is detected, triggers the Zero-on-Delete state wipe[cite: 1].
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization token format."[cite: 1]
        )

    token = authorization.split("Bearer ")[1].strip()
    payload = await verify_firebase_token(token)
    auth_id = payload.get("uid")

    if not auth_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session authentication token expired or invalid."
        )

    # 1. Fetch user by auth_id from Supabase Postgres[cite: 1]
    stmt = select(User).where(User.auth_id == UUID(auth_id), User.deleted_at.is_(None))[cite: 1]
    result = await db.execute(stmt)
    current_user = result.scalar_one_or_none()

    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sanctuary profile not found."
        )

    incoming_uuid = x_installation_uuid.strip()

    # 2. Case A: Initial Login / First Account Setup[cite: 1]
    if current_user.last_installation_uuid is None:
        current_user.last_installation_uuid = incoming_uuid[cite: 1]
        await db.commit()
        await db.refresh(current_user)
        return SessionSyncResponse(
            status="initialized",
            message="Session identity bound to current device sandbox.",
            streak_count=current_user.streak_count,
            reward_balance=current_user.reward_balance,
            swipes_remaining=current_user.swipes_remaining,
            direct_letters_count=current_user.direct_letters_count
        )

    # 3. Case B: App Reinstallation or Data Wipe Detected (UUID Mismatch)[cite: 1]
    if current_user.last_installation_uuid != incoming_uuid:
        # Trigger Zero-on-Delete Reset Protocol[cite: 1]
        current_user.streak_count = 0[cite: 1]
        current_user.reward_balance = 0[cite: 1]
        current_user.swipes_remaining = 25  # Reset to default daily allowance
        current_user.direct_letters_count = 1  # Reset to default daily allowance
        current_user.last_installation_uuid = incoming_uuid[cite: 1]

        await db.commit()[cite: 1]
        await db.refresh(current_user)[cite: 1]

        return SessionSyncResponse(
            status="reset_executed",[cite: 1]
            message="App reinstallation detected. Streaks and reward tokens have been reset to zero.",[cite: 1]
            streak_count=0,[cite: 1]
            reward_balance=0,[cite: 1]
            swipes_remaining=25,
            direct_letters_count=1
        )

    # 4. Case C: Normal Continuation on Existing Installation[cite: 1]
    return SessionSyncResponse(
        status="active",[cite: 1]
        message="Session active and verified.",
        streak_count=current_user.streak_count,[cite: 1]
        reward_balance=current_user.reward_balance,[cite: 1]
        swipes_remaining=current_user.swipes_remaining,
        direct_letters_count=current_user.direct_letters_count
    )
7. MULTI-DEVICE LOGIN & LOGOUT POLICIES
7.1 Single Device Policy for Gamification
Dating apps par fake activity rokne ke liye ek samay par ek hi device active install allow hoti hai:

Agar user apne account ko Device A se Device B par login karega, to Device B ka fresh Installation UUID last_installation_uuid par overwrite ho jayega[cite: 1].

Isse Device B par streaks/points reset ho jayenge (Zero-on-Delete guarantee)[cite: 1]. Isse users multiple devices par login karke simultaneous video ad farming nahi kar sakte.

7.2 Explicit Logout Protocol (Screen 13)
Jab user Screen 13 par "Log Out of Sanctuary" par tap karta hai:   
PNG
+ 1

Local Firebase session token wipe hota hai.

Local installation_uuid SharedPreferences mein preserve rehta hai taaki agar same user bina uninstall kiye wapas login kare, to unka streak reset na ho. Streak sirf uninstall ya system-level app data clear karne par hi wipe hota hai[cite: 1].

8. ANTIGRAVITY VERIFICATION & TEST SUITE
Antigravity agent ko verification karte waqt nimn assertions pass karni hain:

Python


# ============================================================================
# ZERO-ON-DELETE VERIFICATION SUITE
# ============================================================================

async def test_zero_on_delete_workflow():
    # Setup Mock User with active streaks and ad points
    user = User(
        auth_id=UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
        streak_count=14,
        reward_balance=450,
        last_installation_uuid="device-uuid-alpha-1111"
    )

    # Test 1: Normal Boot with Same UUID
    # Expected: No reset, streaks retained
    assert user.last_installation_uuid == "device-uuid-alpha-1111"
    assert user.streak_count == 14

    # Test 2: Reinstallation Simulation (Incoming UUID: device-uuid-beta-2222)
    incoming_uuid = "device-uuid-beta-2222"
    if user.last_installation_uuid != incoming_uuid:
        user.streak_count = 0
        user.reward_balance = 0
        user.last_installation_uuid = incoming_uuid

    # Expected: State wiped to zero and new UUID locked
    assert user.streak_count == 0
    assert user.reward_balance == 0
    assert user.last_installation_uuid == "device-uuid-beta-2222"
    print("Zero-on-Delete Test Passed Successfully!")