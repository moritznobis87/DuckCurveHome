"""REST-Zugriff auf Home Assistant: Heartbeat-Entität für die Wächter-Automation (Ebene E1)."""

from __future__ import annotations

from datetime import UTC, datetime

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

    async def close(self) -> None:
        await self._client.aclose()
