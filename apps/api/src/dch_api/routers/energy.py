from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import EnergySummaryOut, EvReportOut, HeatReportOut, Period
from hems_core.simulation import BERLIN

router = APIRouter(prefix="/energy", tags=["Energiebilanz"])


def _anchor(runner: Runtime, anchor: date | None) -> date:
    return anchor or runner.now.astimezone(BERLIN).date()


@router.get("/summary", response_model=EnergySummaryOut, summary="Energiebilanz eines Zeitraums")
async def summary(
    runner: Annotated[Runtime, Depends(get_runner)],
    period: Annotated[Period, Query()] = "day",
    anchor: date | None = None,
) -> EnergySummaryOut:
    return await runner.energy_summary(period, _anchor(runner, anchor))


@router.get(
    "/heat", response_model=HeatReportOut, summary="Wärme: WP-Strom, Kosten, Wärmebedarfsprognose"
)
async def heat(
    runner: Annotated[Runtime, Depends(get_runner)],
    period: Annotated[Period, Query()] = "day",
    anchor: date | None = None,
) -> HeatReportOut:
    return await runner.heat_report(period, _anchor(runner, anchor))


@router.get(
    "/ev",
    response_model=EvReportOut,
    summary="Wallbox: Ladeenergie, Herkunft, Kosten, Ladevorgänge",
)
async def ev(
    runner: Annotated[Runtime, Depends(get_runner)],
    period: Annotated[Period, Query()] = "day",
    anchor: date | None = None,
) -> EvReportOut:
    return await runner.ev_report(period, _anchor(runner, anchor))
