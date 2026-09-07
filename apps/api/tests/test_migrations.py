"""Die Migrationskette muss dasselbe Schema erzeugen wie die Modelle.

Ohne diese Prüfung fällt eine vergessene Migration erst beim Deploy auf - dann steht die API, und
die Datenbank ist in einem Zustand, den niemand vorhergesehen hat. Alembic läuft dabei als eigener
Prozess, genau wie beim Deploy; env.py startet eine eigene Ereignisschleife und ließe sich aus einem
laufenden Test heraus nicht aufrufen.

Geprüft wird gegen SQLite. Die Spaltentypen unterscheiden sich von PostgreSQL, die Tabellen- und
Spaltennamen nicht - und genau die gehen beim Nachtragen verloren.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, inspect

from dch_api.infrastructure.db.models import Base

API_DIR = Path(__file__).resolve().parents[1]
ALEMBIC_INI = API_DIR / "alembic.ini"


@pytest.fixture(scope="module")
def migrated(tmp_path_factory: pytest.TempPathFactory) -> str:
    path = tmp_path_factory.mktemp("mig") / "migrated.sqlite"
    env = {**os.environ, "DCH_MIGRATION_DATABASE_URL": f"sqlite+aiosqlite:///{path}"}
    run = subprocess.run(
        [sys.executable, "-m", "alembic", "-c", str(ALEMBIC_INI), "upgrade", "head"],
        cwd=API_DIR,
        env=env,
        capture_output=True,
        text=True,
        timeout=180,
    )
    assert run.returncode == 0, f"alembic upgrade head fehlgeschlagen:\n{run.stderr}"
    return f"sqlite:///{path}"


def test_migrations_produce_the_model_schema(migrated: str) -> None:
    engine = create_engine(migrated)
    insp = inspect(engine)
    tables = set(insp.get_table_names()) - {"alembic_version"}
    assert tables == set(Base.metadata.tables), "Tabellen weichen ab"
    for name, table in Base.metadata.tables.items():
        migrated_cols = {c["name"] for c in insp.get_columns(name)}
        assert migrated_cols == set(table.columns.keys()), f"Spalten von {name} weichen ab"
    engine.dispose()


def test_measurements_minute_is_keyed_by_bucket_alone(migrated: str) -> None:
    """Ein Primärschlüssel nur auf der Zeit: darauf beruhen die Bereichsabfragen und der Upsert."""
    engine = create_engine(migrated)
    pk = inspect(engine).get_pk_constraint("measurements_minute")
    assert pk["constrained_columns"] == ["bucket"]
    engine.dispose()
