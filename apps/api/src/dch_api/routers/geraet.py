"""Technik -> Hausgerät: wie es dem Gerät und seinen Diensten geht, und ein paar Handgriffe.

Auf dem Hausgerät gibt es für den Hausherrn sonst keinen Zugang: kein Bildschirm, keine
Kommandozeile. Diese Seite ersetzt `dch status`, `dch logs` und `dch neustart`.

Die Werte kommen aus dem Bericht, den das Gerät jede Minute schreibt (`dch zustand`, siehe
`geraet_austausch`); die Handgriffe legt die API als Anfrage ab, ausgeführt werden sie auf dem
Gerät. Bewertet wird hier, nicht in den Oberflächen: Browser und iOS-App sollen dieselbe Ampel
zeigen, und eine Regel, die an zwei Stellen steht, läuft auseinander.

Ohne Hausgerät (Railway) gibt es nur die Selbstauskunft der API; `unterstuetzt` ist dann falsch.
"""

from __future__ import annotations

import asyncio
import re
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Annotated, Any

import structlog
from fastapi import APIRouter, Depends, Request
from pydantic import ValidationError
from sqlalchemy import text

from dch_api import geraet_austausch as austausch
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.infrastructure.prozess import speicher_mb
from dch_api.routers.health import running_commit
from dch_api.schemas import (
    Ampel,
    ApiSelbstOut,
    GeraetAktionIn,
    GeraetAktionOut,
    GeraetDienstOut,
    GeraetEinheitOut,
    GeraetOut,
    GeraetProtokollOut,
    GeraetRechnerOut,
    GeraetSicherungOut,
)

log = structlog.get_logger("geraet")

router = APIRouter(prefix="/system/geraet", tags=["System"])

_GESTARTET = time.monotonic()
_DIENSTNAME = re.compile(r"^[a-z][a-z0-9_-]{0,30}$")
#: Der Zeitgeber schreibt jede Minute; drei verpasste Läufe heißen: Er läuft nicht.
BERICHT_ALT = timedelta(minutes=3)
#: Eine Nacht darf ausfallen, zwei nicht: Die Sicherung läuft gegen 03:15.
SICHERUNG_ALT = timedelta(hours=36)

_RANG: dict[Ampel, int] = {"aus": 0, "gut": 1, "warn": 2, "schlecht": 3}

# `vcgencmd get_throttled`: Bits 0-3 gelten jetzt, 16-19 seit dem Start
# (https://www.raspberrypi.com/documentation/computers/os.html#get_throttled).
_DROSSEL_JETZT = {
    0: "Die Spannung ist gerade zu niedrig - Netzteil oder PoE-Versorgung reicht nicht.",
    1: "Der Prozessor ist gerade heruntergetaktet.",
    2: "Der Prozessor wird gerade gedrosselt.",
    3: "Die Temperaturgrenze ist gerade erreicht.",
}
_DROSSEL_SEIT_START = {
    16: "Seit dem Start war die Spannung mindestens einmal zu niedrig.",
    17: "Seit dem Start wurde der Prozessor heruntergetaktet.",
    18: "Seit dem Start wurde der Prozessor gedrosselt.",
    19: "Seit dem Start wurde die Temperaturgrenze erreicht.",
}


def _schlechteste(*ampeln: Ampel) -> Ampel:
    return max(ampeln, key=lambda a: _RANG[a], default="aus")


# --------------------------------------------------------------------------------- Bewertung


def bewerte_dienst(d: GeraetDienstOut) -> GeraetDienstOut:
    zustand, gesund = d.zustand, d.gesundheit
    if zustand == "fehlt":
        d.ampel, d.text_de = "schlecht", "Nicht angelegt - der Dienst wurde nie gestartet."
    elif zustand == "restarting":
        d.ampel, d.text_de = "schlecht", "Startet immer wieder neu."
    elif zustand == "exited":
        code = f" (Code {d.exit_code})" if d.exit_code is not None else ""
        d.ampel, d.text_de = "schlecht", f"Beendet{code}."
    elif zustand in ("paused", "created", "removing", "dead"):
        d.ampel, d.text_de = "warn", f"Steht ({zustand})."
    elif gesund == "unhealthy":
        mal = d.pruefung_fehlschlaege
        folge = f", {mal}-mal in Folge" if mal else ""
        d.ampel, d.text_de = "schlecht", f"Läuft, aber die Prüfung schlägt fehl{folge}."
    elif gesund == "starting":
        d.ampel, d.text_de = "warn", "Startet, die erste Prüfung steht noch aus."
    elif gesund == "healthy":
        d.ampel, d.text_de = "gut", "Läuft, Prüfung bestanden."
    else:
        d.ampel, d.text_de = "gut", "Läuft."
    if d.neustarts and d.ampel == "gut":
        d.text_de += f" Seit dem Anlegen {d.neustarts}-mal von selbst neu gestartet."
    return d


