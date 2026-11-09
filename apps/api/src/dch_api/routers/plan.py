from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import NachbetrachtungOut, PlanOut
from hems_core.simulation import BERLIN

router = APIRouter(prefix="/plan", tags=["Planung"])


@router.get("", response_model=PlanOut, summary="Aktueller Energieplan (Fenster und 15-min-Raster)")
def plan(runner: Annotated[Runtime, Depends(get_runner)]) -> PlanOut:
    if runner.plan is None:
        raise DchError("plan_unavailable", "Noch kein Plan berechnet.", 503)
    return runner.plan


@router.get(
    "/nachbetrachtung",
    response_model=NachbetrachtungOut,
    summary="Ein Ortstag in Euro: versprochen, gehalten, wirklich",
)
async def nachbetrachtung(
    runner: Annotated[Runtime, Depends(get_runner)], day: date
) -> NachbetrachtungOut:
    """Was der Fahrplan für diesen Tag versprach, was er gehalten hätte und was der Tag kostete.

    Die Antwort rechnet einen Vergleichslauf mit perfekter Voraussicht und braucht dafür so lange
    wie ein Lauf des Optimierers, im schlechtesten Fall einige Sekunden. Für einen Tag in der
    Zukunft gibt es nichts zu betrachten.
    """
    if day > runner.now.astimezone(BERLIN).date():
        raise DchError(
            "future_day", "Der Tag liegt in der Zukunft; es gibt nichts zu betrachten.", 422
        )
    return await runner.nachbetrachtung(day)
