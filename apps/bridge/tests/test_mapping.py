from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

from dch_bridge.mapping import ActuatorMap, EntityMap, SensorMap, normalize
from hems_core.domain import Quality

NOW = datetime(2026, 9, 4, 12, 0, tzinfo=UTC)


def test_watt_to_kw_and_sign() -> None:
    grid = SensorMap(key="grid_power_kw", entity="sensor.grid", unit="W", sign="import_positive")
    r = normalize(grid, "-2400", {}, NOW, NOW)
    assert r.value == -2.4 and r.quality is Quality.OK
    bat = SensorMap(key="battery_power_kw", entity="sensor.bat", unit="W", sign="charge_positive")
    assert normalize(bat, "1500", {}, NOW, NOW).value == -1.5  # laden → negativ


def test_percent_price_and_binary() -> None:
    soc = SensorMap(key="battery_soc", entity="sensor.soc", unit="%")
    assert normalize(soc, "87", {}, NOW, NOW).value == 0.87
    price = SensorMap(key="electricity_price_ct_kwh", entity="sensor.price", unit="EUR/kWh")
    assert normalize(price, "0.2941", {}, NOW, NOW).value == 29.41
    act = ActuatorMap(key="coffee_machine", entity="switch.coffee", label="Kaffee")
    r = normalize(act, "on", {}, NOW, NOW)
    assert r.key == "actuator:coffee_machine" and r.value == 1.0


def test_unavailable_unknown_and_stale() -> None:
    s = SensorMap(key="pv_power_kw", entity="sensor.pv", unit="W", stale_after_s=60)
    assert normalize(s, "unavailable", {}, NOW, NOW).quality is Quality.UNAVAILABLE
    assert normalize(s, "unknown", {}, NOW, NOW).quality is Quality.UNKNOWN
    assert normalize(s, "abc", {}, NOW, NOW).quality is Quality.UNKNOWN
    old = normalize(s, "1000", {}, NOW - timedelta(minutes=5), NOW)
    assert old.quality is Quality.STALE and old.value == 1.0


def test_unit_from_attributes_and_yaml_load(tmp_path: Path) -> None:
    s = SensorMap(key="pv_power_kw", entity="sensor.pv")
    assert normalize(s, "2500", {"unit_of_measurement": "W"}, NOW, NOW).value == 2.5
    p = tmp_path / "entities.yaml"
    p.write_text(
        "sensors:\n  - {key: pv_power_kw, entity: sensor.pv, unit: W}\n"
        "actuators:\n  - {key: coffee_machine, entity: switch.c, label: Kaffee}\n"
    )
    em = EntityMap.load(p)
    assert em.keys() == ["pv_power_kw", "actuator:coffee_machine"]
    assert len(em.digest()) == 16
