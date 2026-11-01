"""Wer etwas verändert hat: Gerät heute, Person später, und beides nebeneinander.

**Das Problem.** Im Protokoll steht, *dass* jemand den Sollwert gestellt hat, und seit dem
Raumprotokoll auch, *dass* es über dieses Werkzeug ging. Wer es war, stand nirgends. Die Sitzung
weiß es längst: Beim Paaren bekommt jedes Gerät einen Namen (`/pair?token=…&name=iPad-Flur`), und
der steht signiert im Cookie. Er kam nur nie am Dienst an.

**Warum vier Felder und nicht ein Name.** Es soll später ein Benutzersystem geben, und dann will
niemand die alten Zeilen umschreiben. Ein Urheber ist deshalb zusammengesetzt:

| Feld | heute | mit Benutzersystem |
| --- | --- | --- |
| `art` | `geraet` | `person` |
| `id` | `ipad-flur` | `u_17` |
| `name` | `iPad Flur` | `Moritz` |
| `geraet` | `iPad Flur` | `iPad Flur` |

Das Gerät bleibt also stehen, wenn die Person dazukommt: „Moritz, am iPad im Flur" ist die
vollständige Auskunft, und sie entsteht ohne Umbau. Alte Zeilen behalten `art: geraet` und
behaupten nie, eine Person zu kennen - **rückwirkend aus einem Gerät einen Menschen zu machen
wäre eine Erfindung**, auch wenn meistens derselbe davor saß.

**Der Name wird mitgeschrieben, nicht nachgeschlagen.** Wer das Gerät später umbenennt oder einen
Benutzer löscht, soll das Protokoll nicht verändern. Darum steht der Anzeigename in jeder Zeile,
nicht nur die Kennung.

**Wie weit die Angabe trägt.** Der Urheber kommt als Kopfzeile vom BFF, und dem glaubt der Dienst,
weil hinter derselben Tür das API-Token steht. Wer das Token hat, kann jeden Urheber behaupten -
er kann aber ohnehin alles. Es ist also eine *Zuordnung*, keine Beweisführung; für Letzteres
müsste der Browser selbst signieren. Für die Frage „wer hat die Heizung hochgedreht" reicht es,
und das steht hier, damit es niemand später für mehr hält.

Dieses Modul rechnet nur. Es liest nichts und kennt weder Datenbank noch HTTP.
"""

from __future__ import annotations

from collections.abc import Mapping
from contextvars import ContextVar, Token
from dataclasses import dataclass
from typing import Literal

#: Woher eine Änderung kommt. `geraet` ist eine gepaarte Anzeige, `person` ein angemeldeter
#: Mensch (gibt es noch nicht), `automatik` die Raum- oder Speicherautomatik, `system` alles
#: Übrige: Start, Wartung, Zeitpläne.
Art = Literal["geraet", "person", "automatik", "system"]

#: Unter diesem Präfix steht der Urheber im Kontext eines Ereignisses. Flache Punktschlüssel wie
#: bei `raum.1.name`: Sie bleiben Zeichenketten, lassen sich in der Datenbank durchsuchen und
#: überstehen auch den Weg über die Brücke, deren Kontext nur Zeichenketten kennt.
PRAEFIX = "urheber"

#: Länge, auf die eine Kennung beschnitten wird. `config_versions.created_by` ist 64 Zeichen breit.
MAX_ID = 64
MAX_NAME = 80


@dataclass(frozen=True, slots=True)
class Urheber:
    """Wer eine Änderung veranlasst hat."""

    art: Art
    id: str
    name: str
    #: Das Gerät, an dem es geschah. Heute dasselbe wie `name`, später daneben.
    geraet: str = ""
    #: Die Rolle der Sitzung, soweit bekannt (`owner` oder `guest`). Nur zur Einordnung.
    rolle: str = ""

    def text(self) -> str:
        """Eine Zeile für die Anzeige: „Moritz, am iPad Flur" oder einfach „iPad Flur"."""
        if self.geraet and self.geraet != self.name:
            return f"{self.name}, am {self.geraet}"
        return self.name

    def als_kontext(self) -> dict[str, str]:
        """Die Felder als flache Punktschlüssel, wie sie in einem Ereignis stehen."""
        out = {f"{PRAEFIX}.art": self.art, f"{PRAEFIX}.id": self.id, f"{PRAEFIX}.name": self.name}
        if self.geraet:
            out[f"{PRAEFIX}.geraet"] = self.geraet
        if self.rolle:
            out[f"{PRAEFIX}.rolle"] = self.rolle
        return out


