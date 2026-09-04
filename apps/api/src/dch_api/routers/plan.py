from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.demo_runner import DemoRunner
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import PlanOut

router = APIRouter(prefix="/plan", tags=["Planung"])


@router.get("", response_model=PlanOut, summary="Aktueller Energieplan (Fenster und 15-min-Raster)")
def plan(runner: Annotated[DemoRunner, Depends(get_runner)]) -> PlanOut:
    if runner.plan is None:
        raise DchError("plan_unavailable", "Noch kein Plan berechnet.", 503)
    return runner.plan
