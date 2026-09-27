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

# NullPool is strictly mandatory for Supabase PgBouncer (Port 6543 transaction pooling)
engine = create_async_engine(
    settings.SUPABASE_PGBOUNCER_URL,
    poolclass=NullPool,
    echo=settings.DEBUG,
    future=True
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

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
