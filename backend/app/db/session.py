from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# Determine if we are in production
is_production = settings.ENVIRONMENT.lower() == "production"

# Create async engine with optimized connection pool
# - pool_size: base number of persistent connections (20 supports ~20 concurrent handlers)
# - max_overflow: temporary connections beyond pool_size (allows bursts up to 30 total)
# - pool_recycle: recycle connections after 1 hour (avoids stale connections)
# - pool_pre_ping: test connection before use (emits "SELECT 1" to avoid errors on reconnect)
# - echo: disable query logging in production (performance + privacy), keep in dev/test
engine = create_async_engine(
    settings.assemble_db_url(),
    echo=not is_production,
    pool_size=20,
    max_overflow=10,
    pool_recycle=3600,
    pool_pre_ping=True,
)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
