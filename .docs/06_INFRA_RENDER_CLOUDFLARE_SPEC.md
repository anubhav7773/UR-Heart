# Infrastructure, Deployment (Render) & Zero-Card Media Storage Specification

**Document Identifier:** URH-INF-006  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Backend Hosting Platform:** Render.com (Web Service — Free Tier)  
**Media Storage Engine:** Supabase Storage (1 GB Free Tier via MCP — Zero Card Required)  
**Authentication & Backup Bucket:** Firebase Spark Free Tier (5 GB Storage — Zero Card Required)  
**Target Monthly Infra Cost:** $0.00 / month

---

## 1. Zero-Card Cloud Architecture Overview

Because neither Cloudflare R2 nor Google Cloud Blaze are viable without credit/debit card verification, the entire storage and hosting pipeline is engineered around verified **Card-Free Services**:

[Flutter Client]│├── 1. Auth via Firebase (Google Sign-In / Email) -> Free Spark Tier (No Card)│├── 2. Compress Photo to WebP (<100KB) + Calc BlurHash│├── 3. GET /api/v1/storage/upload-ticket -> [FastAPI on Render Free Tier]│                                                 ││                                         (Tesseract OCR + QR Check)│                                                 │├── 4. Direct Upload WebP Binary ─────────────────┼──► [Supabase Storage: user-photos]│                                                 │     (1 GB Free - via MCP)│                                                 ▼└── 5. Sync Session & DDL Mutations ────────► [Supabase PostgreSQL DB](500 MB Free - via MCP)
---

## 2. Render.com Free Tier Constraints & Engineering Defenses

Render’s free tier provides a container with **512 MB RAM and 0.1 CPU core**. If memory consumption exceeds 512 MB, Render kills the process with `OOM (Out Of Memory) Error 137`. Furthermore, free containers sleep after 15 minutes of inactivity.

### 2.1. Memory Optimization Defenses (Staying Under 512 MB)
1. **Headless OpenCV:** Use `opencv-python-headless` instead of the full GUI build, saving ~120 MB RAM.
2. **Tesseract Slim Engine (`tessdata_fast`):** Install only the neural-net fast models (`tesseract-ocr`, `tesseract-ocr-hin`) with `--oem 1` to reduce memory consumption during OCR scans to $< 60$ MB.
3. **Single Worker Uvicorn:** Run Uvicorn with a single async worker (`--workers 1 --loop uvloop`). Concurrency is handled by Python’s async event loop rather than multi-process forks.
4. **Client-Side Offload:** Image re-encoding (WebP) and BlurHash calculations are executed strictly on the user's mobile device, transmitting $< 100$ KB files to the server.

### 2.2. Spin-Down Defense (Keep-Alive Strategy)
- Free containers take 30–50 seconds to boot on cold start.
- **Client Fallback UX:** The Flutter app splash screen checks `/api/v1/health`. If a timeout occurs, it displays a friendly vernacular loader: *"UR-Heart surakshit server se connect ho raha hai (Connecting to secure server...)"*.
- **Keep-Alive Cron:** A lightweight Supabase Edge Function or GitHub Actions workflow pings `GET /api/v1/health` every 14 minutes during peak regional hours (6:00 PM to 12:00 AM IST) to prevent cold starts during peak dating traffic.

---

## 3. Production Dockerfile for Render

The backend requires system-level C++ binaries for OCR (`tesseract`) and Barcode parsing (`libzbar`). Deploy via Docker on Render:

