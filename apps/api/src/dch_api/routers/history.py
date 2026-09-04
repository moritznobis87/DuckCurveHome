from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import HistoryOut
from hems_core.simulation import BERLIN

router = APIRouter(prefix="/history", tags=["Historie"])


@router.get("", response_model=HistoryOut, summary="Minutenmittel eines Zeitraums")
async def history(
    runner: Annotated[Runtime, Depends(get_runner)],
    range_: Annotated[
        Literal["today", "yesterday", "24h", "custom"], Query(alias="range")
    ] = "today",
    start: datetime | None = None,
    end: datetime | None = None,
) -> HistoryOut:
    now = runner.now
    local_day = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
    if range_ == "today":
        s, e = local_day.astimezone(UTC), (local_day + timedelta(days=1)).astimezone(UTC)
    elif range_ == "yesterday":
        s, e = (local_day - timedelta(days=1)).astimezone(UTC), local_day.astimezone(UTC)
    elif range_ == "24h":
        s, e = now - timedelta(hours=24), now
    else:
        if start is None or end is None:
            raise DchError(
                "missing_range", "start und end sind für range=custom erforderlich.", 422
            )
        s, e = start, end
        if e <= s or e - s > timedelta(days=7):
            raise DchError(
                "invalid_range", "Zeitraum muss positiv und höchstens 7 Tage lang sein.", 422
            )
    return HistoryOut(start=s, end=e, rows=await runner.history_rows(s, e))
