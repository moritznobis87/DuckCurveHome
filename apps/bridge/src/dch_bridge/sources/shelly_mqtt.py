"""Shelly-Geräte direkt über MQTT lesen – ohne Umweg über Home Assistant.

Zwei Gerätegenerationen mit sehr verschiedenen Formaten:

**Generation 1** (Shelly 3EM): jede Größe ist eine eigene Nachricht mit einer nackten Zahl unter
`shellies/shellyem3-<id>/emeter/<phase>/{power,voltage,current,pf,total,total_returned}`, dazu
`shellies/shellyem3-<id>/online`. Energie (`total`, `total_returned`) steht in Wh im nichtflüchtigen
Speicher des Geräts; die flüchtigen `energy`/`returned_energy` werden bewusst nicht verwendet.

**Generation 2 und 3** (Plus, Pro): das Gerät meldet JSON-RPC unter `<präfix>/events/rpc`
(`NotifyStatus`, `NotifyFullStatus`) und – falls in der Geräteoberfläche aktiviert – den Zustand je
Komponente unter `<präfix>/status/<komponente>`. Welche Komponente welchem Domänenschlüssel entspricht,
steht im Entity-Mapping.

Gemeinsam ist beiden: jede Nachricht wird geprüft, der letzte gültige Zustand gehalten und daraus alle
`publish_interval_s` ein konsistenter Satz `RawReading`s in der Domänenkonvention erzeugt (kW, kWh, °C).
Als Messzeitpunkt gilt der Empfang – die Uhr des Geräts wird bewusst nicht verwendet.
"""

from __future__ import annotations

import asyncio
import contextlib
import itertools
import json
import math
import random
from collections.abc import AsyncIterator, Awaitable, Callable, Iterator
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

import structlog

from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

log = structlog.get_logger("shelly_mqtt")

RPC_SRC = "dch-bridge"  # Antworten des Shelly landen unter <RPC_SRC>/rpc – wir werten sie nicht aus
SWITCHABLE_KINDS = frozenset({"switch", "light"})
PHASES = ("0", "1", "2")
PHASE_LABEL = {"0": "l1", "1": "l2", "2": "l3"}
FIELDS = ("power", "voltage", "current", "pf", "total", "total_returned")
# Plausibilitätsgrenzen je Feld (Rohwert des Shelly). Außerhalb → verworfen, nicht weitergeleitet.
LIMITS: dict[str, tuple[float, float]] = {
    "power": (-30_000.0, 30_000.0),  # W, Rückspeisung negativ möglich
    "voltage": (0.0, 500.0),  # V
    "current": (0.0, 300.0),  # A
    "pf": (-1.0, 1.0),
    "total": (0.0, 1e10),  # Wh, Zählerstand
    "total_returned": (0.0, 1e10),  # Wh
}
COUNTER_FIELDS = ("total", "total_returned")
COUNTER_RESET_AFTER = (
    5  # so viele aufeinanderfolgende niedrigere Zählerstände gelten als Zählerreset
)
W_TO_KW = 0.001
WH_TO_KWH = 0.001


@dataclass
class _Value:
    value: float
    at: datetime


