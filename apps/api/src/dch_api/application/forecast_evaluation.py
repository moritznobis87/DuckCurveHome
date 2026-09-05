"""Prognosebewertung: bewahrt ausgegebene PV-Prognosen auf, vergleicht sie mit der Messung und lernt daraus.

Sammelt Prognoseläufe (15-min-Raster), schließt Tage ab (Day-ahead-Lauf gegen Ist), pflegt den
BiasCorrector und liefert die Auswertung für die Detailseite. Reine Rechenlogik, die Läufe und Messwerte
bekommt sie von der Laufzeit (Demo oder Live) gereicht; Persistenz über `to_state`/`from_state`.
"""

from __future__ import annotations

from collections import deque
from collections.abc import Callable, Iterable
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict, Field

from dch_api.schemas import (
    DailyScoreOut,
    ForecastDayOut,
    ForecastEvaluationOut,
    ForecastPointOut,
    HorizonScoreOut,
    SourceOut,
)
from hems_core.forecasting import (
    BiasCorrector,
    CorrectorState,
    DayUpdate,
    ForecastSample,
    aggregate_15min,
    explain_corrections_de,
    score,
    score_by_horizon,
    solar_elevation_deg,
)
from hems_core.forecasting.evaluation import HORIZON_LABELS_DE, horizon_hours

STEP = timedelta(minutes=15)
STAGE_DE = "Stufe 1 – Bias-Korrektur je Sonnenhöhe"


class IssuedRun(BaseModel):
    model_config = ConfigDict(frozen=True)

    issued_at: datetime
    source: str
    points: dict[datetime, float]  # 15-min-Intervallbeginn (UTC) → kW


class EvaluatorState(BaseModel):
    """Serialisierbarer Gesamtzustand (Korrektor, Tageswerte, aufbewahrte Läufe)."""

    corrector: CorrectorState = Field(default_factory=CorrectorState)
    daily: list[DailyScoreOut] = Field(default_factory=list)
    runs: list[IssuedRun] = Field(default_factory=list)
    closed_days: list[date] = Field(default_factory=list)


