"""Die gemessene Kennlinie der Wärmepumpe: Arbeitszahl über Außen- und Vorlauftemperatur.

**Woraus ein Messpunkt entsteht.** Aus den Minutenwerten, die der Bus der Maschine und der
Zähler liefern: Durchfluss, Vorlauf, Rücklauf, Leistungsaufnahme, Außentemperatur. Die Wärme
einer Minute ist Durchfluss mal Spreizung mal Wärmekapazität des Wassers; die Arbeitszahl
eines Fensters ist die Summe der Wärme durch die Summe des Stroms. Ein Fenster zählt, wenn die
Maschine in mindestens acht seiner zehn Minuten eingeschwungen heizt und die Werte da sind.

**Warum Fenster und nicht Minuten.** Die Werte kommen nicht gleichzeitig (der Bus meldet im
Abstand von Sekunden bis zu einer Minute), und Wasser hat eine Laufzeit vom Vorlauf- zum
Rücklauffühler. In einer einzelnen Minute stehen deshalb Zahlen nebeneinander, die nicht
zusammengehören; über zehn Minuten mittelt sich das heraus.

**Warum der Anlauf fehlt.** Nach dem Start heizt die Maschine erst sich selbst und ihr Wasser
auf. Die Arbeitszahl dieser Minuten sagt etwas über den Start, nichts über die Kennlinie.

**Ohne Heizstab.** Läuft neben dem Verdichter die elektrische Zusatzheizung, zählt die Minute
nicht (`zusatz`).

**Die Bilanz.** `auswerten` gibt neben den Punkten zurück, wo die übrigen Minuten geblieben
sind: im Anlauf, beim Heizstab, ohne Wert, ohne Wärme. Eine leere Kennlinie soll sagen, woran
es liegt.

**Was der Punkt nicht ist.** Abtauphasen fallen heraus (die Maschine heizt dann nicht), also
ist das die Arbeitszahl im Heizbetrieb, nicht die eines Tages. Und sie erbt den Vorbehalt der
Messung: der Durchflussgeber ist nicht geeicht (`docs/SENSORIK.md`). Ein systematischer Fehler
dort verschiebt alle Punkte gemeinsam; die Form der Kennlinie bleibt.

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
from dataclasses import dataclass, field, replace
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

#: **Der Heizstab.** Läuft neben dem Verdichter die elektrische Zusatzheizung, gehört die Minute
#: nicht in die Kennlinie der Wärmepumpe: ein Heizstab hat die Arbeitszahl eins. Am 14.11.2026
#: um 11:18 standen im Haus 8,84 kW am Zähler bei 64 Hz; eine Stunde vorher waren es bei 65 Hz
#: 3,16 kW. Erkannt wird das auf zwei Wegen:
#:
#: * Der Zähler misst mehr, als der Verdichter allein aufnehmen kann (`ZUSATZ_ABSOLUT_KW`).
#:   Gesetzt aus dem, was im Haus gesehen wurde: bis rund 3,5 kW im gewöhnlichen Lauf.
#: * Der Zähler liegt deutlich über dem, was die Maschine für sich meldet, **gemessen an ihrem
#:   gewöhnlichen Verhältnis** (`ZUSATZ_KW`). Das Verhältnis wird aus den Minuten selbst
#:   bestimmt (Median), weil nicht bekannt ist, ob die Maschine ihre ganze Aufnahme meldet oder
#:   nur einen Teil. Die erste Fassung verglich die beiden Zahlen unmittelbar; meldet die
#:   Maschine grundsätzlich weniger, als der Zähler misst, fiel damit jede Minute heraus, und
#:   die Kennlinie blieb leer (im Haus gesehen am 14.11.2026).
ZUSATZ_ABSOLUT_KW = 5.5
ZUSATZ_KW = 1.5
#: Ab so vielen Minuten mit beiden Angaben gilt das Verhältnis als bestimmt.
VERHAELTNIS_MIN = 30

#: Die Betriebszustände der Maschine, in denen sie heizt (`heat_pump_mode_code`): Heizen, Heizen
#: mit voller Leistung, Heizen im Nennpunkt. Abtauen ist 9.
MODUS_HEIZT = 3
MODI_HEIZEN = frozenset({3, 4, 6})
#: Länge eines Fensters in Minuten; Fenster liegen auf dem Raster der Uhr.
FENSTER_MIN = 10
#: So viele Minuten eines Fensters müssen gültig sein. Nicht alle zehn: eine einzelne Minute
#: ohne Wert darf kein ganzes Fenster kosten.
FENSTER_GUELTIG_MIN = 8
#: Über so viele Minuten ohne Wert wird eine Reihe überbrückt: zwischen dem Wert davor und dem
#: danach liegt die Gerade, am Ende der Reihe gilt der letzte weiter. Der Bus sendet Vorlauf,
#: Rücklauf und die Leistung der Maschine nur etwa alle halbe Minute bis Minute (gezählt in vier
#: Protokollen vom 13. und 14.11.2026: je ein bis zwei Meldungen in vierzig Sekunden), der
#: Rücklauf steht dazu in einer Liste, deren Zusammensetzung wechselt. Rutscht eine Meldung über
#: die Minutengrenze, hat eine Minute keinen Wert, obwohl nichts fehlt. Die erste Fassung
#: verlangte jeden Wert in jeder Minute und fand im Haus nach Stunden Lauf kein einziges
#: vollständiges Fenster (14.11.2026). Gesetzt: fünf Minuten; im eingeschwungenen Lauf ändern
#: sich die Temperaturen in dieser Zeit um Zehntel, nicht um Grade.
AUFFUELLEN_MIN = 5
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
    #: Die Stellung des Umschaltventils als Zahl des Reglers (abgefragt seit dem 14.11.2026).
    #: Laut Bus-Beschreibung 0 Warmwasser, 1 Heizung; im Haus noch nicht gegengeprüft.
    ventil: float | None = None
    #: Der Vorlauf-Sollwert, den der Regler der Maschine vorgibt. Die Kennlinie braucht ihn
    #: nicht; aus ihm entsteht die Heizkurve des Reglers (`betrieb.py`).
    vorlauf_soll_c: float | None = None


def zusatz_kw(
    zaehler_kw: float | None, maschine_kw: float | None, verhaeltnis: float | None = None
) -> float | None:
    """Wie viel der Zähler über dem liegt, was dem Verdichter zuzurechnen ist, wenn es für den
    Heizstab reicht; sonst `None`.

    Mit `verhaeltnis` (dem gewöhnlichen Verhältnis von Zähler zu Maschine) zählt der Abstand
    zum Gewöhnlichen. Ohne es wird nur behauptet, was sicher ist: mehr als `ZUSATZ_ABSOLUT_KW`
    nimmt der Verdichter allein nicht auf.
    """
    if zaehler_kw is None or maschine_kw is None or maschine_kw < MIN_LEISTUNG_KW:
        return None
    if verhaeltnis is not None:
        mehr = zaehler_kw - verhaeltnis * maschine_kw
        return round(mehr, 2) if mehr >= ZUSATZ_KW else None
    if zaehler_kw >= ZUSATZ_ABSOLUT_KW and zaehler_kw - maschine_kw >= ZUSATZ_KW:
        return round(zaehler_kw - maschine_kw, 2)
    return None


def zusatz(m: Minute, verhaeltnis: float | None) -> bool:
    """Läuft in dieser Minute neben dem Verdichter etwas anderes mit, vermutlich der Heizstab?"""
    if m.strom_kw is None:
        return False
    if m.strom_kw >= ZUSATZ_ABSOLUT_KW:
        return True
    return (
        verhaeltnis is not None
        and zusatz_kw(m.strom_kw, m.strom_maschine_kw, verhaeltnis) is not None
    )


def verhaeltnis_zaehler_maschine(minuten: Sequence[Minute]) -> float | None:
    """Wie viel der Zähler gewöhnlich über dem liegt, was die Maschine für sich meldet: der
    Median des Verhältnisses über die Minuten im Lauf. `None`, solange es zu wenige sind."""
    werte = sorted(
        m.strom_kw / m.strom_maschine_kw
        for m in minuten
        if m.strom_kw is not None
        and m.strom_maschine_kw is not None
        and m.strom_maschine_kw >= MIN_LEISTUNG_KW
        and MIN_LEISTUNG_KW <= m.strom_kw < ZUSATZ_ABSOLUT_KW
    )
    if len(werte) < VERHAELTNIS_MIN:
        return None
    mitte = len(werte) // 2
    return werte[mitte] if len(werte) % 2 else (werte[mitte - 1] + werte[mitte]) / 2


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
    #: Die Stellung des Umschaltventils, wenn sie in allen Minuten des Fensters dieselbe war.
    ventil: int | None = None


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


#: Die Größen, ohne die sich keine Wärme rechnen lässt, mit ihrem Namen für die Bilanz.
PFLICHT = {
    "aussen_c": "Außentemperatur",
    "vorlauf_c": "Vorlauf",
    "ruecklauf_c": "Rücklauf",
    "durchfluss_l_min": "Durchfluss",
    "strom_kw": "Zähler",
}
#: Alle Reihen, deren letzter Wert kurz weiter gilt.
_REIHEN = (*PFLICHT, "modus", "hz", "strom_maschine_kw", "ventil", "vorlauf_soll_c")
#: Davon die Zustände: zwischen zwei Zuständen liegt kein dritter, der alte gilt weiter.
_ZUSTAENDE = frozenset({"modus", "ventil"})


@dataclass
class Bilanz:
    """Wo die Minuten geblieben sind. Damit eine leere Kennlinie sagt, woran es liegt."""

    minuten: int = 0
    #: Minuten, in denen die Maschine heizte.
    heizen: int = 0
    #: davon im Anlauf nach einem Start,
    anlauf: int = 0
    #: mit Heizstab,
    zusatz: int = 0
    #: ohne einen der nötigen Werte (welcher, steht in `fehlt`),
    ohne_wert: int = 0
    #: mit allen Werten, aber ohne rechenbare Wärme (Pumpe steht, keine Spreizung),
    ohne_waerme: int = 0
    #: und die übrigen: gültig.
    gueltig: int = 0
    #: Fenster mit mindestens einer gültigen Minute, und wie viele davon voll genug waren.
    fenster: int = 0
    punkte: int = 0
    #: Fenster, deren Arbeitszahl außerhalb des Glaubwürdigen lag.
    unglaubwuerdig: int = 0
    #: Das gewöhnliche Verhältnis von Zähler zu Maschine, wenn es bestimmt ist.
    verhaeltnis: float | None = None
    fehlt: dict[str, int] = field(default_factory=dict)


def auffuellen(minuten: Sequence[Minute]) -> list[Minute]:
    """Die Minuten in zeitlicher Folge, kurze Lücken einer Reihe überbrückt.

    Zwischen zwei Werten, die höchstens `AUFFUELLEN_MIN` Minuten ohne Wert trennen, liegt die
    Gerade; der Betriebszustand ist ein Zustand und keine Größe, er gilt so lange einfach
    weiter. Am Ende einer Reihe gilt der letzte Wert weiter, ebenso lange. Eine Reihe, die länger
    schweigt, bleibt leer."""
    reihe = sorted(minuten, key=lambda x: x.ts)
    grenze = timedelta(minutes=AUFFUELLEN_MIN + 1, seconds=30)
    nach: list[dict[str, float]] = [{} for _ in reihe]
    for name in _REIHEN:
        davor: tuple[datetime, float] | None = None
        offen: list[int] = []
        for i, m in enumerate(reihe):
            wert = getattr(m, name)
            if wert is None:
                offen.append(i)
                continue
            if davor is not None and offen and m.ts - davor[0] <= grenze:
                spanne = (m.ts - davor[0]).total_seconds()
                for j in offen:
                    anteil = (reihe[j].ts - davor[0]).total_seconds() / spanne
                    nach[j][name] = (
                        davor[1] if name in _ZUSTAENDE else davor[1] + (wert - davor[1]) * anteil
                    )
            davor = (m.ts, wert)
            offen = []
        if davor is not None:
            for j in offen:
                if reihe[j].ts - davor[0] <= grenze - timedelta(minutes=1):
                    nach[j][name] = davor[1]
    return [replace(m, **n) if n else m for m, n in zip(reihe, nach, strict=True)]


def heizt(m: Minute) -> bool:
    """Läuft der Verdichter im Heizbetrieb? Der Zustand der Maschine entscheidet, wo er da ist."""
    if m.modus is not None:
        return round(m.modus) in MODI_HEIZEN
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
    spreizung = m.vorlauf_c - m.ruecklauf_c
    if (
        m.durchfluss_l_min < MIN_DURCHFLUSS
        or spreizung < MIN_SPREIZUNG_K
        or m.strom_kw < MIN_LEISTUNG_KW
    ):
        return None
    return m.durchfluss_l_min * spreizung * KW_JE_L_MIN_K


def auswerten(minuten: Sequence[Minute]) -> tuple[list[Messpunkt], Bilanz]:
    """Die Messpunkte und die Bilanz der Minuten, aus denen sie entstanden oder nicht entstanden."""
    reihe = auffuellen(minuten)
    b = Bilanz(minuten=len(reihe), verhaeltnis=verhaeltnis_zaehler_maschine(reihe))
    fenster: dict[datetime, list[tuple[Minute, float]]] = {}
    laeuft_seit = 0
    davor: datetime | None = None
    for m in reihe:
        luecke = davor is not None and m.ts - davor > timedelta(minutes=1, seconds=30)
        davor = m.ts
        im_lauf = heizt(m)
        if im_lauf:
            b.heizen += 1
        if luecke or not im_lauf:
            # Eine Lücke in den Daten zählt wie ein Halt: was in ihr war, weiß niemand.
            laeuft_seit = 1 if im_lauf else 0
            if im_lauf:
                b.anlauf += 1
            continue
        laeuft_seit += 1
        if laeuft_seit <= ANLAUF_MIN:
            b.anlauf += 1
            continue
        if zusatz(m, b.verhaeltnis):
            b.zusatz += 1
            continue
        fehlend = [wort for name, wort in PFLICHT.items() if getattr(m, name) is None]
        if fehlend:
            b.ohne_wert += 1
            for wort in fehlend:
                b.fehlt[wort] = b.fehlt.get(wort, 0) + 1
            continue
        waerme = _waerme_kw(m)
        if waerme is None:
            b.ohne_waerme += 1
            continue
        b.gueltig += 1
        start = m.ts.replace(
            minute=m.ts.minute - m.ts.minute % FENSTER_MIN, second=0, microsecond=0
        )
        fenster.setdefault(start, []).append((m, waerme))

    punkte: list[Messpunkt] = []
    b.fenster = len(fenster)
    for start in sorted(fenster):
        teile = fenster[start]
        if len(teile) < FENSTER_GUELTIG_MIN:
            continue
        strom = sum(m.strom_kw or 0.0 for m, _ in teile)
        waerme = sum(w for _, w in teile)
        if strom <= 0:
            continue
        cop = waerme / strom
        if not COP_GRENZEN[0] <= cop <= COP_GRENZEN[1]:
            b.unglaubwuerdig += 1
            continue
        n = len(teile)
        stellungen = {None if m.ventil is None else round(m.ventil) for m, _ in teile}
        punkte.append(
            Messpunkt(
                ventil=stellungen.pop() if len(stellungen) == 1 else None,
                at=start,
                minuten=n,
                aussen_c=round(sum(m.aussen_c or 0.0 for m, _ in teile) / n, 2),
                vorlauf_c=round(sum(m.vorlauf_c or 0.0 for m, _ in teile) / n, 2),
                cop=round(cop, 3),
                waerme_kw=round(waerme / n, 3),
                strom_kw=round(strom / n, 3),
            )
        )
    b.punkte = len(punkte)
    return punkte, b


def messpunkte(minuten: Sequence[Minute]) -> list[Messpunkt]:
    """Die Fenster im eingeschwungenen Heizbetrieb, in zeitlicher Reihenfolge."""
    return auswerten(minuten)[0]


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
