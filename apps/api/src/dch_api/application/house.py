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
from datetime import UTC, datetime
from pathlib import PurePosixPath

from pydantic import ValidationError

from hems_core.domain import Measurement
from hems_core.domain.zeit import HAUS_ZONE
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
        return None, "Die Meldung der Brücke enthält keinen Hausplan."
    try:
        return HousePlan.model_validate_json(roh), ""
    except ValidationError as exc:
        return (
            None,
            "Der Hausplan der Brücke passt nicht zu dem, was dieser Dienst lesen kann "
            f"({exc.error_count()} Fehler). Brücke und Dienst sind dann auf verschiedenem Stand.",
        )


def contact_open(m: Measurement) -> bool | None:
    """Offen, zu oder unbekannt. Nur ein frischer Wert zaehlt: ein Kontakt, der seit Stunden
    schweigt, sagt nichts darueber, ob die Tuer gerade offen steht."""
    if m.value is None or not m.quality.usable:
        return None
    return m.value >= 0.5


def source_text(context: Mapping[str, object], at: datetime | None) -> str:
    """Woher der Plan kommt, für die Zeile über dem Hausmodell: Datei und Zeitpunkt der Meldung.

    Die Zeile steht in Dashboard und App hinter dem Namen des Plans, also etwa „Zuhause · aus
    haus.yaml, gemeldet am 26.11.2026 um 08:19 Uhr“. Sie beginnt deshalb klein und ist kein
    eigener Satz.

    Bis zum 27.11.2026 hieß sie „Bruecke, /config/duckcurve/haus.yaml, gemeldet 26.11.2026 07:19
    UTC“: der ganze Pfad im Add-on, den auf der Seite niemand braucht, und die Uhrzeit in
    Weltzeit, im Winter eine und im Sommer zwei Stunden vor der Uhr des Hauses. Genannt wird
    jetzt nur der Name der Datei, weil er sagt, was zu bearbeiten ist, und die Zeit des Hauses
    (`HAUS_ZONE`).
    """
    datei = PurePosixPath(str(context.get(CTX_FILE) or "")).name
    woher = f"aus {datei}" if datei else "von der Brücke"
    if at is None:
        return woher if datei else f"{woher} gemeldet"
    ortszeit = (at if at.tzinfo else at.replace(tzinfo=UTC)).astimezone(HAUS_ZONE)
    wann = f"am {ortszeit:%d.%m.%Y} um {ortszeit:%H:%M} Uhr"
    return f"{woher}, gemeldet {wann}" if datei else f"{woher} gemeldet {wann}"


def contact_rooms(plan: HousePlan) -> dict[str, Contact]:
    """Kontakte nach Schluessel, ueber alle Decks."""
    return {k.key: k for k in plan.contacts}
