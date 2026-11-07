"""Prognoseläufe aufbewahren: was ein Lauf ist, wann er einer ist, und welcher für immer bleibt.

**Das Problem.** Die Wettervorhersage liegt im Arbeitsspeicher des `ForecastService` und ist nach
dem nächsten Abruf weg. Die PV-Läufe hält der `ForecastEvaluator` 60 Stunden. Die Tabellen
`forecast_runs` und `forecast_points` liegen seit der Grundmigration vom 04.09.2026 da, mit `kind`
für weather, pv und price, und kein Anwendungscode hat sie je beschrieben.

Daraus folgt der Satz, der diese Datei begründet: **die Nachbetrachtung ist für die Vergangenheit
nicht nachholbar.** Die Frage „was hätte die ursprüngliche Prognose gekostet" braucht die
ursprüngliche Prognose, und die gibt es für keinen Tag vor dieser Datei. Jeder Tag ohne Ablage ist
ein dauerhaft verlorener Lerntag. Das ist der Grund, warum die Ablage vor allem anderen am Zwilling
steht und nicht hinten in der Reihenfolge.

**Was ein Lauf ist.** Ein Abruf mit neuem Inhalt, nicht jedes Speichern. Liefert der Anbieter
dieselben Zahlen wie beim letzten Mal, ist das kein neuer Lauf, sondern eine Wiederholung. Das
entscheidet der Fingerabdruck, und er zählt den **Inhalt**, nicht die Erstellungszeit: sonst wäre
jeder Lauf neu und der Filter wirkungslos. Dasselbe Prinzip wie der Wiederholungsfilter des
Live-Stroms in `dch_api.application.live_feed.kern`.

Das wirkt vor allem bei den Preisen. Tibber wird alle 30 Minuten abgefragt, zwischen 13 und 15 Uhr
noch häufiger, aber die veröffentlichten Preise ändern sich einmal am Tag. Ohne Filter lägen 48
nahezu gleiche Läufe am Tag in der Tabelle; mit ihm bleiben die wenigen, in denen wirklich etwas
Neues stand. Bei der PV-Prognose greift er kaum, weil ihr Raster mit jeder Auffrischung eine Stunde
weiterwandert, und das ist richtig so: ein verschobener Horizont ist neuer Inhalt.

**Was bleibt.** Alle Läufe 30 Tage, dazu ein kanonischer Day-ahead-Lauf je Ortstag für immer. Die
30 Tage reichen, um die rollierende Verbesserung anzusehen, also die Frage, wie viel besser die
Prognose wird, je näher die Lieferung kommt. Der kanonische Lauf ist der Lernbestand und wird nicht
gelöscht.

Kanonisch ist der **letzte Lauf, der zur kanonischen Stunde noch gültig war**, also der jüngste,
der an oder vor dieser Stunde erstellt wurde. Das ist derselbe Begriff, den
`dch_api.application.forecast_evaluation` für seine Tageswertung benutzt, und die beiden sollen
nicht auseinanderlaufen. Gab es an einem Tag keinen Lauf vor dieser Stunde, etwa weil der Dienst
später gestartet ist, bleibt der früheste des Tages: sonst behielte dieser Tag für immer nichts,
und das wäre das Gegenteil des Zwecks.

Reine Rechenlogik, kein I/O. Wer ablegt und wer löscht, entscheidet die API.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, tzinfo

from hems_core.forecasting.models import PvForecast, WeatherForecast
from hems_core.planning.price_windows import PricePoint

#: Die drei Arten, die `forecast_runs.kind` kennt.
WETTER = "weather"
PV = "pv"
PREIS = "price"

#: Welche Wettergrößen aufbewahrt werden.
#:
#: `temp_c` trägt den Wärmebedarf **und** den COP, ist also die wichtigste Reihe des Zwillings.
#: `cloud_cover` ist heute die einzige Größe, aus der `pv_simple` rechnet. `ghi_w_m2` wird von
#: Open-Meteo längst mitgeliefert und von keinem Modell gelesen; aufbewahrt wird sie trotzdem, weil
#: ein künftiges PV-Modell sie braucht und eine Reihe, die man heute nicht ablegt, später nicht
#: nachträglich entsteht. Das ist genau der Fehler, den diese Datei behebt.
WETTER_GROESSEN: tuple[str, ...] = ("temp_c", "cloud_cover", "ghi_w_m2")

#: Auf wie viele Stellen der Fingerabdruck rundet. Ohne Rundung machte das letzte Bit einer
#: Gleitkommazahl aus einer Wiederholung einen neuen Lauf.
RUNDUNG = 4

#: Wie viele Zeichen des Hashes aufbewahrt werden. 16 Hexzeichen sind 64 Bit; bei einigen Zehntausend
#: Läufen im Jahr ist eine Kollision nicht die Fehlerquelle, über die man nachdenken muss.
LAENGE = 16


@dataclass(frozen=True)
class Punkt:
    """Ein Wert einer Reihe zu einem Zeitpunkt, wie ihn `forecast_points` aufnimmt."""

    ts: datetime
    variable: str
    wert: float | None
    lo: float | None = None
    hi: float | None = None


@dataclass(frozen=True)
class Lauf:
    """Ein Prognoselauf, fertig zum Ablegen."""

    art: str
    anbieter: str
    erstellt: datetime
    von: datetime
    bis: datetime
    schritt_min: int
    punkte: tuple[Punkt, ...]

    @property
    def fingerabdruck(self) -> str:
        return fingerabdruck(self.punkte)


def fingerabdruck(punkte: Iterable[Punkt]) -> str:
    """Der Inhalt eines Laufs als eine kurze Zeichenkette.

    Eine Zeichenkette und kein Wörterbuch: sie lässt sich in einem Schritt vergleichen und in
    `forecast_runs.params` mitschreiben, sodass der nächste Abruf nur den letzten Lauf lesen muss,
    um zu wissen, ob er etwas Neues bringt.

    Die Erstellungszeit zählt **nicht** mit, die Reihenfolge der Punkte auch nicht.
    """

    def rund(x: float | None) -> float | None:
        return None if x is None else round(x, RUNDUNG)

    roh: list[tuple[str, str, float | None, float | None, float | None]] = [
        (p.ts.isoformat(), p.variable, rund(p.wert), rund(p.lo), rund(p.hi)) for p in punkte
    ]
    # Nur nach Zeit und Name sortieren: das ist der Schlüssel in `forecast_points`, und ein Vergleich
    # der Werte selbst würde an einem `None` scheitern.
    roh.sort(key=lambda z: (z[0], z[1]))
    text = json.dumps([list(z) for z in roh], separators=(",", ":"))
    return hashlib.sha256(text.encode()).hexdigest()[:LAENGE]


def wetter_lauf(prognose: WeatherForecast | None) -> Lauf | None:
    """Aus einer Wettervorhersage einen Lauf machen, oder `None`, wenn nichts darin steht."""
    if prognose is None or not prognose.points:
        return None
    punkte: list[Punkt] = []
    for p in prognose.points:
        for name, wert in (
            ("temp_c", p.temp_c),
            ("cloud_cover", p.cloud_cover),
            ("ghi_w_m2", p.ghi_w_m2),
        ):
            if wert is not None:
                punkte.append(Punkt(ts=p.ts, variable=name, wert=wert))
    if not punkte:
        return None
    zeiten = [p.ts for p in prognose.points]
    return Lauf(
        art=WETTER,
        anbieter=prognose.provider,
        erstellt=prognose.issued_at,
        von=min(zeiten),
        bis=max(zeiten),
        schritt_min=prognose.resolution_min,
        punkte=tuple(punkte),
    )


def pv_lauf(prognose: PvForecast | None) -> Lauf | None:
    """Aus einer PV-Prognose einen Lauf machen. Das Band aus lo und hi reist mit."""
    if prognose is None or not prognose.points:
        return None
    zeiten = [p.ts for p in prognose.points]
    return Lauf(
        art=PV,
        anbieter=prognose.provider,
        erstellt=prognose.issued_at,
        von=min(zeiten),
        bis=max(zeiten),
        schritt_min=prognose.resolution_min,
        punkte=tuple(
            Punkt(ts=p.ts, variable="ac_kw", wert=p.ac_kw, lo=p.ac_kw_lo, hi=p.ac_kw_hi)
            for p in prognose.points
        ),
    )


def preis_lauf(punkte: Sequence[PricePoint], erstellt: datetime, anbieter: str) -> Lauf | None:
    """Aus einer Preisliste einen Lauf machen.

    Das Raster steht nicht in der Liste, sondern in der Dauer eines Punktes; Tibber liefert je nach
    Schema Stunden oder Viertelstunden, und beides soll richtig vermerkt sein.
    """
    if not punkte:
        return None
    sortiert = sorted(punkte, key=lambda p: p.start)
    erster = sortiert[0]
    return Lauf(
        art=PREIS,
        anbieter=anbieter,
        erstellt=erstellt,
        von=erster.start,
        bis=max(p.end for p in sortiert),
        schritt_min=round((erster.end - erster.start).total_seconds() / 60),
        punkte=tuple(Punkt(ts=p.start, variable="ct_kwh", wert=p.ct_kwh) for p in sortiert),
    )


def kanonisch[S](
    laeufe: Sequence[tuple[S, datetime]],
    tag: date,
    stunde: int,
    zone: tzinfo,
) -> S | None:
    """Welcher Lauf eines Ortstags für immer bleibt, oder `None`, wenn es an dem Tag keinen gab.

    `laeufe` sind Paare aus einem Schlüssel, den der Aufrufer wiedererkennt, und der
    Erstellungszeit. Was der Schlüssel ist, ist dieser Funktion gleichgültig; die API gibt die
    Kennung des Laufs hinein.

    Der Ortstag und nicht der UTC-Tag: ein Lauf von 23:30 UTC gehört im Winter schon zum nächsten
    Tag in Berlin, und die Tageswertung rechnet in Ortszeit.
    """
    des_tags = [(s, t) for s, t in laeufe if t.astimezone(zone).date() == tag]
    if not des_tags:
        return None
    grenze = datetime.combine(tag, time(hour=stunde), tzinfo=zone)
    davor = [(s, t) for s, t in des_tags if t <= grenze]
    if davor:
        return max(davor, key=lambda z: z[1])[0]
    return min(des_tags, key=lambda z: z[1])[0]
