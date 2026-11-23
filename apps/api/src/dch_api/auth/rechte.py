"""Welche Rolle was darf - die Matrix an einer Stelle.

**Warum hier und nicht im BFF.** Bis zur Anmeldung mit Personen stand die Beschränkung des Gasts
im Proxy des Dashboards (`apps/web/src/app/api/dch/[...path]/route.ts`). Das reichte, solange nur
ein Browser mit dem Dienst sprach. Die iOS-App spricht direkt mit ihm, und dort wäre eine
Beschränkung nur eine ausgeblendete Schaltfläche. Geprüft wird deshalb hier: am Dienst, vor dem
Endpunkt, für jeden Weg herein (ADR-0002).

**Vier Rollen.**

| Rolle      | darf lesen            | darf stellen                        |
|------------|-----------------------|-------------------------------------|
| `hausherr` | alles                 | alles                               |
| `bewohner` | alles außer den Akten | im Haus (Räume, Kontakte, Alfred)   |
| `service`  | alles außer den Akten | am Gerät (Update, Neustart, Dienste)|
| `gast`     | alles außer den Akten | nichts                              |

**Die Akten** sind das, was in die Steuerakte und in die Privatsphäre gehört: die Tibber-Rechnungen
(Name, Adresse, Marktlokation, Zählernummer, IBAN), die PV-Abrechnung mit ihren
Bemessungsgrundlagen, der Datenexport, der den gesamten Bestand ausliefert, das Protokoll der
Haustür (wer wann kam) und die Personenverwaltung selbst. Sie bleiben dem Hausherrn.

Die Haustür **öffnet** über diesen Dienst niemand: das macht der Leser im Haus über die Bridge
(`docs/TUEROEFFNUNG.md`). Hier liegt nur ihr Protokoll, und das ist eine Akte.

**Unbekannte Pfade.** Ein neuer Endpunkt, der nichts von dieser Datei weiß, ist lesbar für alle
Angemeldeten und stellbar nur für den Hausherrn. Das ist die Richtung, in der ein Versehen
harmlos bleibt: ein neuer Bericht wird versehentlich sichtbar, ein neuer Schalter nicht
versehentlich bedienbar.
"""

from __future__ import annotations

from typing import Literal, get_args

__all__ = ["AKTEN", "ROLLEN", "Rolle", "darf", "ist_akte"]

Rolle = Literal["hausherr", "bewohner", "gast", "service"]

#: Dieselbe Liste wie die Prüfbedingung `ck_personen_rolle` in der Wanderung.
ROLLEN: tuple[str, ...] = get_args(Rolle)

#: Pfade (ohne `/api/v1`), die dem Hausherrn bleiben. Verglichen wird mit „beginnt mit".
AKTEN: tuple[str, ...] = (
    "/import/tibber-invoice",
    "/energy/pv",
    "/export/",
    "/system/door",
    "/auth/personen",
    "/alfred/rechnung",
    "/alfred/zuordnung",
)

#: Was ein Bewohner stellen darf: das Haus im Alltag.
_HAUS: tuple[str, ...] = (
    "/control/",
    "/rooms/",
    "/push/",
    "/alfred/ask",
)

#: Was der Beratungszugang stellen darf: das Gerät, nicht das Haus.
_GERAET: tuple[str, ...] = (
    "/system/update",
    "/system/geraet/",
)

_LESEND = frozenset({"GET", "HEAD", "OPTIONS"})


def _beginnt(pfad: str, praefixe: tuple[str, ...]) -> bool:
    return any(pfad.startswith(p) for p in praefixe)


def ist_akte(pfad: str) -> bool:
    """Gehört dieser Pfad in die Steuerakte oder in die Privatsphäre des Hausherrn?"""
    return _beginnt(pfad, AKTEN)


def darf(rolle: str, methode: str, pfad: str) -> bool:
    """Darf diese Rolle diese Anfrage stellen? `pfad` ohne `/api/v1`, mit führendem Schrägstrich.

    Die eigenen Sachen einer Person - ihre Passkeys, ihre Sitzungen, das Abmelden - liegen unter
    `/auth/` und werden hier durchgelassen; sie prüfen am Endpunkt selbst, dass es die eigenen
    sind. Nur `/auth/personen` ist eine Akte und steht oben.
    """
    if rolle == "hausherr":
        return True
    if ist_akte(pfad):
        return False
    if methode.upper() in _LESEND:
        return True
    if pfad.startswith("/auth/"):
        return True  # eigene Passkeys, eigene Sitzungen, abmelden
    if rolle == "bewohner":
        return _beginnt(pfad, _HAUS)
    if rolle == "service":
        return _beginnt(pfad, _GERAET)
    return False  # gast
