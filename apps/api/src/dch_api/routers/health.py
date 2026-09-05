from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner

router = APIRouter(tags=["System"])


@router.get("/", summary="Wegweiser", include_in_schema=False)
def root() -> dict[str, object]:
    return {
        "service": "Duck Curve Home API",
        "hint": "Das Dashboard läuft im Web-Service. Diese API nutzen Bridge (/bridge/ws) und Web-BFF (/api/v1).",
        "health": "/health",
        "docs": "/docs",
    }


@router.get("/health", summary="Gesundheitszustand")
def health(runner: Annotated[Runtime, Depends(get_runner)]) -> dict[str, object]:
    return {
        "status": "ok",
        "version": runner.live_state().system.version,
        "mode": runner.settings.mode,
        "server_time": runner.now.isoformat(),
        "sse_clients": runner.broker.client_count,
    }
