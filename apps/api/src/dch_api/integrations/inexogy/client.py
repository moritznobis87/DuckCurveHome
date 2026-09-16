"""HTTP-Zugang zum Smartmeter-Portal von inexogy (vormals Discovergy).

**Anmeldung.** Die Dokumentation beschreibt ausschließlich OAuth 1.0a mit HMAC-SHA1: vier
Aufrufe, um an einen Zugangsschlüssel zu kommen, und eine Signatur an jedem weiteren Request.
Genommen wird hier trotzdem HTTP Basic mit Kontomail und Passwort. Der Server nimmt es an - eine
Anfrage mit erfundenen Zugangsdaten antwortet mit

    www-authenticate: Basic realm="Discovergy"
    401 Unauthorized: Invalid email or password supplied in the HTTP Authorization header

also mit einer Ablehnung *dieser Zugangsdaten*, nicht des Verfahrens. Das ist der Weg, den auch die
Home-Assistant-Integration und evcc gehen. Sollte er eines Tages wegfallen, kündigt sich das als
401 mit `www-authenticate: Bearer` an; dann ist die OAuth-Kette nachzurüsten, und der Rest dieses
Moduls bleibt, wie er ist.

**Eine Verbindung.** Die API erlaubt je IP hundert Anfragen je Sekunde, aber **eine gleichzeitige
Verbindung**. Darüber gibt es 429. Der Client hält deshalb genau eine Verbindung offen und
serialisiert seine Aufrufe über eine Sperre, statt sich auf die Sparsamkeit der Aufrufer zu
verlassen.
"""

from __future__ import annotations

import asyncio
from datetime import datetime
from typing import Any

import httpx
import structlog

log = structlog.get_logger("inexogy")
BASE_URL = "https://api.inexogy.com/public/v1"
USER_AGENT = "DuckCurveHome/1.0"


class InexogyError(RuntimeError):
    pass


class InexogyClient:
    """Kleiner, asynchroner Client für die Messwerte eines Zählers."""

    def __init__(self, email: str, password: str, timeout_s: float = 20.0) -> None:
        self.auth = httpx.BasicAuth(email.strip(), password)
        self.timeout_s = timeout_s
        self._lock = asyncio.Lock()
        self._client: httpx.AsyncClient | None = None

    async def _http(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                base_url=BASE_URL,
                auth=self.auth,
                timeout=self.timeout_s,
                # Eine Verbindung, weil die Gegenstelle nur eine zulässt.
                limits=httpx.Limits(max_connections=1, max_keepalive_connections=1),
                headers={
                    "User-Agent": USER_AGENT,
                    # Ohne text/plain im Accept liefert die API bei Fehlern keine lesbare Meldung,
                    # sondern nur den Statuscode. Das steht so in ihrer Beschreibung.
                    "Accept": "application/json, text/plain",
                },
            )
        return self._client

    async def close(self) -> None:
        if self._client is not None and not self._client.is_closed:
            await self._client.aclose()
        self._client = None

    async def _get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        async with self._lock:
            try:
                client = await self._http()
                r = await client.get(path, params=params)
            except httpx.HTTPError as exc:
                await self.close()
                raise InexogyError(f"Netzwerkfehler: {exc.__class__.__name__}") from exc
        if r.status_code == 401:
            raise InexogyError("Anmeldung abgelehnt (E-Mail/Passwort prüfen)")
        if r.status_code == 429:
            raise InexogyError("Zu viele Anfragen (429)")
        if r.status_code != 200:
            raise InexogyError(f"HTTP {r.status_code}: {r.text[:160]}")
        try:
            return r.json()
        except ValueError as exc:
            raise InexogyError("Antwort ist kein JSON") from exc

    async def meters(self) -> list[dict[str, Any]]:
        """Alle Zähler des Kontos. Der `meterId` daraus ist der Schlüssel für alles Weitere.

        Nicht die Seriennummer: die API nimmt nur den 32-stelligen `meterId`, und genau daran ist
        evcc nach der Umstellung von Discovergy auf inexogy gescheitert.
        """
        data = await self._get("/meters")
        if not isinstance(data, list):
            raise InexogyError("unerwartete Antwort auf /meters")
        return [d for d in data if isinstance(d, dict)]

    async def field_names(self, meter_id: str) -> list[str]:
        data = await self._get("/field_names", {"meterId": meter_id})
        return [str(f) for f in data] if isinstance(data, list) else []

    async def last_reading(self, meter_id: str) -> dict[str, Any]:
        """Der jüngste Messwert: `{"time": <ms>, "values": {...}}`."""
        data = await self._get("/last_reading", {"meterId": meter_id})
        if not isinstance(data, dict):
            raise InexogyError("unerwartete Antwort auf /last_reading")
        return data

    async def readings(
        self,
        meter_id: str,
        start: datetime,
        end: datetime,
        resolution: str = "three_minutes",
    ) -> list[dict[str, Any]]:
        """Messwerte eines Zeitraums. Zeitangaben sind UNIX-Millisekunden."""
        data = await self._get(
            "/readings",
            {
                "meterId": meter_id,
                "from": int(start.timestamp() * 1000),
                "to": int(end.timestamp() * 1000),
                "resolution": resolution,
            },
        )
        return [d for d in data if isinstance(d, dict)] if isinstance(data, list) else []
