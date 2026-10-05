from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine
)
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool
from app.core.config import get_settings

settings = get_settings()

import os
import sys

is_test_env = ("pytest" in sys.modules) or bool(os.getenv("PYTEST_CURRENT_TEST")) or getattr(settings, "ENVIRONMENT", "").lower() == "test"

engine_kwargs = {
    "echo": settings.DEBUG,
    "future": True,
    "connect_args": {
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0,
    }
}

if is_test_env:
    engine_kwargs["poolclass"] = NullPool
else:
    engine_kwargs.update({
        "pool_size": 10,
        "max_overflow": 20,
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "pool_timeout": 10,
    })

# Connection engine with disabled prepared statement cache for Supabase PgBouncer (Port 6543)
engine = create_async_engine(
    settings.SUPABASE_PGBOUNCER_URL,
    **engine_kwargs
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)
async_session_factory = AsyncSessionLocal


class Base(declarative_base()):
    __abstract__ = True
    __allow_unmapped__ = True


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency for providing transactional async database sessions."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
