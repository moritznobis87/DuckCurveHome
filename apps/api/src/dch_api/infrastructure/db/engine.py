"""Async-Engine und Session-Fabrik. DATABASE_URL: postgresql+asyncpg://… oder sqlite+aiosqlite:///…"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from dch_api.infrastructure.db.models import Base


def normalize_url(url: str) -> str:
    """Railway liefert postgresql://…; asyncpg braucht postgresql+asyncpg://…"""
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    if url.startswith("postgresql://"):
        url = "postgresql+asyncpg://" + url[len("postgresql://") :]
    return url


def make_engine(url: str, echo: bool = False) -> AsyncEngine:
    url = normalize_url(url)
    kwargs: dict[str, object] = {"echo": echo, "pool_pre_ping": True}
    if url.startswith("postgresql+asyncpg"):
        kwargs.update(pool_size=5, max_overflow=5, pool_recycle=300)
    return create_async_engine(url, **kwargs)


def make_sessionmaker(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(engine, expire_on_commit=False)


async def create_all_for_tests(engine: AsyncEngine) -> None:
    """Nur für Tests/SQLite – im Betrieb laufen Alembic-Migrationen."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@asynccontextmanager
async def session_scope(maker: async_sessionmaker[AsyncSession]) -> AsyncIterator[AsyncSession]:
    async with maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
