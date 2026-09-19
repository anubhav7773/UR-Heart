import os
import re
import sys
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool
from app.core.config import settings

DATABASE_URL = settings.DATABASE_URL or os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/ur_heart"
)

# Convert URL scheme if required
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgresql://") and not DATABASE_URL.startswith("postgresql+asyncpg://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

# Render & cloud host IPv6 bypass:
supabase_direct_match = re.search(r'@db\.([a-z0-9]+)\.supabase\.co:5432', DATABASE_URL)
if supabase_direct_match:
    project_id = supabase_direct_match.group(1)
    DATABASE_URL = re.sub(r'://postgres:', f'://postgres.{project_id}:', DATABASE_URL)
    DATABASE_URL = DATABASE_URL.replace(
        f'db.{project_id}.supabase.co:5432',
        'aws-0-ap-south-1.pooler.supabase.com:6543'
    )

connect_args = {
    "command_timeout": 15,
    "server_settings": {
        "statement_timeout": "15000"  # Terminate queries taking over 15 seconds
    }
}
if "supabase.com" in DATABASE_URL or "supabase.co" in DATABASE_URL or "pooler" in DATABASE_URL:
    connect_args["ssl"] = "require"
    connect_args["statement_cache_size"] = 0

Base = declarative_base()

is_test = "pytest" in sys.modules or os.getenv("PYTEST_CURRENT_TEST") is not None

# Connection Pool configured specifically for Render 512 MB RAM constraints
try:
    if is_test:
        engine = create_async_engine(
            DATABASE_URL,
            echo=False,
            future=True,
            poolclass=NullPool,
            connect_args=connect_args
        )
    else:
        engine = create_async_engine(
            DATABASE_URL,
            echo=False,
            future=True,
            pool_size=5,             # Minimal baseline active connections
            max_overflow=5,          # Maximum surge capacity for spikes
            pool_timeout=10,         # Fast failure if pool is exhausted
            pool_recycle=300,        # Recycle connections every 5 minutes to prevent stale leaks
            pool_pre_ping=True,      # Discard dead connections before assigning to workers
            connect_args=connect_args
        )
except Exception:
    # Fallback for mock/test environments
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

async_session_factory = AsyncSessionLocal

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency ensuring database sessions are immediately closed and
    released back to the pool in a finally block.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()  # Instantly release connection to keep RAM free
