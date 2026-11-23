"""
Zuordnung vorschlagen: welche Entitaet welche Messgroesse ist (docs/ALFRED.md, "Einrichtung").

Fuer ein neues Haus ist `entities.yaml` die muehsamste Stelle: Aus einer Liste von zweihundert
Entitaeten die zwanzig herauszufinden, die Duck Curve Home braucht, und Einheit und Vorzeichen
richtig zu setzen. Alfred schlaegt die Zuordnung vor; der Dienst prueft jede Zeile gegen einen
festen Katalog, und heraus kommt ein YAML-Ausschnitt zum Pruefen und Kopieren. Geschrieben wird
nichts - die Datei liegt in Home Assistant, und dort entscheidet der Mensch.

**Nur Messgroessen.** Aktoren, Alarmanlage und Kontakte stehen nicht im Katalog: Eine falsche
Zuordnung dort schaltet etwas Falsches oder meldet ein offenes Fenster als geschlossen, und das
soll niemand aus einem Vorschlag uebernehmen, den er nur ueberflogen hat.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel

from hems_core.domain.config import SensorTimeouts

#: Hoechstzahl der Zeilen aus der eingefuegten Liste.
ZEILEN_MAX = 400

#: Die Altersgrenze der vier Pufferfuehler - geholt und nicht abgeschrieben.
#:
#: Hier stand 3600, dieselbe Zahl, die bis zum 22.11.2026 in `config/entities.home.yaml` stand und
#: dort zur zweiten Grenze fuer dieselben Fuehler geworden war. Eine Vorlage, die eine Zahl
#: vorschlaegt, die der Dienst nicht benutzt, bringt sie bei der naechsten Einrichtung zurueck.
#: Die eine Stelle ist `SensorTimeouts.temperature_s`.
_PUFFER_FRIST = int(SensorTimeouts().temperature_s)


@dataclass(frozen=True)
class Ziel:
    schluessel: str
    #: Erlaubte Einheiten der Quelle; die Bruecke rechnet W in kW selbst um.
    einheiten: tuple[str, ...]
    bedeutung: str
    stale_after_s: int


_LEISTUNG = ("W", "kW")
_TEMPERATUR = ("°C",)

#: Der Katalog: die Messgroessen, die die Bruecke ueber `sensors:` kennt.
KATALOG: tuple[Ziel, ...] = (
    Ziel("pv_power_kw", _LEISTUNG, "PV-Erzeugung, immer positiv", 120),
    Ziel("grid_power_kw", _LEISTUNG, "Netz: positiv = Bezug, negativ = Einspeisung", 120),
    Ziel("battery_power_kw", _LEISTUNG, "Hausspeicher: positiv = Entladen, negativ = Laden", 120),
    Ziel("battery_soc", ("%",), "Ladestand des Hausspeichers", 600),
    Ziel("house_power_kw", _LEISTUNG, "Gesamtverbrauch des Hauses", 120),
    Ziel("heat_pump_power_kw", _LEISTUNG, "Elektrische Leistung der Waermepumpe", 60),
    Ziel("ev_power_kw", _LEISTUNG, "Ladeleistung der Wallbox", 120),
    Ziel("buffer_temp_top_c", _TEMPERATUR, "Pufferspeicher oben", _PUFFER_FRIST),
    Ziel("buffer_temp_mid_top_c", _TEMPERATUR, "Pufferspeicher mitte oben", _PUFFER_FRIST),
    Ziel("buffer_temp_mid_bottom_c", _TEMPERATUR, "Pufferspeicher mitte unten", _PUFFER_FRIST),
    Ziel("buffer_temp_bottom_c", _TEMPERATUR, "Pufferspeicher unten", _PUFFER_FRIST),
    Ziel("outdoor_temp_c", _TEMPERATUR, "Aussentemperatur", 3600),
    Ziel("flow_temp_c", _TEMPERATUR, "Vorlauftemperatur des Waermepumpenkreises", 900),
)

_NACH_SCHLUESSEL = {z.schluessel: z for z in KATALOG}

_ENTITAET = re.compile(r"\bsensor\.[a-z0-9_]+\b")


class Zuordnungszeile(BaseModel):
    schluessel: str
    entitaet: str
    einheit: str
    grund: str
    yaml: str


class Zuordnungsergebnis(BaseModel):
    zeilen: list[Zuordnungszeile]
    verworfen: list[str]
    offen: list[str]
    yaml: str
    zeilen_gesendet: int


def eingabe(text: str) -> tuple[list[str], set[str]]:
    """Die Zeilen der eingefuegten Liste, die eine Sensor-Entitaet nennen, und deren Kennungen."""
    zeilen = []
    kennungen: set[str] = set()
    for roh in text.splitlines():
        treffer = _ENTITAET.findall(roh)
        if not treffer:
            continue
        kennungen.update(treffer)
        zeilen.append(" ".join(roh.split())[:200])
        if len(zeilen) >= ZEILEN_MAX:
            break
    return zeilen, kennungen


def systemtext() -> str:
    katalog = "\n".join(
        f"- {z.schluessel} ({'/'.join(z.einheiten)}): {z.bedeutung}" for z in KATALOG
    )
    return (
        "Du ordnest Home-Assistant-Entitaeten den Messgroessen eines Energiemanagements zu. "
        "Antworte NUR mit einem JSON-Objekt der Form "
        '{"zuordnung": [{"schluessel": "...", "entitaet": "sensor....", "einheit": "W", '
        '"grund": "kurz, warum"}]}.\n'
        "Regeln: Nur Schluessel aus dem KATALOG. Nur Entitaeten, die woertlich in der Liste "
        "stehen. Hoechstens eine Entitaet je Schluessel. Bist du unsicher, laesst du den "
        "Schluessel weg - eine fehlende Zuordnung ist besser als eine falsche. Die Einheit "
        "uebernimmst du aus der Liste.\n\n"
        f"KATALOG:\n{katalog}"
    )


def pruefen(roh: dict[str, Any], kennungen: set[str], gesendet: int) -> Zuordnungsergebnis:
    """Jede vorgeschlagene Zeile gegen Katalog, Liste und Einheit; Verworfenes mit Grund."""
    zeilen: list[Zuordnungszeile] = []
    verworfen: list[str] = []
    vergeben: set[str] = set()
    eintraege = roh.get("zuordnung")
    for eintrag in eintraege if isinstance(eintraege, list) else []:
        if not isinstance(eintrag, dict):
            continue
        schluessel = str(eintrag.get("schluessel") or "").strip()
        entitaet = str(eintrag.get("entitaet") or "").strip()
        einheit = str(eintrag.get("einheit") or "").strip().replace("° C", "°C")
        ziel = _NACH_SCHLUESSEL.get(schluessel)
        if ziel is None:
            verworfen.append(f"{schluessel or '?'}: kein bekannter Schluessel")
            continue
        if entitaet not in kennungen:
            verworfen.append(f"{schluessel}: {entitaet or '?'} steht nicht in der Liste")
            continue
        if schluessel in vergeben:
            verworfen.append(f"{schluessel}: doppelt vorgeschlagen")
            continue
        if einheit not in ziel.einheiten:
            verworfen.append(
                f"{schluessel}: Einheit {einheit or '?'} passt nicht ({'/'.join(ziel.einheiten)})"
            )
            continue
        vergeben.add(schluessel)
        einheit_yaml = f'"{einheit}"' if not einheit.isalnum() else einheit
        zeilen.append(
            Zuordnungszeile(
                schluessel=schluessel,
                entitaet=entitaet,
                einheit=einheit,
                grund=str(eintrag.get("grund") or "")[:160],
                yaml=f"  - {{ key: {schluessel}, entity: {entitaet}, unit: {einheit_yaml}, "
                f"stale_after_s: {ziel.stale_after_s} }}",
            )
        )
    offen = [z.schluessel for z in KATALOG if z.schluessel not in vergeben]
    return Zuordnungsergebnis(
        zeilen=zeilen,
        verworfen=verworfen,
        offen=offen,
        yaml="sensors:\n" + "\n".join(z.yaml for z in zeilen) if zeilen else "",
        zeilen_gesendet=gesendet,
    )
