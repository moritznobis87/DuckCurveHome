"""Der Hausplan: was die Modellansicht zeichnet, beschrieben als Daten.

**Warum der Plan Daten ist und kein Code.** Das Repository ist oeffentlich, der Grundriss eines
bewohnten Hauses gehoert nicht hinein. Die Anzeige kennt deshalb nur die Sprache, in der ein Haus
beschrieben wird: Decks, Raeume, Waende mit Tuerluecken, Fenster, Kontakte, Moebel. Der Plan des
eigenen Hauses liegt als `haus.yaml` neben der Entity-Zuordnung auf dem Home-Assistant-Rechner; die
Bruecke liest ihn und reicht ihn als Ereignis durch, genau wie die Raumliste der Einzelraumregelung.
Im Repository steht ein erfundenes Beispielhaus, dasselbe, das die Vorfuehrung zeigt.

**Koordinaten.** Meter. `x` waechst nach rechts, `z` nach unten, also auf dem Bildschirm nach
unten, wenn oben Norden ist; `y` waechst nach oben. Ein Raum ist ein achsparalleles Rechteck
`x0 < x1`, `z0 < z1`. Winkelige Raeume setzt man aus mehreren Rechtecken zusammen, von denen alle
bis auf eines `part_of` den Namen des ersten nennen: sie teilen Temperatur und Beschriftung.

**Was das Modell nicht prueft.** Ob Waende aufeinanderstossen, ob Moebel in Raeumen stehen, ob der
Plan dem Haus aehnelt. Es prueft, dass jede Zahl eine Zahl ist, jedes Rechteck ein Rechteck, jeder
Verweis ein Ziel hat, und dass die Datei nicht groesser ist, als ein Ereignis sinnvoll aufnimmt.

Dieses Modul rechnet nicht. Es beschreibt und prueft.
"""

from __future__ import annotations

import math
import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Side = Literal["n", "s", "o", "w"]
SIDES: tuple[Side, ...] = ("n", "s", "o", "w")

# Ein Schluessel wie in der Entity-Zuordnung: klein, Buchstaben, Ziffern, Unterstrich.
_KEY = re.compile(r"^[a-z][a-z0-9_]*$")
# Groesser soll ein Plan nicht sein: er geht als ein Ereignis durch die Bruecke, liegt als ein
# Eintrag im Ereignisprotokoll und wird bei jedem Aufruf der Seite uebertragen.
MAX_ITEMS = 600
MAX_ROOMS = 80

Punkt = tuple[float, float]
Loch = tuple[float, float, float, float]

ItemKind = Literal[
    "box",  # Quader: Schraenke, Tische, Technik
    "cylinder",  # Zylinder: Hocker, Pflanzkuebel
    "bed",  # Bett mit Decke und Kopfteil (head: Seite des Kopfteils)
    "chair",  # Stuhl, als niedriger Zylinder
    "stove",  # Ofen mit Rohr; device: pellet bindet die Glut an den Pelletofen
    "ladder",  # Leitertreppe von (x0, z0) nach (x1, z1), breite b
    "loft",  # Empore: halbdurchsichtige Platte in Hoehe y
    "panel",  # Wandpaneel, Akzentwand: duenn und wandhoch
    "tiles",  # Fliesenmuster auf einer Flaeche ausserhalb eines gefliesten Raums
    "ground",  # Bodenflaeche draussen (tone: paving, terrace)
    "wall",  # Mauer draussen, in Aussenwandfarbe
    "gate",  # Tor: Rahmen mit Staeben, von x0 bis x1 bei z (oder z0 bis z1 bei x)
    "plant",  # Pflanze: Zylinder in Gruen
    "car",  # Auto, schemenhaft, an (x, z) mit Drehwinkel angle (rad)
    "wallbox",  # Wallbox mit Ladekabel nach (x1, z1), Chip mit der Ladeleistung
    "heat_pump",  # Aussengeraet der Waermepumpe, Luefter zur Seite dir, Chip mit der Leistung
    "buffer",  # Pufferspeicher: vier Schichten in Fuehlerfarben, Chip mit dem Ladestand
    "indoor_unit",  # Inneneinheit der Waermepumpe an der Wand
    "pipe",  # Leitung entlang points [[x, y, z], ...]
    "flight",  # Treppenlauf von (x0, z0) nach (x1, z1), breite b, steps Stufen, von y bis y1
    "landing",  # Podest: Quader in Hoehe y mit Dicke h
    "pit",  # dunkle Flaeche in Hoehe y (Treppenauge, Luftraum von unten)
]