@dataclass
class Shelly3EmState:
    """Letzter gültiger Zustand aller drei Phasen (reine Logik, ohne Netz)."""

    topic_prefix: str
    phases: dict[str, dict[str, _Value]] = field(default_factory=lambda: {p: {} for p in PHASES})
    online: bool | None = None
    online_at: datetime | None = None
    last_message_at: datetime | None = None
    messages: int = 0
    rejected: int = 0
    _lower_counter: dict[tuple[str, str], int] = field(default_factory=dict)

    # ------------------------------------------------------------------ Eingang
    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool:
        """Eine MQTT-Nachricht einarbeiten. True, wenn ein Wert übernommen wurde."""
        self.messages += 1
        if not topic.startswith(self.topic_prefix + "/"):
            return False
        rest = topic[len(self.topic_prefix) + 1 :]
        text = payload.decode("utf-8", errors="replace") if isinstance(payload, bytes) else payload
        text = text.strip()
        if rest == "online":
            flag = _parse_bool(text)
            if flag is None:
                self.rejected += 1
                return False
            self.online = flag
            self.online_at = now
            self.last_message_at = now
            return True
        parts = rest.split("/")
        if (
            len(parts) != 3
            or parts[0] != "emeter"
            or parts[1] not in PHASES
            or parts[2] not in FIELDS
        ):
            return False  # unbekanntes Topic (relay, announce, energy, …) – bewusst ignoriert
        phase, fld = parts[1], parts[2]
        value = _parse_float(text)
        if value is None:
            self.rejected += 1
            return False
        lo, hi = LIMITS[fld]
        if not lo <= value <= hi:
            self.rejected += 1
            log.debug("shelly value out of range", phase=phase, field=fld, value=value)
            return False
        if fld in COUNTER_FIELDS and not self._counter_ok(phase, fld, value):
            self.rejected += 1
            return False
        self.phases[phase][fld] = _Value(value, now)
        self.last_message_at = now
        return True

    def _counter_ok(self, phase: str, fld: str, value: float) -> bool:
        """Zählerstände dürfen nicht fallen; nach COUNTER_RESET_AFTER niedrigeren Werten gilt ein Reset."""
        prev = self.phases[phase].get(fld)
        key = (phase, fld)
        if prev is None or value >= prev.value - 1.0:
            self._lower_counter.pop(key, None)
            return True
        n = self._lower_counter.get(key, 0) + 1
        self._lower_counter[key] = n
        if n >= COUNTER_RESET_AFTER:
            log.warning(
                "shelly counter reset accepted", phase=phase, field=fld, old=prev.value, new=value
            )
            self._lower_counter.pop(key, None)
            return True
        log.debug(
            "shelly counter decreased, rejected", phase=phase, field=fld, old=prev.value, new=value
        )
        return False

    # ------------------------------------------------------------------ Ausgang
    def snapshot(self, now: datetime, stale_after: timedelta) -> Shelly3EmSnapshot | None:
        """Konsistenter Datensatz, wenn alle drei Phasen eine frische Leistung haben; sonst None."""
        powers: list[_Value] = []
        for p in PHASES:
            v = self.phases[p].get("power")
            if v is None or now - v.at > stale_after:
                return None
            powers.append(v)
        per_phase: dict[str, dict[str, float]] = {}
        newest = max(v.at for v in powers)
        for p in PHASES:
            vals: dict[str, float] = {}
            for fld in FIELDS:
                v = self.phases[p].get(fld)
                if v is not None and now - v.at <= stale_after:
                    vals[fld] = v.value
                    newest = max(newest, v.at)
            per_phase[PHASE_LABEL[p]] = vals
        totals_ok = all("total" in per_phase[PHASE_LABEL[p]] for p in PHASES)
        returned_ok = all("total_returned" in per_phase[PHASE_LABEL[p]] for p in PHASES)
        return Shelly3EmSnapshot(
            at=newest,
            online=self.online,
            phases=per_phase,
            power_w=sum(v.value for v in powers),
            energy_wh=sum(per_phase[PHASE_LABEL[p]]["total"] for p in PHASES)
            if totals_ok
            else None,
            energy_returned_wh=(
                sum(per_phase[PHASE_LABEL[p]]["total_returned"] for p in PHASES)
                if returned_ok
                else None
            ),
        )

    def is_stale(
        self, now: datetime, stale_after: timedelta, since: datetime | None = None
    ) -> bool:
        """Veraltet, wenn die letzte Nachricht (oder ohne jede Nachricht: der Start) länger zurückliegt."""
        ref = self.last_message_at or since
        return ref is None or now - ref > stale_after


@dataclass(frozen=True)
class Shelly3EmSnapshot:
    at: datetime  # Empfangszeit der jüngsten enthaltenen Nachricht
    online: bool | None
    phases: dict[str, dict[str, float]]  # l1/l2/l3 → Feld → Rohwert (W, V, A, –, Wh)
    power_w: float  # Summe der drei aktuellen Leistungen
    energy_wh: float | None  # Summe der drei Zählerstände (Bezug)
    energy_returned_wh: float | None


