"""Der Platzbedarf der Datenbank muss von außen ablesbar sein.

Eine verwaltete Datenbank wird nach Arbeitsspeicher abgerechnet, und den belegt sie im Wesentlichen
mit ihrer eigenen Größe. Welche Tabelle das ist, lässt sich nicht erraten - und solange man rät,
optimiert man die falsche.
"""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings

AUTH = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'storage.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
        raw_retention_days=3,
    )
    with TestClient(create_app(settings)) as c:
        yield c


def test_the_endpoint_answers_and_names_the_retention(client: TestClient) -> None:
    r = client.get("/api/v1/system/storage", headers=AUTH)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["raw_retention_days"] == 3
    assert body["total_bytes"] == 0
    # Ohne PostgreSQL gibt es keine Größen, und der Text sagt das, statt eine leere Tabelle zu zeigen.
    assert body["tables"] == []
    assert "PostgreSQL" in body["note_de"]


def test_it_is_not_public(client: TestClient) -> None:
    assert client.get("/api/v1/system/storage").status_code == 401
