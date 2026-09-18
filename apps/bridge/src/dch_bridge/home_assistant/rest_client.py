"""REST-Zugriff auf Home Assistant: Heartbeat-Entität und Dienstaufrufe."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import httpx


class HaRestClient:
    def __init__(self, base_url: str, token: str) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            headers={"authorization": f"Bearer {token}", "content-type": "application/json"},
            timeout=10.0,
        )

    async def set_heartbeat(self, entity_id: str, cloud_connected: bool) -> None:
        now = datetime.now(UTC)
        await self._client.post(
            f"/states/{entity_id}",
            json={
                "state": now.isoformat(timespec="seconds"),
                "attributes": {
                    "friendly_name": "Duck Curve Home Bridge Heartbeat",
                    "device_class": "timestamp",
                    "cloud_connected": cloud_connected,
                },
            },
        )

    async def call_service(self, domain: str, service: str, entity_id: str) -> Any:
        """Einen Dienst auf einer Entität ausführen, etwa `lock.open` auf dem Türschloss.

        Kurzer Zeitrahmen und eine Ausnahme bei Misserfolg: hinter der Tür steht jemand. Ein
        Aufruf, der stillschweigend nichts bewirkt, ist hier die schlechteste aller Antworten.
        """
        r = await self._client.post(f"/services/{domain}/{service}", json={"entity_id": entity_id})
        r.raise_for_status()
        try:
            return r.json()
        except ValueError:
            return []

    async def state_of(self, entity_id: str) -> str | None:
        """Der Zustand einer Entität, oder None, wenn Home Assistant sie nicht kennt."""
        r = await self._client.get(f"/states/{entity_id}")
        if r.status_code == 404:
            return None
        r.raise_for_status()
        data = r.json()
        return str(data.get("state")) if isinstance(data, dict) else None

    async def close(self) -> None:
        await self._client.aclose()
