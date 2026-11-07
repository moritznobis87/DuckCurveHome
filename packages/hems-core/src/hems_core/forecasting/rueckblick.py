"""Was die Prognose wert war: die abgelegten Läufe gegen das, was eintrat.

**Das Problem.** Seit dem 07.11.2026 legt die Laufzeit jeden Prognoselauf in `forecast_runs` und
`forecast_points` ab. Gelesen hat sie niemand. Geschrieben ohne gelesen ist kein halber Nutzen,
sondern keiner: die Frage „wie viel besser wird die Prognose, je näher die Lieferung kommt" ist der
ganze Grund, warum alle Läufe dreißig Tage bleiben und nicht nur der kanonische.

**Was hier anders ist als in `evaluation.py`.** Dort hält der `ForecastEvaluator` PV-Läufe sechzig
Stunden im Arbeitsspeicher und lernt daraus Korrekturfaktoren. Diese Datei rechnet nichts und lernt
nichts; sie liest. Der Unterschied ist nicht Geschmack:

* Der Bewerter verliert alles beim Neustart und kennt nur PV. Das Archiv überlebt und kennt Wetter,
  PV und Preis.
* `ForecastSample` trägt `forecast_kw`, `actual_kw` und `elevation_deg`. Eine Außentemperatur hat
  keine Sonnenhöhe, ihr Fehler keine Kilowattstunden und ihre Summe keinen Sinn. Eine Probe hier
  ist deshalb **einheitenfrei**: zwei Zahlen und der Abstand zur Lieferung. Was die Zahlen bedeuten,
  weiß die Reihe, nicht die Probe.

**Der Vorlauf ist die eigentliche Größe.** `vorlauf_h` ist der Abstand zwischen der Ausgabe eines
Laufs und dem Intervall, das er beschreibt - englisch time to delivery. Ein Fehler ohne diese Zahl
ist nicht interpretierbar: eine Prognose für die nächste Stunde und eine für übermorgen früh sind
nicht dieselbe Leistung. Jeder Lauf stiftet deshalb seine eigenen Proben, auch wenn mehrere Läufe
dasselbe Intervall beschreiben. Dass dasselbe Ist dabei mehrfach vorkommt, ist kein Doppelzählen:
bewertet werden Läufe, nicht Viertelstunden.

**Eine eigene Vorlaufleiter.** `evaluation.HORIZON_CLASSES` hat drei Sprossen bis 36 Stunden und
bleibt, wie sie ist, weil die PV-Seite auf ihr steht. Der Zwilling plant 48 Stunden, und drei
Sprossen beantworten die Frage nach der rollierenden Verbesserung nicht: zwischen „in zwei Stunden"
und „in zehn" liegt genau das, was den Fahrplan noch ändern kann. Die Leiter hier ist feiner und
reicht bis 48.

**Warum der Preis nicht dabei ist.** Der Day-ahead-Preis ist eine Veröffentlichung und keine
Vorhersage; sein „Fehler" wäre die Frage, wann die Börse geliefert hat, nicht wie gut sie geraten
hat. Abgelegt wird er trotzdem, denn die Nachbetrachtung braucht den Preis, der zur Planungszeit
bekannt war - und vor der Veröffentlichung am Mittag ist das für morgen gar keiner. Das ist eine
Lücke im Plan, kein Prognosefehler, und sie gehört nicht in dieselbe Tabelle.

Reine Rechenlogik, kein I/O und keine Konfiguration. Wer die Läufe holt, das Ist dazulegt und eine
Temperatur in einen Wärmebedarf umrechnet, entscheidet die API.
"""

from __future__ import annotations

import math
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict

from hems_core.forecasting.archive import PV, WETTER

