"""Der Betrieb der Wärmepumpe über Tage: Läufe, Abtauen, Takten und die Heizkurve des Reglers.

Die Kennlinie (`kennlinie.py`) fragt, wie gut die Maschine im eingeschwungenen Heizbetrieb ist.
Dieses Modul fragt, was sie über den Tag tatsächlich tut:

**Läufe.** Ein Lauf reicht vom Anlaufen des Verdichters bis zu seinem Halt. Ein Abtauen mitten
darin beendet ihn nicht; es wird mitgezählt und für sich ausgewiesen. Viele kurze Läufe heißen
Takten: jeder Start kostet Anlauf, in dem die Arbeitszahl schlecht ist.

**Abtauen.** Die Maschine meldet es als eigenen Zustand (9). In diesen Minuten holt sie Wärme
aus dem Heizwasser zurück, um den Verdampfer zu enteisen: die Wärme der Minute ist negativ. Die
Arbeitszahl des Tages rechnet deshalb mit Vorzeichen und liegt unter der im reinen Heizbetrieb.

**Die Heizkurve des Reglers.** Der Regler gibt der Maschine einen Vorlauf-Sollwert vor, der von
der Außentemperatur abhängt. Über der Außentemperatur aufgetragen zeigt er die Kurve, die am
Gerät eingestellt ist, ohne dass jemand im Menü nachsehen muss.

Alles hier ist eine Auszählung gespeicherter Minuten. Die Grenzen dessen, was die Minuten
hergeben (Durchflussgeber nicht geeicht, Heizstab nur erschlossen), gelten wie in der Kennlinie.

Reine Rechnung, kein I/O.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, tzinfo

from hems_core.thermal import kennlinie as kl

#: Der Zustand der Maschine, in dem sie abtaut (`heat_pump_mode_code`).
MODUS_ABTAUEN = 9
#: Eine Lücke in den Daten, länger als das, beendet einen Lauf: was in ihr war, weiß niemand.
LUECKE = timedelta(minutes=1, seconds=30)
#: Die Klassen der Lauflängen in Minuten, obere Grenze ausgeschlossen. Gesetzt: unter zehn
#: Minuten ist ein Lauf kürzer als der Anlauf, den die Kennlinie verwirft.
KLASSEN: tuple[tuple[int, int | None], ...] = ((0, 10), (10, 20), (20, 40), (40, 90), (90, None))
#: Ab so vielen Kilowattstunden Strom am Tag gibt es eine Arbeitszahl des Tages.
MIN_STROM_KWH = 0.5
#: Eine Stunde zählt für die Heizkurve ab so vielen Minuten im Heizbetrieb.
MIN_STUNDE_MIN = 10
#: Die Gerade der Heizkurve gibt es ab so vielen Stunden und so viel Spanne draußen.
MIN_STUNDEN = 6
MIN_SPANNE_AUSSEN_K = 3.0


@dataclass(frozen=True)
class Lauf:
    """Ein Lauf des Verdichters, vom Anlaufen bis zum Halt."""

    start: datetime
    #: Minuten vom Start bis zum Halt, Abtauen eingeschlossen.
    minuten: int
    abtau_min: int
    #: Wie oft in diesem Lauf abgetaut wurde.
    abtauungen: int
    #: Minuten, in denen neben dem Verdichter etwas anderes Strom aufnahm (erschlossen).
    zusatz_min: int
    strom_kwh: float
    #: Wärme mit Vorzeichen, soweit sie sich rechnen ließ.
    waerme_kwh: float | None
    #: Der Lauf begann vor den Daten oder lief an ihrem Ende noch: seine Länge ist unvollständig.
    angeschnitten: bool


@dataclass
class Tag:
    """Ein Ortstag der Maschine."""

    tag: date
    starts: int = 0
    lauf_min: int = 0
    abtau_min: int = 0
    abtauungen: int = 0
    zusatz_min: int = 0
    strom_kwh: float = 0.0
    waerme_kwh: float | None = None
    #: Der Strom der Minuten im Lauf, für die sich eine Wärme rechnen ließ: der Nenner von
    #: `cop_tag`. Über mehrere Tage wird mit diesen Summen gerechnet, nicht mit dem Mittel.
    strom_lauf_kwh: float = 0.0
    #: Wärme durch Strom über alle Minuten, in denen die Maschine arbeitete, Abtauen und
    #: Heizstab eingeschlossen.
    cop_tag: float | None = None
    #: Dieselbe Zahl nur aus den Fenstern der Kennlinie: eingeschwungen, ohne Abtauen und Stab.
    cop_heizen: float | None = None
    #: Die mittlere Länge (Median) der Läufe, die an diesem Tag begannen und vollständig sind.
    lauf_median_min: float | None = None
    aussen_c: float | None = None
    #: Minuten im Lauf, für die sich eine Wärme rechnen ließ. Liegt das weit unter `lauf_min`,
    #: ist `cop_tag` aus einem Ausschnitt gerechnet.
    waerme_min: int = 0


@dataclass(frozen=True)
class Stunde:
    """Eine Stunde im Heizbetrieb, für die Heizkurve des Reglers."""

    at: datetime
    minuten: int
    aussen_c: float
    soll_c: float
    vorlauf_c: float | None
    #: Stellung des Umschaltventils, wenn sie in der Stunde einheitlich war.
    ventil: int | None


@dataclass(frozen=True)
class Gerade:
    """Sollwert = a + b * Außentemperatur, nach kleinsten Quadraten."""

    a: float
    b: float
    n: int
    r2: float | None
    aussen_von_c: float
    aussen_bis_c: float

    def soll(self, aussen_c: float) -> float:
        return self.a + self.b * aussen_c


@dataclass
class Betrieb:
    tage: list[Tag] = field(default_factory=list)
    laeufe: list[Lauf] = field(default_factory=list)
    stunden: list[Stunde] = field(default_factory=list)
    heizkurve: Gerade | None = None
    #: Zahl der vollständigen Läufe je Klasse aus `KLASSEN`.
    klassen: list[int] = field(default_factory=list)


def art(m: kl.Minute) -> str:
    """Was die Maschine in dieser Minute tut: `heizt`, `taut` oder `steht`."""
    if m.modus is not None and round(m.modus) == MODUS_ABTAUEN:
        return "taut"
    return "heizt" if kl.heizt(m) else "steht"


def waerme_kw(m: kl.Minute) -> float | None:
    """Die Wärmeleistung der Minute mit Vorzeichen. Beim Abtauen ist sie negativ: die Maschine
    holt Wärme aus dem Heizwasser. Ohne Durchfluss ist sie null, ohne Werte unbekannt."""
    if m.durchfluss_l_min is None:
        return None
    if m.durchfluss_l_min < kl.MIN_DURCHFLUSS:
        return 0.0
    if m.vorlauf_c is None or m.ruecklauf_c is None:
        return None
    return m.durchfluss_l_min * (m.vorlauf_c - m.ruecklauf_c) * kl.KW_JE_L_MIN_K


def _median(werte: Sequence[float]) -> float | None:
    if not werte:
        return None
    s = sorted(werte)
    mitte = len(s) // 2
    return s[mitte] if len(s) % 2 else (s[mitte - 1] + s[mitte]) / 2


def klasse(minuten: int) -> int:
    """Die Nummer der Klasse aus `KLASSEN`, in die eine Lauflänge fällt."""
    for i, (_, bis) in enumerate(KLASSEN):
        if bis is None or minuten < bis:
            return i
    return len(KLASSEN) - 1


def _gerade(stunden: Sequence[Stunde]) -> Gerade | None:
    n = len(stunden)
    if n < MIN_STUNDEN:
        return None
    xs = [s.aussen_c for s in stunden]
    ys = [s.soll_c for s in stunden]
    if max(xs) - min(xs) < MIN_SPANNE_AUSSEN_K:
        return None
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0:
        return None
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True)) / sxx
    a = my - b * mx
    syy = sum((y - my) ** 2 for y in ys)
    rest = sum((y - (a + b * x)) ** 2 for x, y in zip(xs, ys, strict=True))
    return Gerade(
        a=round(a, 3),
        b=round(b, 4),
        n=n,
        r2=round(1 - rest / syy, 3) if syy > 0 else None,
        aussen_von_c=round(min(xs), 1),
        aussen_bis_c=round(max(xs), 1),
    )


def auswerten(minuten: Sequence[kl.Minute], tz: tzinfo) -> Betrieb:
    """Tage, Läufe und Heizkurve aus den Minuten eines Zeitraums. `tz` bestimmt, wo ein Tag
    beginnt."""
    reihe = kl.auffuellen(minuten)
    verhaeltnis = kl.verhaeltnis_zaehler_maschine(reihe)
    punkte, _ = kl.auswerten(reihe)

    tage: dict[date, Tag] = {}
    aussen: dict[date, list[float]] = {}
    waerme_tag: dict[date, float] = {}
    strom_im_lauf: dict[date, float] = {}
    laeufe: list[Lauf] = []
    stunden: dict[datetime, list[kl.Minute]] = {}

    # Der laufende Lauf: Start, Minuten, Abtauminuten, Abtauungen, Zusatzminuten, Strom, Wärme,
    # ob eine Wärme fehlte, ob er angeschnitten ist.
    start: datetime | None = None
    lauf = [0, 0, 0, 0]
    lauf_strom = 0.0
    lauf_waerme = 0.0
    lauf_waerme_da = False
    angeschnitten = False
    taute = False
    davor: datetime | None = None

    def schliessen(am_ende: bool) -> None:
        nonlocal start
        if start is None:
            return
        laeufe.append(
            Lauf(
                start=start,
                minuten=lauf[0],
                abtau_min=lauf[1],
                abtauungen=lauf[2],
                zusatz_min=lauf[3],
                strom_kwh=round(lauf_strom, 3),
                waerme_kwh=round(lauf_waerme, 3) if lauf_waerme_da else None,
                angeschnitten=angeschnitten or am_ende,
            )
        )
        start = None

    for i, m in enumerate(reihe):
        ort = m.ts.astimezone(tz).date()
        tag = tage.setdefault(ort, Tag(tag=ort))
        if m.aussen_c is not None:
            aussen.setdefault(ort, []).append(m.aussen_c)
        if m.strom_kw is not None:
            tag.strom_kwh += m.strom_kw / 60.0
        luecke = davor is not None and m.ts - davor > LUECKE
        davor = m.ts
        was = art(m)
        if luecke:
            schliessen(am_ende=True)
        if was == "steht":
            schliessen(am_ende=False)
            taute = False
            continue
        if start is None:
            start = m.ts
            lauf = [0, 0, 0, 0]
            lauf_strom, lauf_waerme, lauf_waerme_da = 0.0, 0.0, False
            # Beginnt der Lauf mit der ersten Minute der Daten, lief er vielleicht schon vorher.
            angeschnitten = i == 0 or luecke
            taute = False
            tag.starts += 1
        lauf[0] += 1
        tag.lauf_min += 1
        if was == "taut":
            lauf[1] += 1
            tag.abtau_min += 1
            if not taute:
                lauf[2] += 1
                tag.abtauungen += 1
            taute = True
        else:
            taute = False
            if kl.zusatz(m, verhaeltnis):
                lauf[3] += 1
                tag.zusatz_min += 1
            if m.aussen_c is not None and m.vorlauf_soll_c is not None:
                stunde = m.ts.replace(minute=0, second=0, microsecond=0)
                stunden.setdefault(stunde, []).append(m)
        if m.strom_kw is not None:
            lauf_strom += m.strom_kw / 60.0
        w = waerme_kw(m)
        if w is not None and m.strom_kw is not None:
            lauf_waerme += w / 60.0
            lauf_waerme_da = True
            waerme_tag[ort] = waerme_tag.get(ort, 0.0) + w / 60.0
            strom_im_lauf[ort] = strom_im_lauf.get(ort, 0.0) + m.strom_kw / 60.0
            tag.waerme_min += 1
    schliessen(am_ende=True)

    # Die Arbeitszahl im reinen Heizbetrieb je Tag: aus den Fenstern der Kennlinie.
    heiz_waerme: dict[date, float] = {}
    heiz_strom: dict[date, float] = {}
    for p in punkte:
        ort = p.at.astimezone(tz).date()
        heiz_waerme[ort] = heiz_waerme.get(ort, 0.0) + p.waerme_kw * p.minuten
        heiz_strom[ort] = heiz_strom.get(ort, 0.0) + p.strom_kw * p.minuten

    klassen = [0] * len(KLASSEN)
    laengen: dict[date, list[float]] = {}
    for lf in laeufe:
        if lf.angeschnitten:
            continue
        klassen[klasse(lf.minuten)] += 1
        laengen.setdefault(lf.start.astimezone(tz).date(), []).append(float(lf.minuten))

    for ort, tag in tage.items():
        tag.strom_kwh = round(tag.strom_kwh, 2)
        if ort in aussen:
            tag.aussen_c = round(sum(aussen[ort]) / len(aussen[ort]), 1)
        if ort in waerme_tag:
            tag.waerme_kwh = round(waerme_tag[ort], 2)
            tag.strom_lauf_kwh = round(strom_im_lauf.get(ort, 0.0), 2)
            if strom_im_lauf.get(ort, 0.0) >= MIN_STROM_KWH:
                tag.cop_tag = round(waerme_tag[ort] / strom_im_lauf[ort], 2)
        if heiz_strom.get(ort, 0.0) > 0:
            tag.cop_heizen = round(heiz_waerme[ort] / heiz_strom[ort], 2)
        tag.lauf_median_min = _median(laengen.get(ort, []))

    kurve: list[Stunde] = []
    for at in sorted(stunden):
        teile = stunden[at]
        if len(teile) < MIN_STUNDE_MIN:
            continue
        vorlaeufe = [m.vorlauf_c for m in teile if m.vorlauf_c is not None]
        stellungen = {None if m.ventil is None else round(m.ventil) for m in teile}
        kurve.append(
            Stunde(
                at=at,
                minuten=len(teile),
                aussen_c=round(sum(m.aussen_c or 0.0 for m in teile) / len(teile), 2),
                soll_c=round(sum(m.vorlauf_soll_c or 0.0 for m in teile) / len(teile), 2),
                vorlauf_c=round(sum(vorlaeufe) / len(vorlaeufe), 2) if vorlaeufe else None,
                ventil=stellungen.pop() if len(stellungen) == 1 else None,
            )
        )

    return Betrieb(
        tage=[tage[t] for t in sorted(tage)],
        laeufe=laeufe,
        stunden=kurve,
        heizkurve=_gerade(kurve),
        klassen=klassen,
    )
