"""Taktung der Wärmepumpe: Verdichterläufe aus der Leistungsreihe.

Zu häufiges Takten ist der häufigste Fehler an Wärmepumpenanlagen - falsch eingestellte Hysterese,
zu kleiner Puffer, überdimensionierter Verdichter. Es kostet Effizienz und Verdichterlebensdauer,
und der Stromzähler zeigt es nicht: er kennt nur die Summe. Sichtbar wird es erst, wenn man die
Minutenreihe in Läufe zerlegt und zählt.

Reine Rechenlogik, kein I/O. Bewusst ohne Urteil über die Anlage: die Funktion zählt und misst, die
Einordnung steht getrennt in `assess` und ist als Hinweis formuliert, nicht als Diagnose.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from itertools import pairwise
from statistics import median
from typing import Literal

from pydantic import BaseModel, ConfigDict


@dataclass(frozen=True)
class Run:
    """Ein zusammenhängender Verdichterlauf."""

    start: datetime
    end: datetime  # Ende der letzten laufenden Minute
    minutes: int
    kwh: float


Verdict = Literal["ok", "watch", "short_cycling", "unknown"]


class CyclingStats(BaseModel):
    """Kennzahlen der Taktung eines Zeitraums."""

    model_config = ConfigDict(frozen=True)

    runs: int = 0
    covered_hours: float = 0.0  # bewertete Zeit; ohne sie sagt „Starts je Tag" nichts
    starts_per_day: float | None = None
    running_minutes: int = 0
    duty_cycle: float | None = None  # Laufzeit / bewertete Zeit
    mean_run_min: float | None = None
    median_run_min: float | None = None
    shortest_run_min: int | None = None
    longest_run_min: int | None = None
    mean_pause_min: float | None = None
    short_runs: int = 0  # kürzer als die Mindestlaufzeit der Regelung
    short_share: float | None = None
    verdict: Verdict = "unknown"
    note_de: str = ""


def compressor_runs(
    samples: Sequence[tuple[datetime, float | None]],
    on_kw: float,
    step: timedelta = timedelta(minutes=1),
) -> list[Run]:
    """Läufe aus einer Leistungsreihe schneiden.

    `on_kw` trennt den Verdichter von der Grundlast der Anlage (Umwälzpumpe, Elektronik, Standby) -
    ohne diese Schwelle zählte jedes Brummen als Lauf.

    Eine Lücke in den Messwerten beendet den Lauf, statt ihn zu überbrücken. Über eine Lücke hinweg
    weiterzuzählen erfände Laufzeit; sie zu ignorieren erfände einen zusätzlichen Start. Der Schnitt
    ist die ehrlichere Wahl, und wie viel Zeit überhaupt bewertet wurde, steht in `covered_hours`.
    """
    runs: list[Run] = []
    start: datetime | None = None
    last: datetime | None = None
    energy = 0.0
    hours = step.total_seconds() / 3600.0
    for ts, kw in samples:
        gap = last is not None and ts - last > step * 1.5
        running = kw is not None and kw >= on_kw
        if start is not None and (gap or not running):
            runs.append(_close(start, last, step, energy))
            start, energy = None, 0.0
        if running:
            if start is None:
                start = ts
                energy = 0.0
            energy += (kw or 0.0) * hours
        last = ts if kw is not None else None
    if start is not None:
        runs.append(_close(start, last, step, energy))
    return runs


def _close(start: datetime, last: datetime | None, step: timedelta, energy: float) -> Run:
    end = (last or start) + step
    minutes = max(1, int((end - start).total_seconds() // 60))
    return Run(start=start, end=end, minutes=minutes, kwh=round(energy, 3))


def cycling_stats(
    runs: Sequence[Run], covered_minutes: int, min_runtime_min: float
) -> CyclingStats:
    """Läufe zu Kennzahlen verdichten. `covered_minutes` ist die Zeit mit Messwerten."""
    hours = round(covered_minutes / 60.0, 2)
    if covered_minutes <= 0:
        return CyclingStats(note_de="Keine Messwerte im Zeitraum.")
    lengths = [r.minutes for r in runs]
    running = sum(lengths)
    days = covered_minutes / 1440.0
    pauses = [int((b.start - a.end).total_seconds() // 60) for a, b in pairwise(runs)]
    short = sum(1 for m in lengths if m < min_runtime_min)
    stats = CyclingStats(
        runs=len(runs),
        covered_hours=hours,
        starts_per_day=round(len(runs) / days, 1) if days > 0 else None,
        running_minutes=running,
        duty_cycle=round(running / covered_minutes, 3),
        mean_run_min=round(running / len(lengths), 1) if lengths else None,
        median_run_min=round(float(median(lengths)), 1) if lengths else None,
        shortest_run_min=min(lengths) if lengths else None,
        longest_run_min=max(lengths) if lengths else None,
        mean_pause_min=round(sum(pauses) / len(pauses), 1) if pauses else None,
        short_runs=short,
        short_share=round(short / len(lengths), 3) if lengths else None,
    )
    return stats.model_copy(update=assess(stats, min_runtime_min))


def assess(s: CyclingStats, min_runtime_min: float) -> dict[str, object]:
    """Einordnung als Hinweis, nicht als Diagnose.

    Die Schwellen sind Erfahrungswerte, keine Norm: eine Wärmepumpe, die im Mittel öfter als
    stündlich startet oder deren Läufe überwiegend unter der eingestellten Mindestlaufzeit bleiben,
    taktet auffällig. Ob das an Hysterese, Puffereinbindung oder Dimensionierung liegt, sagt diese
    Rechnung nicht - sie sagt nur, dass es sich anzusehen lohnt.
    """
    if s.starts_per_day is None or s.runs == 0:
        return {"verdict": "unknown", "note_de": "Kein Verdichterlauf im Zeitraum erfasst."}
    if s.covered_hours < 12:
        return {
            "verdict": "unknown",
            "note_de": f"Nur {s.covered_hours:g} h bewertet - für eine Aussage zur Taktung zu wenig.",
        }
    short = s.short_share or 0.0
    base = (
        f"{s.starts_per_day:g} Starts je Tag, Läufe im Mittel {s.mean_run_min:g} min"
        f" (Mindestlaufzeit {min_runtime_min:g} min)."
    )
    if s.starts_per_day >= 24 or short >= 0.5:
        return {
            "verdict": "short_cycling",
            "note_de": f"{base} Das ist auffällig häufig - Hysterese, Puffereinbindung und"
            " Dimensionierung wären einen Blick wert.",
        }
    if s.starts_per_day >= 12 or short >= 0.25:
        return {"verdict": "watch", "note_de": f"{base} Grenzwertig, im Auge behalten."}
    return {"verdict": "ok", "note_de": f"{base} Unauffällig."}