def readings_from_snapshot(
    snap: Shelly3EmSnapshot, key_prefix: str, device_id: str
) -> list[RawReading]:
    """Domänen-Messwerte: Summen und alle drei Phasen; W→kW und Wh→kWh explizit."""
    src = f"mqtt:shellyem3-{device_id}"
    at = snap.at
    out = [
        RawReading(
            key=f"{key_prefix}_power_kw",
            value=round(snap.power_w * W_TO_KW, 4),
            observed_at=at,
            source=src,
        )
    ]
    if snap.energy_wh is not None:
        out.append(
            RawReading(
                key=f"{key_prefix}_energy_kwh",
                value=round(snap.energy_wh * WH_TO_KWH, 3),
                observed_at=at,
                source=src,
            )
        )
    if snap.energy_returned_wh is not None:
        out.append(
            RawReading(
                key=f"{key_prefix}_energy_returned_kwh",
                value=round(snap.energy_returned_wh * WH_TO_KWH, 3),
                observed_at=at,
                source=src,
            )
        )
    for label, vals in snap.phases.items():
        for fld, value in vals.items():
            if fld == "power":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_power_{label}_kw",
                        value=round(value * W_TO_KW, 4),
                        observed_at=at,
                        source=src,
                    )
                )
            elif fld == "total":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_energy_{label}_kwh",
                        value=round(value * WH_TO_KWH, 3),
                        observed_at=at,
                        source=src,
                    )
                )
            elif fld == "total_returned":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_energy_returned_{label}_kwh",
                        value=round(value * WH_TO_KWH, 3),
                        observed_at=at,
                        source=src,
                    )
                )
            elif fld == "voltage":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_voltage_{label}_v",
                        value=round(value, 1),
                        observed_at=at,
                        source=src,
                    )
                )
            elif fld == "current":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_current_{label}_a",
                        value=round(value, 3),
                        observed_at=at,
                        source=src,
                    )
                )
            elif fld == "pf":
                out.append(
                    RawReading(
                        key=f"{key_prefix}_pf_{label}",
                        value=round(value, 3),
                        observed_at=at,
                        source=src,
                    )
                )
    return out


def unavailable_readings(key_prefix: str, device_id: str, at: datetime) -> list[RawReading]:
    """Gerät offline oder Daten veraltet: die Kernwerte ausdrücklich als nicht verfügbar melden."""
    src = f"mqtt:shellyem3-{device_id}"
    return [
        RawReading(
            key=f"{key_prefix}_power_kw",
            value=None,
            observed_at=at,
            quality=Quality.UNAVAILABLE,
            source=src,
        ),
        RawReading(
            key=f"{key_prefix}_energy_kwh",
            value=None,
            observed_at=at,
            quality=Quality.UNAVAILABLE,
            source=src,
        ),
    ]


def _parse_float(text: str) -> float | None:
    try:
        v = float(text)
    except ValueError:
        return None
    return None if math.isnan(v) or math.isinf(v) else v


def _parse_bool(text: str) -> bool | None:
    t = text.lower()
    if t in ("true", "1", "on", "online"):
        return True
    if t in ("false", "0", "off", "offline"):
        return False
    return None


# ---------------------------------------------------------------------- Generation 2/3 (Plus, Pro)
# Aus welchem Feld einer Komponente der natürliche Messwert kommt, wenn das Mapping nur einen Schlüssel nennt.
NATURAL_FIELD: dict[str, str] = {
    "temperature": "tC",
    "humidity": "rh",
    "switch": "apower",
    "cover": "apower",
    "pm1": "apower",
    "em1": "act_power",
    "voltmeter": "voltage",
    "input": "state",
}
# Umrechnung in die Domänenkonvention. Was hier nicht steht, wird unverändert übernommen (°C, %, V, A).
FIELD_SCALE: dict[str, float] = {
    "apower": W_TO_KW,
    "act_power": W_TO_KW,
    "aenergy.total": WH_TO_KWH,
    "total_act_energy": WH_TO_KWH,
    "ret_aenergy.total": WH_TO_KWH,
}
BOOL_FIELDS = frozenset({"output", "state"})
# Grenzen wie bei Generation 1, zusätzlich Temperatur und Luftfeuchte
GEN2_LIMITS: dict[str, tuple[float, float]] = {
    "apower": (-30_000.0, 30_000.0),
    "act_power": (-30_000.0, 30_000.0),
    "voltage": (0.0, 500.0),
    "current": (0.0, 300.0),
    "tC": (-60.0, 250.0),
    "rh": (0.0, 100.0),
    "freq": (0.0, 100.0),
    "pf": (-1.0, 1.0),
}


