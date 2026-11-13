"""Das Morning Briefing: was der Tag bringt, in vier kurzen Zeilen aufs Handy.

Die Startseite sagt das auch, aber dazu muss man sie öffnen. Das Briefing kommt von selbst, um
sieben, und sagt, was sich an diesem Tag zu wissen lohnt, bevor man das Haus verlässt:

    Morning Briefing
    ☀️ 12 kWh erwartet, im Wesentlichen zwischen 10:15 und 14:15 Uhr
    ⚡ Ø 28 ct, am günstigsten 13:00 bis 15:00 Uhr (19 ct)
    🔥 62 kWh Wärme: Wärmepumpe 5 h, Ofen 3 h
    💶 Wärme: 2,10 € Strom; 1,40 € Pellets

**Die Form ist ein Nutzerwunsch vom 13.11.2026.** Vorher hieß die Mitteilung „Heute im Haus" und
bestand aus drei ganzen Sätzen („Sonne: rund 12 kWh erwartet, am meisten von …"). Gewünscht:
der Titel „Morning Briefing", kürzere Texte, je Zeile ein Zeichen vorweg, bei der Sonne die
Menge mit dem Wort „erwartet" und der Zeitraum als „im Wesentlichen zwischen X und Y Uhr", beim
Strom eine Kennzahl des Preises, bei der Wärme eine kurze Kennzahl und darunter die erwarteten
Wärmekosten, geteilt in Strom und Pellets.

Was die Zeilen bedeuten:

- **Sonne.** Die erwartete Erzeugung im Rest des Tages. „Im Wesentlichen" ist die kürzeste
  zusammenhängende Zeit, in der vier Fünftel davon anfallen (`ANTEIL_WESENTLICH`).
- **Strom.** Der mittlere Preis im Rest des Tages und die günstigsten zwei Stunden am Stück,
  denn so lange läuft, was sich verschieben lässt. Liegen billigster und teuerster Preis
  weniger als vier Cent auseinander, gibt es kein Fenster.
- **Wärme.** Der Wärmebedarf (Heizen und Warmwasser), gegen den der Fahrplan rechnet, und wie
  lange Wärmepumpe und Ofen dafür laufen sollen.
- **Kosten.** Was der Fahrplan für diese Wärme ausgibt: Strom der Wärmepumpe und Pellets.

Alles gilt für den Rest des heutigen Tages, nicht für die nächsten 24 Stunden: „morgen 02:00"
ist morgens um sieben keine Auskunft für heute.

Reine Rechnung, kein I/O. Alltagssprache, ohne Wörter des Reglers.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta, tzinfo
from itertools import pairwise

TITEL = "Morning Briefing"
SCHRITT = timedelta(minutes=15)
#: Ein Fenster für alles, was warten kann: zwei Stunden.
FENSTER = 8
#: Unter dieser Spanne zwischen billigstem und teuerstem Preis lohnt kein Hinweis.
MIN_SPANNE_CT = 4.0
#: Unter so vielen Kilowattstunden am Tag heißt es „kaum Sonne".
WENIG_SONNE_KWH = 2.0
#: „Im Wesentlichen": die kürzeste Zeit, in der dieser Anteil der Sonnenenergie anfällt.
ANTEIL_WESENTLICH = 0.8


@dataclass(frozen=True)
class Viertel:
    """Eine Viertelstunde des Fahrplans, soweit das Briefing sie braucht.

    `None` heißt überall: dazu sagt der Fahrplan nichts. Das ist etwas anderes als null, und
    eine Zeile, deren Zahlen fehlen, steht nicht im Briefing.
    """

    ts: datetime
    preis_ct: float | None
    pv_kw: float
    #: Der Optimierer hat hier einen Lauf der Wärmepumpe geplant.
    wp: bool
    #: Soll der Ofen brennen? `None`: es gibt keinen Ofenfahrplan.
    ofen: bool | None = None
    #: Wärmebedarf aus Heizen und Warmwasser.
    waerme_kw: float | None = None
    #: Was der Fahrplan in dieser Viertelstunde für Wärme ausgibt.
    strom_eur: float | None = None
    pellet_eur: float | None = None


@dataclass(frozen=True)
class Brief:
    titel: str
    zeilen: tuple[str, ...]

    @property
    def text(self) -> str:
        return "\n".join(self.zeilen)


def _uhr(t: datetime, tz: tzinfo) -> str:
    return t.astimezone(tz).strftime("%H:%M")


def _euro(betrag: float) -> str:
    return f"{betrag:.2f}".replace(".", ",") + " €"


def _dauer(viertel: int) -> str:
    """„45 min", „5 h", „4:15 h"."""
    stunden, minuten = divmod(viertel * 15, 60)
    if stunden == 0:
        return f"{minuten} min"
    return f"{stunden} h" if minuten == 0 else f"{stunden}:{minuten:02d} h"


