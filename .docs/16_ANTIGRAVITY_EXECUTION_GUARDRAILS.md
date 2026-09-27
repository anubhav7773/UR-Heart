# 16_ANTIGRAVITY_EXECUTION_GUARDRAILS.md: MCP AGENT CODING STANDARDS & PROTOCOL
# Project: UR-Heart (Mindful Dating Sanctuary)
# Target Agent: Antigravity Full-Stack MCP Engine
# Core Objective: 0% Architectural Drift, Zero Spaghetti Code, 100% Free-Tier Stability

---

## 1. THE ANTIGRAVITY OPERATIONAL CONTRACT

Antigravity agent ka primary role autonomous code generator ka nahi, balki **deterministic architecture execution engine** ka hai. Pura project architecture `.docs/` folder (Docs 00 se 15) ke andar strictly freeze hai[cite: 1, 14]. Antigravity ko kisi bhi assumption ya speculative implementation ki permission nahi hai.

### 1.1 The Golden Execution Rule
IF an architectural question, data type, or design pattern arises:
Antigravity MUST cross-reference the corresponding .docs specification.
Antigravity MUST NEVER invent new patterns, unapproved packages, or ad-hoc DB tables.

### 1.2 Agent Role Distribution
* **Architect & Director (Gemini)**: End-to-end architecture design, security validation, and atomic prompt generation.
* **Mediator (You - The Founder)**: Prompts ko forward karna, execution status monitor karna, aur terminal outputs verify karna.
* **Executor (Antigravity MCP)**: Pure deterministic coding, file generation, linting checks, and unit tests execution.

---

## 2. THE 10 IMMUTABLE CODING COMMANDMENTS

Antigravity dwara generate kiye gaye har code file ko in 10 statutory rules ko qualify karna hoga:

### Rule 1: The 250-Line Hard Ceiling (Max 250 Lines per File)
* Koi bhi Flutter `.dart` file ya Python `.py` file **250 lines se badi nahi hogi**.
* Agar koi screen ya router 250 lines approach karta hai, to use immediately micro-components mein decompose karna mandatory hai:
  * Screens: Split into `presentation/screens/` and `presentation/widgets/`.
  * Business Logic: Extracted to `controllers/` or `services/`.
  * Routing: Sub-divided into domain endpoints (`endpoints/auth.py`, `endpoints/swipes.py`).

### Rule 2: Zero Hardcoded Constants (Magic Value Ban)
* **Colors**: Koi bhi inline `Color(0xFF...)` allowed nahi hai. Hamesha `DarkSanctuaryTokens` ya `LightSanctuaryTokens` se import honge[cite: 2, 15].
* **Strings & Copy**: Headings, disclaimers aur validation errors central string constants se derive honge.
* **Layout Spacing**: Padding aur Margins standard scale (`4.0`, `8.0`, `12.0`, `16.0`, `24.0`, `32.0`) se aayenge.
* **Ad Unit IDs & Keys**: Environment configurations (`.env` via `core/config.py` in FastAPI and String Environment declarations in Flutter) se derive honge.

