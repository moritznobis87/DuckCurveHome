"""Die Regelkreis-Karte: lesen, einen Parameter übersteuern, ihn wieder freigeben."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Body, Depends, Path

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import RegelkreisOut, RegelkreisStellenIn

router = APIRouter(prefix="/regelkreis", tags=["Anlage"])


@router.get("", response_model=RegelkreisOut, summary="Die Regelkreis-Karte")
async def regelkreis(runner: Annotated[Runtime, Depends(get_runner)]) -> RegelkreisOut:
    """Die ganze Kaskade: Blöcke, Signale, Störgrößen, die geltenden Parameter mit ihrer Herkunft,
    der daraus entworfene Regler je Kreis mit Reserven und Frequenzkennlinie, und das Protokoll
    der Übernahmen.

    Gerechnet für den Augenblick: die Verstärkung der Wärmepumpe hängt von Außen- und
    Vorlauftemperatur ab, und `arbeitspunkt.gemessen` sagt, ob diese Zahlen aus der Messung kamen.
    """
    return await runner.regelkreis()


@router.post(
    "/parameter/{pid}",
    response_model=RegelkreisOut,
    summary="Einen Parameter übersteuern",
)
async def uebersteuern(
    runner: Annotated[Runtime, Depends(get_runner)],
    pid: Annotated[str, Path(description="Kennung des Parameters, etwa `wp_totzeit`")],
    body: Annotated[RegelkreisStellenIn, Body()],
) -> RegelkreisOut:
    """Einen geschätzten Wert von Hand setzen.

    Die Übersteuerung gewinnt gegen jede Schätzung, bis sie freigegeben wird; der Schätzer läuft
    weiter und schreibt mit, was er gesagt hätte. Beschnitten wird auf die
    Plausibilitätsgrenzen - wer sich vertippt, bringt die Regelung nicht zum Stehen.

    Die abgeleiteten Reglerwerte ändern sich mit: das ist der Zweck, denn so lässt sich sehen, was
    eine andere Streckenannahme aus dem Regler macht.
    """
    return await runner.regelkreis_uebersteuern(pid, body.wert)


@router.delete(
    "/parameter/{pid}",
    response_model=RegelkreisOut,
    summary="Eine Übersteuerung aufheben",
)
async def freigeben(
    runner: Annotated[Runtime, Depends(get_runner)],
    pid: Annotated[str, Path(description="Kennung des Parameters")],
) -> RegelkreisOut:
    """Die Übersteuerung aufheben; es gilt wieder, was gelernt wurde."""
    return await runner.regelkreis_freigeben(pid)
