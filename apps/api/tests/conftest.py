from __future__ import annotations

import asyncio
import threading
import time
from collections.abc import AsyncIterator, Iterator
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncEngine

from dch_api.infrastructure.db import engine as db_engine
from dch_api.main import create_app
from dch_api.settings import Settings

#: So heißt der Faden, den aiosqlite je offener Verbindung führt.
VERBINDUNGSFADEN = "_connection_worker_thread"


def _verbindungsfaeden() -> set[threading.Thread]:
    return {t for t in threading.enumerate() if VERBINDUNGSFADEN in t.name}


@pytest.fixture(autouse=True)
async def datenbanken_schliessen(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[None]:
    """Jede Datenbank, die ein Test öffnet, schließt mit ihm - und sonst fällt der Test.

    **Warum es das gibt.** Bis zum 27.11.2026 schlossen 33 Tests in 8 Dateien ihre `AsyncEngine`
    nie: Sie bauen sie in einem Helfer (`_seed`, `baue`, `repos`), reichen sie in ein
    `SqlRepositories` und enden. aiosqlite führt je offener Verbindung einen Faden, und der
    blieb liegen, bis die Speicherbereinigung die Engine irgendwann fand. Erst dann schloss er
    die Datenbank, also in irgendeinem späteren Test.

    Aufgefallen ist das an den Zeittests der Wärmebilanz, die in der CI viermal rot wurden, an
    Ständen, die sie nicht berührten. Sie räumen vor jeder Messung auf (`gc.collect()`), und
    genau damit gaben sie zwei solche Fäden aus derselben Datei frei, die danach noch über eine
    halbe Sekunde im Schließen standen, quer durch die Messung. Nachgemessen, je fünfzehn
    Messungen der Nulllinie über 0,3 s: ohne liegengelassene Verbindung 27 bis 29 Schläge des
    Pulses und eine längste Pause von 10 bis 16 ms, mit zweien 17 bis 31 Schläge und eine
    längste Pause von 36 ms im Mittel und bis 63 ms. In der CI waren es fünf Schläge und 224 ms.

    **Wie es geht.** Der Dienst baut jede Engine an einer Stelle (`make_engine`), und die ruft
    `create_async_engine` aus ihrem Modul. Für die Dauer eines Tests merkt sich diese Fixture
    dort jede gebaute Engine und schließt sie am Ende. Ein zweites `dispose()` schadet nicht:
    Tests, die selbst schließen, und der Dienst, der es beim Herunterfahren tut, bleiben, wie
    sie sind.

    **Und die Kontrolle.** Bleibt nach dem Schließen ein Verbindungsfaden übrig, den es vor dem
    Test nicht gab, hat der Test eine Verbindung an dieser Fixture vorbei geöffnet, und er fällt
    mit dem Namen des Fadens. Ein Faden endet einen Augenblick nach seinem `close()`; darum wird
    bis zu zwei Sekunden gewartet, bevor das als Fund gilt.
    """
    vorher = _verbindungsfaeden()
    gebaut: list[AsyncEngine] = []
    echt = db_engine.create_async_engine

    def merken(*args: Any, **kwargs: Any) -> AsyncEngine:
        engine = echt(*args, **kwargs)
        gebaut.append(engine)
        return engine

    monkeypatch.setattr(db_engine, "create_async_engine", merken)
    yield
    for engine in gebaut:
        await engine.dispose()
    frist = time.monotonic() + 2.0
    while (uebrig := _verbindungsfaeden() - vorher) and time.monotonic() < frist:
        await asyncio.sleep(0.01)
    assert not uebrig, (
        "Dieser Test lässt eine SQLite-Verbindung offen: "
        + ", ".join(sorted(t.name for t in uebrig))
        + ". Jede Engine gehört über `make_engine` gebaut oder im Test selbst geschlossen."
    )


@pytest.fixture
def client() -> Iterator[TestClient]:
    settings = Settings(
        demo_autostart=False,
        demo_warmup_hours=26.0,
        demo_start=datetime(2026, 9, 4, 11, 30, tzinfo=UTC),
        demo_seed=3,
    )
    app = create_app(settings)
    with TestClient(app) as c:
        yield c
