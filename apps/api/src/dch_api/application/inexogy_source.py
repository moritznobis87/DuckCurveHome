"""Der amtliche Zähler als mitlaufende Beobachtung.

**Was diese Quelle absichtlich nicht tut.** Sie ändert keine Zahl, die heute schon jemand liest.
Der Netzwert der Bilanz kommt weiter aus dem Stromwandler des Speichers; der Zähler schreibt auf
eigene Schlüssel (`grid_power_meter_kw` und die beiden Zählerstände). Zuerst ist zu beantworten,
wie stabil er überträgt - der vorige Zähler hatte Verbindungsabbrüche -, und erst danach, wie weit
die beiden auseinanderliegen. Beide Fragen setzen voraus, dass die Reihen getrennt bleiben.

**Warum ein eigener Nachtrag.** Die Anbindung soll Lücken selbst schließen. Fällt der Dienst aus
oder die Verbindung zum Portal, liefert `/readings` die Minuten der Zwischenzeit nach. Ohne das
wäre jede Lücke in der Verfügbarkeitskarte doppeldeutig: sie zeigte dann auch unsere eigenen
Ausfälle, und genau die sollen nicht dem Zähler angelastet werden.
"""

from __future__ import annotations

import asyncio
import contextlib
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

import structlog

from dch_api.integrations.inexogy.mapping import (
    POWER_KEY,
    identifiers,
    pick_meter,
    readings_from_history,
    readings_from_measurement,
)
from hems_core.protocol import RawReading

log = structlog.get_logger("inexogy")


def _why(exc: Exception) -> str:
    """Der Satz der Ausnahme, nicht ihre Darstellung im Quelltext.

    `repr` macht aus einer brauchbaren Meldung `RuntimeError('...')` mit doppelt maskierten
    Anführungszeichen. Diese Zeichenkette landet in der Oberfläche, wo sie jemand lesen soll.
    """
    return (str(exc) or exc.__class__.__name__)[:200]


MAX_BACKOFF_S = 300.0
# Feinste Auflösung, die für einen Nachtrag über Stunden noch sinnvoll ist. `raw` liefert beim
# Discovergy-Zähler alle zwei Sekunden und damit für einen Tag über vierzigtausend Zeilen; drei
# Minuten reichen, um eine Lücke zu füllen, deren Zweck die Verfügbarkeit und nicht die Feinstruktur
# ist. Die laufende Messung kommt ohnehin sekundengenau über `/last_reading`.
BACKFILL_RESOLUTION = "three_minutes"


class MeterClient(Protocol):
    async def meters(self) -> list[dict[str, Any]]: ...

    async def last_reading(self, meter_id: str) -> dict[str, Any]: ...

    async def readings(
        self, meter_id: str, start: datetime, end: datetime, resolution: str = ...
    ) -> list[dict[str, Any]]: ...

    async def close(self) -> None: ...


