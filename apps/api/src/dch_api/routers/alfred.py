"""
Alfred: Fragen an den Helfer (docs/ALFRED.md).

`/ask` nimmt eine getippte Frage samt Hilfetexten entgegen und gibt die Antwort als JSON zurueck;
`/ask/stream` dieselbe Frage als Ereignisstrom mit einem Zwischenstand je Werkzeug. Dazu zwei feste
Auswertungen: `/rechnung` liest die Stromrechnung eines anderen Anbieters, `/zuordnung` schlaegt
die Entitaetszuordnung fuer ein neues Haus vor.

Die Tagesgrenze zaehlt im Prozess, nicht in der Datenbank: Sie schuetzt die Rechnung vor einer
Schleife, sie rechnet nicht ab. Gezaehlt wird je Geraet (Urheber aus dem BFF).

Gaeste erreichen keinen dieser Endpunkte ausser `/status`: Das BFF laesst fuer sie nur GET durch.
"""

from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from typing import Annotated, Any

import structlog
from fastapi import APIRouter, Depends, Request
from sse_starlette.sse import EventSourceResponse

from dch_api.alfred import dienst, rechnung, zuordnung
from dch_api.alfred.werkzeuge import Kontext, NurLesen
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import (
    AlfredAntwortOut,
    AlfredFrageIn,
    AlfredVorschlagOut,
    AlfredZuordnungIn,
    AlfredZustandOut,
)
from dch_api.settings import Settings

log = structlog.get_logger("alfred")

router = APIRouter(prefix="/alfred", tags=["Alfred"])

#: Hoechstgroesse einer hochgeladenen Rechnung in Bytes.
PDF_MAX = 10 * 1024 * 1024


def _settings(request: Request) -> Settings:
    settings: Settings = request.app.state.settings
    return settings


def _zaehlen(request: Request, settings: Settings) -> None:
    """Zaehlt die Anfrage und wirft bei erreichter Tagesgrenze. Vor jedem Modellaufruf, auch vor
    dem ersten Byte eines Stroms: Ein begonnener Strom traegt Status 200 und kann ihn nicht mehr
    aendern."""
    # Je App und nicht je Modul: Zwei Apps in einem Vorgang (Tests) zaehlen getrennt.
    if not hasattr(request.app.state, "alfred_heute"):
        request.app.state.alfred_heute = defaultdict(int)
    _heute: dict[tuple[str, str], int] = request.app.state.alfred_heute
    wer = request.headers.get("x-dch-urheber-name") or "ohne-namen"
    # Alte Tage fallen heraus, damit das Woerterbuch nicht ueber Monate waechst.
    heute = datetime.now(UTC).date().isoformat()
    for schluessel in [s for s in _heute if s[1] != heute]:
        del _heute[schluessel]
    _heute[(wer, heute)] += 1
    if _heute[(wer, heute)] > settings.alfred_fragen_pro_tag:
        raise DchError(
            "zu_viele_fragen",
            "Für heute sind genug Fragen gestellt.",
            429,
            {"hoechstens": settings.alfred_fragen_pro_tag},
        )


def _bereit_oder_fehler(settings: Settings) -> None:
    if not dienst.aktiv(settings):
        raise DchError("alfred_aus", "Für Alfred ist kein Sprachmodell eingerichtet.", 409)


def _verlauf(anfrage: AlfredFrageIn) -> list[tuple[str, str]]:
    return [(w.wer, w.inhalt) for w in anfrage.verlauf]


def _antwort(antwort: dienst.Antwort) -> AlfredAntwortOut:
    return AlfredAntwortOut(
        bereit=True,
        antwort=antwort.text,
        vorschlaege=[AlfredVorschlagOut.model_validate(v) for v in antwort.vorschlaege],
    )


@router.get("/status", response_model=AlfredZustandOut, summary="Kann Alfred antworten?")
def zustand(request: Request) -> AlfredZustandOut:
    """Liest nur Einstellungen; kein Modell, keine Kosten. Die Oberflaeche zeigt das Eingabefeld nur
    bei `bereit` und nennt im Panel den Anbieter."""
    settings = _settings(request)
    if not dienst.aktiv(settings):
        return AlfredZustandOut(bereit=False)
    return AlfredZustandOut(
        bereit=True, anbieter=dienst.anbietername(settings), modell=dienst.modell(settings)
    )


@router.post("/ask", response_model=AlfredAntwortOut, summary="Eine Frage an den Helfer")
async def frage(
    request: Request, anfrage: AlfredFrageIn, runner: Annotated[Runtime, Depends(get_runner)]
) -> AlfredAntwortOut:
    """Ohne eingerichtetes Modell `bereit=False` statt eines Fehlers; die Oberflaeche zeigt dann
    ihre vorbereiteten Texte."""
    settings = _settings(request)
    if not dienst.aktiv(settings):
        return AlfredAntwortOut(bereit=False, antwort="")
    _zaehlen(request, settings)
    try:
        antwort = await dienst.fragen(
            settings, anfrage.frage, anfrage.wissen, Kontext(runner), _verlauf(anfrage)
        )
    except dienst.AlfredError as fehler:
        log.warning("alfred_abgelehnt", grund=str(fehler))
        raise DchError(
            "alfred_scheitert",
            "Die Frage konnte nicht beantwortet werden.",
            502,
            {"grund": str(fehler)},
        ) from fehler
    return _antwort(antwort)


