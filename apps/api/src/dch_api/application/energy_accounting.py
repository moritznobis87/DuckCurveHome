"""Energiebilanz für die Detailseiten: Stundenwerte pflegen (Live: Tabelle energy_hourly) und Zeiträume
(Tag/Woche/Monat/Jahr) mit Quellen, Verbrauchern, Kosten, Wärme- und Wallbox-Auswertung zusammenfassen."""

from __future__ import annotations

import calendar
from collections.abc import Awaitable, Callable, Iterable
from datetime import UTC, date, datetime, time, timedelta
from itertools import pairwise
from zoneinfo import ZoneInfo

import structlog

from dch_api.schemas import (
    BufferBalanceOut,
    EnergyBucketOut,
    EnergyMetaOut,
    EnergySummaryOut,
    EnergyTotalsOut,
    EvReportOut,
    EvSessionOut,
    HeatReportOut,
    Period,
    PriceQualityOut,
    PvTaxBucketOut,
    PvTaxMetaOut,
    PvTaxReportOut,
    StoveOut,
    YearMapOut,
)
from hems_core.accounting import (
    BatteryOrigin,
    HourlyEnergy,
    cop_at,
    heat_forecast,
    hourly_energy,
    pv_tax,
    samples_from_rows,
    summarize,
)
from hems_core.domain import BufferConfig, HemsConfig
from hems_core.thermal import (
    CyclingStats,
    StoveSample,
    compressor_runs,
    cycling_stats,
    fuel_note,
    stove_stats,
    usable_energy_kwh,
)

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
# Kennzahlen der Jahreskarte. Energien werden über zusammenfallende Stunden addiert, Preise und
# Quoten gemittelt - bei der Zeitumstellung im Herbst fällt eine Ortsstunde doppelt an.
ENERGY_METRICS = (
    "pv_kwh",
    "house_kwh",
    "import_kwh",
    "export_kwh",
    "grid_net_kwh",
    "heat_pump_kwh",
)
MEAN_METRICS = ("price_ct_kwh", "autarky")
WEEKDAYS_DE = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
MONTHS_DE = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
# Fenster, das der laufende Betrieb nachrechnet. Nicht mehr durch die Datenhaltung begrenzt: die
# Minutenwerte bleiben dauerhaft, `recompute` kann daher jeden beliebigen Zeitraum neu bilanzieren.
BACKFILL_DAYS = 14

# Verbraucherfelder, die eine Neuberechnung verlieren kann: kennt eine Quelle den Zähler nicht (die
# myenergi-Cloud weiß nichts von der Wärmepumpe), ergibt die Rechnung 0 kWh statt „unbekannt“.
CARRY_GROUPS: dict[str, tuple[str, ...]] = {
    "heat_pump_kwh": (
        "heat_pump_kwh",
        "heat_pump_pv_kwh",
        "heat_pump_battery_kwh",
        "heat_pump_grid_kwh",
        "heat_pump_cost_eur",
        "heat_pump_opportunity_eur",
    ),
    "ev_kwh": (
        "ev_kwh",
        "ev_pv_kwh",
        "ev_battery_kwh",
        "ev_grid_kwh",
        "ev_cost_eur",
        "ev_opportunity_eur",
    ),
}


def merge_hour(new: HourlyEnergy, old: HourlyEnergy | None) -> HourlyEnergy:
    """Neu berechnete Stunde mit der gespeicherten zusammenführen.

    Weist die neue Rechnung einen Verbraucher mit genau 0 kWh aus, während die gespeicherte Stunde einen
    Verbrauch kennt, war er in den Minutenwerten nicht enthalten (z. B. die Wärmepumpe nach einem
    myenergi-Backfill). Sein Wert samt Herkunft und Kosten wird übernommen, der Rest (base_kwh) entsprechend
    verkleinert. Die Bilanz der Quellen bleibt die der neuen, vollständigeren Messung."""
    if old is None:
        return new
    patch: dict[str, float] = {}
    for lead, fields in CARRY_GROUPS.items():
        if getattr(new, lead) == 0.0 and getattr(old, lead) > 0.0:
            patch.update({f: getattr(old, f) for f in fields})
    if not patch:
        return new
    hp = patch.get("heat_pump_kwh", new.heat_pump_kwh)
    ev = patch.get("ev_kwh", new.ev_kwh)
    patch["base_kwh"] = round(max(0.0, new.house_kwh - hp - ev), 4)
    return new.model_copy(update=patch)