#: Die Vorlaufklassen des Rückblicks: untere Grenze, obere Grenze, Schlüssel.
#:
#: Fein, wo sich der Fahrplan noch ändert, und grob, wo er nur noch Kulisse ist. Die Grenze bei 12
#: Stunden ist keine runde Zahl, sondern die Veröffentlichung des Day-ahead-Preises am Mittag: alles
#: darunter liegt im selben Preisbild, alles darüber hat es noch nicht gesehen.
VORLAUF_KLASSEN: tuple[tuple[float, float, str], ...] = (
    (0, 1, "0-1h"),
    (1, 3, "1-3h"),
    (3, 6, "3-6h"),
    (6, 12, "6-12h"),
    (12, 24, "12-24h"),
    (24, 48, "24-48h"),
)

VORLAUF_LABELS_DE: dict[str, str] = {
    "0-1h": "bis 1 Stunde",
    "1-3h": "1 bis 3 Stunden",
    "3-6h": "3 bis 6 Stunden",
    "6-12h": "6 bis 12 Stunden",
    "12-24h": "12 bis 24 Stunden",
    "24-48h": "24 bis 48 Stunden",
}


@dataclass(frozen=True)
class Reihe:
    """Eine vergleichbare Reihe: welche Prognosegröße gegen welche Messung, und in welcher Einheit.

    `ist_reihe` ist der Schlüssel der Messreihe, wie ihn die Minutentabelle und
    `infrastructure.history.SERIES` führen - kein Spaltenname einer Datenbank, sondern der Name, den
    der Sensor im ganzen Haus trägt.

    `schwelle` nimmt Paare aus der Wertung, in denen beide Seiten nahe null liegen und die deshalb
    keine Information tragen: die Nachtstunden der PV-Prognose. Ohne sie bestünde die Hälfte der
    Proben aus der Übereinstimmung zweier Nullen, und jede Kennzahl sähe besser aus, als sie ist.
    """

    art: str
    variable: str
    ist_reihe: str
    label_de: str
    einheit: str
    schwelle: float = 0.0
    #: Das Raster, in dem der Anbieter liefert. Das Ist wird darauf gemittelt und nicht umgekehrt.
    #:
    #: Open-Meteo liefert stündlich, die PV-Prognose viertelstündlich. Würde man das Ist immer auf
    #: Viertelstunden mitteln, vergliche man eine Stundenprognose gegen die erste Viertelstunde der
    #: Stunde und schriebe deren Rauschen der Prognose zu.
    raster_min: int = 15


#: Was heute vergleichbar ist. Zwei Reihen, und die zweite ist die wichtigere.
#:
#: Die Außentemperatur trägt im Modell v1 den gesamten Wärmebedarf und den COP. Eine Messung der
#: gelieferten Wärme gibt es nicht, also ist der Temperaturfehler **der messbare Teil** des
#: Wärmebedarfsfehlers: das Bedarfsmodell ist in der Temperatur deterministisch, mithin ist der
#: Abstand zwischen prognostizierter und eingetretener Temperatur alles, was die Prognose an diesem
#: Bedarf falsch machen kann. Was das Modell selbst falsch macht, steht hier nicht und wird erst mit
#: einem Wärmemengenzähler sichtbar (Entwurf, Abschnitt 5.2).
REIHEN: tuple[Reihe, ...] = (
    Reihe(
        art=PV,
        variable="ac_kw",
        ist_reihe="pv_power_kw",
        label_de="PV-Leistung",
        einheit="kW",
        schwelle=0.05,
    ),
    Reihe(
        art=WETTER,
        variable="temp_c",
        ist_reihe="outdoor_temp_c",
        label_de="Außentemperatur",
        einheit="K",
        raster_min=60,
    ),
)


@dataclass(frozen=True)
class Probe:
    """Ein Paar aus Prognose und Ist für denselben Zeitpunkt, mit dem Abstand zur Lieferung."""

    ts: datetime
    prognose: float
    ist: float
    vorlauf_h: float

    @property
    def fehler(self) -> float:
        """Prognose minus Ist. Positiv heißt: die Prognose lag zu hoch."""
        return self.prognose - self.ist


