"""Wärme, die in Räume mit offenem Fenster ging.

**Warum das in der Bilanz fehlte.** Die Wärmebilanz kennt drei Größen: was erzeugt wurde, was im
Puffer liegt, und als Rest die Entnahme - alles, was in die Heizkreise und ins Warmwasser ging.
Diese Entnahme heißt dort „Wärmebedarf". Für eine halbe Stunde Stoßlüften im Schlafzimmer ist das
die falsche Bezeichnung: Diese Wärme hat das Haus nicht gebraucht, sie ist hinausgegangen.

**Wie aufgeteilt wird.** Die Entnahme ist eine Zahl für das ganze Haus; welcher Raum wie viel davon
bekommen hat, sagt niemand. Es gibt aber zwei Reihen je Raum, die es verraten: wie viele seiner
Heizkreise offen sind (`valve` mal Kreise) und ob sein Fenster offen ist. Die Entnahme einer Minute
wird deshalb nach offenen Kreisen verteilt - vier offene Schleifen ziehen doppelt so viel wie zwei -,
und was dabei auf Räume mit offenem Fenster entfällt, steht hier.

**Was die Zahl ist und was nicht.** Sie ist die Wärme, die in dieser Zeit in Räume mit offenem
Fenster gegangen ist. Sie ist **nicht** der Lüftungsverlust: Ein Teil davon hat den Raum und seinen
Estrich gewärmt und ist im Haus geblieben. Und sie ist eher zu hoch als zu tief, denn in Minuten,
in denen zugleich Warmwasser gezapft wurde, bekommt auch dieser Anteil Räume zugeordnet - trennen
lässt sich das ohne Wärmemengenzähler nicht.

**Minuten ohne offene Kreise zählen nichts.** Steht kein Ventil offen, fließt auch nichts in die
Räume; was dann entnommen wird, ist Warmwasser. Genau deshalb ist die Gewichtung nach Kreisen die
richtige: Sie schließt diese Minuten von selbst aus.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime

#: Ab diesem Wert gilt ein Fenster als offen. Die Kontakte melden 0 oder 1.
OFFEN = 0.5


@dataclass(frozen=True)
class RoomMinute:
    """Eine Minute eines Raums. Fehlende Werte sind erlaubt und werden nicht geraten."""

    at: datetime
    room_id: int
    valve: float | None
    window: float | None


@dataclass(frozen=True)
class RoomVent:
    room_id: int
    #: Minuten mit offenem Fenster.
    open_minutes: int
    #: Davon Minuten, in denen zugleich Heizkreise dieses Raums offen standen.
    heating_minutes: int
    #: Geschätzte Wärme, die in diesen Minuten in den Raum ging.
    kwh: float


@dataclass(frozen=True)
class VentResult:
    kwh: float
    #: Anteil an der Entnahme des Zeitraums. None, wenn nichts entnommen wurde.
    share: float | None
    open_minutes: int
    rooms: tuple[RoomVent, ...]
    #: Minuten, für die Fenster- und Ventilwerte vorlagen. Ohne sie ist die Zahl eine Untergrenze.
    minutes_known: int
    note_de: str


def _de(x: float, stellen: int = 1) -> str:
    return f"{x:.{stellen}f}".replace(".", ",")


def ventilation_split(
    draw_kw: Mapping[datetime, float],
    rooms: Sequence[RoomMinute],
    circuits: Mapping[int, int],
    step_min: float = 1.0,
) -> VentResult:
    """Die Entnahme auf Räume verteilen und zusammenzählen, was bei offenem Fenster ankam.

    `draw_kw` ist die Entnahme je Minute aus der Wärmebilanz, `rooms` sind die Raumreihen derselben
    Minuten, `circuits` die Zahl der Heizkreise je Raum.
    """
    schritt_h = step_min / 60.0
    nach_zeit: dict[datetime, list[RoomMinute]] = {}
    for r in rooms:
        nach_zeit.setdefault(r.at, []).append(r)

    offen_min: dict[int, int] = {}
    heiz_min: dict[int, int] = {}
    kwh: dict[int, float] = {}
    bekannt = 0
    gesamt_kwh = 0.0

    for at, minute in nach_zeit.items():
        hat_fenster = any(r.window is not None for r in minute)
        hat_ventil = any(r.valve is not None for r in minute)
        if hat_fenster and hat_ventil:
            bekannt += 1
        gewichte = {
            r.room_id: max(0.0, (r.valve or 0.0)) * max(1, circuits.get(r.room_id, 1))
            for r in minute
        }
        summe = sum(gewichte.values())
        entnahme = max(0.0, draw_kw.get(at, 0.0))
        gesamt_kwh += entnahme * schritt_h
        for r in minute:
            if r.window is None or r.window < OFFEN:
                continue
            offen_min[r.room_id] = offen_min.get(r.room_id, 0) + 1
            if gewichte.get(r.room_id, 0.0) <= 0.0 or summe <= 0.0:
                continue
            heiz_min[r.room_id] = heiz_min.get(r.room_id, 0) + 1
            kwh[r.room_id] = (
                kwh.get(r.room_id, 0.0) + entnahme * (gewichte[r.room_id] / summe) * schritt_h
            )

    je_raum = tuple(
        RoomVent(
            room_id=rid,
            open_minutes=offen_min.get(rid, 0),
            heating_minutes=heiz_min.get(rid, 0),
            kwh=round(kwh.get(rid, 0.0), 3),
        )
        for rid in sorted(set(offen_min) | set(kwh))
    )
    summe_kwh = round(sum(r.kwh for r in je_raum), 3)
    anteil = round(summe_kwh / gesamt_kwh, 4) if gesamt_kwh > 1e-6 else None
    offen_gesamt = sum(r.open_minutes for r in je_raum)

    if not bekannt:
        note = "Keine Fenster- oder Ventilwerte in diesem Zeitraum."
    elif offen_gesamt == 0:
        note = "Kein Fenster stand offen, während geheizt wurde."
    else:
        # „0 Prozent" ist keine Auskunft, sondern eine gerundete Null. Unter einem Prozent sagt
        # der Satz das in Worten.
        prozent = (anteil or 0.0) * 100
        anteil_satz = (
            f", das sind {_de(prozent, 0)} Prozent der Entnahme"
            if prozent >= 1
            else ", das ist weniger als ein Prozent der Entnahme"
            if anteil
            else ""
        )
        note = (
            f"Geschätzt: {_de(summe_kwh)} kWh gingen in Räume mit offenem Fenster"
            + anteil_satz
            + ". Verteilt nach offenen Heizkreisen; Warmwasser lässt sich davon nicht trennen, "
            "die Zahl ist deshalb eher zu hoch. Ein Teil dieser Wärme ist im Raum geblieben - "
            "ein Lüftungsverlust ist sie nicht ganz."
        )
    return VentResult(
        kwh=summe_kwh,
        share=anteil,
        open_minutes=offen_gesamt,
        rooms=je_raum,
        minutes_known=bekannt,
        note_de=note,
    )
