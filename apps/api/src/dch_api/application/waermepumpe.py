"""Die Wärmepumpe im Augenblick: alles, was ihr eigener Bus und der Zähler melden, an einer Stelle.

**Woher die Werte kommen.** Seit dem 13.11.2026 hängt ein Adapter am Bus der Wärmepumpe (ELCO
Aerotop Split), und die Bridge liefert, was dort mitzulesen ist: Außentemperatur, Verdampfer,
Sauggas, Heißgas, Flüssigkeitsleitung, Verdichterfrequenz, Vorlauf, Rücklauf, Durchfluss,
Sollwert und die Leistungsaufnahme nach Auskunft der Maschine. Die gemessene Leistungsaufnahme
kommt weiter vom Zähler an der Zuleitung, die Puffertemperaturen von den eigenen Fühlern.
Herkunft und Vorbehalte je Größe: `docs/SENSORIK.md`.

**Was hier gerechnet wird, ist eine Abschätzung, und so heißt es auch.**

- Spreizung = Vorlauf minus Rücklauf.
- Wärmeleistung = Durchfluss mal Spreizung mal Wärmekapazität des Wassers (4,186 kJ/(kg K),
  ein Liter als ein Kilogramm gerechnet).
- Arbeitszahl = Wärmeleistung durch Leistungsaufnahme, mit dem Zähler, wo er einen Wert hat,
  sonst mit der Auskunft der Maschine.

Drei Dinge daran sind nicht gesichert (Stand 14.11.2026): Der Durchflussgeber ist nicht geeicht
und seine Einheit als Liter je Minute gelesen. Welche Kennung des Busses der Rücklauf ist, ist
begründet, nicht bestätigt. Und die Werte kommen nicht gleichzeitig, sondern im Abstand von
Sekunden bis zu einer Minute. Eine Arbeitszahl aus diesen Zahlen ist deshalb ein Anhalt.

Reine Zusammensetzung, kein I/O.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, tzinfo

from dch_api.schemas import WaermepumpeOut
from hems_core.domain import EnergySnapshot, Measurement
from hems_core.thermal.kennlinie import (
    KW_JE_L_MIN_K,
    MIN_DURCHFLUSS,
    MIN_LEISTUNG_KW,
    MIN_SPREIZUNG_K,
)

#: So alt darf ein Wert vom Bus sein. ebusd gibt nicht jeden Wert in jedem Takt weiter; gemessen
#: lagen bis zu 55 Sekunden zwischen zwei Meldungen desselben Werts.
STALE_S = 900.0
# Die Wärmerechnung und ihre Grenzen stehen im Kern, weil die Kennlinie dieselben braucht:
# `hems_core.thermal.kennlinie`. Hier nur unter ihrem alten Namen weitergereicht.
__all__ = ["KW_JE_L_MIN_K", "MIN_DURCHFLUSS", "MIN_LEISTUNG_KW", "MIN_SPREIZUNG_K"]

#: Der Betriebszustand, wie die Maschine ihn als Zahl meldet. Die Wörter der fremden Liste sind
#: Englisch und an einer Stelle irreführend: 15 heißt dort „Soft_fail" und ist an dieser Anlage
#: der gewöhnliche Stillstand.
ZUSTAND_DE: dict[int, str] = {
    0: "aus",
    1: "in Bereitschaft",
    2: "kühlt",
    3: "heizt",
    4: "heizt mit voller Leistung",
    5: "kühlt mit voller Leistung",
    8: "schützt vor Frost",
    9: "taut ab",
    10: "schützt sich vor Übertemperatur",
    11: "wartet die Sperrzeit ab",
    12: "meldet eine Störung",
    15: "steht",
}
#: Zustände, in denen der Verdichter arbeitet.
ARBEITET = frozenset({2, 3, 4, 5, 9})

KEYS = {
    "verdampfer_c": "heat_pump_evaporator_temp_c",
    "sauggas_c": "heat_pump_suction_temp_c",
    "heissgas_c": "heat_pump_discharge_temp_c",
    "fluessig_c": "heat_pump_liquid_temp_c",
    "verdichter_hz": "heat_pump_compressor_hz",
    "leistung_bus_kw": "heat_pump_bus_power_kw",
    "vorlauf_c": "flow_temp_c",
    "ruecklauf_c": "heat_pump_return_temp_c",
    "durchfluss_l_min": "heat_pump_flow_l_min",
    "vorlauf_soll_c": "heat_pump_flow_setpoint_c",
    "speicherfuehler_c": "heat_pump_tank_temp_c",
}
ZUSTAND_KEY = "heat_pump_mode_code"

#: Die Betriebsart des Reglers (Kennung c94b des Busses), wie er sie im Rundruf nennt. Die
#: Wörter der fremden Liste sind Englisch („hybrid_status"); gesehen wurden im Haus bisher 0 im
#: Stillstand und 16 im Lauf der Nacht vom 13. auf den 14.11.2026.
KREIS_KEY = "heat_pump_cycle_code"
KREIS_DE: dict[int, str] = {
    0: "Bereitschaft",
    1: "Frostschutz",
    2: "Heizen",
    3: "Warmwasser",
    4: "Legionellenschutz",
    5: "Entlüften",
    7: "Estrichtrocknung",
    8: "keine Wärmeerzeugung",
    9: "Handbetrieb",
    10: "Störung oder Handbetrieb",
    11: "Start",
    12: "aus",
    14: "Kühlen",
    15: "Frostschutz Warmwasser",
    16: "PV-Nutzung",
    17: "Entfeuchten",
    19: "Puffer heizen und Warmwasser",
    20: "Puffer kühlen und Warmwasser",
}
#: Wohin die Maschine in dieser Betriebsart einspeist (Auskunft des Hausherrn, 14.11.2026): bei
#: der Warmwasserbereitung oben in den Speicher, im Heizbetrieb tiefer. Für die übrigen
#: Betriebsarten ist es nicht bekannt, auch nicht für die PV-Nutzung; dort steht nichts.
EINSPEISUNG: dict[int, str] = {3: "oben", 4: "oben", 15: "oben", 2: "tiefer", 7: "tiefer"}


#: Ab dieser Bridge kommt die Lage des Busses mit (`DeviceHealthFrame`, Quelle `ebusd`).
BRIDGE_MIT_LAGE = (0, 14, 2)
#: Daran, dass die Bridge diesen Schlüssel ankündigt, ist zu erkennen, dass ihre Zuordnung den
#: Bus kennt. Er steht seit dem ersten Stand der Zuordnung darin.
BUS_KENNZEICHEN = "heat_pump_flow_l_min"


@dataclass(frozen=True)
class BusStand:
    """Was der Dienst über den Weg der Buswerte weiß, wenn keiner da ist."""

    bridge_online: bool
    bridge_version: str | None = None
    #: Die Schlüssel, die die Bridge beim Handschlag angekündigt hat.
    angekuendigt: frozenset[str] = frozenset()
    #: Das Wort der Bridge (`ebusd_mqtt.LAGEN`), `None`, solange sie keines gemeldet hat.
    lage: str | None = None
    einzelheiten: dict[str, str] = field(default_factory=dict)
    #: Wann zuletzt irgendein Wert vom Bus kam, gleich wie alt.
    zuletzt: datetime | None = None
    #: Woher die Bridge ihre Zuordnung hat (ab 0.14.3): `herkunft` (datei, repository,
    #: zwischenspeicher, datei+repository, datei+zwischenspeicher), `ort`, gegebenenfalls `grund`.
    zuordnung: dict[str, str] = field(default_factory=dict)


def _version(text: str | None) -> tuple[int, ...]:
    teile: list[int] = []
    for teil in (text or "").split("."):
        if not teil.isdigit():
            break
        teile.append(int(teil))
    return tuple(teile)


#: Die Lage der Bridge als Satz. Jeder nennt die Stelle und was dort nachzusehen ist.
LAGE_DE: dict[str, str] = {
    "broker_getrennt": (
        "Die Brücke im Haus kommt nicht an den Mosquitto-Broker. Adresse, Benutzer und Passwort "
        "stehen in den Einstellungen des Add-ons „Duck Curve Bridge“."
    ),
    "kein_wort": (
        "Die Brücke ist am Broker angemeldet, aber unter „{thema}“ kommt dort nichts an. Läuft "
        "das Add-on „Duck Curve eBUS“, und ist bei ihm derselbe Broker und dasselbe Thema "
        "eingestellt?"
    ),
    "verstummt": (
        "Am Broker kommt vom Add-on „Duck Curve eBUS“ nichts mehr an. Läuft es noch, und "
        "erreicht es den Adapter?"
    ),
    "kein_signal": (
        "Das Add-on „Duck Curve eBUS“ läuft, hört aber kein Signal vom Bus der Wärmepumpe. Ist "
        "der Adapter eingeschaltet und im WLAN?"
    ),
    "nicht_zugeordnet": (
        "Vom Bus kommen Nachrichten ({nachrichten} bisher, {namen} verschiedene), aber keine, "
        "die einem Wert dieser Seite zugeordnet ist."
    ),
    "nur_mitlesen": (
        "Die Brücke liest die Werte vom Bus, gibt sie aber nicht weiter: in ihren Einstellungen "
        "steht „source_mode“ auf „{source_mode}“ statt auf „mqtt“."
    ),
    "abgeschaltet": (
        "Die Brücke liest den Broker nicht: in ihren Einstellungen steht „source_mode“ auf "
        "„{source_mode}“ statt auf „mqtt“."
    ),
    "ok": (
        "Die Brücke meldet, dass Werte vom Bus bei ihr ankommen. Hier sind sie noch nicht; das "
        "sollte sich binnen einer Minute geben."
    ),
}


def bus_auskunft(stand: BusStand, tz: tzinfo) -> str:
    """Ein Satz, warum kein Wert vom Bus da ist. Genannt wird die erste Stelle, an der es hängt.

    Der Weg ist: Adapter am Bus, Add-on „Duck Curve eBUS", Broker, Bridge, Dienst. Der Dienst
    sieht nur sein Ende und was die Bridge über ihres sagt; mehr behauptet der Satz nicht.
    """
    nach = ""
    if stand.zuletzt is not None:
        ort = stand.zuletzt.astimezone(tz)
        nach = f" Der letzte Wert vom Bus kam am {ort:%d.%m.} um {ort:%H:%M} Uhr."
    if not stand.bridge_online:
        return "Die Brücke im Haus ist gerade nicht verbunden; ohne sie kommt kein Wert." + nach
    version = stand.bridge_version or "unbekannt"
    if BUS_KENNZEICHEN not in stand.angekuendigt:
        ohne = (
            f"Die Brücke im Haus (Version {version}) arbeitet mit einer Zuordnung, die den Bus der "
            "Wärmepumpe nicht kennt. "
        )
        art, wo = stand.zuordnung.get("herkunft"), stand.zuordnung.get("ort", "")
        grund = stand.zuordnung.get("grund")
        klammer = f" ({grund})" if grund else ""
        if art == "datei":
            # Ab 0.14.3 gilt die Datei nur noch allein, wenn sie es verlangt oder das Repository
            # beim Start nicht zu erreichen war.
            warum = (
                f"das Repository war beim Start nicht zu erreichen{klammer}; Brücke neu starten."
                if grund
                else "sie schließt das Repository mit „ersetzt_repository“ aus; die Zeile "
                "entfernen und die Brücke neu starten."
            )
            return (
                ohne + f"Es gilt allein die Datei {wo} in Home Assistant, und dort fehlt der "
                f"Bus: {warum}" + nach
            )
        if art == "zwischenspeicher":
            return (
                ohne + f"Die aktuelle konnte sie beim Start nicht aus dem Repository holen{klammer}"
                " und nimmt deshalb ihren letzten Abruf. Brücke neu starten; bleibt es dabei, "
                "erreicht Home Assistant die Adresse nicht." + nach
            )
        if art is not None:
            return (
                ohne + "Weder ihre Datei in Home Assistant noch die Zuordnung unter der Adresse "
                "„entities_url“ in ihren Einstellungen enthält ihn." + nach
            )
        return (
            ohne + "Vermutlich liegt in Home Assistant eine eigene Datei "
            "/config/duckcurve/entities.yaml ohne den Bus. Ab Version 0.14.3 nimmt die Brücke die "
            "Zuordnung aus dem Repository zu dieser Datei dazu: das Update genügt." + nach
        )
    if stand.lage is not None:
        einzel = {"thema": "ebusd", "nachrichten": "?", "namen": "?", "source_mode": "?"}
        einzel |= stand.einzelheiten
        satz = LAGE_DE.get(stand.lage)
        if satz is not None:
            return satz.format(**einzel) + nach
    if _version(stand.bridge_version) < BRIDGE_MIT_LAGE:
        return (
            f"Die Brücke im Haus (Version {version}) kennt den Bus der Wärmepumpe, liefert aber "
            "keinen Wert. Woran es liegt, sagt sie ab Version 0.14.2; bis dahin steht es in ihrem "
            "Protokoll in den Zeilen mit „mqtt“ und „ebusd“." + nach
        )
    return (
        "Die Brücke im Haus kennt den Bus der Wärmepumpe, hat aber noch nicht gemeldet, woran es "
        "liegt. Das kommt spätestens fünf Minuten nach ihrem Start." + nach
    )


def zustand_wort(code: int | None, laeuft: bool) -> str:
    if code is None:
        return "läuft" if laeuft else "steht"
    return ZUSTAND_DE.get(code, f"Zustand {code}")


def zusammensetzen(
    *,
    now: datetime,
    snap: EnergySnapshot,
    laeuft_laut_zaehler: bool,
    mess: Callable[[str], Measurement],
    bus_stumm_de: str | None = None,
) -> WaermepumpeOut:
    """`bus_stumm_de` ist der Satz für den Fall, dass kein Wert vom Bus da ist (`bus_auskunft`);
    ohne ihn steht dort die allgemeine Frage nach Add-on und Adapter."""
    werte = {feld: mess(key) for feld, key in KEYS.items()}
    zustand = mess(ZUSTAND_KEY)
    kreis = mess(KREIS_KEY)
    kreis_code = round(kreis.value) if kreis.usable and kreis.value is not None else None
    code = round(zustand.value) if zustand.usable and zustand.value is not None else None
    hz = werte["verdichter_hz"]
    if code is not None:
        laeuft = code in ARBEITET
    elif hz.usable and hz.value is not None:
        laeuft = hz.value > 0
    else:
        laeuft = laeuft_laut_zaehler

    vor, rueck, fluss = werte["vorlauf_c"], werte["ruecklauf_c"], werte["durchfluss_l_min"]
    spreizung: float | None = None
    waerme: float | None = None
    zahl: float | None = None
    if vor.usable and rueck.usable and vor.value is not None and rueck.value is not None:
        spreizung = round(vor.value - rueck.value, 1)
    pumpe_laeuft = fluss.usable and fluss.value is not None and fluss.value >= MIN_DURCHFLUSS
    if (
        pumpe_laeuft
        and laeuft
        and fluss.value is not None
        and spreizung is not None
        and spreizung >= MIN_SPREIZUNG_K
    ):
        waerme = round(fluss.value * spreizung * KW_JE_L_MIN_K, 2)
    zaehler = snap.heat_pump_power_kw
    bus = werte["leistung_bus_kw"]
    aufnahme = (
        zaehler.value
        if zaehler.usable and zaehler.value is not None
        else bus.value
        if bus.usable
        else None
    )
    if waerme is not None and aufnahme is not None and aufnahme >= MIN_LEISTUNG_KW:
        zahl = round(waerme / aufnahme, 1)

    hinweise: list[str] = []
    stumm: str | None = None
    if not any(m.usable for m in werte.values()) and not zustand.usable:
        stumm = bus_stumm_de or (
            "Vom Bus der Wärmepumpe kommt gerade nichts. Läuft das Add-on „Duck Curve eBUS“, "
            "und ist der Adapter erreichbar?"
        )
    else:
        hinweise.append(
            "Wärmeleistung und Arbeitszahl sind Abschätzungen: Der Durchflussgeber der Maschine "
            "ist nicht geeicht, und welcher Wert des Busses der Rücklauf ist, ist begründet, "
            "aber nicht bestätigt."
        )
        if laeuft and waerme is None:
            hinweise.append(
                "Für eine Wärmeleistung fehlt gerade ein Wert: Durchfluss, Vorlauf oder Rücklauf."
            )
        if pumpe_laeuft and kreis_code is not None and kreis_code not in EINSPEISUNG:
            hinweise.append(
                "Wohin die Wärmepumpe gerade in den Speicher einspeist, ist für die Betriebsart "
                f"„{KREIS_DE.get(kreis_code, kreis_code)}“ nicht bekannt. Die Stellung des "
                "Umschaltventils selbst sendet der Bus nicht."
            )
    einspeisung = EINSPEISUNG.get(kreis_code) if kreis_code is not None and pumpe_laeuft else None
    t = snap.buffer_temps_c
    return WaermepumpeOut(
        now=now,
        laeuft=laeuft,
        zustand_code=code,
        zustand_de=zustand_wort(code, laeuft),
        pumpe_laeuft=bool(pumpe_laeuft),
        aussen_c=snap.outdoor_temp_c,
        leistung_zaehler_kw=zaehler,
        puffer_c=[t.top, t.mid_top, t.mid_bottom, t.bottom],
        spreizung_k=spreizung,
        waermeleistung_kw=waerme,
        arbeitszahl=zahl,
        kreis_code=kreis_code,
        kreis_de=None
        if kreis_code is None
        else KREIS_DE.get(kreis_code, f"Betriebsart {kreis_code}"),
        einspeisung=einspeisung,
        bus_stumm_de=stumm,
        hinweise_de=hinweise,
        **werte,
    )


def vorfuehrung(
    *,
    laeuft: bool,
    aussen_c: float,
    leistung_kw: float,
    puffer_oben_c: float,
    puffer_unten_c: float,
) -> dict[str, float]:
    """Was der Bus in der Vorführung meldete: stimmige Zahlen aus dem Zustand des Modellhauses.

    Die Vorführung hat keinen Bus. Damit die Seite dort nicht leer ist, entstehen die Größen aus
    dem, was das Modell weiß, mit runden Annahmen: Arbeitszahl 4,2, Durchfluss 29,5 l/min.
    """
    if laeuft:
        waerme = max(leistung_kw, 0.5) * 4.2
        ruecklauf = max(puffer_unten_c, 24.0)
        vorlauf = ruecklauf + waerme / (29.5 * KW_JE_L_MIN_K)
        return {
            "heat_pump_mode_code": 3.0,
            "heat_pump_cycle_code": 2.0,
            "heat_pump_compressor_hz": round(30.0 + 12.0 * max(leistung_kw, 0.5), 0),
            "heat_pump_flow_l_min": 29.5,
            "flow_temp_c": round(vorlauf, 1),
            "heat_pump_return_temp_c": round(ruecklauf, 1),
            "heat_pump_flow_setpoint_c": 45.0,
            "heat_pump_bus_power_kw": round(leistung_kw * 0.97, 3),
            "heat_pump_evaporator_temp_c": round(aussen_c - 4.5, 1),
            "heat_pump_suction_temp_c": round(aussen_c - 1.5, 1),
            "heat_pump_discharge_temp_c": round(vorlauf + 28.0, 1),
            "heat_pump_liquid_temp_c": round(ruecklauf + 0.6, 1),
            "heat_pump_tank_temp_c": round(puffer_oben_c, 1),
        }
    return {
        "heat_pump_mode_code": 15.0,
        "heat_pump_cycle_code": 0.0,
        "heat_pump_compressor_hz": 0.0,
        "heat_pump_flow_l_min": 0.0,
        "flow_temp_c": round(puffer_unten_c + 1.5, 1),
        "heat_pump_return_temp_c": round(puffer_unten_c + 0.5, 1),
        "heat_pump_flow_setpoint_c": 45.0,
        "heat_pump_bus_power_kw": 0.0,
        "heat_pump_evaporator_temp_c": round(aussen_c + 0.5, 1),
        "heat_pump_suction_temp_c": round(aussen_c + 2.0, 1),
        "heat_pump_discharge_temp_c": round(aussen_c + 12.0, 1),
        "heat_pump_liquid_temp_c": round(puffer_unten_c - 2.0, 1),
        "heat_pump_tank_temp_c": round(puffer_oben_c, 1),
    }