@router.post("/ask/stream", summary="Eine Frage an den Helfer, mit Fortschritt")
async def frage_mit_fortschritt(
    request: Request, anfrage: AlfredFrageIn, runner: Annotated[Runtime, Depends(get_runner)]
) -> EventSourceResponse:
    """Dieselbe Frage wie POST /alfred/ask, mit Ereignissen: `schritt` je laufendem Werkzeug
    (nur der Name - den Satz dazu hat die Oberflaeche), zuletzt `antwort` oder `fehler`.

    POST statt EventSource, weil EventSource nur GET ohne Rumpf kann und die Hilfetexte mitgehen.
    """
    settings = _settings(request)
    if not dienst.aktiv(settings):

        async def aus() -> AsyncIterator[dict[str, str]]:
            yield {
                "event": "antwort",
                "data": AlfredAntwortOut(bereit=False, antwort="").model_dump_json(),
            }

        return EventSourceResponse(aus())
    _zaehlen(request, settings)
    schlange: asyncio.Queue[tuple[str, dict[str, Any]]] = asyncio.Queue()

    async def melden(schritt: dict[str, Any]) -> None:
        await schlange.put(("schritt", schritt))

    async def lauf() -> None:
        try:
            antwort = await dienst.fragen(
                settings, anfrage.frage, anfrage.wissen, Kontext(runner), _verlauf(anfrage), melden
            )
            await schlange.put(("antwort", _antwort(antwort).model_dump(mode="json")))
        except dienst.AlfredError as fehler:
            log.warning("alfred_abgelehnt", grund=str(fehler))
            await schlange.put(("fehler", {"code": "alfred_scheitert", "grund": str(fehler)}))
        except Exception:
            # Der Ausnahmetext bleibt draussen: Er kann die Frage zitieren.
            log.exception("alfred_unerwartet")
            await schlange.put(("fehler", {"code": "alfred_scheitert", "grund": "unerwartet"}))

    async def strom() -> AsyncIterator[dict[str, str]]:
        aufgabe = asyncio.create_task(lauf())
        try:
            while True:
                art, daten = await schlange.get()
                yield {"event": art, "data": json.dumps(daten, ensure_ascii=False)}
                if art != "schritt":
                    break
        finally:
            if not aufgabe.done():
                aufgabe.cancel()

    return EventSourceResponse(strom(), ping=15)


@router.post(
    "/rechnung",
    response_model=rechnung.Rechnungsergebnis,
    summary="Stromrechnung eines anderen Anbieters lesen und gegen die eigene Messung halten",
)
async def rechnung_lesen(
    request: Request, runner: Annotated[Runtime, Depends(get_runner)]
) -> rechnung.Rechnungsergebnis:
    """Das PDF als Rumpf (`application/pdf`). An den Anbieter gehen nur geschwaerzte Zeilen mit
    Mengen, Preisen und Zeitraeumen; gespeichert wird nichts (alfred/rechnung.py)."""
    settings = _settings(request)
    _bereit_oder_fehler(settings)
    payload = await request.body()
    if not payload:
        raise DchError("leer", "Keine Datei erhalten.", 400)
    if len(payload) > PDF_MAX:
        raise DchError("zu_gross", "Die Datei ist größer als 10 MB.", 413)
    try:
        text = rechnung.pdf_text(payload)
    except ValueError as fehler:
        raise DchError("pdf_unlesbar", str(fehler), 422) from fehler
    zeilen = rechnung.relevante_zeilen(text)
    if not zeilen:
        raise DchError("kein_text", "Im PDF steht kein lesbarer Text (vermutlich ein Scan).", 422)
    _zaehlen(request, settings)
    try:
        roh = await dienst.auswerten(settings, rechnung.SYSTEMTEXT, "\n".join(zeilen))
    except dienst.AlfredError as fehler:
        log.warning("alfred_rechnung_abgelehnt", grund=str(fehler))
        raise DchError(
            "alfred_scheitert",
            "Die Rechnung konnte nicht gelesen werden.",
            502,
            {"grund": str(fehler)},
        ) from fehler
    # Auch hier nur lesend: die Pruefung braucht den Zaehler, sonst nichts.
    return await rechnung.pruefen(NurLesen(runner), rechnung.lesen(roh), len(zeilen))


@router.post(
    "/zuordnung",
    response_model=zuordnung.Zuordnungsergebnis,
    summary="Entitätszuordnung für ein neues Haus vorschlagen",
)
async def zuordnung_vorschlagen(
    request: Request, eingabe: AlfredZuordnungIn
) -> zuordnung.Zuordnungsergebnis:
    """Aus einer eingefuegten Entitaetenliste einen gepruefen YAML-Ausschnitt fuer `sensors:`.
    Schreibt nichts; die Datei liegt in Home Assistant."""
    settings = _settings(request)
    _bereit_oder_fehler(settings)
    zeilen, kennungen = zuordnung.eingabe(eingabe.liste)
    if not zeilen:
        raise DchError(
            "keine_entitaeten", "In der Liste steht keine Entität der Form sensor.….", 422
        )
    _zaehlen(request, settings)
    try:
        roh = await dienst.auswerten(
            settings, zuordnung.systemtext(), "LISTE:\n" + "\n".join(zeilen), max_token=2000
        )
    except dienst.AlfredError as fehler:
        log.warning("alfred_zuordnung_abgelehnt", grund=str(fehler))
        raise DchError(
            "alfred_scheitert",
            "Es konnte keine Zuordnung vorgeschlagen werden.",
            502,
            {"grund": str(fehler)},
        ) from fehler
    return zuordnung.pruefen(roh, kennungen, len(zeilen))
