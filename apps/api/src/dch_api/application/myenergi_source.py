"""myenergi als direkte Messquelle: Live-Abfrage alle N Sekunden, Lückenfüllung aus der Minutenhistorie.

Läuft neben der Bridge. Beide liefern dieselben Domänenschlüssel; im LiveState gewinnt je Schlüssel der
jüngere Messzeitpunkt. Fällt myenergi aus, bleiben die Werte der Bridge; fällt die Bridge aus, trägt
myenergi PV, Netz, Batterie und Wallbox weiter.
"""

from __future__ import annotations

import asyncio
import contextlib
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

import structlog

from dch_api.integrations.myenergi.mapping import (
    HISTORY_KEYS,
    devices_for_history,
    history_minutes,
    readings_from_history,
    readings_from_status,
)
from hems_core.domain import Quality
from hems_core.planning import PricePoint
from hems_core.protocol import RawReading

log = structlog.get_logger("myenergi")
MAX_BACKOFF_S = 300.0


class StatusClient(Protocol):
    async def status(self) -> list[dict[str, Any]]: ...

    async def history_minutes(
        self, prefix: str, serial: int | str, start_utc: datetime, minutes: int
    ) -> list[dict[str, Any]]: ...


MinuteRows = list[dict[str, float | str | None]]


