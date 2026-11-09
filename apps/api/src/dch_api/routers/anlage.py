"""Das Anlagenschema: der Augenblick der Wasser- und Stromseite in einer Antwort."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from dch_api.application.anlage_replay import SCHRITTE
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import AnlageOut, AnlageReplayOut

router = APIRouter(prefix="/anlage", tags=["Anlage"])


@router.get("", response_model=AnlageOut, summary="Anlagenschema im Augenblick")
async def anlage(runner: Annotated[Runtime, Depends(get_runner)]) -> AnlageOut:
    return await runner.anlage()


@router.get(
    "/wiedergabe",
    response_model=AnlageReplayOut,
    summary="Ein Ortstag als Folge von Anlagenbildern",
)
async def wiedergabe(
    runner: Annotated[Runtime, Depends(get_runner)],
    day: date,
    step_min: Annotated[int, Query(description="Schrittweite in Minuten: 1, 5 oder 15")] = 5,
) -> AnlageReplayOut:
    """Dieselben Bilder wie `GET /anlage`, nur aus der Minutenreihe eines vergangenen Tages.

    Die Oberflaeche faehrt mit einem Schieber darueber, und das Schema zeichnet jedes Bild so, wie
    es den Augenblick zeichnet. Luecken in der Erfassung bleiben Luecken; `erwartet` sagt, wie
    viele Bilder ein vollstaendiger Tag ergeben haette.

    `step_min` ist auf drei Werte begrenzt und nicht frei: eine Schrittweite von sieben Minuten
    ergaebe ein Band, dessen Raster zu keiner Uhrzeit passt.
    """
    if step_min not in SCHRITTE:
        raise DchError(
            "bad_step",
            f"Schrittweite {step_min} gibt es nicht; erlaubt sind {', '.join(map(str, SCHRITTE))}.",
            422,
        )
    return await runner.anlage_replay(day, step_min)
