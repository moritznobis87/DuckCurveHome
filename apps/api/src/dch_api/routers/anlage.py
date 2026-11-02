"""Das Anlagenschema: der Augenblick der Wasser- und Stromseite in einer Antwort."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import AnlageOut

router = APIRouter(prefix="/anlage", tags=["Anlage"])


@router.get("", response_model=AnlageOut, summary="Anlagenschema im Augenblick")
async def anlage(runner: Annotated[Runtime, Depends(get_runner)]) -> AnlageOut:
    return await runner.anlage()
