"""Auskunft über den Betrieb selbst: was die Datenbank belegt.

Eigener Router und nicht in `/health`, weil hier gezählt wird statt geantwortet: die Abfrage über
`pg_class` ist billig, aber sie gehört nicht in einen Endpunkt, den eine Überwachung im Minutentakt
aufruft.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import StorageReportOut, StorageTableOut

router = APIRouter(prefix="/system", tags=["System"])


@router.get("/storage", response_model=StorageReportOut, summary="Platzbedarf der Datenbank")
async def storage(runner: Annotated[Runtime, Depends(get_runner)]) -> StorageReportOut:
    repos = getattr(runner, "repos", None)
    rows = await repos.storage_report() if repos is not None else []
    tables = [StorageTableOut(**r) for r in rows]
    days = runner.settings.raw_retention_days
    note = (
        f"Rohwerte werden {days} Tage aufgehoben. Gebraucht werden sie nur, bis die Minute "
        "verdichtet ist - das geschieht alle fünf Minuten. Alles darüber ist Vorrat."
        if tables
        else "Ohne PostgreSQL gibt es keine Größenangaben."
    )
    return StorageReportOut(
        tables=tables,
        total_bytes=sum(t.total_bytes for t in tables),
        raw_retention_days=days,
        note_de=note,
    )
