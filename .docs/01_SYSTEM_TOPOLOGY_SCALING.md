# 01_SYSTEM_TOPOLOGY_SCALING.md: DISTRIBUTED TOPOLOGY & ZERO-COST SCALING
# Project: UR-Heart (Mindful Dating Platform)
# Target Architecture: 100% Free-Tier Infrastructure Scalable to 1,000,000 MAU

---

## 1. END-TO-END SYSTEM TOPOLOGY & DATA FLOW

UR-Heart ka architecture distributed, stateless aur asymmetric hai. Heavy compute operations (media encoding, blurhash generation, cryptographic key generation) client device par offload hoti hain, jabki backend (FastAPI) strictly lightweight orchestration, security enforcement aur state machine transition ko handle karta hai.

### 1.1 Architectural Topology Diagram

                          ┌────────────────────────────────────────┐
                          │           FLUTTER CLIENT APP           │
                          │  - Riverpod State Architecture         │
                          │  - Sentry SDK (Error Telemetry)        │
                          │  - Google Mobile Ads + InMobi SDK      │
                          │  - WebP Compressor (<100KB) + BlurHash │
                          └──────────────────┬─────────────────────┘
                                             │
                 ┌───────────────────────────┼───────────────────────────┐
                 │ HTTPS / WSS (TLS 1.3)     │ Direct Media Upload       │ Push & Auth
                 ▼                           ▼                           ▼
    ┌─────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐
    │  RENDER WEB SERVICE     │ │    CLOUDFLARE R2        │ │    FIREBASE CLOUD       │
    │  (FastAPI Async Core)   │ │  (Media Object Storage) │ │  - Firebase Auth        │
    │  - Render Free Tier     │ │  - 10GB Zero-Egress     │ │  - FCM Notifications   │
    │  - Stateless ASGI       │ │  - Direct PUT S3 API    │ └─────────────────────────┘
    └────────────┬────────────┘ └─────────────────────────┘
                 │
     ┌───────────┼───────────────────────────┐
     │           │                           │
     ▼           ▼                           ▼
┌──────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐
│ SUPABASE PGBOUNCER│ │      GROQ CLOUD API     │ │ ADMOB SSV CALLBACKS     │
│ (Port 6543 Pool) │ │ (Llama-3 Multimodal)    │ │ - Google AdMob ECDSA    │
│ - PostgreSQL 15  │ │ - 3s Live Video KYC     │ │ - InMobi / AppLovin S2S │
│ - 500MB Ceil RLS │ │ - Liveness & Age Audit  │ └─────────────────────────┘
└──────────────────┘ └─────────────────────────┘
▲
│ Every 5 Minutes (HTTP GET)
┌──────────────────┐
│   UPTIMEROBOT    │
│ (Keep-Alive Bot) │
└──────────────────┘


---

## 2. RENDER FREE-TIER SLEEPLESS ENGINE (UPTIMEROBOT 24/7 ARCHITECTURE)

Render free tier web services 15 minutes ki inbound HTTP inactivity ke baad container ko automatically spin down (sleep mode) kar deti hain. Sleep hone ke baad aane wali pehli request ko container wake up karne mein **50 se 70 seconds ka cold-start delay** lagta hai, jo dating app ke real-time matching aur chat experience ko completely tod deta hai.

Is problem ko 100% zero-cost par solve karne ke liye **UptimeRobot HTTP Keep-Alive Strategy** implement ki gayi hai.

### 2.1 Keep-Alive Operational Specs

1. **Ping Source**: UptimeRobot (Free Monitoring Tier - 50 monitors, 5-minute check intervals).
2. **Ping Target**: `https://<ur-heart-api>.onrender.com/api/v1/health`
3. **HTTP Method**: `GET`
4. **Execution Frequency**: Exactly har 5 minutes (300 seconds).
5. **Payload Optimization**: Zero Database Querying. Health endpoint database ko ping nahi karega taaki Supabase ke connection pool aur compute hours waste na hon. Ye sirf ASGI event loop ki liveness check karega.

### 2.2 Production FastAPI Health Check Endpoint (`app/api/v1/endpoints/health.py`)

