"""Die Anweisung trägt die Zeilen nicht.

**Der Anlass.** Am 29.10.2026 lagen im laufenden Dienst 102 774 `BindParameter`-Objekte im
Speicher. Sie kamen aus `INSERT … VALUES (…), (…), …`: Dabei geht ein Platzhalter je Spalte **und
Zeile** in die Anweisung. Der Minuten-Rollup arbeitet tageweise, ein Tag sind 1440 Zeilen mit rund
dreißig Spalten, und nach einem Neustart holt er den Rückstand auf. Eine einzige Anweisung baut so
über vierzigtausend Python-Objekte auf, bevor die erste Zeile geschrieben ist.

Die Zeilen gehören deshalb ans Ausführen (`execute(anweisung, zeilen)`), nicht in die Anweisung.
Dann ist die Anweisung eine Zeile breit, gleich wie viele Zeilen kommen, und SQLAlchemy bündelt
sie selbst.

**Was die Suite nicht prüfen kann.** Sie läuft auf SQLite, geschrieben wird in Produktion auf
PostgreSQL, und `ON CONFLICT DO UPDATE` mit einem Stapel ist genau die Stelle, an der sich die
beiden unterscheiden könnten. Von Hand gegen PostgreSQL 16 geprüft am 29.10.2026: ein Stapel von
eins, ein Stapel von 2000, derselbe Schlüssel noch einmal mit neuem Wert, danach zweimal
derselbe Rollup. Ergebnis: eine Zeile je Schlüssel im Live-Zustand mit dem jüngeren Wert, 2000
Rohzeilen statt 4000, und der zweite Rollup aktualisierte dieselben 400 Minutenzeilen, statt sie
zu verdoppeln.

**Was hier nicht geprüft wird, und warum nicht.** Ein erster Versuch zählte die Platzhalter im
Speicher vor und nach dem Schreiben. Der Test bestand auch mit dem alten Stand: Die Objekte leben
nur während des Schreibens, danach räumt Python sie weg. Sie lagen nicht herum, sie waren in
Arbeit - und ein Test, der den Fehler nicht sieht, beweist nichts. Geprüft wird darum die
Eigenschaft der Anweisung selbst.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from dch_api.infrastructure.db import models as m
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import MINUTE_COLUMNS, SqlRepositories
from hems_core.domain import Quality
from hems_core.protocol import RawReading


def messwerte(n: int, ab: datetime) -> list[RawReading]:
    return [
        RawReading(
            key=f"reihe_{i % 8}",
            value=float(i),
            observed_at=ab + timedelta(seconds=i),
            quality=Quality.OK,
            source="test",
        )
        for i in range(n)
    ]


def test_die_anweisung_ist_eine_zeile_breit(tmp_path: Path) -> None:
    """Je Spalte ein Platzhalter, nicht je Spalte und Zeile."""
    repos = SqlRepositories(make_engine(f"sqlite+aiosqlite:///{tmp_path / 'form.sqlite'}"))
    roh = repos._upsert(m.MeasurementRaw, ["sensor_key", "observed_at"], ["value", "quality"])
    uebersetzt = roh.compile()
    assert len(uebersetzt.binds) <= 4, uebersetzt.binds
    assert str(uebersetzt).count("VALUES") == 1

    # Die breiteste Tabelle ist die wichtigste: hier wuchs es am schnellsten.
    minute = repos._upsert(m.MeasurementMinute, ["bucket"], [*MINUTE_COLUMNS, "extra"])
    assert len(minute.compile().binds) <= len(MINUTE_COLUMNS) + 2


@pytest.mark.asyncio
async def test_die_zeilen_kommen_trotzdem_an(tmp_path: Path) -> None:
    """Die Form der Anweisung ist das eine, die Daten das andere."""
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'rows.sqlite'}")
    await create_all_for_tests(engine)
    repos = SqlRepositories(engine)
    ab = datetime(2026, 10, 29, 6, 0, tzinfo=UTC)
    await repos.add_readings(messwerte(50, ab))
    # Dieselben Schluessel noch einmal, spaeter: der juengste Wert gewinnt im Live-Zustand.
    await repos.add_readings(messwerte(50, ab + timedelta(hours=1)))
    letzte = await repos.latest()
    assert {r.key for r in letzte} == {f"reihe_{i}" for i in range(8)}
    for r in letzte:
        assert r.observed_at >= ab + timedelta(hours=1)
    await engine.dispose()