def _guenstigstes(reihe: Sequence[Viertel]) -> tuple[datetime, datetime, float] | None:
    """Die zwei Stunden am Stück mit dem kleinsten mittleren Preis. Lücken zählen nicht."""
    bestes: tuple[datetime, datetime, float] | None = None
    for i in range(len(reihe) - FENSTER + 1):
        stueck = reihe[i : i + FENSTER]
        preise = [v.preis_ct for v in stueck if v.preis_ct is not None]
        if len(preise) < FENSTER:
            continue
        if any(b.ts - a.ts != SCHRITT for a, b in pairwise(stueck)):
            continue
        mittel = sum(preise) / FENSTER
        if bestes is None or mittel < bestes[2]:
            bestes = (stueck[0].ts, stueck[-1].ts + SCHRITT, mittel)
    return bestes


def _im_wesentlichen(reihe: Sequence[Viertel]) -> tuple[datetime, datetime] | None:
    """Die kürzeste zusammenhängende Zeit, in der `ANTEIL_WESENTLICH` der Sonne anfällt.

    Bei gleicher Länge die mit der meisten Energie. Eine Lücke in der Reihe trennt: ein Fenster
    reicht nicht über sie hinweg.
    """
    ziel = sum(v.pv_kw for v in reihe) * ANTEIL_WESENTLICH
    if ziel <= 0:
        return None
    bestes: tuple[int, float, datetime, datetime] | None = None
    for i in range(len(reihe)):
        summe = 0.0
        for j in range(i, len(reihe)):
            if j > i and reihe[j].ts - reihe[j - 1].ts != SCHRITT:
                break
            summe += reihe[j].pv_kw
            if summe >= ziel:
                laenge = j - i + 1
                if bestes is None or (laenge, -summe) < (bestes[0], -bestes[1]):
                    bestes = (laenge, summe, reihe[i].ts, reihe[j].ts + SCHRITT)
                break
    return (bestes[2], bestes[3]) if bestes else None


def morgenbrief(
    viertel: Sequence[Viertel], *, jetzt: datetime, tz: tzinfo, hat_fahrplan: bool = True
) -> Brief | None:
    """Das Briefing für den Rest des heutigen Tages, oder `None`, wenn es nichts zu sagen gibt."""
    heute = jetzt.astimezone(tz).date()
    reihe = sorted(
        (v for v in viertel if v.ts + SCHRITT > jetzt and v.ts.astimezone(tz).date() == heute),
        key=lambda v: v.ts,
    )
    if len(reihe) < FENSTER:
        return None
    zeilen: list[str] = []

    # --- Sonne
    kwh = sum(v.pv_kw for v in reihe) * 0.25
    if kwh < WENIG_SONNE_KWH:
        zeilen.append("☀️ kaum Sonne erwartet")
    else:
        spanne = _im_wesentlichen(reihe)
        wann = (
            f", im Wesentlichen zwischen {_uhr(spanne[0], tz)} und {_uhr(spanne[1], tz)} Uhr"
            if spanne
            else ""
        )
        zeilen.append(f"☀️ {kwh:.0f} kWh erwartet{wann}")

    # --- Strompreis
    preise = [v.preis_ct for v in reihe if v.preis_ct is not None]
    if len(preise) >= FENSTER:
        mittel = sum(preise) / len(preise)
        guenstig = _guenstigstes(reihe) if max(preise) - min(preise) >= MIN_SPANNE_CT else None
        if guenstig:
            zeilen.append(
                f"⚡ Ø {mittel:.0f} ct, am günstigsten {_uhr(guenstig[0], tz)} bis "
                f"{_uhr(guenstig[1], tz)} Uhr ({guenstig[2]:.0f} ct)"
            )
        else:
            zeilen.append(f"⚡ Ø {mittel:.0f} ct, kaum Schwankung")

    # --- Wärme
    bedarf = [v.waerme_kw for v in reihe if v.waerme_kw is not None]
    wp = sum(1 for v in reihe if v.wp)
    ofen = sum(1 for v in reihe if v.ofen)
    teile: list[str] = []
    if hat_fahrplan:
        if wp:
            teile.append(f"Wärmepumpe {_dauer(wp)}")
        if ofen:
            teile.append(f"Ofen {_dauer(ofen)}")
    if bedarf:
        menge = f"🔥 {sum(bedarf) * 0.25:.0f} kWh Wärme"
        if teile:
            zeilen.append(f"{menge}: {', '.join(teile)}")
        elif hat_fahrplan:
            zeilen.append(f"{menge}, kein Lauf geplant")
        else:
            zeilen.append(menge)
    elif hat_fahrplan:
        zeilen.append(f"🔥 {', '.join(teile)}" if teile else "🔥 kein Lauf geplant")

    # --- Kosten der Wärme
    strom = [v.strom_eur for v in reihe if v.strom_eur is not None]
    pellets = [v.pellet_eur for v in reihe if v.pellet_eur is not None]
    if hat_fahrplan and strom:
        kosten = f"💶 Wärme: {_euro(sum(strom))} Strom"
        # Pellets nur, wo es einen Ofenfahrplan gibt. Dann aber auch mit null: „0,00 € Pellets"
        # ist die Auskunft, dass der Ofen heute aus bleibt.
        if pellets and any(v.ofen is not None for v in reihe):
            kosten += f"; {_euro(sum(pellets))} Pellets"
        zeilen.append(kosten)

    return Brief(titel=TITEL, zeilen=tuple(zeilen))
