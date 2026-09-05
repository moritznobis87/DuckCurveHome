"""Bewertung von PV-Prognosen und rollierende Bias-Korrektur (Stufe 1 des Prognoselernens).

Reine Domänenlogik ohne I/O: Stichproben (Prognose, Ist) → Kennzahlen; Tagesabschluss → Korrekturfaktoren
je Sonnenhöhenklasse mit exponentiellem Vergessen, Dämpfung und Grenzen.
Siehe docs/design/prognose-und-waermemodell.md, Abschnitt 2.2.
"""

from __future__ import annotations

import math
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from pydantic import BaseModel, ConfigDict, Field

ELEVATION_BINS: tuple[tuple[float, float], ...] = ((0, 10), (10, 20), (20, 30), (30, 45), (45, 90))
BIN_LABELS_DE: tuple[str, ...] = ("0–10°", "10–20°", "20–30°", "30–45°", "über 45°")
HORIZON_CLASSES: tuple[tuple[float, float, str], ...] = (
    (0, 3, "0-3h"),
    (3, 12, "3-12h"),
    (12, 36, "12-36h"),
)
HORIZON_LABELS_DE: dict[str, str] = {
    "0-3h": "nächste 3 Stunden",
    "3-12h": "3 bis 12 Stunden",
    "12-36h": "12 bis 36 Stunden",
}


def elevation_bin(elevation_deg: float) -> int | None:
    """Index der Sonnenhöhenklasse; None nachts (Sonne unter dem Horizont)."""
    if elevation_deg <= 0:
        return None
    for i, (lo, hi) in enumerate(ELEVATION_BINS):
        if lo <= elevation_deg < hi:
            return i
    return len(ELEVATION_BINS) - 1


@dataclass(frozen=True)
class ForecastSample:
    """Ein Vergleichspunkt: Prognose gegen Messung für ein Intervall."""

    ts: datetime
    forecast_kw: float
    actual_kw: float
    elevation_deg: float
    horizon_h: float  # Abstand zwischen Ausgabe der Prognose und dem Intervall


class ForecastScore(BaseModel):
    model_config = ConfigDict(frozen=True)

    n: int
    mae_kw: float
    bias_kw: float  # Prognose − Ist; positiv = Prognose zu hoch
    rmse_kw: float
    energy_forecast_kwh: float
    energy_actual_kwh: float
    energy_error_pct: float | None  # (Prognose − Ist) / Ist in %, None ohne nennenswerte Erzeugung


def score(samples: Iterable[ForecastSample], step_h: float = 0.25) -> ForecastScore:
    xs = list(samples)
    n = len(xs)
    if n == 0:
        return ForecastScore(
            n=0,
            mae_kw=0.0,
            bias_kw=0.0,
            rmse_kw=0.0,
            energy_forecast_kwh=0.0,
            energy_actual_kwh=0.0,
            energy_error_pct=None,
        )
    errs = [s.forecast_kw - s.actual_kw for s in xs]
    e_f = sum(s.forecast_kw for s in xs) * step_h
    e_a = sum(s.actual_kw for s in xs) * step_h
    pct = round((e_f - e_a) / e_a * 100.0, 1) if e_a >= 0.5 else None
    return ForecastScore(
        n=n,
        mae_kw=round(sum(abs(e) for e in errs) / n, 3),
        bias_kw=round(sum(errs) / n, 3),
        rmse_kw=round(math.sqrt(sum(e * e for e in errs) / n), 3),
        energy_forecast_kwh=round(e_f, 2),
        energy_actual_kwh=round(e_a, 2),
        energy_error_pct=pct,
    )


def score_by_horizon(samples: Iterable[ForecastSample]) -> dict[str, ForecastScore]:
    xs = list(samples)
    out: dict[str, ForecastScore] = {}
    for lo, hi, key in HORIZON_CLASSES:
        out[key] = score(s for s in xs if lo <= s.horizon_h < hi)
    return out