class InexogySource:
    name = "inexogy"

    def __init__(
        self,
        client: MeterClient,
        on_readings: Callable[[list[RawReading]], Awaitable[None]],
        *,
        meter: str = "",
        poll_s: float = 30.0,
        backfill_hours: int = 48,
        on_state_change: Callable[[bool, str], Awaitable[None]] | None = None,
    ) -> None:
        self.client = client
        self.on_readings = on_readings
        self.wanted_meter = meter
        self.poll_s = poll_s
        self.backfill_hours = backfill_hours
        self.on_state_change = on_state_change
        self.online = False
        self.meter_id: str = ""
        self.meter_label: str = ""
        self.last_ok: datetime | None = None
        self.last_error: str | None = None
        self.polls_ok = 0
        self.readings_seen = 0
        self.last_measurement_at: datetime | None = None
        self.backfilled_readings = 0
        self.last_backfill_at: datetime | None = None
        self.last_backfill_error: str | None = None
        self._tasks: list[asyncio.Task[None]] = []

    # ------------------------------------------------------------------ Gerät finden
    async def resolve_meter(self) -> str:
        """Den Zähler einmalig bestimmen und merken.

        Die Seriennummer steht an der Wand, in der API zählt nur der `meterId`. Deshalb nimmt die
        Auswahl beides an, und ohne Angabe gewinnt der Zähler, der zuletzt gemeldet hat.
        """
        if self.meter_id:
            return self.meter_id
        meters = await self.client.meters()
        chosen = pick_meter(meters, self.wanted_meter)
        if chosen is None:
            # Alle Kennungen, nicht nur die Seriennummer: wer diese Meldung liest, sucht den Wert,
            # den er eintragen soll, und der stand hier bisher nicht vollständig.
            names = " | ".join(sorted(", ".join(sorted(identifiers(m))) for m in meters)) or "keine"
            raise RuntimeError(f"Zähler „{self.wanted_meter}“ nicht eindeutig im Konto ({names})")
        self.meter_id = str(chosen.get("meterId", ""))
        if not self.meter_id:
            raise RuntimeError("Zähler ohne meterId in der Antwort")
        self.meter_label = str(chosen.get("serialNumber") or chosen.get("meterId"))
        log.info("inexogy meter", meter=self.meter_label, type=chosen.get("measurementType"))
        return self.meter_id

    # ------------------------------------------------------------------ Live
    async def poll_once(self, now: datetime | None = None) -> list[RawReading]:
        now = now or datetime.now(UTC)
        try:
            meter_id = await self.resolve_meter()
            measurement = await self.client.last_reading(meter_id)
            readings = readings_from_measurement(measurement, now, f"inexogy:{self.meter_label}")
        except Exception as exc:
            await self._set_online(False, _why(exc))
            raise
        self.last_ok = now
        self.polls_ok += 1
        await self._set_online(True, "")
        power = next((r for r in readings if r.key == POWER_KEY), None)
        if power is not None:
            self.last_measurement_at = power.observed_at
        if readings:
            self.readings_seen += len(readings)
            await self.on_readings(readings)
        return readings

    async def _set_online(self, online: bool, error: str) -> None:
        self.last_error = error or None
        if online != self.online:
            self.online = online
            if online:
                log.info("inexogy online", meter=self.meter_label)
            else:
                log.warning("inexogy offline", error=error)
            if self.on_state_change:
                with contextlib.suppress(Exception):
                    await self.on_state_change(online, error)

    async def _poll_loop(self) -> None:
        backoff = self.poll_s
        while True:
            try:
                await self.poll_once()
                backoff = self.poll_s
            except Exception:
                backoff = min(MAX_BACKOFF_S, backoff * 2)
            await asyncio.sleep(backoff)

    # ------------------------------------------------------------------ Nachtrag
    async def backfill(self, start: datetime, end: datetime) -> int:
        """Messwerte eines Zeitraums nachtragen. Liefert die Anzahl der Messwerte."""
        meter_id = await self.resolve_meter()
        rows = await self.client.readings(meter_id, start, end, BACKFILL_RESOLUTION)
        readings = readings_from_history(rows, end, f"inexogy:{self.meter_label}:history")
        if readings:
            await self.on_readings(readings)
        return len(readings)

    async def _backfill_loop(self) -> None:
        # Kurz warten: die laufende Abfrage soll zuerst den Zähler bestimmen, und die Gegenstelle
        # verträgt ohnehin nur eine Verbindung auf einmal.
        await asyncio.sleep(20)
        while True:
            try:
                end = datetime.now(UTC)
                n = await self.backfill(end - timedelta(hours=self.backfill_hours), end)
                self.backfilled_readings = n
                self.last_backfill_at = end
                self.last_backfill_error = None
                log.info("inexogy backfilled", readings=n)
            except Exception as exc:
                self.last_backfill_error = _why(exc)
                log.warning("inexogy backfill failed", error=self.last_backfill_error)
            await asyncio.sleep(3600)

    # ------------------------------------------------------------------ Lebenszyklus
    def start(self) -> None:
        self._tasks = [asyncio.create_task(self._poll_loop(), name="inexogy-poll")]
        if self.backfill_hours > 0:
            self._tasks.append(asyncio.create_task(self._backfill_loop(), name="inexogy-backfill"))

    async def stop(self) -> None:
        for t in self._tasks:
            t.cancel()
        for t in self._tasks:
            with contextlib.suppress(asyncio.CancelledError):
                await t
        self._tasks = []
        await self.client.close()

    def status_out(self) -> dict[str, Any]:
        """Eine Zeile für die Quellenanzeige.

        Das Alter des jüngsten Messwerts steht mit dabei und nicht nur die Zahl der Abfragen: eine
        Verbindung, die antwortet und dabei seit einer Stunde denselben Wert liefert, ist der Fall,
        den diese Anbindung gerade untersuchen soll.
        """
        parts: list[str] = []
        if self.meter_label:
            parts.append(f"Zähler {self.meter_label}")
        parts.append(
            self.last_error or (f"{self.polls_ok} Abfragen" if self.polls_ok else "wartet")
        )
        if self.last_measurement_at is not None:
            age = int((datetime.now(UTC) - self.last_measurement_at).total_seconds())
            parts.append(f"Messwert {age} s alt" if age < 3600 else f"Messwert {age // 60} min alt")
        if self.last_backfill_error:
            parts.append(f"Nachtrag fehlgeschlagen: {self.last_backfill_error}")
        elif self.last_backfill_at:
            parts.append(f"Nachtrag {self.backfilled_readings} Werte")
        return {
            "name": self.name,
            "online": self.online,
            "last_ok": self.last_ok,
            "detail_de": " · ".join(parts),
        }
