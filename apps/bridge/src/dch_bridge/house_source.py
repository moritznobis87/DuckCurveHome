"""Der Hausplan: aus `haus.yaml` neben der Entity-Zuordnung wird ein Ereignis fuer die Cloud.

**Warum die Bruecke ihn liest und nicht der Dienst.** Der Plan beschreibt ein bewohntes Haus und
liegt deshalb dort, wo auch die Zugangsdaten liegen: auf dem Home-Assistant-Rechner, ausserhalb
des Repositorys. Die Bruecke prueft ihn gegen dasselbe Modell, mit dem der Dienst ihn wieder
liest, und schickt ihn als Ereignis, so wie die Raumliste der Einzelraumregelung. Ein Messwert ist
er nicht.

**Geprueft wird hier, gemeldet wird beides.** Eine Datei, die nicht durchgeht, ergibt ein
Ereignis mit dem Fehler statt mit dem Plan. Wer sie beim Zeichnen kaputt macht, sieht den Grund
auf der Seite und im Protokoll, mit Pfad im Dokument, statt eines Modells, das stillschweigend auf
dem alten Stand bleibt.

**Alle 30 Sekunden ein Blick auf die Datei.** Nicht auf den Inhalt, nur auf Aenderungszeit und
Groesse; gelesen und gesendet wird erst, wenn sich etwas getan hat. So laesst sich der Plan
zeichnen, ohne das Add-on jedes Mal neu zu starten.
"""

from __future__ import annotations

import asyncio
import hashlib
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import structlog
import yaml
from pydantic import ValidationError

from hems_core.house import HousePlan

log = structlog.get_logger("house")

EVENT_CODE = "house.plan"
POLL_S = 30.0
Emit = Callable[[datetime, str, str, str, dict[str, str]], Awaitable[None]]


@dataclass(frozen=True, slots=True)
class Gelesen:
    """Was ein Lesen der Datei ergab: Plan oder Fehler, und wovon."""

    plan: HousePlan | None
    fehler: str
    hash: str
    stand: tuple[float, int] | None  # Aenderungszeit und Groesse der Datei

    @property
    def vorhanden(self) -> bool:
        return self.stand is not None


def _fehlertext(exc: ValidationError) -> str:
    """Die ersten Fehler mit Pfad im Dokument, lesbar fuer jemanden, der die Datei bearbeitet."""
    teile = []
    for e in exc.errors()[:3]:
        pfad = ".".join(str(p) for p in e["loc"]) or "(Wurzel)"
        teile.append(f"{pfad}: {e['msg']}")
    rest = exc.error_count() - len(teile)
    return "; ".join(teile) + (f" (und {rest} weitere)" if rest > 0 else "")


def lesen(file: Path) -> Gelesen:
    """Die Datei lesen und pruefen. Fehlt sie, ist das kein Fehler: dann gibt es keinen Plan."""
    try:
        st = file.stat()
    except OSError:
        return Gelesen(None, "", "", None)
    stand = (st.st_mtime, st.st_size)
    try:
        text = file.read_text(encoding="utf-8")
    except OSError as exc:
        return Gelesen(None, f"Datei nicht lesbar: {exc}", "", stand)
    try:
        daten = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        return Gelesen(None, f"Kein gueltiges YAML: {str(exc).splitlines()[0]}", "", stand)
    if not isinstance(daten, dict):
        return Gelesen(None, "Die Datei muss ein Dokument mit `decks` sein.", "", stand)
    try:
        plan = HousePlan.model_validate(daten)
    except ValidationError as exc:
        return Gelesen(None, _fehlertext(exc), "", stand)
    digest = hashlib.sha256(plan.model_dump_json().encode()).hexdigest()[:16]
    return Gelesen(plan, "", digest, stand)


def ereignis(g: Gelesen, file: Path) -> tuple[str, str, dict[str, str]]:
    """Schwere, Satz und Zusammenhang des Ereignisses zu einem Leseergebnis."""
    if g.plan is not None:
        decks = len(g.plan.decks)
        raeume = sum(len(d.rooms) for d in g.plan.decks)
        return (
            "info",
            f"Hausplan mit {decks} Decks und {raeume} Raeumen",
            {"plan": g.plan.model_dump_json(exclude_none=True), "hash": g.hash, "file": str(file)},
        )
    return ("warning", f"Hausplan nicht lesbar: {g.fehler}", {"error": g.fehler, "file": str(file)})


class HousePlanSource:
    """Liest die Datei, meldet Aenderungen. Ein Ereignis je neuem Stand, keines fuer Stillstand."""

    def __init__(self, file: Path, emit: Emit, poll_s: float = POLL_S) -> None:
        self.file = file
        self.emit = emit
        self.poll_s = poll_s
        self._gemeldet: tuple[str, str] | None = None  # (hash, fehler) des letzten Ereignisses
        self._stand: tuple[float, int] | None = None

    async def tick(self) -> bool:
        """Einmal nachsehen. Gibt zurueck, ob ein Ereignis gesendet wurde."""
        g = lesen(self.file)
        if not g.vorhanden:
            if self._stand is not None:
                log.warning("house plan file vanished", file=str(self.file))
            self._stand = None
            return False
        if g.stand == self._stand:
            return False
        self._stand = g.stand
        kennung = (g.hash, g.fehler)
        if kennung == self._gemeldet:
            return False  # dieselbe Datei nur neu gespeichert
        self._gemeldet = kennung
        schwere, satz, ctx = ereignis(g, self.file)
        if g.plan is None:
            log.warning("house plan invalid", file=str(self.file), error=g.fehler)
        else:
            log.info("house plan loaded", file=str(self.file), hash=g.hash, decks=len(g.plan.decks))
        await self.emit(datetime.now(UTC), schwere, EVENT_CODE, satz, ctx)
        return True

    async def run(self) -> None:
        if not self.file.is_file():
            log.info("no house plan", file=str(self.file))
        while True:
            try:
                await self.tick()
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # pragma: no cover - Schutz der Schleife
                log.warning("house plan check failed", error=str(exc)[:200])
            await asyncio.sleep(self.poll_s)
