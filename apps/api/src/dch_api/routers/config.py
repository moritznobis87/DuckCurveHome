from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import HeatConfigIn
from hems_core.domain import HemsConfig

router = APIRouter(prefix="/config", tags=["Konfiguration"])


@router.get("", response_model=HemsConfig, summary="Aktive Regler- und Modellkonfiguration")
def config(request: Request) -> HemsConfig:
    hems: HemsConfig = request.app.state.hems
    return hems


@router.post("/heat", response_model=HemsConfig, summary="Wärmeannahmen ändern")
async def set_heat(
    patch: HeatConfigIn,
    request: Request,
    runner: Annotated[Runtime, Depends(get_runner)],
) -> HemsConfig:
    """Die Annahmen der Wärmerechnung ändern: Kennlinie, Ofen, Puffer, Pellets.

    **Wirkt sofort und rückwirkend.** Die Auswertungen rechnen bei jeder Abfrage neu, und gespeichert
    sind Eingänge und keine Ergebnisse; eine korrigierte Zahl gilt deshalb auch für letztes Jahr. Das
    ist Absicht: eine Annahme, die nur nach vorn wirkt, lässt die Vergangenheit falsch stehen, ohne
    dass es jemandem auffällt.

    Die neue Fassung wird als Konfigurationsstand gespeichert und übersteht einen Neustart. Gäste
    kommen hier nicht hin: der Proxy der Oberfläche lässt für sie nur GET durch.
    """
    neu = await runner.update_heat_config(patch)
    request.app.state.hems = neu
    return neu
