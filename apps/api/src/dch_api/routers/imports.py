"""Import historischer Daten (Home-Assistant-Recorder-Export) in die Energiebilanz."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request

from dch_api.application.ha_import import ImportResult
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import BackfillResultOut, SystemEventOut

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
    replace_until: Annotated[
        datetime | None,
        Query(
            description="Stunden vor diesem Zeitpunkt auch dann ersetzen, wenn sie schon voll sind"
        ),
    ] = None,
) -> ImportResult:
    payload = await request.body()
    extra = json.loads(extra_map) if extra_map else None
    return await runner.import_history(payload, kind, dry_run, extra, replace_until)


@router.post(
    "/myenergi-backfill",
    response_model=BackfillResultOut,
    summary="myenergi-Minutenhistorie der letzten Stunden nachladen (Lücken füllen)",
)
async def myenergi_backfill(
    runner: Annotated[Runtime, Depends(get_runner)],
    hours: Annotated[int, Query(ge=1, le=336)] = 48,
    start: Annotated[
        datetime | None,
        Query(description="Beginn (UTC); dann gilt end bzw. start+hours, höchstens 62 Tage"),
    ] = None,
    end: Annotated[datetime | None, Query()] = None,
) -> BackfillResultOut:
    return await runner.myenergi_backfill(hours, start, end)


@router.get("/events", response_model=list[SystemEventOut], summary="Letzte Systemereignisse")
async def events(
    runner: Annotated[Runtime, Depends(get_runner)],
    limit: Annotated[int, Query(ge=1, le=500)] = 50,
) -> list[SystemEventOut]:
    return await runner.recent_events(limit)