class Wertung(BaseModel):
    """Kennzahlen einer Menge von Proben, in der Einheit der Reihe.

    Einheitenfrei benannt: `mae` ist bei der PV ein Kilowatt und bei der Temperatur ein Kelvin. Eine
    Energiesumme steht hier bewusst nicht - sie ergibt nur für Leistungen einen Sinn, und wer sie
    für PV braucht, findet sie in `evaluation.ForecastScore`.
    """

    model_config = ConfigDict(frozen=True)

    n: int
    mae: float
    bias: float  # Prognose minus Ist; positiv = Prognose zu hoch
    rmse: float
    #: Der schlechteste Fehler, den man noch erwarten muss (95. Perzentil des Betrags).
    #:
    #: Der Mittelwert sagt nichts über den Tag, an dem der Fahrplan daneben lag. Für die Frage, ob
    #: eine harte Komfortgrenze haltbar ist, zählt genau dieser Rand und nicht die Mitte.
    p95: float


def wertung(stichproben: Iterable[Probe]) -> Wertung:
    xs = list(stichproben)
    n = len(xs)
    if n == 0:
        return Wertung(n=0, mae=0.0, bias=0.0, rmse=0.0, p95=0.0)
    fehler = [p.fehler for p in xs]
    betraege = sorted(abs(f) for f in fehler)
    # Nächstgelegener Rang statt Interpolation: bei kleinen Mengen ist ein gemessener Wert ehrlicher
    # als ein gerechneter zwischen zwei gemessenen.
    rang = min(n - 1, math.ceil(0.95 * n) - 1)
    return Wertung(
        n=n,
        mae=round(sum(betraege) / n, 3),
        bias=round(sum(fehler) / n, 3),
        rmse=round(math.sqrt(sum(f * f for f in fehler) / n), 3),
        p95=round(betraege[max(0, rang)], 3),
    )


def wertung_je_vorlauf(stichproben: Iterable[Probe]) -> dict[str, Wertung]:
    """Eine Wertung je Vorlaufklasse. Leere Klassen bleiben mit `n = 0` stehen.

    Sie bleiben stehen, weil eine fehlende Sprosse etwas anderes heißt als eine fehlerfreie: an
    einem Tag, an dem der Dienst stundenweise stillstand, fehlen Läufe, und die Leiter soll das
    zeigen statt es wegzulassen.
    """
    xs = list(stichproben)
    return {
        key: wertung(p for p in xs if lo <= p.vorlauf_h < hi) for lo, hi, key in VORLAUF_KLASSEN
    }


