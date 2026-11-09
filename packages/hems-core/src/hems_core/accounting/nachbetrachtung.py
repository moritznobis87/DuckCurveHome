"""Die Nachbetrachtung in Euro: was der Tag versprach, was er hielt, was er kostete.

Schritt 9 des Zwillingsentwurfs. Die Frage hat drei Teile, und sie wurden bisher in einen Topf
geworfen: Wie falsch war die Prognose? Was hat das Nachführen des Fahrplans gebracht? Und was hat
die Maschine daraus gemacht, die den Kontakt nur als Anforderung nimmt? Jede der drei Antworten
ist ein Abstand zwischen zwei Linien, und damit die Abstände bedeuten, was sie behaupten, werden
alle Linien **mit derselben Rechnung über dieselben Viertelstunden** bewertet.

Die Linien:

* `versprochen` - der erste aufbewahrte Fahrplan des Tages, mit den Kosten, die der Optimierer
  damals selbst gezählt hat. Das ist keine Nachrechnung, sondern eine Erinnerung.
* `erster` - derselbe Fahrplan, bewertet mit dem eingetretenen Preis und Überschuss: was er
  gehalten hätte, wenn die Maschine gefolgt wäre.
* `letzter` - für jede Viertelstunde der jüngste Fahrplan, der vor ihr entstand, ebenso bewertet.
  Das ist die Absicht, mit der man in die Viertelstunde hineinging.
* `wirklich` - der gemessene Strom des Verdichters und der gemessene Ofenbetrieb.
* `perfekt` - ein neu gerechneter Fahrplan, dem der Tag im Voraus bekannt war.
* `ohne_fuehrung` - dieselbe Strommenge wie in Wirklichkeit, verteilt nach dem Wärmebedarf statt
  nach dem Preis. Eine Schätzung, und so gekennzeichnet.

Die Abstände, als Treppe vom Versprechen zur Wirklichkeit:

    versprochen  +  Prognosefehler  +  Nachführen  +  Eingriff der Maschine  =  wirklich

**Eine Rechnung für alle.** Der Strom einer Viertelstunde kostet den Bezugspreis, soweit er aus
dem Netz kommt, und die entgangene Einspeisevergütung, soweit ihn der Überschuss deckt - anteilig.
Der Optimierer selbst rechnet gröber, alles oder nichts; deshalb steckt in `Prognosefehler` auch
der Abstand zwischen seiner Vereinfachung und der anteiligen Rechnung, und der Hinweis sagt das.

**Dieselben Viertelstunden.** Verglichen wird nur, wo jede Linie etwas sagen kann: der Preis ist
bekannt, die Leistung gemessen, und der erste Fahrplan reicht bis dorthin. Entstand der erste
Fahrplan erst um 14 Uhr, beginnt der Vergleich um 14 Uhr - für alle Linien, auch für die
Wirklichkeit. Ein Tag, an dem die eine Linie 24 Stunden zählt und die andere zehn, ergäbe einen
Abstand, der nur ihre Länge misst.

**Was diese Rechnung nicht ist.** Die Linien liefern nicht dieselbe Wärme. Ein Fahrplan mit sechs
Stunden Freigabe und eine Maschine, die neun Stunden lief, unterscheiden sich in der Menge und im
Zeitpunkt; der Eingriff der Maschine wird deshalb in beides zerlegt. Der Speicher im Keller kommt
nicht vor: ob eine Kilowattstunde aus der Batterie kam, ändert an dieser Bewertung nichts. Und die
Grundlast der Anlage im Stillstand steht in keiner Linie, sondern daneben - sie hängt an keinem
Fahrplan.

Reine Rechenlogik, kein I/O, keine Zeitzonen, kein Löser. Den Vergleichslauf rechnet der Aufrufer
und reicht ihn als Fahrplan herein.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

#: Unter so vielen verglichenen Viertelstunden gibt es Zahlen, aber keinen Satz dazu: eine Stunde
#: sagt über einen Tag nichts.
MIN_VIERTEL = 8


@dataclass(frozen=True)
class Viertel:
    """Eine Viertelstunde, wie sie eintrat. Was fehlt, ist `None` und bleibt es."""

    ts: datetime
    #: Der Bezugspreis in Cent je Kilowattstunde.
    preis_ct: float | None
    #: Der PV-Überschuss vor der Wärmepumpe in Kilowatt, nie negativ.
    ueberschuss_kw: float | None
    #: Der Strom des Verdichters in dieser Viertelstunde, in Kilowattstunden: nur die Minuten, in
    #: denen die Maschine lief.
    wp_kwh: float | None
    #: Der Strom der Anlage in den übrigen Minuten: Umwälzpumpe, Elektronik.
    standby_kwh: float | None = None
    #: Minuten dieser Viertelstunde, in denen der Verdichter lief.
    laufmin: float | None = None
    #: Anteil der Viertelstunde, in dem der Ofen brannte, 0 bis 1. `None` ohne Ofen oder Messung.
    ofen_anteil: float | None = None
    #: Was eine Ofenstunde bei eingetretenem Preis und eingetretener Temperatur kostet.
    ofen_eur_je_h: float = 0.0
    #: Wie viel Strom die Wärmepumpe in dieser Viertelstunde bräuchte, liefe sie dem Wärmebedarf
    #: nach: Bedarf geteilt durch die Arbeitszahl, beides aus der eingetretenen Temperatur. Nur
    #: das Verhältnis der Gewichte zählt, nicht ihre Höhe.
    gewicht: float | None = None


@dataclass(frozen=True)
class Fahrplan:
    """Ein Fahrplan über dieselben Viertelstunden. `None` heißt: er sagt hier nichts."""

    wp: Sequence[bool | None]
    ofen: Sequence[bool | None] = ()
    #: Die Kosten, die der Optimierer selbst gezählt hat. Nur der erste Fahrplan braucht sie.
    versprochen_eur: Sequence[float | None] = ()
    erstellt: datetime | None = None


class Linie(BaseModel):
    """Eine der Linien: ihre Summe, und je Viertelstunde, woraus sie entstand."""

    model_config = ConfigDict(frozen=True)

    key: str
    name_de: str
    verfuegbar: bool = False
    #: Warum die Linie fehlt. Leer, wenn sie da ist.
    grund_de: str = ""
    geschaetzt: bool = False
    eur: float | None = None
    strom_eur: float | None = None
    ofen_eur: float | None = None
    #: Strom der Wärmepumpe über die verglichenen Viertelstunden, in Kilowattstunden.
    wp_kwh: float | None = None
    #: Was die Kilowattstunde Strom dieser Linie im Mittel gekostet hat, in Cent. Die eine Zahl,
    #: die nicht an der Menge hängt: zwei Linien mit verschiedener Laufzeit lassen sich in Euro
    #: nicht fair vergleichen, im mittleren Preis schon. `None` ohne Strom.
    ct_je_kwh: float | None = None
    #: Laufstunden der Wärmepumpe und des Ofens. `None`, wo die Linie keine Schaltzeiten hat.
    wp_h: float | None = None
    ofen_h: float | None = None
    #: Je Viertelstunde des Tages, in der Reihenfolge von `Nachbetrachtung.zeiten`. Strom und
    #: Ofenanteil stehen überall, wo die Linie etwas sagt; Kosten nur in verglichenen
    #: Viertelstunden. `eur_kumuliert` beginnt mit dem Vergleich und läuft von dort an durch.
    wp_kwh_je: list[float | None] = Field(default_factory=list)
    ofen_je: list[float | None] = Field(default_factory=list)
    eur_je: list[float | None] = Field(default_factory=list)
    eur_kumuliert: list[float | None] = Field(default_factory=list)


class Abstand(BaseModel):
    """Der Abstand zwischen zwei Linien, mit seiner Bedeutung. Positiv heißt: teurer."""

    model_config = ConfigDict(frozen=True)

    key: str
    name_de: str
    von: str
    nach: str
    eur: float | None = None
    satz_de: str = ""
    #: Nur beim Eingriff der Maschine: wie viel des Abstands an der Strommenge liegt, wie viel am
    #: Zeitpunkt und wie viel am Ofen. Die drei ergeben zusammen `eur`.
    menge_eur: float | None = None
    zeit_eur: float | None = None
    ofen_eur: float | None = None


class Nachbetrachtung(BaseModel):
    """Der Tag in Euro. Die Oberfläche zeichnet; gerechnet und beurteilt wird hier."""

    model_config = ConfigDict(frozen=True)

    zeiten: list[datetime] = Field(default_factory=list)
    schritt_min: int = 15
    #: Welche Viertelstunden in den Vergleich eingehen.
    verglichen: list[bool] = Field(default_factory=list)
    n_verglichen: int = 0
    #: Eingetretener Preis und Überschuss je Viertelstunde, zum Danebenzeichnen.
    preis_ct: list[float | None] = Field(default_factory=list)
    ueberschuss_kw: list[float | None] = Field(default_factory=list)
    linien: list[Linie] = Field(default_factory=list)
    abstaende: list[Abstand] = Field(default_factory=list)
    #: Die Grundlast der Anlage im Stillstand über die verglichenen Viertelstunden. In keiner
    #: Linie enthalten.
    standby_kwh: float | None = None
    standby_eur: float | None = None
    #: Wann der erste Fahrplan entstand, mit dem verglichen wird.
    erster_plan_erstellt: datetime | None = None
    satz_de: str = ""
    hinweise_de: list[str] = Field(default_factory=list)


def strom_eur(
    kwh: float, *, ueberschuss_kw: float, preis_ct: float, verguetung_ct: float, dt_h: float
) -> float:
    """Was der Strom einer Viertelstunde kostet: anteilig aus Netz und Überschuss.

    Soweit der Überschuss reicht, kostet die Kilowattstunde die Vergütung, die für sie sonst
    geflossen wäre; der Rest kostet den Bezugspreis. Deckt die Sonne zwei von drei Kilowatt, sind
    zwei Drittel billig und ein Drittel teuer - nicht alles teuer, wie es der Optimierer zählt.
    """
    aus_sonne = min(kwh, max(0.0, ueberschuss_kw) * dt_h)
    return ((kwh - aus_sonne) * preis_ct + aus_sonne * verguetung_ct) / 100.0


def nach_bedarf(
    gesamt_kwh: float, gewichte: Sequence[float | None], maske: Sequence[bool]
) -> list[float | None]:
    """Eine Strommenge nach dem Wärmebedarf über die verglichenen Viertelstunden verteilen.

    Die Nulllinie: dieselbe Menge, nur dann, wann ein Thermostat sie gebraucht hätte. Fehlt ein
    Gewicht oder sind alle null, wird gleichmäßig verteilt - das ist dann die Annahme „es war
    immer gleich kalt", und sie ist schwächer als die mit Gewichten, aber keine Lücke.
    """
    drin = [i for i, m in enumerate(maske) if m]
    out: list[float | None] = [None] * len(maske)
    if not drin:
        return out
    g = [gewichte[i] for i in drin]
    if any(w is None for w in g) or sum(w or 0.0 for w in g) <= 0:
        for i in drin:
            out[i] = gesamt_kwh / len(drin)
        return out
    summe = sum(w or 0.0 for w in g)
    for i, w in zip(drin, g, strict=True):
        out[i] = gesamt_kwh * (w or 0.0) / summe
    return out


@dataclass
class _Summe:
    """Was beim Bewerten einer Linie zusammenkommt."""

    strom: float = 0.0
    ofen: float = 0.0
    kwh: float = 0.0
    je: list[float | None] = field(default_factory=list)
    kumuliert: list[float | None] = field(default_factory=list)


def _bewerten(
    viertel: Sequence[Viertel],
    maske: Sequence[bool],
    wp_kwh: Sequence[float | None],
    ofen: Sequence[float | None],
    *,
    verguetung_ct: float,
    dt_h: float,
) -> _Summe:
    """Eine Linie über die verglichenen Viertelstunden bewerten. Eine Funktion für alle Linien."""
    s = _Summe()
    laufend: float | None = None
    for i, v in enumerate(viertel):
        if not maske[i] or v.preis_ct is None or v.ueberschuss_kw is None:
            s.je.append(None)
            s.kumuliert.append(None if laufend is None else round(laufend, 4))
            continue
        kwh = wp_kwh[i] or 0.0
        strom = strom_eur(
            kwh,
            ueberschuss_kw=v.ueberschuss_kw,
            preis_ct=v.preis_ct,
            verguetung_ct=verguetung_ct,
            dt_h=dt_h,
        )
        brennt = (ofen[i] if i < len(ofen) else None) or 0.0
        feuer = brennt * v.ofen_eur_je_h * dt_h
        s.strom += strom
        s.ofen += feuer
        s.kwh += kwh
        laufend = (laufend or 0.0) + strom + feuer
        s.je.append(round(strom + feuer, 4))
        s.kumuliert.append(round(laufend, 4))
    return s


def _eur(x: float) -> str:
    return f"{abs(x):.2f}".replace(".", ",") + " €"


def _kwh(x: float) -> str:
    return f"{x:.1f}".replace(".", ",") + " kWh"


def _mehr_weniger(x: float, mehr: str = "mehr", weniger: str = "weniger") -> str:
    return f"{_eur(x)} {mehr if x >= 0 else weniger}"


def _plan_linie(
    key: str,
    name: str,
    plan: Fahrplan | None,
    grund: str,
    viertel: Sequence[Viertel],
    maske: Sequence[bool],
    *,
    wp_kw: float,
    verguetung_ct: float,
    dt_h: float,
    hat_ofen: bool,
) -> Linie:
    """Ein Fahrplan als Linie: Freigabe heißt Nennleistung, wie im Modell des Optimierers."""
    if plan is None:
        return Linie(key=key, name_de=name, grund_de=grund)
    n = len(viertel)
    wp = [None if i >= len(plan.wp) or plan.wp[i] is None else bool(plan.wp[i]) for i in range(n)]
    if any(maske[i] and wp[i] is None for i in range(n)):
        return Linie(
            key=key,
            name_de=name,
            grund_de="Der Fahrplan deckt nicht alle verglichenen Viertelstunden.",
        )
    kwh: list[float | None] = [None if w is None else (wp_kw * dt_h if w else 0.0) for w in wp]
    ofen: list[float | None] = [
        None if i >= len(plan.ofen) or plan.ofen[i] is None else float(bool(plan.ofen[i]))
        for i in range(n)
    ]
    s = _bewerten(viertel, maske, kwh, ofen, verguetung_ct=verguetung_ct, dt_h=dt_h)
    return Linie(
        key=key,
        name_de=name,
        verfuegbar=True,
        eur=round(s.strom + s.ofen, 2),
        strom_eur=round(s.strom, 2),
        ofen_eur=round(s.ofen, 2) if hat_ofen else None,
        wp_kwh=round(s.kwh, 2),
        wp_h=round(sum(1 for i in range(n) if maske[i] and wp[i]) * dt_h, 2),
        ofen_h=round(sum(1 for i in range(n) if maske[i] and ofen[i]) * dt_h, 2)
        if hat_ofen
        else None,
        wp_kwh_je=[None if k is None else round(k, 3) for k in kwh],
        ofen_je=ofen,
        eur_je=s.je,
        eur_kumuliert=s.kumuliert,
    )


def _abstand(key: str, name: str, von: Linie, nach: Linie, satz: Callable[[float], str]) -> Abstand:
    """Der Abstand `nach` minus `von`. Fehlt eine der Linien, fehlt er."""
    if von.eur is None or nach.eur is None:
        return Abstand(key=key, name_de=name, von=von.key, nach=nach.key)
    eur = round(nach.eur - von.eur, 2)
    return Abstand(key=key, name_de=name, von=von.key, nach=nach.key, eur=eur, satz_de=satz(eur))


def nachbetrachten(
    viertel: Sequence[Viertel],
    *,
    erster: Fahrplan | None,
    letzter: Fahrplan | None,
    perfekt: Fahrplan | None,
    perfekt_grund_de: str = "",
    wp_kw: float,
    verguetung_ct: float,
    hat_ofen: bool,
    schritt_min: int = 15,
    laeuft_noch: bool = False,
) -> Nachbetrachtung:
    """Den Tag bewerten. `viertel` sind alle Viertelstunden des Ortstages, auch die ohne Messung.

    `erster`, `letzter` und `perfekt` sind Fahrpläne über dieselben Viertelstunden. `wp_kw` ist die
    elektrische Nennleistung: was eine Freigabe im Modell des Optimierers zieht. `laeuft_noch`
    sagt, dass der Tag nicht zu Ende ist; die Rechnung ist dieselbe, der Satz ein anderer.
    """
    n = len(viertel)
    dt_h = schritt_min / 60.0
    gemessen = [
        v.preis_ct is not None and v.ueberschuss_kw is not None and v.wp_kwh is not None
        for v in viertel
    ]
    # Mit Fahrplan beginnt der Vergleich dort, wo der erste etwas sagt; ohne ihn gilt, was
    # gemessen ist, und die Linien der Fahrpläne fehlen mit Grund.
    if erster is not None:
        maske = [gemessen[i] and i < len(erster.wp) and erster.wp[i] is not None for i in range(n)]
        if letzter is not None:
            maske = [
                maske[i] and i < len(letzter.wp) and letzter.wp[i] is not None for i in range(n)
            ]
    else:
        maske = gemessen
    n_verglichen = sum(maske)
    kein_plan = (
        "Für diesen Tag ist kein Fahrplan aufbewahrt. Aufbewahrt wird seit dem 09.11.2026, "
        "stündlich."
    )

    linie = {
        "erster": _plan_linie(
            "erster",
            "erster Fahrplan, gehalten",
            erster,
            kein_plan,
            viertel,
            maske,
            wp_kw=wp_kw,
            verguetung_ct=verguetung_ct,
            dt_h=dt_h,
            hat_ofen=hat_ofen,
        ),
        "letzter": _plan_linie(
            "letzter",
            "letzter Stand des Fahrplans",
            letzter,
            kein_plan,
            viertel,
            maske,
            wp_kw=wp_kw,
            verguetung_ct=verguetung_ct,
            dt_h=dt_h,
            hat_ofen=hat_ofen,
        ),
        "perfekt": _plan_linie(
            "perfekt",
            "mit perfekter Voraussicht",
            perfekt,
            perfekt_grund_de or "Der Vergleichslauf wurde nicht gerechnet.",
            viertel,
            maske,
            wp_kw=wp_kw,
            verguetung_ct=verguetung_ct,
            dt_h=dt_h,
            hat_ofen=hat_ofen,
        ),
    }

    # --- versprochen: die Erinnerung des ersten Fahrplans, nicht nachgerechnet.
    versprochen = Linie(key="versprochen", name_de="erster Fahrplan, versprochen")
    if erster is None:
        versprochen = versprochen.model_copy(update={"grund_de": kein_plan})
    else:
        je = [
            erster.versprochen_eur[i] if i < len(erster.versprochen_eur) else None for i in range(n)
        ]
        ohne = sum(1 for i in range(n) if maske[i] and je[i] is None)
        if ohne or not n_verglichen:
            versprochen = versprochen.model_copy(
                update={
                    "grund_de": (
                        f"Für {ohne} der {n_verglichen} verglichenen Viertelstunden hat der "
                        "Fahrplan keine Kosten aufbewahrt. Das gilt für jeden Fahrplan, der vor "
                        "der Erweiterung der Ablage entstand, und für Stunden, in denen nicht "
                        "der Optimierer, sondern die Regel entschied."
                    )
                    if n_verglichen
                    else "Es gibt keine verglichene Viertelstunde."
                }
            )
        else:
            laufend = 0.0
            kumuliert: list[float | None] = []
            begonnen = False
            for i in range(n):
                if maske[i]:
                    laufend += je[i] or 0.0
                    begonnen = True
                kumuliert.append(round(laufend, 4) if begonnen else None)
            basis = linie["erster"]
            versprochen = versprochen.model_copy(
                update={
                    "verfuegbar": True,
                    "eur": round(laufend, 2),
                    "wp_kwh": basis.wp_kwh,
                    "wp_h": basis.wp_h,
                    "ofen_h": basis.ofen_h,
                    "wp_kwh_je": basis.wp_kwh_je,
                    "ofen_je": basis.ofen_je,
                    "eur_je": [je[i] if maske[i] else None for i in range(n)],
                    "eur_kumuliert": kumuliert,
                }
            )

    # --- wirklich: der gemessene Strom des Verdichters und der gemessene Ofen.
    ist_kwh = [v.wp_kwh for v in viertel]
    ist_ofen = [v.ofen_anteil for v in viertel]
    s = _bewerten(viertel, maske, ist_kwh, ist_ofen, verguetung_ct=verguetung_ct, dt_h=dt_h)
    wirklich = Linie(
        key="wirklich",
        name_de="wirklich",
        verfuegbar=n_verglichen > 0,
        grund_de="" if n_verglichen else "Für diesen Tag gibt es keine vollständige Messung.",
        eur=round(s.strom + s.ofen, 2) if n_verglichen else None,
        strom_eur=round(s.strom, 2) if n_verglichen else None,
        ofen_eur=round(s.ofen, 2) if n_verglichen and hat_ofen else None,
        wp_kwh=round(s.kwh, 2) if n_verglichen else None,
        wp_h=round(sum((viertel[i].laufmin or 0.0) for i in range(n) if maske[i]) / 60.0, 2)
        if n_verglichen
        else None,
        ofen_h=round(sum((ist_ofen[i] or 0.0) for i in range(n) if maske[i]) * dt_h, 2)
        if n_verglichen and hat_ofen
        else None,
        wp_kwh_je=[None if k is None else round(k, 3) for k in ist_kwh],
        ofen_je=ist_ofen,
        eur_je=s.je,
        eur_kumuliert=s.kumuliert,
    )

    # --- ohne Führung: dieselbe Menge, nach dem Bedarf verteilt. Der Ofen bleibt, wie er war.
    ohne_fuehrung = Linie(
        key="ohne_fuehrung",
        name_de="ohne Preisblick",
        geschaetzt=True,
        grund_de="Für diesen Tag gibt es keine vollständige Messung.",
    )
    if n_verglichen:
        verteilt = nach_bedarf(s.kwh, [v.gewicht for v in viertel], maske)
        t = _bewerten(viertel, maske, verteilt, ist_ofen, verguetung_ct=verguetung_ct, dt_h=dt_h)
        ohne_fuehrung = ohne_fuehrung.model_copy(
            update={
                "verfuegbar": True,
                "grund_de": "",
                "eur": round(t.strom + t.ofen, 2),
                "strom_eur": round(t.strom, 2),
                "ofen_eur": round(t.ofen, 2) if hat_ofen else None,
                "wp_kwh": round(t.kwh, 2),
                "ofen_h": wirklich.ofen_h,
                "wp_kwh_je": [None if k is None else round(k, 3) for k in verteilt],
                "ofen_je": ist_ofen,
                "eur_je": t.je,
                "eur_kumuliert": t.kumuliert,
            }
        )

    erster_l, letzter_l, perfekt_l = linie["erster"], linie["letzter"], linie["perfekt"]
    abstaende = [
        _abstand(
            "prognosefehler",
            "Prognosefehler",
            versprochen,
            erster_l,
            lambda d: (
                "Mit dem eingetretenen Preis und Überschuss hätte der erste Fahrplan "
                f"{_mehr_weniger(d)} gekostet, als er versprach."
            ),
        ),
        _abstand(
            "nachfuehren",
            "Nachführen",
            erster_l,
            letzter_l,
            lambda d: (
                "Das Nachführen über den Tag hat den Fahrplan um "
                f"{_eur(d)} {'teurer' if d > 0 else 'günstiger'} gemacht."
                if d
                else "Das Nachführen über den Tag hat an den Kosten des Fahrplans nichts geändert."
            ),
        ),
        _eingriff(letzter_l, wirklich),
        _abstand(
            "voraussicht",
            "noch zu holen",
            perfekt_l,
            letzter_l,
            lambda d: (
                f"Mit perfekter Voraussicht hätte der Fahrplan {_eur(d)} weniger gekostet. Mehr "
                "ist mit besseren Prognosen nicht zu holen."
                if d >= 0
                else f"Der Lauf mit perfekter Voraussicht ist {_eur(d)} teurer als der letzte "
                "Stand. Das kommt vor: er rechnet mit dem Modell des Optimierers, bewertet wird "
                "anteilig, und er hält den Puffer bis zum Ende seines Horizonts, nicht nur bis "
                "Mitternacht."
            ),
        ),
        _abstand(
            "gebracht",
            "gegenüber ohne Preisblick",
            ohne_fuehrung,
            wirklich,
            lambda d: (
                f"Nach dem Wärmebedarf verteilt hätte dieselbe Strommenge {_eur(d)} mehr "
                "gekostet. So viel hat das Verschieben gebracht, geschätzt."
                if d < 0
                else f"Nach dem Wärmebedarf verteilt hätte dieselbe Strommenge {_eur(d)} weniger "
                "gekostet. Das Verschieben hat an diesem Tag nichts gebracht, geschätzt."
            ),
        ),
    ]

    standby = [viertel[i].standby_kwh for i in range(n) if maske[i]]
    standby_kwh = sum(k or 0.0 for k in standby) if any(k is not None for k in standby) else None
    standby_eur = (
        sum(
            (viertel[i].standby_kwh or 0.0) * (viertel[i].preis_ct or 0.0) / 100.0
            for i in range(n)
            if maske[i]
        )
        if standby_kwh is not None
        else None
    )

    linien = [
        x.model_copy(
            update={
                "ct_je_kwh": round(x.strom_eur / x.wp_kwh * 100.0, 1)
                if x.strom_eur is not None and x.wp_kwh
                else None
            }
        )
        for x in (versprochen, erster_l, letzter_l, wirklich, perfekt_l, ohne_fuehrung)
    ]
    roh = Nachbetrachtung(
        zeiten=[v.ts for v in viertel],
        schritt_min=schritt_min,
        verglichen=list(maske),
        n_verglichen=n_verglichen,
        preis_ct=[v.preis_ct for v in viertel],
        ueberschuss_kw=[
            None if v.ueberschuss_kw is None else round(v.ueberschuss_kw, 3) for v in viertel
        ],
        linien=linien,
        abstaende=abstaende,
        standby_kwh=None if standby_kwh is None else round(standby_kwh, 2),
        standby_eur=None if standby_eur is None else round(standby_eur, 2),
        erster_plan_erstellt=erster.erstellt if erster else None,
    )
    return roh.model_copy(
        update={
            "satz_de": _satz(roh, laeuft_noch=laeuft_noch),
            "hinweise_de": _hinweise(roh, gemessen=sum(gemessen), laeuft_noch=laeuft_noch),
        }
    )


def _eingriff(plan: Linie, ist: Linie) -> Abstand:
    """Wirklich minus letzter Stand, zerlegt in Menge, Zeitpunkt und Ofen.

    Die Maschine nimmt den Kontakt als Anforderung. Sie kann mehr oder weniger Strom ziehen, als
    der Fahrplan vorsah, und sie kann ihn zu anderen Zeiten ziehen. Beides kostet, aber es sind
    zwei verschiedene Befunde: der eine sagt etwas über das Modell der Leistung, der andere über
    den Gehorsam.

    Die Menge wird zum mittleren Strompreis des Fahrplans bewertet - also zu dem Preis, den eine
    zusätzliche Kilowattstunde gekostet hätte, wäre sie dort gelaufen, wo der Fahrplan laufen
    wollte. Der Rest des Abstands im Strom ist der Zeitpunkt.
    """
    name = "Eingriff der Maschine"
    if plan.eur is None or ist.eur is None or plan.strom_eur is None or ist.strom_eur is None:
        return Abstand(key="eingriff", name_de=name, von=plan.key, nach=ist.key)
    eur = round(ist.eur - plan.eur, 2)
    strom = ist.strom_eur - plan.strom_eur
    ofen = round((ist.ofen_eur or 0.0) - (plan.ofen_eur or 0.0), 2)
    plan_kwh, ist_kwh = plan.wp_kwh or 0.0, ist.wp_kwh or 0.0
    # Sah der Fahrplan gar keinen Lauf vor, gibt es keinen Preis, zu dem die Menge zu bewerten
    # wäre. Dann ist der ganze Abstand Menge: es lief etwas, das nicht laufen sollte.
    menge = (
        round((ist_kwh - plan_kwh) * plan.strom_eur / plan_kwh, 2)
        if plan_kwh > 0
        else round(strom, 2)
    )
    # Der Zeitpunkt ist der Rest, damit die drei Teile auf den Cent den Abstand ergeben.
    zeit = round(eur - menge - ofen, 2)
    teile = (
        f"{_mehr_weniger(menge)} durch die Strommenge "
        f"({_kwh(ist_kwh)} statt {_kwh(plan_kwh)}), {_mehr_weniger(zeit)} durch den Zeitpunkt"
    )
    if plan.ofen_eur is not None or ist.ofen_eur is not None:
        teile += f", {_mehr_weniger(ofen)} durch den Ofen"
    return Abstand(
        key="eingriff",
        name_de=name,
        von=plan.key,
        nach=ist.key,
        eur=eur,
        menge_eur=menge,
        zeit_eur=zeit,
        ofen_eur=ofen,
        satz_de=(
            f"Die Wirklichkeit lag {_mehr_weniger(eur, 'über', 'unter')} dem letzten Stand des "
            f"Fahrplans: {teile}."
        ),
    )


#: Ab diesem Verhältnis der Strommengen gelten zwei Linien als nicht mehr vergleichbar in Euro.
MENGE_TOLERANZ = 0.25


def _weit_auseinander(a_kwh: float, b_kwh: float) -> bool:
    """Liegen zwei Strommengen um mehr als ein Viertel der größeren auseinander?"""
    gross = max(a_kwh, b_kwh)
    return gross > 0 and abs(a_kwh - b_kwh) / gross > MENGE_TOLERANZ


def _satz(n: Nachbetrachtung, *, laeuft_noch: bool) -> str:
    """Der eine Satz über den Tag."""
    je = {x.key: x for x in n.linien}
    ist = je["wirklich"]
    if ist.eur is None or n.n_verglichen == 0:
        return (
            "Für diesen Tag gibt es keine Viertelstunde, in der Preis und Leistung gemessen sind."
        )
    stunden = n.n_verglichen * n.schritt_min / 60.0
    spanne = f"{stunden:.1f}".replace(".", ",").removesuffix(",0")
    kopf = (
        f"Die Wärme hat in den {spanne} verglichenen Stunden bisher {_eur(ist.eur)} gekostet"
        if laeuft_noch
        else f"Die Wärme hat in den {spanne} verglichenen Stunden {_eur(ist.eur)} gekostet"
    )
    if n.n_verglichen < MIN_VIERTEL:
        return f"{kopf}. Das sind zu wenige Viertelstunden für einen Vergleich."
    versprochen, letzter = je["versprochen"], je["letzter"]
    # Bei weit auseinanderliegenden Mengen trägt der Euro-Vergleich nicht, und der Satz sagt es,
    # statt eine Zahl zu nennen, die wie ein Urteil über den Fahrplan klingt.
    menge = ""
    if (
        ist.wp_kwh is not None
        and letzter.wp_kwh is not None
        and _weit_auseinander(ist.wp_kwh, letzter.wp_kwh)
    ):
        menge = (
            f" Der Fahrplan rechnete dabei mit {_kwh(letzter.wp_kwh)} Strom, gemessen sind "
            f"{_kwh(ist.wp_kwh)}: der Unterschied liegt vor allem an der Menge."
        )
    if versprochen.eur is not None:
        d = ist.eur - versprochen.eur
        return f"{kopf}, {_mehr_weniger(d)} als der erste Fahrplan versprach.{menge}"
    if letzter.eur is not None:
        d = ist.eur - letzter.eur
        return f"{kopf}, {_mehr_weniger(d)} als nach dem letzten Stand des Fahrplans.{menge}"
    return f"{kopf}. Ein Fahrplan zum Vergleich ist für diesen Tag nicht aufbewahrt."


def _hinweise(n: Nachbetrachtung, *, gemessen: int, laeuft_noch: bool) -> list[str]:
    out: list[str] = []
    gesamt = len(n.zeiten)
    if laeuft_noch:
        out.append(
            "Der Tag läuft noch. Verglichen sind die abgeschlossenen Viertelstunden; die Zahlen "
            "ändern sich bis Mitternacht."
        )
    if n.n_verglichen < gesamt:
        grund = (
            "Der Rest liegt vor dem ersten aufbewahrten Fahrplan, in der Zukunft oder ohne Messung."
            if gemessen > n.n_verglichen
            else "Für den Rest fehlt der Preis oder die Leistung, oder er liegt in der Zukunft."
        )
        out.append(
            f"Verglichen werden {n.n_verglichen} von {gesamt} Viertelstunden des Tages, und zwar "
            f"für jede Linie dieselben. {grund}"
        )
    je = {x.key: x for x in n.linien}
    ist, letzter = je["wirklich"], je["letzter"]
    if ist.wp_kwh is not None and letzter.wp_kwh is not None:
        out.append(
            f"Die Linien liefern nicht dieselbe Wärme. Der Fahrplan rechnet jede Freigabe mit der "
            f"Nennleistung und kommt auf {_kwh(letzter.wp_kwh)} Strom; gemessen sind "
            f"{_kwh(ist.wp_kwh)}. Der Eingriff der Maschine ist deshalb in Menge und Zeitpunkt "
            "zerlegt, und neben den Euro steht der mittlere Preis der Kilowattstunde: er hängt "
            "nicht an der Menge."
        )
        if _weit_auseinander(ist.wp_kwh, letzter.wp_kwh):
            out.append(
                "Die Mengen liegen weit auseinander. Dann sagt der Abstand in Euro mehr über das "
                "Bedarfsmodell als über den Zeitpunkt: der Fahrplan plant gegen einen Wärmebedarf, "
                "der aus zwei geschätzten Hauswerten kommt, und die Maschine heizt nach ihrer "
                "eigenen Kennlinie."
            )
    out.append(
        "Bewertet wird anteilig: was der Überschuss deckt, kostet die entgangene "
        "Einspeisevergütung, der Rest den Bezugspreis. Der Optimierer zählt gröber, alles oder "
        "nichts; im Prognosefehler steckt deshalb auch der Abstand zwischen beiden Rechnungen. "
        "Der Batteriespeicher kommt in dieser Bewertung nicht vor."
    )
    # Erst ab einem Betrag, der sich zeigen lässt: eine Anlage ohne Grundlast bekommt keinen Satz
    # über null Kilowattstunden.
    if n.standby_eur is not None and n.standby_kwh is not None and n.standby_kwh >= 0.05:
        out.append(
            f"Die Grundlast der Anlage im Stillstand ({_kwh(n.standby_kwh)}, {_eur(n.standby_eur)} "
            "zum Bezugspreis) steht in keiner Linie. Sie hängt an keinem Fahrplan."
        )
    if je["ohne_fuehrung"].verfuegbar:
        out.append(
            "„Ohne Preisblick“ ist eine Schätzung: dieselbe Strommenge wie gemessen, verteilt "
            "nach dem Wärmebedarf der eingetretenen Temperatur. Was ohne Führung wirklich "
            "geschehen wäre, weiß niemand."
        )
    for key in ("versprochen", "erster", "letzter", "perfekt"):
        x = je[key]
        if not x.verfuegbar and x.grund_de:
            out.append(f"Die Linie „{x.name_de}“ fehlt. {x.grund_de}")
    return out
