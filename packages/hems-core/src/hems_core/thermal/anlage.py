"""Das Anlagenschema im Augenblick: zwei Größen, die kein Fühler direkt misst.

Die Anlagenseite zeigt den Speicher als Glas und die vier Wasserkreise, die sich nur in ihm
berühren. Fast alles darauf ist ein Messwert oder ein Zustand, den es anderswo schon gibt. Zwei
Dinge fehlen, und beide werden hier aus Temperaturreihen gelesen:

* **Die Nettoleistung des Speichers.** Ob er gerade lädt oder entlädt, und wie stark, steht in
  keinem Fühler, aber in der Änderung seines Energieinhalts: vier Schichttemperaturen mal Volumen
  mal Wärmekapazität, abgeleitet über ein Zeitfenster. Dieselbe Rechnung wie in der Wärmebilanz,
  nur als einseitige Differenz bis zur jüngsten Minute, weil die Anzeige den Augenblick braucht und
  nicht die Mitte eines Fensters.
* **Die Zapfung am Warmwasser.** Ein Durchflusszähler fehlt. Erkannt wird sie an einem
  Anlegefühler am warmen Auslass oben am Speicher: Solange niemand zapft, kühlt das Rohr auf die
  Raumtemperatur des Technikraums aus; läuft warmes Wasser, springt es binnen ein, zwei Minuten
  auf fast die Temperatur der obersten Schicht. Das sagt, **dass** gezapft wird und seit wann,
  nicht wie viel.

Reine Rechenlogik über Zeitreihen, kein I/O.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

from hems_core.domain.config import BufferConfig
from hems_core.thermal.heat_balance import MAX_GAP_MIN, stored_energy_kwh

#: Über dieses Fenster wird die Nettoleistung gebildet. Länger als die zehn Minuten der
#: Wärmebilanz, weil hier nur eine Seite des Fensters zur Verfügung steht und das Rauschen der
#: Fühler sonst die Richtung wechseln ließe, während niemand etwas tut.
NETTO_FENSTER_MIN = 15.0
#: Mindestens so viel vom Fenster muss belegt sein, sonst ist die Zahl eine Momentaufnahme.
NETTO_MINDEST_MIN = 7.5
#: Darunter heißt es „hält": ein Kelvin Fühlerzittern über eine Viertelstunde sind schon 4,6 kW,
#: 0,15 kW sind also weniger als ein Zehntel davon, und das trauen wir der Messung nicht zu.
HAELT_KW = 0.15
#: Älter darf die jüngste Probe nicht sein, sonst beschreibt die Zahl nicht mehr den Augenblick.
FRISCH_MIN = 5.0

#: So steil steigt ein Rohr nur, wenn Wasser durchläuft. Ein Raum erwärmt es um Zehntel je Stunde.
ZAPF_ANSTIEG_K = 1.0
#: ... innerhalb dieser Spanne.
ZAPF_ANSTIEG_MIN = 3.0
#: So weit darf der Auslass unter sein Maximum fallen, bevor die Zapfung als beendet gilt. Weniger
#: wäre Fühlerzittern auf dem Plateau, mehr hieße, ein stehendes Rohr minutenlang „läuft" zu nennen.
ZAPF_ABKUEHLUNG_K = 0.8
#: So dicht am Tiefsten der Minuten vor dem Sprung gilt eine Minute noch als „unten".
ZAPF_TOLERANZ_K = 0.3


@dataclass(frozen=True)
class TempProbe:
    """Eine Minute Speicherfühler, Schichten von oben nach unten."""

    at: datetime
    temps: tuple[float, ...]


@dataclass(frozen=True)
class Zapfung:
    aktiv: bool
    seit: datetime | None


def buffer_net_kw(
    proben: Sequence[TempProbe],
    cfg: BufferConfig,
    now: datetime,
    window_min: float = NETTO_FENSTER_MIN,
) -> float | None:
    """Die mittlere Leistung des Speichers über das zurückliegende Fenster, positiv = lädt.

    `None`, wenn die Zahl nicht zu bilden ist: keine frische Probe, zu wenig Vergangenheit oder
    eine Lücke, die größer ist als das Fenster. Null wäre in jedem dieser Fälle eine Behauptung.

    Gerechnet wird **ungekappt** (`stored_energy_kwh`, nicht die nutzbare Energie): eine Schicht,
    die unter die Nutzgrenze fällt, verliert weiter Wärme, und genau das soll die Zahl zeigen.
    """
    voll = [p for p in proben if p.temps and p.at <= now]
    if not voll:
        return None
    voll.sort(key=lambda p: p.at)
    letzte = voll[-1]
    if (now - letzte.at).total_seconds() / 60.0 > FRISCH_MIN:
        return None
    # Die jüngste Probe, die mindestens ein Fenster zurückliegt; sonst die älteste, die es gibt.
    erste = letzte
    for p in reversed(voll):
        erste = p
        if (letzte.at - p.at).total_seconds() / 60.0 >= window_min:
            break
    minuten = (letzte.at - erste.at).total_seconds() / 60.0
    if minuten < NETTO_MINDEST_MIN or minuten > window_min + MAX_GAP_MIN:
        return None
    delta = stored_energy_kwh(letzte.temps, cfg) - stored_energy_kwh(erste.temps, cfg)
    return round(delta / (minuten / 60.0), 2)


def netto_wort(kw: float | None) -> str:
    """„lädt", „entlädt", „hält" oder leer: das Wort, das vor der Zahl steht."""
    if kw is None:
        return ""
    if abs(kw) < HAELT_KW:
        return "hält"
    return "lädt" if kw > 0 else "entlädt"


