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
