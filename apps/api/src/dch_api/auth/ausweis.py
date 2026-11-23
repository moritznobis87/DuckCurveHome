"""Wer fragt - der Ausweis einer Anfrage.

`Ausweis` entsteht EINMAL beim Auflösen des Tokens und wird danach weitergereicht; kein Endpunkt
und keine Ablage schlägt selbst nach, wer gerade fragt. Das ist die Naht aus ADR-0002: heute löst
`dienst.sitzung_aufloesen` ihn gegen die eigene Datenbank auf, später könnte es ein signiertes
Dokument einer Zentrale sein. Alles andere im Programm kennt nur diesen Typ.

**Unveränderlich:** ein Ausweis, den man unterwegs umschreiben kann, ist keiner. Wer die Rolle
wechselt, meldet sich neu an.

**Er ist die Quelle des `Urheber`** (`dch_api/urheber.py`). Damit wird aus dem heutigen
`art: geraet` ein `art: person`, ohne dass eine der einundzwanzig Stellen, die Ereignisse
schreiben, angefasst werden muss - und ohne dass alte Zeilen rückwirkend eine Person behaupten.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from dch_api import urheber
from dch_api.auth.rechte import Rolle

__all__ = ["DIENST", "Art", "Ausweis"]

#: `person` ist ein angemeldeter Mensch, `geraet` eine gepaarte Anzeige, `gast` ein Gastlink und
#: `dienst` etwas ohne Menschen davor: die Bridge, ein Automatismus, die iOS-App mit dem
#: API-Token.
Art = Literal["person", "geraet", "gast", "dienst"]


@dataclass(frozen=True, slots=True)
class Ausweis:
    """Wer diese Anfrage stellt und was er darf."""

    art: Art
    rolle: Rolle
    #: Die Kennung der Person als Text (UUID) - leer bei `dienst` und `geraet`.
    person_id: str = ""
    #: Der Anzeigename, der ins Protokoll geht.
    name: str = ""
    email: str = ""
    #: Das Gerät, an dem es geschieht, soweit die Anfrage es nennt.
    geraet: str = ""
    #: Die Sitzung, über die dieser Ausweis entstand - damit „diese Sitzung beenden" gehen kann.
    sitzung_id: str = ""

    @property
    def ist_person(self) -> bool:
        return self.art == "person"

    def als_urheber(self, ueber: str = "") -> urheber.Urheber:
        """Der Urheber für alles, was diese Anfrage schreibt.

        Bei einer Person stehen Kennung und Name aus der Datenbank darin, und das Gerät bleibt
        daneben: „Moritz, am iPad Flur" ist die vollständige Auskunft. Bei einem Gerät ist es
        unverändert das, was bisher in jeder Zeile stand.
        """
        if self.art == "person":
            return urheber.Urheber(
                art="person",
                id=self.person_id[: urheber.MAX_ID],
                name=self.name[: urheber.MAX_NAME] or self.email[: urheber.MAX_NAME],
                geraet=self.geraet[: urheber.MAX_NAME],
                rolle=self.rolle,
                ueber=ueber,
            )
        return urheber.Urheber(
            art="geraet",
            id=urheber.kennung(self.name or self.geraet or "dienst"),
            name=self.name or self.geraet or "Dienst",
            geraet=self.geraet or self.name,
            rolle=self.rolle,
            ueber=ueber,
        )


#: Der Ausweis für alles, was mit dem API-Token kommt und keinen Menschen nennt: die Bridge, ein
#: Zeitplan, ein Skript. Er darf alles - wer das Token hat, könnte ohnehin alles -, und genau
#: deshalb steht er hier mit Namen und nicht als Sonderfall in einer Abfrage.
DIENST = Ausweis(art="dienst", rolle="hausherr", name="Dienst")
