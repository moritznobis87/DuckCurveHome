from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.infrastructure.live_state import LiveState
from hems_core.domain import HemsConfig, Quality
from hems_core.protocol import RawReading

NOW = datetime(2026, 9, 4, 12, 0, tzinfo=UTC)


def reading(key: str, value: float, at: datetime = NOW) -> RawReading:
    return RawReading(key=key, value=value, observed_at=at, quality=Quality.OK, source=f"ha:{key}")


def test_snapshot_derives_house_and_ages_values() -> None:
    ls = LiveState(HemsConfig())
    ls.apply(
        [
            reading("pv_power_kw", 6.0),
            reading("grid_power_kw", -3.0),
            reading("battery_power_kw", -1.0),
            reading("battery_soc", 0.9),
            reading("heat_pump_power_kw", 0.0),
            reading("ev_power_kw", 0.0),
        ]
    )
    snap = ls.snapshot(NOW)
    assert snap.house_power_kw.value == 2.0 and snap.house_power_kw.quality is Quality.DERIVED
    assert snap.buffer_temps_c.top.quality is Quality.UNAVAILABLE
    later = ls.snapshot(NOW + timedelta(minutes=3))
    assert later.pv_power_kw.quality is Quality.STALE
    assert later.house_power_kw.quality is Quality.UNAVAILABLE


def test_newer_reading_wins_and_actuators_map() -> None:
    ls = LiveState(HemsConfig())
    ls.apply(
        [reading("pv_power_kw", 1.0, NOW), reading("pv_power_kw", 2.0, NOW - timedelta(seconds=5))]
    )
    assert ls.readings["pv_power_kw"].value == 1.0
    ls.apply([reading("actuator:coffee_machine", 1.0), reading("actuator:hp_release_contact", 0.0)])
    snap = ls.snapshot(NOW)
    assert snap.actuators["coffee_machine"].value == 1.0
    assert snap.hp_release_contact.value == 0.0
