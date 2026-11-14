"""Die Wärmepumpe über eBUS: Werte, die ebusd auf den Broker legt, als Messwerte.

**Der Weg.** Am Bus der Wärmepumpe (ELCO Aerotop Split, BridgeNet, ein eBUS-Dialekt der
Ariston-Gruppe) hängt ein Netzwerk-Adapter. Das Add-on „Duck Curve eBUS" lässt ebusd an diesem
Adapter lauschen; ebusd entschlüsselt die Telegramme mit der Bus-Beschreibung der Ariston-Gruppe
und legt jeden Wert als JSON unter `<präfix>/<kreis>/<name>` auf den Mosquitto-Broker. Hier
werden diese Nachrichten gelesen. Home Assistant ist an diesem Weg nicht beteiligt.

**Die Form der Nachrichten** ist am 13.11.2026 mit ebusd 26.1 und der Bus-Beschreibung
(Fassung f2c9a631) gegen einen nachgestellten Adapter aufgezeichnet worden, nicht aus der
Anleitung abgeschrieben:

    ebusd/energymgr/ext_temp      {"0": {"name": "", "value": 8.6}}
    ebusd/heatpump/coolat_data    {"LWT_temp": {"value": 35.2}, "EWT_temp": {"value": 30.1},
                                   "evaporator_temp": {"value": 2.5}, "coolant_temp": {"value": 40.0}}

Ein Wert mit Namen steht unter seinem Namen, ein einzelner ohne Namen unter "0".

**Welche Namen diese Anlage wirklich meldet, weiß vorab niemand.** Die Bus-Beschreibung stammt
von einer anderen Anlage derselben Gruppe. Deshalb schreibt die Quelle jeden Namen, den sie zum
ersten Mal sieht, mit seinen Werten ins Protokoll: daraus entsteht die Zuordnung, nicht aus
einer Vermutung.

**Nur frische Werte gehen weiter.** Kommt zu einem Schlüssel nichts mehr, meldet die Quelle
nichts, auch kein „nicht verfügbar": dann springt, wo es eine gibt, die Entität aus Home
Assistant ein (die Bridge prüft das mit `fresh`), und sonst lässt der Dienst den Wert altern.

**Fehlt ein Fühler, meldet der Bus 3276,7** (das Rohwort 0x7FFF, durch zehn). Das ist kein
Messwert und wird verworfen, wie alles außerhalb der Grenzen einer Temperatur.

**Eine Zuordnung kann eine Bedingung tragen.** Der Regler dieser Anlage meldet manche Werte in
Listen (Kennung, Wert, Kennung, Wert, ...), und ebusd liest eine Liste mit einer festen
Schablone. Ändert sich die Zusammensetzung der Liste, liest die Schablone an der alten Stelle
etwas anderes, und zwar ohne Fehler: am 14.11.2026 stand so einmal „Hauptpumpe 0; 46; 48715" im
Protokoll. Deshalb legt die Schablone die Kennung vor dem Wert als eigenes Feld offen, und die
Zuordnung verlangt mit `"=..."`, dass sie stimmt:

    "energymgr/system_temps":
      kennung_2: "=76 9e"                 # nur wenn hier wirklich die Kennung 769e steht
      t_769e: heat_pump_return_temp_c

Stimmt die Bedingung nicht, geht aus dieser Nachricht nichts weiter.

Gelesen wird nur. Diese Quelle schickt nichts an ebusd und damit nichts auf den Bus.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

import structlog

from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

log = structlog.get_logger("ebusd_mqtt")

#: Der einzelne Wert einer Nachricht ohne Feldnamen steht bei ebusd unter diesem Schlüssel.
EINZELWERT = "0"
#: Was als Temperatur gelten darf. Der Marker für einen fehlenden Fühler (3276,7) liegt weit
#: außerhalb, ebenso ein vertauschtes Byte.
TEMPERATUR_C = (-60.0, 150.0)
#: So beginnt in der Zuordnung eine Bedingung statt eines Schlüssels.
BEDINGUNG = "="


def ist_bedingung(ziel: str) -> bool:
    return ziel.startswith(BEDINGUNG)


def schluessel(components: dict[str, str | dict[str, str]]) -> set[str]:
    """Die Domänenschlüssel einer Zuordnung, ohne die Bedingungen."""
    out: set[str] = set()
    for ziel in components.values():
        ziele = {ziel} if isinstance(ziel, str) else set(ziel.values())
        out |= {z for z in ziele if not ist_bedingung(z)}
    return out


def rohwerte(payload: bytes | str) -> dict[str, object] | None:
    """Alle Felder einer ebusd-Nachricht, Zahlen wie Wörter. `None`: nicht lesbar."""
    try:
        roh = json.loads(payload)
    except (ValueError, TypeError):
        return None
    if not isinstance(roh, dict):
        return None
    return {
        str(name): (inhalt.get("value") if isinstance(inhalt, dict) else inhalt)
        for name, inhalt in roh.items()
    }


def felder(payload: bytes | str) -> dict[str, float] | None:
    """Die Zahlen einer ebusd-Nachricht, je Feldname. `None`: nicht lesbar.

    Wörter (etwa der Betriebszustand „Heating") sind keine Messwerte und fehlen im Ergebnis; eine
    Nachricht, die nur Wörter enthält, ergibt ein leeres Verzeichnis und ist trotzdem gültig.
    """
    roh = rohwerte(payload)
    if roh is None:
        return None
    return {
        name: float(wert)
        for name, wert in roh.items()
        if not isinstance(wert, bool) and isinstance(wert, int | float) and math.isfinite(wert)
    }


#: Kam so lange keine Nachricht mehr von ebusd, gilt es als verstummt. ebusd gibt im Betrieb alle
#: paar Sekunden etwas weiter, auch bei stehender Maschine (gemessen: 5 bis 55 Sekunden je Name).
STUMM_S = 600.0

#: Die Lagen der Quelle und wie ernst sie sind (`DeviceHealthFrame.status`). `abgeschaltet` setzt
#: die Bridge selbst: bei `source_mode: home_assistant` gibt es die Quelle gar nicht.
LAGEN: dict[str, str] = {
    "ok": "ok",
    "nur_mitlesen": "degraded",
    "nicht_zugeordnet": "degraded",
    "kein_signal": "degraded",
    "kein_wort": "down",
    "verstummt": "down",
    "broker_getrennt": "down",
    "abgeschaltet": "down",
}


@dataclass
class _Wert:
    value: float
    at: datetime


@dataclass
class EbusdDevice:
    """ebusd am Broker. `components` ordnet `<kreis>/<name>` einem Domänenschlüssel zu, oder,
    bei Nachrichten mit mehreren Feldern, jedem Feldnamen einen:

    ```yaml
    components:
      "energymgr/ext_temp": outdoor_temp_c
      "heatpump/coolat_data":
        LWT_temp: flow_temp_c
    ```
    """

    topic_prefix: str = "ebusd"
    components: dict[str, str | dict[str, str]] = field(default_factory=dict)
    #: Temperaturen ändern sich langsam, und manche Werte meldet der Bus nur bei Änderung.
    stale_s: float = 3600.0
    label: str = "Wärmepumpe (eBUS)"
    values: dict[str, _Wert] = field(default_factory=dict, init=False)
    #: Was der Bus bisher gemeldet hat: Name der Nachricht, zuletzt gesehene Felder.
    gesehen: dict[str, dict[str, float]] = field(default_factory=dict, init=False)
    messages: int = field(default=0, init=False)
    rejected: int = field(default=0, init=False)
    emitted: int = field(default=0, init=False)
    last_message_at: datetime | None = field(default=None, init=False)
    signal: bool | None = field(default=None, init=False)

    @property
    def owned_keys(self) -> set[str]:
        return schluessel(self.components)

    def topics(self) -> list[str]:
        return [f"{self.topic_prefix}/#"]

    def apply(self, topic: str, payload: bytes | str, now: datetime) -> bool:
        vor = f"{self.topic_prefix}/"
        if not topic.startswith(vor):
            return False
        name = topic[len(vor) :]
        if name.startswith("global/"):
            # `global/signal` sagt, ob ebusd den Bus überhaupt hört. Alles andere dort ist Verwaltung.
            if name == "global/signal":
                text = payload.decode("utf-8", "replace") if isinstance(payload, bytes) else payload
                self.signal = text.strip().lower() == "true"
            return True
        if name.endswith(("/get", "/set", "/list")):
            return True
        werte = felder(payload)
        if werte is None:
            self.rejected += 1
            return True
        self.messages += 1
        self.last_message_at = now
        if name not in self.gesehen:
            # Einmal je Name: daraus wird die Zuordnung gemacht.
            log.info("ebusd meldet", name=name, werte=werte, zugeordnet=name in self.components)
        self.gesehen[name] = werte
        ziel = self.components.get(name)
        if ziel is None:
            return True
        zuordnung = {EINZELWERT: ziel} if isinstance(ziel, str) else ziel
        bedingungen = {f: z[len(BEDINGUNG) :] for f, z in zuordnung.items() if ist_bedingung(z)}
        if bedingungen:
            roh = rohwerte(payload) or {}
            verfehlt = {f: roh.get(f) for f, soll in bedingungen.items() if str(roh.get(f)) != soll}
            if verfehlt:
                # Die Nachricht hat eine andere Zusammensetzung als die Schablone annimmt.
                self.rejected += 1
                log.debug("ebusd condition not met", name=name, verfehlt=verfehlt)
                return True
        for feld, key in zuordnung.items():
            if ist_bedingung(key):
                continue
            wert = werte.get(feld)
            if wert is None and isinstance(ziel, str) and len(werte) == 1:
                # Ein einzelner Wert, der doch einen Namen hat.
                wert = next(iter(werte.values()))
            if wert is None:
                continue
            if key.endswith("_c") and not TEMPERATUR_C[0] <= wert <= TEMPERATUR_C[1]:
                self.rejected += 1
                log.debug("ebusd value out of range", name=name, feld=feld, value=wert)
                continue
            self.values[key] = _Wert(round(wert, 3), now)
        return True

    def lage(self, *, verbunden: bool, weitergabe: bool, now: datetime) -> str:
        """Woran es liegt, wenn von der Wärmepumpe nichts ankommt, als ein Wort aus `LAGEN`.

        Die Reihenfolge ist die des Weges: erst der Broker, dann ebusd, dann der Bus, dann die
        Zuordnung. Genannt wird die erste Stelle, an der es hängt.
        """
        if not verbunden:
            return "broker_getrennt"
        if self.messages == 0 or self.last_message_at is None:
            return "kein_wort"
        if (now - self.last_message_at).total_seconds() > STUMM_S:
            return "verstummt"
        if self.signal is False:
            return "kein_signal"
        if not any(self.fresh(key, now) for key in self.values):
            return "nicht_zugeordnet"
        if not weitergabe:
            return "nur_mitlesen"
        return "ok"

    def emit(self, now: datetime) -> list[RawReading]:
        frisch = timedelta(seconds=self.stale_s)
        items = [
            RawReading(
                key=key,
                value=v.value,
                observed_at=v.at,
                quality=Quality.OK,
                source=f"mqtt:{self.topic_prefix}",
            )
            for key, v in self.values.items()
            if now - v.at <= frisch
        ]
        if items:
            self.emitted += 1
        return items

    def command(self, key: str, state: bool, ttl_s: float | None) -> tuple[str, str] | None:
        return None  # gelesen wird nur

    def poll(self) -> tuple[str, str] | None:
        return None  # nichts abfragen: jede Abfrage wäre ein Telegramm auf dem Bus

    def observed(self, key: str) -> bool | None:
        return None

    def fresh(self, key: str, now: datetime) -> bool:
        v = self.values.get(key)
        return v is not None and now - v.at <= timedelta(seconds=self.stale_s)

    def status(self) -> dict[str, Any]:
        jetzt = datetime.now(UTC)
        return {
            "device": self.topic_prefix,
            "signal": self.signal,
            "messages": self.messages,
            "rejected": self.rejected,
            "emitted": self.emitted,
            "last_message_at": self.last_message_at,
            "latest": {
                key: [v.value, round((jetzt - v.at).total_seconds())]
                for key, v in self.values.items()
            },
            # Alle Namen, die der Bus bisher gemeldet hat, mit ihren Feldern.
            "gesehen": {name: sorted(werte) for name, werte in sorted(self.gesehen.items())},
        }
