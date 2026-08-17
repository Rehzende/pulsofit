from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from pydantic import model_validator

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    PROJECT_NAME: str = "PULSO"
    API_V1_STR: str = "/api/v1"
    
    POSTGRES_USER: Optional[str] = None
    POSTGRES_PASSWORD: Optional[str] = None
    POSTGRES_SERVER: Optional[str] = None
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: Optional[str] = None
    
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    MAGIC_LINK_EXPIRE_MINUTES: int = 10
    
    FRONTEND_URL: str = "https://pulsofit.app"
    BACKEND_URL: str = "https://web-production-06662.up.railway.app"
    ENVIRONMENT: str = "production"

    MAIL_FROM: str = "noreply@pulsofit.app"
    MAIL_FROM_NAME: str = "PULSO"
    RESEND_API_KEY: Optional[str] = None

    # Object Storage (Railway / S3-compatible)
    S3_ENDPOINT_URL: str = "https://t3.storageapi.dev"
    S3_PUBLIC_URL: str = "https://fly.storage.tigris.dev"  # CDN URL for public access
    S3_REGION: str = "auto"
    S3_BUCKET_NAME: Optional[str] = None
    S3_ACCESS_KEY_ID: Optional[str] = None
    S3_SECRET_ACCESS_KEY: Optional[str] = None

    # Firebase Cloud Messaging (push notifications)
    GOOGLE_APPLICATION_CREDENTIALS_JSON: Optional[str] = None
    FCM_PROJECT_ID: Optional[str] = None

    # Google OAuth (Sign in with Google)
    GOOGLE_CLIENT_ID: Optional[str] = None

    DATABASE_URL: Optional[str] = None

    # OpenTelemetry / Grafana Cloud
    OTEL_EXPORTER_OTLP_ENDPOINT: Optional[str] = None
    OTEL_EXPORTER_OTLP_HEADERS: Optional[str] = None
    OTEL_SERVICE_NAME: str = "pulso-backend"

    # App Store / Play Store Reviewer Test Codes
    TEST_APPLE_CODE: str = "111111"
    TEST_GOOGLE_CODE: str = "222222"
    TEST_TESTER_CODE: str = "123456"

    # Redis (for Pub/Sub and caching)
    REDIS_URL: Optional[str] = None

    @model_validator(mode='after')
    def check_db_config(self) -> 'Settings':
        if not self.DATABASE_URL:
            if not all([self.POSTGRES_USER, self.POSTGRES_PASSWORD, self.POSTGRES_SERVER, self.POSTGRES_DB]):
                raise ValueError("Database configuration is missing. Either set DATABASE_URL or (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_SERVER, POSTGRES_DB).")
        return self

    def assemble_db_url(self) -> str:
        if self.DATABASE_URL:
            # Fix for Railway/Heroku using postgres:// which SQLAlchemy doesn't support
            if self.DATABASE_URL.startswith("postgres://"):
                return self.DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
            if self.DATABASE_URL.startswith("postgresql://"):
                return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
            return self.DATABASE_URL
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

settings = Settings()