def zapfung(punkte: Sequence[tuple[datetime, float]], now: datetime) -> Zapfung:
    """Läuft gerade warmes Wasser durch den Auslass, und seit wann?

    Die Reihe wird vorwärts gelesen wie ein Schalter mit zwei Stellungen:

    * **Aus → an**, sobald das Rohr um `ZAPF_ANSTIEG_K` über das Tiefste der `ZAPF_ANSTIEG_MIN`
      Minuten davor steigt. Ein Raum, der sich erwärmt, schafft das nicht; fließendes Wasser
      schafft es in der ersten Minute. `seit` ist die letzte Minute, die noch unten lag: die, in
      der der Hahn aufging, nicht die, in der es schon zu sehen war.
    * **An → aus**, sobald das Rohr um `ZAPF_ABKUEHLUNG_K` unter sein Maximum seit dem Anstieg
      fällt. Ein Rohr kühlt nach dem Zudrehen binnen Minuten; das Plateau davor zittert nur, und
      Zittern darf die Zapfung nicht beenden.

    Ohne frische letzte Minute gibt es keine Aussage, also „aus".
    """
    p = sorted(((at, t) for at, t in punkte if at <= now), key=lambda x: x[0])
    if len(p) < 2 or (now - p[-1][0]).total_seconds() / 60.0 > FRISCH_MIN:
        return Zapfung(aktiv=False, seit=None)
    aktiv, seit, spitze = False, None, 0.0
    for j, (at_j, t_j) in enumerate(p):
        if aktiv:
            spitze = max(spitze, t_j)
            if t_j < spitze - ZAPF_ABKUEHLUNG_K:
                aktiv, seit = False, None
            continue
        fenster = [
            (at, t)
            for at, t in p[max(0, j - 10) : j]
            if (at_j - at).total_seconds() / 60.0 <= ZAPF_ANSTIEG_MIN
        ]
        if not fenster:
            continue
        tief = min(t for _, t in fenster)
        if t_j - tief >= ZAPF_ANSTIEG_K:
            aktiv, spitze = True, t_j
            seit = next(at for at, t in reversed(fenster) if t <= tief + ZAPF_TOLERANZ_K + 1e-9)
    return Zapfung(aktiv=aktiv, seit=seit)
