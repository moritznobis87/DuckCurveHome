"""Die Einstellungen des Reglers der Wärmepumpe: gelesen über den Bus, und stellbar.

Das eBUS-Add-on liest diese Einstellungen (ab 0.4.0) und kann eine feste Auswahl davon stellen
(ab 0.5.0, mit seinem Schalter `stellen`). Hier steht die eine Liste, aus der alles andere folgt:
die Zeilen des Add-ons, die Zuordnung der Bridge, die Grenzen beim Stellen und die Seite „Regler“.

**Vier Sicherungen vor jedem Stellen**, in dieser Reihenfolge geprüft (`pruefen`):

1. Die Einstellung steht in der Liste als stellbar. Was nicht drinsteht, lässt sich von hier nicht
   stellen, auch wenn der Bus es könnte.
2. Sie ist gerade gelesen. Ohne den alten Wert gibt es kein Zurück, und ohne Antwort auf die Frage
   ist nicht einmal gesichert, dass die Kennung an dieser Anlage etwas bedeutet.
3. Jemand hat sie mit dem Bediengerät verglichen und das bestätigt (`bestaetigt`). Die Kennungen
   stammen aus der Bus-Beschreibung einer verwandten Anlage; ob `6a71` hier wirklich die Steilheit
   ist, weiß nur, wer am Gerät nachsieht (die Lehre aus „Puffer kühlen“, `waermepumpe.py`).
4. Der Wert liegt in den Grenzen der Liste und auf ihrem Raster, und es waren heute noch nicht zu
   viele Änderungen (`STELLEN_JE_TAG`): wie viele Schreibvorgänge der Speicher des Reglers
   verträgt, ist nicht bekannt.

Gestellt ist eine Einstellung erst, wenn der Regler sie beim nächsten Lesen so meldet. Die Seite
zeigt bis dahin „gesendet“, nicht den neuen Wert.

Reine Zusammensetzung und Prüfung, kein I/O.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal

from dch_api.schemas import (
    ReglerAenderungOut,
    ReglerEinstellungenOut,
    ReglerEinstellungOut,
    ReglerGesendetOut,
)
from hems_core.domain.measurement import Measurement

#: So lange gilt eine gelesene Einstellung. Jede ist etwa alle zehn bis fünfzehn Minuten dran.
STALE_S = 2700.0
#: So oft am Tag darf eine einzelne Einstellung von hier gestellt werden. Gesetzt.
STELLEN_JE_TAG = 12
#: Der Befehl an die Bridge: `ebus:<Schlüssel>:stellen` mit dem Wert.
BEFEHL = "ebus:{key}:stellen"
#: Unter diesem Namen stehen die Bestätigungen in den Einstellungen des Dienstes.
BESTAETIGT_ART = "regler_bestaetigt"
#: Unter diesem Zeichen stehen die Änderungen im Ereignisprotokoll.
EREIGNIS = "regler.gestellt"
#: So lange wartet die Seite auf die Rückmeldung des Reglers, bevor ein gesendeter Wert als
#: nicht übernommen gilt und verschwindet.
GESENDET_S = 1800.0
#: Ab dieser Fassung kann die Bridge eine Einstellung an den Bus weitergeben.
BRIDGE_AB = (0, 15, 0)

Art = Literal["zahl", "wahl", "schalter"]


@dataclass(frozen=True)
class Einstellung:
    key: str
    #: Der Name der Nachricht im Add-on (`energymgr/<thema>`).
    thema: str
    name_de: str
    gruppe_de: str
    kennung: str
    #: Zahlenformat auf dem Bus: Typ und Teiler, wie ebusd sie nennt.
    typ: str
    teiler: str = ""
    einheit: str = ""
    stellen: int = 1
    art: Art = "zahl"
    #: Grenzen und Raster beim Stellen. Ohne sie ist die Einstellung nur zu lesen.
    von: float | None = None
    bis: float | None = None
    schritt: float | None = None
    #: Was die Bus-Beschreibung zu den Zahlen sagt. Nicht im Haus bestätigt.
    lesart: dict[int, str] = field(default_factory=dict)
    #: Die Zeile zum Stellen steht nicht in der Bus-Beschreibung, sondern ist nach dem Muster der
    #: übrigen gebildet (Rundruf, Dienst 2020, dieselbe Kennung wie beim Lesen).
    muster: bool = False
    hinweis_de: str = ""

    @property
    def stellbar(self) -> bool:
        return self.von is not None and self.bis is not None and self.schritt is not None


def _e(
    key: str, thema: str, name: str, gruppe: str, kennung: str, typ: str, **kw: object
) -> Einstellung:
    return Einstellung(f"heat_pump_set_{key}", f"e_{thema}", name, gruppe, kennung, typ, **kw)  # type: ignore[arg-type]


GRAD = {"teiler": "10", "einheit": "°C"}

EINSTELLUNGEN: tuple[Einstellung, ...] = (
    # --- Heizkurve der ersten Zone
    _e(
        "slope",
        "steilheit",
        "Steilheit",
        "Heizkurve",
        "6a71",
        "UIN",
        teiler="100",
        stellen=2,
        von=0.2,
        bis=3.5,
        schritt=0.1,
    ),
    _e(
        "offset_k",
        "verschiebung",
        "Verschiebung",
        "Heizkurve",
        "6471",
        "SCH",
        teiler="10",
        einheit="K",
        von=-7.0,
        bis=7.0,
        schritt=0.5,
    ),
    _e(
        "flow_max_c",
        "vorlauf_max",
        "Vorlauf höchstens",
        "Heizkurve",
        "6071",
        "SIN",
        **GRAD,
        von=25.0,
        bis=60.0,
        schritt=1.0,
    ),
    _e(
        "flow_min_c",
        "vorlauf_min",
        "Vorlauf mindestens",
        "Heizkurve",
        "6171",
        "SIN",
        **GRAD,
        von=20.0,
        bis=45.0,
        schritt=1.0,
    ),
    _e(
        "flow_fixed_c",
        "vorlauf_fest",
        "Vorlauf fest",
        "Heizkurve",
        "6571",
        "SIN",
        **GRAD,
        von=20.0,
        bis=60.0,
        schritt=1.0,
        hinweis_de="Gilt nur, wenn die Art der Vorlaufregelung „fester Vorlauf“ ist.",
    ),
    _e(
        "room_influence",
        "raumeinfluss",
        "Einfluss der Raumtemperatur",
        "Heizkurve",
        "c279",
        "UCH",
        stellen=0,
        von=0.0,
        bis=20.0,
        schritt=1.0,
    ),
    _e(
        "curve_type",
        "heizkurve_art",
        "Art der Vorlaufregelung",
        "Heizkurve",
        "c079",
        "UCH",
        stellen=0,
        art="wahl",
        lesart={
            0: "fester Vorlauf",
            1: "ein und aus nach Raumthermostat",
            2: "nach Außentemperatur",
            3: "nach Raumtemperatur",
            4: "nach Außen- und Raumtemperatur",
        },
    ),
    _e(
        "temp_range",
        "temperaturbereich",
        "Temperaturbereich",
        "Heizkurve",
        "0081",
        "UCH",
        stellen=0,
        art="wahl",
        lesart={0: "niedrig (Fußbodenheizung)", 1: "hoch (Heizkörper)"},
    ),
    _e(
        "flow_correction_k",
        "vorlauf_korrektur",
        "Korrektur des Vorlaufs",
        "Heizkurve",
        "7d2b",
        "SIN",
        teiler="10",
        einheit="K",
    ),
    # --- Raum
    _e(
        "room_day_c",
        "raum_tag",
        "Raumtemperatur Tag",
        "Raum",
        "6271",
        "SIN",
        **GRAD,
        von=10.0,
        bis=30.0,
        schritt=0.5,
    ),
    _e(
        "room_night_c",
        "raum_nacht",
        "Raumtemperatur Nacht",
        "Raum",
        "6371",
        "SIN",
        **GRAD,
        von=10.0,
        bis=30.0,
        schritt=0.5,
    ),
    # --- Warmwasser
    _e(
        "dhw_comfort_c",
        "ww_komfort",
        "Komforttemperatur",
        "Warmwasser",
        "6126",
        "SIN",
        **GRAD,
        von=35.0,
        bis=60.0,
        schritt=1.0,
    ),
    _e(
        "dhw_eco_c",
        "ww_spar",
        "Spartemperatur",
        "Warmwasser",
        "6226",
        "SIN",
        **GRAD,
        von=20.0,
        bis=55.0,
        schritt=1.0,
    ),
    _e(
        "dhw_mode",
        "ww_art",
        "Betriebsart",
        "Warmwasser",
        "c028",
        "UCH",
        stellen=0,
        art="wahl",
        von=0.0,
        bis=2.0,
        schritt=1.0,
        lesart={0: "aus", 1: "nach Zeitprogramm", 2: "immer an"},
    ),
    _e(
        "dhw_cleansing",
        "ww_legionellen",
        "Legionellenprogramm",
        "Warmwasser",
        "0b20",
        "UCH",
        stellen=0,
        art="schalter",
        von=0.0,
        bis=1.0,
        schritt=1.0,
        lesart={0: "aus", 1: "an"},
    ),
    _e(
        "dhw_pv_delta_k",
        "ww_pv_delta",
        "Zuschlag bei Sonnenstrom",
        "Warmwasser",
        "762d",
        "SIN",
        teiler="10",
        einheit="K",
    ),
    # --- Betrieb
    _e(
        "heat_mode",
        "heizbetrieb",
        "Heizbetrieb",
        "Betrieb",
        "1c22",
        "UCH",
        stellen=0,
        art="wahl",
        von=0.0,
        bis=1.0,
        schritt=1.0,
        lesart={0: "Green", 1: "Standard"},
        muster=True,
        hinweis_de="Im Betrieb „Green“ soll der elektrische Heizstab nicht für die Heizung "
        "zuschalten. Das ist die Auskunft des Hausherrn, an dieser Anlage noch nicht gesehen.",
    ),
    _e(
        "silent",
        "fluester",
        "Flüstermodus",
        "Betrieb",
        "0320",
        "UCH",
        stellen=0,
        art="schalter",
        von=0.0,
        bis=1.0,
        schritt=1.0,
        lesart={0: "aus", 1: "an"},
    ),
    _e(
        "comfort_level",
        "komfortstufe",
        "Komfortstufe",
        "Betrieb",
        "c728",
        "UCH",
        stellen=0,
        art="wahl",
        lesart={0: "Eco", 1: "Eco plus", 2: "Mittel", 3: "Komfort", 4: "Komfort plus"},
    ),
    _e(
        "pump_mode",
        "pumpe",
        "Umwälzpumpe",
        "Betrieb",
        "c32a",
        "UCH",
        stellen=0,
        art="wahl",
        lesart={0: "kleine Stufe", 1: "große Stufe", 2: "geregelt"},
    ),
    _e("disable_below_c", "wp_aus_unter", "Wärmepumpe aus unter", "Betrieb", "7226", "SIN", **GRAD),
    _e("summer_above_c", "sommer_ab", "Sommerbetrieb ab", "Betrieb", "7971", "SIN", **GRAD),
)

NACH_KEY: dict[str, Einstellung] = {e.key: e for e in EINSTELLUNGEN}


def zeile_lesen(e: Einstellung) -> str:
    """Die Zeile des Add-ons zum Abfragen (`aerotop_abfragen.csv`)."""
    return (
        f"r9,energymgr,{e.thema},{_ascii(e.name_de)},,18,2000,{e.kennung},,s,IGN:1,,,,"
        f"wert,s,{e.typ},{e.teiler},{e.einheit},"
    )


def zeile_stellen(e: Einstellung) -> str:
    """Die Zeile des Add-ons zum Stellen (`aerotop_stellen.csv`): ein Rundruf mit dem Dienst
    2020, der Kennung und dem Wert, so wie das Bediengerät eine Einstellung ändert."""
    return (
        f"w,energymgr,{e.thema},{_ascii(e.name_de)},,fe,2020,{e.kennung},"
        f"wert,m,{e.typ},{e.teiler},{e.einheit},"
    )


def _ascii(text: str) -> str:
    for a, b in (
        ("ä", "ae"),
        ("ö", "oe"),
        ("ü", "ue"),
        ("ß", "ss"),
        ("Ä", "Ae"),
        ("Ö", "Oe"),
        ("Ü", "Ue"),
    ):
        text = text.replace(a, b)
    return text


def runde(e: Einstellung, wert: float) -> float:
    """Der Wert auf dem Raster der Einstellung."""
    assert e.schritt is not None and e.von is not None
    return round(e.von + round((wert - e.von) / e.schritt) * e.schritt, 4)


def pruefen(
    e: Einstellung | None,
    wert: float,
    *,
    gelesen: Measurement | None,
    bestaetigt: bool,
    heute_gestellt: int,
) -> str | None:
    """Warum sich die Einstellung jetzt nicht auf diesen Wert stellen lässt, als Satz. `None`:
    es spricht nichts dagegen."""
    if e is None:
        return "Diese Einstellung ist nicht bekannt."
    if not e.stellbar:
        return f"„{e.name_de}“ lässt sich von hier nur lesen."
    if gelesen is None or not gelesen.usable or gelesen.value is None:
        return (
            f"„{e.name_de}“ ist gerade nicht gelesen. Ohne den jetzigen Wert wird nichts "
            "gestellt: es gäbe kein Zurück."
        )
    if not bestaetigt:
        return (
            f"„{e.name_de}“ ist noch nicht mit dem Bediengerät verglichen. Erst wenn die Zahl "
            "hier mit der am Gerät übereinstimmt und das bestätigt ist, lässt sie sich stellen."
        )
    assert e.von is not None and e.bis is not None
    if not e.von <= wert <= e.bis:
        return (
            f"„{e.name_de}“ lässt sich von hier nur zwischen {_de(e, e.von)} und "
            f"{_de(e, e.bis)} stellen."
        )
    if abs(runde(e, wert) - wert) > 1e-6:
        return f"„{e.name_de}“ lässt sich nur in Schritten von {_de(e, e.schritt or 0)} stellen."
    if heute_gestellt >= STELLEN_JE_TAG:
        return (
            f"„{e.name_de}“ wurde heute schon {heute_gestellt}-mal gestellt. Mehr als "
            f"{STELLEN_JE_TAG} Änderungen am Tag lässt diese Seite nicht zu."
        )
    return None


def _de(e: Einstellung, wert: float) -> str:
    text = f"{wert:.{e.stellen}f}".replace(".", ",").replace("-", "−")
    return f"{text} {e.einheit}".strip()


def text(e: Einstellung, wert: float | None) -> str:
    """Ein Wert, wie ihn ein Satz nennt: mit Einheit, bei Kennzahlen mit der Lesart der Liste."""
    if wert is None:
        return "unbekannt"
    if e.lesart and round(wert) in e.lesart:
        return f"{round(wert)} ({e.lesart[round(wert)]})"
    return _de(e, wert)


def zusammensetzen(
    *,
    now: datetime,
    mess: Callable[[str], Measurement],
    bestaetigt: Mapping[str, object] | None = None,
    stellen_moeglich: bool = False,
    hindernis_de: str | None = None,
    gesendet: Mapping[str, tuple[float, datetime]] | None = None,
    protokoll: list[ReglerAenderungOut] | None = None,
    vorfuehrung: bool = False,
) -> ReglerEinstellungenOut:
    bestaetigt = bestaetigt or {}
    gesendet = gesendet or {}
    werte = []
    for e in EINSTELLUNGEN:
        m = mess(e.key)
        zahl = m.value if m.usable else None
        werte.append(
            ReglerEinstellungOut(
                schluessel=e.key,
                name_de=e.name_de,
                gruppe_de=e.gruppe_de,
                kennung=e.kennung,
                einheit=e.einheit,
                stellen=e.stellen,
                wert=m,
                lesart_de=e.lesart.get(round(zahl)) if zahl is not None and e.lesart else None,
                art=e.art,
                stellbar=e.stellbar,
                von=e.von,
                bis=e.bis,
                schritt=e.schritt,
                wahl={str(k): v for k, v in e.lesart.items()},
                bestaetigt=e.key in bestaetigt,
                muster=e.muster,
                hinweis_de=e.hinweis_de,
                gesendet=ReglerGesendetOut(wert=gesendet[e.key][0], at=gesendet[e.key][1])
                if e.key in gesendet
                else None,
            )
        )
    gelesen = sum(1 for w in werte if w.wert.usable)
    hinweise = [
        "Gelesen über den Bus, jede Einstellung etwa alle zehn bis fünfzehn Minuten. Nach dem "
        "Stellen wird sofort neu gelesen; erst was der Regler dann meldet, gilt als gestellt.",
        "Kennungen und Zahlenformate stammen aus der Busbeschreibung einer verwandten Anlage. "
        "Stimmt ein Wert nicht mit dem Bediengerät überein, ist die Kennung für diese Anlage "
        "falsch gelesen; eine solche Einstellung bitte nicht bestätigen und nicht stellen.",
        f"Jede Einstellung lässt sich höchstens {STELLEN_JE_TAG}-mal am Tag stellen. Wie viele "
        "Schreibvorgänge der Speicher des Reglers verträgt, ist nicht bekannt.",
    ]
    if vorfuehrung:
        hinweise.insert(0, "Vorführung: die Einstellungen sind erfunden; gestellt wird nichts.")
    if gelesen == 0:
        satz = (
            "Noch keine Einstellung gelesen. Das eBUS-Add-on fragt sie ab Fassung 0.4.0 ab; "
            "danach braucht die Bridge einen Neustart."
        )
    elif gelesen < len(werte):
        satz = (
            f"{gelesen} von {len(werte)} Einstellungen gelesen. Die übrigen beantwortet der Regler "
            "nicht oder noch nicht."
        )
    else:
        satz = f"Alle {len(werte)} Einstellungen gelesen."
    return ReglerEinstellungenOut(
        now=now,
        gelesen=gelesen,
        satz_de=satz,
        werte=werte,
        stellen_moeglich=stellen_moeglich,
        hindernis_de=hindernis_de,
        stellen_je_tag=STELLEN_JE_TAG,
        protokoll=protokoll or [],
        hinweise_de=hinweise,
    )


def offen(
    gesendet: Mapping[str, tuple[float, datetime]],
    mess: Callable[[str], Measurement],
    now: datetime,
) -> dict[str, tuple[float, datetime]]:
    """Welche gesendeten Werte noch auf ihre Rückmeldung warten.

    Erledigt ist einer, wenn der Regler nach dem Senden genau diesen Wert gemeldet hat. Nach
    `GESENDET_S` ohne das gilt er als nicht übernommen und verschwindet ebenfalls: die Seite zeigt
    dann wieder nur, was gelesen ist.
    """
    aus: dict[str, tuple[float, datetime]] = {}
    for key, (wert, at) in gesendet.items():
        m = mess(key)
        gemeldet = (
            m.usable
            and m.value is not None
            and m.observed_at is not None
            and m.observed_at >= at
            and abs(m.value - wert) < 1e-6
        )
        if not gemeldet and (now - at).total_seconds() <= GESENDET_S:
            aus[key] = (wert, at)
    return aus


def aenderung(
    at: datetime, context: Mapping[str, object], urheber_de: str | None
) -> ReglerAenderungOut | None:
    """Eine Zeile des Protokolls aus einem gespeicherten Ereignis."""
    e = NACH_KEY.get(str(context.get("key")))
    if e is None:
        return None

    def zahl(v: object) -> float | None:
        return float(v) if isinstance(v, int | float) else None

    return ReglerAenderungOut(
        at=at,
        schluessel=e.key,
        name_de=f"{e.gruppe_de}: {e.name_de}",
        von_de=text(e, zahl(context.get("from"))),
        auf_de=text(e, zahl(context.get("to"))),
        urheber_de=urheber_de,
    )


def vorfuehrung() -> dict[str, float]:
    """Einstellungen für die Vorführung: eine Heizkurve, die zu der der Seite „Betrieb“ passt."""
    return {
        "heat_pump_set_slope": 0.7,
        "heat_pump_set_offset_k": 0.0,
        "heat_pump_set_flow_max_c": 55.0,
        "heat_pump_set_flow_min_c": 20.0,
        "heat_pump_set_flow_fixed_c": 40.0,
        "heat_pump_set_room_influence": 0.0,
        "heat_pump_set_curve_type": 2.0,
        "heat_pump_set_temp_range": 0.0,
        "heat_pump_set_flow_correction_k": 0.0,
        "heat_pump_set_room_day_c": 21.0,
        "heat_pump_set_room_night_c": 17.0,
        "heat_pump_set_dhw_comfort_c": 52.0,
        "heat_pump_set_dhw_eco_c": 42.0,
        "heat_pump_set_dhw_mode": 1.0,
        "heat_pump_set_dhw_cleansing": 0.0,
        "heat_pump_set_dhw_pv_delta_k": 5.0,
        "heat_pump_set_heat_mode": 1.0,
        "heat_pump_set_silent": 0.0,
        "heat_pump_set_comfort_level": 2.0,
        "heat_pump_set_pump_mode": 2.0,
        "heat_pump_set_disable_below_c": -20.0,
        "heat_pump_set_summer_above_c": 18.0,
    }
