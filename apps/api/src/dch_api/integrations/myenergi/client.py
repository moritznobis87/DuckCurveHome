"""HTTP-Zugang zur myenergi-Cloud.

Anmeldung per HTTP Digest mit Hub-Seriennummer und API-Key (myenergi-App → Konto → Erweitert). Der
„Director“ verweist im Header `x_myenergi-asn` auf den zuständigen Server (z. B. s18.myenergi.net); der
wird gemerkt und bei Fehlern neu ermittelt. Die API ist nicht offiziell dokumentiert, aber seit Jahren
stabil und Grundlage der Home-Assistant-Integration (pymyenergi).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

import httpx
import structlog

log = structlog.get_logger("myenergi")
DIRECTOR_URL = "https://director.myenergi.net"
ASN_HEADER = "x_myenergi-asn"
USER_AGENT = "DuckCurveHome/1.0"


class MyenergiError(RuntimeError):
    pass


# Setzbare Betriebsarten des Libbi. Mehr gibt die Schnittstelle nicht her: die weiteren Modi, die
# die App anzeigt (capture, charge, match), lassen sich nur lesen. „Stopped" hält beides an, Laden
# und Entladen - ein „nicht mehr entladen, aber noch laden" existiert nicht.
LIBBI_MODES: dict[str, int] = {"stopped": 0, "normal": 1, "export": 5}


class MyenergiClient:
    """Kleiner, asynchroner Client für die Hub-API (director.myenergi.net, Digest-Auth)."""

    def __init__(self, hub_serial: str, api_key: str, timeout_s: float = 20.0) -> None:
        self.hub_serial = hub_serial.strip()
        self.auth = httpx.DigestAuth(self.hub_serial, api_key.strip())
        self.timeout_s = timeout_s
        self.base_url: str | None = None

    async def _get(self, client: httpx.AsyncClient, url: str) -> Any:
        r = await client.get(
            url, auth=self.auth, headers={"User-Agent": USER_AGENT}, timeout=self.timeout_s
        )
        asn = r.headers.get(ASN_HEADER)
        if asn:
            new_base = f"https://{asn}"
            if new_base != self.base_url:
                log.info("myenergi server", server=asn)
            self.base_url = new_base
        if r.status_code == 401:
            raise MyenergiError("Anmeldung abgelehnt (Seriennummer/API-Key prüfen)")
        if r.status_code != 200:
            self.base_url = None  # beim nächsten Aufruf neu über den Director
            raise MyenergiError(f"HTTP {r.status_code}")
        return r.json()

    async def _request(self, path: str) -> Any:
        try:
            async with httpx.AsyncClient() as client:
                if self.base_url is None:
                    await self._get(client, f"{DIRECTOR_URL}/cgi-jstatus-E")
                    if self.base_url is None:
                        raise MyenergiError("Director nennt keinen Server (Konto ohne Geräte?)")
                return await self._get(client, f"{self.base_url}{path}")
        except httpx.HTTPError as exc:
            self.base_url = None
            raise MyenergiError(f"Netzwerkfehler: {exc.__class__.__name__}") from exc

    async def set_libbi_mode(self, serial: int | str, mode: str) -> None:
        """Betriebsart des Libbi setzen.

        Die Schnittstelle ist nicht dokumentiert; myenergi veröffentlicht keine API. Der Pfad
        stammt aus der Gegenprobe mit `pymyenergi`, der Bibliothek hinter der
        Home-Assistant-Integration, und läuft über dieselbe Digest-Anmeldung wie alles Lesende.
        Ein Firmware-Update kann ihn brechen; deshalb wirft ein Fehlschlag hier eine Ausnahme,
        statt still zu scheitern, und der Aufrufer entscheidet, ob er es erneut versucht.
        """
        key = mode.strip().lower()
        if key not in LIBBI_MODES:
            raise MyenergiError(f"Unbekannte Betriebsart: {mode}")
        await self._request(f"/cgi-libbi-mode-L{serial}-{LIBBI_MODES[key]}")

    async def status(self) -> list[dict[str, Any]]:
        """Alle Geräte mit aktuellen Werten: Liste von Gruppen {"zappi": [...]}, {"libbi": [...]}, …"""
        data = await self._request("/cgi-jstatus-*")
        if not isinstance(data, list):
            raise MyenergiError("unerwartete Antwort auf jstatus")
        return data

    async def history_minutes(
        self, prefix: str, serial: int | str, start_utc: datetime, minutes: int
    ) -> list[dict[str, Any]]:
        """Minutenwerte eines Geräts (Z = Zappi, E = Eddi, L = Libbi) ab start_utc; Energien in Joule je Minute."""
        path = (
            f"/cgi-jday-{prefix}{serial}-{start_utc.year}-{start_utc.month}-{start_utc.day}"
            f"-{start_utc.hour}-0-{minutes}"
        )
        data = await self._request(path)
        rows = data.get(f"U{serial}") if isinstance(data, dict) else None
        return list(rows) if isinstance(rows, list) else []