def _dig(data: dict[str, Any], path: str) -> Any:
    """Feld einer Komponente, auch verschachtelt (`aenergy.total`)."""
    cur: Any = data
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


@dataclass
class Gen2State:
    """Letzter Zustand je Komponente eines Gen-2-Geräts, übersetzt in Domänenschlüssel."""

    topic_prefix: str
    components: dict[str, str | dict[str, str]]
    values: dict[str, _Value] = field(default_factory=dict)  # Domänenschlüssel → Wert
    faulted: dict[str, datetime] = field(default_factory=dict)  # Schlüssel, deren Komponente meldet
    last_message_at: datetime | None = None
    messages: int = 0
    rejected: int = 0

    @property
    def answer_topic(self) -> str:
        """Eigenes Antwort-Topic je Gerät: so ist zuzuordnen, wer geantwortet hat."""
        return f"{RPC_SRC}/{self.topic_prefix}"

    def topics(self) -> list[str]:
        return [
            f"{self.topic_prefix}/events/rpc",
            f"{self.topic_prefix}/status/#",
            f"{self.answer_topic}/rpc",
        ]

    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool:
        if topic == f"{self.answer_topic}/rpc":
            return self._answer(payload, now)
        if not topic.startswith(self.topic_prefix + "/"):
            return False
        self.messages += 1
        rest = topic[len(self.topic_prefix) + 1 :]
        text = payload.decode("utf-8", errors="replace") if isinstance(payload, bytes) else payload
        try:
            data = json.loads(text)
        except ValueError:
            self.rejected += 1
            return False
        if not isinstance(data, dict):
            self.rejected += 1
            return False
        if rest == "events/rpc":
            if data.get("method") not in ("NotifyStatus", "NotifyFullStatus"):
                return False  # NotifyEvent und Antworten auf Aufrufe interessieren hier nicht
            params = data.get("params")
            if not isinstance(params, dict):
                self.rejected += 1
                return False
            touched = False
            for component, state in params.items():
                if isinstance(state, dict) and self._component(component, state, now):
                    touched = True
            if touched:
                self.last_message_at = now
            return touched
        if rest.startswith("status/") and self._component(rest[len("status/") :], data, now):
            self.last_message_at = now
            return True
        return False

    def _answer(self, payload: bytes | str, now: datetime) -> bool:
        """Antwort auf Shelly.GetStatus: `result` enthält alle Komponenten in einer Nachricht."""
        self.messages += 1
        text = payload.decode("utf-8", errors="replace") if isinstance(payload, bytes) else payload
        try:
            data = json.loads(text)
        except ValueError:
            self.rejected += 1
            return False
        result = data.get("result") if isinstance(data, dict) else None
        if not isinstance(result, dict):
            self.rejected += 1
            return False
        touched = False
        for component, state in result.items():
            if isinstance(state, dict) and self._component(component, state, now):
                touched = True
        if touched:
            self.last_message_at = now
        return touched

    def _component(self, component: str, state: dict[str, Any], now: datetime) -> bool:
        target = self.components.get(component)
        if target is None:
            return False
        fields = (
            {NATURAL_FIELD.get(component.split(":")[0], "value"): target}
            if isinstance(target, str)
            else target
        )
        # Ein Fühler mit Lesefehler meldet `tC: null` und `errors: ["read"]`. Ohne diesen Zweig bliebe
        # der zuletzt gültige Wert stehen – die Anzeige zeigte dann eine Temperatur, die es nicht gibt.
        broken = bool(state.get("errors"))
        touched = False
        for field_path, key in fields.items():
            value = self._value(field_path, state)
            if value is None:
                explicit_null = field_path in state and _dig(state, field_path) is None
                if broken or explicit_null:
                    self.values.pop(key, None)
                    self.faulted[key] = now
                    touched = True
                continue
            self.faulted.pop(key, None)
            self.values[key] = _Value(value, now)
            touched = True
        return touched

    def _value(self, field_path: str, state: dict[str, Any]) -> float | None:
        raw = _dig(state, field_path)
        if raw is None:
            return None
        if field_path.rsplit(".", 1)[-1] in BOOL_FIELDS or isinstance(raw, bool):
            return 1.0 if raw else 0.0
        if not isinstance(raw, int | float):
            self.rejected += 1
            return None
        value = float(raw)
        if math.isnan(value) or math.isinf(value):
            self.rejected += 1
            return None
        lo, hi = GEN2_LIMITS.get(field_path.rsplit(".", 1)[-1], (-1e12, 1e12))
        if not lo <= value <= hi:
            self.rejected += 1
            log.debug("gen2 value out of range", component=field_path, value=value)
            return None
        return round(value * FIELD_SCALE.get(field_path, 1.0), 4)

    def readings(self, now: datetime, stale_after: timedelta, source: str) -> list[RawReading]:
        out = [
            RawReading(key=key, value=v.value, observed_at=v.at, source=source)
            for key, v in self.values.items()
            if now - v.at <= stale_after
        ]
        out += [
            RawReading(
                key=key, value=None, observed_at=at, quality=Quality.UNAVAILABLE, source=source
            )
            for key, at in self.faulted.items()
            if now - at <= stale_after
        ]
        return out

    def is_stale(
        self, now: datetime, stale_after: timedelta, since: datetime | None = None
    ) -> bool:
        ref = self.last_message_at or since
        return ref is None or now - ref > stale_after


