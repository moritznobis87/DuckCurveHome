from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from hems_core.domain import AutoProfile, OperatingMode, Quality, SystemMode
from hems_core.protocol import RawReading

NOW = datetime(2026, 9, 4, 12, 0, tzinfo=UTC)


@pytest.fixture
async def repos(tmp_path: Path) -> SqlRepositories:
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'test.sqlite'}")
    await create_all_for_tests(engine)
    return SqlRepositories(engine)


async def test_readings_latest_and_minute_series(repos: SqlRepositories) -> None:
    items = [
        RawReading(key="pv_power_kw", value=4.0, observed_at=NOW, quality=Quality.OK, source="t"),
        RawReading(
            key="pv_power_kw",
            value=6.0,
            observed_at=NOW + timedelta(seconds=30),
            quality=Quality.OK,
            source="t",
        ),
        RawReading(
            key="pv_power_kw",
            value=8.0,
            observed_at=NOW + timedelta(seconds=70),
            quality=Quality.OK,
            source="t",
        ),
        RawReading(
            key="grid_power_kw",
            value=None,
            observed_at=NOW,
            quality=Quality.UNAVAILABLE,
            source="t",
        ),
    ]
    await repos.add_readings(items)
    await repos.add_readings(items[:1])  # Duplikat → Upsert, kein Fehler
    latest = {r.key: r for r in await repos.latest()}
    assert latest["pv_power_kw"].value == 8.0
    assert latest["grid_power_kw"].quality is Quality.UNAVAILABLE
    rows = await repos.minute_series(
        NOW - timedelta(minutes=1), NOW + timedelta(minutes=5), ["pv_power_kw", "grid_power_kw"]
    )
    assert len(rows) == 2
    assert rows[0]["pv_power_kw"] == 5.0 and rows[1]["pv_power_kw"] == 8.0
    assert rows[0]["grid_power_kw"] is None
    deleted = await repos.prune_raw(timedelta(days=0))
    assert deleted == 4


async def test_mode_config_events(repos: SqlRepositories) -> None:
    assert await repos.load_mode() is None
    await repos.save_mode(OperatingMode(system_mode=SystemMode.AUTO, auto_profile=AutoProfile.PV))
    mode = await repos.load_mode()
    assert mode is not None and mode.auto_profile is AutoProfile.PV
    await repos.save_config("control", {"pv": {"on_surplus_kw": 4.5}})
    await repos.save_config("control", {"pv": {"on_surplus_kw": 5.0}})
    assert (await repos.active_config("control")) == {"pv": {"on_surplus_kw": 5.0}}
    await repos.add_event("warning", "test", "hallo", {"a": "b"})
    events = await repos.recent_events(5)
    assert events[0].code == "test"
    await repos.add_bridge_credential("haus", "hash")
    assert await repos.bridge_token_valid("hash") and not await repos.bridge_token_valid("x")


async def test_calibration_roundtrip(repos: SqlRepositories) -> None:
    assert await repos.load_calibration("pv_forecast_v1") is None
    await repos.save_calibration("pv_forecast_v1", {"days_learned": 3, "bins": [1.0, 0.9]})
    await repos.save_calibration("pv_forecast_v1", {"days_learned": 4, "bins": [1.0, 0.88]})
    state = await repos.load_calibration("pv_forecast_v1")
    assert state == {"days_learned": 4, "bins": [1.0, 0.88]}


def test_normalize_url_strips_quotes_and_maps_driver() -> None:
    from dch_api.infrastructure.db.engine import describe_url_problem, normalize_url

    assert normalize_url(' "postgres://u:p@h:5432/db" ') == "postgresql+asyncpg://u:p@h:5432/db"
    assert describe_url_problem("") == "DATABASE_URL ist leer."
    assert "Referenz" in (describe_url_problem("${{Postgres.DATABASE_URL}}") or "")
    assert "Verbindungs-URL" in (describe_url_problem("abc123") or "")
    assert describe_url_problem("postgresql://u:p@h/db") is None


async def test_energy_hours_roundtrip(repos: SqlRepositories) -> None:
    from datetime import UTC, datetime, timedelta

    from hems_core.accounting import HourlyEnergy

    h0 = datetime(2026, 9, 6, 10, 0, tzinfo=UTC)
    hours = [
        HourlyEnergy(hour_start=h0 + timedelta(hours=i), minutes=60, pv_kwh=1.0 + i)
        for i in range(3)
    ]
    await repos.upsert_energy_hours(hours, {h0: 12.5})
    # Upsert überschreibt die bestehende Stunde statt zu duplizieren
    await repos.upsert_energy_hours([HourlyEnergy(hour_start=h0, minutes=60, pv_kwh=9.0)], {})
    rows = await repos.energy_hours(h0, h0 + timedelta(hours=3))
    assert [round(h.pv_kwh, 1) for h, _ in rows] == [9.0, 2.0, 3.0]
    assert rows[0][1] is None and (await repos.last_energy_hour()) == h0 + timedelta(hours=2)
