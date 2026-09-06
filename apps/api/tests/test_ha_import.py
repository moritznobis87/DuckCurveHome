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
    existing_full = HourlyEnergy(hour_start=T0, minutes=40, pv_kwh=9.9)  # direkt gemessen → bleibt
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


def test_influx_csv_minute_means() -> None:
    lines = ["name,tags,time,mean"]
    for i in range(120):
        ts = int((T0 + timedelta(minutes=i)).timestamp())
        lines.append(f"W,entity_id=myenergi_hub_14117600_power_generation,{ts},3000")
        lines.append(f"W,entity_id=myenergi_hub_14117600_power_grid,{ts},-1500")
    dump = parse_dump("\n".join(lines).encode(), RULES)
    assert dump.kind == "statistics" and not dump.unmapped
    assert "sensor.myenergi_hub_14117600_power_generation" in dump.entities
    hours = compute_hours(dump, HemsConfig())
    assert len(hours) == 2 and hours[0][0].minutes == 60
    assert hours[0][0].pv_kwh == pytest.approx(3.0) and hours[0][0].export_kwh == pytest.approx(1.5)

    # Nanosekunden-Zeitstempel (Influx-Standard) werden erkannt
    ns = [
        "name,tags,time,mean",
        f"W,entity_id=myenergi_hub_14117600_power_generation,{int(T0.timestamp()) * 10**9},1000",
    ]
    d2 = parse_dump("\n".join(ns).encode(), RULES)
    assert T0 in d2.minutes["pv_power_kw"]


def test_chronograf_csv_with_price_and_night_fill() -> None:
    """Chronograf-Export: ISO-Zeit mit Zeitzone, Spalten je Einheit, „-“ für leer; PV fehlt nachts (0 W bleibt)."""
    rules = load_entity_rules(
        ROOT / "config" / "entities.home.yaml",
        {
            "sensor.electricity_price_waldstrasse_48": {
                "key": "electricity_price_ct_kwh",
                "unit": "EUR/kWh",
            }
        },
    )
    lines = ['"time","EUR/kWh.mean","W.mean","entity_id","entity_id_2"']
    # 15-min-Raster ab 20:00 lokal (+02:00): Netz jede Viertelstunde, PV nur bis 20:15 (danach 0 W → keine Zeilen)
    for i in range(8):
        hh, mm = 20 + i // 4, (i % 4) * 15
        t = f"2026-08-10T{hh:02d}:{mm:02d}:00.000+02:00"
        lines.append(f'"{t}","-","500","myenergi_hub_14117600_power_grid","-"')
        if i < 2:
            lines.append(
                f'"{t}","-","{1200 if i == 0 else 0}","myenergi_hub_14117600_power_generation","-"'
            )
    # nächster PV-Punkt erst am Morgen: dazwischen bleibt 0 W stehen
    lines.append(
        '"2026-08-11T06:30:00.000+02:00","-","800","myenergi_hub_14117600_power_generation","-"'
    )
    lines.append(
        '"2026-08-10T20:00:00.000+02:00","0.25","-","-","electricity_price_waldstrasse_48"'
    )
    lines.append(
        '"2026-08-10T21:00:00.000+02:00","0.30","-","-","electricity_price_waldstrasse_48"'
    )
    dump = parse_dump("\n".join(lines).encode(), rules)
    assert dump.kind == "statistics" and not dump.unmapped
    t_utc = datetime(2026, 8, 10, 18, 0, tzinfo=UTC)
    pv = dump.minutes["pv_power_kw"]
    assert pv[t_utc] == pytest.approx(1.2)
    assert pv[t_utc + timedelta(minutes=14)] == pytest.approx(1.2)
    assert pv[t_utc + timedelta(minutes=15)] == 0.0
    assert (
        pv[t_utc + timedelta(hours=1, minutes=59)] == 0.0
    )  # 0 W wird über Stunden fortgeschrieben
    assert dump.minutes["electricity_price_ct_kwh"][t_utc + timedelta(minutes=59)] == pytest.approx(
        25.0
    )
    assert dump.minutes["electricity_price_ct_kwh"][t_utc + timedelta(hours=1)] == pytest.approx(
        30.0
    )
    hours = compute_hours(dump, HemsConfig())
    assert len(hours) == 2 and all(h.minutes == 60 for h, _ in hours)
    h0, _ = hours[0]
    assert h0.import_kwh == pytest.approx(0.5) and h0.price_missing_minutes == 0
    assert h0.import_cost_eur == pytest.approx(0.125)


def test_nonzero_value_is_not_carried_far() -> None:
    lines = ["statistic_id,unit_of_measurement,start_ts,mean,min,max,state,sum"]
    ts = T0.timestamp()
    lines.append(f"sensor.myenergi_hub_14117600_power_generation,W,{ts},3000,,,,")
    lines.append(f"sensor.myenergi_hub_14117600_power_generation,W,{ts + 4 * 3600},3000,,,,")
    dump = parse_dump("\n".join(lines).encode(), RULES)
    pv = dump.minutes["pv_power_kw"]
    assert (T0 + timedelta(minutes=59)) in pv and (
        T0 + timedelta(hours=1)
    ) not in pv  # 3 kW höchstens 1 h


def test_concatenated_sections_merge_into_one_dump() -> None:
    a = _stats_csv(3600, 1).decode()
    b = (
        '"time","entity_id","°C.mean"\n'
        '"2026-08-20T12:30:00.000+02:00","geilenkirchen_air_base_temperatur","18.5"\n'
    )
    dump = parse_dump((a + "\n" + b).encode(), RULES)
    assert dump.kind == "statistics"
    hours = compute_hours(dump, HemsConfig())
    assert len(hours) == 1 and hours[0][1] == 15.5  # Mittel aus 12,5 °C (1. Abschnitt) und 18,5 °C (2.)
