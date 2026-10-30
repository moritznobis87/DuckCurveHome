"""Ein erfundenes Haus fuer die Vorfuehrung und die Pruefungen.

Die Modellansicht braucht einen Plan, und der Plan eines bewohnten Hauses gehoert nicht in ein
oeffentliches Repository. Dieses hier ist ausgedacht: ein schlichter Zweigeschosser mit Garten im
Norden, Hof und Strasse im Sueden, Technik im Suedosten. Die Raeume sind die der Vorfuehrung
(`demo_rooms`), damit Temperaturen und Sollwerte dort hineinfallen. Dieselbe Datei steht als
kommentierte YAML unter `config/haus.example.yaml`; eine Pruefung haelt beide gleich.

Die Kontakte oeffnen sich deterministisch aus der Uhrzeit, wie die Fenster der Vorfuehrungsraeume:
Dieselbe Minute ergibt immer dasselbe Bild.
"""

from __future__ import annotations

from datetime import datetime

from hems_core.house import HousePlan
from hems_core.simulation import BERLIN

PLAN = HousePlan.model_validate(
    {
        "version": 1,
        "name": "Beispielhaus",
        "note_de": "Vorfuehrung mit erfundenem Grundriss. Der Plan des eigenen Hauses kommt aus "
        "der Datei haus.yaml neben der Entity-Zuordnung.",
        "decks": [
            {
                "key": "eg",
                "name": "Erdgeschoss",
                "shell": [[0, 0], [12, 0], [12, 8], [0, 8]],
                "plate": [[0, -2.4], [14, -2.4], [14, 13.4], [0, 13.4]],
                "rooms": [
                    {"name": "Wohnen", "room_id": 3, "x0": 0, "z0": 0, "x1": 6.5, "z1": 5},
                    {"name": "Kochen", "room_id": 2, "x0": 6.5, "z0": 0, "x1": 12, "z1": 4.2},
                    {"name": "Arbeiten", "room_id": 1, "x0": 0, "z0": 5, "x1": 3.6, "z1": 8},
                    {
                        "name": "Treppe",
                        "x0": 3.6,
                        "z0": 5,
                        "x1": 6.5,
                        "z1": 8,
                        "silent": True,
                        "tiles": True,
                    },
                    {
                        "name": "Diele",
                        "x0": 6.5,
                        "z0": 4.2,
                        "x1": 9.4,
                        "z1": 8,
                        "minor": True,
                        "tiles": True,
                    },
                    {
                        "name": "WC",
                        "x0": 9.4,
                        "z0": 4.2,
                        "x1": 12,
                        "z1": 5.8,
                        "minor": True,
                        "tiles": True,
                    },
                    {
                        "name": "Technik",
                        "x0": 9.4,
                        "z0": 5.8,
                        "x1": 12,
                        "z1": 8,
                        "tech": True,
                        "silent": True,
                    },
                ],
                "gaps": [
                    {"x": 6.5, "a": 1.5, "b": 2.4},
                    {"x": 6.5, "a": 4.3, "b": 5.0},
                    {"z": 4.2, "a": 7.0, "b": 7.9},
                    {"x": 9.4, "a": 4.6, "b": 5.4},
                    {"x": 9.4, "a": 6.4, "b": 7.2},
                    {"z": 5.0, "a": 1.2, "b": 2.1},
                    {"x": 6.5, "a": 5.2, "b": 6.2},
                ],
                "openings": [
                    {"x": 12, "a": 1.0, "b": 2.2},
                    {"x": 12, "a": 4.6, "b": 5.2},
                    {"z": 8, "a": 4.2, "b": 5.6},
                ],
                "contacts": [
                    {
                        "name": "Wohnen, Fenster",
                        "key": "kontakt_wohnen_fenster",
                        "room": "Wohnen",
                        "side": "n",
                        "at": 0,
                        "a": 1.0,
                        "b": 2.6,
                    },
                    {
                        "name": "Terrassentür",
                        "key": "kontakt_terrassentuer",
                        "room": "Wohnen",
                        "side": "n",
                        "at": 0,
                        "a": 4.0,
                        "b": 5.3,
                        "door": True,
                    },
                    {
                        "name": "Kochen, Fenster",
                        "key": "kontakt_kochen_fenster",
                        "room": "Kochen",
                        "side": "n",
                        "at": 0,
                        "a": 8.5,
                        "b": 9.9,
                    },
                    {
                        "name": "Arbeiten, Fenster",
                        "key": "kontakt_arbeiten_fenster",
                        "room": "Arbeiten",
                        "side": "s",
                        "at": 8,
                        "a": 1.2,
                        "b": 2.6,
                    },
                    {
                        "name": "Haustür",
                        "key": "kontakt_haustuer",
                        "room": "Diele",
                        "side": "s",
                        "at": 8,
                        "a": 7.4,
                        "b": 8.4,
                        "door": True,
                    },
                ],
                "items": [
                    {
                        "kind": "box",
                        "tone": "soft",
                        "x": 3.2,
                        "z": 3.9,
                        "b": 2.6,
                        "t": 0.9,
                        "h": 0.42,
                    },
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 3.2,
                        "z": 2.6,
                        "b": 1.1,
                        "t": 0.6,
                        "h": 0.4,
                    },
                    {"kind": "cylinder", "tone": "soft", "x": 1.2, "z": 3.2, "r": 0.4, "h": 0.45},
                    {"kind": "stove", "device": "pellet", "x": 0.55, "z": 0.6, "r": 0.24},
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 5.6,
                        "z": 1.0,
                        "b": 1.4,
                        "t": 0.45,
                        "h": 1.0,
                    },
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 9.25,
                        "z": 0.4,
                        "b": 5.1,
                        "t": 0.6,
                        "h": 0.5,
                    },
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 9.2,
                        "z": 2.5,
                        "b": 2.0,
                        "t": 0.9,
                        "h": 0.5,
                    },
                    {"kind": "chair", "x": 8.5, "z": 3.5},
                    {"kind": "chair", "x": 9.4, "z": 3.5},
                    {
                        "kind": "box",
                        "tone": "light",
                        "x": 1.4,
                        "z": 6.0,
                        "b": 1.6,
                        "t": 0.8,
                        "h": 0.45,
                    },
                    {"kind": "chair", "x": 1.4, "z": 6.7},
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 3.3,
                        "z": 7.0,
                        "b": 0.5,
                        "t": 1.8,
                        "h": 1.0,
                    },
                    {
                        "kind": "flight",
                        "x0": 5.0,
                        "z0": 7.7,
                        "x1": 5.0,
                        "z1": 5.3,
                        "b": 1.0,
                        "steps": 12,
                        "y": 0,
                        "y1": 1.0,
                    },
                    {
                        "kind": "box",
                        "tone": "light",
                        "x": 11.6,
                        "z": 5.0,
                        "b": 0.5,
                        "t": 0.4,
                        "h": 0.42,
                    },
                    {"kind": "buffer", "x": 10.2, "z": 7.1, "label": "Puffer"},
                    {"kind": "indoor_unit", "x": 11.78, "z": 6.3, "dir": "w"},
                    {
                        "kind": "pipe",
                        "points": [[12.8, 0.5, 6.9], [12.0, 0.6, 6.7], [11.6, 0.7, 6.4]],
                    },
                    {"kind": "pipe", "points": [[11.6, 0.7, 6.6], [10.9, 0.8, 7.0]]},
                    {"kind": "heat_pump", "x": 13.0, "z": 6.9, "dir": "o", "label": "Waermepumpe"},
                    {"kind": "ground", "tone": "terrace", "x": 3.25, "z": -1.1, "b": 6.5, "t": 2.2},
                    {"kind": "ground", "tone": "paving", "x": 6.0, "z": 10.7, "b": 12.0, "t": 5.0},
                    {"kind": "wall", "x": 12.1, "z": 10.7, "b": 0.2, "t": 5.0, "h": 0.9},
                    {"kind": "car", "x": 3.4, "z": 10.9, "angle": 0.25},
                    {
                        "kind": "wallbox",
                        "x": 8.9,
                        "z": 8.15,
                        "x1": 5.2,
                        "z1": 10.3,
                        "label": "Wallbox",
                    },
                    {"kind": "tree", "x": 9.2, "z": 11.6, "r": 1.3, "b": 2.0, "h": 2.2},
                ],
                "places": [
                    {"text": "Garten", "x": 6.0, "z": -3.1},
                    {"text": "Hof", "x": 6.0, "z": 12.4},
                ],
            },
            {
                "key": "og",
                "name": "Obergeschoss",
                "shell": [[0, 0], [12, 0], [12, 8], [0, 8]],
                "plate": [[0, -1.0], [12, -1.0], [12, 9.0], [0, 9.0]],
                "holes": [[3.6, 5.6, 6.5, 8.0]],
                "rooms": [
                    {"name": "Schlafen", "room_id": 4, "x0": 0, "z0": 0, "x1": 4.6, "z1": 4.2},
                    {"name": "Oben Nord", "room_id": 5, "x0": 4.6, "z0": 0, "x1": 8.6, "z1": 4.2},
                    {"name": "Knapp", "room_id": 7, "x0": 8.6, "z0": 0, "x1": 12, "z1": 4.2},
                    {
                        "name": "Flur",
                        "x0": 3.6,
                        "z0": 4.2,
                        "x1": 9.6,
                        "z1": 5.6,
                        "minor": True,
                        "tiles": True,
                    },
                    {"name": "Oben Sued", "room_id": 6, "x0": 0, "z0": 4.2, "x1": 3.6, "z1": 8},
                    {
                        "name": "Treppe",
                        "x0": 3.6,
                        "z0": 5.6,
                        "x1": 6.5,
                        "z1": 8,
                        "silent": True,
                        "open": True,
                        "no_walls": "n",
                        "railing": "n",
                    },
                    {"name": "Kammer", "room_id": 8, "x0": 6.5, "z0": 5.6, "x1": 9.6, "z1": 8},
                    {
                        "name": "Baden",
                        "room_id": 9,
                        "x0": 9.6,
                        "z0": 4.2,
                        "x1": 12,
                        "z1": 8,
                        "tiles": True,
                    },
                ],
                "gaps": [
                    {"z": 4.2, "a": 3.8, "b": 4.5},
                    {"z": 4.2, "a": 5.5, "b": 6.4},
                    {"z": 4.2, "a": 8.8, "b": 9.5},
                    {"x": 9.6, "a": 4.5, "b": 5.3},
                    {"z": 5.6, "a": 7.0, "b": 7.8},
                    {"x": 3.6, "a": 4.5, "b": 5.3},
                    {"z": 5.6, "a": 3.6, "b": 6.5},
                ],
                "openings": [
                    {"z": 0, "a": 1.4, "b": 3.0},
                    {"z": 0, "a": 5.8, "b": 7.2},
                    {"z": 0, "a": 9.6, "b": 10.8},
                    {"z": 8, "a": 1.2, "b": 2.6},
                    {"z": 8, "a": 7.2, "b": 8.2},
                    {"z": 8, "a": 10.0, "b": 11.2},
                ],
                "items": [
                    {"kind": "bed", "x": 2.3, "z": 1.3, "b": 1.8, "t": 2.1, "head": "n"},
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 0.4,
                        "z": 2.4,
                        "b": 0.6,
                        "t": 2.6,
                        "h": 1.0,
                    },
                    {"kind": "bed", "x": 7.6, "z": 1.3, "b": 1.0, "t": 2.0, "head": "n"},
                    {
                        "kind": "box",
                        "tone": "light",
                        "x": 5.4,
                        "z": 1.2,
                        "b": 1.2,
                        "t": 0.6,
                        "h": 0.45,
                    },
                    {"kind": "chair", "x": 5.4, "z": 1.9},
                    {"kind": "bed", "x": 10.3, "z": 1.3, "b": 1.4, "t": 2.0, "head": "n"},
                    {"kind": "bed", "x": 1.8, "z": 6.6, "b": 1.4, "t": 2.0, "head": "s"},
                    {
                        "kind": "box",
                        "tone": "dark",
                        "x": 8.0,
                        "z": 6.0,
                        "b": 1.6,
                        "t": 0.6,
                        "h": 1.0,
                    },
                    {
                        "kind": "box",
                        "tone": "water",
                        "x": 10.5,
                        "z": 7.1,
                        "b": 1.6,
                        "t": 0.8,
                        "h": 0.3,
                    },
                    {
                        "kind": "box",
                        "tone": "light",
                        "x": 11.5,
                        "z": 5.0,
                        "b": 0.8,
                        "t": 0.5,
                        "h": 0.5,
                    },
                    {"kind": "pit", "x": 5.05, "z": 6.8, "b": 2.8, "t": 2.3, "y": -0.6},
                    {
                        "kind": "flight",
                        "x0": 5.0,
                        "z0": 7.7,
                        "x1": 5.0,
                        "z1": 5.9,
                        "b": 1.0,
                        "steps": 8,
                        "y": -0.6,
                        "y1": 0.0,
                    },
                ],
                "places": [{"text": "Garten", "x": 6.0, "z": -0.6}],
            },
        ],
    }
)


def _minuten(at: datetime) -> int:
    lokal = at.astimezone(BERLIN)
    return lokal.hour * 60 + lokal.minute


def contact_open(key: str, at: datetime) -> bool | None:
    """Ob ein Kontakt der Vorfuehrung gerade offen ist.

    Morgens wird in der Kueche gelueftet, mittags und abends steht die Terrassentür eine Weile
    auf. Die Haustür ist ein Kontakt ohne Meldung: auch das soll die Anzeige aushalten.
    """
    m = _minuten(at)
    if key == "kontakt_kochen_fenster":
        return 7 * 60 <= m < 7 * 60 + 30
    if key == "kontakt_terrassentuer":
        return 12 * 60 <= m < 12 * 60 + 20 or 18 * 60 <= m < 18 * 60 + 25
    if key == "kontakt_haustuer":
        return None
    return False
