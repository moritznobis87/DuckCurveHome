"""Die Bremse für die Anmeldung mit Wiederherstellungscode.

Gezählt wird im Vorgang, je E-Mail-Adresse. Das ist für ein Haus mit einer Handvoll Personen
genau richtig: eine Tabelle in der Datenbank wäre ein Schreibvorgang je Fehlversuch, und ein
Angreifer, der den Dienst neu startet, um die Zählung zu löschen, kann den Dienst auch einfach
anhalten.

Für die Anmeldung mit Passkey braucht es die Bremse nicht - dort entscheidet eine Signatur, und
die lässt sich nicht erraten. Nur der abgetippte Code braucht sie.
"""

from __future__ import annotations

from time import monotonic

__all__ = ["fehlversuch", "gesperrt", "vergessen"]

#: So viele Fehlversuche je Adresse, dann ist für `FENSTER_S` Schluss.
VERSUCHE = 10
FENSTER_S = 300.0
#: Obergrenze der Einträge, damit eine Flut von erfundenen Adressen den Speicher nicht füllt.
_MAX = 5_000

_VERSUCHE: dict[str, list[float]] = {}


def gesperrt(email: str) -> bool:
    grenze = monotonic() - FENSTER_S
    versuche = [t for t in _VERSUCHE.get(email, []) if t > grenze]
    if versuche:
        _VERSUCHE[email] = versuche
    else:
        _VERSUCHE.pop(email, None)
    return len(versuche) >= VERSUCHE


def fehlversuch(email: str) -> None:
    _VERSUCHE.setdefault(email, []).append(monotonic())
    if len(_VERSUCHE) > _MAX:
        _aufraeumen()


def vergessen(email: str) -> None:
    _VERSUCHE.pop(email, None)


def _aufraeumen() -> None:
    """Abgelaufene weg, und wenn es dann noch zu viele sind, die ältesten."""
    grenze = monotonic() - FENSTER_S
    for adresse in [a for a, t in _VERSUCHE.items() if not t or max(t) <= grenze]:
        _VERSUCHE.pop(adresse, None)
    if len(_VERSUCHE) <= _MAX:
        return
    nach_alter = sorted(_VERSUCHE.items(), key=lambda p: max(p[1] or [0.0]))
    for adresse, _ in nach_alter[: len(_VERSUCHE) - _MAX]:
        _VERSUCHE.pop(adresse, None)
