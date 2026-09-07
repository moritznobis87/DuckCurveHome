"""Den MCZ-Pelletofen über sein Maestro-Modul direkt lesen - ohne Cloud, ohne zweiten Daemon.

**Protokoll.** Die Maestro-Platine spricht WebSocket auf Port 81. Ein Textrahmen `C|RecuperoInfo`
fordert den kompletten Zustand an, die Antwort ist eine mit `|` getrennte Liste hexadezimaler Felder,
deren erstes den Nachrichtentyp trägt (`01` = Info). Die Feldreihenfolge ist fest; welcher Index
welche Größe ist, steht in `MAESTRO_FIELDS`.

Rekonstruiert aus zwei quelloffenen Projekten, die dasselbe Protokoll sprechen:
`hackximus/MCZ-Maestro-API` (Rahmenformat der Schreibbefehle) und `Chibald/maestrogateway`
(Feldtabelle und Maßstäbe). Übernommen ist die Protokollkenntnis, kein Quelltext.

**Diese Quelle schreibt nie.** Der einzige Rahmen, den sie sendet, ist `C|RecuperoInfo`. Der Ofen
wird gelesen, nicht gesteuert. Das ist Absicht: eine Heizung, die im Winter das Haus warm hält, ist
kein Ort für Fernsteuerung nebenbei.

**Maßstäbe.** Temperaturen stehen in halben Grad, der Rohwert wird halbiert. Der Rohwert 255
(also 127,5 °C) heißt „kein Fühler angeschlossen" und wird zu `None` mit Qualität `unknown` - ein
nicht vorhandener Fühler ist etwas anderes als ein Fühler, der 127,5 °C meldet. Betriebsstunden
kommen in Sekunden und werden zu Stunden.

**Warum der WebSocket hier von Hand gesprochen wird.** Die Firmware des Ofens **maskiert ihre
Antwortrahmen**. RFC 6455 verbietet das: maskiert wird nur vom Client zum Server, nie zurück. Die
Bibliothek `websockets` hält sich strikt daran und beendet die Verbindung mit

    sent 1002 (protocol error) incorrect masking

Ein Schalter dagegen ist nicht vorgesehen, und das ist auch richtig so. Für ein Gerät, das man nicht
reparieren kann, bleibt nur ein eigener, nachsichtiger Client: er entmaskiert, was maskiert ankommt,
statt auf der Norm zu bestehen. Der Rest des Protokolls ist gewöhnlich, der Code darunter deshalb
kurz.

**Wozu.** Der Ofen ist die zweite Wärmequelle am selben Puffer. Ohne ihn ist nicht zu sagen, welcher
Anteil einer Pufferladung von der Wärmepumpe kam, und damit ist auch deren Arbeitszahl nicht
belastbar. Schneckendrehzahl (Brennstoffeintrag), Rauchgastemperatur (feuert er wirklich) und
Pumpenmodulation (lädt er gerade) schließen genau diese Lücke.
"""

from __future__ import annotations

import asyncio
import base64
import contextlib
import os
import random
from collections.abc import Awaitable, Callable, Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from urllib.parse import urlsplit

import structlog

from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

log = structlog.get_logger("mcz")

INFO_MESSAGE_TYPE = "01"
GET_INFO = "C|RecuperoInfo"
NO_PROBE_RAW = 255  # Rohwert eines nicht angeschlossenen Temperaturfühlers


@dataclass(frozen=True)
class MaestroField:
    """Ein Feld des Info-Rahmens: Position, Domänenschlüssel, Umrechnung.

    `index` zählt im gesplitteten Rahmen, Feld 0 ist der Nachrichtentyp. `kind` bestimmt die
    Umrechnung des hexadezimalen Rohwerts:

    * `int` - Zahl wie sie ist (Drehzahlen, Stufen, Zustandscodes)
    * `half` - halbe Grad, also Rohwert / 2, mit 255 als „kein Fühler"
    * `hours` - Sekunden im Rahmen, Stunden im Ergebnis
    * `flag` - wahr, wenn der Rohwert dem `truthy`-Wert entspricht
    """

    index: int
    key: str
    kind: str
    truthy: int = 1