def bewerte_einheit(e: GeraetEinheitOut) -> GeraetEinheitOut:
    if e.aktiv == "failed":
        e.ampel, e.text_de = "schlecht", "Fehlgeschlagen."
    elif e.aktiv == "active":
        e.ampel = "gut"
        e.text_de = "Wartet auf den nächsten Lauf." if e.unterzustand == "waiting" else "Aktiv."
    elif e.aktiv in ("activating", "reloading"):
        e.ampel, e.text_de = "gut", "Läuft gerade."
    elif e.eingeschaltet:
        e.ampel, e.text_de = "warn", "Eingeschaltet, aber nicht aktiv."
    else:
        e.ampel, e.text_de = "warn", "Ausgeschaltet."
    return e


def drosselung_de(roh: str | None) -> tuple[list[str], Ampel]:
    if not roh:
        return [], "aus"
    try:
        wert = int(roh, 16)
    except ValueError:
        return [f"Unbekannte Angabe: {roh}"], "warn"
    jetzt = [t for bit, t in _DROSSEL_JETZT.items() if wert & (1 << bit)]
    frueher = [t for bit, t in _DROSSEL_SEIT_START.items() if wert & (1 << bit)]
    if jetzt:
        return jetzt + frueher, "schlecht"
    if frueher:
        return frueher, "warn"
    return [], "gut"


def bewerte_rechner(r: GeraetRechnerOut) -> GeraetRechnerOut:
    # Der Raspberry Pi drosselt sich ab 80 °C selbst; ab 70 °C ist die Kühlung schon knapp.
    if r.temperatur_c is not None:
        r.temperatur_ampel = (
            "schlecht" if r.temperatur_c >= 80 else "warn" if r.temperatur_c >= 70 else "gut"
        )
    r.drosselung_de, r.drosselung_ampel = drosselung_de(r.drosselung)
    if r.speicher_gesamt_mb:
        anteil = r.speicher_frei_mb / r.speicher_gesamt_mb
        r.speicher_ampel = "schlecht" if anteil < 0.05 else "warn" if anteil < 0.10 else "gut"
    for p in r.platten:
        anteil = p.frei_bytes / p.gesamt_bytes if p.gesamt_bytes else 1.0
        p.ampel = "schlecht" if anteil < 0.05 else "warn" if anteil < 0.15 else "gut"
    return r


def bewerte_sicherung(s: GeraetSicherungOut, jetzt: datetime) -> GeraetSicherungOut:
    if not s.letzte or s.letzte_am is None:
        s.ampel, s.text_de = "warn", "Noch keine Sicherung."
    elif jetzt - s.letzte_am > SICHERUNG_ALT:
        tage = (jetzt - s.letzte_am).days
        s.ampel = "warn"
        s.text_de = f"Die letzte Sicherung ist {max(tage, 1)} Tag(e) alt."
    else:
        s.ampel, s.text_de = "gut", f"{s.anzahl} Sicherung(en) auf dem Gerät."
    if s.ampel == "gut" and not s.ausser_haus:
        s.text_de += " Keine Kopie außer Haus eingerichtet."
    return s


# ---------------------------------------------------------------------------- Selbstauskunft


async def _datenbank(request: Request) -> tuple[bool | None, float | None, str]:
    engine = getattr(request.app.state, "engine", None)
    if engine is None:
        return None, None, "Ohne Datenbank (Vorführung)."
    beginn = time.perf_counter()
    try:
        async with asyncio.timeout(3):
            async with engine.connect() as verbindung:
                await verbindung.execute(text("SELECT 1"))
    except Exception as fehler:
        log.warning("datenbank_antwortet_nicht", fehler=repr(fehler)[:200])
        return False, None, "Die Datenbank antwortet nicht."
    ms = round((time.perf_counter() - beginn) * 1000, 1)
    return True, ms, f"Antwortet in {ms:.0f} ms."


