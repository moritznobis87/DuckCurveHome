"""
Updates des Hausgeraets aus der Oberflaeche (deploy/haus/README.md, Abschnitt "Updates").

Die API steuert Docker nicht: Wer an Docker kommt, ist praktisch Administrator des Geraets. Sie liest
nur die Statusdatei, die der Update-Dienst auf dem Geraet schreibt (`dch pruefen`, `dch anfrage`),
und legt fuer "Update installieren" eine Anfrage-Datei ab. systemd sieht sie und ruft den Dienst;
was dann geschieht - Sicherung, Laden, Neustart, Pruefung, notfalls zurueck -, entscheidet allein
das Skript auf dem Geraet.

Ohne `DCH_GERAET_DIR` (Railway, Entwicklung) meldet der Endpunkt `unterstuetzt: false`.
"""

from __future__ import annotations

from pathlib import Path

import structlog
from fastapi import APIRouter, Request
from pydantic import ValidationError

from dch_api import geraet_austausch as austausch
from dch_api.errors import DchError
from dch_api.schemas import UpdateAnfrageIn, UpdateStatusOut

log = structlog.get_logger("update")

router = APIRouter(prefix="/system/update", tags=["System"])


def _status(ordner: Path) -> UpdateStatusOut:
    datei = ordner / "status.json"
    roh = austausch.lies_json(datei)
    try:
        if roh is None and datei.exists():
            raise ValueError("unlesbar")
        # Ohne Datei hat der Dienst noch nie geprueft (frisch eingerichtet): unterstuetzt, ohne Befund.
        status = UpdateStatusOut.model_validate({**(roh or {}), "unterstuetzt": True})
    except (ValidationError, ValueError):
        log.warning("update_status_unlesbar")
        status = UpdateStatusOut(
            unterstuetzt=True, meldung="Der Stand des Update-Dienstes ist unlesbar."
        )
    status.anfrage_offen = austausch.anfrage_offen(ordner)
    return status


@router.get("", response_model=UpdateStatusOut, summary="Steht ein Update bereit?")
def update_status(request: Request) -> UpdateStatusOut:
    ordner = austausch.ordner(request)
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
    ordner = austausch.ordner(request)
    if ordner is None:
        raise DchError(
            "update_nicht_moeglich", "Auf diesem System gibt es keine Updates aus der App.", 409
        )
    status = _status(ordner)
    grund = austausch.beschaeftigt(ordner)
    if grund:
        raise DchError("update_laeuft", grund, 409)
    if anfrage.aktion == "installieren" and not status.update_verfuegbar:
        raise DchError("kein_update", "Es steht kein Update bereit.", 409)
    austausch.anfrage_ablegen(ordner, anfrage.aktion)
    status.anfrage_offen = True
    return status