class MyenergiSource:
    name = "myenergi"

    def __init__(
        self,
        client: StatusClient,
        on_readings: Callable[[list[RawReading]], Awaitable[None]],
        *,
        poll_s: float = 30.0,
        backfill_hours: int = 48,
        minute_rows: Callable[[datetime, datetime, list[str]], Awaitable[MinuteRows]] | None = None,
        on_backfilled: Callable[[datetime, datetime], Awaitable[object]] | None = None,
        on_state_change: Callable[[bool, str], Awaitable[None]] | None = None,
    ) -> None:
        self.client = client
        self.on_readings = on_readings
        self.poll_s = poll_s
        self.backfill_hours = backfill_hours
        self.minute_rows = minute_rows
        self.on_backfilled = on_backfilled
        self.on_state_change = on_state_change
        self.online = False
        self.last_ok: datetime | None = None
        self.last_error: str | None = None
        self.polls_ok = 0
        self.backfilled_readings = 0
        self.last_backfill_at: datetime | None = None
        self.last_backfill_error: str | None = None
        self._groups: list[dict[str, Any]] = []
        self._tasks: list[asyncio.Task[None]] = []

    # ------------------------------------------------------------------ Live
    async def poll_once(self, now: datetime | None = None) -> list[RawReading]:
        now = now or datetime.now(UTC)
        try:
            self._groups = await self.client.status()
            readings = readings_from_status(self._groups, now)
        except Exception as exc:
            await self._set_online(False, repr(exc)[:200])
            raise
        self.last_ok = now
        self.polls_ok += 1
        await self._set_online(True, "")
        if readings:
            await self.on_readings(readings)
        return readings

    async def _set_online(self, online: bool, error: str) -> None:
        self.last_error = error or None
        if online != self.online:
            self.online = online
            if online:
                log.info("myenergi online")
            else:
                log.warning("myenergi offline", error=error)
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

    # ------------------------------------------------------------------ Historie
    async def backfill(self, start: datetime, end: datetime) -> int:
        """Minuten ohne eigenen Messwert aus der myenergi-Historie nachtragen. Liefert die Anzahl Messwerte."""
        if not self._groups:
            self._groups = await self.client.status()
        devices = devices_for_history(self._groups)
        if not devices:
            return 0
        start = start.astimezone(UTC).replace(minute=0, second=0, microsecond=0)
        end = end.astimezone(UTC)
        rows_by_device: dict[str, list[dict[str, Any]]] = {}
        # je Gerät und UTC-Tag höchstens 1440 Minuten – längere Fenster liefert die Cloud nicht zuverlässig
        for kind, prefix, sno in devices:
            rows: list[dict[str, Any]] = []
            day = start.replace(hour=0)
            while day < end:
                day_end = min(end, day + timedelta(days=1))
                first = max(day, start)
                minutes = int((day_end - first).total_seconds() // 60) + 1
                if minutes > 0:
                    rows.extend(
                        await self.client.history_minutes(prefix, sno, first, min(1440, minutes))
                    )
                day += timedelta(days=1)
            rows_by_device[f"{kind}:{sno}"] = rows
        # Schlüssel „zappi:123“ → Art fürs Zusammenführen
        merged = history_minutes({k.split(":")[0]: v for k, v in rows_by_device.items()})
        merged = [h for h in merged if start <= h.ts < end]
        missing: set[tuple[datetime, str]] | None = None
        if self.minute_rows is not None:
            existing = await self.minute_rows(start, end, list(HISTORY_KEYS.values()))
            have: set[tuple[datetime, str]] = set()
            for row in existing:
                ts_raw = row.get("ts")
                if not isinstance(ts_raw, str):
                    continue
                ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).astimezone(UTC)
                for key in HISTORY_KEYS.values():
                    if isinstance(row.get(key), int | float):
                        have.add((ts, key))
            missing = {
                (h.ts, key)
                for h in merged
                for key in HISTORY_KEYS.values()
                if (h.ts, key) not in have
            }
        readings = readings_from_history(merged, missing)
        if readings:
            for i in range(0, len(readings), 2000):
                await self.on_readings(readings[i : i + 2000])
            self.backfilled_readings += len(readings)
        if self.on_backfilled and merged:
            await self.on_backfilled(
                start, end
            )  # auch ohne neue Werte: Preise ergänzen, Stunden neu rechnen
        self.last_backfill_at = datetime.now(UTC)
        self.last_backfill_error = None
        log.info("myenergi backfill", minutes=len(merged), readings=len(readings))
        return len(readings)

    async def _backfill_loop(self) -> None:
        first = True
        while True:
            now = datetime.now(UTC)
            hours = self.backfill_hours if first else 3
            try:
                await self.backfill(now - timedelta(hours=hours), now - timedelta(minutes=2))
                first = False
                await asyncio.sleep(3600)
            except Exception as exc:
                self.last_backfill_error = repr(exc)[:200]
                log.warning("myenergi backfill failed", error=self.last_backfill_error)
                if self.on_state_change:
                    with contextlib.suppress(Exception):
                        await self.on_state_change(
                            self.online, f"Historie: {self.last_backfill_error}"
                        )
                await asyncio.sleep(600)  # in 10 min erneut, Startfenster bleibt

    # ------------------------------------------------------------------ Lebenszyklus
    def start(self) -> None:
        self._tasks = [asyncio.create_task(self._poll_loop(), name="myenergi-poll")]
        if self.backfill_hours > 0:
            self._tasks.append(asyncio.create_task(self._backfill_loop(), name="myenergi-backfill"))

    async def stop(self) -> None:
        for t in self._tasks:
            t.cancel()
        for t in self._tasks:
            with contextlib.suppress(asyncio.CancelledError):
                await t
        self._tasks = []

    def status_out(self) -> dict[str, Any]:
        live = self.last_error or (f"{self.polls_ok} Abfragen" if self.polls_ok else "wartet")
        if self.last_backfill_error:
            hist = f"Historie fehlgeschlagen: {self.last_backfill_error}"
        elif self.last_backfill_at:
            hist = (
                f"Historie {self.backfilled_readings} Werte, "
                f"zuletzt {self.last_backfill_at.strftime('%H:%M')} UTC"
            )
        else:
            hist = "Historie ausstehend"
        return {
            "name": self.name,
            "online": self.online,
            "last_ok": self.last_ok,
            "detail_de": f"{live} · {hist}",
        }


def price_readings_for_gaps(
    prices: list[PricePoint], existing: MinuteRows, start: datetime, end: datetime
) -> list[RawReading]:
    """Strompreis je Minute (Tibber-Historie) für Minuten ohne gespeicherten Preis, damit nachgetragene
    Leistungen nicht mit dem Ersatzpreis bewertet werden."""
    have: set[datetime] = set()
    for row in existing:
        ts_raw = row.get("ts")
        if isinstance(ts_raw, str) and isinstance(row.get("electricity_price_ct_kwh"), int | float):
            have.add(datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).astimezone(UTC))
    start = start.astimezone(UTC).replace(second=0, microsecond=0)
    end = end.astimezone(UTC)
    out: list[RawReading] = []
    for p in prices:
        m = max(start, p.start.astimezone(UTC).replace(second=0, microsecond=0))
        stop = min(end, p.end.astimezone(UTC))
        while m < stop:
            if m not in have:
                out.append(
                    RawReading(
                        key="electricity_price_ct_kwh",
                        value=round(p.ct_kwh, 3),
                        observed_at=m.replace(second=30),
                        quality=Quality.OK,
                        source="tibber:history",
                    )
                )
            m += timedelta(minutes=1)
    return out
