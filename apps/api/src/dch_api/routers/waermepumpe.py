"""Die Technikseite der Wärmepumpe: alle Messwerte des Augenblicks in einer Antwort."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from dch_api.application import kennlinie as kennlinie_logic
from dch_api.application import reglerkennzahl as kennzahl_logic
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import KennlinieOut, ReglerKennzahlenOut, WaermepumpeOut

router = APIRouter(prefix="/waermepumpe", tags=["Anlage"])


@router.get("", response_model=WaermepumpeOut, summary="Die Wärmepumpe im Augenblick")
async def waermepumpe(runner: Annotated[Runtime, Depends(get_runner)]) -> WaermepumpeOut:
    """Außengerät, Kältekreis, Innengerät und Speicher, je mit Zeitpunkt und Güte des Werts,
    dazu Spreizung, Wärmeleistung und Arbeitszahl als Abschätzung."""
    return await runner.waermepumpe()


@router.get("/kennlinie", response_model=KennlinieOut, summary="Die gemessene Kennlinie")
async def kennlinie(
    runner: Annotated[Runtime, Depends(get_runner)],
    tage: Annotated[
        int,
        Query(ge=1, le=kennlinie_logic.TAGE_HOECHSTENS, description="Rückblick in Tagen"),
    ] = kennlinie_logic.TAGE_STANDARD,
) -> KennlinieOut:
    """Arbeitszahl über Außen- und Vorlauftemperatur: Messpunkte aus dem Heizbetrieb, die
    Ausgleichsfläche nach kleinsten Quadraten und die Kennlinie, mit der der Fahrplan rechnet."""
    return await runner.kennlinie(tage)


@router.get("/kennzahlen", response_model=ReglerKennzahlenOut, summary="Die Kennzahlen des Reglers")
async def kennzahlen(
    runner: Annotated[Runtime, Depends(get_runner)],
    tage: Annotated[
        int,
        Query(ge=1, le=kennzahl_logic.TAGE_HOECHSTENS, description="Rückblick in Tagen"),
    ] = kennzahl_logic.TAGE_STANDARD,
) -> ReglerKennzahlenOut:
    """Was die Wärmepumpe unter welcher Kennzahl ihres Reglers tat: Minuten, Lauf, Vorlauf,
    Sollwert, Erwärmung des Speichers oben und unten. Belege, keine Deutung."""
    return await runner.reglerkennzahlen(tage)