# Nur die Felder, die im Modell etwas bewirken. Der Rahmen führt mehr (Chronostat, Uhrzeit des Ofens,
# Tonsignale); wer sie braucht, ergänzt hier eine Zeile. Alles Unbekannte bleibt bewusst ungelesen,
# statt als Zahlenrauschen in der Datenbank zu landen.
MAESTRO_FIELDS: tuple[MaestroField, ...] = (
    MaestroField(1, "stove_state", "int"),  # Zustandscode, siehe STOVE_STATE_RUNNING
    MaestroField(5, "stove_fume_temp_c", "int"),  # Rauchgas, ganze Grad
    MaestroField(6, "stove_ambient_temp_c", "half"),
    MaestroField(7, "stove_buffer_temp_c", "half"),  # eigener Pufferfühler des Ofens
    MaestroField(8, "stove_boiler_temp_c", "half"),  # Vorlauf des Ofenkreises
    MaestroField(12, "stove_fume_fan_rpm", "int"),
    MaestroField(14, "stove_auger_rpm", "int"),  # Förderschnecke: der Brennstoffeintrag
    MaestroField(15, "stove_dhw_mode", "flag"),  # Dreiwegeventil: 1 = Warmwasser, sonst Heizung
    MaestroField(16, "stove_pump_pct", "int"),  # Modulation der Ofenpumpe
    MaestroField(29, "stove_power_level", "int"),
    MaestroField(37, "stove_operating_hours", "hours"),
    MaestroField(45, "stove_ignitions", "int"),
    MaestroField(59, "stove_return_temp_c", "half"),  # Rücklauf des Ofenkreises
)

# Zustandscodes, bei denen der Ofen tatsächlich Wärme erzeugt oder auf dem Weg dorthin ist. Die
# Nummern stammen aus der Maestro-Firmware: 1-15 sind Zünden, Stabilisieren und die Leistungsstufen
# 1 bis 5, 31 ist „an", 40 bis 43 sind Ausbrand und Reinigung, in denen noch Restwärme anfällt.
STOVE_STATE_RUNNING = frozenset({*range(1, 16), 31, 40, 41, 42, 43})


def parse_info(frame: str) -> dict[str, float | None]:
    """Einen Info-Rahmen in Domänenschlüssel übersetzen.

    Rahmen anderen Typs ergeben ein leeres Ergebnis: der Ofen schickt zwischendurch auch Ping- und
    Textnachrichten, die hier nichts zu suchen haben. Fehlt ein Feld, weil die Firmware einen
    kürzeren Rahmen liefert, wird es übersprungen statt geraten.
    """
    parts = frame.split("|")
    if not parts or parts[0] != INFO_MESSAGE_TYPE:
        return {}
    out: dict[str, float | None] = {}
    for field in MAESTRO_FIELDS:
        if field.index >= len(parts):
            continue
        try:
            raw = int(parts[field.index], 16)
        except ValueError:
            continue
        out[field.key] = _convert(field, raw)
    state = out.get("stove_state")
    if state is not None:
        out["stove_running"] = 1.0 if int(state) in STOVE_STATE_RUNNING else 0.0
    return out


def _convert(field: MaestroField, raw: int) -> float | None:
    if field.kind == "half":
        return None if raw == NO_PROBE_RAW else raw / 2
    if field.kind == "hours":
        return raw / 3600
    if field.kind == "flag":
        return 1.0 if raw == field.truthy else 0.0
    return float(raw)


# --------------------------------------------------------------------- WebSocket von Hand
OPCODE_TEXT = 0x1
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA


def _client_frame(opcode: int, payload: bytes) -> bytes:
    """Einen Rahmen zum Server bauen. Maskiert, wie es die Norm für diese Richtung verlangt."""
    mask = os.urandom(4)
    n = len(payload)
    if n < 126:
        header = bytes([0x80 | opcode, 0x80 | n])
    elif n < 1 << 16:
        header = bytes([0x80 | opcode, 0x80 | 126]) + n.to_bytes(2, "big")
    else:
        header = bytes([0x80 | opcode, 0x80 | 127]) + n.to_bytes(8, "big")
    return header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload))


async def _read_frame(reader: asyncio.StreamReader) -> tuple[int, bytes]:
    """Einen Rahmen vom Server lesen - maskiert oder nicht, beides wird angenommen."""
    b0, b1 = await reader.readexactly(2)
    opcode = b0 & 0x0F
    length = b1 & 0x7F
    if length == 126:
        length = int.from_bytes(await reader.readexactly(2), "big")
    elif length == 127:
        length = int.from_bytes(await reader.readexactly(8), "big")
    mask = await reader.readexactly(4) if b1 & 0x80 else b""
    payload = await reader.readexactly(length) if length else b""
    if mask:
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return opcode, payload


