"""Welchen Weg ein Schaltbefehl nimmt: über den Broker oder über Home Assistant."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest

from dch_bridge.main import Bridge
from dch_bridge.mapping import EntityMap
from dch_bridge.settings import BridgeSettings
from hems_core.protocol import CommandFrame

MAP = {
    "actuators": [
        {"key": "courtyard_light", "entity": "switch.lichtinnenhof", "label": "Licht Innenhof"},
        {
            "key": "hp_release_contact",
            "entity": "switch.warmepumpe",
            "label": "WP PV-Freigabe",
            "safety_class": "heat_pump",
        },
    ],
    "mqtt": [
        {
            "prefix": "Lichterkette_Innenhof",
            "components": {"switch:0": {"output": "actuator:courtyard_light"}},
        },
        {
            "prefix": "WP_Kontakt",
            "components": {"switch:0": {"output": "actuator:hp_release_contact"}},
        },
    ],
}


class FakeHub:
    def __init__(self, confirms: bool = True) -> None:
        self.calls: list[tuple[str, bool, float | None]] = []
        self.confirms = confirms

    def can_switch(self, key: str) -> bool:
        return key in ("actuator:courtyard_light", "actuator:hp_release_contact")

    async def switch(self, key: str, state: bool, ttl_s: float | None) -> bool | None:
        self.calls.append((key, state, ttl_s))
        return state if self.confirms else None


class FakeHa:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str]] = []

    async def call_service(self, domain: str, service: str, entity: str) -> None:
        self.calls.append((domain, service, entity))


def build(tmp_path: Path, hub: Any) -> Bridge:
    settings = BridgeSettings(api_token="t", outbox_path=tmp_path / "outbox.sqlite")
    bridge = Bridge(settings, EntityMap.model_validate(MAP))
    bridge.mqtt = hub
    bridge.ha = FakeHa()  # type: ignore[assignment]
    return bridge


def frame(key: str, state: bool, ttl_s: int | None = None) -> CommandFrame:
    return CommandFrame(
        command_id=uuid4(), issued_at=datetime.now(UTC), actuator_key=key, state=state, ttl_s=ttl_s
    )


@pytest.mark.asyncio
async def test_light_is_switched_over_the_broker(tmp_path: Path) -> None:
    hub = FakeHub()
    bridge = build(tmp_path, hub)
    result = await bridge.execute_command(frame("courtyard_light", True, 1800))
    assert result.ok and result.observed_state is True
    assert hub.calls == [("actuator:courtyard_light", True, 1800)]
    assert bridge.ha.calls == []  # type: ignore[attr-defined]


@pytest.mark.asyncio
async def test_heat_pump_contact_stays_on_home_assistant(tmp_path: Path) -> None:
    """Auch wenn ein MQTT-Gerät ihn könnte: der Wächter in HA muss denselben Schalter sehen."""
    hub = FakeHub()
    bridge = build(tmp_path, hub)
    await bridge.execute_command(frame("hp_release_contact", True))
    assert hub.calls == []
    assert bridge.ha.calls == [("switch", "turn_on", "switch.warmepumpe")]  # type: ignore[attr-defined]


@pytest.mark.asyncio
async def test_unconfirmed_broker_command_is_not_ok(tmp_path: Path) -> None:
    bridge = build(tmp_path, FakeHub(confirms=False))
    result = await bridge.execute_command(frame("courtyard_light", True))
    assert result.ok is False and "nicht bestätigt" in (result.error or "")


class QuietHub(FakeHub):
    """Ein MQTT-Gerät, das schweigt: es besitzt den Schlüssel, hat aber keinen frischen Wert."""

    def __init__(self, fresh: bool) -> None:
        super().__init__()
        self._fresh = fresh

    def has_fresh(self, key: str, now: datetime) -> bool:
        return self._fresh

    @property
    def owned_keys(self) -> set[str]:
        return {"actuator:courtyard_light"}


def ha_state(entity: str, state: str) -> Any:
    from dch_bridge.home_assistant.ws_client import EntityState

    now = datetime.now(UTC)
    return EntityState(
        entity_id=entity, state=state, attributes={}, last_updated=now, last_changed=now
    )


@pytest.mark.asyncio
async def test_home_assistant_fills_in_when_the_broker_device_goes_quiet(tmp_path: Path) -> None:
    """Schweigt der Shelly, darf sein letzter Stand nicht einfrieren – HA kennt den richtigen."""
    bridge = build(tmp_path, QuietHub(fresh=False))
    bridge._mqtt_owned = {"actuator:courtyard_light"}
    bridge._ingest(ha_state("switch.lichtinnenhof", "on"))
    assert bridge._pending["actuator:courtyard_light"].value == 1.0


@pytest.mark.asyncio
async def test_broker_value_keeps_precedence_while_it_is_fresh(tmp_path: Path) -> None:
    bridge = build(tmp_path, QuietHub(fresh=True))
    bridge._mqtt_owned = {"actuator:courtyard_light"}
    bridge._ingest(ha_state("switch.lichtinnenhof", "on"))
    assert "actuator:courtyard_light" not in bridge._pending
