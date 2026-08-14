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


from sqlalchemy import text


async def init_db() -> None:
    """Helper function to create tables and auto-migrate missing columns in PostgreSQL."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

        # Execute safe ALTER TABLE column additions for existing PostgreSQL tables
        migration_queries = [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT TRUE;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMP WITH TIME ZONE;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 6);",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 6);",
            "ALTER TABLE sachet_transactions ADD COLUMN IF NOT EXISTS valid_until TIMESTAMP WITH TIME ZONE;",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS client_msg_id VARCHAR(64);",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_video_url TEXT;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(512);",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS dob DATE;",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS date_of_birth DATE;",
        ]
        for query in migration_queries:
            try:
                await conn.execute(text(query))
            except Exception as e:
                print(f"[DB Schema Migration Notice] {query} -> {e}")
