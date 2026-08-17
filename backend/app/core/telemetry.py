from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from app.core.config import settings
from app.db.session import engine
import logging

logger = logging.getLogger(__name__)


def _parse_headers(raw: str) -> dict:
    """Parse 'Key=Value,Key2=Value2' into a dict."""
    headers = {}
    if raw:
        for item in raw.split(','):
            if '=' in item:
                key, value = item.split('=', 1)
                headers[key.strip()] = value.strip()
    return headers


def setup_telemetry(app):
    """
    Sets up OpenTelemetry tracing and metrics for the FastAPI application.

    Instruments:
      - FastAPI (HTTP spans per request)
      - SQLAlchemy (one span per DB query → shows PostgreSQL activity)
      - Redis (one span per Redis command → shows cache/pubsub activity)
      - Requests (outbound HTTP: Gemini, Resend, etc.)

    Spans flow:
      FastAPI HTTP span
        ├── SQLAlchemy SELECT/INSERT (PostgreSQL)
        └── Redis GET/SET/PUBLISH (Redis)
    """

    # 1. Resource — identifies this service in Jaeger / Grafana
    resource = Resource.create(attributes={
        SERVICE_NAME: settings.OTEL_SERVICE_NAME,
        "deployment.environment": settings.ENVIRONMENT,
        "service.version": "1.0.0",
    })

    # 2. Tracing
    tracer_provider = TracerProvider(resource=resource)

    if settings.OTEL_EXPORTER_OTLP_ENDPOINT:
        # The OTLP HTTP exporter expects the full signal path:
        # base_url/v1/traces — OTLPSpanExporter builds this automatically from a bare base URL.
        base_url = settings.OTEL_EXPORTER_OTLP_ENDPOINT.rstrip('/')
        # Strip /v1/traces if user included it (avoid double path)
        if base_url.endswith('/v1/traces'):
            base_url = base_url[:-len('/v1/traces')]

        otlp_headers = _parse_headers(settings.OTEL_EXPORTER_OTLP_HEADERS or "")

        exporter = OTLPSpanExporter(
            endpoint=f"{base_url}/v1/traces",
            headers=otlp_headers,
        )
        tracer_provider.add_span_processor(BatchSpanProcessor(exporter))
        logger.info(f"[OTEL] Tracing → {base_url}/v1/traces (service: {settings.OTEL_SERVICE_NAME})")
    else:
        logger.warning("[OTEL] No OTLP endpoint configured — spans won't be exported.")

    trace.set_tracer_provider(tracer_provider)

    # 3. Metrics
    if settings.OTEL_EXPORTER_OTLP_ENDPOINT:
        base_url = settings.OTEL_EXPORTER_OTLP_ENDPOINT.rstrip('/')
        if base_url.endswith('/v1/metrics'):
            base_url = base_url[:-len('/v1/metrics')]
        elif base_url.endswith('/v1/traces'):
            base_url = base_url[:-len('/v1/traces')]

        otlp_headers = _parse_headers(settings.OTEL_EXPORTER_OTLP_HEADERS or "")
        metric_exporter = OTLPMetricExporter(
            endpoint=f"{base_url}/v1/metrics",
            headers=otlp_headers,
        )
        reader = PeriodicExportingMetricReader(metric_exporter, export_interval_millis=15000)
        metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[reader]))
        logger.info(f"[OTEL] Metrics → {base_url}/v1/metrics")

    # 4. Instrumentations
    # ── FastAPI: one span per HTTP request ──────────────────────────────────
    FastAPIInstrumentor.instrument_app(app)

    # ── SQLAlchemy: one span per SQL query (shows PostgreSQL in Jaeger) ─────
    # Uses engine.sync_engine because async engines wrap a sync core
    SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)

    # ── Redis: one span per Redis command (shows cache/pubsub in Jaeger) ────
    RedisInstrumentor().instrument()

    # ── Requests: external HTTP calls (Gemini API, Resend, etc.) ──────────
    RequestsInstrumentor().instrument()

    return tracer_provider