def mittel_je_raster(
    rows: Iterable[tuple[datetime, float | None]], minuten: int
) -> dict[datetime, float]:
    """Minutenwerte auf ein Raster mitteln, geschlüsselt nach Intervallbeginn.

    Dasselbe wie `evaluation.aggregate_15min`, nur mit wählbarer Weite und als Abbildung: der
    Rückblick muss das Ist auf das Raster des jeweiligen Anbieters bringen, und das ist je Reihe
    ein anderes. Lücken werden übersprungen, nicht interpoliert.
    """
    sammlung: dict[datetime, list[float]] = {}
    for ts, v in rows:
        if v is None:
            continue
        ts = ts.astimezone(UTC)
        minute = (ts.minute // minuten) * minuten if minuten < 60 else 0
        stunde = ts.hour if minuten <= 60 else (ts.hour // (minuten // 60)) * (minuten // 60)
        slot = ts.replace(hour=stunde, minute=minute, second=0, microsecond=0)
        sammlung.setdefault(slot, []).append(float(v))
    return {slot: round(sum(vs) / len(vs), 3) for slot, vs in sorted(sammlung.items())}


def vorlauf_h(erstellt: datetime, ts: datetime) -> float:
    """Der Abstand zwischen der Ausgabe eines Laufs und dem Intervall, in Stunden."""
    return max(0.0, (ts - erstellt).total_seconds() / 3600.0)


def proben(
    punkte: Iterable[tuple[datetime, datetime, float]],
    ist: Mapping[datetime, float],
    *,
    schwelle: float = 0.0,
    von: datetime | None = None,
    bis: datetime | None = None,
) -> list[Probe]:
    """Archivpunkte mit dem Ist paaren.

    `punkte` sind Tripel aus Erstellungszeit des Laufs, Zeitpunkt und Wert - genau die Form, in der
    ein Verbund von `forecast_runs` und `forecast_points` herauskommt. `ist` ist nach demselben
    Raster geschlüsselt; wo kein Ist steht, entsteht keine Probe. Eine Lücke in der Messung ist kein
    Fehler der Prognose.
    """
    out: list[Probe] = []
    for erstellt, ts, wert in punkte:
        if von is not None and ts < von:
            continue
        if bis is not None and ts >= bis:
            continue
        gemessen = ist.get(ts)
        if gemessen is None:
            continue
        if schwelle > 0 and abs(wert) <= schwelle and abs(gemessen) <= schwelle:
            continue
        out.append(
            Probe(
                ts=ts, prognose=float(wert), ist=float(gemessen), vorlauf_h=vorlauf_h(erstellt, ts)
            )
        )
    return out


def umgerechnet(
    stichproben: Iterable[Probe], wandler: Callable[[datetime, float], float]
) -> list[Probe]:
    """Beide Seiten jeder Probe durch dieselbe Funktion schicken.

    Damit wird aus einem Temperaturfehler ein Wärmebedarfsfehler: `wandler` ist das Bedarfsmodell,
    und weil es auf Prognose und Ist gleich angewendet wird, ist die Differenz der Fehler, den die
    **Prognose** verursacht hat, und nicht der, den das Modell macht. Das Modell steckt in beiden
    Seiten und fällt heraus.

    Deshalb ist das Ergebnis keine Aussage über die Güte des Bedarfsmodells. Die bekommt erst, wer
    die Wärme messen kann.
    """
    return [
        Probe(
            ts=p.ts,
            prognose=wandler(p.ts, p.prognose),
            ist=wandler(p.ts, p.ist),
            vorlauf_h=p.vorlauf_h,
        )
        for p in stichproben
    ]


class VorlaufOut(BaseModel):
    """Eine Sprosse der Vorlaufleiter mit ihrer Wertung."""

    model_config = ConfigDict(frozen=True)

    key: str
    label_de: str
    wertung: Wertung


class ReiheOut(BaseModel):
    """Eine Reihe im Rückblick: ihre Wertung über alles und je Vorlaufklasse."""

    model_config = ConfigDict(frozen=True)

    key: str
    label_de: str
    einheit: str
    gesamt: Wertung
    je_vorlauf: list[VorlaufOut]
    #: Wie viele Läufe zu dieser Reihe im Zeitraum lagen. Null heißt: nichts abgelegt, nicht
    #: fehlerfrei.
    laeufe: int


def reihe_out(
    reihe: Reihe,
    stichproben: Sequence[Probe],
    laeufe: int,
    *,
    key: str | None = None,
    label_de: str | None = None,
    einheit: str | None = None,
) -> ReiheOut:
    """Eine Reihe fertig für die Ausgabe. `key` und Beschriftung lassen sich überschreiben, damit
    eine abgeleitete Größe - der Wärmebedarf aus der Temperatur - unter eigenem Namen daneben
    stehen kann."""
    return ReiheOut(
        key=key or f"{reihe.art}.{reihe.variable}",
        label_de=label_de or reihe.label_de,
        einheit=einheit or reihe.einheit,
        gesamt=wertung(stichproben),
        je_vorlauf=[
            VorlaufOut(key=k, label_de=VORLAUF_LABELS_DE[k], wertung=w)
            for k, w in wertung_je_vorlauf(stichproben).items()
        ],
        laeufe=laeufe,
    )
