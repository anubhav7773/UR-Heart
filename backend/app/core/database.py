from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.core.config import settings
from app.models.orm import Base

# Configure connection parameters for Supabase PgBouncer transaction pooler & SSL
connect_args = {}

# Set statement cache size to 0 for PgBouncer compatibility
if "pooler.supabase.com" in settings.DATABASE_URL or "6543" in settings.DATABASE_URL:
    connect_args["statement_cache_size"] = 0
    connect_args["prepared_statement_cache_size"] = 0
    connect_args["ssl"] = "require"

# Ensure asyncpg dialect prefix is present
db_url = settings.DATABASE_URL
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)

engine = create_async_engine(
    db_url,
    echo=False,
    future=True,
    pool_pre_ping=True,
    connect_args=connect_args,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI async dependency yielding database session from connection pool."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db() -> None:
    """Helper function to create tables from SQLAlchemy metadata."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
