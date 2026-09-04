"""Fan-out von Ereignissen an SSE-Clients. Snapshot-Ereignisse werden bei Rückstau koalesziert."""

from __future__ import annotations

import asyncio
import contextlib
import json
from dataclasses import dataclass, field
from typing import Any

COALESCE = {"snapshot"}


@dataclass(eq=False)
class Subscriber:
    queue: asyncio.Queue[tuple[int, str, str]] = field(
        default_factory=lambda: asyncio.Queue(maxsize=8)
    )


class SseBroker:
    def __init__(self) -> None:
        self._subs: set[Subscriber] = set()
        self._seq = 0

    @property
    def client_count(self) -> int:
        return len(self._subs)

    def subscribe(self) -> Subscriber:
        s = Subscriber()
        self._subs.add(s)
        return s

    def unsubscribe(self, s: Subscriber) -> None:
        self._subs.discard(s)

    def publish(self, event: str, data: Any) -> None:
        self._seq += 1
        payload = json.dumps(data, default=str, ensure_ascii=False)
        for s in list(self._subs):
            if s.queue.full():
                # ältesten Eintrag verwerfen, aber nur, wenn er koaleszierbar ist
                try:
                    oldest = s.queue.get_nowait()
                    if oldest[1] not in COALESCE:
                        s.queue.put_nowait(oldest)  # nicht verwerfbar → zurücklegen
                        continue
                except asyncio.QueueEmpty:
                    pass
            with contextlib.suppress(asyncio.QueueFull):
                s.queue.put_nowait((self._seq, event, payload))