Tone = Literal["dark", "light", "soft", "water", "wall", "paving", "terrace", "slate"]


class WallLine(BaseModel):
    """Ein Stueck Wandlinie: `x` fuer eine Nord-Sued-Wand, `z` fuer eine Ost-West-Wand, `a..b`
    laengs der Wand. Genau eines von `x` und `z` ist gesetzt."""

    model_config = ConfigDict(extra="forbid")

    x: float | None = None
    z: float | None = None
    a: float
    b: float

    @model_validator(mode="after")
    def _eine_achse(self) -> WallLine:
        if (self.x is None) == (self.z is None):
            raise ValueError("genau eines von x und z angeben")
        if not self.b > self.a:
            raise ValueError("b muss groesser als a sein")
        return self


class Opening(WallLine):
    """Fenster oder Tuer ohne Kontakt: steht still in der Wand."""

    door: bool = False


class Contact(BaseModel):
    """Ein Fenster oder eine Tuer mit Kontakt der Alarmanlage.

    `key` ist der Schluessel, unter dem die Bruecke den Kontakt meldet (Entity-Zuordnung, `kind:
    binary`, 1 heisst offen). `side` sagt, in welcher Aussenwand des Raums er sitzt, `at` ist die
    Koordinate dieser Wand (z fuer n/s, x fuer o/w), `a..b` die Lage laengs der Wand.
    """

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=60)
    key: str = Field(pattern=_KEY.pattern, max_length=64)
    room: str | None = None
    side: Side
    at: float
    a: float
    b: float
    door: bool = False

    @model_validator(mode="after")
    def _laenge(self) -> Contact:
        if not self.b > self.a:
            raise ValueError("b muss groesser als a sein")
        return self