# ---------------------------------------------------------------------- Vergleich HA ↔ MQTT
@dataclass
class Comparator:
    """Vergleichsmodus: HA-Wert bleibt maßgeblich, MQTT wird daneben gemessen; Abweichungen ins Protokoll."""

    tolerance_kw: float = 0.05
    tolerance_rel: float = 0.05
    summary_every: int = 60
    samples: int = 0
    deviations: int = 0
    max_delta_kw: float = 0.0
    sum_abs_delta_kw: float = 0.0
    ha_kw: float | None = None
    ha_at: datetime | None = None

    def note_ha(self, value_kw: float | None, at: datetime) -> None:
        self.ha_kw = value_kw
        self.ha_at = at

    def compare(self, mqtt_kw: float, at: datetime) -> float | None:
        if self.ha_kw is None or self.ha_at is None or abs((at - self.ha_at).total_seconds()) > 120:
            return None
        delta = mqtt_kw - self.ha_kw
        self.samples += 1
        self.sum_abs_delta_kw += abs(delta)
        self.max_delta_kw = max(self.max_delta_kw, abs(delta))
        tol = max(self.tolerance_kw, self.tolerance_rel * abs(self.ha_kw))
        if abs(delta) > tol:
            self.deviations += 1
            log.warning(
                "compare: mqtt deviates from ha",
                ha_kw=self.ha_kw,
                mqtt_kw=round(mqtt_kw, 3),
                delta_kw=round(delta, 3),
            )
        if self.samples % self.summary_every == 0:
            log.info(
                "compare summary",
                samples=self.samples,
                deviations=self.deviations,
                mean_abs_delta_kw=round(self.sum_abs_delta_kw / self.samples, 4),
                max_delta_kw=round(self.max_delta_kw, 3),
            )
        return delta


# ---------------------------------------------------------------------- MQTT-Anbindung
class MqttMessage(Protocol):
    @property
    def topic(self) -> Any: ...
    @property
    def payload(self) -> Any: ...


class MqttSession(Protocol):
    """Was wir vom MQTT-Client brauchen (aiomqtt.Client erfüllt das; Tests nutzen eine Attrappe)."""

    async def __aenter__(self) -> MqttSession: ...
    async def __aexit__(self, *exc: object) -> None: ...
    async def subscribe(self, topic: str, qos: int = 0) -> Any: ...
    async def publish(self, topic: str, payload: Any, qos: int = 0) -> Any: ...
    @property
    def messages(self) -> AsyncIterator[MqttMessage]: ...


SessionFactory = Callable[[], MqttSession]
ReadingsSink = Callable[[list[RawReading]], Awaitable[None]]


