"""Was in das Feld `alarm_entity` gerät, und was die Bridge daraus macht.

**Der Anlass.** Am 29.10.2026 stand in der Oberfläche beim Scharfschalten: „HA-Fehler
invalid_format: expected 'all' or 'none' at 'target.entity_id'. Got 'alarm_entity:
alarm_control_panel.lupusec_alarm'". In das Eingabefeld war die ganze Zeile aus der Anleitung
geraten, Optionsname und Doppelpunkt inbegriffen. Home Assistant bekam das als Ziel und
antwortete mit einem Satz, der die Ursache nicht nennt - und zwar beim Druck auf den Knopf in der
Küche, nicht beim Einrichten.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest

from dch_bridge.main import Bridge
from dch_bridge.mapping import EntityMap
from dch_bridge.settings import BridgeSettings, ist_entitaet
from hems_core.protocol import CommandFrame


class FakeHa:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str]] = []

    async def call_service(self, domain: str, service: str, entity: str) -> None:
        self.calls.append((domain, service, entity))


def bruecke(tmp_path: Path, **optionen: Any) -> Bridge:
    settings = BridgeSettings(api_token="t", outbox_path=tmp_path / "outbox.sqlite", **optionen)
    b = Bridge(settings, EntityMap.model_validate({"sensors": []}))
    b.ha = FakeHa()  # type: ignore[assignment]
    return b


def befehl() -> CommandFrame:
    return CommandFrame(
        command_id=uuid4(),
        issued_at=datetime.now(UTC),
        actuator_key="alarm:arm_away",
        state=True,
    )


@pytest.mark.parametrize(
    "eingabe",
    [
        "alarm_entity: alarm_control_panel.lupusec_alarm",
        "alarm_entity:alarm_control_panel.lupusec_alarm",
        "  alarm_control_panel.lupusec_alarm  ",
        '"alarm_control_panel.lupusec_alarm"',
    ],
)
def test_die_zeile_aus_der_anleitung_wird_zur_entitaet(eingabe: str) -> None:
    s = BridgeSettings(api_token="t", alarm_entity=eingabe)
    assert s.alarm_entity == "alarm_control_panel.lupusec_alarm"
    assert ist_entitaet(s.alarm_entity)


@pytest.mark.asyncio
async def test_scharf_schalten_geht_an_die_entitaet(tmp_path: Path) -> None:
    b = bruecke(
        tmp_path,
        alarm_entity="alarm_entity: alarm_control_panel.lupusec_alarm",
        alarm_arm_enabled=True,
    )
    ergebnis = await b.execute_command(befehl())
    assert ergebnis.ok, ergebnis.error
    assert b.ha.calls == [  # type: ignore[attr-defined]
        ("alarm_control_panel", "alarm_arm_away", "alarm_control_panel.lupusec_alarm")
    ]


@pytest.mark.asyncio
async def test_unsinn_geht_gar_nicht_erst_hinaus(tmp_path: Path) -> None:
    """Keine Absage von Home Assistant, sondern eine, die sagt, was in welches Feld gehört."""
    b = bruecke(tmp_path, alarm_entity="meine Alarmanlage", alarm_arm_enabled=True)
    ergebnis = await b.execute_command(befehl())
    assert not ergebnis.ok
    assert ergebnis.error is not None
    assert "alarm_entity" in ergebnis.error
    assert "alarm_control_panel" in ergebnis.error
    assert b.ha.calls == []  # type: ignore[attr-defined]
