"""myenergi-Quelle: Übersetzung der Cloud-Antwort, Poller und Lückenfüllung aus der Historie."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from dch_api.application.myenergi_source import MyenergiSource, price_readings_for_gaps
from dch_api.infrastructure.live_state import LiveState
from dch_api.integrations.myenergi.mapping import (
    history_minutes,
    readings_from_history,
    readings_from_status,
)
from hems_core.domain import HemsConfig, Quality
from hems_core.planning import PricePoint
from hems_core.protocol import RawReading

NOW = datetime(2026, 9, 5, 10, 0, tzinfo=UTC)

# Aufnahme wie in config/entities.home.yaml dokumentiert: PV 7650 W, Einspeisung 2378 W, Batterie lädt 445 W
STATUS: list[dict[str, Any]] = [
    {"eddi": []},
    {
        "zappi": [
            {
                "sno": 10000001,
                "dat": "05-09-2026",
                "tim": "09:59:50",
                "ectp1": 0,
                "ectt1": "Internal Load",
                "ectt2": "None",
                "ectt3": "None",
                "gen": 7650,
                "grd": -2378,
                "div": 0,
                "sta": 1,
                "pst": "A",
                "zmo": 3,
            }
        ]
    },
    {
        "harvi": [
            {
                "sno": 11546287,
                "dat": "05-09-2026",
                "tim": "09:59:55",
                "ectp1": 2573,
                "ectt1": "Generation",
                "ectp2": 2542,
                "ectt2": "Generation",
                "ectp3": 2535,
                "ectt3": "Generation",
            }
        ]
    },
    {
        "libbi": [
            {
                "sno": 26244255,
                "dat": "05-09-2026",
                "tim": "09:59:58",
                "ectp1": 445,
                "ectt1": "Internal Load",
                "ectp2": -2378,
                "ectt2": "Grid",
                "ectt3": "None",
                "soc": 58,
                "mbc": 5120,
                "sta": 3,
            }
        ]
    },
    {"asn": "s18.myenergi.net", "fwv": "3401S5.421"},
]


def by_key(items: list[RawReading]) -> dict[str, RawReading]:
    return {r.key: r for r in items}


def test_status_maps_to_domain_keys_and_signs() -> None:
    r = by_key(readings_from_status(STATUS, NOW))
    assert r["pv_power_kw"].value == pytest.approx(7.65)  # Summe der drei Harvi-CTs
    assert r["grid_power_kw"].value == pytest.approx(-2.378)  # Einspeisung negativ
    assert r["battery_power_kw"].value == pytest.approx(-0.445)  # Laden negativ (Entladen positiv)
    assert r["battery_soc"].value == pytest.approx(0.58)
    assert r["ev_power_kw"].value == 0.0
    assert r["battery_soc"].observed_at == datetime(2026, 9, 5, 9, 59, 58, tzinfo=UTC)
    assert r["pv_power_kw"].source == "myenergi:generation"
    assert r["battery_power_kw"].source == "myenergi:libbi:26244255"
    # Bilanz: PV + Netz + Batterie(Entladen+) = Hausverbrauch 4,827 kW wie in der Aufnahme
    house = r["pv_power_kw"].value + r["grid_power_kw"].value + r["battery_power_kw"].value  # type: ignore[operator]
    assert house == pytest.approx(4.827, abs=1e-3)


def test_status_falls_back_to_gen_and_grd_without_cts() -> None:
    groups = [{"zappi": [{"sno": 1, "gen": 1200, "grd": 300, "div": 2400, "ectt1": "None"}]}]
    r = by_key(readings_from_status(groups, NOW))
    assert r["pv_power_kw"].value == pytest.approx(1.2)
    assert r["grid_power_kw"].value == pytest.approx(0.3)
    assert r["ev_power_kw"].value == pytest.approx(2.4)
    assert r["pv_power_kw"].observed_at == NOW  # kein dat/tim → Abrufzeit


def test_history_minutes_merge_devices() -> None:
    rows = {
        "libbi": [
            {
                "yr": 2026,
                "mon": 9,
                "dom": 5,
                "hr": 10,
                "min": 0,
                "imp": 60_000,
                "gep": 120_000,
                "bcp1": 30_000,
            },
            {
                "yr": 2026,
                "mon": 9,
                "dom": 5,
                "hr": 10,
                "min": 1,
                "exp": 60_000,
                "gep": 120_000,
                "bdp1": 30_000,
            },
        ],
        "zappi": [
            {
                "yr": 2026,
                "mon": 9,
                "dom": 5,
                "hr": 10,
                "min": 0,
                "imp": 60_000,
                "gep": 120_000,
                "h1d": 90_000,
            },
        ],
    }
    out = history_minutes(rows)
    assert [h.ts.minute for h in out] == [0, 1]
    m0, m1 = out
    assert m0.pv_kw == pytest.approx(2.0)  # 120 kJ je Minute = 2 kW
    assert m0.grid_kw == pytest.approx(1.0)
    assert m0.battery_kw == pytest.approx(-0.5)  # Laden
    assert m0.ev_kw == pytest.approx(1.5)
    assert m1.grid_kw == pytest.approx(-1.0)  # Einspeisung
    assert m1.battery_kw == pytest.approx(0.5)  # Entladen
    assert m1.ev_kw is None  # keine Zappi-Zeile in dieser Minute

    # Zeile ohne Energiefelder (Nacht, Batterie ruht) → 0 statt fehlend
    quiet = history_minutes({"libbi": [{"yr": 2026, "mon": 9, "dom": 5, "hr": 2, "min": 0}]})
    assert quiet[0].pv_kw == 0.0 and quiet[0].grid_kw == 0.0 and quiet[0].battery_kw == 0.0

    readings = readings_from_history(out, missing={(m0.ts, "pv_power_kw")})
    assert [(r.key, r.value) for r in readings] == [("pv_power_kw", 2.0)]
    assert readings[0].observed_at.second == 30 and readings[0].source == "myenergi:history"


class FakeClient:
    def __init__(self) -> None:
        self.fail = False
        self.history_calls: list[tuple[str, int, datetime, int]] = []

    async def status(self) -> list[dict[str, Any]]:
        if self.fail:
            raise RuntimeError("cloud weg")
        return STATUS

    async def history_minutes(
        self, prefix: str, serial: int | str, start_utc: datetime, minutes: int
    ) -> list[dict[str, Any]]:
        self.history_calls.append((prefix, int(serial), start_utc, minutes))
        rows = []
        for i in range(minutes):
            ts = start_utc + timedelta(minutes=i)
            row: dict[str, Any] = {
                "yr": ts.year,
                "mon": ts.month,
                "dom": ts.day,
                "hr": ts.hour,
                "min": ts.minute,
                "gep": 60_000,
            }
            if prefix == "L":
                row["bdp1"] = 6_000
            rows.append(row)
        return rows


@pytest.mark.asyncio
async def test_source_polls_and_tracks_state() -> None:
    client = FakeClient()
    got: list[list[RawReading]] = []
    states: list[bool] = []

    async def on_readings(items: list[RawReading]) -> None:
        got.append(items)

    async def on_state(online: bool, _err: str) -> None:
        states.append(online)

    src = MyenergiSource(client, on_readings, on_state_change=on_state)
    await src.poll_once(NOW)
    assert src.online and src.polls_ok == 1 and len(got[0]) == 5
    client.fail = True
    with pytest.raises(RuntimeError):
        await src.poll_once(NOW)
    assert not src.online and src.last_error and states == [True, False]
    assert src.status_out()["name"] == "myenergi"


@pytest.mark.asyncio
async def test_backfill_only_fills_missing_minutes() -> None:
    client = FakeClient()
    got: list[RawReading] = []
    recomputed: list[tuple[datetime, datetime]] = []
    start = datetime(2026, 9, 5, 8, 0, tzinfo=UTC)
    end = start + timedelta(minutes=3)

    async def on_readings(items: list[RawReading]) -> None:
        got.extend(items)

    async def minute_rows(
        s: datetime, e: datetime, keys: list[str]
    ) -> list[dict[str, float | str | None]]:
        # Minute 8:01 hat bereits PV aus der Bridge
        return [{"ts": "2026-09-05T08:01:00Z", "pv_power_kw": 0.9}]

    async def on_backfilled(s: datetime, e: datetime) -> None:
        recomputed.append((s, e))

    src = MyenergiSource(client, on_readings, minute_rows=minute_rows, on_backfilled=on_backfilled)
    n = await src.backfill(start, end)
    # Libbi (L) und Zappi (Z) werden abgefragt, Harvi nicht
    assert sorted(p for p, *_ in client.history_calls) == ["L", "Z"]
    assert all(m <= 1440 for *_, m in client.history_calls)
    pv = [r for r in got if r.key == "pv_power_kw"]
    bat = [r for r in got if r.key == "battery_power_kw"]
    assert [r.observed_at.minute for r in pv] == [0, 2]  # 8:01 übersprungen
    assert len(bat) == 3 and bat[0].value == pytest.approx(0.1)
    ev = [r for r in got if r.key == "ev_power_kw"]
    assert len(ev) == 3 and all(r.value == 0.0 for r in ev)  # Zappi-Zeilen ohne h1d/h1b = 0 kW
    grid = [r for r in got if r.key == "grid_power_kw"]
    assert len(grid) == 3 and all(r.value == 0.0 for r in grid)  # keine imp/exp-Felder = 0 kW
    assert n == len(got) == 11 and recomputed == [(start, end)]
    # zweiter Lauf ohne neue Werte ruft den Nachlauf trotzdem (Preise, Stunden)
    await src.backfill(start, end)
    assert len(recomputed) == 2


@pytest.mark.asyncio
async def test_backfill_is_chunked_per_utc_day() -> None:
    client = FakeClient()

    async def on_readings(items: list[RawReading]) -> None:
        pass

    src = MyenergiSource(client, on_readings)
    start = datetime(2026, 9, 4, 20, 0, tzinfo=UTC)
    end = datetime(2026, 9, 6, 8, 30, tzinfo=UTC)
    await src.backfill(start, end)
    libbi_calls = [c for c in client.history_calls if c[0] == "L"]
    assert [c[2].day for c in libbi_calls] == [4, 5, 6]
    assert libbi_calls[0][2].hour == 20 and libbi_calls[1][3] == 1440
    assert "Historie" in src.status_out()["detail_de"] and src.last_backfill_at is not None


def test_price_readings_only_for_missing_minutes() -> None:
    start = datetime(2026, 9, 5, 10, 0, tzinfo=UTC)
    prices = [
        PricePoint(start=start, end=start + timedelta(hours=1), ct_kwh=25.5),
        PricePoint(start=start + timedelta(hours=1), end=start + timedelta(hours=2), ct_kwh=30.0),
    ]
    existing = [{"ts": "2026-09-05T10:05:00Z", "electricity_price_ct_kwh": 25.5}]
    out = price_readings_for_gaps(prices, existing, start, start + timedelta(minutes=70))
    assert len(out) == 69  # 70 Minuten, eine schon vorhanden
    assert out[0].observed_at == start.replace(second=30) and out[0].value == 25.5
    assert out[-1].value == 30.0 and out[-1].source == "tibber:history"


def test_unavailable_from_other_source_does_not_hide_good_value() -> None:
    live = LiveState(HemsConfig())
    good = RawReading(key="pv_power_kw", value=6.9, observed_at=NOW, source="myenergi:generation")
    live.apply([good])
    ha_gone = RawReading(
        key="pv_power_kw",
        value=None,
        observed_at=NOW + timedelta(seconds=5),
        quality=Quality.UNAVAILABLE,
        source="ha:sensor.myenergi_hub_14117600_power_generation",
    )
    live.apply([ha_gone])
    assert live.readings["pv_power_kw"].value == 6.9
    # dieselbe Quelle darf ihren eigenen Wert auf „nicht verfügbar“ setzen
    live.apply(
        [
            RawReading(
                key="pv_power_kw",
                value=None,
                observed_at=NOW + timedelta(seconds=9),
                quality=Quality.UNAVAILABLE,
                source="myenergi:generation",
            )
        ]
    )
    assert live.readings["pv_power_kw"].value is None