class Device(Protocol):
    """Ein Gerät am Broker: sagt, was es abonnieren will, verarbeitet Nachrichten, liefert Messwerte."""

    label: str

    def topics(self) -> list[str]: ...
    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool: ...
    def emit(self, now: datetime) -> list[RawReading]: ...
    def status(self) -> dict[str, Any]: ...
    @property
    def owned_keys(self) -> set[str]: ...
    def command(self, key: str, state: bool, ttl_s: float | None) -> tuple[str, str] | None:
        """Topic und Nutzdaten, um `key` zu schalten – None, wenn das Gerät das nicht kann."""
        ...

    def poll(self) -> tuple[str, str] | None:
        """Topic und Nutzdaten, um den vollständigen Zustand abzufragen – None, wenn nicht nötig."""
        ...

    def observed(self, key: str) -> bool | None:
        """Zuletzt empfangener Schaltzustand zu `key`, None wenn unbekannt."""
        ...


@dataclass
class Em3Device:
    """Shelly 3EM der ersten Generation: Summen und alle drei Phasen im festen Takt."""

    topic_prefix: str
    device_id: str
    key_prefix: str
    stale_s: float = 90.0
    comparator: Comparator | None = None
    label: str = "Shelly 3EM"
    state: Shelly3EmState = field(init=False)
    emitted: int = 0
    _unavailable_sent: bool = field(default=False, init=False)
    _last_seen_messages: int = field(default=0, init=False)
    _started_at: datetime | None = field(default=None, init=False)

    def __post_init__(self) -> None:
        self.state = Shelly3EmState(topic_prefix=self.topic_prefix)

    @property
    def owned_keys(self) -> set[str]:
        return {f"{self.key_prefix}_power_kw", f"{self.key_prefix}_energy_kwh"}

    def command(self, key: str, state: bool, ttl_s: float | None) -> tuple[str, str] | None:
        return None  # ein Zähler schaltet nichts

    def poll(self) -> tuple[str, str] | None:
        return None  # Generation 1 sendet von sich aus laufend

    def observed(self, key: str) -> bool | None:
        return None

    def topics(self) -> list[str]:
        return [f"{self.topic_prefix}/#"]

    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool:
        return self.state.apply(topic, payload, now)

    def emit(self, now: datetime) -> list[RawReading]:
        """Konsistenter Datensatz, sobald alle drei Phasen frisch sind – sonst die Nichtverfügbarkeit."""
        stale = timedelta(seconds=self.stale_s)
        if self._started_at is None:
            self._started_at = now
        snap = self.state.snapshot(now, stale) if self.state.online is not False else None
        if snap is None:
            offline = self.state.online is False or self.state.is_stale(
                now, stale, self._started_at
            )
            if offline and not self._unavailable_sent:
                self._unavailable_sent = True
                log.warning(
                    "shelly unavailable",
                    device=self.device_id,
                    online=self.state.online,
                    last_message_at=self.state.last_message_at,
                )
                return unavailable_readings(self.key_prefix, self.device_id, now)
            return []
        if self.state.messages == self._last_seen_messages and not self._unavailable_sent:
            return []  # nichts Neues seit dem letzten Takt
        self._last_seen_messages = self.state.messages
        self._unavailable_sent = False
        if self.comparator is not None:
            self.comparator.compare(snap.power_w * W_TO_KW, snap.at)
        self.emitted += 1
        return readings_from_snapshot(snap, self.key_prefix, self.device_id)

    def status(self) -> dict[str, Any]:
        return {
            "device": self.device_id,
            "online": self.state.online,
            "messages": self.state.messages,
            "rejected": self.state.rejected,
            "emitted": self.emitted,
            "last_message_at": self.state.last_message_at,
        }


