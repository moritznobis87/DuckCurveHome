"""Tibber-Preisabruf (GraphQL). Liefert PricePoints in ct/kWh (total = Energie + Steuern/Netz)."""

from __future__ import annotations

from datetime import datetime, timedelta

import httpx
import structlog

from hems_core.planning import PricePoint

log = structlog.get_logger("tibber")
TIBBER_URL = "https://api.tibber.com/v1-beta/gql"
QUERY = """
{ viewer { homes { id appNickname currentSubscription { priceInfo {
  today { total startsAt } tomorrow { total startsAt } } } } } }
"""


class TibberPriceProvider:
    name = "tibber"

    def __init__(self, token: str, home_id: str | None = None, timeout_s: float = 20.0) -> None:
        self.token = token
        self.home_id = home_id
        self.timeout_s = timeout_s

    async def fetch_range(self, start: datetime, end: datetime) -> list[PricePoint]:
        """Historische Stundenpreise [start, end) über die Tibber-Range-API, rückwärts blätternd."""
        points: list[tuple[datetime, float]] = []
        cursor: str | None = None
        async with httpx.AsyncClient(timeout=self.timeout_s) as client:
            for _ in range(60):  # höchstens 60 × 720 h ≈ 5 Jahre
                before = f', before: "{cursor}"' if cursor else ""
                query = (
                    "{ viewer { homes { id currentSubscription { priceInfo { range(resolution: HOURLY, last: 720"
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
                    raise RuntimeError(
                        f"Tibber: {body['errors'][0].get('message', 'GraphQL-Fehler')}"
                    )
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
        out = [
            PricePoint(start=s, end=s + timedelta(hours=1), ct_kwh=round(ct, 3))
            for s, ct in points
            if start <= s + timedelta(hours=1) and s < end
        ]
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
