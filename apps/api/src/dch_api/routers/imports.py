"""Import historischer Daten (Home-Assistant-Recorder-Export) in die Energiebilanz."""

from __future__ import annotations

import json
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request

from dch_api.application.ha_import import ImportResult
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner

router = APIRouter(prefix="/import", tags=["Import"])


@router.post(
    "/ha",
    response_model=ImportResult,
    summary="HA-Recorder-Export (CSV, optional gzip) in Stundenbilanzen übernehmen",
)
async def import_ha(
    request: Request,
    runner: Annotated[Runtime, Depends(get_runner)],
    kind: Annotated[Literal["auto", "states", "statistics"], Query()] = "auto",
    dry_run: Annotated[bool, Query()] = False,
    extra_map: Annotated[
        str | None, Query(description="JSON {entity: {key, unit?, sign?, scale?}}")
    ] = None,
) -> ImportResult:
    payload = await request.body()
    extra = json.loads(extra_map) if extra_map else None
    return await runner.import_history(payload, kind, dry_run, extra)
