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

**Wozu.** Der Ofen ist die zweite Wärmequelle am selben Puffer. Ohne ihn ist nicht zu sagen, welcher
Anteil einer Pufferladung von der Wärmepumpe kam, und damit ist auch deren Arbeitszahl nicht
belastbar. Schneckendrehzahl (Brennstoffeintrag), Rauchgastemperatur (feuert er wirklich) und
Pumpenmodulation (lädt er gerade) schließen genau diese Lücke.
"""

from __future__ import annotations

import asyncio
import contextlib
import random
from collections.abc import Awaitable, Callable, Iterable
from dataclasses import dataclass
from datetime import UTC, datetime

import structlog
import websockets
from websockets.asyncio.client import ClientConnection

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
    label: str = "MCZ Maestro"

    _connected: bool = False
    _announced_offline: bool = False
    _frames: int = 0
    _reconnects: int = 0

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

    async def run(self) -> None:
        backoff = 1.0
        while True:
            try:
                async with websockets.connect(self.url, open_timeout=10) as ws:
                    self._connected = True
                    self._announced_offline = False
                    backoff = 1.0
                    log.info("stove connected", url=self.url)
                    await self._session(ws)
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.warning("stove connection failed", error=str(exc)[:200])
            self._connected = False
            self._reconnects += 1
            await self._announce_offline()
            await asyncio.sleep(backoff + random.uniform(0, 0.5))
            backoff = min(backoff * 2, 60.0)

    async def _session(self, ws: ClientConnection) -> None:
        """Solange die Verbindung steht: anfragen, lesen, weiterreichen."""
        poller = asyncio.create_task(self._poll(ws), name="mcz-poll")
        try:
            async for message in ws:
                text = message if isinstance(message, str) else message.decode("utf-8", "replace")
                values = parse_info(text)
                if values:
                    self._frames += 1
                    await self._emit(values)
        finally:
            poller.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await poller

    async def _poll(self, ws: ClientConnection) -> None:
        while True:
            await ws.send(GET_INFO)
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
    url = stove_url(host, port)
    print(f"verbinde mit {url}")
    try:
        async with websockets.connect(url, open_timeout=10) as ws:
            await ws.send(GET_INFO)
            async with asyncio.timeout(timeout_s):
                async for message in ws:
                    text = (
                        message if isinstance(message, str) else message.decode("utf-8", "replace")
                    )
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
        print(f"fehlgeschlagen: {exc}")
        return 1
    return 1


if __name__ == "__main__":  # pragma: no cover - Prüfmodus von Hand
    import sys

    argv = sys.argv[1:]
    if not argv:
        print("Aufruf: python -m dch_bridge.sources.mcz_maestro <ip-des-ofens> [port]")
        raise SystemExit(2)
    raise SystemExit(asyncio.run(probe(argv[0], int(argv[1]) if len(argv) > 1 else 81)))
