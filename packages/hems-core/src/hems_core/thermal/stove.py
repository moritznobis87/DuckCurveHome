"""Der Pelletofen: Brennphasen, Brennstoffeintrag, Anteil an der Pufferladung.

Der Ofen ist die zweite Wärmequelle am selben Kombipuffer. Solange nur die Wärmepumpe gemessen wurde,
ließ sich eine Pufferladung nicht zuordnen: wird der Speicher wärmer, während die Wärmepumpe steht,
war das bisher ein *Verdacht* auf Fremdwärme. Mit den Daten aus dem Maestro-Modul wird daraus eine
Feststellung, und erst damit ist die Arbeitszahl der Wärmepumpe belastbar.

**Der Brennstoffeintrag.** Die Förderschnecke dosiert die Pellets. Ihre Drehzahl über die Zeit
integriert ergibt eine Größe, die dem eingebrachten Brennstoff proportional ist. Der Proportionalfaktor
ist unbekannt und geräteabhängig, deshalb heißt die Größe hier `auger_revolutions` und nicht
„Kilogramm". Wer den Sack wiegt und die Umdrehungen dazwischen abliest, hat den Faktor; bis dahin ist
es eine belastbare **relative** Größe: doppelt so viele Umdrehungen sind doppelt so viel Brennstoff.

Reine Rechenlogik, kein I/O, kein Urteil über die Anlage.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from pydantic import BaseModel, ConfigDict

# Ab dieser Rauchgastemperatur brennt es wirklich. Darunter kann der Zustandscode „an" melden,
# während nur gezündet oder ausgekühlt wird.
#
# 45 °C und nicht 60: das Datenblatt nennt für den Minimalbetrieb 48 °C Abgastemperatur. Mit der
# ursprünglichen Schwelle hätte ein sauber auf kleiner Flamme laufender Ofen als „brennt nicht"
# gegolten. Die Schwelle muss unter den kältesten Betriebspunkt und über die Raumtemperatur, und
# dazwischen ist weniger Platz, als man vermutet.
BURNING_FUME_C = 45.0
# Ab dieser Pumpenmodulation gibt der Ofen Wärme an den Kreis ab. Darunter zirkuliert nichts,
# und eine Spreizung wäre bedeutungslos.
PUMPING_PCT = 5.0


@dataclass(frozen=True)
class StoveSample:
    """Eine Minute Ofen. Alle Felder dürfen fehlen: nicht jede Firmware führt jedes davon."""

    running: bool | None = None  # aus dem Zustandscode abgeleitet
    power_level: float | None = None
    auger_rpm: float | None = None
    fume_temp_c: float | None = None
    boiler_temp_c: float | None = None
    return_temp_c: float | None = None
    pump_pct: float | None = None
    dhw: bool | None = None  # Dreiwegeventil auf Warmwasser


class StoveStats(BaseModel):
    """Kennzahlen eines Zeitraums. `available=False` heißt: für diesen Zeitraum liegt nichts vor."""

    model_config = ConfigDict(frozen=True)

    available: bool = False
    running_minutes: int = 0
    burning_minutes: int = 0  # davon mit heißem Rauchgas, also wirklich Feuer
    runs: int = 0  # zusammenhängende Brennphasen
    longest_run_min: int | None = None
    auger_revolutions: float = 0.0  # Brennstoffeintrag, relativ
    fume_temp_max_c: float | None = None
    spread_k: float | None = None  # mittlere Spreizung, solange die Pumpe fördert
    pumping_minutes: int = 0
    dhw_minutes: int = 0
    minutes_by_level: dict[str, int] = {}
    note_de: str = ""


def stove_stats(samples: Sequence[StoveSample], step_min: float = 1.0) -> StoveStats:
    """Kennzahlen aus einer Minutenreihe.

    Eine Datenlücke **beendet** eine Brennphase, sie überbrückt sie nicht. Zwei Läufe mit einer Lücke
    dazwischen als einen zu zählen wäre eine Erfindung; sie getrennt zu zählen ist im Zweifel die
    vorsichtigere Aussage, weil sie die Taktung eher über- als unterschätzt.
    """
    known = [s for s in samples if s.running is not None]
    if not known:
        return StoveStats(note_de="Für diesen Zeitraum liegen keine Ofendaten vor.")

    running = burning = pumping = dhw = 0
    runs = 0
    current = 0
    longest = 0
    revolutions = 0.0
    fume_max: float | None = None
    spreads: list[float] = []
    by_level: dict[str, int] = {}
    was_running = False

    for s in samples:
        if s.running is None:  # Lücke: laufende Phase abschließen
            if was_running:
                longest = max(longest, current)
            was_running, current = False, 0
            continue
        if s.fume_temp_c is not None:
            fume_max = s.fume_temp_c if fume_max is None else max(fume_max, s.fume_temp_c)
        if not s.running:
            if was_running:
                longest = max(longest, current)
            was_running, current = False, 0
            continue

        running += 1
        if not was_running:
            runs += 1
        was_running = True
        current += 1

        if s.fume_temp_c is not None and s.fume_temp_c >= BURNING_FUME_C:
            burning += 1
        if s.auger_rpm is not None:
            revolutions += s.auger_rpm * step_min
        if s.power_level is not None and s.power_level > 0:
            key = str(int(s.power_level))
            by_level[key] = by_level.get(key, 0) + 1
        if s.dhw:
            dhw += 1
        if s.pump_pct is not None and s.pump_pct >= PUMPING_PCT:
            pumping += 1
            if s.boiler_temp_c is not None and s.return_temp_c is not None:
                spreads.append(s.boiler_temp_c - s.return_temp_c)

    longest = max(longest, current)
    spread = round(sum(spreads) / len(spreads), 1) if spreads else None
    return StoveStats(
        available=True,
        running_minutes=running,
        burning_minutes=burning,
        runs=runs,
        longest_run_min=longest or None,
        auger_revolutions=round(revolutions, 1),
        fume_temp_max_c=fume_max,
        spread_k=spread,
        pumping_minutes=pumping,
        dhw_minutes=dhw,
        minutes_by_level=dict(sorted(by_level.items())),
        note_de=_note(running, burning, runs, spread),
    )


def _note(running: int, burning: int, runs: int, spread: float | None) -> str:
    if running == 0:
        return "Der Ofen lief in diesem Zeitraum nicht."
    parts = [f"{runs} Brennphase{'n' if runs != 1 else ''}, zusammen {running} Minuten"]
    if burning and burning < running:
        idle = running - burning
        parts.append(f"davon {idle} Minuten Zünden oder Ausbrand ohne heißes Rauchgas")
    if spread is not None:
        parts.append(f"mittlere Spreizung des Ofenkreises {spread:.1f} K")
    return ", ".join(parts) + "."


def fuel_note(revolutions: float, kg_per_revolution: float | None = None) -> str:
    """Den Brennstoffeintrag benennen, ohne eine Genauigkeit zu behaupten, die es nicht gibt."""
    if revolutions <= 0:
        return "Kein Brennstoffeintrag im Zeitraum."
    if kg_per_revolution is None:
        return (
            f"{revolutions:.0f} Schneckenumdrehungen. Das ist dem eingebrachten Brennstoff "
            "proportional, aber nicht in Kilogramm umgerechnet: der Faktor ist geräteabhängig und "
            "hier nicht gemessen. Als Vergleichsgröße zwischen zwei Zeiträumen taugt er trotzdem."
        )
    return f"{revolutions * kg_per_revolution:.1f} kg Pellets (Faktor aus der Konfiguration)."
