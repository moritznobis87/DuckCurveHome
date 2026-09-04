"""Home-Assistant-WebSocket-Client: auth, get_states, state_changed-Abonnement, call_service.

Verwendet die dokumentierte WebSocket-API. Läuft im Add-on über den Supervisor-Proxy
(ws://supervisor/core/websocket) oder lokal gegen ws://<ha>:8123/api/websocket.
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

import structlog
import websockets
from websockets.asyncio.client import ClientConnection

log = structlog.get_logger("ha")


@dataclass(frozen=True)
class EntityState:
    entity_id: str
    state: str
    attributes: dict[str, Any]
    last_updated: datetime | None
    last_changed: datetime | None


@dataclass
class HaWsClient:
    url: str
    token: str
    entity_filter: set[str] = field(default_factory=set)
    _ws: ClientConnection | None = None
    _next_id: int = 1
    _pending: dict[int, asyncio.Future[dict[str, Any]]] = field(default_factory=dict)
    _events: asyncio.Queue[EntityState] = field(default_factory=asyncio.Queue)
    _reader: asyncio.Task[None] | None = None
    connected: bool = False

    async def connect(self) -> None:
        self._ws = await websockets.connect(self.url, max_size=8 * 1024 * 1024, open_timeout=15)
        first = json.loads(await self._ws.recv())
        if first.get("type") != "auth_required":
            raise RuntimeError(f"Unerwartete Begrüßung von Home Assistant: {first.get('type')}")
        await self._ws.send(json.dumps({"type": "auth", "access_token": self.token}))
        reply = json.loads(await self._ws.recv())
        if reply.get("type") != "auth_ok":
            raise RuntimeError(
                f"Home-Assistant-Authentifizierung fehlgeschlagen: {reply.get('message')}"
            )
        self.connected = True
        self._reader = asyncio.create_task(self._read_loop())
        log.info("ha connected", version=reply.get("ha_version"))

    async def close(self) -> None:
        self.connected = False
        if self._reader:
            self._reader.cancel()
        if self._ws:
            await self._ws.close()

    async def _read_loop(self) -> None:
        assert self._ws is not None
        try:
            async for raw in self._ws:
                msg = json.loads(raw)
                mid = msg.get("id")
                if msg.get("type") == "event":
                    ev = msg.get("event", {})
                    if ev.get("event_type") == "state_changed":
                        new = ev.get("data", {}).get("new_state")
                        if new and (
                            not self.entity_filter or new["entity_id"] in self.entity_filter
                        ):
                            self._events.put_nowait(_to_state(new))
                elif mid in self._pending:
                    self._pending.pop(mid).set_result(msg)
        except websockets.ConnectionClosed as exc:
            log.warning("ha connection closed", code=exc.code)
        finally:
            self.connected = False
            for fut in self._pending.values():
                if not fut.done():
                    fut.set_exception(ConnectionError("Home-Assistant-Verbindung geschlossen"))
            self._pending.clear()

    async def _call(self, payload: dict[str, Any], timeout: float = 15.0) -> dict[str, Any]:
        if self._ws is None or not self.connected:
            raise ConnectionError("nicht verbunden")
        mid = self._next_id
        self._next_id += 1
        fut: asyncio.Future[dict[str, Any]] = asyncio.get_running_loop().create_future()
        self._pending[mid] = fut
        await self._ws.send(json.dumps({"id": mid, **payload}))
        reply = await asyncio.wait_for(fut, timeout)
        if not reply.get("success", False):
            err = reply.get("error", {})
            raise RuntimeError(f"HA-Fehler {err.get('code')}: {err.get('message')}")
        return reply

    async def get_states(self) -> list[EntityState]:
        reply = await self._call({"type": "get_states"})
        states = [_to_state(s) for s in reply.get("result", [])]
        if self.entity_filter:
            states = [s for s in states if s.entity_id in self.entity_filter]
        return states

    async def subscribe_state_changes(self) -> None:
        await self._call({"type": "subscribe_events", "event_type": "state_changed"})

    async def events(self) -> AsyncIterator[EntityState]:
        while self.connected or not self._events.empty():
            try:
                yield await asyncio.wait_for(self._events.get(), timeout=1.0)
            except TimeoutError:
                continue

    async def call_service(
        self, domain: str, service: str, entity_id: str, data: dict[str, Any] | None = None
    ) -> None:
        await self._call(
            {
                "type": "call_service",
                "domain": domain,
                "service": service,
                "service_data": data or {},
                "target": {"entity_id": entity_id},
            }
        )


def _to_state(raw: dict[str, Any]) -> EntityState:
    from dch_bridge.mapping import parse_ha_time

    return EntityState(
        entity_id=raw["entity_id"],
        state=str(raw.get("state", "")),
        attributes=dict(raw.get("attributes") or {}),
        last_updated=parse_ha_time(raw.get("last_updated")),
        last_changed=parse_ha_time(raw.get("last_changed")),
    )


StateCallback = Callable[[EntityState], None]


def utcnow() -> datetime:
    return datetime.now(UTC)
