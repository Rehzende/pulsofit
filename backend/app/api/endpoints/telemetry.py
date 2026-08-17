from fastapi import APIRouter, Request, HTTPException, Depends
import httpx
from app.core.config import settings

router = APIRouter()

@router.post("/v1/traces")
async def proxy_traces(request: Request):
    """
    Acts as a secure proxy to forward OTLP spans from the mobile app 
    to Grafana Cloud without exposing the token in the APK.
    """
    if not settings.OTEL_EXPORTER_OTLP_ENDPOINT:
        # If backend doesn't have telemetry configured, just accept and drop
        return {"status": "dropped"}

    # Grafana Cloud endpoint for traces usually ends with /v1/traces
    # We construct the destination URL carefully
    base_endpoint = settings.OTEL_EXPORTER_OTLP_ENDPOINT
    if not base_endpoint.endswith("/v1/traces"):
        if base_endpoint.endswith("/otlp"):
            target_url = base_endpoint + "/v1/traces"
        else:
            target_url = base_endpoint.rstrip("/") + "/v1/traces"
    else:
        target_url = base_endpoint

    headers = {
        "Content-Type": request.headers.get("Content-Type", "application/x-protobuf"),
        "User-Agent": request.headers.get("User-Agent", "pulso-mobile-proxy"),
    }

    # Add Grafana Cloud Authorization
    if settings.OTEL_EXPORTER_OTLP_HEADERS:
        # OTEL_EXPORTER_OTLP_HEADERS is typically "Authorization=Basic <base64>"
        for header in settings.OTEL_EXPORTER_OTLP_HEADERS.split(","):
            if "=" in header:
                k, v = header.split("=", 1)
                headers[k.strip()] = v.strip()

    body = await request.body()

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(target_url, content=body, headers=headers, timeout=5.0)
            if response.status_code >= 400:
                print(f"Grafana OTLP Error: {response.status_code} - {response.text}")
                raise HTTPException(status_code=response.status_code, detail="Error forwarding traces")
            return {"status": "forwarded"}
        except httpx.RequestError as exc:
            print(f"Error proxying traces: {exc}")
            raise HTTPException(status_code=502, detail="Failed to reach Grafana Cloud")