def aggregate_15min(rows: Iterable[tuple[datetime, float | None]]) -> list[tuple[datetime, float]]:
    """Mittelt 1-Minuten-Werte auf 15-Minuten-Intervalle (Intervallbeginn), Lücken werden übersprungen."""
    sums: dict[datetime, list[float]] = {}
    for ts, v in rows:
        if v is None:
            continue
        slot = ts.replace(minute=(ts.minute // 15) * 15, second=0, microsecond=0)
        sums.setdefault(slot, []).append(v)
    return [(slot, round(sum(vs) / len(vs), 3)) for slot, vs in sorted(sums.items())]


# ----------------------------------------------------------------------------- Korrektur


class BinCorrection(BaseModel):
    model_config = ConfigDict(frozen=True)

    bin: int
    label_de: str
    factor: float = 1.0
    previous: float = 1.0  # Faktor vor dem letzten Tagesabschluss
    last_ratio: float | None = None  # Ist/Prognose des letzten bewerteten Tages
    days: int = 0  # Anzahl Tage, an denen diese Klasse gelernt hat


class CorrectorState(BaseModel):
    """Serialisierbarer Zustand des Korrektors (Persistenz in der API)."""

    model_config = ConfigDict(frozen=True)

    bins: list[BinCorrection] = Field(
        default_factory=lambda: [
            BinCorrection(bin=i, label_de=BIN_LABELS_DE[i]) for i in range(len(ELEVATION_BINS))
        ]
    )
    k_global: float = 1.0  # EWMA des Tagesenergie-Verhältnisses Ist/Prognose (nur Kennzahl)
    k_global_previous: float = 1.0
    days_learned: int = 0
    min_days: int = 14
    half_life_days: float = 10.0
    updated_on: date | None = None

    @property
    def active(self) -> bool:
        return self.days_learned >= self.min_days


class BinChange(BaseModel):
    model_config = ConfigDict(frozen=True)

    bin: int
    label_de: str
    ratio: float | None
    old: float
    new: float
    n: int


class DayUpdate(BaseModel):
    model_config = ConfigDict(frozen=True)

    day: date
    score: ForecastScore
    changes: list[BinChange]
    k_global_old: float
    k_global_new: float
    days_learned: int
    active_after: bool


class BiasCorrector:
    """Multiplikative Korrektur je Sonnenhöhenklasse, täglich aus dem Verhältnis Ist/Prognose gelernt.

    Vergessen über Halbwertszeit, höchstens ±max_step pro Tag, hart begrenzt auf clamp. Bis min_days Lerntage
    erreicht sind, wird nur beobachtet (apply liefert die Prognose unverändert).
    """

    def __init__(
        self,
        state: CorrectorState | None = None,
        *,
        half_life_days: float = 10.0,
        min_days: int = 14,
        clamp: tuple[float, float] = (0.5, 1.5),
        max_step: float = 0.05,
        min_energy_kwh_per_bin: float = 0.5,
    ) -> None:
        self.state = state or CorrectorState(min_days=min_days, half_life_days=half_life_days)
        self.clamp = clamp
        self.max_step = max_step
        self.min_energy_kwh_per_bin = min_energy_kwh_per_bin

    @property
    def alpha(self) -> float:
        return 1.0 - float(0.5 ** (1.0 / max(1.0, self.state.half_life_days)))

    def factor_for(self, elevation_deg: float) -> float:
        b = elevation_bin(elevation_deg)
        if b is None or not self.state.active:
            return 1.0
        return self.state.bins[b].factor

    def apply(self, forecast_kw: float, elevation_deg: float) -> float:
        return round(forecast_kw * self.factor_for(elevation_deg), 3)

    def _damped(self, old: float, target: float) -> float:
        new = old + self.alpha * (target - old)
        new = max(old - self.max_step, min(old + self.max_step, new))
        return round(max(self.clamp[0], min(self.clamp[1], new)), 4)

    def update_day(
        self, day: date, samples: Iterable[ForecastSample], step_h: float = 0.25
    ) -> DayUpdate:
        xs = list(samples)
        day_score = score(xs, step_h)
        st = self.state
        changes: list[BinChange] = []
        new_bins: list[BinCorrection] = []
        for bc in st.bins:
            lo, hi = ELEVATION_BINS[bc.bin]
            part = [
                s
                for s in xs
                if lo <= s.elevation_deg < hi
                or (bc.bin == len(ELEVATION_BINS) - 1 and s.elevation_deg >= hi)
            ]
            e_f = sum(s.forecast_kw for s in part) * step_h
            e_a = sum(s.actual_kw for s in part) * step_h
            if e_f < self.min_energy_kwh_per_bin:
                new_bins.append(bc)  # zu wenig Energie in dieser Klasse: nichts lernen
                continue
            ratio = round(e_a / e_f, 4)
            new = self._damped(bc.factor, ratio)
            changes.append(
                BinChange(
                    bin=bc.bin,
                    label_de=bc.label_de,
                    ratio=ratio,
                    old=bc.factor,
                    new=new,
                    n=len(part),
                )
            )
            new_bins.append(
                bc.model_copy(
                    update={
                        "factor": new,
                        "previous": bc.factor,
                        "last_ratio": ratio,
                        "days": bc.days + 1,
                    }
                )
            )
        k_old = st.k_global
        k_new = k_old
        if day_score.energy_forecast_kwh >= 1.0:
            k_new = self._damped(k_old, day_score.energy_actual_kwh / day_score.energy_forecast_kwh)
        learned = st.days_learned + (1 if changes else 0)
        self.state = st.model_copy(
            update={
                "bins": new_bins,
                "k_global": k_new,
                "k_global_previous": k_old,
                "days_learned": learned,
                "updated_on": day,
            }
        )
        return DayUpdate(
            day=day,
            score=day_score,
            changes=changes,
            k_global_old=k_old,
            k_global_new=k_new,
            days_learned=learned,
            active_after=self.state.active,
        )


def _de(x: float, digits: int = 2) -> str:
    return f"{x:.{digits}f}".replace(".", ",")


def explain_corrections_de(state: CorrectorState) -> list[str]:
    """Was sich für die nächste Prognose ändert, in Sätzen für die Detailseite."""
    lines: list[str] = []
    if not state.active:
        lines.append(
            f"Korrektur noch nicht aktiv: {state.days_learned} von {state.min_days} Lerntagen. "
            "Bis dahin wird die Prognose unverändert verwendet und nur bewertet."
        )
    for b in state.bins:
        if b.days == 0:
            continue
        pct = (b.factor - 1.0) * 100.0
        delta = (b.factor - b.previous) * 100.0
        direction = "gesenkt" if pct < 0 else "angehoben"
        if abs(pct) < 0.5:
            lines.append(
                f"Sonnenhöhe {b.label_de}: keine Korrektur nötig (Faktor {_de(b.factor)})."
            )
            continue
        trend = ""
        if abs(delta) >= 0.5:
            richtung = "weiter" if delta * pct > 0 else "wieder etwas zurück"
            trend = f", zuletzt {richtung} um {_de(abs(delta), 1)} Punkte"
        lines.append(
            f"Sonnenhöhe {b.label_de}: Prognose wird um {abs(pct):.0f} % {direction} "
            f"(Faktor {_de(b.factor)}{trend})."
        )
    kg = (state.k_global - 1.0) * 100.0
    if state.days_learned:
        lines.append(
            f"Tagesenergie im Mittel {'über' if kg < 0 else 'unter'}schätzt: Ist/Prognose {_de(state.k_global)} "
            f"(exponentiell gewichtet, Halbwertszeit {state.half_life_days:g} Tage)."
        )
    return lines


def horizon_hours(issued_at: datetime, ts: datetime) -> float:
    return max(0.0, (ts - issued_at) / timedelta(hours=1))
