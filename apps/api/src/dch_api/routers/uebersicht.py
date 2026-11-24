"""Die Übersicht eines Bereichs: je Seite eine Karte mit Leitzahl und Ampel."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from dch_api.application import uebersicht
from dch_api.application.push import PushService
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.routers import geraet as geraet_seite
from dch_api.routers import push as push_seite
from dch_api.routers import system as system_seite
from dch_api.schemas import UebersichtOut

router = APIRouter(prefix="/uebersicht", tags=["Übersicht"])


@router.get(
    "/{bereich}",
    response_model=UebersichtOut,
    summary="Die Karten der Übersicht eines Bereichs",
)
async def bereichsuebersicht(
    bereich: str,
    request: Request,
    runner: Annotated[Runtime, Depends(get_runner)],
    push: Annotated[PushService, Depends(push_seite.get_push)],
) -> UebersichtOut:
    """Je Seite des Bereichs die wichtigste Zahl und ein Zustand, fertig formuliert.

    Der Schlüssel des Bereichs ist der aus `docs/seitenbaum.json`. Eine Übersicht gibt es für
    die Bereiche in `uebersicht.BEREICHE`. Welche Karten ein Betrachter sieht, entscheidet die
    Oberfläche wie bei den Seiten selbst.

    Die Übersicht des Systems bleibt dem Hausherrn (`auth/rechte.py`, `AKTEN`): Ihre Karte der
    Haustür liest das Protokoll der Haustür, und das ist eine Akte.
    """
    if bereich == "anlage":
        return await uebersicht.anlage(runner)
    if bereich == "energie":
        return await uebersicht.energie(runner)
    if bereich == "system":
        # Dieselben Antworten, die die fünf Seiten des Systems bekommen.
        return await uebersicht.system(
            mitteilungen=lambda: push_seite.geraete(push),
            haustuer=lambda: system_seite.door_log(
                runner, days=uebersicht.HAUSTUER_TAGE, limit=system_seite.MAX_DOOR_ENTRIES
            ),
            geraet=lambda: geraet_seite.geraet(request, runner),
            platz=lambda: system_seite.storage(runner),
            abdeckung=lambda: system_seite.coverage(runner, None, uebersicht.ABDECKUNG_TAGE),
        )
    raise DchError("unknown_area", f"Für den Bereich {bereich} gibt es keine Übersicht.", 404)
