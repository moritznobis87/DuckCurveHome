from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import PlainTextResponse

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import (
    EnergySummaryOut,
    EvReportOut,
    HeatReportOut,
    Period,
    PvTaxReportOut,
    YearMapOut,
)
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


@router.get(
    "/pv",
    response_model=PvTaxReportOut,
    summary="PV-Abrechnung: Einspeisung, Eigenverbrauch, Umsatzsteuer",
)
async def pv(
    runner: Annotated[Runtime, Depends(get_runner)],
    period: Annotated[Period, Query()] = "year",
    anchor: date | None = None,
) -> PvTaxReportOut:
    return await runner.pv_report(period, _anchor(runner, anchor))


@router.get(
    "/year-map",
    response_model=YearMapOut,
    summary="Kalenderjahr als Fläche Tag × Stunde (Jahreskarte)",
)
async def year_map(
    runner: Annotated[Runtime, Depends(get_runner)],
    year: Annotated[int | None, Query(ge=2000, le=2100)] = None,
) -> YearMapOut:
    out: YearMapOut = await runner.year_map(year or _anchor(runner, None).year)
    return out


@router.get(
    "/diagnose",
    response_class=PlainTextResponse,
    summary="Einen Tag als Text aufschlüsseln (Stunden und auffällige Minuten)",
)
async def diagnose(
    runner: Annotated[Runtime, Depends(get_runner)],
    day: date | None = None,
) -> str:
    """Rohe Zahlen statt Grafik: was steht in den Stunden, und welche Minuten haben es dorthin
    gebracht. Gedacht für die Frage „diese Zahl kann nicht stimmen"."""
    return await runner.diagnose_day(_anchor(runner, day))