@dataclass
class Gen2Device:
    """Shelly Plus oder Pro: die im Mapping genannten Komponenten als Messwerte."""

    topic_prefix: str
    components: dict[str, str | dict[str, str]]
    stale_s: float = 300.0  # Temperaturen ändern sich langsam; das Gerät meldet seltener
    label: str = "Shelly Plus"
    state: Gen2State = field(init=False)
    emitted: int = 0
    _last_seen_messages: int = field(default=0, init=False)
    _switchable: dict[str, tuple[str, int]] = field(default_factory=dict, init=False)
    _rpc_ids: Iterator[int] = field(default_factory=lambda: itertools.count(1), init=False)

    def __post_init__(self) -> None:
        self.state = Gen2State(topic_prefix=self.topic_prefix, components=self.components)
        # Schaltbar ist, was auf das Feld `output` einer Switch-Komponente zeigt.
        self._switchable = {}
        self._rpc_ids = itertools.count(1)
        for component, target in self.components.items():
            kind, _, ident = component.partition(":")
            if kind not in SWITCHABLE_KINDS or not ident.isdigit():
                continue
            fields = (
                {NATURAL_FIELD.get(kind, "value"): target} if isinstance(target, str) else target
            )
            for field_path, mapped in fields.items():
                if field_path == "output":
                    self._switchable[mapped] = (kind, int(ident))

    @property
    def owned_keys(self) -> set[str]:
        out: set[str] = set()
        for target in self.components.values():
            out |= {target} if isinstance(target, str) else set(target.values())
        return out

    def topics(self) -> list[str]:
        return self.state.topics()

    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool:
        return self.state.apply(topic, payload, now)

    def emit(self, now: datetime) -> list[RawReading]:
        if self.state.messages == self._last_seen_messages:
            return []
        self._last_seen_messages = self.state.messages
        items = self.state.readings(
            now, timedelta(seconds=self.stale_s), f"mqtt:{self.topic_prefix}"
        )
        if items:
            self.emitted += 1
        return items

    def command(self, key: str, state: bool, ttl_s: float | None) -> tuple[str, str] | None:
        """Switch.Set an <präfix>/rpc. `ttl_s` wird zu `toggle_after`: der Shelly fällt von selbst
        zurück, falls kein weiteres Kommando kommt – dieselbe Absicherung wie ein Auto-Off-Timer."""
        target = self._switchable.get(key)
        if target is None:
            return None
        kind, ident = target
        params: dict[str, Any] = {"id": ident, "on": state}
        if ttl_s and ttl_s > 0:
            params["toggle_after"] = int(ttl_s)
        payload = {
            "id": next(self._rpc_ids),
            "src": self.state.answer_topic,
            "method": f"{kind.capitalize()}.Set",
            "params": params,
        }
        return f"{self.topic_prefix}/rpc", json.dumps(payload)

    def poll(self) -> tuple[str, str] | None:
        """Shelly.GetStatus. Nötig, weil NotifyStatus nur bei Änderung kommt: nach einem Neustart
        wüsste die Bridge sonst nichts, und ein ruhender Fühler bliebe für immer unbekannt."""
        payload = {
            "id": next(self._rpc_ids),
            "src": self.state.answer_topic,
            "method": "Shelly.GetStatus",
        }
        return f"{self.topic_prefix}/rpc", json.dumps(payload)

    def observed(self, key: str) -> bool | None:
        value = self.state.values.get(key)
        if value is None:
            return None
        return value.value >= 0.5

    def status(self) -> dict[str, Any]:
        return {
            "device": self.topic_prefix,
            "components": len(self.components),
            "values": len(self.state.values),
            "messages": self.state.messages,
            "rejected": self.state.rejected,
            "emitted": self.emitted,
            "last_message_at": self.state.last_message_at,
        }


