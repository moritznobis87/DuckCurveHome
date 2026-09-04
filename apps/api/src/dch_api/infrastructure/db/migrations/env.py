"""Alembic-Umgebung: URL aus Settings, Typvergleich an, JSON/JSONB-Variante korrekt gerendert."""

from __future__ import annotations

import asyncio
import os
from logging.config import fileConfig
from typing import Literal

from alembic import context
from alembic.autogenerate.api import AutogenContext
from sqlalchemy import Connection, pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from dch_api.infrastructure.db.engine import normalize_url
from dch_api.infrastructure.db.models import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def database_url() -> str:
    url = os.environ.get("DCH_MIGRATION_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL ist nicht gesetzt.")
    return normalize_url(url)


def render_item(type_: str, obj: object, autogen_context: AutogenContext) -> str | Literal[False]:
    # JSON mit JSONB-Variante für PostgreSQL einheitlich rendern
    if type_ == "type" and obj.__class__.__name__ == "JSON":
        autogen_context.imports.add("from sqlalchemy.dialects import postgresql")
        return 'sa.JSON().with_variant(postgresql.JSONB(), "postgresql")'
    return False


def run_migrations_offline() -> None:
    context.configure(
        url=database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        compare_type=True,
        render_item=render_item,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        render_item=render_item,
        render_as_batch=connection.dialect.name == "sqlite",
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    cfg = config.get_section(config.config_ini_section) or {}
    cfg["sqlalchemy.url"] = database_url()
    engine = async_engine_from_config(cfg, prefix="sqlalchemy.", poolclass=pool.NullPool)
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
