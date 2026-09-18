"""Auskunft über den Betrieb selbst: was die Datenbank belegt.

Eigener Router und nicht in `/health`, weil hier gezählt wird statt geantwortet: die Abfrage über
`pg_class` ist billig, aber sie gehört nicht in einen Endpunkt, den eine Überwachung im Minutentakt
aufruft.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import (
    CoverageOut,
    CoverageSeriesOut,
    DoorEntryOut,
    DoorLogOut,
    StorageReportOut,
    StorageTableOut,
)
from hems_core.simulation import BERLIN

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


# Welche Reihen die Verfügbarkeitskarte zeigt. Bewusst nur diese beiden: sie messen dieselbe Größe
# an derselben Stelle, und genau ihr Vergleich ist die offene Frage. Eine Karte mit fünfzehn Reihen
# beantwortet sie nicht besser, sondern gar nicht mehr.
COVERAGE_SERIES: list[tuple[str, str]] = [
    ("grid_power_meter_kw", "Zähler (inexogy)"),
    ("grid_power_kw", "Stromwandler (Libbi)"),
    # Die Tür gehört nicht zur Energiebilanz, aber zur selben Frage: kommt an, was ankommen soll.
    # Ob die Strecke zum Schloss trägt, entscheidet sich an dieser Zeile und nicht am Gefühl.
    ("door_lock_online", "Weg zum Türschloss"),
]
MAX_COVERAGE_DAYS = 90


@router.get("/coverage", response_model=CoverageOut, summary="Verfügbarkeit der Netzreihen")
async def coverage(
    runner: Annotated[Runtime, Depends(get_runner)],
    anchor: date | None = None,
    days: int = 28,
) -> CoverageOut:
    """Wie lückenlos die beiden Netzmessungen in den letzten Tagen angekommen sind.

    Der Zeitraum endet am Ankertag, damit die Karte zu dem Tag passt, den die Prüfseite gerade
    zeigt, und nicht zu heute.
    """
    span = max(1, min(MAX_COVERAGE_DAYS, days))
    last_day = anchor or runner.now.astimezone(BERLIN).date()
    end_local = datetime.combine(last_day, time(0), tzinfo=BERLIN) + timedelta(days=1)
    start_local = end_local - timedelta(days=span)
    start, end = start_local.astimezone(UTC), end_local.astimezone(UTC)
    repos = getattr(runner, "repos", None)
    keys = [k for k, _ in COVERAGE_SERIES]
    hourly = await repos.hourly_coverage(keys, start, end) if repos is not None else {}
    now = runner.now
    out: list[CoverageSeriesOut] = []
    for key, label in COVERAGE_SERIES:
        hours = hourly.get(key, [])
        seen = sum(n for _, n in hours)
        # Erwartet werden die Stunden bis jetzt, nicht bis Mitternacht: ein angebrochener Tag darf
        # die Abdeckung nicht drücken, nur weil er noch nicht vorbei ist.
        horizon = min(end, now)
        expected = max(0, int((horizon - start).total_seconds() // 60))
        run = best = 0
        for _, n in hours:
            run = run + 1 if n == 0 else 0
            best = max(best, run)
        last_at = await repos.last_value_at(key) if repos is not None else None
        out.append(
            CoverageSeriesOut(
                key=key,
                label_de=label,
                hours=hours,
                # Nach oben begrenzt: liegt die Uhr des Geräts ein paar Minuten vor unserer, gäbe
                # es sonst „100,6 % Abdeckung". Der Leser lernt daraus nichts über den Zähler,
                # sondern nur über zwei Uhren, und dafür ist diese Ansicht nicht da.
                coverage=round(min(1.0, seen / expected), 4) if expected else 0.0,
                minutes_seen=seen,
                minutes_expected=expected,
                incomplete_hours=sum(1 for _, n in hours if n < 60),
                longest_outage_h=best,
                last_at=last_at,
            )
        )
    return CoverageOut(
        start=start,
        end=end,
        series=out,
        note_de=(
            "Gezählt werden die Minuten, für die ein Wert im dauerhaften Bestand steht. "
            "Der längste Ausfall zählt nur vollständig leere Stunden und ist damit eine Untergrenze."
        ),
    )


# Unter diesem Code legt die API ab, was die Bridge als `door_access` meldet.
DOOR_EVENT_CODE = "bridge.door_access"
MAX_DOOR_DAYS = 90
MAX_DOOR_ENTRIES = 500


@router.get("/door", response_model=DoorLogOut, summary="Zutritte an der Haustür")
async def door_log(
    runner: Annotated[Runtime, Depends(get_runner)],
    days: int = 14,
    limit: int = 200,
) -> DoorLogOut:
    """Wer sich wann an der Haustür erkannt hat, jüngster Eintrag zuerst.

    **Nur lesen.** Es gibt hier keinen Weg zur Tür und soll keinen geben: die Entscheidung fällt im
    Haus, an einer Erlaubnisliste in der Bridge, und die Cloud erfährt davon erst hinterher. Ein
    Endpunkt, der öffnen könnte, wäre eine Tür, die am Internet hängt.

    Gezeigt werden auch die abgelehnten Versuche. Für die eine Frage, wegen der man abends
    hineinsieht - stand jemand vor der Tür, den das Haus nicht kannte - sind sie die eigentliche
    Auskunft.
    """
    span = max(1, min(MAX_DOOR_DAYS, days))
    count = max(1, min(MAX_DOOR_ENTRIES, limit))
    since = runner.now - timedelta(days=span)
    repos = getattr(runner, "repos", None)
    rows = await repos.events_by_code(DOOR_EVENT_CODE, since, count) if repos is not None else []
    entries = [DoorEntryOut(at=r.at, **_door_fields(r.context)) for r in rows]
    opened = sum(1 for e in entries if e.outcome == "geöffnet")
    note = (
        f"{len(entries)} Ereignisse in {span} Tagen, davon {opened} geöffnet."
        if entries
        else "Noch kein Zutritt aufgezeichnet. Die Bridge meldet jeden Scan, sobald sie ihn sieht."
    )
    return DoorLogOut(entries=entries, days=span, note_de=note)


def _door_fields(context: object) -> dict[str, object]:
    """Die Zusatzfelder eines Ereignisses in die Felder einer Zeile übersetzen.

    Nachsichtig, weil das Protokoll älter sein kann als diese Fassung: eine Zeile aus einer früheren
    Version der Bridge soll nicht die ganze Abfrage zum Scheitern bringen, sondern mit leeren
    Feldern dastehen. Ein Protokoll, das bei der ersten Formänderung nicht mehr lesbar ist, ist
    kein Protokoll.
    """
    c = context if isinstance(context, dict) else {}
    return {
        "actor": str(c.get("actor") or ""),
        "door": str(c.get("door") or ""),
        "method": str(c.get("method") or ""),
        "outcome": str(c.get("outcome") or "unbekannt"),
        "granted": str(c.get("granted") or "") == "ja",
        "reason": str(c.get("reason") or ""),
    }
