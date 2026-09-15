"""Der Speicher soll sagen, in welchem Zustand er war, als er aus dem Netz geladen hat.

Die Messreihen zeigen die Ladung, erklären sie aber nicht: DCH schickt nie einen Ladebefehl, und die
myenergi-Cloud nennt keine Gründe. Die einzige Spur ist der Zustand, den das Gerät in jeder
Statusantwort mitschickt. Diese Tests halten fest, dass er vollständig mitgeschrieben wird, dass die
Messgrößen darin nicht landen, und dass eine unvollständige Auswahl das Protokoll nicht flutet.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from dch_api.application.myenergi_source import MyenergiSource
from dch_api.integrations.myenergi.mapping import libbi_report, libbi_summary_de

T0 = datetime(2026, 9, 13, 12, 0, tzinfo=UTC)


def _libbi(**over: Any) -> list[dict[str, Any]]:
    d: dict[str, Any] = {
        "sno": 12345,
        "dat": "13-09-2026",
        "tim": "12:00:00",
        "lmo": "Normal",
        "sta": 3,
        "soc": 41,
        "frq": 50.01,
        "vol": 2361,
        "gen": 950,
        "grd": 4200,
        "ectp1": -2800,
        "ectt1": "Internal Load",
        "ectt2": "Grid",
        "ectt3": "Generation",
        "batteryDischargingBoost": False,
        "g100LockoutState": 0,
    }
    d.update(over)
    return [{"libbi": [d]}]


def test_the_report_keeps_the_state_and_drops_the_measurements() -> None:
    r = libbi_report(_libbi())
    assert r is not None
    assert r["lmo"] == "Normal"
    assert r["sta"] == 3
    assert r["ectt1"] == "Internal Load"  # die Belegung der Wandler gehört zum Zustand
    assert r["g100LockoutState"] == 0
    for volatile in ("soc", "frq", "vol", "gen", "grd", "ectp1", "dat", "tim"):
        assert volatile not in r, volatile


def test_an_unknown_field_is_kept_rather_than_dropped() -> None:
    """Gerade die Felder, die wir heute nicht deuten, fehlen sonst bei der nächsten Frage."""
    r = libbi_report(_libbi(someNewFlagFromAFirmwareUpdate="scheduled"))
    assert r is not None
    assert r["someNewFlagFromAFirmwareUpdate"] == "scheduled"


def test_no_libbi_no_report() -> None:
    assert libbi_report([{"zappi": [{"sno": 1}]}]) is None
    assert libbi_report([]) is None


def test_the_summary_names_mode_status_and_what_changed() -> None:
    r = libbi_report(_libbi())
    assert r is not None
    assert libbi_summary_de(r) == "Speicher meldet Betriebsart Normal, Status 3"
    assert libbi_summary_de(r, {"lmo": "Normal"}) == (
        "Speicher meldet Betriebsart Normal, Status 3 (geändert: lmo=Normal)"
    )


class _Client:
    def __init__(self, groups: list[list[dict[str, Any]]]) -> None:
        self.groups = groups
        self.i = 0

    async def status(self) -> list[dict[str, Any]]:
        g = self.groups[min(self.i, len(self.groups) - 1)]
        self.i += 1
        return g

    async def history_minutes(self, *a: Any, **k: Any) -> list[dict[str, Any]]:
        return []

    async def set_libbi_mode(self, serial: int | str, mode: str) -> None:
        return None


def _source(
    groups: list[list[dict[str, Any]]], seen: list[tuple[str, dict[str, Any]]]
) -> MyenergiSource:
    async def note(message: str, report: dict[str, Any]) -> None:
        seen.append((message, report))

    async def nothing(_: Any) -> None:
        return None

    return MyenergiSource(_Client(groups), nothing, on_libbi_state=note)


@pytest.mark.asyncio
async def test_the_first_poll_records_the_state_and_a_repeat_does_not() -> None:
    seen: list[tuple[str, dict[str, Any]]] = []
    src = _source([_libbi(), _libbi(soc=44, ectp1=-2790)], seen)
    await src.poll_once(T0)
    await src.poll_once(T0 + timedelta(minutes=5))
    assert len(seen) == 1  # nur der Ladestand hat sich geändert, und der ist eine Messgröße
    assert "Betriebsart Normal" in seen[0][0]


@pytest.mark.asyncio
async def test_a_changed_mode_is_recorded_with_what_changed() -> None:
    seen: list[tuple[str, dict[str, Any]]] = []
    src = _source([_libbi(), _libbi(lmo="Stopped", sta=6)], seen)
    await src.poll_once(T0)
    await src.poll_once(T0 + timedelta(minutes=5))
    assert len(seen) == 2
    assert "Betriebsart Stopped" in seen[1][0]
    assert "lmo=Stopped" in seen[1][0]
    assert "sta=6" in seen[1][0]


@pytest.mark.asyncio
async def test_a_field_that_flips_every_poll_cannot_flood_the_log() -> None:
    """Die Auswahl der Zustandsfelder ist eine Annahme; der Mindestabstand begrenzt ihren Schaden."""
    seen: list[tuple[str, dict[str, Any]]] = []
    src = _source([_libbi(lmo="Normal"), _libbi(lmo="Other"), _libbi(lmo="Normal")], seen)
    await src.poll_once(T0)
    await src.poll_once(T0 + timedelta(seconds=30))
    await src.poll_once(T0 + timedelta(seconds=59))
    assert len(seen) == 1
