"""Bridge-Hauptprogramm: HA lesen → normalisieren → Uplink; Kommandos; Heartbeat; Wächter."""

from __future__ import annotations

import asyncio
import contextlib
import logging
import sys
from datetime import UTC, datetime, timedelta

import structlog

from dch_bridge.entities_source import load_entity_map
from dch_bridge.home_assistant.rest_client import HaRestClient
from dch_bridge.home_assistant.ws_client import EntityState, HaWsClient
from dch_bridge.mapping import ActuatorMap, EntityMap, normalize
from dch_bridge.outbox import Outbox
from dch_bridge.settings import BridgeSettings
from dch_bridge.sources.mcz_maestro import MaestroStove, stove_url
from dch_bridge.sources.shelly_mqtt import (
    Comparator,
    Device,
    Em3Device,
    Gen2Device,
    MqttHub,
    aiomqtt_session_factory,
)
from dch_bridge.uplink.client import UplinkClient
from hems_core.protocol import CommandFrame, CommandResultFrame, RawReading

VERSION = "0.7.0"
log = structlog.get_logger("bridge")


class Bridge:
    def __init__(self, settings: BridgeSettings, entity_map: EntityMap) -> None:
        self.settings = settings
        self.map = entity_map
        self.by_entity = entity_map.by_entity()
        self.ha = HaWsClient(settings.ha_ws_url, settings.ha_token, set(self.by_entity))
        self.rest = HaRestClient(settings.ha_rest_url, settings.ha_token)
        self.outbox = Outbox(
            settings.outbox_path, max_age=timedelta(hours=settings.outbox_max_age_h)
        )
        # Pelletofen: eigene WebSocket-Verbindung, unabhängig von Home Assistant und vom Broker.
        # Vor dem Uplink, damit seine Schlüssel im hello mit angekündigt werden.
        self.stove: MaestroStove | None = None
        if settings.mcz_host:
            self.stove = MaestroStove(
                url=stove_url(settings.mcz_host, settings.mcz_port),
                on_readings=self._ingest_readings,
                poll_interval_s=settings.mcz_poll_interval_s,
                allow_control=settings.mcz_allow_control,
            )
        self.uplink = UplinkClient(
            url=settings.api_ws_url,
            token=settings.api_token,
            bridge_id=settings.bridge_id,
            bridge_version=VERSION,
            entity_map_hash=entity_map.digest(),
            keys=entity_map.keys()
            + (self.stove.keys if self.stove else [])
            + (["actuator:stove"] if self.stove and settings.mcz_allow_control else []),
            outbox=self.outbox,
            on_command=self.execute_command,
        )
        self.latest: dict[str, EntityState] = {}
        self._pending: dict[str, RawReading] = {}
        self._released_contacts_after_offline = False
        self._last_sent: dict[str, tuple[float | None, str | None]] = {}
        self._sent_by_source: dict[str, int] = {}  # kumulativ, je Quellenart
        # Geräte, die direkt über MQTT gelesen werden (Modus mqtt/compare). Im Modus mqtt liefert Home
        # Assistant die dort abgedeckten Schlüssel nicht mehr - sie kämen sonst doppelt und älter.
        self.mqtt: MqttHub | None = None
        self.comparator: Comparator | None = None
        self._mqtt_owned: set[str] = set()
        devices = self._mqtt_devices()
        if devices:
            self.mqtt = MqttHub(
                session_factory=aiomqtt_session_factory(
                    settings.mqtt_host,
                    settings.mqtt_port,
                    settings.mqtt_username,
                    settings.mqtt_password,
                    client_id=f"dch-bridge-{settings.bridge_id}",
                ),
                devices=devices,
                on_readings=self._ingest_readings,
                publish_interval_s=settings.mqtt_publish_interval_s,
                qos=settings.mqtt_qos,
                poll_interval_s=settings.mqtt_poll_interval_s,
                forward=settings.source_mode == "mqtt",
            )
            if settings.source_mode == "mqtt":
                self._mqtt_owned = self.mqtt.owned_keys
            else:
                log.warning(
                    "MQTT-Geräte werden nur mitgelesen, nicht gesendet",
                    source_mode=settings.source_mode,
                    hint="source_mode auf mqtt setzen, damit die Werte in der API ankommen",
                    devices=[d.label for d in devices],
                )

    def _mqtt_devices(self) -> list[Device]:
        """Geräteliste aus dem Entity-Mapping; der Shelly 3EM geht ersatzweise auch über die Add-on-Optionen."""
        settings = self.settings
        if settings.source_mode == "home_assistant":
            return []
        out: list[Device] = []
        for dev in self.map.mqtt:
            if dev.kind == "em3":
                self.comparator = Comparator() if settings.source_mode == "compare" else None
                out.append(
                    Em3Device(
                        topic_prefix=dev.prefix,
                        device_id=dev.prefix.rsplit("-", 1)[-1],
                        key_prefix=dev.key_prefix or settings.mqtt_key_prefix,
                        stale_s=settings.mqtt_stale_s,
                        comparator=self.comparator,
                        label=dev.label or "Shelly 3EM",
                    )
                )
            elif dev.components:
                out.append(
                    Gen2Device(
                        topic_prefix=dev.prefix,
                        components=dev.components,
                        label=dev.label or "Shelly Plus",
                    )
                )
        if not out and settings.shelly_topic_prefix:
            self.comparator = Comparator() if settings.source_mode == "compare" else None
            out.append(
                Em3Device(
                    topic_prefix=settings.shelly_topic_prefix,
                    device_id=settings.shelly_topic_prefix.rsplit("-", 1)[-1],
                    key_prefix=settings.mqtt_key_prefix,
                    stale_s=settings.mqtt_stale_s,
                    comparator=self.comparator,
                )
            )
        return out

    # ------------------------------------------------------------------ Lesen
    def _ingest(self, st: EntityState) -> None:
        m = self.by_entity.get(st.entity_id)
        if m is None:
            return
        self.latest[st.entity_id] = st
        now = datetime.now(UTC)
        reading = normalize(m, st.state, st.attributes, st.observed_at, now)
        if (
            self.comparator is not None
            and reading.key == f"{self.settings.mqtt_key_prefix}_power_kw"
        ):
            self.comparator.note_ha(reading.value, reading.observed_at)
        # Modus mqtt: der Shelly kommt direkt über den Broker - aber nur solange er auch wirklich
        # meldet. Schweigt er, springt Home Assistant ein, statt den letzten Stand einfrieren zu lassen.
        if (
            reading.key in self._mqtt_owned
            and self.mqtt is not None
            and self.mqtt.has_fresh(reading.key, now)
        ):
            return
        self._pending[reading.key] = reading

    async def _ingest_readings(self, items: list[RawReading]) -> None:
        """Messwerte einer Nicht-HA-Quelle (MQTT, Pelletofen) in denselben Sammelpuffer."""
        for r in items:
            self._pending[r.key] = r

    async def _ha_loop(self) -> None:
        backoff = 1.0
        while True:
            try:
                await self.ha.connect()
                for st in await self.ha.get_states():
                    self._ingest(st)
                await self.ha.subscribe_state_changes()
                backoff = 1.0
                async for st in self.ha.events():
                    self._ingest(st)
                log.warning("ha stream ended")
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.warning("ha connection failed", error=str(exc)[:200])
            with contextlib.suppress(Exception):
                await self.ha.close()
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60.0)

    async def _refresh_loop(self) -> None:
        """Alle Zustände periodisch neu lesen: HA sendet state_changed nur bei Änderungen, ein konstanter Wert
        (PV nachts, Puffertemperatur) würde sonst nie wieder gemeldet und in der API als veraltet gelten."""
        while True:
            await asyncio.sleep(self.settings.state_refresh_s)
            if not self.ha.connected:
                continue
            try:
                for st in await self.ha.get_states():
                    self._ingest(st)
            except Exception as exc:
                log.warning("state refresh failed", error=repr(exc)[:200])

    async def _telemetry_loop(self) -> None:
        while True:
            await asyncio.sleep(self.settings.telemetry_interval_s)
            if not self._pending:
                continue
            items = list(self._pending.values())
            self._pending.clear()
            # Fortschreiben, nicht ersetzen: ein Takt trägt nur die Schlüssel, die gerade neu sind.
            # Ersetzen hieße, dass die Statuszeile alle fünf Minuten eine zufällige Sekunde zeigt
            # statt den letzten bekannten Stand jeder Größe.
            self._last_sent.update({r.key: (r.value, r.source) for r in items})
            for r in items:
                kind = (r.source or "?").split(":", 1)[0]
                self._sent_by_source[kind] = self._sent_by_source.get(kind, 0) + 1
            await self.uplink.publish(items)

    # ------------------------------------------------------------------ Schalten
    def _actuator(self, key: str) -> ActuatorMap | None:
        for a in self.map.actuators:
            if a.key == key:
                return a
        return None

    async def execute_command(self, cmd: CommandFrame) -> CommandResultFrame:
        now = datetime.now(UTC)
        a = self._actuator(cmd.actuator_key)
        # Aktoren, die einem MQTT-Gerät gehören, werden direkt am Broker geschaltet - kein Umweg über
        # Home Assistant. Ausgenommen die Sicherheitsklasse heat_pump: dort bleibt der Weg über HA,
        # damit die Wächter-Automation denselben Schalter sieht, den DCH stellt.
        key = f"actuator:{cmd.actuator_key}"
        safety = a.safety_class if a is not None else "none"
        # Der Ofen hängt an keinem Broker und an keiner HA-Entität: er wird direkt über seinen
        # eigenen WebSocket geschaltet, und nur wenn die Freigabe gesetzt ist.
        if self.stove is not None and self.stove.can_switch(key):
            try:
                observed = await self.stove.switch(key, cmd.state)
            except Exception as exc:
                return CommandResultFrame(
                    command_id=cmd.command_id,
                    ok=False,
                    observed_state=None,
                    error=str(exc)[:200],
                    at=datetime.now(UTC),
                )
            # Beim Ofen zählt als gelungen, dass der Befehl angekommen ist. Ein Pelletofen
            # bestätigt nicht in Sekunden: Zünden dauert Minuten, und beim Abschalten meldet die
            # Firmware die ganze Ausbrandphase über weiter „läuft". `observed_state` sagt, was er
            # gerade tut; wer das mit „nicht geschaltet" verwechselt, zeigt beim Anheizen Fehler an.
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=True,
                observed_state=observed,
                error=None,
                at=datetime.now(UTC),
            )
        if self.mqtt is not None and safety != "heat_pump" and self.mqtt.can_switch(key):
            try:
                observed = await self.mqtt.switch(key, cmd.state, cmd.ttl_s)
            except Exception as exc:
                return CommandResultFrame(
                    command_id=cmd.command_id,
                    ok=False,
                    observed_state=None,
                    error=str(exc)[:200],
                    at=datetime.now(UTC),
                )
            ok = observed == cmd.state
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=ok,
                observed_state=observed,
                error=None if ok else "Zustand nicht bestätigt",
                at=datetime.now(UTC),
            )
        if a is None:
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=False,
                observed_state=None,
                error="unbekannter Aktor",
                at=now,
            )
        domain = a.entity.split(".", 1)[0]
        service = "turn_on" if cmd.state else "turn_off"
        try:
            await self.ha.call_service(domain, service, a.entity)
            observed = await self._wait_for_state(a.entity, cmd.state, timeout_s=5.0)
            ok = observed == cmd.state
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=ok,
                observed_state=observed,
                error=None if ok else "Zustand nicht bestätigt",
                at=datetime.now(UTC),
            )
        except Exception as exc:
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=False,
                observed_state=None,
                error=str(exc)[:200],
                at=datetime.now(UTC),
            )

    async def _wait_for_state(self, entity: str, want: bool, timeout_s: float) -> bool | None:
        deadline = asyncio.get_running_loop().time() + timeout_s
        while asyncio.get_running_loop().time() < deadline:
            st = self.latest.get(entity)
            if st is not None and (st.state == "on") == want:
                return want
            await asyncio.sleep(0.2)
        st = self.latest.get(entity)
        return None if st is None else st.state == "on"

    # ------------------------------------------------------------------ Wächter / Heartbeat
    async def _guardian_loop(self) -> None:
        """Ohne Cloud-Kontakt länger als offline_release_s: Wärmepumpen-Kontakte zurücksetzen."""
        while True:
            await asyncio.sleep(self.settings.heartbeat_interval_s)
            connected = self.uplink.connected
            with contextlib.suppress(Exception):
                await self.rest.set_heartbeat(self.settings.heartbeat_entity, connected)
            since = self.uplink.seconds_since_contact
            offline = not connected and (since is None or since > self.settings.offline_release_s)
            if offline and not self._released_contacts_after_offline:
                for a in self.map.actuators:
                    if a.safety_class == "heat_pump":
                        st = self.latest.get(a.entity)
                        if st is not None and (st.state == "on") != a.safe_state:
                            log.warning("offline: resetting heat pump contact", entity=a.entity)
                            with contextlib.suppress(Exception):
                                await self.ha.call_service(
                                    a.entity.split(".")[0],
                                    "turn_on" if a.safe_state else "turn_off",
                                    a.entity,
                                )
                self._released_contacts_after_offline = True
            if connected:
                self._released_contacts_after_offline = False

    async def _source_status_loop(self) -> None:
        """Alle 5 Minuten Kennzahlen der Direktquellen ins Protokoll (Nachrichten, verworfen, Reconnects)."""
        while True:
            await asyncio.sleep(300)
            if self.mqtt is not None:
                log.info("mqtt status", **self.mqtt.status())
            if self.stove is not None:
                log.info("stove status", **self.stove.status())
            # Welche Schlüssel zuletzt tatsächlich an die API gingen - und aus welcher Quelle.
            log.info(
                "telemetry keys",
                owned_by_mqtt=sorted(self._mqtt_owned),
                sent_by_source=self._sent_by_source,
                last_sent={k: v for k, v in sorted(self._last_sent.items())},
            )

    async def run(self) -> None:
        log.info(
            "bridge starting",
            version=VERSION,
            sensors=len(self.map.sensors),
            actuators=len(self.map.actuators),
            source_mode=self.settings.source_mode,
            mqtt=f"{self.settings.mqtt_host}:{self.settings.mqtt_port}" if self.mqtt else None,
            mqtt_devices=[d.label for d in self.mqtt.devices] if self.mqtt else [],
            stove=self.stove.url if self.stove else None,
        )
        tasks = [
            asyncio.create_task(self._ha_loop(), name="ha"),
            asyncio.create_task(self._telemetry_loop(), name="telemetry"),
            asyncio.create_task(self._refresh_loop(), name="refresh"),
            asyncio.create_task(self.uplink.run(), name="uplink"),
            asyncio.create_task(self._guardian_loop(), name="guardian"),
        ]
        if self.mqtt is not None:
            tasks.append(asyncio.create_task(self.mqtt.run(), name="mqtt"))
        if self.stove is not None:
            tasks.append(asyncio.create_task(self.stove.run(), name="mcz"))
        if self.mqtt is not None or self.stove is not None:
            tasks.append(asyncio.create_task(self._source_status_loop(), name="source-status"))
        try:
            await asyncio.gather(*tasks)
        finally:
            for t in tasks:
                t.cancel()
            self.uplink.stop()
            await self.rest.close()
            self.outbox.close()


