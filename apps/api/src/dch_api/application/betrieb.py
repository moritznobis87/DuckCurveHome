"""Der Betrieb der Wärmepumpe über Tage als Antwort des Dienstes.

Die Rechnung steht im Kern (`hems_core.thermal.betrieb`): Läufe, Abtauen, Lauflängen und die
Heizkurve des Reglers aus den gespeicherten Minuten. Hier wird aus den Minuten die Eingabe und
aus dem Ergebnis die Antwort, mit den Sätzen, die sagen, was die Auszählung zeigt.

Reine Zusammensetzung, kein I/O.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from datetime import datetime, timedelta, tzinfo

from dch_api.application import kennlinie as kennlinie_logic
from dch_api.application.kennlinie import de
from dch_api.schemas import (
    BetriebHeizkurveOut,
    BetriebKlasseOut,
    BetriebLaufOut,
    BetriebOut,
    BetriebStundeOut,
    BetriebTagOut,
)
from hems_core.thermal import betrieb as kern
from hems_core.thermal import kennlinie as kl

#: Die Minutenreihen der Auszählung: die der Kennlinie und der Vorlauf-Sollwert des Reglers.
REIHEN: dict[str, str] = {
    **kennlinie_logic.REIHEN,
    "heat_pump_flow_setpoint_c": "vorlauf_soll_c",
}
TAGE_STANDARD = 14
TAGE_HOECHSTENS = 90
#: So viele Läufe stehen höchstens in der Antwort (die jüngsten).
LAEUFE_HOECHSTENS = 300


def minuten(zeilen: Sequence[dict[str, float | str | None]]) -> list[kl.Minute]:
    return kennlinie_logic.minuten(zeilen, REIHEN)


def _mal(n: int) -> str:
    return "einmal" if n == 1 else f"{n}-mal"


def _dauer(minuten_: int) -> str:
    if minuten_ < 60:
        return f"{minuten_} Minuten" if minuten_ != 1 else "1 Minute"
    stunden, rest = divmod(minuten_, 60)
    return f"{stunden} h {rest} min" if rest else f"{stunden} h"


def formel(g: kern.Gerade) -> str:
    return f"Sollwert = {de(g.a, 1)} {'+' if g.b >= 0 else '-'} {de(abs(g.b), 2)} × Außentemperatur"


def saetze(b: kern.Betrieb, zeitraum_tage: int) -> list[str]:
    """Was die Auszählung zeigt, je Thema ein Satz. Leer, wenn die Maschine nicht lief."""
    lauf = sum(t.lauf_min for t in b.tage)
    if lauf == 0:
        return ["In diesem Zeitraum ist nach den gespeicherten Werten kein Lauf der Wärmepumpe."]
    starts = sum(t.starts for t in b.tage)
    tage_mit = sum(1 for t in b.tage if t.lauf_min) or 1
    ganze = [lf for lf in b.laeufe if not lf.angeschnitten]
    aus = []
    satz = (
        f"Die Wärmepumpe lief {_dauer(lauf)} in "
        f"{'einem Lauf' if starts == 1 else f'{starts} Läufen'}, an Tagen mit Betrieb im Mittel "
        f"{de(starts / tage_mit, 1)} Starts."
    )
    if ganze:
        median = kern._median([float(lf.minuten) for lf in ganze])
        kurz = b.klassen[0] if b.klassen else 0
        satz += f" Ein Lauf dauerte im Mittel {_dauer(round(median or 0))}"
        satz += (
            f"; {kurz} von {len(ganze)} waren kürzer als zehn Minuten."
            if kurz
            else "; keiner war kürzer als zehn Minuten."
        )
    aus.append(satz)
    abtau = sum(t.abtau_min for t in b.tage)
    abtauungen = sum(t.abtauungen for t in b.tage)
    if abtauungen:
        aus.append(
            f"Abgetaut wurde {_mal(abtauungen)}, zusammen {_dauer(abtau)}: "
            f"{de(100 * abtau / lauf, 1)} % der Laufzeit."
        )
    else:
        aus.append(
            "Ein Abtauen hat die Maschine in diesem Zeitraum nicht gemeldet. Sie meldet es als "
            "eigenen Zustand; kommt der Zustand selten über den Bus, kann ein kurzes Abtauen fehlen."
        )
    waerme = sum(t.waerme_kwh or 0.0 for t in b.tage if t.strom_lauf_kwh > 0)
    strom = sum(t.strom_lauf_kwh for t in b.tage)
    heizen = cop_heizen(b)
    if strom >= kern.MIN_STROM_KWH:
        satz = f"Über alles gerechnet wurden aus {de(strom, 1)} kWh Strom {de(waerme, 1)} kWh Wärme"
        satz += f": Arbeitszahl {de(waerme / strom, 2)}."
        if heizen is not None:
            satz += f" Im eingeschwungenen Heizbetrieb allein waren es {de(heizen, 2)}."
        aus.append(satz)
    zusatz = sum(t.zusatz_min for t in b.tage)
    if zusatz:
        aus.append(
            f"In {_dauer(zusatz)} nahm neben dem Verdichter etwas anderes Strom auf, vermutlich "
            "der elektrische Heizstab."
        )
    if b.heizkurve is not None:
        g = b.heizkurve
        aus.append(
            f"Der Regler verlangt bei 0 °C draußen rund {de(g.soll(0.0), 0)} °C Vorlauf und bei "
            f"10 °C rund {de(g.soll(10.0), 0)} °C (aus {g.n} Stunden zwischen "
            f"{de(g.aussen_von_c, 0)} und {de(g.aussen_bis_c, 0)} °C)."
        )
    return aus


def cop_heizen(b: kern.Betrieb) -> float | None:
    """Die Arbeitszahl im eingeschwungenen Heizbetrieb über den Zeitraum: das Mittel der Tage,
    gewichtet mit ihrem Strom. Genauer als das einfache Mittel, einfacher als alle Fenster."""
    tage = [t for t in b.tage if t.cop_heizen is not None and t.strom_lauf_kwh > 0]
    strom = sum(t.strom_lauf_kwh for t in tage)
    if strom <= 0:
        return None
    return round(sum((t.cop_heizen or 0.0) * t.strom_lauf_kwh for t in tage) / strom, 2)


def zusammensetzen(
    *, now: datetime, tage: int, betrieb: kern.Betrieb, vorfuehrung: bool = False
) -> BetriebOut:
    hinweise = [
        "Ein Lauf reicht vom Anlaufen des Verdichters bis zu seinem Halt; ein Abtauen mitten "
        "darin beendet ihn nicht. Läufe am Rand der Daten oder an einer Lücke zählen nicht zu "
        "den Lauflängen.",
        "Beim Abtauen holt die Maschine Wärme aus dem Heizwasser zurück: diese Minuten zählen "
        "mit negativem Vorzeichen. Die Arbeitszahl über alles enthält sie, dazu jeden Anlauf "
        "und den Heizstab; die im Heizbetrieb zählt nur eingeschwungene Fenster ohne das alles.",
        "Wärme aus Durchfluss mal Spreizung, Strom vom Zähler an der Zuleitung. Der "
        "Durchflussgeber ist nicht geeicht; der Heizstab ist aus der Leistung erschlossen, "
        "nicht gelesen.",
    ]
    if vorfuehrung:
        hinweise.insert(0, "Vorführung: die Minuten sind erzeugt, nicht gemessen.")
    strom = sum(t.strom_lauf_kwh for t in betrieb.tage)
    waerme = sum(t.waerme_kwh or 0.0 for t in betrieb.tage if t.strom_lauf_kwh > 0)
    ganze = [float(lf.minuten) for lf in betrieb.laeufe if not lf.angeschnitten]
    g = betrieb.heizkurve
    return BetriebOut(
        now=now,
        von=now - timedelta(days=tage),
        bis=now,
        zeitraum_tage=tage,
        tage=[BetriebTagOut(**t.__dict__) for t in betrieb.tage],
        laeufe=[BetriebLaufOut(**lf.__dict__) for lf in betrieb.laeufe[-LAEUFE_HOECHSTENS:]],
        stunden=[BetriebStundeOut(**s.__dict__) for s in betrieb.stunden],
        heizkurve=None if g is None else BetriebHeizkurveOut(**g.__dict__, formel_de=formel(g)),
        klassen=[
            BetriebKlasseOut(von_min=von, bis_min=bis, laeufe=n)
            for (von, bis), n in zip(kern.KLASSEN, betrieb.klassen, strict=True)
        ],
        starts=sum(t.starts for t in betrieb.tage),
        lauf_min=sum(t.lauf_min for t in betrieb.tage),
        abtau_min=sum(t.abtau_min for t in betrieb.tage),
        abtauungen=sum(t.abtauungen for t in betrieb.tage),
        zusatz_min=sum(t.zusatz_min for t in betrieb.tage),
        cop_gesamt=round(waerme / strom, 2) if strom >= kern.MIN_STROM_KWH else None,
        cop_heizen=cop_heizen(betrieb),
        lauf_median_min=kern._median(ganze),
        saetze_de=saetze(betrieb, tage),
        hinweise_de=hinweise,
    )


def vorfuehrung(now: datetime, tage: int, tz: tzinfo) -> list[kl.Minute]:
    """Minuten für die Vorführung: eine Maschine, die taktet, bei Kälte abtaut und einmal den
    Heizstab braucht.

    Die Vorführung hat keinen Bus. Damit die Seite dort zu sehen ist, entstehen die Minuten aus
    festen Regeln, bei jedem Aufruf dieselben: das Wetter schwingt über die Tage und den Tag,
    der Regler verlangt 35,7 Grad Vorlauf bei null Grad und je Grad wärmer 0,7 Grad weniger
    (das ist die Heizkurve der Seite „Regler“: Raum 21 Grad, Steilheit 0,7, keine Verschiebung), die
    Maschine läuft morgens und abends lang und taktet am Nachmittag, taut unter drei Grad alle
    fünfzig Minuten ab, und an einem kalten Morgen läuft zwanzig Minuten der Heizstab mit. In
    den ersten Minuten eines Laufs kommt erst ein Teil der Wärme an: so kostet das Takten in
    der Vorführung, was es auch an einer echten Maschine kostet.
    """
    n = min(tage, 30)
    start = (
        (now - timedelta(days=n)).astimezone(tz).replace(hour=0, minute=0, second=0, microsecond=0)
    )
    aus: list[kl.Minute] = []
    seit_abtauen = 0
    seit_start = 0
    for i in range(n * 1440):
        ts = start + timedelta(minutes=i)
        if ts > now:
            break
        tag, im_tag = divmod(i, 1440)
        stunde = im_tag / 60.0
        aussen = 4.0 + 5.0 * math.sin(tag / 4.0) + 3.5 * math.sin((stunde - 9.0) * math.pi / 12.0)
        soll = 35.7 - 0.7 * aussen
        # Morgens und abends ein langer Lauf, am Nachmittag kurze Takte, nachts Ruhe.
        if 5.0 <= stunde < 8.5 or 17.0 <= stunde < 20.5:
            laeuft = True
        elif 12.0 <= stunde < 16.0:
            laeuft = im_tag % (27 if tag % 3 else 16) < (13 if tag % 3 else 7)
        else:
            laeuft = False
        if not laeuft:
            seit_abtauen = 0
            seit_start = 0
            aus.append(
                kl.Minute(
                    ts=ts,
                    aussen_c=round(aussen, 2),
                    vorlauf_c=30.0,
                    ruecklauf_c=29.5,
                    durchfluss_l_min=0.0,
                    strom_kw=0.02,
                    modus=15.0,
                    hz=0.0,
                    strom_maschine_kw=0.0,
                    ventil=1.0,
                    vorlauf_soll_c=round(soll, 1),
                )
            )
            continue
        seit_abtauen += 1
        seit_start += 1
        taut = aussen < 3.0 and seit_abtauen > 50
        if taut and seit_abtauen > 54:
            seit_abtauen = 0
        vorlauf = soll - 3.0 + (im_tag % 7) * 0.2
        # Der Anlauf: in der ersten Minute kommt ein Drittel der Wärme an, nach acht alles.
        cop = (6.4 + 0.09 * aussen - 0.065 * vorlauf) * min(1.0, 0.3 + 0.1 * seit_start)
        strom = 2.4 + 0.3 * math.sin(i / 11.0)
        spreizung = cop * strom / (29.5 * kl.KW_JE_L_MIN_K)
        stab = tag == n - 3 and 5.5 <= stunde < 5.84
        aus.append(
            kl.Minute(
                ts=ts,
                aussen_c=round(aussen, 2),
                vorlauf_c=round(vorlauf - 6.0 if taut else vorlauf, 2),
                ruecklauf_c=round(vorlauf - 3.0 if taut else vorlauf - spreizung, 2),
                durchfluss_l_min=29.5,
                strom_kw=round(1.6 if taut else strom + (6.0 if stab else 0.0), 3),
                modus=9.0 if taut else 3.0,
                hz=40.0 if taut else 62.0,
                strom_maschine_kw=round((1.6 if taut else strom) * 0.97, 3),
                ventil=1.0,
                vorlauf_soll_c=round(soll, 1),
            )
        )
    return aus
