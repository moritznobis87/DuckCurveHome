"""Energiebilanz für die Detailseiten: Stundenwerte pflegen (Live: Tabelle energy_hourly) und Zeiträume
(Tag/Woche/Monat/Jahr) mit Quellen, Verbrauchern, Kosten, Wärme- und Wallbox-Auswertung zusammenfassen."""

from __future__ import annotations

import calendar
from collections.abc import Awaitable, Callable, Iterable
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import structlog

from dch_api.schemas import (
    EnergyBucketOut,
    EnergyMetaOut,
    EnergySummaryOut,
    EnergyTotalsOut,
    EvReportOut,
    EvSessionOut,
    HeatReportOut,
    Period,
)
from hems_core.accounting import (
    HourlyEnergy,
    cop_at,
    heat_forecast,
    hourly_energy,
    samples_from_rows,
    summarize,
)
from hems_core.domain import HemsConfig

log = structlog.get_logger("energy")

MinuteRow = dict[str, float | str | None]
MinuteRows = Callable[[datetime, datetime], Awaitable[list[MinuteRow]]]
HourStore = tuple[
    Callable[[datetime, datetime], Awaitable[list[tuple[HourlyEnergy, float | None]]]],
    Callable[[list[HourlyEnergy], dict[datetime, float | None]], Awaitable[None]],
    Callable[[], Awaitable[datetime | None]],
]

ENERGY_KEYS = [
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
]
WEEKDAYS_DE = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
MONTHS_DE = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
BACKFILL_DAYS = 14  # entspricht der Aufbewahrung der Rohwerte


def _mean(values: Iterable[float | None]) -> float | None:
    xs = [v for v in values if v is not None]
    return round(sum(xs) / len(xs), 2) if xs else None