```python
import os
import time
from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter(tags=["System Health"])

START_TIME = time.time()

class HealthResponse(BaseModel):
    status: str
    uptime_seconds: float
    environment: str
    engine: str

@router.get(
    "/api/v1/health",
    status_code=status.HTTP_200_OK,
    response_model=HealthResponse,
    summary="Stateless Keep-Alive Ping Endpoint"
)
async def health_check():
    """
    Zero-allocation endpoint dedicated to external keep-alive bots (UptimeRobot).
    Bypasses database connections to prevent Supabase connection exhaustion.
    """
    return HealthResponse(
        status="active",
        uptime_seconds=round(time.time() - START_TIME, 2),
        environment=os.getenv("ENVIRONMENT", "production"),
        engine="FastAPI-Async-Sleepless"
    )
2.3 UptimeRobot Setup Blueprint
Monitor Type: HTTP(s)

Friendly Name: UR-Heart Render Backend Keep-Alive

URL (or IP): https://<YOUR-RENDER-SUBDOMAIN>.onrender.com/api/v1/health

Monitoring Interval: Every 5 minutes

Monitor Timeout: 30 seconds

HTTP Method: GET

Accepted HTTP Status Codes: 200

3. 1M MAU HORIZONTAL SCALING STRATEGY (STATELESS ARCHITECTURE)
1,000,000 Monthly Active Users (MAU) ko free aur low-cost tier par support karne ke liye backend server ko 100% Stateless hona padega.

       Stateless Rule: Server RAM mein 0% user state ya active session data store hoga.
3.1 Core Principles of Stateless Scaling
JWT & App-Scoped Installation UUID Authentication:

Har request Firebase Auth ID token ya internal signed JWT ke saath aayegi. Server session memory mein hold nahi karta; token dynamically verify hota hai.

Device reinstallation aur state tracking ke liye header X-Installation-UUID verify kiya jayega, jo local Linux app sandbox se originate hota hai.   
PDF

Memory-Isolated WebSocket Pool:

FastAPI WebSocket connections memory leak ka sabse bada source hote hain.

ConnectionManager sirf active memory socket pointers Dict[UUID, WebSocket] rakhega. User metadata, profile details, ya message queues memory mein nahi rahenge.   
PDF
+ 1

Offline user ko message bhejne par WebSocket pipeline immediately fail-over karke Firebase Cloud Messaging (FCM) push trigger karegi.

Background Media Bypass:

Backend media processing (uploading, resizing, cropping) nahi karega. Server ka CPU 100% compute free rahega kyunki image files seedhe Flutter client se Cloudflare R2 bucket mein jayengi.   
PDF
+ 1

4. SUPABASE CONNECTION POOLING (PGBOUNCER ARCHITECTURE)
PostgreSQL process-based database hai. Har direct connection 2MB se 10MB memory consume karta hai. Supabase Free Tier par direct PostgreSQL connections ki limit 60 connections ke aas-paas hoti hai. Agar 10,000 users ek sath app open karenge, to direct database connection immediately crash ho jayega (FATAL: remaining connection slots are reserved).

Is problem se bachne ke liye UR-Heart PgBouncer Transaction Pooling mode use karega.

4.1 Connection Modes Comparison
Parameter	Direct Connection (Port 5432)	PgBouncer Pooler (Port 6543)
Protocol	Direct TCP PostgreSQL	Transaction-Level Connection Pooler
Max Concurrency	~60 active sessions (CRITICAL RISK)	Up to 10,000 client transactions
Memory Footprint	Heavy (Process per connection)	Ultra-light (Reuses idle connections)
Prepared Statements	Supported	Supported via prepare_threshold=0
UR-Heart Policy	STRICTLY PROHIBITED	MANDATORY IN ALL REPOSITORIES

4.2 SQLAlchemy Async Connection Engine Configuration (app/core/database.py)
Antigravity ko connection pool configuration mein ye settings enforce karni hain:

Python


import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool

# IMPORTANT: Port 6543 (PgBouncer Transaction Pooler) must be used.
# URL format: postgresql+asyncpg://postgres.[ref]:[password]@aws-0-[region][.pooler.supabase.com:6543/postgres](https://.pooler.supabase.com:6543/postgres)
DATABASE_URL = os.getenv("SUPABASE_PGBOUNCER_URL")

# For transaction pooling via PgBouncer with asyncpg:
# NullPool is recommended when connecting to PgBouncer in transaction mode
# to prevent local client-side poolers from clashing with server-side PgBouncer.
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    poolclass=NullPool,
    connect_args={
        "prepared_statement_cache_size": 0,
        "statement_cache_size": 0,
        "command_timeout": 15,
        "server_settings": {
            "application_name": "ur_heart_fastapi_backend"
        }
    }
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def get_db():
    """FastAPI Dependency for database session execution."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
5. ZERO-COST CDN & MEDIA EGRESS STRATEGY (CLOUDFLARE R2)
AWS S3 par data egress (download bandwidth) ke liye $0.09 per GB charge lagta hai, jo 1M users par thousand dollars ka bill generate kar sakta hai.
UR-Heart Cloudflare R2 use karega:

Storage Limit: 10 GB free permanently.

Egress Bandwidth Fees: $0.00 (Zero Egress Fees) globally.   
PDF

Class A Operations (Uploads/Writes): 1,000,000 calls/month free.   
PDF

Class B Operations (Reads): 10,000,000 calls/month free.

5.1 Storage Lifecycle Rules & Directory Tree
Plaintext


ur-heart-media/
├── users/
│   └── {user_id}/
│       ├── photos/
│       │   ├── slot_1.webp    # Overwritten in-place, Max 100KB
│       │   ├── slot_2.webp
│       │   ├── slot_3.webp
│       │   ├── slot_4.webp
│       │   └── slot_5.webp
│       └── kyc/
│           └── video.mp4      # Auto-expires via Lifecycle Rule in 24 Hours
5.2 R2 Object Lifecycle Configuration
DPDP Act 2023 compliance aur 10GB storage limit protect karne ke liye Cloudflare R2 bucket par Object Lifecycle Rule configure hoga:

Rule Name: Auto-Purge KYC Videos

Filter Prefix: users/*/kyc/

Action: Delete objects permanently after 1 day (24 hours) from creation.   
PDF

6. GROQ CLOUD AI KYC INTEGRATION TOPOLOGY
Profile authenticity confirm karne aur minors/fake profiles ko prevent karne ke liye 3-second live video KYC process Groq Cloud infrastructure par run hoga.   
PDF
+ 1

[Flutter Camera] 
       │ Record 3s Video (<2MB)
       ▼
[FastAPI Backend Proxy] (RAM-Only Stream)
       │ Extract 3 representative frames (0s, 1.5s, 3.0s)
       ▼
[Groq Cloud Vision API] (Llama-3 Multimodal Engine)
       │ Evaluate: (1) Liveness/Blink, (2) Neutral Age > 18, (3) Face Match with Slot 1
       ▼
[Supabase users.kyc_status] -> Set TRUE (or REJECT & Purge)
Transient Compute: Video frames server disk par persist nahi hote. Unhe RAM buffer mein read kiya jata hai aur verification complete hote hi garbage collection unhe wipe kar deti hai[cite: 1].

Groq Speed Advantage: Groq LPUs (Language Processing Units) sub-500ms inference time deliver karte hain, jisse user ko verification ke liye lambe queues mein wait nahi karna padta.

7. CRASH TELEMETRY & OBSERVABILITY (SENTRY FREE TIER)
Flutter application par zero-cost crash reporting ke liye Sentry Developer Free Tier integrate kiya gaya hai (5,000 free crash events/month).

7.1 Sentry Configuration Parameters
Client SDK: sentry_flutter: ^8.0.0

Performance Tracing Sampling: Set strictly to tracesSampleRate = 0.1 (10% sampling) taaki free tier event limits exhaust na hon.

PII Redaction (Mandatory for DPDP Act 2023): User phone numbers, passwords, coordinates, aur message contents Sentry logs mein transmit hone se pehle beforeSend callback ke through scrub kiye jate hain.

7.2 Flutter Sentry Bootstrap Code (lib/main.dart)
Dart


import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/app/ur_heart_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 0.1; // Conserves free tier quota
      options.sendDefaultPii = false; // DPDP Compliance: Strips personal data
      options.attachScreenshot = false; // FLAG_SECURE & Privacy Protection
      options.beforeSend = (event, hint) {
        // Strip out email or sensitive form params from error reports
        if (event.request?.data != null) {
          event.request?.data = '[REDACTED_BY_DPDP_POLICY]';
        }
        return event;
      };
    },
    appRunner: () => runApp(const URHeartApp()),
  );
}
8. SYSTEM FAILURE & RECOVERY RESILIENCE MATRIX
Component	Failure Mode	Impact	Automatic Recovery Mechanism
Render API	Dyno cold sleep (if ping fails)	50s latency on next request	UptimeRobot redundant 5-min ping + Flutter client 60s timeout with retry indicator.
Supabase DB	PgBouncer max client pool limit hit	HTTP 500 DB error	NullPool in SQLAlchemy async engine automatically closes idle sockets immediately.
Cloudflare R2	Network timeout during photo upload	Photo slot fails to save	Flutter client initiates exponential backoff (retry after 2s, 4s, 8s).
WebSocket	Network handover / connection drop	Chat appears disconnected	
Flutter client automatically reconnects with exponential backoff on app lifecycle resume[cite: 1].

Ad Networks	"Ad not available" in regional area	User cannot unlock feature	
Fallback Waterfall: AdMob -> InMobi -> Meta -> Unity -> AppLovin ensures 99%+ fill[cite: 1].

Groq AI	API Rate Limit (429 Too Many Requests)	KYC pending state	Async background queue retries after 60s; profile marked kyc_status = pending.
