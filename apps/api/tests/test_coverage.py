"""Kam überhaupt etwas an? Die Verfügbarkeit ist eine eigene Frage, nicht Teil der Bilanz.

Der Unterschied, auf den es ankommt: eine Stunde ohne jede Minutenzeile ist **unser** Ausfall, eine
Stunde mit Minutenzeilen, in denen diese eine Reihe fehlt, ist der des Geräts. Die erste liefert
keine Zeile, die zweite eine mit der Zahl null. Wer beides gleich behandelt, schaut hinterher das
falsche Gerät an.
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
from dch_api.settings import Settings
from hems_core.domain import Quality
from hems_core.protocol import RawReading
from hems_core.simulation import BERLIN

AUTH = {"authorization": "Bearer api-geheim"}
DAY = datetime(2026, 9, 15, 0, 0, tzinfo=UTC)


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'cov.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def _series(body: dict, key: str) -> dict:
    return next(s for s in body["series"] if s["key"] == key)


def test_an_hour_without_any_row_differs_from_an_hour_without_this_series(
    client: TestClient,
) -> None:
    r = client.get("/api/v1/system/coverage?anchor=2026-09-15&days=2", headers=AUTH)
    assert r.status_code == 200, r.text
    body = r.json()
    meter = _series(body, "grid_power_meter_kw")
    # Ohne jede Minutenzeile gibt es auch keine Stundenzeile: die Karte lässt die Zelle leer,
    # statt eine Null zu behaupten, die das Gerät beschuldigt.
    assert meter["hours"] == []
    assert meter["coverage"] == 0.0
    assert meter["last_at"] is None


def test_the_counts_are_per_hour_and_per_series(client: TestClient) -> None:
    r = client.get("/api/v1/system/coverage?anchor=2026-09-15&days=1", headers=AUTH)
    assert r.status_code == 200
    assert {s["key"] for s in r.json()["series"]} == {
        "grid_power_meter_kw",
        "grid_power_kw",
        "door_lock_online",
    }
    assert all(s["label_de"] for s in r.json()["series"])


def _kalendertage(body: dict[str, object]) -> int:
    """Die Spanne in Kalendertagen am Ort, nicht in Vielfachen von 24 Stunden.

    **Zweimal im Jahr ist ein Tag keine 24 Stunden.** Die Grenzen des Zeitraums liegen auf
    Mitternacht in Geilenkirchen; über eine Zeitumstellung hinweg sind 90 Kalendertage in
    absoluter Zeit 90 Tage und eine Stunde. Ein Test auf exakte Gleichheit scheiterte deshalb an
    genau zwei Tagen im Jahr - gesehen am 25.10.2026, dem Tag der Rückstellung.
    """
    start = datetime.fromisoformat(str(body["start"])).astimezone(BERLIN)
    end = datetime.fromisoformat(str(body["end"])).astimezone(BERLIN)
    return (end.date() - start.date()).days


def test_the_window_ends_on_the_anchor_day(client: TestClient) -> None:
    r = client.get("/api/v1/system/coverage?anchor=2026-09-15&days=7", headers=AUTH)
    body = r.json()
    assert body["end"].startswith("2026-09-15T22:00") or body["end"].startswith("2026-09-16")
    assert _kalendertage(body) == 7


def test_the_span_is_capped(client: TestClient) -> None:
    body = client.get("/api/v1/system/coverage?days=9999", headers=AUTH).json()
    assert _kalendertage(body) == 90
    body = client.get("/api/v1/system/coverage?days=0", headers=AUTH).json()
    assert _kalendertage(body) == 1


def test_it_is_not_public(client: TestClient) -> None:
    assert client.get("/api/v1/system/coverage").status_code == 401


async def test_the_counting_separates_the_two_series(tmp_path: Path) -> None:
    """Dieselbe Stunde, zwei Reihen: die eine vollständig, die andere nur zum Teil."""
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'count.sqlite'}")
    await create_all_for_tests(engine)
    repos = SqlRepositories(engine)
    items = []
    for i in range(30):
        ts = DAY + timedelta(minutes=i, seconds=10)
        items.append(
            RawReading(
                key="grid_power_kw", value=1.0, observed_at=ts, quality=Quality.OK, source="t"
            )
        )
        if i >= 20:
            items.append(
                RawReading(
                    key="grid_power_meter_kw",
                    value=1.0,
                    observed_at=ts,
                    quality=Quality.OK,
                    source="t",
                )
            )
    await repos.add_readings(items)
    await repos.rollup_minutes(DAY, DAY + timedelta(hours=1))

    cov = await repos.hourly_coverage(
        ["grid_power_kw", "grid_power_meter_kw"], DAY, DAY + timedelta(hours=1)
    )
    assert [n for _, n in cov["grid_power_kw"]] == [30]
    # Die Stunde steht da, der Zähler fehlt in zwanzig ihrer Minuten. Genau dieser Unterschied
    # trennt "der Dienst stand still" von "das Gerät lieferte nichts".
    assert [n for _, n in cov["grid_power_meter_kw"]] == [10]
    assert await repos.last_value_at("grid_power_meter_kw") == DAY + timedelta(minutes=29)
    assert await repos.last_value_at("gibt_es_nicht") is None
