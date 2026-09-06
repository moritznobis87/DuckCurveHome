"""Entity-Mapping: Home-Assistant-Entitäten → Domänenschlüssel (Einheit, Skalierung, Vorzeichen).

Die Vorzeichen-Übersetzung findet ausschließlich hier statt; ab dem Uplink gilt die Domänenkonvention.
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field

from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

SignConvention = Literal[
    "as_is", "import_positive", "export_positive", "discharge_positive", "charge_positive"
]


class SensorMap(BaseModel):
    model_config = ConfigDict(frozen=True)

    key: str
    entity: str
    unit: str | None = None  # W, kW, %, °C, EUR/kWh, ct/kWh
    scale: float | None = None  # explizite Skalierung, sonst aus unit abgeleitet
    sign: SignConvention = "as_is"
    stale_after_s: int = 120
    kind: Literal["number", "binary"] = "number"


class ActuatorMap(BaseModel):
    model_config = ConfigDict(frozen=True)

    key: str
    entity: str  # switch.* oder light.*
    label: str
    safety_class: Literal["none", "heat_pump"] = "none"
    safe_state: bool = False


class MqttDeviceMap(BaseModel):
    """Ein Shelly, den die Bridge direkt über MQTT liest.

    Generation 1 (Shelly 3EM): jede Größe kommt als eigene Nachricht unter
    `shellies/<gerät>/emeter/<phase>/<feld>`. Es genügt `prefix` und `key_prefix`.

    Generation 2/3 (Plus, Pro): das Gerät meldet JSON unter `<präfix>/events/rpc` und – falls in der
    Geräteoberfläche aktiviert – `<präfix>/status/<komponente>`. Hier muss `components` sagen, welche
    Komponente welchem Domänenschlüssel entspricht:

    ```yaml
    components:
      "temperature:100": buffer_temp_top_c        # natürlicher Wert der Komponente (°C)
      "switch:0":                                  # oder mehrere Felder ausdrücklich
        apower: coffee_power_kw
        output: "actuator:coffee_machine"
    ```
    """

    model_config = ConfigDict(frozen=True)

    prefix: str  # shellies/shellyem3-XXXX (Gen 1) oder shellyplus1-XXXX (Gen 2)
    generation: Literal[1, 2] = 2
    kind: Literal["em3", "generic"] = "generic"  # em3 = dreiphasiger Zähler der ersten Generation
    key_prefix: str = ""  # nur für kind em3: heat_pump → heat_pump_power_kw, …
    components: dict[str, str | dict[str, str]] = Field(default_factory=dict)
    label: str = ""


class EntityMap(BaseModel):
    model_config = ConfigDict(frozen=True)

    sensors: list[SensorMap] = Field(default_factory=list)
    actuators: list[ActuatorMap] = Field(default_factory=list)
    mqtt: list[MqttDeviceMap] = Field(default_factory=list)

    @classmethod
    def load(cls, path: Path) -> EntityMap:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        return cls.model_validate(data)

    def digest(self) -> str:
        return hashlib.sha256(self.model_dump_json().encode()).hexdigest()[:16]

    def by_entity(self) -> dict[str, SensorMap | ActuatorMap]:
        out: dict[str, SensorMap | ActuatorMap] = {s.entity: s for s in self.sensors}
        out.update({a.entity: a for a in self.actuators})
        return out

    def keys(self) -> list[str]:
        """Was die Bridge der API ankündigt – auch Schlüssel, die es nur über MQTT gibt."""
        out = [s.key for s in self.sensors] + [f"actuator:{a.key}" for a in self.actuators]
        out += sorted(self.mqtt_keys() - set(out))
        return out

    def mqtt_keys(self) -> set[str]:
        """Domänenschlüssel, die über MQTT kommen – Home Assistant liefert sie dann nicht mehr."""
        out: set[str] = set()
        for dev in self.mqtt:
            if dev.kind == "em3" and dev.key_prefix:
                out |= {f"{dev.key_prefix}_power_kw", f"{dev.key_prefix}_energy_kwh"}
            for target in dev.components.values():
                out |= {target} if isinstance(target, str) else set(target.values())
        return out


UNIT_SCALE: dict[str, float] = {
    "W": 0.001,
    "kW": 1.0,
    "%": 0.01,
    "°C": 1.0,
    "EUR/kWh": 100.0,
    "ct/kWh": 1.0,
}
UNAVAILABLE_STATES = {"unavailable", "none", ""}
UNKNOWN_STATES = {"unknown"}


def _apply_sign(value: float, sign: SignConvention) -> float:
    # Domänenkonvention: grid > 0 Bezug; battery > 0 Entladen
    if sign in ("as_is", "import_positive", "discharge_positive"):
        return value
    return -value


def normalize(
    m: SensorMap | ActuatorMap,
    state: str,
    attributes: dict[str, object],
    last_updated: datetime | None,
    now: datetime,
) -> RawReading:
    at = last_updated or now
    key = m.key if isinstance(m, SensorMap) else f"actuator:{m.key}"
    source = f"ha:{m.entity}"
    s = state.strip().lower()
    if s in UNAVAILABLE_STATES:
        return RawReading(
            key=key, value=None, observed_at=at, quality=Quality.UNAVAILABLE, source=source
        )
    if s in UNKNOWN_STATES:
        return RawReading(
            key=key, value=None, observed_at=at, quality=Quality.UNKNOWN, source=source
        )
    if isinstance(m, ActuatorMap) or m.kind == "binary":
        return RawReading(
            key=key,
            value=1.0 if s == "on" else 0.0,
            observed_at=at,
            quality=Quality.OK,
            source=source,
        )
    try:
        raw = float(state)
    except ValueError:
        return RawReading(
            key=key, value=None, observed_at=at, quality=Quality.UNKNOWN, source=source
        )
    unit = m.unit or str(attributes.get("unit_of_measurement") or "")
    scale = m.scale if m.scale is not None else UNIT_SCALE.get(unit, 1.0)
    value = _apply_sign(raw * scale, m.sign)
    quality = Quality.OK
    if (now - at).total_seconds() > m.stale_after_s:
        quality = Quality.STALE
    return RawReading(
        key=key, value=round(value, 4), observed_at=at, quality=quality, source=source
    )


def parse_ha_time(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)
