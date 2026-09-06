"""Import der Home-Assistant-Historie: Mapping, Statistik- und Zustandsexport, Zusammenführen mit Bestand."""

from __future__ import annotations

import gzip
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from dch_api.application.ha_import import (
    EntityRule,
    HaImporter,
    apply_prices,
    compute_hours,
    load_entity_rules,
    parse_dump,
)
from hems_core.accounting import HourlyEnergy
from hems_core.domain import HemsConfig
from hems_core.planning import PricePoint
from hems_core.protocol import RawReading

ROOT = Path(__file__).resolve().parents[3]
RULES = load_entity_rules(ROOT / "config" / "entities.home.yaml")
T0 = datetime(2026, 8, 20, 10, 0, tzinfo=UTC)


def test_rules_from_house_mapping() -> None:
    assert RULES["sensor.myenergi_hub_14117600_power_grid"].key == "grid_power_kw"
    bat = RULES["sensor.myenergi_libbi_26244255_power_ct_internal_load"]
    assert bat.convert(445.0, None) == pytest.approx(-0.445)  # Laden → negativ
    assert RULES["sensor.myenergi_libbi_26244255_soc"].convert(58, None) == pytest.approx(0.58)
    extra = load_entity_rules(
        ROOT / "nicht-da.yaml",
        {"sensor.tibber": {"key": "electricity_price_ct_kwh", "unit": "EUR/kWh"}},
    )
    assert extra["sensor.tibber"].convert(0.3156, None) == pytest.approx(31.56)


def _stats_csv(step_s: int, hours: int) -> bytes:
    lines = ["statistic_id,unit_of_measurement,start_ts,mean,min,max,state,sum"]
    n = hours * 3600 // step_s
    for i in range(n):
        ts = T0.timestamp() + i * step_s
        lines.append(f"sensor.myenergi_hub_14117600_power_generation,W,{ts},4000,3900,4100,,")
        lines.append(f"sensor.myenergi_hub_14117600_power_grid,W,{ts},-1000,,,,")
        lines.append(f"sensor.myenergi_libbi_26244255_power_ct_internal_load,W,{ts},500,,,,")
        lines.append(f"sensor.heatpump_total_power,W,{ts},1500,,,,")
        lines.append(f"sensor.geilenkirchen_air_base_temperatur,°C,{ts},12.5,,,,")
        lines.append(f"sensor.unbekannt_xyz,W,{ts},1,,,,")
    return "\n".join(lines).encode()


def test_statistics_hourly_become_hours() -> None:
    dump = parse_dump(_stats_csv(3600, 2), RULES)
    assert dump.kind == "statistics" and dump.unmapped == {"sensor.unbekannt_xyz"}
    hours = compute_hours(dump, HemsConfig())
    assert len(hours) == 2
    h, temp = hours[0]
    assert h.minutes == 60 and temp == 12.5
    assert h.pv_kwh == pytest.approx(4.0)
    assert h.export_kwh == pytest.approx(1.0)
    assert h.battery_charge_kwh == pytest.approx(0.5)
    assert h.house_kwh == pytest.approx(2.5)  # 4 − 1 − 0,5
    assert h.heat_pump_kwh == pytest.approx(1.5)
    assert h.price_missing_minutes == 60


def test_statistics_short_term_and_gzip() -> None:
    dump = parse_dump(gzip.compress(_stats_csv(300, 1)), RULES)
    hours = compute_hours(dump, HemsConfig())
    assert len(hours) == 1 and hours[0][0].minutes == 60


def test_states_step_function_and_raw_readings() -> None:
    now = datetime.now(UTC).replace(second=0, microsecond=0)
    base = now - timedelta(hours=2)
    rows = ["entity_id,state,last_updated_ts"]
    for i, (pv, grid) in enumerate([(3000, -500), (3200, -700), (2800, -300)]):
        ts = (base + timedelta(minutes=10 * i)).timestamp()
        rows.append(f"sensor.myenergi_hub_14117600_power_generation,{pv},{ts}")
        rows.append(f"sensor.myenergi_hub_14117600_power_grid,{grid},{ts}")
    rows.append(
        f"sensor.myenergi_hub_14117600_power_grid,unavailable,{(base + timedelta(minutes=25)).timestamp()}"
    )
    dump = parse_dump("\n".join(rows).encode(), RULES)
    assert dump.kind == "states"
    pv = dump.minutes["pv_power_kw"]
    assert pv[base] == pytest.approx(3.0) and pv[base + timedelta(minutes=9)] == pytest.approx(3.0)
    assert pv[base + timedelta(minutes=10)] == pytest.approx(3.2)
    assert pv[base + timedelta(minutes=21)] == pytest.approx(
        2.8
    )  # letzter Wert läuft höchstens 20 min nach
    assert (base + timedelta(minutes=21)) in pv and (base + timedelta(minutes=41)) not in pv
    assert len(dump.readings) == 6 and all(r.source.startswith("ha-import:") for r in dump.readings)
    hours = compute_hours(dump, HemsConfig())
    assert sum(h.minutes for h, _ in hours) == 22


def test_apply_prices_fills_only_missing_minutes() -> None:
    dump = parse_dump(_stats_csv(3600, 1), RULES)
    dump.minutes["electricity_price_ct_kwh"][T0] = 99.0
    n = apply_prices(dump, [PricePoint(start=T0, end=T0 + timedelta(hours=1), ct_kwh=25.0)])
    assert n == 59 and dump.minutes["electricity_price_ct_kwh"][T0] == 99.0
    h, _ = compute_hours(dump, HemsConfig())[0]
    assert h.price_missing_minutes == 0
    assert h.import_cost_eur == 0.0 and h.export_revenue_eur == pytest.approx(0.08)


@pytest.mark.asyncio
async def test_importer_merges_with_existing_hours() -> None:
    written: list[HourlyEnergy] = []
    readings: list[RawReading] = []
    existing_full = HourlyEnergy(hour_start=T0, minutes=60, pv_kwh=9.9)
    existing_sparse = HourlyEnergy(hour_start=T0 + timedelta(hours=1), minutes=3)

    async def read_hours(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return [(existing_full, None), (existing_sparse, None)]

    async def write_hours(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def add_readings(items: list[RawReading]) -> None:
        readings.extend(items)

    async def prices(s: datetime, e: datetime) -> list[PricePoint]:
        return [
            PricePoint(start=T0 + timedelta(hours=i), end=T0 + timedelta(hours=i + 1), ct_kwh=30.0)
            for i in range(2)
        ]

    imp = HaImporter(
        HemsConfig(), RULES, read_hours, write_hours, add_readings, price_history=prices
    )
    res = await imp.run(_stats_csv(3600, 2))
    assert res.hours_computed == 2 and res.hours_written == 1 and res.hours_kept_existing == 1
    assert written[0].hour_start == T0 + timedelta(hours=1)
    assert res.price_minutes_from_tibber == 120 and res.minutes_without_price == 0
    assert res.unmapped == ["sensor.unbekannt_xyz"] and not readings

    dry = await imp.run(_stats_csv(3600, 2), dry_run=True)
    assert dry.dry_run and dry.hours_written == 0 and len(written) == 1


def test_unknown_format_is_rejected() -> None:
    with pytest.raises(ValueError):
        parse_dump(b"a,b\n1,2\n", {"x": EntityRule(key="pv_power_kw", entity="x")})
