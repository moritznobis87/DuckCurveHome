"""Das Haus als Modell: der Plan und der Zustand seiner Tueren und Fenster.

Ein Endpunkt, keine Zeitreihe: Der Plan aendert sich, wenn jemand seine Datei aendert, und die
Kontakte sind ein Augenblick. Temperaturen und Sollwerte holt die Anzeige weiter unter `/rooms`,
den Alarm, den Puffer und die Waermepumpe aus dem Live-Zustand - der Plan verweist auf sie nur
ueber Raumkennungen und Schluessel.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import HouseOut

router = APIRouter(prefix="/haus", tags=["Haus"])


@router.get("", response_model=HouseOut, summary="Hausplan und Kontakte")
async def house(runner: Annotated[Runtime, Depends(get_runner)]) -> HouseOut:
    """Der Plan aus der Datei `haus.yaml` neben der Entity-Zuordnung, gemeldet von der Bruecke,
    und je Kontakt darin, ob er gerade offen ist. Ohne Plan sagt `error_de`, warum."""
    return await runner.house_plan()
