"""Erfundene Räume für die Vorführung.

Die Raumseite soll im Demo-Modus nicht leer sein, und die Namen hier sind **absichtlich nicht die
eines echten Hauses**: Die Vorführung ist öffentlich. Dasselbe gilt für die Prüffälle.

Gerechnet wird deterministisch aus der Uhrzeit, ohne Zufall und ohne Zustand. Dieselbe Minute
ergibt immer dieselben Werte, also auch beim Blättern durch die Tageszeitreihe.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime

from hems_core.simulation import BERLIN


@dataclass(frozen=True, slots=True)
class DemoRoom:
    id: int
    name: str
    floor: str
    setpoint_c: float
    circuits: int
    # Wie weit dieser Raum dauerhaft neben dem Sollwert liegt. Das Bad hinkt nach, das
    # Gästezimmer überhitzt - genau die Spreizung, die die Seite sichtbar machen soll.
    bias_k: float


ROOMS: tuple[DemoRoom, ...] = (
    DemoRoom(1, "Arbeiten", "Erdgeschoss", 21.0, 2, -0.4),
    DemoRoom(2, "Kochen", "Erdgeschoss", 21.0, 3, 0.35),
    DemoRoom(3, "Wohnen", "Erdgeschoss", 21.5, 4, 0.05),
    DemoRoom(4, "Schlafen", "Obergeschoss", 19.0, 2, 0.2),
    DemoRoom(5, "Oben Nord", "Obergeschoss", 20.5, 2, -0.15),
    DemoRoom(6, "Oben Sued", "Obergeschoss", 20.5, 2, 0.3),
    DemoRoom(7, "Knapp", "Obergeschoss", 18.0, 1, 0.6),
    DemoRoom(8, "Kammer", "Obergeschoss", 20.0, 1, -0.1),
    DemoRoom(9, "Baden", "Obergeschoss", 23.0, 2, -1.1),
)


def _tageszeit(at: datetime) -> float:
    """Stunden seit Mitternacht in Ortszeit, mit Bruchteil."""
    lokal = at.astimezone(BERLIN)
    return lokal.hour + lokal.minute / 60.0


def temperature_c(room: DemoRoom, at: datetime) -> float:
    """Die Raumtemperatur: Sollwert, Dauerabweichung und ein Tagesgang.

    Der Tagesgang ist eine Schwingung mit Tiefpunkt am frühen Morgen, nicht eine Treppe: ein
    Fußboden mit 13 Stunden Zeitkonstante kann keine Kante.
    """
    h = _tageszeit(at)
    gang = -0.55 * math.cos((h - 14.0) / 24.0 * 2.0 * math.pi)
    fein = 0.12 * math.sin((h + room.id) / 6.0 * 2.0 * math.pi)
    return round(room.setpoint_c + room.bias_k + gang + fein, 1)


def offset_k(room: DemoRoom, at: datetime) -> float:
    """Die Anpassung, die Controme auf den Sollwert rechnet.

    In der echten Anlage ist `total_offset` die **Summe** mehrerer benannter Quellen - neben dem
    Wert steht ein Feld `offsets`, und darin stand unter anderem `Geolocation`. Hier wird eine
    davon nachgebildet: Je milder der Tag, desto weiter wird der Sollwert gesenkt. Das Vorzeichen
    ist damit meistens negativ, wie auf dem Bildschirmfoto der Anlage.

    Nicht für jeden Raum derselbe Wert: sonst wäre auf der Seite nicht zu sehen, dass der Offset
    je Raum verschieden sein kann.
    """
    h = _tageszeit(at)
    milde = max(0.0, math.cos((h - 14.0) / 24.0 * 2.0 * math.pi))
    return round(-0.5 * milde * (0.6 + 0.1 * (room.id % 5)), 2)


def valve(room: DemoRoom, at: datetime) -> float:
    """Anteil der offenen Heizkreise, 0 bis 1 - in Stufen von einem Kreis.

    Der Regler öffnet, wenn es unter dem Sollwert liegt, und je mehr Kreise, je feiner die
    Abstufung. Keine Zwischenstellung: jeder Kreis ist auf oder zu.
    """
    fehlt = room.setpoint_c + offset_k(room, at) - temperature_c(room, at)
    if fehlt <= 0.0:
        return 0.0
    # 0,15 K Unterschreitung je zusätzlich geöffneten Kreis, gedeckelt bei allen.
    offen = min(room.circuits, 1 + int(fehlt / 0.15))
    return round(offen / room.circuits, 3)
