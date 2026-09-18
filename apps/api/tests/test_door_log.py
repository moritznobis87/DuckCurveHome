"""Das Türprotokoll in der Oberfläche: mitlesen, nicht öffnen.

Der wichtigste Test ist `test_there_is_no_way_to_the_door_from_here`. Er hält fest, was der Entwurf
verspricht: die Cloud sieht die Tür, sie erreicht sie nicht. Ein Endpunkt, der öffnen könnte, wäre
eine Haustür am Internet - und solche Versprechen verfallen still, wenn sie niemand prüft.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.main import create_app
from dch_api.routers.system import DOOR_EVENT_CODE
from dch_api.settings import Settings

AUTH = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'door.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def test_an_empty_log_says_so_instead_of_staying_blank(client: TestClient) -> None:
    body = client.get("/api/v1/system/door", headers=AUTH).json()
    assert body["entries"] == []
    assert "Noch kein Zutritt" in body["note_de"]


def test_it_is_not_public(client: TestClient) -> None:
    """Namen aus dem Haushalt. Die Anmeldung ist hier keine Formsache."""
    assert client.get("/api/v1/system/door").status_code == 401


def test_there_is_no_way_to_the_door_from_here(client: TestClient) -> None:
    for method in ("post", "put", "delete", "patch"):
        r = getattr(client, method)("/api/v1/system/door", headers=AUTH)
        assert r.status_code == 405, f"{method} darf nicht gehen, bekam {r.status_code}"


def test_the_span_is_capped(client: TestClient) -> None:
    assert client.get("/api/v1/system/door?days=9999", headers=AUTH).json()["days"] == 90
    assert client.get("/api/v1/system/door?days=0", headers=AUTH).json()["days"] == 1


async def _repos(tmp_path: Path) -> SqlRepositories:
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'entries.sqlite'}")
    await create_all_for_tests(engine)
    return SqlRepositories(engine)


async def test_the_youngest_entry_comes_first(tmp_path: Path) -> None:
    repos = await _repos(tmp_path)
    now = datetime.now(UTC)
    for i in range(3):
        await repos.add_event(
            "info", DOOR_EVENT_CODE, f"Eintrag {i}", {"actor": f"P{i}"}, at=now - timedelta(hours=i)
        )
    rows = await repos.events_by_code(DOOR_EVENT_CODE, now - timedelta(days=1), 10)
    assert [r.message for r in rows] == ["Eintrag 0", "Eintrag 1", "Eintrag 2"]


async def test_the_limit_cuts_the_oldest_not_the_newest(tmp_path: Path) -> None:
    """Sonst zeigt ein volles Protokoll die Woche von vorletztem Monat."""
    repos = await _repos(tmp_path)
    now = datetime.now(UTC)
    for i in range(5):
        await repos.add_event(
            "info", DOOR_EVENT_CODE, f"Eintrag {i}", {}, at=now - timedelta(hours=i)
        )
    rows = await repos.events_by_code(DOOR_EVENT_CODE, now - timedelta(days=1), 2)
    assert [r.message for r in rows] == ["Eintrag 0", "Eintrag 1"]


async def test_events_of_other_codes_stay_out(tmp_path: Path) -> None:
    repos = await _repos(tmp_path)
    now = datetime.now(UTC)
    await repos.add_event("info", DOOR_EVENT_CODE, "Tür", {}, at=now)
    await repos.add_event("info", "libbi_state", "Speicher", {}, at=now)
    rows = await repos.events_by_code(DOOR_EVENT_CODE, now - timedelta(days=1), 10)
    assert [r.message for r in rows] == ["Tür"]
