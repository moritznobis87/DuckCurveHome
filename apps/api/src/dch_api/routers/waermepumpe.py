"""Die Technikseite der Wärmepumpe: alle Messwerte des Augenblicks in einer Antwort."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import WaermepumpeOut

router = APIRouter(prefix="/waermepumpe", tags=["Anlage"])


@router.get("", response_model=WaermepumpeOut, summary="Die Wärmepumpe im Augenblick")
async def waermepumpe(runner: Annotated[Runtime, Depends(get_runner)]) -> WaermepumpeOut:
    """Außengerät, Kältekreis, Innengerät und Speicher, je mit Zeitpunkt und Güte des Werts,
    dazu Spreizung, Wärmeleistung und Arbeitszahl als Abschätzung."""
    return await runner.waermepumpe()
