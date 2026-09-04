from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.balance import balance
from hems_core.domain import BalanceConfig, Quality
from hems_core.simulation import DemoConfig, new_demo_house


def run_day(seed: int = 7):
    house = new_demo_house(datetime(2026, 9, 3, 22, 0, tzinfo=UTC), DemoConfig(seed=seed))
    snaps = []
    for _ in range(24 * 60):  # 24 h in Minutenschritten
        house.step(60)
        snaps.append(house.snapshot())
    return house, snaps


def test_pv_has_day_night_cycle_and_respects_inverter_limit() -> None:
    _, snaps = run_day()
    pv = [s.pv_power_kw.value or 0 for s in snaps]
    assert max(pv) > 2.0
    night = [
        v for s, v in zip(snaps, pv, strict=True) if s.timestamp.astimezone().hour in (1, 2, 3)
    ]
    assert all(v == 0 for v in night)
    assert max(pv) <= 8.25 + 1e-6


def test_energy_balance_holds_every_step() -> None:
    _, snaps = run_day()
    for s in snaps:
        r = balance(
            now=s.timestamp,
            pv=s.pv_power_kw,
            grid=s.grid_power_kw,
            battery=s.battery_power_kw,
            heat_pump=s.heat_pump_power_kw,
            ev=s.ev_power_kw,
            house_measured=None,
            cfg=BalanceConfig(),
        )
        assert r.consistent
        assert (r.base_load_kw.value or 0) >= 0


def test_buffer_stays_stratified_and_within_bounds() -> None:
    _, snaps = run_day()
    for s in snaps:
        t = [m.value or 0 for m in s.buffer_temps_c.as_list()]
        assert min(t) >= 12.0 and max(t) <= 66.0
        assert t[0] >= t[1] - 1e-6 >= t[2] - 2e-6 >= t[3] - 3e-6
    # Wärmepumpe ist irgendwann gelaufen (Warmwasser) …
    assert any((s.heat_pump_power_kw.value or 0) > 3.0 for s in snaps)


def test_release_contact_makes_heat_pump_run_and_ttl_expires() -> None:
    house = new_demo_house(datetime(2026, 9, 4, 10, 0, tzinfo=UTC))
    house.temps = [50.0, 48.0, 44.0, 38.0]
    house.hp_stopped_at = house.now - timedelta(hours=1)
    house.set_actuator("hp_release_contact", True, ttl_s=1200)
    for _ in range(5):
        house.step(60)
    assert house.hp_running
    assert house.snapshot().hp_release_contact.value == 1.0
    for _ in range(20):
        house.step(60)
    assert house.k1 is False  # TTL abgelaufen


def test_block_contact_stops_heat_pump_unless_frost() -> None:
    house = new_demo_house(datetime(2026, 9, 4, 10, 0, tzinfo=UTC))
    house.temps = [40.0, 38.0, 35.0, 30.0]  # unter 45 → eigene Regelung will laufen
    house.set_actuator("hp_block_contact", True, ttl_s=3600)
    for _ in range(10):
        house.step(60)
    assert not house.hp_running


def test_prices_daily_and_tomorrow_after_13() -> None:
    house = new_demo_house(datetime(2026, 9, 4, 9, 0, tzinfo=UTC))
    assert len(house.prices_available(house.now)) == 24
    assert len(house.prices_available(datetime(2026, 9, 4, 12, 30, tzinfo=UTC))) == 48
    a = house.prices_for_day(house.local().date())
    b = house.prices_for_day(house.local().date())
    assert a == b  # deterministisch


def test_fault_injection_marks_quality() -> None:
    house = new_demo_house(datetime(2026, 9, 4, 9, 0, tzinfo=UTC))
    house.step(10)
    house.inject_fault("grid_power_kw", Quality.UNAVAILABLE, 120)
    s = house.snapshot()
    assert s.grid_power_kw.quality is Quality.UNAVAILABLE and s.grid_power_kw.value is None
    house.step(200)
    assert house.snapshot().grid_power_kw.quality is Quality.OK
