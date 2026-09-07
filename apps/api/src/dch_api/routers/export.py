"""Datenexport: die Messreihen als komprimiertes CSV herunterladen.

Die Datenbank ist die einzige Kopie. „Für immer aufbewahren" hält nur, was auch außerhalb dieses
Anbieters liegt - ein verwaltetes Volume ist kein Archiv. Diese Endpunkte liefern den Bestand als
Datei, die einen Anbieterwechsel überlebt.

Alles wird gestreamt und im Vorbeigehen komprimiert: ein Jahr Minutenwerte sind 525 600 Zeilen, und
weder der Dienst noch die Antwort sollen sie gleichzeitig im Speicher halten.
"""

from __future__ import annotations

import zlib
from collections.abc import AsyncIterator
from datetime import UTC, datetime, time, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from hems_core.simulation import BERLIN

router = APIRouter(prefix="/export", tags=["Export"])

KIND_LABEL = {"minutes": "minuten", "hours": "stunden"}


def _bounds(
    year: int | None, start: datetime | None, end: datetime | None
) -> tuple[datetime, datetime, str]:
    """Zeitraum und Namensteil der Datei. Ein Jahr ist das Kalenderjahr in Ortszeit, nicht in UTC."""
    if year is not None:
        s = datetime.combine(datetime(year, 1, 1).date(), time(0), tzinfo=BERLIN)
        e = datetime.combine(datetime(year + 1, 1, 1).date(), time(0), tzinfo=BERLIN)
        return s.astimezone(UTC), e.astimezone(UTC), str(year)
    if start is None or end is None:
        raise DchError("missing_range", "Entweder year oder start und end angeben.", 422)
    if end <= start:
        raise DchError("invalid_range", "end muss nach start liegen.", 422)
    if end - start > timedelta(days=800):
        raise DchError("invalid_range", "Höchstens 800 Tage je Abruf; sonst year verwenden.", 422)
    label = f"{start.astimezone(BERLIN):%Y%m%d}-{end.astimezone(BERLIN):%Y%m%d}"
    return start.astimezone(UTC), end.astimezone(UTC), label


async def _gzipped(chunks: AsyncIterator[str]) -> AsyncIterator[bytes]:
    """CSV-Stücke im Vorbeigehen zu einem gzip-Strom machen (wbits 31 = gzip-Rahmen)."""
    comp = zlib.compressobj(6, zlib.DEFLATED, 31)
    async for chunk in chunks:
        out = comp.compress(chunk.encode("utf-8"))
        if out:
            yield out
    tail = comp.flush()
    if tail:
        yield tail


@router.get(
    "/{kind}",
    summary="Messreihen als gzip-komprimiertes CSV herunterladen",
    response_class=StreamingResponse,
)
async def export(
    runner: Annotated[Runtime, Depends(get_runner)],
    kind: Literal["minutes", "hours"],
    year: Annotated[
        int | None, Query(ge=2000, le=2100, description="Kalenderjahr (Ortszeit)")
    ] = None,
    start: datetime | None = None,
    end: datetime | None = None,
) -> StreamingResponse:
    s, e, label = _bounds(year, start, end)
    name = f"dch-{KIND_LABEL[kind]}-{label}.csv.gz"
    return StreamingResponse(
        _gzipped(runner.export_csv(kind, s, e)),
        media_type="application/gzip",
        headers={
            "content-disposition": f'attachment; filename="{name}"',
            "cache-control": "no-store",
        },
    )
