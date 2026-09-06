"""Shelly 3EM (Gen1) direkt über MQTT: letzter gültiger Zustand je Phase → konsistenter Datensatz im Takt.

Der Shelly veröffentlicht jede Größe als eigene Nachricht unter
`shellies/shellyem3-<id>/emeter/<phase>/{power,voltage,current,pf,total,total_returned}` und
`shellies/shellyem3-<id>/online`. Dieses Modul validiert jede Nachricht, hält je Phase den letzten gültigen
Wert und erzeugt daraus alle `publish_interval_s` einen Satz `RawReading`s in der Domänenkonvention (kW, kWh).

Einheiten: Leistung kommt in W, Energie (`total`, `total_returned`) in Wh aus dem nichtflüchtigen Speicher.
Beide werden hier explizit durch 1000 geteilt. `energy`/`returned_energy` (flüchtig) werden ignoriert.
"""

from __future__ import annotations

import asyncio
import contextlib
import math
import random
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

import structlog

from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

log = structlog.get_logger("shelly_mqtt")

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
    @property
    def messages(self) -> AsyncIterator[MqttMessage]: ...


SessionFactory = Callable[[], MqttSession]
ReadingsSink = Callable[[list[RawReading]], Awaitable[None]]


@dataclass
class ShellyMqttSource:
    """Verbindung zum Broker mit Reconnect, Takt-Emission, Online-/Offline-Erkennung."""

    session_factory: SessionFactory
    topic_prefix: str
    device_id: str
    key_prefix: str
    on_readings: ReadingsSink
    publish_interval_s: float = 10.0
    stale_s: float = 90.0
    qos: int = 1
    comparator: Comparator | None = None
    forward: bool = True  # False im Vergleichsmodus: nur messen, nicht senden
    state: Shelly3EmState = field(init=False)
    connected: bool = False
    reconnects: int = 0
    emitted: int = 0
    _unavailable_sent: bool = field(default=False, init=False)
    _last_seen_messages: int = field(default=0, init=False)
    _started_at: datetime | None = field(default=None, init=False)

    def __post_init__(self) -> None:
        self.state = Shelly3EmState(topic_prefix=self.topic_prefix)

    @property
    def owned_keys(self) -> set[str]:
        return {f"{self.key_prefix}_power_kw", f"{self.key_prefix}_energy_kwh"}

    async def run(self) -> None:
        await asyncio.gather(self._connect_loop(), self._emit_loop())

    async def _connect_loop(self) -> None:
        backoff = 1.0
        while True:
            try:
                async with self.session_factory() as session:
                    await session.subscribe(f"{self.topic_prefix}/#", qos=self.qos)
                    self.connected = True
                    backoff = 1.0
                    log.info("mqtt connected", topic=f"{self.topic_prefix}/#", qos=self.qos)
                    async for msg in session.messages:
                        self.state.apply(str(msg.topic), msg.payload, datetime.now(UTC))
                log.warning("mqtt stream ended")
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # aiomqtt.MqttError, OSError, …
                log.warning("mqtt connection failed", error=str(exc)[:200])
            self.connected = False
            self.reconnects += 1
            delay = backoff + random.uniform(0, 0.5)
            await asyncio.sleep(delay)
            backoff = min(backoff * 2, 60.0)

    async def _emit_loop(self) -> None:
        while True:
            await asyncio.sleep(self.publish_interval_s)
            with contextlib.suppress(Exception):
                await self.emit_once(datetime.now(UTC))

    async def emit_once(self, now: datetime) -> list[RawReading]:
        """Einen konsistenten Datensatz erzeugen (oder Nichtverfügbarkeit melden). Für Tests direkt aufrufbar."""
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
                items = unavailable_readings(self.key_prefix, self.device_id, now)
                log.warning(
                    "shelly unavailable",
                    online=self.state.online,
                    last_message_at=self.state.last_message_at,
                )
                if self.forward:
                    await self.on_readings(items)
                return items
            return []
        if self.state.messages == self._last_seen_messages and not self._unavailable_sent:
            return []  # nichts Neues seit dem letzten Takt
        self._last_seen_messages = self.state.messages
        self._unavailable_sent = False
        items = readings_from_snapshot(snap, self.key_prefix, self.device_id)
        if self.comparator is not None:
            self.comparator.compare(snap.power_w * W_TO_KW, snap.at)
        if self.forward:
            await self.on_readings(items)
            self.emitted += 1
        return items

    def status(self) -> dict[str, object]:
        return {
            "connected": self.connected,
            "online": self.state.online,
            "messages": self.state.messages,
            "rejected": self.state.rejected,
            "reconnects": self.reconnects,
            "emitted": self.emitted,
            "last_message_at": self.state.last_message_at,
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
