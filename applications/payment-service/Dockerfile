################################################################################
# FILE        : applications/payment-service/Dockerfile
# DESCRIPTION : Multi-stage build for the FinTech payment service.
#
# STAGE 1 (builder) : Installs dependencies in isolated layer.
#                     Build tools never reach the final image.
# STAGE 2 (runtime) : Copies only what is needed to run.
#                     Smaller image = smaller attack surface.
#
# SECURITY STANDARDS:
#   - Non-root user (appuser uid=1001)
#   - Pinned base image tag — no floating latest
#   - Explicit COPY — no COPY . . to prevent secrets leaking in
#   - HEALTHCHECK instruction for Docker-native monitoring
#
# BUILD:
#   docker build -t payment-service:1.0.0 .
#
# RUN LOCALLY:
#   docker run -p 8000:8000 \
#     -e APP_ENV=local \
#     -e APP_VERSION=1.0.0 \
#     payment-service:1.0.0
#
# TEST:
#   curl http://localhost:8000/health
################################################################################

# ── STAGE 1: BUILDER ──────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements first — Docker layer cache optimisation
# This layer only rebuilds when requirements.txt changes
COPY requirements.txt .

# Install to a prefix directory for clean copy to runtime stage
RUN pip install \
    --no-cache-dir \
    --prefix=/install \
    -r requirements.txt

# ── STAGE 2: RUNTIME ──────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Build arguments — injected at build time by CI/CD pipeline
ARG APP_VERSION=1.0.0
ARG BUILD_DATE
ARG GIT_COMMIT

# OCI standard image labels
LABEL org.opencontainers.image.title="payment-service"
LABEL org.opencontainers.image.description="FinTech Payment Service — Cloud Native Portfolio"
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

# Runtime environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=${APP_VERSION} \
    APP_ENV=local \
    SERVICE_NAME=payment-service \
    PORT=8000

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Create non-root user — never run app as root inside container
RUN groupadd --gid 1001 appgroup && \
    useradd \
      --uid 1001 \
      --gid appgroup \
      --shell /bin/sh \
      --no-create-home \
      appuser

WORKDIR /app

# Explicit file copy — not COPY . .
# Prevents .env files, .git history, secrets from entering image
COPY app/main.py .

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root
USER appuser

EXPOSE 8000

# Docker-native health check
HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=10s \
    --retries=3 \
    CMD python -c \
      "import urllib.request; \
       urllib.request.urlopen('http://localhost:8000/health')" \
    || exit 1

# Single worker — Kubernetes manages scaling via replicas
CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--log-level", "info"]
