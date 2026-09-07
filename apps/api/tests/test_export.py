"""Der Export ist die einzige Kopie außerhalb der Datenbank. Er muss eine Datei liefern, die sich
Jahre später ohne dieses Programm wieder lesen lässt."""

from __future__ import annotations

import csv
import gzip
import io
import json
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings

AUTH = {"authorization": "Bearer api-geheim"}
NOW = datetime(2026, 9, 7, 10, 0, tzinfo=UTC)


@pytest.fixture
def live_client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'export.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    app = create_app(settings)
    with TestClient(app) as c:
        yield c


def test_export_is_a_readable_gzip_csv(live_client: TestClient) -> None:
    r = live_client.get("/api/v1/export/minutes?year=2026", headers=AUTH)
    assert r.status_code == 200, r.text
    assert r.headers["content-type"].startswith("application/gzip")
    assert 'filename="dch-minuten-2026.csv.gz"' in r.headers["content-disposition"]
    text = gzip.decompress(r.content).decode("utf-8")
    header = next(csv.reader(io.StringIO(text)))
    # Die Kopfzeile ist der Vertrag mit dem Archiv: Zeitstempel, jede Reihe, dann der Rest.
    assert header[0] == "ts" and header[-1] == "extra"
    assert "pv_power_kw" in header and "buffer_temp_top_c" in header


def test_hours_export_has_its_own_name_and_columns(live_client: TestClient) -> None:
    r = live_client.get("/api/v1/export/hours?year=2026", headers=AUTH)
    assert r.status_code == 200, r.text
    assert 'filename="dch-stunden-2026.csv.gz"' in r.headers["content-disposition"]
    header = next(csv.reader(io.StringIO(gzip.decompress(r.content).decode("utf-8"))))
    assert header[0] == "hour_start"
    assert "self_consumption_value_eur" in header and "export_revenue_eur" in header


def test_custom_range_needs_both_ends_and_stays_bounded(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/export/minutes", headers=AUTH).status_code == 422
    r = live_client.get(
        "/api/v1/export/minutes?start=2026-01-01T00:00:00Z&end=2020-01-01T00:00:00Z", headers=AUTH
    )
    assert r.status_code == 422
    r = live_client.get(
        "/api/v1/export/minutes?start=2000-01-01T00:00:00Z&end=2026-01-01T00:00:00Z", headers=AUTH
    )
    assert r.status_code == 422 and "800" in json.dumps(r.json())


def test_export_needs_the_api_token(live_client: TestClient) -> None:
    assert live_client.get("/api/v1/export/minutes?year=2026").status_code == 401


def test_export_is_refused_in_demo_mode(client: TestClient) -> None:
    r = client.get("/api/v1/export/minutes?year=2026")
    assert r.status_code == 400 and "Live" in json.dumps(r.json())
