from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sse_starlette.sse import EventSourceResponse

from dch_api.application.demo_runner import DemoRunner
from dch_api.dependencies import get_runner
from dch_api.schemas import LiveStateOut

router = APIRouter(prefix="/live", tags=["Live"])


@router.get("/state", response_model=LiveStateOut, summary="Aktueller Zustand")
def state(runner: Annotated[DemoRunner, Depends(get_runner)]) -> LiveStateOut:
    return runner.live_state()


@router.get("/stream", summary="Server-Sent Events: snapshot, decision, plan, system")
async def stream(
    request: Request, runner: Annotated[DemoRunner, Depends(get_runner)]
) -> EventSourceResponse:
    sub = runner.broker.subscribe()

    async def gen() -> AsyncIterator[dict[str, str]]:
        try:
            # Erst der vollständige Zustand, dann die Ereignisse
            yield {"event": "snapshot", "id": "0", "data": runner.live_state().model_dump_json()}
            if runner.plan is not None:
                yield {"event": "plan", "id": "0", "data": runner.plan.model_dump_json()}
            while True:
                if await request.is_disconnected():
                    break
                try:
                    seq, event, payload = await asyncio.wait_for(sub.queue.get(), timeout=5.0)
                except TimeoutError:
                    yield {"event": "heartbeat", "data": runner.now.isoformat()}
                    continue
                yield {"event": event, "id": str(seq), "data": payload}
        finally:
            runner.broker.unsubscribe(sub)

    return EventSourceResponse(gen(), ping=15)
