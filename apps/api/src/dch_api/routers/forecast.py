from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import ForecastEvaluationOut

router = APIRouter(prefix="/forecast", tags=["Prognose"])


@router.get(
    "/evaluation",
    response_model=ForecastEvaluationOut,
    summary="Prognose gegen Ist, Tageskennzahlen, Korrekturfaktoren und was sich ändert",
)
async def evaluation(runner: Annotated[Runtime, Depends(get_runner)]) -> ForecastEvaluationOut:
    return await runner.forecast_evaluation()
