"""Der Austausch mit dem Hausgerät über Dateien (deploy/haus/dch, deploy/haus/README.md).

Die API steuert weder Docker noch systemd: Wer an Docker kommt, ist praktisch Administrator des
Geräts. Stattdessen liegt unter `DCH_GERAET_DIR` ein Ordner, den das Gerät beschreibt und die API
liest - `status.json` (Updates), `geraet.json` (Gesundheitsbericht, jede Minute), `aktion.json`
(die zuletzt angefragte Aktion), `protokoll/<dienst>.txt` - und ein Unterordner `anfrage/`, in
den die API genau eine Anfrage legen darf. systemd sieht sie (`duckcurve-anfrage.path`) und ruft
`dch anfrage`; was dann geschieht, entscheidet allein das Skript.

Gemeinsam für `routers/update.py` und `routers/geraet.py`, damit beide dieselbe Anfrage-Datei
schreiben und dieselbe Sperre achten: Es gibt immer höchstens eine offene Anfrage.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import structlog
from fastapi import Request

from dch_api import urheber
from dch_api.errors import DchError
from dch_api.settings import Settings

log = structlog.get_logger("geraet")


def ordner(request: Request) -> Path | None:
    """Der Austauschordner, oder `None` ohne Hausgerät (Railway, Entwicklung)."""
    settings: Settings = request.app.state.settings
    return Path(settings.geraet_dir) if settings.geraet_dir else None


def anfrage_datei(o: Path) -> Path:
    return o / "anfrage" / "anfrage.json"


def anfrage_offen(o: Path) -> bool:
    return anfrage_datei(o).exists()


def offene_anfrage(o: Path) -> str | None:
    """Welche Anfrage auf `dch anfrage` wartet (`installieren`, `pruefen`, `neustart`, ...).

    Alle Anfragen teilen sich eine Datei. Ob ein Update läuft, entscheidet darum die Aktion darin
    und nicht, dass die Datei da ist: Sonst zeigte „Jetzt nach Updates sehen“ oder ein Neustart
    eines Dienstes „Update läuft“. Eine unlesbare Datei heißt `unbekannt`.
    """
    if not anfrage_offen(o):
        return None
    aktion = (lies_json(anfrage_datei(o)) or {}).get("aktion")
    return aktion if isinstance(aktion, str) and aktion else "unbekannt"


def lies_json(datei: Path) -> dict[str, Any] | None:
    """Eine Datei des Geräts, oder `None`, wenn sie fehlt oder unlesbar ist."""
    try:
        roh = json.loads(datei.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        log.warning("geraet_datei_unlesbar", datei=str(datei))
        return None
    return roh if isinstance(roh, dict) else None


def anfrage_ablegen(o: Path, aktion: str, **felder: str) -> dict[str, str]:
    """Legt die Anfrage für `dch anfrage` ab und gibt ihren Inhalt zurück.

    Erst vollständig in eine Nebendatei, dann umbenennen: systemd reagiert auf das Erscheinen der
    Datei und soll nie eine halbe lesen.
    """
    wer = urheber.aktueller()
    inhalt = {
        "aktion": aktion,
        **felder,
        "von": wer.text() if wer else "App",
        "am": datetime.now(UTC).isoformat(),
    }
    ziel = anfrage_datei(o)
    teil = ziel.with_suffix(".teil")
    try:
        ziel.parent.mkdir(parents=True, exist_ok=True)
        teil.write_text(json.dumps(inhalt, ensure_ascii=False), encoding="utf-8")
        os.replace(teil, ziel)
    except OSError as fehler:
        log.warning("anfrage_nicht_geschrieben", fehler=repr(fehler))
        raise DchError(
            "geraet_nicht_erreichbar", "Die Anfrage ließ sich nicht ablegen.", 500
        ) from fehler
    log.info("geraet_angefragt", aktion=aktion, von=inhalt["von"], **felder)
    return inhalt


def beschaeftigt(o: Path) -> str | None:
    """Warum gerade keine neue Anfrage angenommen wird, oder `None`."""
    if anfrage_offen(o):
        return "Eine Anfrage wird gerade bearbeitet."
    status = lies_json(o / "status.json") or {}
    if status.get("zustand") == "laeuft":
        return "Es läuft bereits ein Update."
    aktion = lies_json(o / "aktion.json") or {}
    if aktion.get("zustand") == "laeuft" and not _verwaist(aktion.get("begonnen_am")):
        return "Das Gerät ist noch mit der letzten Aktion beschäftigt."
    return None


def _verwaist(begonnen_am: object) -> bool:
    """Eine Aktion, die seit zehn Minuten "läuft", ist abgebrochen (Stromausfall, Absturz) und
    soll die nächste nicht für immer sperren. Die längste, ein Neustart mit Prüfung, braucht drei."""
    try:
        t = datetime.fromisoformat(str(begonnen_am).replace("Z", "+00:00"))
    except ValueError:
        return True
    return (datetime.now(UTC) - t).total_seconds() > 600