class ForecastEvaluator:
    def __init__(
        self,
        *,
        latitude: float,
        longitude: float,
        tz: ZoneInfo,
        source: str,
        source_label_de: str,
        corrector: BiasCorrector | None = None,
        keep_runs: timedelta = timedelta(hours=60),
        max_daily: int = 30,
    ) -> None:
        self.lat = latitude
        self.lon = longitude
        self.tz = tz
        self.source = source
        self.source_label_de = source_label_de
        self.corrector = corrector or BiasCorrector()
        self.keep_runs = keep_runs
        self.runs: list[IssuedRun] = []
        self.daily: deque[DailyScoreOut] = deque(maxlen=max_daily)
        self.closed_days: set[date] = set()
        self.last_update: DayUpdate | None = None

    # ------------------------------------------------------------------ Zustand
    def to_state(self) -> EvaluatorState:
        return EvaluatorState(
            corrector=self.corrector.state,
            daily=list(self.daily),
            runs=self.runs[-80:],
            closed_days=sorted(self.closed_days)[-40:],
        )

    def load_state(self, state: EvaluatorState) -> None:
        self.corrector = BiasCorrector(state.corrector)
        self.daily = deque(state.daily, maxlen=self.daily.maxlen)
        self.runs = list(state.runs)
        self.closed_days = set(state.closed_days)

    # ------------------------------------------------------------------ Hilfen
    def elevation(self, ts: datetime) -> float:
        return solar_elevation_deg(ts, self.lat, self.lon)

    def corrected(self, forecast_kw: float, ts: datetime) -> float:
        return self.corrector.apply(forecast_kw, self.elevation(ts))

    def pv_expected_corrected(
        self, raw: Callable[[datetime], float]
    ) -> Callable[[datetime], float]:
        """Umhüllt eine Prognosefunktion mit den gelernten Faktoren (für den Planer)."""

        def f(at: datetime) -> float:
            return self.corrected(raw(at), at)

        return f

    def day_bounds(self, day: date) -> tuple[datetime, datetime]:
        start = datetime.combine(day, time(0, 0), tzinfo=self.tz).astimezone(UTC)
        return start, start + timedelta(days=1)

    @staticmethod
    def slot(ts: datetime) -> datetime:
        ts = ts.astimezone(UTC)
        return ts.replace(minute=(ts.minute // 15) * 15, second=0, microsecond=0)

    # ------------------------------------------------------------------ Läufe
    def record_run(
        self,
        issued_at: datetime,
        points: Iterable[tuple[datetime, float]],
        source: str | None = None,
    ) -> None:
        pts = {self.slot(ts): round(float(kw), 3) for ts, kw in points}
        if not pts:
            return
        issued_slot = self.slot(issued_at)
        # ein Lauf pro Viertelstunde: gleiches Ausgabeintervall ersetzt den vorherigen
        self.runs = [r for r in self.runs if self.slot(r.issued_at) != issued_slot]
        self.runs.append(IssuedRun(issued_at=issued_at, source=source or self.source, points=pts))
        cutoff = issued_at - self.keep_runs
        self.runs = [r for r in self.runs if r.issued_at >= cutoff]
        self.runs.sort(key=lambda r: r.issued_at)

    def latest_run(self) -> IssuedRun | None:
        return self.runs[-1] if self.runs else None

    def day_ahead_run(self, day: date) -> IssuedRun | None:
        """Lauf, der um 06:00 Ortszeit gültig war (der letzte davor), sonst der früheste, der den Tag deckt."""
        six = datetime.combine(day, time(6, 0), tzinfo=self.tz).astimezone(UTC)
        start, end = self.day_bounds(day)
        covering = [r for r in self.runs if any(start <= ts < end for ts in r.points)]
        before = [r for r in covering if r.issued_at <= six]
        if before:
            return before[-1]
        return covering[0] if covering else None

    # ------------------------------------------------------------------ Vergleich
    def samples(
        self, run: IssuedRun, actual: dict[datetime, float], start: datetime, end: datetime
    ) -> list[ForecastSample]:
        out: list[ForecastSample] = []
        for ts, kw in run.points.items():
            if not (start <= ts < end) or ts not in actual:
                continue
            el = self.elevation(ts + STEP / 2)
            if el <= 0 and kw <= 0.01 and actual[ts] <= 0.01:
                continue  # Nacht ohne Information
            out.append(
                ForecastSample(
                    ts=ts,
                    forecast_kw=kw,
                    actual_kw=actual[ts],
                    elevation_deg=el,
                    horizon_h=horizon_hours(run.issued_at, ts),
                )
            )
        return out

    def close_day(
        self, day: date, actual_rows: Iterable[tuple[datetime, float | None]]
    ) -> DayUpdate | None:
        if day in self.closed_days:
            return None
        run = self.day_ahead_run(day)
        if run is None:
            return None
        start, end = self.day_bounds(day)
        actual = dict(aggregate_15min(actual_rows))
        xs = self.samples(run, actual, start, end)
        if len(xs) < 8:  # weniger als zwei Stunden Vergleich: Tag nicht bewerten
            return None
        upd = self.corrector.update_day(day, xs)
        self.closed_days.add(day)
        self.last_update = upd
        s = upd.score
        self.daily.append(
            DailyScoreOut(
                day=day,
                energy_forecast_kwh=s.energy_forecast_kwh,
                energy_actual_kwh=s.energy_actual_kwh,
                energy_error_pct=s.energy_error_pct,
                mae_kw=s.mae_kw,
                bias_kw=s.bias_kw,
                k_global_after=upd.k_global_new,
                issued_at=run.issued_at,
            )
        )
        return upd

    def days_to_close(self, now: datetime) -> list[date]:
        """Gestern (und ggf. Vortage), sobald es 00:15 Ortszeit ist und der Tag noch offen ist."""
        local = now.astimezone(self.tz)
        if local.hour == 0 and local.minute < 15:
            return []
        yesterday = local.date() - timedelta(days=1)
        return [d for d in (yesterday - timedelta(days=1), yesterday) if d not in self.closed_days]

    # ------------------------------------------------------------------ Auswertung
    def _day_out(
        self, day: date, actual_rows: Iterable[tuple[datetime, float | None]], now: datetime
    ) -> ForecastDayOut:
        start, end = self.day_bounds(day)
        actual = dict(aggregate_15min(actual_rows))
        ahead = self.day_ahead_run(day)
        latest = self.latest_run()
        points: list[ForecastPointOut] = []
        t = start
        while t < end:
            a = actual.get(t)
            f_ahead = ahead.points.get(t) if ahead else None
            f_latest = latest.points.get(t) if latest else None
            points.append(
                ForecastPointOut(
                    ts=t,
                    actual_kw=a if t <= now else None,
                    day_ahead_kw=f_ahead,
                    latest_kw=f_latest,
                    corrected_kw=None if f_latest is None else self.corrected(f_latest, t),
                )
            )
            t += STEP
        sc = None
        if ahead is not None:
            xs = self.samples(ahead, actual, start, min(end, now))
            if xs:
                sc = score(xs)
        return ForecastDayOut(
            day=day, issued_at=ahead.issued_at if ahead else None, score=sc, points=points
        )

    def evaluation(
        self,
        now: datetime,
        today_rows: Iterable[tuple[datetime, float | None]],
        yesterday_rows: Iterable[tuple[datetime, float | None]],
    ) -> ForecastEvaluationOut:
        today_rows_l = list(today_rows)
        yesterday_rows_l = list(yesterday_rows)
        local_today = now.astimezone(self.tz).date()
        today = self._day_out(local_today, today_rows_l, now)
        yesterday = self._day_out(local_today - timedelta(days=1), yesterday_rows_l, now)

        # Fehler nach Horizont über alle aufbewahrten Läufe (gestern und heute bis jetzt)
        actual = dict(aggregate_15min(yesterday_rows_l + today_rows_l))
        y_start, _ = self.day_bounds(local_today - timedelta(days=1))
        all_samples: list[ForecastSample] = []
        for r in self.runs:
            all_samples.extend(self.samples(r, actual, y_start, now))
        horizons = [
            HorizonScoreOut(key=k, label_de=HORIZON_LABELS_DE[k], score=v)
            for k, v in score_by_horizon(all_samples).items()
        ]

        recent = list(self.daily)[-7:]
        mae7 = round(sum(d.mae_kw for d in recent) / len(recent), 3) if recent else None
        st = self.corrector.state
        notes = [
            "Bewertet wird der Day-ahead-Lauf: die Prognose, die um 06:00 Uhr für den Tag vorlag.",
            "Die Korrektur lernt aus dem Verhältnis Ist/Prognose je Sonnenhöhenklasse, Halbwertszeit "
            f"{st.half_life_days:g} Tage, höchstens ±5 Punkte pro Tag, Grenzen 0,5 bis 1,5.",
            "„Korrigiert“ zeigt die jüngste Prognose mit den heutigen Faktoren.",
        ]
        return ForecastEvaluationOut(
            generated_at=now,
            stage_de=STAGE_DE,
            sources=[
                SourceOut(
                    name=self.source,
                    label_de=self.source_label_de,
                    weight=1.0,
                    mae_7d_kw=mae7,
                    active=True,
                )
            ],
            today=today,
            yesterday=yesterday,
            daily=list(self.daily),
            horizons=horizons,
            corrector=st,
            correction_active=st.active,
            next_changes_de=explain_corrections_de(st),
            runs_kept=len(self.runs),
            notes_de=notes,
        )
