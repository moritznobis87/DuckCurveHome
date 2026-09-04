"""Ausgehende WSS-Verbindung zur API: hello/welcome, Telemetrie mit Sequenzen und Acks, Kommandos, Reconnect."""

from __future__ import annotations

import asyncio
import contextlib
import json
import random
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

import structlog
import websockets
from websockets.asyncio.client import ClientConnection

from dch_bridge.outbox import Outbox
from hems_core.protocol import (
    AckFrame,
    BacklogFrame,
    CommandFrame,
    CommandResultFrame,
    HeartbeatFrame,
    HelloFrame,
    RawReading,
    TelemetryFrame,
    WelcomeFrame,
    parse_frame,
)

log = structlog.get_logger("uplink")
CommandHandler = Callable[[CommandFrame], Awaitable[CommandResultFrame]]


class UplinkClient:
    def __init__(
        self,
        url: str,
        token: str,
        bridge_id: str,
        bridge_version: str,
        entity_map_hash: str,
        keys: list[str],
        outbox: Outbox,
        on_command: CommandHandler,
    ) -> None:
        self.url = url
        self.token = token
        self.bridge_id = bridge_id
        self.bridge_version = bridge_version
        self.entity_map_hash = entity_map_hash
        self.keys = keys
        self.outbox = outbox
        self.on_command = on_command
        self.connected = False
        self.last_ack_seq = 0
        self.last_contact: datetime | None = None
        self._ws: ClientConnection | None = None
        self._send_lock = asyncio.Lock()
        self._stop = asyncio.Event()

    # ------------------------------------------------------------------ Senden
    async def _send(self, payload: object) -> None:
        if self._ws is None or not self.connected:
            raise ConnectionError("Uplink nicht verbunden")
        async with self._send_lock:
            await self._ws.send(
                payload.model_dump_json()
                if hasattr(payload, "model_dump_json")
                else json.dumps(payload)
            )

    async def publish(self, items: list[RawReading]) -> None:
        """Telemetrie in die Outbox schreiben und, wenn verbunden, sofort senden."""
        if not items:
            return
        seq = self.outbox.next_seq()
        frame = TelemetryFrame(seq=seq, sent_at=datetime.now(UTC), items=items)
        self.outbox.put(seq, frame.model_dump(mode="json"))
        if self.connected:
            with contextlib.suppress(ConnectionError, websockets.ConnectionClosed):
                await self._send(frame)

    async def _drain_backlog(self, resume_from: int) -> None:
        after = max(resume_from - 1, 0)
        while True:
            pending = self.outbox.pending(after, limit=20)
            if not pending:
                return
            total = self.outbox.count()
            for i, (seq, payload) in enumerate(pending):
                raw_items = payload.get("items", [])
                items = [
                    RawReading.model_validate(x)
                    for x in (raw_items if isinstance(raw_items, list) else [])
                ]
                await self._send(
                    BacklogFrame(seq=seq, items=items, remaining=max(0, total - i - 1))
                )
                after = seq
            await asyncio.sleep(0.05)

    # ------------------------------------------------------------------ Verbindung
    async def run(self) -> None:
        backoff = 1.0
        while not self._stop.is_set():
            try:
                await self._session()
                backoff = 1.0
            except (OSError, websockets.WebSocketException, ConnectionError, TimeoutError) as exc:
                log.warning("uplink error", error=str(exc)[:200])
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.error("uplink unexpected", error=repr(exc)[:200])
            self.connected = False
            if self._stop.is_set():
                break
            delay = backoff + random.uniform(0, 0.5)
            log.info("uplink reconnect", in_s=round(delay, 1))
            with contextlib.suppress(TimeoutError):
                await asyncio.wait_for(self._stop.wait(), timeout=delay)
            backoff = min(backoff * 2, 60.0)

    async def _session(self) -> None:
        headers = {"authorization": f"Bearer {self.token}"}
        async with websockets.connect(
            self.url, additional_headers=headers, open_timeout=15, ping_interval=20, ping_timeout=20
        ) as ws:
            self._ws = ws
            self.connected = True
            hello = HelloFrame(
                bridge_version=self.bridge_version,
                bridge_id=self.bridge_id,
                clock=datetime.now(UTC),
                entity_map_hash=self.entity_map_hash,
                keys=self.keys,
                last_acked_seq=self.last_ack_seq,
            )
            await self._send(hello)
            welcome = parse_frame(await asyncio.wait_for(ws.recv(), timeout=15))
            if not isinstance(welcome, WelcomeFrame):
                raise ConnectionError(f"Erwartete welcome, bekam {welcome.type}")
            offset_ms = (welcome.server_time - hello.clock).total_seconds() * 1000
            log.info(
                "uplink connected",
                server_version=welcome.server_version,
                resume_from=welcome.resume_from_seq,
                clock_offset_ms=round(offset_ms),
            )
            self.last_contact = datetime.now(UTC)
            await self._drain_backlog(welcome.resume_from_seq)
            heartbeat = asyncio.create_task(self._heartbeat_loop(welcome.heartbeat_s))
            try:
                async for raw in ws:
                    self.last_contact = datetime.now(UTC)
                    await self._handle(parse_frame(raw))
            finally:
                heartbeat.cancel()
                self.connected = False
                self._ws = None

    async def _heartbeat_loop(self, interval_s: int) -> None:
        while True:
            await asyncio.sleep(interval_s)
            with contextlib.suppress(ConnectionError, websockets.ConnectionClosed):
                await self._send(HeartbeatFrame(at=datetime.now(UTC)))

    async def _handle(self, frame: object) -> None:
        if isinstance(frame, AckFrame):
            self.last_ack_seq = max(self.last_ack_seq, frame.seq)
            self.outbox.ack(frame.seq)
        elif isinstance(frame, CommandFrame):
            age = (datetime.now(UTC) - frame.issued_at).total_seconds()
            if age > 30:
                result = CommandResultFrame(
                    command_id=frame.command_id,
                    ok=False,
                    observed_state=None,
                    error="Kommando zu alt (Replay-Schutz)",
                    at=datetime.now(UTC),
                )
            else:
                result = await self.on_command(frame)
            await self._send(result)
        elif isinstance(frame, HeartbeatFrame):
            pass
        else:
            log.debug("uplink frame ignored", type=getattr(frame, "type", "?"))

    def stop(self) -> None:
        self._stop.set()

    @property
    def seconds_since_contact(self) -> float | None:
        return (
            None
            if self.last_contact is None
            else (datetime.now(UTC) - self.last_contact).total_seconds()
        )