def _mean(values: Iterable[float | None]) -> float | None:
    xs = [v for v in values if v is not None]
    return round(sum(xs) / len(xs), 2) if xs else None


def _price_quality(
    hours: list[tuple[HourlyEnergy, float | None]], totals: EnergyTotalsOut
) -> PriceQualityOut:
    """Hat die Wärmepumpe zur richtigen Zeit gelaufen?

    Gemessen wird das Ergebnis, nicht die Regeltreue: was der Wärmepumpenstrom aus dem Netz
    tatsächlich gekostet hat, gegen den Mittelpreis des Hausbezugs im selben Zeitraum. Die Zahlen
    stehen bereits in der Stundenbilanz - `heat_pump_cost_eur` ist Netzanteil × Preis der Stunde.

    Ein Vergleich gegen den *geplanten* Fahrplan wäre die naheliegende Alternative, ist aber nicht
    möglich: Pläne werden bisher nicht gespeichert. Das Ergebnis ist ohnehin die ehrlichere Frage -
    ein Plan, der perfekt eingehalten wird und trotzdem teuer ist, hilft niemandem.
    """
    hp_grid = sum(h.heat_pump_grid_kwh for h, _ in hours)
    hp_cost = sum(h.heat_pump_cost_eur for h, _ in hours)
    hp_price = round(hp_cost * 100.0 / hp_grid, 2) if hp_grid > 1e-6 else None
    house_price = totals.avg_import_price_ct

    # Anteil der WP-Energie in den günstigsten 25 % der Stunden. Gerankt wird nur, was einen Preis
    # hat; Stunden ohne Bezug haben keinen gewichteten Mittelpreis.
    priced = [(h.avg_import_price_ct, h.heat_pump_kwh) for h, _ in hours if h.avg_import_price_ct]
    cheap_share: float | None = None
    if len(priced) >= 8:
        priced.sort(key=lambda x: x[0] or 0.0)
        cut = max(1, len(priced) // 4)
        cheap = sum(kwh for _, kwh in priced[:cut])
        total = sum(kwh for _, kwh in priced)
        cheap_share = round(cheap / total, 3) if total > 1e-6 else None

    hp_total = totals.heat_pump_kwh
    pv_share = (
        round((totals.heat_pump_pv_kwh + totals.heat_pump_battery_kwh) / hp_total, 3)
        if hp_total > 1e-6
        else None
    )
    advantage = (
        round(house_price - hp_price, 2)
        if hp_price is not None and house_price is not None
        else None
    )
    if advantage is None:
        note = "Zu wenig Netzbezug der Wärmepumpe für einen Preisvergleich."
    elif advantage > 0.5:
        note = (
            f"Der Wärmepumpenstrom war {advantage:.2f} ct/kWh günstiger als der Hausdurchschnitt."
        )
    elif advantage < -0.5:
        note = (
            f"Der Wärmepumpenstrom war {-advantage:.2f} ct/kWh teurer als der Hausdurchschnitt -"
            " sie lief überwiegend in den teuren Stunden."
        )
    else:
        note = "Der Wärmepumpenstrom kostete etwa so viel wie der Hausdurchschnitt."
    return PriceQualityOut(
        hp_grid_price_ct=hp_price,
        house_grid_price_ct=house_price,
        advantage_ct=advantage,
        cheap_share=cheap_share,
        pv_share=pv_share,
        hours_ranked=len(priced),
        note_de=note,
    )


_BUFFER_KEYS = (
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
)


def _num(v: object) -> bool:
    """Liegt für diese Minute überhaupt ein Messwert vor? `None` heißt Lücke, nicht Null."""
    return isinstance(v, int | float) and not isinstance(v, bool)


def _val(v: object) -> float | None:
    return float(v) if _num(v) else None  # type: ignore[arg-type]


def _buffer_balance(series: list[MinuteRow], cfg: BufferConfig) -> BufferBalanceOut:
    """Energieinhalt des Puffers über den Tag und wer ihn gefüllt hat.

    Zunahmen, während die Wärmepumpe steht, sind Fremdwärme - beim Kombipuffer der Pelletofen.
    Die Rechnung ist eine Untergrenze: läuft gleichzeitig die Heizung, wird ein Teil der zugeführten
    Wärme sofort wieder entnommen und taucht hier nie auf.
    """
    points: list[tuple[float, bool, bool | None]] = []
    for row in series:
        temps = [row.get(k) for k in _BUFFER_KEYS]
        if any(not isinstance(t, int | float) for t in temps):
            continue
        hp = row.get("heat_pump_power_kw")
        running = isinstance(hp, int | float) and hp > 0.3
        sr = row.get("stove_running")
        stove = bool(sr) if isinstance(sr, int | float) else None
        points.append((usable_energy_kwh([float(t) for t in temps], cfg), running, stove))  # type: ignore[arg-type]
    if len(points) < 2:
        return BufferBalanceOut(
            note_de="Zu wenige vollständige Puffermesswerte am Ankertag für eine Bilanz."
        )
    gain = drop = with_hp = without_hp = with_stove = unexplained = 0.0
    stove_known = False
    for (e0, _, _), (e1, running, stove) in pairwise(points):
        d = e1 - e0
        if d < 0:
            drop -= d
            continue
        gain += d
        if stove is not None:
            stove_known = True
        if running:
            with_hp += d
            continue
        without_hp += d
        if stove:
            with_stove += d
        elif stove is False:
            unexplained += d
    return BufferBalanceOut(
        energy_start_kwh=round(points[0][0], 2),
        energy_end_kwh=round(points[-1][0], 2),
        gain_kwh=round(gain, 2),
        drop_kwh=round(drop, 2),
        gain_with_hp_kwh=round(with_hp, 2),
        gain_without_hp_kwh=round(without_hp, 2),
        gain_with_stove_kwh=round(with_stove, 2),
        gain_unexplained_kwh=round(unexplained, 2),
        stove_known=stove_known,
        samples=len(points),
        note_de=_balance_note(without_hp, with_stove, unexplained, stove_known),
    )


def _balance_note(without_hp: float, stove: float, unexplained: float, known: bool) -> str:
    """Den Befund in Worte fassen, ohne mehr zu behaupten, als die Daten hergeben."""
    if without_hp <= 0.2:
        return "Keine nennenswerte Wärmezufuhr ohne laufende Wärmepumpe."
    if not known:
        return (
            f"{without_hp:.1f} kWh kamen in den Puffer, während die Wärmepumpe stand. Ohne Ofendaten "
            "bleibt die Quelle eine Vermutung. Untergrenze: gleichzeitige Entnahme fehlt darin."
        )
    if stove > 0.2 and unexplained <= 0.2:
        return (
            f"{stove:.1f} kWh kamen vom Pelletofen, gemessen und nicht geschlossen. "
            "Untergrenze: gleichzeitige Entnahme ist darin nicht enthalten."
        )
    if stove > 0.2:
        return (
            f"{stove:.1f} kWh vom Pelletofen, {unexplained:.1f} kWh ohne erkennbare Quelle. "
            "Letzteres deutet auf Umschichtung im Speicher oder auf einen Fühler, der nachläuft."
        )
    return (
        f"{unexplained:.1f} kWh kamen in den Puffer, ohne dass Wärmepumpe oder Ofen liefen. Das ist "
        "kein Fremdwärme-Befund, sondern ein Hinweis auf Umschichtung oder Messfehler."
    )


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
        order = sorted(by_hour)
        # Das Herkunftskonto des Speichers läuft über die Stunden weiter; ohne den Anschluss an die
        # vorige Stunde begänne jede Neuberechnung mit leerem Konto und hielte die erste Entladung
        # danach für PV. Fehlt die Vorstunde, bleibt es leer - dann wird die Schätzung ausgewiesen.
        origin = await self._origin_before(order[0]) if order else BatteryOrigin()
        capacity = self.hems.battery.capacity_kwh
        for hour_start in order:
            hrows = by_hour[hour_start]
            h = hourly_energy(
                hour_start, samples_from_rows(hrows), self.hems.tariff, origin, capacity
            )
            temps = [r.get("outdoor_temp_c") for r in hrows]
            out.append((h, _mean(v if isinstance(v, int | float) else None for v in temps)))
        return out

    async def _origin_before(self, start: datetime) -> BatteryOrigin:
        """Stand des Speicher-Herkunftskontos aus der letzten gespeicherten Stunde vor `start`."""
        if self.store is None:
            return BatteryOrigin()
        read, _write, _last = self.store
        prev = await read(start - timedelta(hours=6), start)
        if not prev:
            return BatteryOrigin()
        h = prev[-1][0]
        return BatteryOrigin(pv_kwh=h.battery_pv_stored_kwh, grid_kwh=h.battery_grid_stored_kwh)

    async def refresh(self, now: datetime) -> int:
        """Live: fehlende und die laufende Stunde neu berechnen und speichern. Liefert die Anzahl Stunden."""
        if self.store is None:
            return 0
        read, write, last = self.store
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
            merged = await self._merge_with_stored(read, hours, begin, current + timedelta(hours=1))
            await write([h for h, _ in merged], {h.hour_start: t for h, t in merged})
        self._last_refresh_hour = current
        return len(hours)

    async def _merge_with_stored(
        self,
        read: Callable[[datetime, datetime], Awaitable[list[tuple[HourlyEnergy, float | None]]]],
        hours: list[tuple[HourlyEnergy, float | None]],
        begin: datetime,
        stop: datetime,
    ) -> list[tuple[HourlyEnergy, float | None]]:
        """Neu berechnete Stunden gegen den Bestand abgleichen: nichts verlieren, nichts verschlechtern."""
        stored = {h.hour_start: (h, t) for h, t in await read(begin, stop)}
        out: list[tuple[HourlyEnergy, float | None]] = []
        for h, temp in hours:
            old, old_temp = stored.get(h.hour_start, (None, None))
            if old is not None and h.minutes < old.minutes:
                continue  # Teildaten ersetzen keine vollständigere Stunde
            out.append((merge_hour(h, old), temp if temp is not None else old_temp))
        return out

    async def recompute(self, start: datetime, end: datetime) -> int:
        """Stunden eines Zeitraums aus Minutenwerten neu berechnen (nach nachgetragenen Messwerten).

        Eine gespeicherte Stunde mit mehr bewerteten Minuten (z. B. aus einem Historienimport) bleibt stehen -
        Teildaten aus der Cloud dürfen eine vollständige Stunde nicht ersetzen.

        Gerechnet wird tageweise. Ein Backfill darf 62 Tage umfassen; die auf einmal zu laden wären
        rund 90 000 Minutenzeilen im Speicher, und das Herkunftskonto des Speichers läuft ohnehin
        chronologisch weiter, sodass die Zerlegung nichts kostet."""
        if self.store is None:
            return 0
        read, write, _last = self.store
        begin = start.astimezone(UTC).replace(minute=0, second=0, microsecond=0)
        stop = end.astimezone(UTC).replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        total = 0
        cursor = begin
        while cursor < stop:
            chunk_end = min(cursor + timedelta(days=1), stop)
            hours = await self._compute_hours(cursor, chunk_end)
            if hours:
                keep = await self._merge_with_stored(read, hours, cursor, chunk_end)
                if keep:
                    await write([h for h, _ in keep], {h.hour_start: t for h, t in keep})
                    total += len(keep)
            cursor = chunk_end
        return total

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

    async def year_map(self, year: int, now: datetime) -> YearMapOut:
        """Ein Kalenderjahr als Fläche Tag × Stunde.

        Gruppiert wird nach **Ortszeit**: die Stundenzeilen sollen die Sonne zeigen, nicht die
        Zeitzone. Die Umstellung im Frühjahr lässt eine Stunde leer, die im Herbst legt zwei
        UTC-Stunden auf dieselbe Ortsstunde - Energien werden dort addiert, Preise und Quoten
        gemittelt, was beides der Wirklichkeit entspricht.

        Fehlende Stunden bleiben `None`. Sie als 0 auszuweisen wäre die bequeme Lüge: eine Lücke in
        der Aufzeichnung sähe dann aus wie eine Nacht ohne Verbrauch.
        """
        start = datetime.combine(date(year, 1, 1), time(0), tzinfo=self.tz).astimezone(UTC)
        end = datetime.combine(date(year + 1, 1, 1), time(0), tzinfo=self.tz).astimezone(UTC)
        days = [date(year, 1, 1) + timedelta(days=i) for i in range((end - start).days + 2)]
        days = [d for d in days if d.year == year]
        index = {d: i for i, d in enumerate(days)}

        sums: dict[str, list[list[float]]] = {}
        counts: list[list[int]] = [[0] * 24 for _ in days]
        for name in ENERGY_METRICS + MEAN_METRICS:
            sums[name] = [[0.0] * 24 for _ in days]

        for h, _temp in await self.hours(start, end):
            local = h.hour_start.astimezone(self.tz)
            row = index.get(local.date())
            if row is None or h.minutes <= 0:
                continue
            col = local.hour
            counts[row][col] += 1
            sums["pv_kwh"][row][col] += h.pv_kwh
            sums["house_kwh"][row][col] += h.house_kwh
            sums["import_kwh"][row][col] += h.import_kwh
            sums["export_kwh"][row][col] += h.export_kwh
            sums["grid_net_kwh"][row][col] += h.import_kwh - h.export_kwh
            sums["heat_pump_kwh"][row][col] += h.heat_pump_kwh
            sums["price_ct_kwh"][row][col] += h.avg_import_price_ct or 0.0
            sums["autarky"][row][col] += h.autarky if h.autarky is not None else 0.0

        metrics: dict[str, list[list[float | None]]] = {}
        for name in ENERGY_METRICS + MEAN_METRICS:
            divide = name in MEAN_METRICS
            metrics[name] = [
                [
                    None
                    if counts[r][c] == 0
                    else round(sums[name][r][c] / (counts[r][c] if divide else 1), 3)
                    for c in range(24)
                ]
                for r in range(len(days))
            ]
        filled = sum(1 for r in counts for c in r if c)
        since = await self.data_since() if self.data_since else None
        return YearMapOut(
            year=year, days=days, metrics=metrics, hours_with_data=filled, data_since=since
        )

    async def pv_report(self, period: Period, anchor: date, now: datetime) -> PvTaxReportOut:
        """PV-Abrechnung: Einspeisung, Eigenverbrauch und Umsatzsteuer für den Zeitraum.

        Die Summen des Zeitraums werden aus den ungerundeten Stundenwerten gebildet, die Zeilen der
        Aufschlüsselung jede für sich. Die Zeilensumme kann deshalb um wenige Cent vom ausgewiesenen
        Gesamtwert abweichen; die Seite sagt das dazu.
        """
        start, end = self.period_bounds(period, anchor)
        hours = await self.hours(start, end)
        totals = summarize(h for h, _ in hours)
        tariff = self.hems.tariff
        buckets = [
            PvTaxBucketOut(
                start=b_start,
                end=b_end,
                label=label,
                totals=pv_tax(
                    summarize(h for h, _ in hours if b_start <= h.hour_start < b_end), tariff
                ),
            )
            for b_start, b_end, label in self.bucket_starts(period, start, end)
        ]
        elapsed_min = max(0.0, (min(now, end) - start).total_seconds() / 60.0)
        coverage = round(min(1.0, totals.minutes / elapsed_min), 3) if elapsed_min > 0 else None
        since = await self.data_since() if self.data_since else None
        return PvTaxReportOut(
            period=period,
            anchor=anchor,
            start=start,
            end=end,
            totals=pv_tax(totals, tariff),
            buckets=buckets,
            meta=PvTaxMetaOut(
                feed_in_ct_kwh=tariff.feed_in_ct_kwh,
                vat_rate=0.0 if tariff.small_business else tariff.vat_rate,
                small_business=tariff.small_business,
                prices_include_vat=tariff.price_includes_vat,
                data_since=since,
                coverage=coverage,
                battery_capacity_kwh=self.hems.battery.capacity_kwh,
                method_de=(
                    "Eigenverbrauch ist PV, die im Haus geblieben ist: direkt plus der PV-Anteil der "
                    "Speicherentladung. Über den Speicher wird Buch geführt, welcher Anteil des Inhalts "
                    "aus PV stammt und welcher aus dem Netz geladen wurde; nur der PV-Anteil zählt. "
                    "Bewertet wird jede Kilowattstunde mit dem Netto-Bezugspreis derselben Stunde "
                    "(Tibber-Preis ÷ 1,19), also dem, was ihre Beschaffung aus dem Netz gekostet hätte."
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
                    # Der Ofen lädt denselben Puffer. Ohne ihn in derselben Reihe wäre die Frage
                    # „wer hat geladen?" wieder nur zu erschließen statt abzulesen.
                    "stove_running",
                    "stove_boiler_temp_c",
                    "stove_return_temp_c",
                    "stove_pump_pct",
                )
            }
            for i, r in enumerate(rows)
            if i % 5 == 0
        ]
        cycling = await self._cycling(start, min(end, now))
        stove = await self._stove(start, min(end, now))
        return HeatReportOut(
            summary=summary,
            thermal_kwh_est=round(thermal, 2),
            cop_est=cop_est,
            cycling=cycling,
            price_quality=_price_quality(hours, summary.totals),
            buffer_balance=_buffer_balance(buffer_series, self.hems.buffer),
            stove=stove,
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

    async def _stove(self, start: datetime, end: datetime) -> StoveOut:
        """Kennzahlen des Pelletofens aus der Minutenreihe des Zeitraums.

        Dieselbe Zeitgrenze wie bei der Taktung: über einen Monat hinaus wird nicht gerechnet, sonst
        müssten hunderttausende Zeilen durch den Dienst. Für „wie oft und wie lange brennt er?" sagt
        ein Monat dasselbe wie ein Jahr.
        """
        if end - start > timedelta(days=31):
            return StoveOut(
                note_de="Für Zeiträume über einen Monat wird der Ofen nicht ausgewertet."
            )
        rows = await self.minute_rows(start, end)
        samples = [
            StoveSample(
                running=bool(r["stove_running"]) if _num(r.get("stove_running")) else None,
                power_level=_val(r.get("stove_power_level")),
                auger_rpm=_val(r.get("stove_auger_rpm")),
                fume_temp_c=_val(r.get("stove_fume_temp_c")),
                boiler_temp_c=_val(r.get("stove_boiler_temp_c")),
                return_temp_c=_val(r.get("stove_return_temp_c")),
                pump_pct=_val(r.get("stove_pump_pct")),
                dhw=bool(r["stove_dhw_mode"]) if _num(r.get("stove_dhw_mode")) else None,
            )
            for r in rows
        ]
        st = stove_stats(samples)
        last = next((r for r in reversed(rows) if _num(r.get("stove_operating_hours"))), None)
        ignitions = _val(last.get("stove_ignitions")) if last else None
        return StoveOut(
            **st.model_dump(),
            operating_hours=_val(last.get("stove_operating_hours")) if last else None,
            ignitions=int(ignitions) if ignitions is not None else None,
            fuel_note_de=fuel_note(st.auger_revolutions),
        )

    async def _cycling(self, start: datetime, end: datetime) -> CyclingStats:
        """Verdichterläufe aus der Minutenreihe des Zeitraums.

        Über 31 Tage hinaus wird nicht gerechnet: dafür müssten hunderttausende Minutenzeilen durch
        den Dienst, und für die Frage „taktet die Anlage?" sagt ein Monat alles, was ein Jahr auch
        sagt. Statt einer stillen Näherung gibt es dann eine Ansage.
        """
        span = end - start
        if span > timedelta(days=31):
            return CyclingStats(
                note_de="Für Zeiträume über einen Monat wird die Taktung nicht ausgewertet."
            )
        rows = await self.minute_rows(start, end)
        samples: list[tuple[datetime, float | None]] = []
        covered = 0
        for r in rows:
            ts_raw = r.get("ts")
            if not isinstance(ts_raw, str):
                continue
            v = r.get("heat_pump_power_kw")
            value = float(v) if isinstance(v, int | float) else None
            samples.append((datetime.fromisoformat(ts_raw.replace("Z", "+00:00")), value))
            if value is not None:
                covered += 1
        hp = self.hems.heat_pump
        # Schwelle zwischen Verdichter und Grundlast: gut ein Drittel der kleinsten Verdichterstufe.
        on_kw = max(0.3, hp.minimum_electric_power_kw * 0.35)
        runs = compressor_runs(samples, on_kw)
        return cycling_stats(runs, covered, hp.min_runtime_min)

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
