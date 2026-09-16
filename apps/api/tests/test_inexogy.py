"""Der amtliche Zähler läuft als zweite Meinung mit und darf nichts verändern.

Der wichtigste Test hier ist der letzte: die Anbindung schreibt auf eigene Schlüssel. Liefe sie auf
`grid_power_kw`, wäre der Vergleich, für den sie gebaut wurde, nicht mehr zu führen - man verglich
den Zähler dann mit sich selbst.

Der zweitwichtigste ist der über die Einheiten. Die API nennt sie nicht; Milliwatt und
Zehnmilliardstel Kilowattstunden sind aus fremdem Quelltext geschlossen. Eine Reihe, die aussieht
wie eine Messreihe und um den Faktor tausend danebenliegt, wäre der teuerste Fehler, den diese
Anbindung machen kann - deshalb fängt die Plausibilitätsgrenze ihn ab, statt ihn zu glätten.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from dch_api.application.inexogy_source import InexogySource
from dch_api.integrations.inexogy.mapping import (
    EXPORT_KEY,
    IMPORT_KEY,
    POWER_KEY,
    pick_meter,
    readings_from_measurement,
)

NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)
# 16.09.2026 11:59:30 UTC als Millisekunden, so wie der Zähler die Zeit meldet.
MEASURED_MS = int((NOW - timedelta(seconds=30)).timestamp() * 1000)


def _measurement(**values: Any) -> dict[str, Any]:
    base: dict[str, Any] = {"power": 2_350_000, "energy": 441_576_730_000, "energyOut": 12_000_000}
    base.update(values)
    return {"time": MEASURED_MS, "values": base}


def test_power_is_milliwatt_and_counters_are_ten_billionths_of_a_kwh() -> None:
    out = {r.key: r.value for r in readings_from_measurement(_measurement(), NOW, "test")}
    assert out[POWER_KEY] == pytest.approx(2.35)  # 2 350 000 mW = 2,35 kW
    assert out[IMPORT_KEY] == pytest.approx(44.157673)
    assert out[EXPORT_KEY] == pytest.approx(0.0012)


def test_the_sign_is_ours_already() -> None:
    """Der Zähler meldet Einspeisung negativ, so wie die Domäne es erwartet. Nichts umzudrehen."""
    out = {
        r.key: r.value for r in readings_from_measurement(_measurement(power=-4_100_000), NOW, "t")
    }
    assert out[POWER_KEY] == pytest.approx(-4.1)


def test_the_measurement_keeps_its_own_timestamp() -> None:
    r = readings_from_measurement(_measurement(), NOW, "t")[0]
    assert r.observed_at == NOW - timedelta(seconds=30)


def test_a_wrong_unit_factor_is_rejected_instead_of_recorded() -> None:
    """Wäre `power` in Watt statt Milliwatt, käme hier ein Gigawatt heraus. Das darf nicht in die Reihe."""
    out = {
        r.key: r.value
        for r in readings_from_measurement(_measurement(power=2_350_000_000_000), NOW, "t")
    }
    assert POWER_KEY not in out
    assert IMPORT_KEY in out  # die übrigen Felder bleiben davon unberührt


def test_a_negative_counter_is_rejected() -> None:
    out = {r.key: r.value for r in readings_from_measurement(_measurement(energy=-5), NOW, "t")}
    assert IMPORT_KEY not in out


def test_missing_fields_are_simply_absent() -> None:
    m = {"time": MEASURED_MS, "values": {"power": 1_000_000}}
    out = {r.key: r.value for r in readings_from_measurement(m, NOW, "t")}
    assert out == {POWER_KEY: 1.0}
    assert readings_from_measurement({"time": MEASURED_MS}, NOW, "t") == []


def test_the_meter_is_found_by_printed_serial_number() -> None:
    """An der Wand steht die lange Seriennummer, in der API zählt der meterId."""
    meters = [
        {
            "meterId": "aaa",
            "serialNumber": "111",
            "printedFullSerialNumber": "1ESY111",
            "lastMeasurementTime": 1,
        },
        {
            "meterId": "bbb",
            "serialNumber": "222",
            "printedFullSerialNumber": "1ESY222",
            "lastMeasurementTime": 9,
        },
    ]
    assert pick_meter(meters, "1ESY111")["meterId"] == "aaa"  # type: ignore[index]
    assert pick_meter(meters, "bbb")["meterId"] == "bbb"  # type: ignore[index]
    assert pick_meter(meters, "unbekannt") is None
    # Ohne Angabe gewinnt der Zähler, der zuletzt gemeldet hat.
    assert pick_meter(meters)["meterId"] == "bbb"  # type: ignore[index]
    assert pick_meter([{"meterId": "x", "lastMeasurementTime": -1}])["meterId"] == "x"  # type: ignore[index]
    assert pick_meter([]) is None


class _Client:
    def __init__(self, meters: list[dict[str, Any]] | None = None) -> None:
        self._meters = (
            meters
            if meters is not None
            else [{"meterId": "abc", "serialNumber": "77", "lastMeasurementTime": 5}]
        )
        self.meter_calls = 0
        self.reading_calls = 0

    async def meters(self) -> list[dict[str, Any]]:
        self.meter_calls += 1
        return self._meters

    async def last_reading(self, meter_id: str) -> dict[str, Any]:
        self.reading_calls += 1
        assert meter_id == "abc"
        return _measurement()

    async def readings(
        self, meter_id: str, start: datetime, end: datetime, resolution: str = "three_minutes"
    ) -> list[dict[str, Any]]:
        return [_measurement(), _measurement(power=1_000_000)]

    async def close(self) -> None:
        return None


@pytest.mark.asyncio
async def test_the_source_writes_only_its_own_keys() -> None:
    seen: list[str] = []

    async def collect(items: list[Any]) -> None:
        seen.extend(r.key for r in items)

    src = InexogySource(_Client(), collect)
    await src.poll_once(NOW)
    assert set(seen) == {POWER_KEY, IMPORT_KEY, EXPORT_KEY}
    # Der Netzwert der Bilanz bleibt unangetastet - daran hängt die ganze Beobachtungsphase.
    assert "grid_power_kw" not in seen
    assert src.online and src.polls_ok == 1


@pytest.mark.asyncio
async def test_the_meter_is_resolved_once_and_then_remembered() -> None:
    async def nothing(_: Any) -> None:
        return None

    client = _Client()
    src = InexogySource(client, nothing)
    await src.poll_once(NOW)
    await src.poll_once(NOW + timedelta(seconds=30))
    assert client.meter_calls == 1
    assert client.reading_calls == 2
    assert src.meter_label == "77"


@pytest.mark.asyncio
async def test_an_unknown_meter_is_an_error_naming_what_exists() -> None:
    async def nothing(_: Any) -> None:
        return None

    src = InexogySource(_Client(), nothing, meter="99")
    with pytest.raises(RuntimeError, match="77"):
        await src.poll_once(NOW)
    assert not src.online
    assert src.last_error is not None


@pytest.mark.asyncio
async def test_the_backfill_reports_how_much_it_wrote() -> None:
    seen: list[Any] = []

    async def collect(items: list[Any]) -> None:
        seen.extend(items)

    src = InexogySource(_Client(), collect)
    n = await src.backfill(NOW - timedelta(hours=1), NOW)
    assert n == 6  # zwei Messwerte mit je drei Feldern
    assert len(seen) == 6
