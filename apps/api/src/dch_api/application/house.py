"""Der Hausplan: aus einem Ereignis der Bruecke wird die Geometrie der Modellansicht.

**Derselbe Weg wie die Raumliste.** Ein Grundriss ist kein Messwert; er geht nicht durch die
Telemetrie, sondern als Zusammenhang eines Ereignisses, und gelesen wird immer der juengste
Eintrag. Anders als bei der Raumliste ist der Inhalt kein Schluessel je Angabe, sondern ein
Dokument: Der Plan hat Listen in Listen, und die Bruecke hat ihn vor dem Senden schon gegen
dasselbe Modell geprueft, das hier wieder liest.

**Zwei Faelle unter einem Code.** Ein gueltiger Plan kommt mit `plan`; eine Datei, die sich nicht
lesen liess, kommt mit `error`. Beides unter `house.plan`, damit der juengste Eintrag immer den
letzten Stand sagt: Wer seine Datei kaputt macht, sieht den Fehler, und wer sie repariert, sieht
den Plan. Ein alter Plan, der stillschweigend weiterliefe, saehe aus wie Erfolg.

Dieses Modul rechnet nur. Es liest nichts und kennt weder Datenbank noch HTTP.
"""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime

from pydantic import ValidationError

from hems_core.domain import Measurement
from hems_core.house import Contact, HousePlan

# Der Ereigniscode im Protokoll. Die Bruecke schickt `house.plan`; alles von ihr wird als
# `bridge.<code>` abgelegt.
EVENT_CODE = "bridge.house.plan"
# Schluessel im Zusammenhang des Ereignisses.
CTX_PLAN = "plan"
CTX_HASH = "hash"
CTX_FILE = "file"
CTX_ERROR = "error"
# Ab wann ein Kontakt als alt gilt. Die Kontakte melden ueber Home Assistant nur bei Aenderung,
# und die Bruecke stempelt beim Vollabruf alle 30 Sekunden neu; eine halbe Stunde Stille ist
# also kein Takt mehr, sondern ein Ausfall der Quelle.
STALE_S = 1800.0


def plan_from_context(context: Mapping[str, object]) -> tuple[HousePlan | None, str]:
    """Der Plan aus dem Zusammenhang, oder der Grund, warum es keinen gibt.

    Gibt `(plan, "")` zurueck, wenn ein gueltiger Plan darin steht, sonst `(None, grund)`. Ein Plan,
    den die Bruecke fuer gueltig hielt und der hier nicht mehr durchgeht, ist ein Versionsstand,
    der auseinanderlaeuft - auch das ist ein Grund, keine Ausnahme.
    """
    fehler = context.get(CTX_ERROR)
    if fehler:
        return None, str(fehler)
    roh = context.get(CTX_PLAN)
    if not isinstance(roh, str) or not roh:
        return None, "Das Ereignis der Bruecke enthaelt keinen Plan."
    try:
        return HousePlan.model_validate_json(roh), ""
    except ValidationError as exc:
        return (
            None,
            f"Der Plan der Bruecke passt nicht zum Schema dieses Dienstes: {exc.error_count()} Fehler.",
        )


def contact_open(m: Measurement) -> bool | None:
    """Offen, zu oder unbekannt. Nur ein frischer Wert zaehlt: ein Kontakt, der seit Stunden
    schweigt, sagt nichts darueber, ob die Tuer gerade offen steht."""
    if m.value is None or not m.quality.usable:
        return None
    return m.value >= 0.5


def source_text(context: Mapping[str, object], at: datetime | None) -> str:
    """Woher der Plan kommt, fuer die Anzeige: Datei und Zeitpunkt der Meldung."""
    datei = str(context.get(CTX_FILE) or "")
    wann = at.strftime("%d.%m.%Y %H:%M") if at is not None else ""
    if datei and wann:
        return f"Bruecke, {datei}, gemeldet {wann} UTC"
    if datei:
        return f"Bruecke, {datei}"
    return "Bruecke"


def contact_rooms(plan: HousePlan) -> dict[str, Contact]:
    """Kontakte nach Schluessel, ueber alle Decks."""
    return {k.key: k for k in plan.contacts}
