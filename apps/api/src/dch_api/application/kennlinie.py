"""Die gemessene Kennlinie der Wärmepumpe als Antwort des Dienstes.

Die Rechnung steht im Kern (`hems_core.thermal.kennlinie`): Messpunkte aus Minutenwerten,
Ausgleich nach kleinsten Quadraten. Hier wird aus den gespeicherten Minuten die Eingabe und aus
dem Ergebnis die Antwort, mit den Sätzen, die sagen, was sie taugt.

Reine Zusammensetzung, kein I/O.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from datetime import datetime, timedelta

from dch_api.schemas import (
    KennlinienAnnahmeOut,
    KennlinienFitOut,
    KennlinienPunktOut,
    KennlinieOut,
)
from hems_core.domain.config import BufferConfig, HeatDemandConfig
from hems_core.thermal import kennlinie as kern

#: Die Minutenreihen, aus denen ein Messpunkt entsteht, und ihr Feld in `kern.Minute`.
REIHEN: dict[str, str] = {
    "outdoor_temp_c": "aussen_c",
    "flow_temp_c": "vorlauf_c",
    "heat_pump_return_temp_c": "ruecklauf_c",
    "heat_pump_flow_l_min": "durchfluss_l_min",
    "heat_pump_power_kw": "strom_kw",
    "heat_pump_mode_code": "modus",
    "heat_pump_compressor_hz": "hz",
    "heat_pump_bus_power_kw": "strom_maschine_kw",
}
TAGE_STANDARD = 30
TAGE_HOECHSTENS = 180


def de(zahl: float, stellen: int = 2) -> str:
    return f"{zahl:.{stellen}f}".replace(".", ",")


def minuten(zeilen: Sequence[dict[str, float | str | None]]) -> list[kern.Minute]:
    """Die gespeicherten Minutenzeilen als Eingabe der Rechnung."""
    aus: list[kern.Minute] = []
    for zeile in zeilen:
        ts = zeile.get("ts")
        if not isinstance(ts, str):
            continue
        werte: dict[str, float | None] = {}
        for reihe, feld in REIHEN.items():
            v = zeile.get(reihe)
            werte[feld] = float(v) if isinstance(v, int | float) and math.isfinite(v) else None
        aus.append(kern.Minute(ts=datetime.fromisoformat(ts), **werte))
    return aus


def formel(f: kern.Ausgleich) -> str:
    """Die Ausgleichsfläche als Satz, mit deutschen Zahlen und nur den Termen, die es gibt."""
    teile = [f"COP = {de(f.a)}"]
    if f.art in ("ebene", "aussen"):
        teile.append(
            f"{'+' if f.b_aussen >= 0 else '-'} {de(abs(f.b_aussen), 3)} × Außentemperatur"
        )
    if f.art in ("ebene", "vorlauf"):
        teile.append(f"{'+' if f.c_vorlauf >= 0 else '-'} {de(abs(f.c_vorlauf), 3)} × Vorlauf")
    return " ".join(teile)


def geltung(f: kern.Ausgleich) -> str:
    return (
        f"Gemessen zwischen {de(f.aussen_von_c, 1)} und {de(f.aussen_bis_c, 1)} °C draußen und "
        f"zwischen {de(f.vorlauf_von_c, 1)} und {de(f.vorlauf_bis_c, 1)} °C Vorlauf. Außerhalb "
        "davon ist die Formel eine Verlängerung, keine Messung."
    )


def fehlt(punkte: Sequence[kern.Messpunkt], f: kern.Ausgleich | None) -> str | None:
    """Was dem Ausgleich noch fehlt: Punkte, oder Streuung in einer der beiden Temperaturen."""
    n = len(punkte)
    if n == 0:
        return (
            "Noch kein Messpunkt. Einer entsteht, wenn die Wärmepumpe zwanzig Minuten am Stück "
            "heizt: zehn Minuten Anlauf, dann ein Fenster von zehn Minuten."
        )
    if f is None:
        return (
            f"{n} von {kern.MIN_PUNKTE} Messpunkten, ab denen ausgeglichen wird. Bis dahin "
            "bestimmt der Zufall das Ergebnis."
        )
    spanne_a = f.aussen_bis_c - f.aussen_von_c
    spanne_v = f.vorlauf_bis_c - f.vorlauf_von_c
    if f.art == "mittel":
        return (
            "Die Punkte liegen bei fast derselben Außen- und Vorlauftemperatur "
            f"({de(spanne_a, 1)} und {de(spanne_v, 1)} Grad Spanne). Bestimmen lässt sich daraus "
            "nur der Mittelwert; für eine Steigung braucht es anderes Wetter und andere Vorläufe."
        )
    if f.art == "vorlauf":
        return (
            f"Draußen lagen die Punkte nur {de(spanne_a, 1)} Grad auseinander (nötig: "
            f"{de(kern.MIN_SPANNE_AUSSEN_K, 0)}). Der Einfluss der Außentemperatur ist deshalb noch "
            "nicht bestimmt; er kommt mit kälteren und wärmeren Tagen."
        )
    if f.art == "aussen":
        if spanne_v < kern.MIN_SPANNE_VORLAUF_K:
            return (
                f"Der Vorlauf lag nur {de(spanne_v, 1)} Grad auseinander (nötig: "
                f"{de(kern.MIN_SPANNE_VORLAUF_K, 0)}). Sein Einfluss ist deshalb noch nicht bestimmt."
            )
        return (
            "Vorlauf und Außentemperatur änderten sich bisher im Gleichschritt. Ihre Einflüsse "
            "lassen sich daraus nicht trennen; die Steigung über der Außentemperatur enthält "
            "beide."
        )
    return None


def zusammensetzen(
    *,
    now: datetime,
    tage: int,
    punkte: Sequence[kern.Messpunkt],
    heat: HeatDemandConfig,
    buffer: BufferConfig,
    vorfuehrung: bool = False,
    zusatz_min: int = 0,
) -> KennlinieOut:
    f = kern.ausgleich(punkte)
    hinweise = [
        "Jeder Punkt ist ein Fenster von zehn Minuten im Heizbetrieb, frühestens zehn Minuten "
        "nach dem Start. Abtauen zählt nicht mit: das ist die Arbeitszahl im Heizbetrieb, nicht "
        "die eines Tages.",
        "Wärme aus Durchfluss mal Spreizung, Strom vom Zähler an der Zuleitung. Der "
        "Durchflussgeber ist nicht geeicht und die Zuordnung des Rücklaufs nicht bestätigt; ein "
        "Fehler dort verschiebt alle Punkte gemeinsam, die Form der Kennlinie bleibt.",
    ]
    if zusatz_min:
        hinweise.append(
            f"{zusatz_min} Minuten zählen nicht mit, weil der Zähler dort mindestens "
            f"{de(kern.ZUSATZ_KW, 1)} kW mehr aufnahm, als die Maschine für sich meldet: neben "
            "dem Verdichter lief etwas anderes, vermutlich der elektrische Heizstab."
        )
    if vorfuehrung:
        hinweise.insert(
            0, "Vorführung: die Punkte sind aus dem Modellhaus erzeugt, nicht gemessen."
        )
    return KennlinieOut(
        now=now,
        von=now - timedelta(days=tage),
        bis=now,
        tage=tage,
        punkte=[KennlinienPunktOut(**p.__dict__) for p in punkte],
        fit=None
        if f is None
        else KennlinienFitOut(**f.__dict__, formel_de=formel(f), geltung_de=geltung(f)),
        fehlt_de=fehlt(punkte, f),
        annahme=[
            KennlinienAnnahmeOut(aussen_c=t, cop=c)
            for t, c in sorted(heat.cop_curve, key=lambda p: p[0])
        ],
        annahme_vorlauf_c=buffer.target_temperature_c,
        hinweise_de=hinweise,
    )


def vorfuehrung(now: datetime, tage: int) -> list[kern.Messpunkt]:
    """Messpunkte für die Vorführung: eine Maschine mit bekannter Kennlinie und etwas Streuung.

    Die Vorführung hat keinen Bus und keine Minutenreihen der Maschine. Damit die Seite dort zu
    sehen ist, entstehen die Punkte aus einer festen Formel (COP = 6,4 + 0,09 * außen - 0,065 *
    Vorlauf) mit einer Streuung, die sich aus der Nummer des Punkts ergibt: bei jedem Aufruf
    dieselbe.
    """
    punkte: list[kern.Messpunkt] = []
    start = (now - timedelta(days=min(tage, 45))).replace(minute=0, second=0, microsecond=0)
    for i in range(min(tage, 45) * 4):
        at = start + timedelta(hours=6 * i)
        # Wetter über die Wochen, Tagesgang, und ein Vorlauf, der mit der Ladung steigt.
        aussen = 4.0 + 7.0 * math.sin(i / 23.0) + 3.0 * math.sin(i * math.pi / 2.0 + 0.6)
        vorlauf = 33.0 + (i * 7 % 23)
        rauschen = ((i * 37) % 17 - 8) / 8.0 * 0.22
        cop = 6.4 + 0.09 * aussen - 0.065 * vorlauf + rauschen
        strom = 1.4 + (i * 5 % 9) / 6.0
        punkte.append(
            kern.Messpunkt(
                at=at,
                minuten=kern.FENSTER_MIN,
                aussen_c=round(aussen, 2),
                vorlauf_c=round(vorlauf, 2),
                cop=round(cop, 3),
                waerme_kw=round(cop * strom, 3),
                strom_kw=round(strom, 3),
            )
        )
    return punkte