class EnergyAccounting:
    def __init__(
        self,
        hems: HemsConfig,
        tz: ZoneInfo,
        minute_rows: MinuteRows,
        store: HourStore | None = None,
        data_since: Callable[[], Awaitable[datetime | None]] | None = None,
    ) -> None:
        self.hems = hems
        self.tz = tz
        self.minute_rows = minute_rows
        self.store = store
        self.data_since = data_since
        self._last_refresh_hour: datetime | None = None

    # ------------------------------------------------------------------ Zeiträume
    def period_bounds(self, period: Period, anchor: date) -> tuple[datetime, datetime]:
        if period == "day":
            s = datetime.combine(anchor, time(0), tzinfo=self.tz)
            e = s + timedelta(days=1)
        elif period == "week":
            monday = anchor - timedelta(days=anchor.weekday())
            s = datetime.combine(monday, time(0), tzinfo=self.tz)
            e = s + timedelta(days=7)
        elif period == "month":
            s = datetime.combine(anchor.replace(day=1), time(0), tzinfo=self.tz)
            nxt = (anchor.replace(day=28) + timedelta(days=4)).replace(day=1)
            e = datetime.combine(nxt, time(0), tzinfo=self.tz)
        else:
            s = datetime.combine(date(anchor.year, 1, 1), time(0), tzinfo=self.tz)
            e = datetime.combine(date(anchor.year + 1, 1, 1), time(0), tzinfo=self.tz)
        return s.astimezone(UTC), e.astimezone(UTC)

    def bucket_starts(
        self, period: Period, start: datetime, end: datetime
    ) -> list[tuple[datetime, datetime, str]]:
        out: list[tuple[datetime, datetime, str]] = []
        loc = start.astimezone(self.tz)
        end_loc = end.astimezone(self.tz)
        if period == "day":
            t = loc
            while t < end_loc:
                n = t + timedelta(hours=1)
                out.append((t.astimezone(UTC), n.astimezone(UTC), t.strftime("%H:00")))
                t = n
        elif period in ("week", "month"):
            t = loc
            while t < end_loc:
                n = datetime.combine(t.date() + timedelta(days=1), time(0), tzinfo=self.tz)
                label = (
                    f"{WEEKDAYS_DE[t.weekday()]} {t.day:02d}.{t.month:02d}."
                    if period == "week"
                    else f"{t.day:02d}."
                )
                out.append((t.astimezone(UTC), n.astimezone(UTC), label))
                t = n
        else:
            for month in range(1, 13):
                t = datetime(loc.year, month, 1, tzinfo=self.tz)
                last = calendar.monthrange(loc.year, month)[1]
                n = datetime(loc.year, month, last, tzinfo=self.tz) + timedelta(days=1)
                out.append((t.astimezone(UTC), n.astimezone(UTC), MONTHS_DE[month - 1]))
        return out

    # ------------------------------------------------------------------ Stunden
    async def _compute_hours(
        self, start: datetime, end: datetime
    ) -> list[tuple[HourlyEnergy, float | None]]:
        """Stunden direkt aus Minutenzeilen berechnen (Demo, oder Live für noch nicht gespeicherte Stunden)."""
        rows = await self.minute_rows(start, end)
        by_hour: dict[datetime, list[MinuteRow]] = {}
        for r in rows:
            ts_raw = r.get("ts")
            if not isinstance(ts_raw, str):
                continue
            ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).astimezone(UTC)
            by_hour.setdefault(ts.replace(minute=0, second=0, microsecond=0), []).append(r)
        out: list[tuple[HourlyEnergy, float | None]] = []
        for hour_start in sorted(by_hour):
            hrows = by_hour[hour_start]
            h = hourly_energy(hour_start, samples_from_rows(hrows), self.hems.tariff)
            temps = [r.get("outdoor_temp_c") for r in hrows]
            out.append((h, _mean(v if isinstance(v, int | float) else None for v in temps)))
        return out

    async def refresh(self, now: datetime) -> int:
        """Live: fehlende und die laufende Stunde neu berechnen und speichern. Liefert die Anzahl Stunden."""
        if self.store is None:
            return 0
        _read, write, last = self.store
        current = now.astimezone(UTC).replace(minute=0, second=0, microsecond=0)
        if self._last_refresh_hour is None:
            stored = await last()
            begin = (
                (stored - timedelta(hours=1)) if stored else current - timedelta(days=BACKFILL_DAYS)
            )
        else:
            begin = self._last_refresh_hour - timedelta(hours=1)
        begin = max(begin, current - timedelta(days=BACKFILL_DAYS))
        hours = await self._compute_hours(begin, current + timedelta(hours=1))
        if hours:
            await write([h for h, _ in hours], {h.hour_start: t for h, t in hours})
        self._last_refresh_hour = current
        return len(hours)

    async def recompute(self, start: datetime, end: datetime) -> int:
        """Stunden eines Zeitraums neu berechnen (nach nachgetragenen Messwerten)."""
        if self.store is None:
            return 0
        _read, write, _last = self.store
        begin = start.astimezone(UTC).replace(minute=0, second=0, microsecond=0)
        stop = end.astimezone(UTC).replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        hours = await self._compute_hours(begin, stop)
        if hours:
            await write([h for h, _ in hours], {h.hour_start: t for h, t in hours})
        return len(hours)

    async def hours(
        self, start: datetime, end: datetime
    ) -> list[tuple[HourlyEnergy, float | None]]:
        if self.store is None:
            return await self._compute_hours(start, end)
        read, _write, _last = self.store
        return await read(start, end)

    # ------------------------------------------------------------------ Zusammenfassungen
    async def summary(self, period: Period, anchor: date, now: datetime) -> EnergySummaryOut:
        start, end = self.period_bounds(period, anchor)
        hours = await self.hours(start, end)
        totals = summarize(h for h, _ in hours)
        buckets: list[EnergyBucketOut] = []
        for b_start, b_end, label in self.bucket_starts(period, start, end):
            part = summarize(h for h, _ in hours if b_start <= h.hour_start < b_end)
            buckets.append(
                EnergyBucketOut(
                    start=b_start, end=b_end, label=label, totals=EnergyTotalsOut.from_totals(part)
                )
            )
        elapsed_min = max(0.0, (min(now, end) - start).total_seconds() / 60.0)
        coverage = round(min(1.0, totals.minutes / elapsed_min), 3) if elapsed_min > 0 else None
        since = await self.data_since() if self.data_since else None
        return EnergySummaryOut(
            period=period,
            anchor=anchor,
            start=start,
            end=end,
            totals=EnergyTotalsOut.from_totals(totals),
            buckets=buckets,
            meta=EnergyMetaOut(
                battery_capacity_kwh=self.hems.battery.capacity_kwh,
                feed_in_ct_kwh=self.hems.tariff.feed_in_ct_kwh,
                data_since=since,
                coverage=coverage,
                estimated_note_de=(
                    "Quellen-Zuordnung je Minute: PV deckt zuerst den Hausverbrauch, dann die Batterie; "
                    "Verbraucher erhalten die Quellen anteilig. Geld: Netzbezug × Tibber-Preis, PV- und "
                    f"Batterieanteile mit {self.hems.tariff.feed_in_ct_kwh:g} ct Einspeisevergütung bewertet."
                ),
            ),
        )

    async def heat_report(
        self,
        period: Period,
        anchor: date,
        now: datetime,
        temps_48h: list[tuple[datetime, float]],
    ) -> HeatReportOut:
        summary = await self.summary(period, anchor, now)
        start, end = self.period_bounds(period, anchor)
        hours = await self.hours(start, end)
        cfg = self.hems.heat_demand
        thermal = 0.0
        for h, t_out in hours:
            thermal += h.heat_pump_kwh * cop_at(t_out if t_out is not None else 7.0, cfg)
        electric = summary.totals.heat_pump_kwh
        cop_est = round(thermal / electric, 2) if electric > 1e-6 else 0.0
        off = now.astimezone(self.tz).utcoffset()
        offset_h = int(off.total_seconds() // 3600) if off is not None else 0
        fc = heat_forecast(temps_48h, cfg, tz_offset_h=offset_h)
        first24 = fc[:24]
        day_start, day_end = self.period_bounds("day", anchor)
        rows = await self.minute_rows(day_start, min(day_end, now + timedelta(minutes=1)))
        buffer_series = [
            {
                k: r.get(k)
                for k in (
                    "ts",
                    "buffer_temp_top_c",
                    "buffer_temp_mid_top_c",
                    "buffer_temp_mid_bottom_c",
                    "buffer_temp_bottom_c",
                    "heat_pump_power_kw",
                    "outdoor_temp_c",
                )
            }
            for i, r in enumerate(rows)
            if i % 5 == 0
        ]
        return HeatReportOut(
            summary=summary,
            thermal_kwh_est=round(thermal, 2),
            cop_est=cop_est,
            forecast=fc,
            forecast_electric_kwh_24h=round(sum(p.electric_kw for p in first24), 2),
            forecast_thermal_kwh_24h=round(sum(p.heating_kw + p.dhw_kw for p in first24), 2),
            buffer_series=buffer_series,
            heat_loss_kw_per_k=cfg.heat_loss_kw_per_k,
            model_note_de=(
                "Wärme ohne Wärmemengenzähler geschätzt: Strom × COP-Kennlinie über der Außentemperatur. "
                f"Bedarfsprognose aus Heizgradstunden (H = {cfg.heat_loss_kw_per_k:g} kW/K, Heizgrenze "
                f"{cfg.heating_limit_c:g} °C) plus Warmwasserprofil ({cfg.dhw_kwh_per_day:g} kWh/Tag)."
            ),
        )

    async def ev_report(self, period: Period, anchor: date, now: datetime) -> EvReportOut:
        summary = await self.summary(period, anchor, now)
        sessions: list[EvSessionOut] = []
        if period in ("day", "week"):
            start, end = self.period_bounds(period, anchor)
            rows = await self.minute_rows(start, min(end, now + timedelta(minutes=1)))
            sessions = self._sessions(rows)
        return EvReportOut(summary=summary, sessions=sessions)

    def _sessions(
        self, rows: list[MinuteRow], min_kw: float = 0.3, gap_min: int = 5
    ) -> list[EvSessionOut]:
        feed_in = self.hems.tariff.feed_in_ct_kwh
        fallback = self.hems.tariff.fallback_import_ct_kwh
        out: list[EvSessionOut] = []
        cur: dict[str, float] | None = None
        cur_start: datetime | None = None
        cur_end: datetime | None = None
        idle = 0

        def close() -> None:
            nonlocal cur, cur_start, cur_end, idle
            if cur and cur_start and cur_end and cur["kwh"] >= 0.2:
                minutes = max(1.0, (cur_end - cur_start).total_seconds() / 60.0 + 1)
                out.append(
                    EvSessionOut(
                        start=cur_start,
                        end=cur_end + timedelta(minutes=1),
                        kwh=round(cur["kwh"], 2),
                        pv_share=round(cur["pv"] / cur["kwh"], 3) if cur["kwh"] > 0 else None,
                        grid_kwh=round(cur["grid"], 2),
                        cost_eur=round(cur["cost"], 2),
                        avg_kw=round(cur["kwh"] / (minutes / 60.0), 2),
                    )
                )
            cur = None
            cur_start = None
            cur_end = None
            idle = 0

        for r in rows:
            ts_raw = r.get("ts")
            ev = r.get("ev_power_kw")
            if not isinstance(ts_raw, str) or not isinstance(ev, int | float):
                continue
            ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
            if ev >= min_kw:
                pv = r.get("pv_power_kw")
                grid = r.get("grid_power_kw")
                bat = r.get("battery_power_kw")
                price = r.get("electricity_price_ct_kwh")
                pv_v = float(pv) if isinstance(pv, int | float) else 0.0
                grid_v = float(grid) if isinstance(grid, int | float) else 0.0
                bat_v = float(bat) if isinstance(bat, int | float) else 0.0
                price_v = float(price) if isinstance(price, int | float) else fallback
                house = max(1e-6, pv_v + grid_v + bat_v)
                pv_direct = min(max(0.0, pv_v), house)
                grid_to_house = max(
                    0.0, house - pv_direct - min(max(0.0, bat_v), max(0.0, house - pv_direct))
                )
                frac = min(1.0, ev / house)
                if cur is None:
                    cur = {"kwh": 0.0, "pv": 0.0, "grid": 0.0, "cost": 0.0}
                    cur_start = ts
                cur["kwh"] += ev / 60.0
                cur["pv"] += frac * pv_direct / 60.0
                g = frac * grid_to_house / 60.0
                cur["grid"] += g
                cur["cost"] += g * price_v / 100.0 + frac * pv_direct / 60.0 * feed_in / 100.0 * 0.0
                cur_end = ts
                idle = 0
            elif cur is not None:
                idle += 1
                if idle > gap_min:
                    close()
        close()
        return out
