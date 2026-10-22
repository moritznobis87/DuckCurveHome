"""Einzelraumregelung: aus Messreihen und einem Ereignis wird eine Raumliste.

**Warum das nicht einfach Spalten sind.** Welche Räume es gibt, steht in Controme, nicht in einer
Einstellung dieses Werkzeugs. Ihre Zahl ändert sich, wenn jemand dort einen Raum anlegt, und ihre
Kennungen sind Contromes Kennungen. Darum heißen die Reihen `room_<id>_<feld>` und landen in der
JSON-Spalte `extra` der Minutentabelle - ohne Migration, ohne dass jemand vorher etwas eintragen
muss, und ohne dass neun Räume neun mal fünf Spalten kosten.

**Der Name ist keine Zahl.** Über die Telemetrie geht nur, was sich mitteln lässt. Namen, Etagen
und Kreiszahlen kommen deshalb als Zusammenhang des Ereignisses `rooms.list`; gelesen wird immer
der jüngste Eintrag, und ältere bleiben als Verlauf stehen.

Dieses Modul rechnet nur. Es liest nichts und kennt weder Datenbank noch HTTP.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timedelta

# Die Felder je Raum, in der Reihenfolge, in der sie in der Anzeige gebraucht werden.
FIELDS = ("temp_c", "setpoint_c", "offset_k", "humidity_pct", "valve")
# Felder, für die eine Zeitreihe aufgehoben wird. Der Offset gehört nicht dazu: er ist eine
# Einstellung, und wie oft jemand am Regler gedreht hat, steht im Sollwert mit drin.
SERIES_FIELDS = ("temp_c", "setpoint_c", "valve")

_KEY = re.compile(r"^room_(\d+)_(" + "|".join(FIELDS) + r")$")
_META = re.compile(r"^raum\.(\d+)\.(name|etage|kreise|rang)$")

# Verdichtungsstufen der Tageszeitreihe. Eine Raumtemperatur folgt dem Haus mit Zeitkonstanten um
# 25 Stunden; minütlich übertragen wären es neun Räume mal drei Reihen mal 1440 Zahlen für eine
# Kurve, die in diesem Takt gar nichts Neues sagt.
STEPS = (5, 15, 60)

# Ab wann ein Raumwert als alt gilt. Contromes Funkfühler melden alle 3 bis 5 Minuten, die Brücke
# fragt alle 2 Minuten; eine Viertelstunde Stille ist also kein Takt mehr, sondern ein Ausfall.
STALE_S = 900.0

# Der Ereigniscode, unter dem die Raumliste im Protokoll steht. **Mit Vorsatz**: Alles, was von der
# Brücke kommt, wird als `bridge.<code>` abgelegt, damit im Protokoll zu sehen ist, wer etwas
# gemeldet hat. Die Brücke selbst schickt `rooms.list`.
EVENT_CODE = "bridge.rooms.list"


def parse_key(key: str) -> tuple[int, str] | None:
    """`room_5_temp_c` → `(5, "temp_c")`. `None`, wenn es keine Raumreihe ist."""
    m = _KEY.match(key)
    return (int(m.group(1)), m.group(2)) if m else None


def ids_from_keys(keys: Iterable[str]) -> list[int]:
    """Welche Raumkennungen in diesen Reihennamen vorkommen, aufsteigend."""
    return sorted({t[0] for t in (parse_key(k) for k in keys) if t is not None})


def keys_for(ids: Iterable[int], fields: Sequence[str] = FIELDS) -> list[str]:
    return [f"room_{i}_{f}" for i in ids for f in fields]


@dataclass(frozen=True, slots=True)
class RoomMeta:
    """Was einen Raum beschreibt, ohne Messgröße zu sein."""

    id: int
    name: str
    floor: str = ""
    circuits: int = 0
    rank: int = 0


def _int(v: object) -> int | None:
    try:
        return int(str(v))
    except (TypeError, ValueError):
        return None


def meta_from_context(context: Mapping[str, object]) -> dict[int, RoomMeta]:
    """Die Raumliste aus dem Zusammenhang eines `rooms.list`-Ereignisses.

    **Das alte Format wird mitgelesen.** Die erste Fassung der Brücke schickte `{"5": "Büro"}`,
    ohne Etage und Kreiszahl. Wer sie noch laufen hat, soll die Namen trotzdem sehen; ein Raum
    ohne Etage landet später in der Gruppe „ohne Etage". Fällt weg, sobald niemand mehr eine
    Brücke von vor dem 22.10.2026 betreibt - und schadet bis dahin nichts.
    """
    namen: dict[int, str] = {}
    etagen: dict[int, str] = {}
    kreise: dict[int, int] = {}
    raenge: dict[int, int] = {}
    for key, value in context.items():
        m = _META.match(key)
        if m is not None:
            rid, feld = int(m.group(1)), m.group(2)
            if feld == "name":
                namen[rid] = str(value)
            elif feld == "etage":
                etagen[rid] = str(value)
            elif feld == "kreise":
                kreise[rid] = _int(value) or 0
            else:
                raenge[rid] = _int(value) or 0
            continue
        rid_alt = _int(key)
        if rid_alt is not None and isinstance(value, str):
            namen.setdefault(rid_alt, value)
    return {
        rid: RoomMeta(
            id=rid,
            name=name,
            floor=etagen.get(rid, ""),
            circuits=kreise.get(rid, 0),
            rank=raenge.get(rid, rid),
        )
        for rid, name in namen.items()
    }


def sort_key(m: RoomMeta) -> tuple[int, int, str]:
    """Reihenfolge der Räume: wie in Controme, nicht alphabetisch.

    Räume ohne Etagenangabe kommen zuletzt - sie stammen entweder aus einer alten Brücke oder aus
    einem Abruf, bei dem `temps` ausgefallen war, und gehören in keine Geschossgruppe.
    """
    return (0 if m.floor else 1, m.rank, m.name)


# ------------------------------------------------------------------ Tageszeitreihe


@dataclass(slots=True)
class Series:
    """Eine verdichtete Zeitreihe je Raum, spaltenweise - alle Listen gleich lang wie `ts`."""

    id: int
    values: dict[str, list[float | None]] = field(default_factory=dict)


def bucket_starts(start: datetime, end: datetime, step_min: int) -> list[datetime]:
    """Die Anfänge aller Zeitfenster von `start` bis `end`, letztes angeschnitten eingeschlossen."""
    if step_min <= 0 or end <= start:
        return []
    schritt = timedelta(minutes=step_min)
    out: list[datetime] = []
    t = start
    while t < end:
        out.append(t)
        t += schritt
    return out


def condense(
    rows: Sequence[Mapping[str, float | str | None]],
    ids: Sequence[int],
    start: datetime,
    end: datetime,
    step_min: int,
    fields: Sequence[str] = SERIES_FIELDS,
) -> tuple[list[datetime], list[Series]]:
    """Minutenzeilen zu Fenstermitteln je Raum und Feld verdichten.

    Ein Fenster ohne Messwert bleibt `None` und wird nicht überbrückt: eine Lücke in der Kurve ist
    die Aussage „hier war nichts", und eine durchgezogene Linie wäre eine Behauptung.

    Gemittelt wird auch die Ventilstellung, obwohl das einzelne Ventil nur Auf oder Zu kennt. Über
    eine Viertelstunde ist der Mittelwert dann die Einschaltdauer, und genau die interessiert.
    """
    ts = bucket_starts(start, end, step_min)
    summe: dict[tuple[int, str], list[float]] = {}
    anzahl: dict[tuple[int, str], list[int]] = {}
    for rid in ids:
        for f in fields:
            summe[(rid, f)] = [0.0] * len(ts)
            anzahl[(rid, f)] = [0] * len(ts)
    schritt_s = step_min * 60
    for row in rows:
        rohzeit = row.get("ts")
        if not isinstance(rohzeit, str):
            continue
        try:
            zeit = datetime.fromisoformat(rohzeit.replace("Z", "+00:00"))
        except ValueError:
            continue
        i = int((zeit - start).total_seconds() // schritt_s)
        if i < 0 or i >= len(ts):
            continue
        for key, value in row.items():
            if not isinstance(value, float) and not isinstance(value, int):
                continue
            t = parse_key(key)
            if t is None or t[1] not in fields:
                continue
            feld = summe.get(t)
            if feld is None:
                continue
            feld[i] += float(value)
            anzahl[t][i] += 1
    reihen = [
        Series(
            id=rid,
            values={
                f: [
                    round(summe[(rid, f)][i] / n, 3) if (n := anzahl[(rid, f)][i]) else None
                    for i in range(len(ts))
                ]
                for f in fields
            },
        )
        for rid in ids
    ]
    return ts, reihen
