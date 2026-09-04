"""WebSocket-Endpunkt für die Bridge: Bearer-Token, hello/welcome, Frames an den BridgeHub."""

from __future__ import annotations

import hmac

import structlog
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from hems_core.protocol import HelloFrame, parse_frame

router = APIRouter(tags=["Bridge"])
log = structlog.get_logger("bridge_ws")


def _token_ok(header: str | None, allowed: list[str]) -> bool:
    if not header or not header.lower().startswith("bearer "):
        return False
    token = header[7:].strip()
    return any(hmac.compare_digest(token, t) for t in allowed if t)


@router.websocket("/bridge/ws")
async def bridge_ws(ws: WebSocket) -> None:
    settings = ws.app.state.settings
    hub = getattr(ws.app.state, "bridge_hub", None)
    if hub is None:
        await ws.close(code=4004, reason="kein Live-Modus")
        return
    if not _token_ok(ws.headers.get("authorization"), settings.bridge_tokens):
        await ws.close(code=4401, reason="ungültiges Token")
        return
    await ws.accept()
    try:
        first = parse_frame(await ws.receive_text())
        if not isinstance(first, HelloFrame):
            await ws.close(code=4400, reason="hello erwartet")
            return
        await hub.serve(ws, first)
        while True:
            frame = parse_frame(await ws.receive_text())
            await hub.handle(frame)
    except WebSocketDisconnect:
        pass
    except ValidationError as exc:
        log.warning("bridge frame invalid", error=str(exc)[:200])
        await ws.close(code=4400, reason="ungültiger Frame")
    finally:
        hub.disconnected(ws)
