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
    if not isinstance(ausgang, dict) or not ausgang:
        return None
    werte = [_zahl(v) for v in ausgang.values()]
    gut = [v for v in werte if v is not None]
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
        on_rooms: Callable[[dict[int, str]], Awaitable[None]] | None = None,
        house_id: int = 0,
        poll_interval_s: float = POLL_S,
        user: str = "",
        password: str = "",
        timeout_s: float = 10.0,
    ) -> None:
        self.host = host.strip().rstrip("/")
        self.on_readings = on_readings
        self.on_rooms = on_rooms
        self.house_id = house_id  # 0 = suchen
        self.poll_interval_s = poll_interval_s
        self.timeout_s = timeout_s
        self._auth = (user, password) if user else None
        self._names: dict[int, str] = {}
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
        namen: dict[int, str] = {}

        for raum in raeume_aus(temps):
            rid = int(raum["id"])
            namen[rid] = str(raum.get("name") or f"Raum {rid}")
            werte[f"room_{rid}_temp_c"] = _zahl(raum.get("temperatur"))
            # `solltemperatur` ist der Wert, auf den geregelt wird; `total_offset` steckt laut
            # Contromes Oberflaeche bereits darin. Beide getrennt mitzuschreiben waere doppelt.
            werte[f"room_{rid}_setpoint_c"] = _zahl(raum.get("solltemperatur"))

        for raum in raeume_aus(outs):
            rid = int(raum["id"])
            namen.setdefault(rid, str(raum.get("name") or f"Raum {rid}"))
            werte[f"room_{rid}_valve"] = ventilanteil(raum.get("ausgang"))

        if namen != self._names:
            self._names = namen
            if self.on_rooms is not None:
                await self.on_rooms(dict(namen))
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
                await asyncio.sleep(self.poll_interval_s)
