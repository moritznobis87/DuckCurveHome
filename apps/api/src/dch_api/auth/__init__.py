"""Anmeldung mit Passkey, Sitzungen und Personenverwaltung (ADR-0002).

    token.py              opake Token: erzeugen, hashen, vergleichen
    wiederherstellung.py  zehn Codes als Rückweg
    drossel.py            die Bremse für den abgetippten Code
    rechte.py             welche Rolle was darf - die Matrix an einer Stelle
    ausweis.py            wer fragt; die Naht, hinter der später eine Zentrale stehen kann
    passkeys.py           die WebAuthn-Zeremonien
    dienst.py             Sitzungen, Einladungen, Personen - alles mit Datenbank

Der Rest des Programms kennt davon nur `Ausweis` und die Abhängigkeiten in `dependencies.py`.
"""

from __future__ import annotations

from dch_api.auth.ausweis import DIENST, Ausweis
from dch_api.auth.rechte import ROLLEN, Rolle, darf

__all__ = ["DIENST", "ROLLEN", "Ausweis", "Rolle", "darf"]
