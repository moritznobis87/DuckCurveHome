"""Die gemessene Kennlinie der Wärmepumpe: Arbeitszahl über Außen- und Vorlauftemperatur.

**Woraus ein Messpunkt entsteht.** Aus den Minutenwerten, die der Bus der Maschine und der
Zähler liefern: Durchfluss, Vorlauf, Rücklauf, Leistungsaufnahme, Außentemperatur. Die Wärme
einer Minute ist Durchfluss mal Spreizung mal Wärmekapazität des Wassers; die Arbeitszahl
eines Fensters ist die Summe der Wärme durch die Summe des Stroms. Ein Fenster zählt nur, wenn
die Maschine in jeder seiner Minuten heizt, schon eine Weile läuft und alle Werte da sind.

**Warum Fenster und nicht Minuten.** Die Werte kommen nicht gleichzeitig (der Bus meldet im
Abstand von Sekunden bis zu einer Minute), und Wasser hat eine Laufzeit vom Vorlauf- zum
Rücklauffühler. In einer einzelnen Minute stehen deshalb Zahlen nebeneinander, die nicht
zusammengehören; über zehn Minuten mittelt sich das heraus.

**Warum der Anlauf fehlt.** Nach dem Start heizt die Maschine erst sich selbst und ihr Wasser
auf. Die Arbeitszahl dieser Minuten sagt etwas über den Start, nichts über die Kennlinie.

**Ohne Heizstab.** Misst der Zähler deutlich mehr, als die Maschine für sich meldet, läuft die
elektrische Zusatzheizung mit. Solche Minuten zählen nicht (`ZUSATZ_KW`).

**Was der Punkt nicht ist.** Abtauphasen fallen heraus (die Maschine heizt dann nicht), also
ist das die Arbeitszahl im Heizbetrieb, nicht die eines Tages. Und sie erbt die Vorbehalte der
Messung: der Durchflussgeber ist nicht geeicht, die Zuordnung des Rücklaufs nicht bestätigt
(`docs/SENSORIK.md`). Ein systematischer Fehler dort verschiebt alle Punkte gemeinsam; die
Form der Kennlinie bleibt.

**Der Ausgleich.** Kleinste Quadrate über die Ebene

    COP = a + b * Außentemperatur + c * Vorlauftemperatur

Eine Ebene, weil sie die einfachste Form ist, die beide Abhängigkeiten trägt, und weil ihre
drei Zahlen sich lesen lassen: b sagt, was ein Grad draußen bringt, c, was ein Grad Vorlauf
kostet. Sie gilt nur dort, wo gemessen wurde. Decken die Punkte eine der beiden Temperaturen
nicht ab, lässt sich deren Einfluss nicht bestimmen; dann fällt der Term weg, statt eine Zahl
zu erfinden (`Ausgleich.art`).

Reine Funktionen, kein I/O.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal

#: Wärmekapazität von Wasser, auf Liter je Minute und Kelvin umgelegt: 4,186 kJ/(kg K) / 60 s,
#: ein Liter als ein Kilogramm gerechnet. Ergibt Kilowatt.
KW_JE_L_MIN_K = 4.186 / 60.0
#: Unter diesem Durchfluss steht die Pumpe; der Geber zeigt dann null oder Rauschen.
MIN_DURCHFLUSS = 2.0
#: Unter dieser Spreizung ist die Rechnung mehr Messfehler als Wärme.
MIN_SPREIZUNG_K = 0.5
#: Unter dieser Leistungsaufnahme läuft der Verdichter nicht.
MIN_LEISTUNG_KW = 0.3

#: Nimmt der Zähler an der Zuleitung so viel mehr auf, als die Maschine für sich meldet, läuft
#: neben dem Verdichter etwas anderes, vermutlich der elektrische Heizstab. Am 14.11.2026 um
#: 11:18 standen im Haus 8,84 kW am Zähler bei 64 Hz; eine Stunde vorher waren es bei 65 Hz
#: 3,16 kW. Solche Minuten gehören nicht in die Kennlinie der Wärmepumpe: ein Heizstab hat die
#: Arbeitszahl eins. Gesetzt auf 1,5 kW, unter der kleinsten Stufe eines Heizstabs und über dem,
#: was Lüfter, Umwälzpumpe und Regler aufnehmen.
ZUSATZ_KW = 1.5

#: Der Betriebszustand „heizt" der Maschine (`heat_pump_mode_code`). Abtauen ist 9.
MODUS_HEIZT = 3
#: Länge eines Fensters in Minuten; Fenster liegen auf dem Raster der Uhr.
FENSTER_MIN = 10
#: So lange muss die Maschine schon laufen, bevor ihre Minuten zählen.
ANLAUF_MIN = 10
#: Eine Arbeitszahl außerhalb dieser Grenzen ist ein Messfehler, kein Betriebspunkt.
COP_GRENZEN = (1.0, 9.0)

#: Ab so vielen Punkten wird ausgeglichen. Darunter bestimmt der Zufall das Ergebnis.
MIN_PUNKTE = 12
#: So weit müssen die Punkte in einer Temperatur gestreut sein, damit deren Einfluss bestimmbar
#: ist. Gesetzt, nicht gemessen: bei weniger liegt die Steigung in der Größe der Messstreuung.
MIN_SPANNE_AUSSEN_K = 4.0
MIN_SPANNE_VORLAUF_K = 5.0

Art = Literal["ebene", "aussen", "vorlauf", "mittel"]


@dataclass(frozen=True)
class Minute:
    """Eine Minute der Maschine. Fehlende Werte sind `None`."""

    ts: datetime
    aussen_c: float | None
    vorlauf_c: float | None
    ruecklauf_c: float | None
    durchfluss_l_min: float | None
    strom_kw: float | None
    modus: float | None = None
    hz: float | None = None
    #: Die Leistungsaufnahme nach Auskunft der Maschine selbst. Mit ihr lässt sich erkennen, ob
    #: der Zähler noch etwas anderes misst als den Verdichter.
    strom_maschine_kw: float | None = None


def zusatz_kw(zaehler_kw: float | None, maschine_kw: float | None) -> float | None:
    """Was der Zähler mehr misst, als die Maschine für sich meldet, wenn es mehr als `ZUSATZ_KW`
    ist. `None`: kein Zusatz erkennbar, oder einer der beiden Werte fehlt."""
    if zaehler_kw is None or maschine_kw is None:
        return None
    mehr = zaehler_kw - maschine_kw
    return round(mehr, 2) if mehr >= ZUSATZ_KW else None


@dataclass(frozen=True)
class Messpunkt:
    """Ein Fenster im eingeschwungenen Heizbetrieb."""

    at: datetime
    minuten: int
    aussen_c: float
    vorlauf_c: float
    cop: float
    waerme_kw: float
    strom_kw: float


@dataclass(frozen=True)
class Ausgleich:
    """COP = a + b_aussen * Außentemperatur + c_vorlauf * Vorlauftemperatur.

    `art` sagt, welche Terme bestimmt wurden: `ebene` beide, `aussen` oder `vorlauf` nur einer
    (der andere ist null, weil die Punkte ihn nicht hergeben), `mittel` keiner.
    """

    art: Art
    a: float
    b_aussen: float
    c_vorlauf: float
    n: int
    #: Mittlere Abweichung der Punkte von der Ausgleichsfläche (Wurzel des mittleren Quadrats).
    rmse: float
    #: Anteil der Streuung, den die Fläche erklärt. `None`, wenn die Punkte nicht streuen.
    r2: float | None
    aussen_von_c: float
    aussen_bis_c: float
    vorlauf_von_c: float
    vorlauf_bis_c: float

    def cop(self, aussen_c: float, vorlauf_c: float) -> float:
        return self.a + self.b_aussen * aussen_c + self.c_vorlauf * vorlauf_c


def _heizt(m: Minute) -> bool:
    """Läuft der Verdichter im Heizbetrieb? Der Zustand der Maschine entscheidet, wo er da ist."""
    if m.modus is not None:
        return round(m.modus) == MODUS_HEIZT
    if m.hz is not None:
        return m.hz > 0
    return m.strom_kw is not None and m.strom_kw >= MIN_LEISTUNG_KW


def _waerme_kw(m: Minute) -> float | None:
    """Die Wärmeleistung der Minute, oder `None`, wenn sie sich nicht rechnen lässt."""
    if (
        m.aussen_c is None
        or m.vorlauf_c is None
        or m.ruecklauf_c is None
        or m.durchfluss_l_min is None
        or m.strom_kw is None
    ):
        return None
    if zusatz_kw(m.strom_kw, m.strom_maschine_kw) is not None:
        return None  # der Heizstab läuft mit: keine Minute der Wärmepumpe allein
    spreizung = m.vorlauf_c - m.ruecklauf_c
    if (
        m.durchfluss_l_min < MIN_DURCHFLUSS
        or spreizung < MIN_SPREIZUNG_K
        or m.strom_kw < MIN_LEISTUNG_KW
    ):
        return None
    return m.durchfluss_l_min * spreizung * KW_JE_L_MIN_K


def zusatz_minuten(minuten: Sequence[Minute]) -> int:
    """In wie vielen Minuten neben dem Verdichter etwas anderes Strom nahm."""
    return sum(1 for m in minuten if zusatz_kw(m.strom_kw, m.strom_maschine_kw) is not None)


def messpunkte(minuten: Sequence[Minute]) -> list[Messpunkt]:
    """Die Fenster im eingeschwungenen Heizbetrieb, in zeitlicher Reihenfolge."""
    fenster: dict[datetime, list[tuple[Minute, float]]] = {}
    laeuft_seit = 0
    davor: datetime | None = None
    for m in sorted(minuten, key=lambda x: x.ts):
        luecke = davor is not None and m.ts - davor > timedelta(minutes=1, seconds=30)
        davor = m.ts
        if luecke or not _heizt(m):
            # Eine Lücke in den Daten zählt wie ein Halt: was in ihr war, weiß niemand.
            laeuft_seit = 1 if _heizt(m) else 0
            continue
        laeuft_seit += 1
        waerme = _waerme_kw(m)
        if laeuft_seit <= ANLAUF_MIN or waerme is None:
            continue
        start = m.ts.replace(
            minute=m.ts.minute - m.ts.minute % FENSTER_MIN, second=0, microsecond=0
        )
        fenster.setdefault(start, []).append((m, waerme))

    punkte: list[Messpunkt] = []
    for start in sorted(fenster):
        teile = fenster[start]
        if len(teile) < FENSTER_MIN:
            continue
        strom = sum(m.strom_kw or 0.0 for m, _ in teile)
        waerme = sum(w for _, w in teile)
        if strom <= 0:
            continue
        cop = waerme / strom
        if not COP_GRENZEN[0] <= cop <= COP_GRENZEN[1]:
            continue
        n = len(teile)
        punkte.append(
            Messpunkt(
                at=start,
                minuten=n,
                aussen_c=round(sum(m.aussen_c or 0.0 for m, _ in teile) / n, 2),
                vorlauf_c=round(sum(m.vorlauf_c or 0.0 for m, _ in teile) / n, 2),
                cop=round(cop, 3),
                waerme_kw=round(waerme / n, 3),
                strom_kw=round(strom / n, 3),
            )
        )
    return punkte


def _loese(matrix: list[list[float]], rechts: list[float]) -> list[float] | None:
    """Ein kleines lineares Gleichungssystem, Gauß mit Spaltenpivot. `None`: nicht lösbar."""
    n = len(rechts)
    a = [[*zeile, r] for zeile, r in zip(matrix, rechts, strict=True)]
    for spalte in range(n):
        pivot = max(range(spalte, n), key=lambda z: abs(a[z][spalte]))
        if abs(a[pivot][spalte]) < 1e-9:
            return None
        a[spalte], a[pivot] = a[pivot], a[spalte]
        for zeile in range(spalte + 1, n):
            f = a[zeile][spalte] / a[spalte][spalte]
            for k in range(spalte, n + 1):
                a[zeile][k] -= f * a[spalte][k]
    loesung = [0.0] * n
    for zeile in range(n - 1, -1, -1):
        rest = a[zeile][n] - sum(a[zeile][k] * loesung[k] for k in range(zeile + 1, n))
        loesung[zeile] = rest / a[zeile][zeile]
    return loesung


def ausgleich(punkte: Sequence[Messpunkt]) -> Ausgleich | None:
    """Die Ausgleichsfläche nach der Methode der kleinsten Quadrate, oder `None` bei zu wenigen
    Punkten. Gerechnet wird um die Mittelwerte der Temperaturen, damit das Gleichungssystem gut
    gestellt ist; ausgegeben werden die Zahlen der Formel in Grad Celsius."""
    n = len(punkte)
    if n < MIN_PUNKTE:
        return None
    ta = [p.aussen_c for p in punkte]
    tv = [p.vorlauf_c for p in punkte]
    y = [p.cop for p in punkte]
    ma, mv, my = sum(ta) / n, sum(tv) / n, sum(y) / n
    mit_aussen = max(ta) - min(ta) >= MIN_SPANNE_AUSSEN_K
    mit_vorlauf = max(tv) - min(tv) >= MIN_SPANNE_VORLAUF_K
    da = [t - ma for t in ta]
    dv = [t - mv for t in tv]
    dy = [c - my for c in y]
    b = c = 0.0
    if mit_aussen and mit_vorlauf:
        saa = sum(x * x for x in da)
        svv = sum(x * x for x in dv)
        sav = sum(p * q for p, q in zip(da, dv, strict=True))
        say = sum(p * q for p, q in zip(da, dy, strict=True))
        svy = sum(p * q for p, q in zip(dv, dy, strict=True))
        # Liegen die Punkte auf einer Geraden in der Ebene der zwei Temperaturen (kälter draußen
        # heißt immer auch wärmerer Vorlauf), lassen sich die zwei Einflüsse nicht trennen.
        if saa * svv > 0 and (sav * sav) / (saa * svv) < 0.98:
            loesung = _loese([[saa, sav], [sav, svv]], [say, svy])
            if loesung is not None:
                b, c = loesung
            else:
                mit_vorlauf = False
        else:
            mit_vorlauf = False
    if mit_aussen and not mit_vorlauf:
        saa = sum(x * x for x in da)
        b = sum(p * q for p, q in zip(da, dy, strict=True)) / saa if saa > 0 else 0.0
        c = 0.0
    elif mit_vorlauf and not mit_aussen:
        svv = sum(x * x for x in dv)
        c = sum(p * q for p, q in zip(dv, dy, strict=True)) / svv if svv > 0 else 0.0
        b = 0.0
    a = my - b * ma - c * mv
    rest = [yi - (a + b * t1 + c * t2) for yi, t1, t2 in zip(y, ta, tv, strict=True)]
    quadrate = sum(r * r for r in rest)
    streuung = sum(d * d for d in dy)
    art: Art = (
        "ebene"
        if mit_aussen and mit_vorlauf
        else "aussen"
        if mit_aussen
        else "vorlauf"
        if mit_vorlauf
        else "mittel"
    )
    return Ausgleich(
        art=art,
        a=round(a, 4),
        b_aussen=round(b, 4),
        c_vorlauf=round(c, 4),
        n=n,
        rmse=round((quadrate / n) ** 0.5, 3),
        r2=round(1 - quadrate / streuung, 3) if streuung > 1e-9 else None,
        aussen_von_c=min(ta),
        aussen_bis_c=max(ta),
        vorlauf_von_c=min(tv),
        vorlauf_bis_c=max(tv),
    )
