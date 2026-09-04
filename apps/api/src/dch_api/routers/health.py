from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.demo_runner import VERSION, DemoRunner
from dch_api.dependencies import get_runner

router = APIRouter(tags=["System"])


@router.get("/health", summary="Gesundheitszustand")
def health(runner: Annotated[DemoRunner, Depends(get_runner)]) -> dict[str, object]:
    return {
        "status": "ok",
        "version": VERSION,
        "mode": runner.settings.mode,
        "server_time": runner.now.isoformat(),
        "sse_clients": runner.broker.client_count,
    }
