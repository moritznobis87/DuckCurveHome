"""Tibber-Preisabruf (GraphQL). Liefert PricePoints in ct/kWh (total = Energie + Steuern/Netz)."""

from __future__ import annotations

import re
from datetime import datetime, timedelta
from typing import Any

import httpx
import structlog

from hems_core.planning import PricePoint

log = structlog.get_logger("tibber")
TIBBER_URL = "https://api.tibber.com/v1-beta/gql"
# Namen, unter denen ein Viertelstundenraster im Schema auftauchen kann. Ein Muster statt einer
# festen Liste, weil der genaue Bezeichner Tibbers Sache ist. „QUARTER" muss dabei an „HOUR" hängen:
# ein bloßes QUARTERLY neben MONTHLY und ANNUAL wäre ein Quartal — gröber statt feiner, und damit
# genau das Gegenteil dessen, wonach hier gesucht wird.
_FINE = re.compile(r"QUARTER[_ ]?HOUR|FIFTEEN[_ ]?MIN|15[_ ]?MIN|MIN(UTE)?[_ ]?15|PT15M", re.I)
QUERY = """
{ viewer { homes { id appNickname currentSubscription { priceInfo {
  today { total startsAt } tomorrow { total startsAt } } } } } }
"""


class TibberPriceProvider:
    name = "tibber"

    def __init__(
        self,
        token: str,
        home_id: str | None = None,
        timeout_s: float = 20.0,
        resolution: str = "",
    ) -> None:
        self.token = token
        self.home_id = home_id
        self.timeout_s = timeout_s
        # Auflösung der Preishistorie. Leer heißt: beim ersten Abruf im Schema nachsehen und die
        # feinste angebotene nehmen. Die Börse rechnet seit Oktober 2025 in Viertelstunden, aber wie
        # der zugehörige Enum-Wert heißt, ist nichts, was man raten sollte — GraphQL kann danach
        # gefragt werden. Ein fest gesetzter Wert überspringt die Abfrage.
        self.resolution = resolution
        self._resolved: str | None = resolution or None

    async def _post(self, client: httpx.AsyncClient, query: str) -> dict[str, Any]:
        r = await client.post(
            TIBBER_URL, json={"query": query}, headers={"authorization": f"Bearer {self.token}"}
        )
        r.raise_for_status()
        body: dict[str, Any] = r.json()
        return body

    async def _resolution(self, client: httpx.AsyncClient) -> str:
        """Feinste Auflösung, die `range` laut Schema annimmt; im Zweifel stündlich.

        Gefragt wird das Schema selbst (`__type`), nicht das eigene Gedächtnis. Kommt keine Antwort —
        Introspektion abgeschaltet, Feld umbenannt —, bleibt es bei HOURLY: lieber gröber nachtragen
        als gar nicht.
        """
        if self._resolved is not None:
            return self._resolved
        names: list[str] = []
        try:
            body = await self._post(
                client, '{ __type(name: "PriceResolution") { enumValues { name } } }'
            )
            values = ((body.get("data") or {}).get("__type") or {}).get("enumValues") or []
            names = [str(v.get("name", "")) for v in values]
        except Exception as exc:  # Introspektion ist Kür, nicht Pflicht
            log.warning("tibber introspection failed", error=repr(exc)[:200])
        fine = next((n for n in names if _FINE.search(n)), None)
        self._resolved = fine or "HOURLY"
        log.info("tibber price resolution", resolution=self._resolved, offered=names or None)
        return self._resolved

    async def fetch_range(self, start: datetime, end: datetime) -> list[PricePoint]:
        """Historische Preise [start, end) über die Tibber-Range-API, rückwärts blätternd.

        Die Intervallgrenzen kommen aus den Daten, nicht aus einer Annahme: das Ende eines Punkts ist
        der Beginn des nächsten. Bei Viertelstundenpreisen entstehen so 15-Minuten-Intervalle, ohne
        dass hier etwas umgestellt werden müsste.
        """
        points: list[tuple[datetime, float]] = []
        cursor: str | None = None
        async with httpx.AsyncClient(timeout=self.timeout_s) as client:
            resolution = await self._resolution(client)
            for _ in range(60):  # höchstens 60 × 720 Punkte
                before = f', before: "{cursor}"' if cursor else ""
                query = (
                    "{ viewer { homes { id currentSubscription { priceInfo { range("
                    + f"resolution: {resolution}, last: 720"
                    + before
                    + ") { pageInfo { hasPreviousPage startCursor } nodes { total startsAt } } } } } } }"
                )
                r = await client.post(
                    TIBBER_URL,
                    json={"query": query},
                    headers={"authorization": f"Bearer {self.token}"},
                )
                r.raise_for_status()
                body = r.json()
                if body.get("errors"):
                    message = body["errors"][0].get("message", "GraphQL-Fehler")
                    if resolution != "HOURLY":
                        # Das Schema kannte den Wert, die Abfrage nimmt ihn nicht: gröber nachtragen
                        # ist besser als eine Lücke in der Historie.
                        log.warning(
                            "tibber resolution rejected, falling back",
                            resolution=resolution,
                            error=message[:200],
                        )
                        resolution = "HOURLY"
                        self._resolved = "HOURLY"
                        continue
                    raise RuntimeError(f"Tibber: {message}")
                homes = (body.get("data") or {}).get("viewer", {}).get("homes", [])
                if not homes:
                    break
                home = next((h for h in homes if h.get("id") == self.home_id), homes[0])
                rng = ((home.get("currentSubscription") or {}).get("priceInfo") or {}).get(
                    "range"
                ) or {}
                nodes = rng.get("nodes") or []
                for n in nodes:
                    points.append(
                        (datetime.fromisoformat(n["startsAt"]), float(n["total"]) * 100.0)
                    )
                info = rng.get("pageInfo") or {}
                oldest = min((p[0] for p in points), default=None)
                if (
                    not nodes
                    or not info.get("hasPreviousPage")
                    or (oldest is not None and oldest <= start)
                ):
                    break
                cursor = info.get("startCursor")
        points.sort(key=lambda x: x[0])
        out: list[PricePoint] = []
        for i, (s_at, ct) in enumerate(points):
            e_at = points[i + 1][0] if i + 1 < len(points) else s_at + timedelta(hours=1)
            if start <= e_at and s_at < end:
                out.append(PricePoint(start=s_at, end=e_at, ct_kwh=round(ct, 3)))
        return out

    async def fetch(self) -> list[PricePoint]:
        async with httpx.AsyncClient(timeout=self.timeout_s) as client:
            r = await client.post(
                TIBBER_URL, json={"query": QUERY}, headers={"authorization": f"Bearer {self.token}"}
            )
            r.raise_for_status()
            data = r.json()
        homes = data.get("data", {}).get("viewer", {}).get("homes", [])
        if not homes:
            raise RuntimeError("Tibber: keine Homes im Konto")
        home = next((h for h in homes if h.get("id") == self.home_id), homes[0])
        info = (home.get("currentSubscription") or {}).get("priceInfo") or {}
        raw = list(info.get("today") or []) + list(info.get("tomorrow") or [])
        points = [(datetime.fromisoformat(p["startsAt"]), float(p["total"]) * 100.0) for p in raw]
        points.sort(key=lambda x: x[0])
        out: list[PricePoint] = []
        for i, (start, ct) in enumerate(points):
            end = points[i + 1][0] if i + 1 < len(points) else start + timedelta(hours=1)
            out.append(PricePoint(start=start, end=end, ct_kwh=round(ct, 4)))
        log.info("tibber prices fetched", points=len(out))
        return out