async def selbstauskunft(request: Request, runner: Runtime) -> ApiSelbstOut:
    system = runner.live_state().system
    ok, ms, db_de = await _datenbank(request)
    rss, _ = speicher_mb()
    api = ApiSelbstOut(
        version=system.version,
        commit=running_commit(),
        modus=system.mode,
        laufzeit_s=int(time.monotonic() - _GESTARTET),
        rss_mb=round(rss or 0.0, 1),
        datenbank_ok=ok,
        datenbank_ms=ms,
        datenbank_de=db_de,
        bridge_online=system.bridge_online,
        verbindung_de=system.connection_label_de,
        quellen=system.sources,
        befunde=system.watch,
        sse_clients=system.sse_clients,
        alfred_eingerichtet=bool(runner.settings.alfred_schluessel),
        energy_rebuild=str(getattr(runner, "energy_rebuild", "")),
    )
    if ok is False:
        api.ampel, api.text_de = "schlecht", "Die Datenbank antwortet nicht."
    elif any(b.severity == "alarm" for b in api.befunde):
        api.ampel, api.text_de = "schlecht", api.befunde[0].title_de
    elif system.mode == "live" and not system.bridge_online:
        api.ampel, api.text_de = (
            "warn",
            "Die Bridge ist nicht verbunden; es kommen keine Messwerte.",
        )
    elif api.befunde:
        api.ampel, api.text_de = "warn", api.befunde[0].title_de
    else:
        api.ampel, api.text_de = "gut", "Die API läuft, Datenbank und Bridge antworten."
    return api


# ------------------------------------------------------------------------------- Endpunkte


def _liste(roh: Any, modell: type[Any]) -> list[Any]:
    """Liest eine Liste aus dem Bericht und überspringt Einträge, die nicht passen, statt die
    ganze Seite scheitern zu lassen."""
    aus: list[Any] = []
    for eintrag in roh if isinstance(roh, list) else []:
        try:
            aus.append(modell.model_validate(eintrag))
        except ValidationError:
            log.warning("geraet_eintrag_unlesbar", modell=modell.__name__)
    return aus


def _einzeln(roh: Any, modell: type[Any]) -> Any:
    if not isinstance(roh, dict):
        return None
    try:
        return modell.model_validate(roh)
    except ValidationError:
        log.warning("geraet_eintrag_unlesbar", modell=modell.__name__)
        return None


def zusammenstellen(ordner: Path, api: ApiSelbstOut, jetzt: datetime) -> GeraetOut:
    bericht = austausch.lies_json(ordner / "geraet.json") or {}
    out = GeraetOut(unterstuetzt=True, api=api)
    try:
        out.bericht_am = datetime.fromisoformat(str(bericht["erstellt_am"]).replace("Z", "+00:00"))
    except (KeyError, ValueError):
        out.bericht_am = None
    out.bericht_alt = out.bericht_am is None or jetzt - out.bericht_am > BERICHT_ALT
    out.kanal = bericht.get("kanal") or None
    out.fernzugang = bool(bericht.get("fernzugang"))
    rechner = _einzeln(bericht.get("rechner"), GeraetRechnerOut)
    out.rechner = bewerte_rechner(rechner) if rechner else None
    out.dienste = [bewerte_dienst(d) for d in _liste(bericht.get("dienste"), GeraetDienstOut)]
    out.einheiten = [bewerte_einheit(e) for e in _liste(bericht.get("einheiten"), GeraetEinheitOut)]
    sicherung = _einzeln(bericht.get("sicherung"), GeraetSicherungOut)
    out.sicherung = bewerte_sicherung(sicherung, jetzt) if sicherung else None
    out.letzte_aktion = _einzeln(austausch.lies_json(ordner / "aktion.json"), GeraetAktionOut)
    out.beschaeftigt = austausch.beschaeftigt(ordner)

    # Das Gesamturteil: das schlechteste Einzelurteil, mit seinem Grund.
    kandidaten: list[tuple[Ampel, str]] = [(api.ampel, f"API: {api.text_de}")]
    kandidaten += [(d.ampel, f"{d.name}: {d.text_de}") for d in out.dienste]
    kandidaten += [(e.ampel, f"{e.name}: {e.text_de}") for e in out.einheiten]
    if out.rechner:
        r = out.rechner
        if r.temperatur_c is not None:
            kandidaten.append((r.temperatur_ampel, f"Temperatur {r.temperatur_c:.0f} °C."))
        if r.drosselung_de:
            kandidaten.append((r.drosselung_ampel, r.drosselung_de[0]))
        kandidaten.append((r.speicher_ampel, "Der Arbeitsspeicher wird knapp."))
        kandidaten += [(p.ampel, f"Auf {p.ort} wird der Platz knapp.") for p in r.platten]
    if out.sicherung:
        kandidaten.append((out.sicherung.ampel, out.sicherung.text_de))
    if out.bericht_alt:
        kandidaten.append(
            ("warn", "Das Gerät hat seit Minuten keinen Bericht geschrieben; die Werte sind alt.")
        )
    out.ampel = _schlechteste(*(a for a, _ in kandidaten))
    if out.ampel == "gut":
        out.text_de = "Alles in Ordnung."
    else:
        out.text_de = next(t for a, t in kandidaten if a == out.ampel)
    return out


