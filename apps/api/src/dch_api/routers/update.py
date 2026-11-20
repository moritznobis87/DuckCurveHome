"""
Updates des Hausgeraets aus der Oberflaeche (deploy/haus/README.md, Abschnitt "Updates").

Die API steuert Docker nicht: Wer an Docker kommt, ist praktisch Administrator des Geraets. Sie liest
nur die Statusdatei, die der Update-Dienst auf dem Geraet schreibt (`dch pruefen`, `dch anfrage`),
und legt fuer "Update installieren" eine Anfrage-Datei ab. systemd sieht sie und ruft den Dienst;
was dann geschieht - Sicherung, Laden, Neustart, Pruefung, notfalls zurueck -, entscheidet allein
das Skript auf dem Geraet.

Ohne `DCH_UPDATE_DIR` (Railway, Entwicklung) meldet der Endpunkt `unterstuetzt: false`.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from pathlib import Path

import structlog
from fastapi import APIRouter, Request
from pydantic import ValidationError

from dch_api import urheber
from dch_api.errors import DchError
from dch_api.schemas import UpdateAnfrageIn, UpdateStatusOut
from dch_api.settings import Settings

log = structlog.get_logger("update")

router = APIRouter(prefix="/system/update", tags=["System"])


def _ordner(request: Request) -> Path | None:
    settings: Settings = request.app.state.settings
    return Path(settings.update_dir) if settings.update_dir else None


def _status(ordner: Path) -> UpdateStatusOut:
    datei = ordner / "status.json"
    try:
        roh = json.loads(datei.read_text(encoding="utf-8"))
        status = UpdateStatusOut.model_validate({**roh, "unterstuetzt": True})
    except FileNotFoundError:
        # Der Dienst hat noch nie geprueft (frisch eingerichtet): unterstuetzt, aber ohne Befund.
        status = UpdateStatusOut(unterstuetzt=True)
    except (OSError, ValueError, ValidationError):
        log.warning("update_status_unlesbar", datei=str(datei))
        status = UpdateStatusOut(
            unterstuetzt=True, meldung="Der Stand des Update-Dienstes ist unlesbar."
        )
    status.anfrage_offen = (ordner / "anfrage" / "anfrage.json").exists()
    return status


@router.get("", response_model=UpdateStatusOut, summary="Steht ein Update bereit?")
def update_status(request: Request) -> UpdateStatusOut:
    ordner = _ordner(request)
    if ordner is None:
        return UpdateStatusOut(unterstuetzt=False)
    return _status(ordner)


@router.post(
    "",
    response_model=UpdateStatusOut,
    status_code=202,
    summary="Update installieren oder jetzt pruefen",
)
def update_anfragen(request: Request, anfrage: UpdateAnfrageIn) -> UpdateStatusOut:
    """Legt die Anfrage fuer den Update-Dienst ab und kehrt sofort zurueck (202). Den Fortschritt
    liest die Oberflaeche ueber GET; waehrend des Neustarts ist die API kurz nicht erreichbar."""
    ordner = _ordner(request)
    if ordner is None:
        raise DchError(
            "update_nicht_moeglich", "Auf diesem System gibt es keine Updates aus der App.", 409
        )
    status = _status(ordner)
    if status.zustand == "laeuft" or status.anfrage_offen:
        raise DchError("update_laeuft", "Es läuft bereits ein Update.", 409)
    if anfrage.aktion == "installieren" and not status.update_verfuegbar:
        raise DchError("kein_update", "Es steht kein Update bereit.", 409)

    wer = urheber.aktueller()
    inhalt = {
        "aktion": anfrage.aktion,
        "von": wer.text() if wer else "App",
        "am": datetime.now(UTC).isoformat(),
    }
    ziel = ordner / "anfrage" / "anfrage.json"
    teil = ziel.with_suffix(".teil")
    try:
        ziel.parent.mkdir(parents=True, exist_ok=True)
        teil.write_text(json.dumps(inhalt, ensure_ascii=False), encoding="utf-8")
        # Erst vollstaendig schreiben, dann umbenennen: systemd reagiert auf das Erscheinen der
        # Datei und soll nie eine halbe lesen.
        os.replace(teil, ziel)
    except OSError as fehler:
        log.warning("update_anfrage_nicht_geschrieben", fehler=repr(fehler))
        raise DchError(
            "update_nicht_moeglich", "Die Anfrage ließ sich nicht ablegen.", 500
        ) from fehler
    log.info("update_angefragt", aktion=anfrage.aktion, von=inhalt["von"])
    status.anfrage_offen = True
    return status
