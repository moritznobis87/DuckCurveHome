"""Sonnenaufgang und Sonnenuntergang am Standort, gerechnet aus Datum und Ort.

**Warum es das gibt.** Die Startseite zeichnet die Sonne auf einem Bogen vom Aufgang zum Untergang.
Bis zum 26.11.2026 nahm sie als Enden dieses Bogens die erste und die letzte Viertelstunde, in der
die Ertragsprognose mehr als 50 Watt kannte. Das ist der Beginn der Erzeugung und nicht der
Sonnenaufgang: An jenem Tag stand an den Enden 08:45 und 16:45, die Sonne ging aber um 08:09 auf
und um 16:36 unter, und um 09:17 saß sie im Bild noch am Horizont (Hausherr: „Es passt doch
nicht“). Wann die Sonne aufgeht, hängt weder an der Anlage noch am Wetter, also wird es hier
gerechnet und im Fahrplan mitgegeben.

**Das Verfahren** ist das der NOAA nach Meeus: mittlere Länge und Anomalie der Sonne, daraus
Deklination und Zeitgleichung, daraus der Stundenwinkel, bei dem der obere Sonnenrand am Horizont
steht. Dafür gilt die übliche Höhe von −0,833 Grad: 16 Bogenminuten für den halben Sonnendurchmesser
und 34 für die Brechung in der Luft. Gegen veröffentlichte Zeiten stimmt das auf die Minute, siehe
`test_sonne.py`. Die Höhe des Ortes über dem Meer geht nicht ein: Auf dem Land liegt der Horizont
so hoch wie das Haus.

**Nicht dasselbe wie `pv_simple.solar_elevation_deg`.** Die Ertragsprognose rechnet den Sonnenstand
mit einer einfacheren Formel ohne Zeitgleichung. Ihr Sonnenmittag liegt damit Ende November knapp
dreizehn Minuten zu spät und Mitte Februar gut vierzehn zu früh. Das ist ein eigener Fehler; er ist
in `docs/design/werkstatt/startseite/bau.md` unter „Der Sonnenstand“ als offen vermerkt.
"""

from __future__ import annotations

import math
from datetime import UTC, date, datetime, timedelta

from hems_core.forecasting.models import GeoPoint, SunEvent

#: Die Höhe der Sonnenmitte, bei der der obere Rand am Horizont erscheint, in Grad.
HORIZONT_GRAD = -0.833

#: Der Tag Null des julianischen Datums gegen `date.toordinal()`, zur Mitternacht in Weltzeit.
_JD_VERSATZ = 1721424.5


def _deklination_und_zeitgleichung(jd: float) -> tuple[float, float]:
    """Deklination der Sonne im Bogenmaß und Zeitgleichung in Minuten zum julianischen Datum."""
    t = (jd - 2451545.0) / 36525.0
    laenge = math.radians((280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0)
    anomalie = math.radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
    exzentrizitaet = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    mittelpunkt = (
        math.sin(anomalie) * (1.914602 - t * (0.004817 + 0.000014 * t))
        + math.sin(2 * anomalie) * (0.019993 - 0.000101 * t)
        + math.sin(3 * anomalie) * 0.000289
    )
    knoten = math.radians(125.04 - 1934.136 * t)
    scheinbar = math.radians(
        math.degrees(laenge) + mittelpunkt - 0.00569 - 0.00478 * math.sin(knoten)
    )
    schiefe_mittel = (
        23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
    )
    schiefe = math.radians(schiefe_mittel + 0.00256 * math.cos(knoten))
    deklination = math.asin(math.sin(schiefe) * math.sin(scheinbar))
    y = math.tan(schiefe / 2) ** 2
    zeitgleichung = 4.0 * math.degrees(
        y * math.sin(2 * laenge)
        - 2 * exzentrizitaet * math.sin(anomalie)
        + 4 * exzentrizitaet * y * math.sin(anomalie) * math.cos(2 * laenge)
        - 0.5 * y * y * math.sin(4 * laenge)
        - 1.25 * exzentrizitaet * exzentrizitaet * math.sin(2 * anomalie)
    )
    return deklination, zeitgleichung


def sonnenzeiten(tag: date, ort: GeoPoint) -> SunEvent | None:
    """Aufgang und Untergang der Sonne am Kalendertag `tag` am Ort, in Weltzeit.

    `tag` ist der Tag am Ort: gerechnet wird um den Sonnenmittag dieses Tages auf dem Längengrad
    des Ortes. `None`, wenn die Sonne an diesem Tag nicht auf- oder nicht untergeht, also in der
    Polarnacht und am Polartag.
    """
    mitternacht = datetime(tag.year, tag.month, tag.day, tzinfo=UTC)
    breite = math.radians(ort.latitude)
    zeiten: list[datetime] = []
    for richtung in (-1.0, 1.0):
        # Deklination und Zeitgleichung ändern sich über den Tag. Dreimal nachgerechnet am
        # gefundenen Zeitpunkt, liegt das Ergebnis unter einer Sekunde am Festpunkt.
        minuten = 720.0 - 4.0 * ort.longitude
        for _ in range(3):
            jd = tag.toordinal() + _JD_VERSATZ + minuten / 1440.0
            deklination, zeitgleichung = _deklination_und_zeitgleichung(jd)
            cos_winkel = math.sin(math.radians(HORIZONT_GRAD)) / (
                math.cos(breite) * math.cos(deklination)
            ) - math.tan(breite) * math.tan(deklination)
            if not -1.0 <= cos_winkel <= 1.0:
                return None
            stundenwinkel = math.degrees(math.acos(cos_winkel))
            minuten = 720.0 - 4.0 * ort.longitude - zeitgleichung + richtung * 4.0 * stundenwinkel
        zeiten.append(mitternacht + timedelta(minutes=minuten))
    return SunEvent(day=tag, sunrise=zeiten[0], sunset=zeiten[1])
