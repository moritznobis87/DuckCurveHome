from __future__ import annotations

import os
from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner

router = APIRouter(tags=["System"])


def running_commit() -> str:
    """Welcher Stand hier gerade läuft, aus der Umgebung der Plattform.

    Ohne das ist „ist mein Fehler schon behoben?" nicht zu beantworten, ohne im Deployment-Verlauf
    zu suchen: `version` ist eine Konstante im Quelltext und ändert sich mit keinem Deploy.
    Railway setzt `RAILWAY_GIT_COMMIT_SHA`; lokal steht hier `dev`.
    """
    sha = os.environ.get("RAILWAY_GIT_COMMIT_SHA") or os.environ.get("GIT_COMMIT_SHA") or ""
    return sha[:7] if sha else "dev"


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
        "commit": running_commit(),
        "mode": runner.settings.mode,
        "server_time": runner.now.isoformat(),
        "sse_clients": runner.broker.client_count,
    }
