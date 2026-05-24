################################################################################
# FILE        : applications/payment-service/app/main.py
# DESCRIPTION : Minimal FinTech payment service simulation.
#               Demonstrates production API patterns:
#               - Health and readiness endpoints (ALB/K8s probe targets)
#               - Structured JSON responses
#               - Request correlation ID header
#               - Environment-aware configuration
#
# HONEST NOTE : This is a portfolio simulation — not a real payment processor.
#               It demonstrates API structure, health check patterns, and
#               container-native configuration via environment variables.
################################################################################

import os
import uuid
import logging
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# ── LOGGING SETUP ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s"
)
logger = logging.getLogger("payment-service")

# ── APP CONFIGURATION FROM ENVIRONMENT ────────────────────────────────────────
# Container-native pattern: all config via environment variables
# No hardcoded values — matches 12-Factor App principle III
APP_ENV     = os.getenv("APP_ENV", "local")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
SERVICE_NAME = os.getenv("SERVICE_NAME", "payment-service")

# ── FASTAPI INSTANCE ──────────────────────────────────────────────────────────
app = FastAPI(
    title="FinTech Payment Service",
    description="Cloud-native payment service — portfolio demonstration",
    version=APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc"
)

# ── REQUEST MODELS ─────────────────────────────────────────────────────────────
class PaymentRequest(BaseModel):
    transaction_id: str
    amount: float
    currency: str = "INR"
    sender_account: str
    receiver_account: str

class PaymentResponse(BaseModel):
    status: str
    transaction_id: str
    reference_id: str
    timestamp: str
    message: str

# ── MIDDLEWARE — CORRELATION ID ────────────────────────────────────────────────
@app.middleware("http")
async def add_correlation_id(request: Request, call_next):
    """
    Adds X-Correlation-ID to every response.
    Critical for distributed tracing in microservice architectures.
    Reads from incoming header if present (forwarded by API gateway),
    generates a new UUID if not.
    """
    correlation_id = request.headers.get(
        "X-Correlation-ID",
        str(uuid.uuid4())
    )
    response = await call_next(request)
    response.headers["X-Correlation-ID"] = correlation_id
    return response

# ── HEALTH ENDPOINTS ───────────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    """
    Liveness probe endpoint.
    Kubernetes kubelet hits this to decide if the container needs restart.
    ALB target group health check also hits this path.
    Must return 200 quickly — no database calls here.
    """
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "service": SERVICE_NAME,
            "version": APP_VERSION,
            "environment": APP_ENV,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    )

@app.get("/ready")
async def readiness_check():
    """
    Readiness probe endpoint.
    Kubernetes hits this to decide if pod should receive traffic.
    Difference from liveness: readiness can check downstream deps.
    Returns 503 if service is not ready to handle requests.
    """
    return JSONResponse(
        status_code=200,
        content={
            "status": "ready",
            "service": SERVICE_NAME,
            "version": APP_VERSION,
            "environment": APP_ENV,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    )

# ── APPLICATION ENDPOINTS ──────────────────────────────────────────────────────

@app.get("/")
async def root():
    """Service discovery root endpoint."""
    return {
        "service": SERVICE_NAME,
        "version": APP_VERSION,
        "environment": APP_ENV,
        "endpoints": {
            "health":   "/health",
            "ready":    "/ready",
            "payments": "/api/v1/payments",
            "docs":     "/docs"
        }
    }

@app.post("/api/v1/payments", response_model=PaymentResponse)
async def process_payment(payment: PaymentRequest, request: Request):
    """
    Simulated payment processing endpoint.
    In a real system this would call a payment gateway (Razorpay, Stripe).
    Here it demonstrates: request validation, structured response,
    correlation ID propagation, and error handling patterns.
    """
    correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))

    logger.info(
        f"Processing payment | tx_id={payment.transaction_id} "
        f"amount={payment.amount} {payment.currency} "
        f"correlation_id={correlation_id}"
    )

    # Basic business rule validation
    if payment.amount <= 0:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "INVALID_AMOUNT",
                "message": "Payment amount must be greater than zero",
                "transaction_id": payment.transaction_id
            }
        )

    if payment.sender_account == payment.receiver_account:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "SAME_ACCOUNT",
                "message": "Sender and receiver accounts cannot be the same",
                "transaction_id": payment.transaction_id
            }
        )

    # Simulate successful payment processing
    reference_id = f"REF-{uuid.uuid4().hex[:12].upper()}"

    logger.info(
        f"Payment processed | tx_id={payment.transaction_id} "
        f"ref_id={reference_id} status=SUCCESS"
    )

    return PaymentResponse(
        status="SUCCESS",
        transaction_id=payment.transaction_id,
        reference_id=reference_id,
        timestamp=datetime.now(timezone.utc).isoformat(),
        message=f"Payment of {payment.amount} {payment.currency} processed successfully"
    )

@app.get("/api/v1/payments/{transaction_id}")
async def get_payment_status(transaction_id: str):
    """
    Payment status lookup endpoint.
    Simulates fetching transaction state from a data store.
    """
    return {
        "transaction_id": transaction_id,
        "status": "COMPLETED",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": SERVICE_NAME,
        "note": "Simulated response — no real data store in local environment"
    }
