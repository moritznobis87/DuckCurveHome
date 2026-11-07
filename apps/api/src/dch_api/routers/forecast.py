from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import ForecastEvaluationOut, ForecastHistoryOut

router = APIRouter(prefix="/forecast", tags=["Prognose"])


@router.get(
    "/evaluation",
    response_model=ForecastEvaluationOut,
    summary="Prognose gegen Ist, Tageskennzahlen, Korrekturfaktoren und was sich ändert",
)
async def evaluation(runner: Annotated[Runtime, Depends(get_runner)]) -> ForecastEvaluationOut:
    return await runner.forecast_evaluation()


@router.get(
    "/history",
    response_model=ForecastHistoryOut,
    summary="Was die abgelegten Prognosen wert waren, nach Abstand zur Lieferung",
)
async def history(
    runner: Annotated[Runtime, Depends(get_runner)],
    days: Annotated[int, Query(ge=1, le=30)] = 7,
) -> ForecastHistoryOut:
    return await runner.forecast_history(days)