async def _handshake(
    host: str, port: int, timeout_s: float
) -> tuple[asyncio.StreamReader, asyncio.StreamWriter]:
    """HTTP-Upgrade nach RFC 6455. Geprüft wird nur der Status 101.

    Bewusst nicht geprüft wird `Sec-WebSocket-Accept`: eine Firmware, die schon beim Maskieren
    schludert, soll nicht an einer Prüfsumme scheitern, die uns nichts nützt.
    """
    reader, writer = await asyncio.wait_for(asyncio.open_connection(host, port), timeout=timeout_s)
    try:
        writer.write(
            (
                "GET / HTTP/1.1\r\n"
                f"Host: {host}:{port}\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {base64.b64encode(os.urandom(16)).decode()}\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        await writer.drain()
        head = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=timeout_s)
    except BaseException:
        writer.close()
        with contextlib.suppress(Exception):
            await writer.wait_closed()
        raise
    status = head.split(b"\r\n", 1)[0].decode("latin-1", "replace")
    if " 101" not in status:
        writer.close()
        with contextlib.suppress(Exception):
            await writer.wait_closed()
        raise ConnectionError(f"kein WebSocket-Upgrade: {status}")
    return reader, writer


@dataclass
class MaestroStove:
    """Hält die WebSocket-Verbindung zum Ofen und liefert Messwerte im Bridge-Takt.

    Die Verbindung bleibt offen, alle `poll_interval_s` geht ein `C|RecuperoInfo` hinaus. Bricht sie
    ab, wird mit wachsendem Abstand neu verbunden, und einmalig gehen alle Schlüssel als
    `unavailable` hinaus. Das ist der Unterschied zwischen „der Ofen ist aus" und „wir wissen es
    nicht" - einfrieren lassen wäre die schlechtere Lüge.
    """

    url: str
    on_readings: Callable[[list[RawReading]], Awaitable[None]]
    poll_interval_s: float = 15.0
    connect_timeout_s: float = 10.0
    read_timeout_s: float = 60.0  # deutlich über dem Abfragetakt: Schweigen ist ein Ausfall
    label: str = "MCZ Maestro"

    _connected: bool = False
    _announced_offline: bool = False
    _frames: int = 0
    _reconnects: int = 0
    _logged_first_frame: bool = False

    @property
    def keys(self) -> list[str]:
        return [f.key for f in MAESTRO_FIELDS] + ["stove_running"]

    def status(self) -> dict[str, object]:
        return {
            "device": self.label,
            "connected": self._connected,
            "frames": self._frames,
            "reconnects": self._reconnects,
        }

    @property
    def address(self) -> tuple[str, int]:
        parts = urlsplit(self.url)
        return parts.hostname or "192.168.120.1", parts.port or 81

    async def run(self) -> None:
        backoff = 1.0
        while True:
            writer: asyncio.StreamWriter | None = None
            try:
                host, port = self.address
                reader, writer = await _handshake(host, port, self.connect_timeout_s)
                self._connected = True
                self._announced_offline = False
                self._logged_first_frame = False
                backoff = 1.0
                log.info("stove connected", url=self.url)
                await self._session(reader, writer)
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.warning("stove connection failed", error=f"{type(exc).__name__}: {exc}"[:200])
            finally:
                if writer is not None:
                    writer.close()
                    with contextlib.suppress(Exception):
                        await writer.wait_closed()
            self._connected = False
            self._reconnects += 1
            await self._announce_offline()
            await asyncio.sleep(backoff + random.uniform(0, 0.5))
            backoff = min(backoff * 2, 60.0)

    async def _session(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        """Solange die Verbindung steht: anfragen, lesen, weiterreichen."""
        poller = asyncio.create_task(self._poll(writer), name="mcz-poll")
        try:
            while True:
                opcode, payload = await asyncio.wait_for(
                    _read_frame(reader), timeout=self.read_timeout_s
                )
                if opcode == OPCODE_CLOSE:
                    raise ConnectionError("Ofen hat die Verbindung geschlossen")
                if opcode == OPCODE_PING:
                    writer.write(_client_frame(OPCODE_PONG, payload))
                    await writer.drain()
                    continue
                if opcode != OPCODE_TEXT:
                    continue
                values = parse_info(payload.decode("utf-8", "replace"))
                if values:
                    self._frames += 1
                    if not self._logged_first_frame:
                        # Einmal je Verbindung im Klartext: welche Größen dieses Gerät wirklich
                        # führt und welche Fühler es nicht hat. Ohne das steht im Protokoll nur
                        # eine Zahl, und ob 20 Rahmen sinnvolle Werte trugen, bliebe offen.
                        self._logged_first_frame = True
                        log.info("stove first frame", values=readable(values.items()))
                    await self._emit(values)
        finally:
            poller.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await poller

    async def _poll(self, writer: asyncio.StreamWriter) -> None:
        while True:
            writer.write(_client_frame(OPCODE_TEXT, GET_INFO.encode()))
            await writer.drain()
            await asyncio.sleep(self.poll_interval_s)

    async def _emit(self, values: dict[str, float | None]) -> None:
        now = datetime.now(UTC)
        await self.on_readings(
            [
                RawReading(
                    key=key,
                    value=value,
                    observed_at=now,
                    quality=Quality.OK if value is not None else Quality.UNKNOWN,
                    source="mcz",
                )
                for key, value in values.items()
            ]
        )

    async def _announce_offline(self) -> None:
        """Einmal je Ausfall melden, dass der Ofen nicht erreichbar ist - nicht bei jedem Versuch."""
        if self._announced_offline:
            return
        self._announced_offline = True
        now = datetime.now(UTC)
        await self.on_readings(
            [
                RawReading(
                    key=key,
                    value=None,
                    observed_at=now,
                    quality=Quality.UNAVAILABLE,
                    source="mcz",
                )
                for key in self.keys
            ]
        )


def stove_url(host: str, port: int) -> str:
    """`ws://<host>:<port>/` aus den Einstellungen, tolerant gegenüber einer bereits fertigen URL."""
    raw = host.strip()
    if raw.startswith(("ws://", "wss://")):
        return raw
    return f"ws://{raw}:{port}/"


def readable(values: Iterable[tuple[str, float | None]]) -> str:
    """Kompakte Zeile fürs Protokoll, damit ein erster Rahmen von Hand prüfbar ist."""
    return " ".join(f"{k}={'-' if v is None else round(v, 1)}" for k, v in values)


async def probe(host: str, port: int = 81, timeout_s: float = 20.0) -> int:
    """Einmal verbinden, einen Info-Rahmen holen, roh und gedeutet ausgeben.

    Gedacht für die erste Inbetriebnahme: läuft von jedem Rechner im selben Netz, braucht keine
    Konfiguration und ändert am Ofen nichts. Wer wissen will, ob die Maestro-Platine über die
    Heimnetz-Adresse antwortet, führt das hier aus, bevor er die Bridge anfasst.
    """
    print(f"verbinde mit {stove_url(host, port)}")
    writer: asyncio.StreamWriter | None = None
    try:
        reader, writer = await _handshake(host, port, timeout_s=10.0)
        writer.write(_client_frame(OPCODE_TEXT, GET_INFO.encode()))
        await writer.drain()
        async with asyncio.timeout(timeout_s):
            while True:
                opcode, payload = await _read_frame(reader)
                if opcode == OPCODE_CLOSE:
                    print("Ofen hat die Verbindung geschlossen, ohne zu antworten")
                    return 1
                if opcode != OPCODE_TEXT:
                    continue
                text = payload.decode("utf-8", "replace")
                print(f"roh:  {text}")
                values = parse_info(text)
                if not values:
                    continue
                print(f"info: {readable(values.items())}")
                missing = [k for k, v in values.items() if v is None]
                if missing:
                    print(f"ohne Fühler: {', '.join(missing)}")
                return 0
    except TimeoutError:
        print("kein Info-Rahmen innerhalb der Wartezeit")
        return 1
    except Exception as exc:  # Prüfmodus: jeder Grund soll im Klartext auf dem Schirm stehen
        print(f"fehlgeschlagen: {type(exc).__name__}: {exc}")
        return 1
    finally:
        if writer is not None:
            writer.close()
            with contextlib.suppress(Exception):
                await writer.wait_closed()


if __name__ == "__main__":  # pragma: no cover - Prüfmodus von Hand
    import sys

    argv = sys.argv[1:]
    if not argv:
        print("Aufruf: python -m dch_bridge.sources.mcz_maestro <ip-des-ofens> [port]")
        raise SystemExit(2)
    raise SystemExit(asyncio.run(probe(argv[0], int(argv[1]) if len(argv) > 1 else 81)))
