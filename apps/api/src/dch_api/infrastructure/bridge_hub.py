"""BridgeHub: hält die (eine) Bridge-Verbindung, verteilt Telemetrie, stellt Kommandos zu."""

from __future__ import annotations

import asyncio
import contextlib
import hashlib
import hmac
import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from uuid import UUID

import structlog
from fastapi import WebSocket

from hems_core.protocol import (
    AckFrame,
    BacklogFrame,
    CommandFrame,
    CommandResultFrame,
    DeviceHealthFrame,
    EventFrame,
    Frame,
    HeartbeatFrame,
    HelloFrame,
    RawReading,
    TelemetryFrame,
    WelcomeFrame,
)

log = structlog.get_logger("bridge_hub")
TelemetryHandler = Callable[[list[RawReading], bool], Awaitable[None]]  # (items, is_backlog)


def token_hash(token: str, pepper: str) -> str:
    return hmac.new(pepper.encode(), token.encode(), hashlib.sha256).hexdigest()


class BridgeHub:
    def __init__(self, server_version: str) -> None:
        self.server_version = server_version
        self._ws: WebSocket | None = None
        self.bridge_id: str | None = None
        self.connected_at: datetime | None = None
        self.last_frame_at: datetime | None = None
        self.last_seq = 0
        self.frames_in = 0
        self._pending: dict[UUID, asyncio.Future[CommandResultFrame]] = {}
        self.on_telemetry: TelemetryHandler | None = None
        self.on_event: Callable[[EventFrame | DeviceHealthFrame], Awaitable[None]] | None = None
        self.health: DeviceHealthFrame | None = None

    @property
    def online(self) -> bool:
        if self._ws is None or self.last_frame_at is None:
            return False
        return (datetime.now(UTC) - self.last_frame_at).total_seconds() < 60

    async def serve(self, ws: WebSocket, hello: HelloFrame) -> None:
        if self._ws is not None:
            log.info("bridge superseded", bridge_id=self.bridge_id)
            with contextlib.suppress(Exception):
                await self._ws.close(code=4001, reason="superseded")
        self._ws = ws
        self.bridge_id = hello.bridge_id
        self.connected_at = datetime.now(UTC)
        self.last_frame_at = self.connected_at
        resume = max(self.last_seq, hello.last_acked_seq) + 1
        await ws.send_text(
            WelcomeFrame(
                server_time=datetime.now(UTC),
                server_version=self.server_version,
                resume_from_seq=resume,
            ).model_dump_json()
        )
        log.info(
            "bridge connected",
            bridge_id=hello.bridge_id,
            version=hello.bridge_version,
            keys=len(hello.keys),
            resume_from=resume,
        )

    async def handle(self, frame: Frame) -> None:
        self.frames_in += 1
        self.last_frame_at = datetime.now(UTC)
        if isinstance(frame, TelemetryFrame | BacklogFrame):
            is_backlog = isinstance(frame, BacklogFrame)
            if frame.seq > self.last_seq or is_backlog:
                if self.on_telemetry is not None:
                    await self.on_telemetry(frame.items, is_backlog)
                self.last_seq = max(self.last_seq, frame.seq)
            if self._ws is not None:
                await self._ws.send_text(AckFrame(seq=frame.seq).model_dump_json())
        elif isinstance(frame, CommandResultFrame):
            fut = self._pending.pop(frame.command_id, None)
            if fut is not None and not fut.done():
                fut.set_result(frame)
        elif isinstance(frame, HeartbeatFrame):
            pass
        elif isinstance(frame, DeviceHealthFrame):
            self.health = frame
            if self.on_event is not None:
                await self.on_event(frame)
        elif isinstance(frame, EventFrame) and self.on_event is not None:
            await self.on_event(frame)

    def disconnected(self, ws: WebSocket) -> None:
        if self._ws is ws:
            self._ws = None
            log.info("bridge disconnected", bridge_id=self.bridge_id)

    async def send_command(
        self,
        actuator_key: str,
        state: bool,
        ttl_s: int | None,
        decision_id: UUID | None,
        timeout_s: float = 10.0,
    ) -> CommandResultFrame:
        if self._ws is None:
            raise ConnectionError("Bridge nicht verbunden")
        cmd = CommandFrame(
            command_id=uuid.uuid4(),
            issued_at=datetime.now(UTC),
            actuator_key=actuator_key,
            state=state,
            ttl_s=ttl_s,
            decision_id=decision_id,
        )
        fut: asyncio.Future[CommandResultFrame] = asyncio.get_running_loop().create_future()
        self._pending[cmd.command_id] = fut
        await self._ws.send_text(cmd.model_dump_json())
        try:
            return await asyncio.wait_for(fut, timeout_s)
        except TimeoutError:
            self._pending.pop(cmd.command_id, None)
            return CommandResultFrame(
                command_id=cmd.command_id,
                ok=False,
                observed_state=None,
                error="keine Antwort der Bridge",
                at=datetime.now(UTC),
            )
