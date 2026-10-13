"""Die Wärmebilanz über den Endpunkt: kommt der Ofen an, und geht die Rechnung auf.

Der wichtigste Test ist `test_der_ofen_kommt_in_der_bilanz_an`. Bis zu dieser Fassung las die
Ofenauswertung über `ENERGY_KEYS`, und dort steht keine einzige Ofenspalte: im Live-Betrieb meldete
sie „keine Ofendaten", während die Spalten in der Minutentabelle gefüllt dastanden. Ein Fehler, den
kein Test gesehen hat, weil im Demo-Betrieb alle Spalten kommen.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.application.energy_accounting import ENERGY_KEYS, HEAT_KEYS
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.domain import Quality
from hems_core.protocol import RawReading

AUTH = {"authorization": "Bearer api-geheim"}
# Ortszeit Berlin: 6 Uhr des 12.10.2026 ist 4 Uhr UTC.
TAG = "2026-10-12"
START = datetime(2026, 10, 12, 4, 0, tzinfo=UTC)


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'waerme.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def test_die_ofenspalten_fehlen_in_der_bilanzliste_und_stehen_in_der_waermeliste() -> None:
    """Die Trennung ist Absicht, und genau deshalb muss sie festgehalten sein."""
    assert not [k for k in ENERGY_KEYS if k.startswith("stove_")]
    assert "stove_running" in HEAT_KEYS
    assert "stove_power_level" in HEAT_KEYS
    assert "stove_ambient_temp_c" in HEAT_KEYS
    assert set(ENERGY_KEYS) <= set(HEAT_KEYS)


async def _seed(tmp_path: Path, minuten: int = 120) -> SqlRepositories:
    """Zwei Stunden Haus: Wärmepumpe läuft, Ofen brennt, Puffer kühlt langsam aus."""
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'seed.sqlite'}")
    await create_all_for_tests(engine)
    repos = SqlRepositories(engine)
    items: list[RawReading] = []
    for i in range(minuten):
        ts = START + timedelta(minutes=i, seconds=10)
        temp = 52.0 - 0.02 * i
        werte = {
            "heat_pump_power_kw": 2.0,
            "outdoor_temp_c": 4.0,
            "buffer_temp_top_c": temp,
            "buffer_temp_mid_top_c": temp - 1,
            "buffer_temp_mid_bottom_c": temp - 2,
            "buffer_temp_bottom_c": temp - 3,
            "stove_running": 1.0,
            "stove_power_level": 5.0,
            "stove_ambient_temp_c": 21.0,
        }
        items.extend(
            RawReading(key=k, value=v, observed_at=ts, quality=Quality.OK, source="t")
            for k, v in werte.items()
        )
    await repos.add_readings(items)
    await repos.rollup_minutes(START, START + timedelta(minutes=minuten))
    return repos


async def test_der_ofen_kommt_in_der_bilanz_an(tmp_path: Path) -> None:
    repos = await _seed(tmp_path)
    rows = await repos.minute_series(START, START + timedelta(hours=2), HEAT_KEYS)
    assert rows, "ohne Minutenzeilen sagt der Test nichts"
    assert any(r.get("stove_running") == 1.0 for r in rows)
    assert any(r.get("stove_power_level") == 5.0 for r in rows)
    # Und über die schmale Liste eben nicht: das ist der Fehler, den die Trennung behebt.
    schmal = await repos.minute_series(START, START + timedelta(hours=2), ENERGY_KEYS)
    assert all("stove_running" not in r for r in schmal)


def test_ein_leerer_tag_antwortet_mit_null_und_einem_satz(client: TestClient) -> None:
    r = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["totals"]["heat_pump_kwh"] == 0.0
    assert body["note_de"]
    assert body["params"]["buffer_volume_liters"] > 0


def test_die_annahmen_stehen_im_bericht(client: TestClient) -> None:
    """Eine gerechnete Wärmemenge ohne ihre Annahmen ist keine Zahl, sondern eine Behauptung."""
    body = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    p = body["params"]
    assert p["cop_curve"], "ohne Kennlinie keine Wärmepumpenwärme"
    assert p["stove_water_heat_kw"] > 0
    assert p["pellet_kwh_per_kg"] > 0
    assert "Ofen" in p["room_source_de"]


def test_es_ist_nicht_oeffentlich(client: TestClient) -> None:
    assert client.get("/api/v1/energy/waermebilanz").status_code == 401


def test_ein_jahr_wird_nicht_aus_minuten_gerechnet(client: TestClient) -> None:
    """525 000 Minutenzeilen für zwölf Balken sind keine Auswertung, sondern ein Ausfall.

    Lange Zeiträume kommen deshalb aus den Stundeneingängen. Liegen keine vor, sagt der Bericht das,
    statt eine Null zu zeigen, die wie eine Messung aussieht.
    """
    body = client.get(f"/api/v1/energy/waermebilanz?period=year&anchor={TAG}", headers=AUTH).json()
    assert "Minuten" not in body["resolution_de"]
    assert body["series"] == []


def test_der_tag_hat_einen_verlauf_und_die_woche_nicht(client: TestClient) -> None:
    tag = client.get(f"/api/v1/energy/waermebilanz?period=day&anchor={TAG}", headers=AUTH).json()
    woche = client.get(f"/api/v1/energy/waermebilanz?period=week&anchor={TAG}", headers=AUTH).json()
    assert tag["resolution_de"].startswith("aus Minuten")
    assert woche["series"] == []


async def test_die_stundeneingaenge_entstehen_aus_den_minuten(tmp_path: Path) -> None:
    """Der Weg für lange Zeiträume: Minuten einmal verdichten, danach Stunden lesen."""
    from datetime import date

    from dch_api.application.energy_accounting import HEAT_KEYS, EnergyAccounting
    from hems_core.domain import HemsConfig
    from hems_core.simulation import BERLIN

    repos = await _seed(tmp_path)
    acc = EnergyAccounting(
        HemsConfig(),
        BERLIN,
        lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
        heat_store=(repos.heat_hours, repos.upsert_heat_hours),
    )
    n = await acc.refresh_heat_hours(START, START + timedelta(hours=2))
    assert n == 2
    stunden = await repos.heat_hours(START, START + timedelta(hours=2))
    assert len(stunden) == 2
    assert stunden[0].electric_kwh == 2.0  # eine Stunde mal zwei Kilowatt
    assert stunden[0].stove_minutes == 60
    assert stunden[0].buffer_top_c is not None and stunden[0].buffer_top_c > 50.0

    # Und die Jahresrechnung findet sie dann auch.
    bericht = await acc.heat_balance("year", date(2026, 10, 12), START + timedelta(hours=3))
    assert "Stunden" in bericht.resolution_de
    assert bericht.totals.heat_pump_kwh > 0
    assert bericht.totals.stove_water_kwh > 0