#: Was die Automatik schreibt, wenn sie von sich aus stellt.
AUTOMATIK = Urheber(art="automatik", id="automatik", name="Automatik")
#: Alles, was ohne Anfrage geschieht: Start, Zeitpläne, Wartung.
SYSTEM = Urheber(art="system", id="system", name="System")


def _kurz(wert: object, grenze: int) -> str:
    return str(wert).strip()[:grenze] if wert is not None else ""


def kennung(name: str) -> str:
    """Aus einem Anzeigenamen eine Kennung machen: `iPad Flur` → `ipad-flur`.

    **Nur als Notnagel.** Sobald es Benutzer gibt, kommt die Kennung von dort. Bis dahin ist der
    Gerätename das Einzige, was es gibt, und zwei Geräte mit demselben Namen wären dasselbe Gerät -
    was beim Paaren auffällt und sich dort beheben lässt.
    """
    erlaubt = [c if c.isalnum() else "-" for c in name.strip().lower()]
    zusammen = "".join(erlaubt)
    while "--" in zusammen:
        zusammen = zusammen.replace("--", "-")
    return zusammen.strip("-")[:MAX_ID]


def aus_kopfzeilen(headers: Mapping[str, str]) -> Urheber | None:
    """Den Urheber aus den Kopfzeilen einer Anfrage lesen. `None`, wenn keiner mitkam.

    Erwartet werden `x-dch-urheber-name` und, sobald es Benutzer gibt, `x-dch-urheber-art` und
    `-id`. Fehlt die Art, ist es ein Gerät: Das ist der heutige Stand, und ein Dienst, der eine
    fehlende Angabe zur Person erklärt, hätte das Protokoll verdorben.
    """
    name = _kurz(headers.get("x-dch-urheber-name"), MAX_NAME)
    if not name:
        return None
    roh_art = _kurz(headers.get("x-dch-urheber-art"), 16)
    art: Art = roh_art if roh_art in ("geraet", "person", "automatik", "system") else "geraet"  # type: ignore[assignment]
    geraet = _kurz(headers.get("x-dch-urheber-geraet"), MAX_NAME) or (
        name if art == "geraet" else ""
    )
    return Urheber(
        art=art,
        id=_kurz(headers.get("x-dch-urheber-id"), MAX_ID) or kennung(name),
        name=name,
        geraet=geraet,
        rolle=_kurz(headers.get("x-dch-urheber-rolle"), 16),
    )


def aus_kontext(context: Mapping[str, object]) -> Urheber | None:
    """Den Urheber aus dem Kontext eines Ereignisses zurücklesen, falls einer darin steht."""
    name = _kurz(context.get(f"{PRAEFIX}.name"), MAX_NAME)
    if not name:
        return None
    roh_art = _kurz(context.get(f"{PRAEFIX}.art"), 16)
    art: Art = roh_art if roh_art in ("geraet", "person", "automatik", "system") else "geraet"  # type: ignore[assignment]
    return Urheber(
        art=art,
        id=_kurz(context.get(f"{PRAEFIX}.id"), MAX_ID),
        name=name,
        geraet=_kurz(context.get(f"{PRAEFIX}.geraet"), MAX_NAME),
        rolle=_kurz(context.get(f"{PRAEFIX}.rolle"), 16),
    )


# ------------------------------------------------------------------ der laufende Urheber

#: Wer gerade handelt. Eine Kontextvariable und kein Parameter, weil sonst jeder der einundzwanzig
#: Aufrufe von `add_event` und jede Schicht dazwischen ihn durchreichen müsste - und der eine, den
#: jemand vergisst, wäre genau die Zeile, die später fehlt. Asyncio gibt jeder Anfrage ihren
#: eigenen Kontext; zwei gleichzeitige Anfragen sehen einander nicht.
_aktuell: ContextVar[Urheber | None] = ContextVar("dch_urheber", default=None)


def aktueller() -> Urheber | None:
    """Wer gerade handelt, oder `None` außerhalb einer Anfrage (Takt, Start, Brücke)."""
    return _aktuell.get()


def setze(urheber: Urheber | None) -> Token[Urheber | None]:
    """Den Urheber für diesen Kontext setzen. Gibt den Merkzettel zum Zurücksetzen zurück."""
    return _aktuell.set(urheber)


def zuruecksetzen(merker: Token[Urheber | None]) -> None:
    """Den vorigen Stand wiederherstellen."""
    _aktuell.reset(merker)
