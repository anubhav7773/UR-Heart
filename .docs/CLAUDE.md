# Agent Guidelines & Development Standards

**Product Name:** Project RuralHeart  
**Document Version:** 2.0.0  
**Target Environment:** Flutter 3.x (Frontend) + FastAPI / Python 3.11 (Backend) + Supabase PostgreSQL (Database)  

---

## 1. Core Architecture & Stack Rules

1. **Backend (Python / FastAPI):**
   - Follow Modular Domain Architecture (`app/api/v1/`, `app/core/`, `app/models/`, `app/services/`).
   - Use Pydantic v2 for data validation and request/response models.
   - Use Async SQLAlchemy 2.0 for DB operations with GeoAlchemy2 for PostGIS queries.
   - **No Mock Implementations:** Always write production-ready code. Fallbacks must only trigger gracefully if third-party keys are missing in dev mode.

2. **Frontend (Flutter / Dart):**
   - State Management: Use Clean Architecture principles with Provider / Riverpod or BLoC.
   - UI Rules: Dark Theme First (`#121212` background, `#FF2D55` primary accent, `#2A2A2A` card backgrounds).
   - Responsive Layouts: Design for both standard mobile displays and web preview aspect ratios.

---

## 2. Feature Implementation Guidelines

### A. "Chai Date" & Today's Intent Engine
- Support real-time intent status updates (`free_for_chai`, `quick_snacks`, `study_partner`, `none`).
- Render a distinct **"☕ Free for Chai"** badge on discovery cards.
- Integrate ₹9 Sachet payment trigger for sending direct "Chai Invites".

### B. Safe WhatsApp Bridge (Message Counter Engine)
- Track mutual message count in `matches.mutual_message_count`.
- **Threshold Rule:** When mutual messages reach **15**, automatically flip `is_whatsapp_unlocked = TRUE`.
- Present a clean UI card in `ChatScreen` when unlocked, allowing users to exchange WhatsApp / Phone numbers safely.

### C. Persistent 20-Skip Ad Counter
- Track `persistent_skip_count` in both local storage (`shared_preferences` / `hive`) and synced back to user DB.
- On every 20th rejection (`action == 'reject'`), trigger AdMob Interstitial Video Ad and reset counter to 0.

### D. Sachet Micro-Transactions (Razorpay UPI)
- Support micro-plans:
  - `chai_invite_9` (₹9)
  - `profile_boost_19` (₹19)
  - `day_photo_pass_19` (₹19)
  - `monthly_premium_99` (₹99)
- Always verify Webhook signatures in backend before activating paid features.

---

## 3. Directory Structure Standards

```text
.
├── .docs/                   # Architecture, PRD, Schema & API Specs
├── backend/                 # FastAPI Backend
│   ├── app/
│   │   ├── api/v1/          # Endpoints (auth, feed, chat, intent, payments)
│   │   ├── core/            # Config, DB connection pool, security
│   │   ├── models/          # DB Models & Pydantic Schemas
│   │   └── services/        # Business Logic (Ad Engine, PostGIS Routing)
│   └── main.py
└── mobile_app/              # Flutter Cross-Platform Application
    ├── lib/
    │   ├── core/            # Theme, Ad Manager, Network Client
    │   ├── features/        # Feature Modules (auth, feed, chat, subscription)
    │   └── main.dart


 4. Coding Style Standards
Python: Strict PEP8 compliance, explicit type hints, concise logging.

Dart: Effective Dart guidelines, no hardcoded colors (use Theme.of(context) or centralized Constants), explicit null-safety handling.

Git Commits: Use Conventional Commits (feat:, fix:, refactor:, docs:).