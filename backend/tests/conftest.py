import pytest
import asyncio
from typing import AsyncGenerator, Any
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy import String, TypeDecorator, JSON
import uuid
import sys
from unittest.mock import MagicMock

# --- BYPASS TELEMETRY FOR TESTS ---
# We mock telemetry modules before they are imported by app.main to avoid dependency issues (like pkg_resources in Python 3.13)
telemetry_mock = MagicMock()
sys.modules["app.core.telemetry"] = telemetry_mock
sys.modules["opentelemetry"] = MagicMock()
sys.modules["opentelemetry.trace"] = MagicMock()
sys.modules["opentelemetry.metrics"] = MagicMock()
sys.modules["opentelemetry.instrumentation.fastapi"] = MagicMock()
sys.modules["opentelemetry.instrumentation.sqlalchemy"] = MagicMock()
sys.modules["opentelemetry.instrumentation.requests"] = MagicMock()
sys.modules["opentelemetry.exporter.otlp"] = MagicMock()

# --- MONKEYPATCH UUID FOR SQLITE COMPATIBILITY ---
# SQLite doesn't have a native UUID type. We patch postgresql.UUID to behave like String(36) in SQLite.
from sqlalchemy.dialects import postgresql

class SQLiteUUID(TypeDecorator):
    impl = String
    cache_ok = True

    def __init__(self, as_uuid=True):
        super().__init__(36)

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        return str(value)

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        return uuid.UUID(value)

# Replacement for postgresql.UUID, JSONB and ARRAY in tests
postgresql.UUID = SQLiteUUID
postgresql.JSONB = JSON
postgresql.ARRAY = JSON
# ------------------------------------------------

from app.main import app
from app.db.session import Base, get_db
from app.core.config import settings

# Test database URL (SQLite in-memory)
SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = async_sessionmaker(
    autocommit=False, autoflush=False, bind=engine, expire_on_commit=False
)

@pytest.fixture(scope="session")
async def init_db():
    """Initialize database schema once per session."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.fixture
async def db(init_db) -> AsyncGenerator[AsyncSession, None]:
    """Provide a clean session for each test."""
    async with TestingSessionLocal() as session:
        yield session
        # Session cleans up automatically

@pytest.fixture
async def client(db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Provide an HTTP client with DB dependency overridden."""
    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()

@pytest.fixture
def mock_gemini(mocker):
    """Fixture to mock Gemini AI responses."""
    mock_model = mocker.patch("app.api.endpoints.ai_workouts.genai.GenerativeModel")
    instance = mock_model.return_value
    
    # Mock response object
    mock_response = mocker.Mock()
    mock_response.text = "{}" # Default empty JSON
    instance.generate_content.return_value = mock_response
    
    return instance
