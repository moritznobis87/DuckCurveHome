"""Neuberechnung darf Verbraucher nicht verlieren, die nur eine andere Quelle kennt."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from dch_api.application.energy_accounting import EnergyAccounting, merge_hour
from hems_core.accounting import HourlyEnergy
from hems_core.domain import HemsConfig
from hems_core.simulation import BERLIN

HOUR = datetime(2026, 4, 15, 12, 0, tzinfo=UTC)


def test_merge_keeps_consumer_the_new_calculation_cannot_see() -> None:
    old = HourlyEnergy(
        hour_start=HOUR,
        minutes=60,
        house_kwh=3.0,
        heat_pump_kwh=2.0,
        heat_pump_grid_kwh=2.0,
        heat_pump_cost_eur=0.6,
        base_kwh=1.0,
    )
    new = HourlyEnergy(hour_start=HOUR, minutes=60, house_kwh=5.0, base_kwh=5.0)
    merged = merge_hour(new, old)
    assert merged.heat_pump_kwh == pytest.approx(2.0)  # aus der gespeicherten Stunde übernommen
    assert merged.heat_pump_cost_eur == pytest.approx(0.6)
    assert merged.house_kwh == pytest.approx(5.0)  # bessere Bilanz der neuen Messung bleibt
    assert merged.base_kwh == pytest.approx(3.0)  # Rest um die Wärmepumpe verkleinert


def test_merge_does_not_override_a_measured_consumer() -> None:
    old = HourlyEnergy(hour_start=HOUR, minutes=60, heat_pump_kwh=2.0, house_kwh=3.0)
    new = HourlyEnergy(hour_start=HOUR, minutes=60, heat_pump_kwh=1.5, house_kwh=4.0, base_kwh=2.5)
    assert merge_hour(new, old).heat_pump_kwh == pytest.approx(1.5)
    assert merge_hour(new, None) is new


@pytest.mark.asyncio
async def test_recompute_carries_heat_pump_forward() -> None:
    """myenergi-Backfill (nur PV, Netz, Batterie, Wallbox) darf die Wärmepumpe der Stunde nicht löschen."""
    written: list[HourlyEnergy] = []
    stored = HourlyEnergy(
        hour_start=HOUR,
        minutes=60,
        house_kwh=3.0,
        heat_pump_kwh=2.0,
        heat_pump_grid_kwh=2.0,
        base_kwh=1.0,
    )

    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return [
            {
                "ts": (HOUR + timedelta(minutes=i)).isoformat().replace("+00:00", "Z"),
                "pv_power_kw": 4.0,
                "grid_power_kw": 1.0,
            }
            for i in range(60)
        ]

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return [(stored, 12.5)]

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def last() -> datetime | None:
        return None

    acc = EnergyAccounting(HemsConfig(), BERLIN, minute_rows, store=(read, write, last))
    n = await acc.recompute(HOUR, HOUR + timedelta(hours=1))
    assert n == 1 and len(written) == 1
    h = written[0]
    assert h.house_kwh == pytest.approx(5.0)  # PV 4 + Netz 1, aus den Minutenwerten
    assert h.heat_pump_kwh == pytest.approx(2.0)  # erhalten geblieben
    assert h.base_kwh == pytest.approx(3.0)


@pytest.mark.asyncio
async def test_luecken_im_minutenraster_kosten_keine_energie_mehr() -> None:
    """Der Befund vom 08.09.: nachts meldet die Quelle nur jede dritte Minute.

    Der Speicher trug das Haus mit gleichmäßigen 0,36 kW. Gezählt wurde vorher nur, was eine
    Minutenzeile hatte - ein Drittel. Auf der Seite standen 0,6 statt 1,7 kWh und daraus ein
    Wirkungsgrad von 11 %.
    """
    written: list[HourlyEnergy] = []

    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return [
            {
                "ts": (HOUR + timedelta(minutes=i)).isoformat().replace("+00:00", "Z"),
                "pv_power_kw": 0.0,
                "grid_power_kw": 0.0,
                "battery_power_kw": 0.36,
            }
            for i in range(0, 60, 3)
        ]

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return []

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def last() -> datetime | None:
        return None

    acc = EnergyAccounting(HemsConfig(), BERLIN, minute_rows, store=(read, write, last))
    await acc.recompute(HOUR, HOUR + timedelta(hours=1))
    h = written[0]
    assert h.minutes >= 58, "die Stunde ist abgedeckt, nicht nur zu einem Drittel"
    assert h.battery_discharge_kwh == pytest.approx(0.36, abs=0.02)
    assert h.battery_to_house_kwh == pytest.approx(0.36, abs=0.02)


@pytest.mark.asyncio
async def test_repair_coarse_nimmt_erfundene_netzladung_zurueck() -> None:
    """Der Befund vom 08.09.: Januar und Februar melden Netzladung, die es nie gab.

    Diese Monate stammen aus dem Historienimport und liegen nur als Stundenmittel vor; Minutenzeilen
    gibt es dafür nicht. Im Mittel einer Stunde löschen sich der PV-Überschuss der Sonnenminuten und
    der Netzbezug der Wolkenminuten gegenseitig aus, und die Differenz erschien als Netzladung des
    Speichers. Die Reparatur ordnet aus den gespeicherten Summen neu zu.
    """
    written: list[HourlyEnergy] = []
    # So sah die Stunde gespeichert aus: 1,47 kWh PV, 0,20 kWh Bezug, 0,67 kWh geladen - und daraus
    # 0,20 kWh angebliche Netzladung.
    stored = HourlyEnergy(
        hour_start=HOUR,
        minutes=60,
        pv_kwh=1.467,
        import_kwh=0.2,
        export_kwh=0.0,
        battery_charge_kwh=0.667,
        house_kwh=1.0,
        base_kwh=1.0,
        pv_direct_kwh=1.0,
        grid_to_house_kwh=0.0,
        pv_to_battery_kwh=0.467,
        grid_to_battery_kwh=0.2,
        import_cost_eur=0.06,
        price_weighted_ct=6.0,
    )

    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return []  # genau der Fall: keine Minutenwerte für diesen Zeitraum

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return [(stored, 3.0)] if s <= HOUR < e else []

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def last() -> datetime | None:
        return None

    acc = EnergyAccounting(HemsConfig(), BERLIN, minute_rows, store=(read, write, last))
    assert await acc.recompute(HOUR, HOUR + timedelta(hours=1)) == 0, "ohne Auftrag nichts anfassen"
    assert written == []

    n = await acc.recompute(HOUR, HOUR + timedelta(hours=1), repair_coarse=True)
    assert n == 1
    h = written[0]
    assert h.grid_to_battery_kwh == pytest.approx(0.0, abs=1e-6)
    assert h.pv_to_battery_kwh == pytest.approx(0.667, abs=0.005)
    assert h.coarse_minutes == 60  # die Stunde weist ihre Auflösung jetzt aus
    # Die Summen bleiben, wie sie waren - korrigiert wird nur die Zuordnung.
    assert h.pv_kwh == pytest.approx(stored.pv_kwh, abs=0.005)
    assert h.house_kwh == pytest.approx(stored.house_kwh, abs=0.005)
    assert h.battery_charge_kwh == pytest.approx(stored.battery_charge_kwh, abs=0.005)
    assert h.import_kwh == pytest.approx(stored.import_kwh, abs=0.005)
    assert h.import_cost_eur == pytest.approx(stored.import_cost_eur, abs=0.005)


@pytest.mark.asyncio
async def test_repair_coarse_laesst_echte_minutenrechnung_in_ruhe() -> None:
    """Ein Tag mit Minutenwerten wird normal gerechnet, auch wenn die Reparatur angefordert ist."""
    written: list[HourlyEnergy] = []

    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return [
            {
                "ts": (HOUR + timedelta(minutes=i)).isoformat().replace("+00:00", "Z"),
                "pv_power_kw": 0.0,
                "grid_power_kw": 3.0,
                "battery_power_kw": -3.0,
            }
            for i in range(60)
        ]

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return []

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        written.extend(hours)

    async def last() -> datetime | None:
        return None

    acc = EnergyAccounting(HemsConfig(), BERLIN, minute_rows, store=(read, write, last))
    await acc.recompute(HOUR, HOUR + timedelta(hours=1), repair_coarse=True)
    h = written[0]
    assert h.coarse_minutes == 0
    assert h.grid_to_battery_kwh == pytest.approx(3.0, abs=0.02)  # echte Netzladung bleibt stehen