class Room(BaseModel):
    """Ein Raum als Rechteck. `room_id` ist die Kennung der Einzelraumregelung; ohne sie zeigt die
    Anzeige den Namen, aber keine Temperatur."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=40)
    room_id: int | None = Field(default=None, ge=0)
    x0: float
    z0: float
    x1: float
    z1: float
    part_of: str | None = None
    minor: bool = False  # Nebenraum: kleiner Chip, erst beim Heranzoomen
    silent: bool = False  # gar kein Chip
    open: bool = False  # kein Boden: Luftraum, Treppenauge
    cold: bool = False  # unbeheizter Anbau
    tech: bool = False  # Technikraum
    tiles: bool = False  # Fliesenmuster
    no_walls: str = ""  # Seiten ohne Wand, etwa "nw"
    railing: str = ""  # Seiten mit Gelaender

    @field_validator("no_walls", "railing")
    @classmethod
    def _seiten(cls, v: str) -> str:
        """Eine Reihe von Seitenbuchstaben, jede hoechstens einmal, etwa "nw" oder "nwso"."""
        if any(c not in SIDES for c in v) or len(set(v)) != len(v):
            raise ValueError("nur die Buchstaben n, s, o, w, jeder hoechstens einmal")
        return v

    @model_validator(mode="after")
    def _rechteck(self) -> Room:
        if not (self.x1 > self.x0 and self.z1 > self.z0):
            raise ValueError(f"Raum {self.name!r}: x1 > x0 und z1 > z0 noetig")
        return self


class Item(BaseModel):
    """Ein Moebel, ein Geraet, ein Stueck Treppe. Welche Felder gelten, sagt `kind`; die Anzeige
    nimmt fuer fehlende Masse ihre Voreinstellungen. Geprueft wird hier nur, dass die Zahlen endlich
    sind und die Art bekannt ist."""

    model_config = ConfigDict(extra="forbid")

    kind: ItemKind
    tone: Tone | None = None
    x: float | None = None
    z: float | None = None
    y: float | None = None  # Unterkante, Voreinstellung Boden
    b: float | None = None  # Breite in x
    t: float | None = None  # Tiefe in z
    h: float | None = None  # Hoehe
    r: float | None = None  # Radius
    x0: float | None = None
    z0: float | None = None
    x1: float | None = None
    z1: float | None = None
    y1: float | None = None
    steps: int | None = Field(default=None, ge=1, le=40)
    head: Side | None = None  # Bett: Seite des Kopfteils
    dir: Side | None = None  # Geraete: wohin sie schauen
    angle: float | None = None  # Auto: Drehung in rad
    device: Literal["pellet", "wood"] | None = None  # Ofen
    label: str | None = Field(default=None, max_length=40)
    points: list[tuple[float, float, float]] | None = None

    @field_validator("x", "z", "y", "b", "t", "h", "r", "x0", "z0", "x1", "z1", "y1", "angle")
    @classmethod
    def _endlich(cls, v: float | None) -> float | None:
        if v is not None and not math.isfinite(v):
            raise ValueError("Zahl muss endlich sein")
        return v

    @field_validator("b", "t", "h", "r")
    @classmethod
    def _positiv(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("Mass muss groesser als 0 sein")
        return v


class Place(BaseModel):
    """Eine Ortsmarke draussen: Garten, Innenhof, Strasse."""

    model_config = ConfigDict(extra="forbid")

    text: str = Field(min_length=1, max_length=30)
    x: float
    z: float


class Deck(BaseModel):
    """Ein Geschoss. `shell` ist die Aussenhaut (Vieleck, gegen den Uhrzeigersinn in x/z); an ihr
    werden Aussenwaende hoeher und heller gezeichnet und steht der Schutzschild der Alarmanlage.
    `plate` ist die Grundplatte darunter, `holes` sind Loecher darin (Luftraeume)."""

    model_config = ConfigDict(extra="forbid")

    key: str = Field(pattern=r"^[a-z][a-z0-9_]{0,15}$")
    name: str = Field(min_length=1, max_length=40)
    shell: list[Punkt] = Field(min_length=3, max_length=60)
    plate: list[Punkt] | None = Field(default=None, min_length=3, max_length=60)
    alarm_shell: list[Punkt] | None = Field(default=None, min_length=3, max_length=60)
    holes: list[Loch] = Field(default_factory=list, max_length=20)
    rooms: list[Room] = Field(min_length=1, max_length=MAX_ROOMS)
    walls: list[WallLine] = Field(default_factory=list, max_length=100)
    gaps: list[WallLine] = Field(default_factory=list, max_length=100)
    openings: list[Opening] = Field(default_factory=list, max_length=100)
    contacts: list[Contact] = Field(default_factory=list, max_length=60)
    items: list[Item] = Field(default_factory=list, max_length=MAX_ITEMS)
    places: list[Place] = Field(default_factory=list, max_length=12)

    @model_validator(mode="after")
    def _verweise(self) -> Deck:
        namen = [r.name for r in self.rooms if r.part_of is None]
        doppelt = {n for n in namen if namen.count(n) > 1}
        if doppelt:
            raise ValueError(f"Deck {self.key!r}: Raumname mehrfach: {sorted(doppelt)}")
        for r in self.rooms:
            if r.part_of is not None and r.part_of not in namen:
                raise ValueError(
                    f"Deck {self.key!r}: {r.name!r} gehoert zu unbekanntem {r.part_of!r}"
                )
        for k in self.contacts:
            if k.room is not None and k.room not in namen:
                raise ValueError(f"Deck {self.key!r}: Kontakt {k.name!r} nennt unbekannten Raum")
        schluessel = [k.key for k in self.contacts]
        if len(set(schluessel)) != len(schluessel):
            raise ValueError(f"Deck {self.key!r}: Kontaktschluessel mehrfach")
        for loch in self.holes:
            if not (loch[2] > loch[0] and loch[3] > loch[1]):
                raise ValueError(f"Deck {self.key!r}: Loch braucht x1 > x0 und z1 > z0")
        return self

    def room(self, name: str) -> Room | None:
        return next((r for r in self.rooms if r.name == name and r.part_of is None), None)


class HousePlan(BaseModel):
    """Das ganze Haus: ein bis drei Decks. `note_de` steht unter der Anzeige, etwa fuer das, was
    im Plan angenommen und nicht gemessen ist."""

    model_config = ConfigDict(extra="forbid")

    version: Literal[1] = 1
    name: str = Field(default="", max_length=60)
    decks: list[Deck] = Field(min_length=1, max_length=3)
    note_de: str = Field(default="", max_length=400)

    @model_validator(mode="after")
    def _decks(self) -> HousePlan:
        keys = [d.key for d in self.decks]
        if len(set(keys)) != len(keys):
            raise ValueError("Deckschluessel mehrfach")
        return self

    @property
    def contacts(self) -> list[Contact]:
        return [k for d in self.decks for k in d.contacts]

    @property
    def room_ids(self) -> list[int]:
        return sorted({r.room_id for d in self.decks for r in d.rooms if r.room_id is not None})