@dataclass
class MqttHub:
    """Eine Verbindung zum Broker für alle Geräte: Reconnect mit Backoff, Takt-Emission, Kennzahlen."""

    session_factory: SessionFactory
    devices: list[Device]
    on_readings: ReadingsSink
    publish_interval_s: float = 10.0
    poll_interval_s: float = 120.0  # Vollstand abrufen; 0 schaltet den Abruf ab
    qos: int = 1
    forward: bool = True  # False im Vergleichsmodus: nur messen, nicht senden
    connected: bool = False
    reconnects: int = 0
    commands: int = 0
    polls: int = 0
    _session: MqttSession | None = field(default=None, init=False)

    @property
    def owned_keys(self) -> set[str]:
        out: set[str] = set()
        for dev in self.devices:
            out |= dev.owned_keys
        return out

    def can_switch(self, key: str) -> bool:
        return any(dev.command(key, True, None) is not None for dev in self.devices)

    async def switch(
        self, key: str, state: bool, ttl_s: float | None, timeout_s: float = 5.0
    ) -> bool | None:
        """Aktor über den Broker schalten und auf die Rückmeldung des Geräts warten.

        Rückgabe ist der beobachtete Zustand, nicht der gewünschte: der Shelly meldet die Änderung
        von sich aus per NotifyStatus, und erst die zählt als Bestätigung. None heißt „keine
        Rückmeldung“ – der Aufrufer wertet das als nicht bestätigt.
        """
        session = self._session
        if session is None:
            raise RuntimeError("keine MQTT-Verbindung")
        for dev in self.devices:
            built = dev.command(key, state, ttl_s)
            if built is None:
                continue
            topic, payload = built
            await session.publish(topic, payload, qos=self.qos)
            self.commands += 1
            deadline = asyncio.get_running_loop().time() + timeout_s
            while asyncio.get_running_loop().time() < deadline:
                if dev.observed(key) == state:
                    return state
                await asyncio.sleep(0.05)
            return dev.observed(key)
        raise LookupError(f"kein MQTT-Gerät für {key}")

    async def run(self) -> None:
        await asyncio.gather(self._connect_loop(), self._emit_loop(), self._poll_loop())

    async def _poll_loop(self) -> None:
        while True:
            if self.poll_interval_s <= 0:
                await asyncio.sleep(60.0)
                continue
            await asyncio.sleep(self.poll_interval_s)
            with contextlib.suppress(Exception):
                await self.poll_once()

    async def poll_once(self) -> int:
        """Alle Geräte nach ihrem vollständigen Zustand fragen. Antworten laufen als Nachrichten ein."""
        session = self._session
        if session is None:
            return 0
        sent = 0
        for dev in self.devices:
            built = dev.poll()
            if built is None:
                continue
            await session.publish(built[0], built[1], qos=self.qos)
            sent += 1
        self.polls += sent
        return sent

    async def _connect_loop(self) -> None:
        backoff = 1.0
        while True:
            try:
                async with self.session_factory() as session:
                    for topic in sorted({t for dev in self.devices for t in dev.topics()}):
                        await session.subscribe(topic, qos=self.qos)
                    self._session = session
                    self.connected = True
                    backoff = 1.0
                    log.info("mqtt connected", devices=len(self.devices), qos=self.qos)
                    # Sofort den Ist-Zustand holen, statt auf die erste Änderung zu warten.
                    with contextlib.suppress(Exception):
                        await self.poll_once()
                    async for msg in session.messages:
                        now = datetime.now(UTC)
                        topic = str(msg.topic)
                        for dev in self.devices:
                            if dev.apply(topic, msg.payload, now):
                                break
                log.warning("mqtt stream ended")
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # aiomqtt.MqttError, OSError, …
                log.warning("mqtt connection failed", error=str(exc)[:200])
            self.connected = False
            self._session = None
            self.reconnects += 1
            await asyncio.sleep(backoff + random.uniform(0, 0.5))
            backoff = min(backoff * 2, 60.0)

    async def _emit_loop(self) -> None:
        while True:
            await asyncio.sleep(self.publish_interval_s)
            with contextlib.suppress(Exception):
                await self.emit_once(datetime.now(UTC))

    async def emit_once(self, now: datetime) -> list[RawReading]:
        """Einen Takt auswerten: alle Geräte abfragen und die Messwerte weiterreichen."""
        items: list[RawReading] = []
        for dev in self.devices:
            items.extend(dev.emit(now))
        if items and self.forward:
            await self.on_readings(items)
        return items

    def status(self) -> dict[str, Any]:
        return {
            "connected": self.connected,
            "reconnects": self.reconnects,
            "commands": self.commands,
            "polls": self.polls,
            "devices": [dev.status() for dev in self.devices],
        }


def aiomqtt_session_factory(
    host: str, port: int, username: str, password: str, client_id: str
) -> SessionFactory:
    """Echte Verbindung (unverschlüsselt im LAN – der Shelly 3EM Gen1 kann kein TLS). Zugangsdaten werden nie
    protokolliert."""
    import aiomqtt

    def make() -> MqttSession:
        return aiomqtt.Client(  # type: ignore[return-value]
            hostname=host,
            port=port,
            username=username or None,
            password=password or None,
            identifier=client_id,
            keepalive=30,
            clean_session=False,
        )

    return make