@router.get("", response_model=GeraetOut, summary="Wie es dem Hausgerät und seinen Diensten geht")
async def geraet(request: Request, runner: Annotated[Runtime, Depends(get_runner)]) -> GeraetOut:
    api = await selbstauskunft(request, runner)
    ordner = austausch.ordner(request)
    if ordner is None:
        return GeraetOut(unterstuetzt=False, api=api, ampel=api.ampel, text_de=api.text_de)
    return zusammenstellen(ordner, api, datetime.now(UTC))


@router.post(
    "/aktion",
    response_model=GeraetAktionOut,
    status_code=202,
    summary="Einen Handgriff auf dem Gerät anfragen",
)
def aktion(request: Request, anfrage: GeraetAktionIn) -> GeraetAktionOut:
    """Dienst neu starten, jetzt sichern, Protokoll holen, Gerät neu starten oder den Bericht
    erneuern. Kehrt sofort zurück (202); wie es ausging, steht danach in `letzte_aktion`."""
    ordner = austausch.ordner(request)
    if ordner is None:
        raise DchError("kein_hausgeraet", "Das gibt es nur auf dem Hausgerät.", 409)
    if anfrage.aktion in ("neustart", "protokoll"):
        if not anfrage.dienst:
            raise DchError("dienst_fehlt", "Welcher Dienst?", 422)
        bekannt = {
            d.get("name")
            for d in (austausch.lies_json(ordner / "geraet.json") or {}).get("dienste", [])
            if isinstance(d, dict)
        }
        erlaubt = bekannt | ({"alle"} if anfrage.aktion == "neustart" else set())
        if bekannt and anfrage.dienst not in erlaubt:
            raise DchError("dienst_unbekannt", f"Einen Dienst {anfrage.dienst} gibt es nicht.", 422)
    grund = austausch.beschaeftigt(ordner)
    if grund:
        raise DchError("geraet_beschaeftigt", grund, 409)
    felder = {"dienst": anfrage.dienst} if anfrage.dienst else {}
    inhalt = austausch.anfrage_ablegen(ordner, anfrage.aktion, **felder)
    return GeraetAktionOut(
        aktion=anfrage.aktion,
        dienst=anfrage.dienst,
        zustand="angefragt",
        von=inhalt["von"],
        begonnen_am=datetime.fromisoformat(inhalt["am"]),
    )


@router.get(
    "/protokoll/{dienst}",
    response_model=GeraetProtokollOut,
    summary="Die zuletzt geholten Protokollzeilen eines Dienstes",
)
def protokoll(request: Request, dienst: str) -> GeraetProtokollOut:
    """Liefert, was `aktion: protokoll` zuletzt geholt hat (300 Zeilen, Geheimnisse geschwärzt).
    Frisch wird es nur über die Aktion; diese Abfrage liest bloß die Datei."""
    if not _DIENSTNAME.match(dienst):
        raise DchError("dienst_unbekannt", "Diesen Dienst gibt es nicht.", 422)
    ordner = austausch.ordner(request)
    if ordner is None:
        raise DchError("kein_hausgeraet", "Das gibt es nur auf dem Hausgerät.", 409)
    datei = ordner / "protokoll" / f"{dienst}.txt"
    try:
        inhalt = datei.read_text(encoding="utf-8", errors="replace")
        erstellt = datetime.fromtimestamp(datei.stat().st_mtime, UTC)
    except FileNotFoundError:
        return GeraetProtokollOut(dienst=dienst, vorhanden=False)
    return GeraetProtokollOut(
        dienst=dienst, vorhanden=True, erstellt_am=erstellt, zeilen=inhalt.splitlines()[-300:]
    )