```dockerfile
# ==============================================================================
# UR-HEART FASTAPI BACKEND - PRODUCTION DOCKERFILE
# Base: Debian-slim with Python 3.11
# ==============================================================================
FROM python:3.11-slim as base

# 1. Prevent Python from writing .pyc files and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PORT=8000 \
    OMP_THREAD_LIMIT=1 \
    TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/tessdata

WORKDIR /app

# 2. Install minimal system binaries for OCR, QR detection, and network security
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-hin \
    libgl1 \
    libzbar0 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Python production dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 4. Copy application source code
COPY app/ ./app/

# 5. Create a non-privileged system user for container security
RUN useradd -m -u 1001 urheart_user && \
    chown -R urheart_user:urheart_user /app
USER urheart_user

# 6. Expose default port
EXPOSE 8000

# 7. Health check instruction for container management
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/v1/health || exit 1

# 8. Start Uvicorn with single worker to preserve 512MB free tier RAM
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1 --timeout-keep-alive 65
4. Render Infrastructure-as-Code: render.yamlSave this file in the root of your project. It configures the Web Service automatically inside Render:YAMLservices:
  - type: web
    name: ur-heart-api
    env: docker
    plan: free
    region: singapore # Closest low-latency region for Indian users
    dockerfilePath: Dockerfile
    healthCheckPath: /api/v1/health
    autoDeploy: true
    envVars:
      - key: ENVIRONMENT
        value: production
      - key: SUPABASE_URL
        sync: false
      - key: SUPABASE_SERVICE_ROLE_KEY
        sync: false
      - key: FIREBASE_PROJECT_ID
        sync: false
      - key: FIREBASE_CLIENT_EMAIL
        sync: false
      - key: FIREBASE_PRIVATE_KEY
        sync: false
      - key: ADMOB_APP_ID
        sync: false
      - key: APPLOVIN_SDK_KEY
        sync: false
      - key: CORS_ALLOWED_ORIGINS
        value: "[https://asiverticals.com](https://asiverticals.com),http://localhost:3000"
5. Python Production Requirements: requirements.txtPlaintextfastapi==0.110.0
uvicorn[standard]==0.28.0
pydantic==2.6.4
pydantic-settings==2.2.1
sqlalchemy==2.0.28
asyncpg==0.29.0
httpx==0.27.0
pytesseract==0.3.10
opencv-python-headless==4.9.0.80
pyzbar==0.1.9
numpy==1.26.4
cryptography==42.0.5
supabase==2.4.0
firebase-admin==6.5.0
python-multipart==0.0.9
6. Supabase Storage Bucket Setup & Security PoliciesExecute this SQL via the Supabase MCP or SQL Editor to create the zero-cost storage buckets and configure bucket-level access control:SQL-- =============================================================================
-- SUPABASE STORAGE CONFIGURATION FOR UR-HEART
-- =============================================================================

-- 1. Insert Storage Buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('user-photos', 'user-photos', TRUE, 150000, ARRAY['image/webp']), -- 150KB limit per photo
    ('kyc-temp', 'kyc-temp', FALSE, 2500000, ARRAY['video/mp4'])       -- 2.5MB limit per video
ON CONFLICT (id) DO NOTHING;

-- 2. Storage Policies for user-photos (Public Read, Owner Upload)
CREATE POLICY "Public profiles can view photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'user-photos');

CREATE POLICY "Authenticated users can upload own photo slots"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-photos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update and replace own photo slots"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'user-photos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete own photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'user-photos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. Storage Policies for kyc-temp (Strictly Private - Service Role only)
CREATE POLICY "Users can upload their KYC video"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'kyc-temp' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Deny public reading of KYC videos under all circumstances
CREATE POLICY "Deny public access to KYC videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id != 'kyc-temp');
7. Storage Service Implementation: app/services/storage_service.pyThis service manages presigned upload URLs and coordinates the hard-deletion cascade when a user executes a data purge:Pythonimport os
from uuid import UUID
from fastapi import HTTPException, status
from supabase import create_client, Client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")

supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

async def create_signed_upload_url(user_id: UUID, slot_index: int) -> dict:
    """
    Generates a secure, 10-minute upload URL for the user's specific photo slot.
    Format: user-photos/{user_id}/slot_{slot_index}.webp
    """
    file_path = f"{user_id}/slot_{slot_index}.webp"
    try:
        res = supabase_admin.storage.from_("user-photos").create_signed_upload_url(file_path)
        return {
            "upload_url": res.get("signedUrl") or res.get("url"),
            "file_path": file_path,
            "bucket": "user-photos"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Storage upload ticket generation failed: {str(e)}"
        )

async def purge_user_storage_assets(user_id: UUID) -> None:
    """
    Hard-deletes all photos and temporary KYC videos associated with user_id.
    Used for Account Deletion and One-Tap Data Purge.
    """
    # 1. List and remove all files in user's photo directory
    try:
        photo_files = supabase_admin.storage.from_("user-photos").list(path=str(user_id))
        if photo_files:
            file_keys = [f"{user_id}/{f['name']}" for f in photo_files]
            supabase_admin.storage.from_("user-photos").remove(file_keys)
    except Exception as e:
        # Continue execution to prevent partial deletion failure
        pass

    # 2. List and remove any lingering KYC files
    try:
        kyc_files = supabase_admin.storage.from_("kyc-temp").list(path=str(user_id))
        if kyc_files:
            kyc_keys = [f"{user_id}/{f['name']}" for f in kyc_files]
            supabase_admin.storage.from_("kyc-temp").remove(kyc_keys)
    except Exception:
        pass
8. Health Check & Diagnostics Endpoint: app/api/v1/endpoints/health.pyThis endpoint satisfies Render's health-check probe and provides memory diagnostic monitoring:Pythonimport os
import psutil
from datetime import datetime
from fastapi import APIRouter, status
from sqlalchemy import text
from app.core.database import async_session_factory

router = APIRouter()

@router.get("/api/v1/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    Monitors process memory and database connectivity to guarantee 
    the container remains safely below the 512MB Render RAM ceiling.
    """
    # Check RAM usage
    process = psutil.Process(os.getpid())
    memory_mb = process.memory_info().rss / (1024 * 1024)

    # Verify Database Connectivity
    db_status = "healthy"
    try:
        async with async_session_factory() as session:
            await session.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return {
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat(),
        "app_name": "UR-Heart",
        "parent_entity": "ASI Verticals",
        "database": db_status,
        "memory_consumption_mb": round(memory_mb, 2),
        "memory_limit_mb": 512.0
    }
9. Antigravity Deployment Verification ChecklistThe Antigravity agent must verify the following operational gates before proceeding to mobile client builds:[ ] Docker Build Success: Execute docker build -t urheart-api . locally or on Render and ensure image builds without missing tesseract headers.[ ] RAM Ceiling Compliance: Ensure container idle RAM does not exceed 160 MB, leaving $> 350$ MB headroom for active OCR and WebSocket connections.[ ] Supabase Storage Bucket Verification: Verify bucket existence (user-photos and kyc-temp) with correct file-size limits (150 KB for photos, 2.5 MB for videos).[ ] Signed URL Generation Test: Trigger create_signed_upload_url() and confirm Flutter can execute a direct PUT upload without encountering CORS errors.[ ] Storage Cascade Test: Call purge_user_storage_assets(test_uuid) $\rightarrow$ Confirm all files under user-photos/{test_uuid}/ are permanently removed.Authorized & Validated for ASI Verticals / UR-Heart Infrastructure Pipeline.