### Rule 3: Clean Feature-First Architecture
* Har feature module apne self-contained directory ke andar exist karega:
  ```text
  features/<feature_name>/
  ├── data/           # Repositories, Data sources, DTOs
  ├── domain/         # Entities, Use cases, Failure models
  └── presentation/   # State Notifiers, Screens, Micro-Widgets
Cross-feature dependencies strictly prohibited hain. Shared logic core/ folder ke zariye share hogi.   
PDF

Rule 4: Zero Server-Side File Disk Buffering
FastAPI backend Render free tier par run hota hai jahan disk space ephemeral aur RAM sirf 512MB hai.   
PDF

Backend par open('temp.jpg', 'wb') ya local file buffering strictly prohibited hai. Media streaming direct RAM buffers (io.BytesIO) aur Cloudflare R2 presigned PUT URLs ke zariye stream hogi.   
PDF
+ 1

Rule 5: Non-Bypassable Row-Level Security (RLS)
Client-side Flutter app direct Supabase PostgREST endpoints call karte waqt hamesha authenticated user JWT claim supply karegi.   
PDF

Service role bypass key (SUPABASE_SERVICE_ROLE_KEY) sirf backend administrative endpoints (SSV callback, automated purge, KYC approval) ke liye reserved hai[cite: 1].

Rule 6: WhatsApp & Contact-Sharing Zero Tolerance
Chat UI (Screen 9) mein image attachment, voice notes, stickers ya location buttons add karna strictly ban hai.   
PNG
+ 1

Plaintext contact sharing (phones, handles, links) ko block karne ke liye client-side regex aur backend inspect_chat_message() gatekeeper hamesha synchronous check pass karenge[cite: 1].

Rule 7: Permanent Theme Lock Integrity
Install ke baad theme switch karne ka single chance sirf Screen 1 par allow hai.   
PNG
+ 2

Ek baar ur_heart_theme_locked = true set hone ke baad settings ya kisi bhi inner view mein theme switcher render nahi hoga.   
PNG
+ 1

Rule 8: 100% Anti-Ban Ad Compliance
Night Farmer / Slumber mode mein background infinite video looping implement karna strictly prohibited hai.   
PNG
+ 1

Impressions native/ambient frequency capped rahenge aur morning interactive gate ke zariye harvest honge.   
PNG
+ 1

Rule 9: Groq Multimodal Fallback Gate
Video KYC mein low-confidence matches par automatic direct failure emit nahi hoga; dossiers admin_kyc_escalations queue mein transition honge jo exclusively kshtriyaanubhav9120@gmail.com ke Settings panel se resolve honge.   
PNG

Rule 10: Strict Null-Safety & Type Safety
Flutter code mein dynamic type ya ! (force-unwrap) use karna prohibited hai.

Python code mein 100% functions type hints (typing module) aur Pydantic v2 validation contracts enforce karenge[cite: 1].

3. ATOMIC STEP-BY-STEP PROMPTING PROTOCOL
Spaghetti code aur agent confusion se bachne ke liye mediator (user) Antigravity ko ek samay par sirf ek atomic task dega.

3.1 Standard Prompt Template for Antigravity
Plaintext


[TASK DIRECTIVE]
Phase: <Phase Number>
Target Document Spec: <e.g., .docs/04_BACKEND_FASTAPI_ARCHITECTURE.md>
Action: <e.g., Implement app/api/v1/endpoints/swipes.py>

[CONSTRAINTS]
1. Maximum 250 lines of code.
2. Zero hardcoded colors or string literals.
3. Import dependencies strictly from core/ and schemas/.
4. Provide the complete code file without placeholders ("// TODO" or "...rest of code").

[VERIFICATION CRITERIA]
- File must pass linting without warnings.
- Endpoints must return Pydantic v2 schemas.
4. FLUTTER CODING STANDARDS & WIDGET DECOMPOSITION
4.1 Widget Hierarchy Decomposition Pattern
Kisi bhi complex screen ko single widget class mein nahi likhna hai. Structure 3 distinct layers mein divide hoga:

Plaintext


lib/features/feed/presentation/
├── screens/
│   └── feed_screen.dart             # Scaffold, Lifecycle, Top App Bar (<150 lines)[cite: 6]
├── controllers/
│   └── feed_controller.dart         # Riverpod AsyncNotifier State (<180 lines)
└── widgets/
    ├── sanctuary_card_deck.dart     # Swipeable stack container (<160 lines)[cite: 6]
    ├── candidate_photo_carousel.dart# Horizontal image pager (<140 lines)[cite: 6]
    ├── mindful_intent_quote.dart    # Editorial quote box (<90 lines)[cite: 6]
    └── feed_action_bar.dart         # Pass / Resonate / Like buttons (<120 lines)[cite: 6]
4.2 State Management Rules (Riverpod)
UI components strictly dumb presentation widgets honge jo ConsumerWidget ya ConsumerStatefulWidget extend karenge.

Business logic, network calls aur database access strictly StateNotifier ya AsyncNotifier ke andar encapsulate rahenge.

State updates immutable copyWith() methods ke through emit hongi.

5. FASTAPI BACKEND CODING STANDARDS
5.1 Endpoint Implementation Pattern
Har API router endpoint standard lifecycle follow karega:

Python


from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.api.dependencies import get_current_user[cite: 1]
from app.models.domain.user import User[cite: 1]
from app.schemas.swipe_schema import SwipeRequest, SwipeResponse
from app.services.swipe_service import execute_user_swipe[cite: 1]

router = APIRouter(prefix="/swipes", tags=["Swipes & Matching"])[cite: 1]

@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=SwipeResponse,
    summary="Record Swipe Action (Like, Pass, Superlike)"[cite: 1]
)
async def record_swipe_action(
    payload: SwipeRequest,
    current_user: User = Depends(get_current_user),[cite: 1]
    db: AsyncSession = Depends(get_db)
):
    """
    Validates swipe limits, checks remaining quota,[cite: 1]
    and triggers match creation if mutual like exists.[cite: 1]
    """
    return await execute_user_swipe(
        actor=current_user,
        target_id=payload.target_id,
        swipe_type=payload.swipe_type,[cite: 1]
        db=db
    )
6. ERROR HANDLING & BUG ISOLATION PROTOCOL
Jab Antigravity code execute kare aur compiler ya runtime error encounter ho, to agent ko ye 3-step isolation sequence follow karna hoga:

[Error Occurs / Build Fails]
              │
              ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STEP 1: ROOT CAUSE LOCALIZATION (Do NOT write hacky inline fixes)      │
│ - Trace exact file, line number, and exception stack trace             │
│ - Check if error violates .docs architecture boundaries                │
└─────────────────────┬──────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STEP 2: CONSULT THE SPECIFICATION LEDGER                               │
│ - For DB errors: Check 02_DATABASE_SCHEMA_OPTIMIZATION.md              │
│ - For RLS errors: Check 03_SUPABASE_RLS_SECURITY_POLICIES.md           │
│ - For Chat/NLP errors: Check 08_NLP_CHAT_SANITIZER.md                  │
│ - For Theme errors: Check 14_FLUTTER_DESIGN_SYSTEM_THEME_LOCK.md       │
└─────────────────────┬──────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STEP 3: CLEAN ARCHITECTURAL FIX & RETEST                               │
│ - Apply the fix at the root layer (Model, Repository, or Controller)   │
│ - Verify build passes cleanly without breaking adjacent files          │
└────────────────────────────────────────────────────────────────────────┘
7. PRE-COMMIT VALIDATION AUDIT CHECKLIST
Antigravity ko kisi bhi module ya phase ko "Complete" mark karne se pehle ye audit checklist verify karni hogi:

Audit Parameter	Verification Method	Status
Line Count Verification	Get-Content <file> | Measure-Object -Line must be $\l 250 lines	MANDATORY
Linting & Code Analysis	flutter analyze must report 0 issues	MANDATORY
Python Syntax & Typing	flake8 app/ and mypy app/ must pass cleanly	MANDATORY
Zero Hardcoded Secrets	Verify no raw API keys, passwords, or Supabase service keys in code	MANDATORY
Theme Lock Verification	Verify header pill displays lock modal before toggling theme	MANDATORY
Sentry Telemetry Shield	Verify PII redaction callback is active in SentryFlutter.init	MANDATORY
Keep-Alive Integrity	Verify /api/v1/health has 0 database connections	MANDATORY

