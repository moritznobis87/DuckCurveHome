"""Die Übersicht eines Bereichs: je Seite eine Karte mit Leitzahl und Ampel."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application import uebersicht
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import UebersichtOut

router = APIRouter(prefix="/uebersicht", tags=["Übersicht"])


@router.get(
    "/{bereich}",
    response_model=UebersichtOut,
    summary="Die Karten der Übersicht eines Bereichs",
)
async def bereichsuebersicht(
    bereich: str, runner: Annotated[Runtime, Depends(get_runner)]
) -> UebersichtOut:
    """Je Seite des Bereichs die wichtigste Zahl und ein Zustand, fertig formuliert.

    Der Schlüssel des Bereichs ist der aus `docs/seitenbaum.json`. Eine Übersicht gibt es für
    die Bereiche in `uebersicht.BEREICHE`. Welche Karten ein Betrachter sieht, entscheidet die
    Oberfläche wie bei den Seiten selbst.
    """
    karten = await uebersicht.bereich(bereich, runner)
    if karten is None:
        raise DchError("unknown_area", f"Für den Bereich {bereich} gibt es keine Übersicht.", 404)
    return karten
