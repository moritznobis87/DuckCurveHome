"""Die Einzelraumregelung von Controme mitlesen - nur lesen, nichts stellen.

**Was hier hereinkommt.** Je Raum die gemessene Temperatur, der Sollwert, auf den geregelt wird,
und wie weit die Ventile am Heizkreisverteiler offen sind. Das ist genau die Schicht, die dem
Werkzeug bisher fehlte: Die Entnahme des Puffers war eine einzige Zahl, die als Rest einer
Umkehrrechnung herausfiel. Mit den Ventilstellungen bekommt dieser Rest Zeugen.

**Warum nur lesen.** Contromes Schnittstelle hat fuer Ausgaenge ausschliesslich Lese-Endpunkte;
schreiben liesse sich nur der Sollwert, und das waere ein Eingriff in die Behaglichkeit eines
bewohnten Hauses. Der Fussboden hat Zeitkonstanten von rund 13 Stunden, der Raum von rund 25 -
auf dieser Skala gewinnt ein Optimierer durch feinere Ventiltaktung nichts. Die Regelung bleibt
dort, wo sie hingehoert; wir sehen ihr zu.

**Ohne Anmeldung, und das ist kein Entwurf, sondern ein Befund.** Die Lese-Endpunkte des
Mini-Servers antworten im Heimnetz ohne Zugangsdaten (gemessen am 21.10.2026). Das ist eine
Schwaeche von Controme, keine Einladung: Die Quelle nimmt deshalb optional Benutzername und
Passwort entgegen, damit sie weiterlaeuft, wenn Controme das eines Tages repariert.

**Die Haus-Kennung ist nicht verlaesslich 1.** Contromes eigene Dokumentation sagt, sie sei "aus
unterschiedlichen Gruenden manchmal 2". Auf der Anlage, gegen die das hier gebaut wurde, ist sie
2 und 1 liefert eine leere Liste. Darum wird sie gesucht statt vorausgesetzt - eine Einstellung
weniger, die jemand falsch setzen kann.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import httpx
import structlog

from hems_core.domain.quality import Quality
from hems_core.protocol.frames import RawReading

log = structlog.get_logger(__name__)

SOURCE = "controme"
# Welche Haus-Kennungen beim Suchen probiert werden, in dieser Reihenfolge.
HAUS_KANDIDATEN = (2, 1, 3)
# Contromes Funkfuehler melden alle 3 bis 5 Minuten. Haeufiger zu fragen erzeugt Last ohne Ertrag.
POLL_S = 120.0


@dataclass(frozen=True, slots=True)
class RaumInfo:
    """Was einen Raum beschreibt, ohne eine Messgroesse zu sein.

    Diese drei Angaben gehen nicht durch die Telemetrie - die kennt nur Zahlen je Schluessel. Sie
    gehen als Zusammenhang eines Ereignisses mit, und zwar alle drei: Die Etage braucht die
    Anzeige, um nach Geschoss zu gruppieren, und die Zahl der Heizkreise braucht sie, um aus
    "0,25 offen" wieder "einer von vier" zu machen.

    Die Kreiszahl steht hier und nicht in einer Messreihe, weil sie sich nicht aendert, solange
    niemand am Verteiler schraubt. Als Zeitreihe waere sie 1440 Mal am Tag dieselbe Zahl.
    """

    name: str
    etage: str = ""
    kreise: int = 0
    # Der Platz in Contromes eigener Reihenfolge. Die Anzeige gruppiert nach Etage, und die
    # Reihenfolge der Etagen steckt nur in der Reihenfolge des JSON: alphabetisch sortiert waere
    # das Dachgeschoss vor dem Erdgeschoss und der Keller mitten drin.
    rang: int = 0


def _zahl(v: object) -> float | None:
    """Eine Zahl aus dem, was Controme liefert. Strings kommen vor, `None` auch."""
    if isinstance(v, bool):
        return float(v)
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        try:
            return float(v.strip().replace(",", "."))
        except ValueError:
            return None
    return None


def raeume_aus(daten: object) -> list[dict[str, Any]]:
    """Die flache Raumliste aus Contromes Etagenschachtelung.

    Die Antworten von `temps`, `outs` und `rooms` haben dieselbe Form: eine Liste von Etagen, jede
    mit einer Liste `raeume`. Ein Raum ohne `id` ist fuer uns nicht zuzuordnen und faellt heraus.

    **Der Abruf eines einzelnen Raums hat eine andere Form**: dort liegen die Raumfelder flach im
    Array, ohne Etagenhuelle. Diese Funktion gibt dafuer eine leere Liste zurueck. Das ist heute
    richtig, weil nur die Sammelabrufe benutzt werden; wer `temps/<raumid>/` dazunimmt, muss es
    hier abfangen.
    """
    out: list[dict[str, Any]] = []
    if not isinstance(daten, list):
        return out
    for etage in daten:
        if not isinstance(etage, dict):
            continue
        for raum in etage.get("raeume") or []:
            if isinstance(raum, dict) and raum.get("id") is not None:
                out.append({**raum, "etage": etage.get("etagenname") or ""})
    return out


def _kreiswerte(ausgang: object) -> list[float]:
    """Die auswertbaren Ventilwerte eines Raums. Leer, wenn keiner brauchbar ist."""
    if not isinstance(ausgang, dict):
        return []
    return [v for v in (_zahl(x) for x in ausgang.values()) if v is not None]


def kreiszahl(ausgang: object) -> int:
    """Wie viele Heizkreise dieser Raum am Verteiler hat."""
    return len(_kreiswerte(ausgang))


def ventilanteil(ausgang: object) -> float | None:
    """Welcher Anteil der Heizkreise dieses Raums offen ist, 0 bis 1.

    **Das einzelne Ventil kennt keine Zwischenstellung.** Die verbauten thermoelektrischen
    Antriebe sind Auf oder Zu, nichts dazwischen (Angabe des Hausherrn 21.10.2026). Ein Anteil
    entsteht hier trotzdem, und zwar aus der Zahl der Kreise: ein Raum mit vier Heizschleifen,
    von denen eine offen ist, zieht weniger Waerme als einer, bei dem alle vier offen sind.
    0,25 heisst also "einer von vier", nicht "ein Ventil zu einem Viertel".

    Wer nur wissen will, ob ueberhaupt geheizt wird, prueft auf groesser null.

    **Die Schluessel haben teils fuehrende Leerzeichen** - gemessen kam `{" 6": 1, "5": 1}`. Hier
    werden nur die Werte gebraucht; der Hinweis steht trotzdem da, weil jeder, der spaeter je
    Ausgang auswerten will, darueber stolpert.
    """
    gut = _kreiswerte(ausgang)
    if not gut:
        return None
    # Auf oder Zu: alles ueber null gilt als offen. Sollte Controme je Prozentwerte liefern
    # (es gibt eine 0-10-V-Variante der Antriebe), waere das hier eine stille Verfaelschung -
    # darum nicht gemittelt, sondern gezaehlt.
    offen = sum(1 for v in gut if v > 0.0)
    return round(offen / len(gut), 3)


class ContromeRooms:
    """Fragt den Mini-Server im Takt ab und schiebt die Werte in den Sammelpuffer der Bridge."""

    def __init__(
        self,
        host: str,
        on_readings: Callable[[list[RawReading]], Awaitable[None]],
        *,
        on_rooms: Callable[[dict[int, RaumInfo]], Awaitable[None]] | None = None,
        house_id: int = 0,
        poll_interval_s: float = POLL_S,
        user: str = "",
        password: str = "",
        timeout_s: float = 10.0,
    ) -> None:
        # Das Schema wird hier angehaengt, nicht erwartet. Wer "http://192.168.1.50" eintraegt,
        # bekaeme sonst "http://http://..."; der haeufigste Eingabefehler bei solchen Feldern,
        # und er kostet eine Zeile.
        self.host = host.strip().removeprefix("http://").removeprefix("https://").rstrip("/")
        self.on_readings = on_readings
        self.on_rooms = on_rooms
        self.house_id = house_id  # 0 = suchen
        self.poll_interval_s = poll_interval_s
        self.timeout_s = timeout_s
        self._auth = (user, password) if user else None
        self._names: dict[int, RaumInfo] = {}
        self._keys: list[str] = []
        self._last_ok: datetime | None = None
        self._fails = 0

    # ------------------------------------------------------------------ Auskunft
    @property
    def keys(self) -> list[str]:
        """Was diese Quelle liefert. Leer, bis einmal abgefragt wurde - die Raeume stehen nicht
        in einer Konfiguration, sondern in Controme."""
        return list(self._keys)

    def status(self) -> dict[str, object]:
        return {
            "name": SOURCE,
            "online": self._fails == 0 and self._last_ok is not None,
            "host": self.host,
            "house_id": self.house_id,
            "rooms": len(self._names),
            "last_ok": self._last_ok.isoformat() if self._last_ok else None,
            "fails": self._fails,
        }

    # ------------------------------------------------------------------ Abfrage
    def _url(self, methode: str, haus: int) -> str:
        return f"http://{self.host}/get/json/v1/{haus}/{methode}/"

    async def _hole(self, client: httpx.AsyncClient, methode: str, haus: int) -> object | None:
        """Einen Endpunkt lesen. `None` heisst: nicht erreichbar oder kein JSON."""
        try:
            r = await client.get(self._url(methode, haus), auth=self._auth)
            r.raise_for_status()
            daten: object = r.json()
            return daten
        except (httpx.HTTPError, ValueError) as exc:
            # Controme antwortet bei Fehlern gern mit HTML statt JSON; `ValueError` faengt das.
            log.debug("controme read failed", methode=methode, haus=haus, error=str(exc))
            return None

    async def _finde_haus(self, client: httpx.AsyncClient) -> int | None:
        """Die Haus-Kennung suchen: die erste, unter der ueberhaupt Raeume stehen.

        Eine leere Liste ist kein Fehler, sondern Contromes Art zu sagen "dieses Haus gibt es
        nicht". Ohne diese Suche haette man eine Einstellung, die niemand erraten kann und die in
        der Oberflaeche des Herstellers nirgends auftaucht.
        """
        for haus in HAUS_KANDIDATEN:
            daten = await self._hole(client, "rooms", haus)
            if raeume_aus(daten):
                return haus
        return None

    async def _einmal(self, client: httpx.AsyncClient) -> list[RawReading]:
        """Ein Abfragelauf: Temperaturen und Ventilstellungen, zu Messwerten gemacht."""
        if not self.house_id:
            gefunden = await self._finde_haus(client)
            if gefunden is None:
                return []
            self.house_id = gefunden
            log.info("controme house found", house_id=gefunden)

        temps = await self._hole(client, "temps", self.house_id)
        outs = await self._hole(client, "outs", self.house_id)
        if temps is None and outs is None:
            return []

        jetzt = datetime.now(UTC)
        werte: dict[str, float | None] = {}
        infos: dict[int, RaumInfo] = {}

        for i, raum in enumerate(raeume_aus(temps)):
            rid = int(raum["id"])
            infos[rid] = RaumInfo(
                name=str(raum.get("name") or f"Raum {rid}"),
                etage=str(raum.get("etage") or ""),
                rang=i,
            )
            werte[f"room_{rid}_temp_c"] = _zahl(raum.get("temperatur"))
            # **Sollwert und Offset getrennt, und das ist Absicht.**
            #
            # Ich hatte zuerst nur `solltemperatur` genommen, mit der Begruendung, der Offset
            # stecke bereits darin. Dagegen sprechen drei Belege: Contromes FPS-Dokumentation
            # definiert `ziel = soll + offsets`, die Supportseite rechnet "Zieltemperatur =
            # Standardtemperatur plus/minus Offset", und die Anlage selbst meldet
            # `solltemperatur: 21.0` neben `total_offset: 0.2` - 21,0 ist ein glatter Planwert,
            # der Offset steckt also nicht darin.
            #
            # Belegt ist das nicht, die offizielle Beschreibung sagt es nicht ausdruecklich.
            # Darum werden beide Zahlen mitgeschrieben: dann ist die Frage aus den eigenen Daten
            # zu entscheiden statt aus einer Vermutung, und falsch gerechnet wird in keinem Fall
            # mehr als der Offset.
            werte[f"room_{rid}_setpoint_c"] = _zahl(raum.get("solltemperatur"))
            werte[f"room_{rid}_offset_k"] = _zahl(raum.get("total_offset"))
            # Luftfeuchte: im Bad die interessantere Groesse als die Temperatur. Controme setzt
            # hier bei fehlendem Fuehler einen deutschen Satz statt einer Zahl ("kein Sensor
            # vorhanden"); `_zahl` macht daraus `None` statt eines Typfehlers.
            werte[f"room_{rid}_humidity_pct"] = _zahl(raum.get("luftfeuchte"))

        for i, raum in enumerate(raeume_aus(outs)):
            rid = int(raum["id"])
            ausgang = raum.get("ausgang")
            # `outs` kennt dieselben Raeume wie `temps`, aber nicht unbedingt gleichzeitig: einer
            # der beiden Abrufe kann ausgefallen sein. Darum wird hier ergaenzt und nicht ersetzt.
            vorher = infos.get(rid)
            infos[rid] = RaumInfo(
                name=vorher.name if vorher else str(raum.get("name") or f"Raum {rid}"),
                etage=(vorher.etage if vorher and vorher.etage else str(raum.get("etage") or "")),
                kreise=kreiszahl(ausgang),
                rang=vorher.rang if vorher else i,
            )
            werte[f"room_{rid}_valve"] = ventilanteil(ausgang)

        if infos != self._names:
            self._names = infos
            if self.on_rooms is not None:
                await self.on_rooms(dict(infos))
        self._keys = sorted(werte)

        return [
            RawReading(
                key=k,
                value=v,
                observed_at=jetzt,
                # Ein fehlender Wert ist etwas anderes als eine gemessene Null: ein Raum ohne
                # Fuehler meldet nichts, und das soll die Bilanz nicht als 0 Grad lesen.
                quality=Quality.OK if v is not None else Quality.UNKNOWN,
                source=SOURCE,
            )
            for k, v in werte.items()
        ]

    # ------------------------------------------------------------------ Lauf
    async def run(self) -> None:
        async with httpx.AsyncClient(timeout=self.timeout_s) as client:
            while True:
                try:
                    werte = await self._einmal(client)
                    if werte:
                        self._last_ok = datetime.now(UTC)
                        self._fails = 0
                        await self.on_readings(werte)
                    else:
                        self._fails += 1
                        if self._fails in (1, 5, 20):
                            log.warning(
                                "controme liefert nichts",
                                host=self.host,
                                house_id=self.house_id,
                                fails=self._fails,
                            )
                except asyncio.CancelledError:
                    raise
                except Exception as exc:
                    self._fails += 1
                    log.warning("controme poll failed", error=str(exc), fails=self._fails)
                # Rueckfalltakt: gegen einen abgeschalteten Mini-Server waeren es sonst gut
                # 700 vergebliche Anfragen am Tag. Nach jedem Fehlschlag wird laenger gewartet,
                # gedeckelt bei zehn Takten, und ein Erfolg setzt zurueck.
                await asyncio.sleep(self.poll_interval_s * (1 + min(self._fails, 10)))
