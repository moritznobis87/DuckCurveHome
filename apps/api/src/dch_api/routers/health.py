from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner

router = APIRouter(tags=["System"])


@router.get("/health", summary="Gesundheitszustand")
def health(runner: Annotated[Runtime, Depends(get_runner)]) -> dict[str, object]:
    return {
        "status": "ok",
        "version": runner.live_state().system.version,
        "mode": runner.settings.mode,
        "server_time": runner.now.isoformat(),
        "sse_clients": runner.broker.client_count,
    }
