# ==========================================
# STAGE 1: Build Dependencies
# ==========================================
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build-time system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ==========================================
# STAGE 2: Production Runtime
# ==========================================
FROM python:3.11-slim AS runner

WORKDIR /app

# Install minimal runtime libraries (libpq for asyncpg, libzbar0 for QR scan)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libzbar0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create unprivileged application user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/sh appuser

# Copy installed wheels from builder
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Copy application source code
COPY --chown=appuser:appgroup . /app

# Ephemeral storage directory with explicit cleanup permissions
RUN mkdir -p /app/temp_uploads && chown -R appuser:appgroup /app/temp_uploads

USER appuser

# Expose API port
EXPOSE 8000

# Healthcheck for orchestration monitoring
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Production server entrypoint optimized for Render 512MB RAM & horizontal scaling
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--timeout-keep-alive", "30", "--limit-concurrency", "50"]
