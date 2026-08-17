import logging

# Configure logging - suppress verbose libraries
logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
logging.getLogger("sqlalchemy.pool").setLevel(logging.WARNING)
logging.getLogger("opentelemetry").setLevel(logging.WARNING)
logging.getLogger("opentelemetry.exporter.otlp").setLevel(logging.ERROR)
logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.core.telemetry import setup_telemetry

# Determine if we are in production
is_production = settings.ENVIRONMENT.lower() == "production"

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json" if not is_production else None,
    docs_url="/docs" if not is_production else None,
    redoc_url="/redoc" if not is_production else None,
)

# Initialize OpenTelemetry
setup_telemetry(app)

from fastapi.middleware.cors import CORSMiddleware

origins = [
    "http://192.168.0.5:3000",
    "http://192.168.0.5:8000",
    "http://192.168.68.112:3000",
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8000",
    'http://localhost:36491',
    settings.FRONTEND_URL,
    "https://pulsofit.app",
    "https://www.pulsofit.app",
    "https://pulsoapp-tau.vercel.app",
    "https://pulso-6dk02j6ji-rehzendes-projects.vercel.app",
    "https://pulso-git-main-rehzendes-projects.vercel.app",
]

if is_production:
    origins = [
        "https://pulsofit.app",
        "https://www.pulsofit.app",
        "https://api.pulsofit.app",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure rate limiting (SlowAPI)
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# Mount static files directory
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.on_event("startup")
async def on_startup():
    # Garantir que as tabelas do AI Agent existam
    from app.db.session import engine, Base
    from app.models.ai_agent import AgentSession, AgentMessage # Importar para registrar no Base
    async with engine.begin() as conn:
        # create_all não sobrescreve tabelas existentes
        await conn.run_sync(Base.metadata.create_all)

    # Initialize Redis
    from app.services.redis_service import redis_service
    await redis_service.connect()

@app.on_event("shutdown")
async def on_shutdown():
    # Disconnect Redis
    from app.services.redis_service import redis_service
    await redis_service.disconnect()


from fastapi import HTTPException

@app.get("/")
async def root():
    if is_production:
        raise HTTPException(status_code=404, detail="Not Found")
    return {"message": "Welcome to PULSO API"}

@app.get("/health")
async def health_check():
    return {"status": "ok"}

from app.api.api import api_router
app.include_router(api_router, prefix=settings.API_V1_STR)
