import os
import re
from contextlib import asynccontextmanager
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/postgres"
)

# Convert standard postgres:// or postgresql:// to postgresql+asyncpg:// if needed
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)

# Render & cloud host IPv6 bypass:
# Supabase direct host (db.<ref>.supabase.co:5432) resolves ONLY to IPv6, causing
# 'OSError: [Errno 101] Network is unreachable' on platforms without outbound IPv6 (like Render).
# Auto-rewrite to the IPv4 transaction pooler (aws-0-ap-south-1.pooler.supabase.com:6543)
supabase_direct_match = re.search(r'@db\.([a-z0-9]+)\.supabase\.co:5432', DATABASE_URL)
if supabase_direct_match:
    project_id = supabase_direct_match.group(1)
    DATABASE_URL = re.sub(r'://postgres:', f'://postgres.{project_id}:', DATABASE_URL)
    DATABASE_URL = DATABASE_URL.replace(
        f'db.{project_id}.supabase.co:5432',
        'aws-0-ap-south-1.pooler.supabase.com:6543'
    )

connect_args = {}
if "supabase.com" in DATABASE_URL or "supabase.co" in DATABASE_URL or "pooler" in DATABASE_URL:
    connect_args = {
        "ssl": "require",
        "statement_cache_size": 0,
    }

Base = declarative_base()

# Initialize engine with safe pool limits for Render 512MB RAM
try:
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        pool_size=5,
        max_overflow=10,
        pool_pre_ping=True,
        connect_args=connect_args,
    )
except Exception:
    # Fallback to in-memory sqlite for mock/test environments
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)

async_session_factory = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
