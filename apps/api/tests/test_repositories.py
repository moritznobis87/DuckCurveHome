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
