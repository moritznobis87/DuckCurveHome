"""Die Regelkreis-Karte als Antwort des Dienstes, und der Lernlauf dahinter.

Gerechnet wird im Kern (`hems_core.regelkreis`): Struktur, Entwurf nach SIMC, Schätzer und
Übernahmeprüfung. Hier wird zweierlei getan.

**Erstens der Lernlauf.** Er nimmt die Auswertungen, die der Dienst ohnehin schon rechnet - die
Ausgleichsebene der COP-Kennlinie und die Ereignisstudie zu K1 -, macht daraus Kandidaten und legt
sie der Prüfung vor. Dass hier keine neuen Messreihen gelesen werden, ist Absicht: die Zahlen für
den Reglerentwurf liegen seit Monaten in diesen beiden Auswertungen, sie wurden nur nirgends
abgeholt. Eine zweite Rechnung über dieselben Minuten wäre eine zweite Wahrheit.

**Zweitens der Arbeitspunkt.** Die Verstärkung der Wärmepumpe hängt von Außen- und
Vorlauftemperatur ab. Die Karte wird deshalb für den Augenblick gerechnet, mit den gemessenen
Temperaturen und dem Preis, mit dem der Fahrplan gerade rechnet - und sagt in ihrer Antwort, ob
diese Zahlen gemessen oder angenommen waren.

**Der Lernzustand liegt in `model_calibrations`** unter `regelkreis_v1`, wie der PV-Korrektor. Eine
eigene Tabelle braucht er nicht: er ist ein Zustand je Modell, und genau dafür ist die Tabelle da.

Reine Zusammensetzung. Wer liest und schreibt, ist die Laufzeit.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, datetime, timedelta, tzinfo

from dch_api.errors import DchError
from dch_api.schemas import KennlinieOut, KontaktwirkungOut, RegelkreisOut
from hems_core.domain.config import HemsConfig
from hems_core.domain.snapshot import EnergySnapshot
from hems_core.regelkreis import karte as kern
from hems_core.regelkreis import messung
from hems_core.regelkreis.parameter import PARAMETER
from hems_core.regelkreis.schaetzer import Pruefung, Schaetzstand
from hems_core.thermal.heat_balance import HeatSample, heat_series
from hems_core.thermal.kennlinie import Ausgleich

#: Der Schlüssel des Lernzustands in `model_calibrations`.
MODELL = "regelkreis_v1"
#: So oft höchstens ein Lernlauf. Die Übernahmeprüfung wartet ohnehin vierzehn Tage zwischen zwei
#: Übernahmen; stündlich zu rechnen reicht also mit großem Abstand und hält die Seite schnell.
LERNABSTAND = timedelta(hours=1)
#: Rückblick der beiden Auswertungen, aus denen die Kandidaten kommen.
KENNLINIE_TAGE = 30
WIRKUNG_TAGE = 30
#: Rückblick der Wärmebilanz. Mehr trägt die Minutenauflösung des Bestands nicht, und für
#: Heizstunden und stille Nächte reichen zwei Wochen.
WAERME_TAGE = 14


def arbeitspunkt(
    cfg: HemsConfig,
    stand: Schaetzstand,
    snapshot: EnergySnapshot | None,
    *,
    vorlauf_c: float | None = None,
) -> kern.Arbeitspunkt:
    """Der Punkt, für den die Karte gilt: gemessen, wo es Messungen gibt.

    Außentemperatur und Strompreis stehen im Augenblickszustand. Die Vorlauftemperatur steht dort
    nicht; wo sie fehlt, wird sie aus der Heizkennlinie gerechnet, und die Antwort sagt das. Eine
    Karte, die mit Annahmen gerechnet wurde und sich nicht dazu bekennt, lädt dazu ein, ihre
    Reglerwerte für gemessen zu halten.
    """
    grund = kern.Arbeitspunkt.aus_konfiguration(cfg)
    if snapshot is None:
        return grund
    aussen = snapshot.outdoor_temp_c.value
    if aussen is None:
        return grund
    w = kern.werte(cfg, stand)
    preis_ct = snapshot.electricity_price_ct_kwh.value
    return kern.Arbeitspunkt(
        aussen_c=aussen,
        vorlauf_c=vorlauf_c if vorlauf_c is not None else kern.vorlauf_sollwert(cfg, w, aussen),
        strompreis_eur_kwh=(preis_ct / 100.0 if preis_ct is not None else grund.strompreis_eur_kwh),
        aussen_gemessen=True,
        vorlauf_gemessen=vorlauf_c is not None,
    )


def _ausgleich(kennlinie: KennlinieOut | None) -> Ausgleich | None:
    """Die Ausgleichsebene der Kennlinienantwort als Kernobjekt zurück."""
    if kennlinie is None or kennlinie.fit is None:
        return None
    f = kennlinie.fit
    return Ausgleich(
        art=f.art,
        a=f.a,
        b_aussen=f.b_aussen,
        c_vorlauf=f.c_vorlauf,
        n=f.n,
        rmse=f.rmse,
        r2=f.r2,
        aussen_von_c=f.aussen_von_c,
        aussen_bis_c=f.aussen_bis_c,
        vorlauf_von_c=f.vorlauf_von_c,
        vorlauf_bis_c=f.vorlauf_bis_c,
    )


def lernen(
    stand: Schaetzstand,
    cfg: HemsConfig,
    *,
    jetzt: datetime,
    kennlinie: KennlinieOut | None = None,
    wirkung: KontaktwirkungOut | None = None,
    waerme: Sequence[HeatSample] | None = None,
    zeitzone: tzinfo = UTC,
) -> dict[str, Pruefung]:
    """Ein Lernlauf: Kandidaten bilden, vorlegen, und die Prüfungen zurückgeben.

    Der Zustand wird dabei verändert - übernommen wird nur, was die Prüfung durchlässt, und auch
    eine Ablehnung wird festgehalten. Die Rückgabe ist das Protokoll dieses Laufs, je Parameter
    eine Prüfung; sie steht hinterher auch in der Karte.
    """
    start = kern.werte(cfg, Schaetzstand())
    kandidaten = []
    a = _ausgleich(kennlinie)
    if a is not None:
        kandidaten.extend(messung.aus_kennlinie(a))
    if wirkung is not None:
        kandidaten.extend(messung.aus_kontaktwirkung(wirkung))
    if waerme:
        # Dieselbe Rechnung wie auf der Wärmeseite, nicht eine zweite daneben.
        punkte = heat_series(
            waerme,
            stove=cfg.stove,
            heat=cfg.heat_demand,
            buffer=cfg.buffer,
            heat_pump=cfg.heat_pump,
        )
        kandidaten.extend(
            messung.aus_waermebilanz(waerme, punkte, heat=cfg.heat_demand, zeitzone=zeitzone)
        )
        nacht = messung.aus_naechten(
            waerme,
            buffer=cfg.buffer,
            heat=cfg.heat_demand,
            kapazitaet_kwh_k=kern.werte(cfg, stand)["puffer_c"],
        )
        if nacht is not None:
            kandidaten.append(nacht)
    aus: dict[str, Pruefung] = {}
    for k in kandidaten:
        vorher = stand.parameter.get(k.pid)
        aus[k.pid] = stand.melde(
            k.pid,
            kandidat=k.wert,
            sigma=k.sigma,
            n=k.n,
            jetzt=jetzt,
            startwert=start[k.pid],
            rmse_alt=vorher.rmse if vorher is not None else None,
            rmse_neu=k.rmse,
        )
    if stand.seit is None:
        stand.seit = jetzt
    return aus


def zusammensetzen(
    cfg: HemsConfig,
    stand: Schaetzstand,
    *,
    jetzt: datetime,
    ap: kern.Arbeitspunkt | None = None,
) -> RegelkreisOut:
    """Die Karte für diesen Augenblick."""
    k = kern.aufbauen(cfg, stand, jetzt=jetzt, arbeitspunkt=ap)
    return RegelkreisOut(**k.model_dump())


def pruefe_parameter(pid: str) -> None:
    """Eine Kennung, die das Register nicht kennt, ist ein Eingabefehler und kein Serverfehler."""
    if pid not in PARAMETER:
        raise DchError(
            code="unbekannter_parameter",
            message=f"Der Regelkreis kennt keinen Parameter „{pid}“.",
            status=404,
            details={"bekannt": sorted(PARAMETER)},
        )


def uebersteuern(stand: Schaetzstand, pid: str, wert: float) -> None:
    """Einen Parameter von Hand setzen. Beschnitten auf die Plausibilitätsgrenzen des Registers."""
    pruefe_parameter(pid)
    stand.uebersteuere(pid, wert)


def freigeben(stand: Schaetzstand, pid: str) -> None:
    """Die Übersteuerung aufheben; es gilt wieder, was gelernt wurde."""
    pruefe_parameter(pid)
    stand.freigeben(pid)


def faellig(letzter: datetime | None, jetzt: datetime) -> bool:
    """Ob ein Lernlauf ansteht."""
    return letzter is None or jetzt - letzter >= LERNABSTAND