def _configure_logging(level: str) -> None:
    logging.basicConfig(level=level.upper(), format="%(message)s", stream=sys.stderr)
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.getLevelName(level.upper())),
        logger_factory=structlog.PrintLoggerFactory(sys.stderr),
    )


def run() -> None:
    settings = BridgeSettings()
    _configure_logging(settings.log_level)
    if not settings.api_token:
        log.error("DCH_BRIDGE_API_TOKEN fehlt - Bridge startet nicht")
        sys.exit(2)
    try:
        entity_map, origin = load_entity_map(
            settings.entities_file, settings.entities_url, settings.entities_cache
        )
    except Exception as exc:
        log.error("Entity-Mapping nicht ladbar - Bridge startet nicht", error=str(exc)[:300])
        sys.exit(2)
    log.info("entity map loaded", origin=origin, digest=entity_map.digest())
    has_device = bool(entity_map.mqtt) or bool(settings.shelly_topic_prefix)
    if settings.source_mode != "home_assistant" and not (settings.mqtt_host and has_device):
        log.error(
            "MQTT-Modus ohne Broker oder Gerät - Rückfall auf home_assistant",
            source_mode=settings.source_mode,
            hint="shelly_device_id in den Add-on-Optionen oder ein Abschnitt mqtt: im Entity-Mapping",
        )
        settings = settings.model_copy(update={"source_mode": "home_assistant"})
    bridge = Bridge(settings, entity_map)
    with contextlib.suppress(KeyboardInterrupt):
        asyncio.run(bridge.run())


if __name__ == "__main__":
    run()
