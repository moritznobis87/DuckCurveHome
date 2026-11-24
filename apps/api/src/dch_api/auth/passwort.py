"""Das Passwort einer Person: Regeln, Hash und Prüfung.

Der Hausherr hat am 24.11.2026 entschieden, dass es neben dem Passkey ein Passwort geben muss,
für Leute, die keinen Passkey verwenden möchten (ADR-0002, Nachtrag vom 24.11.2026). Der Passkey
bleibt der empfohlene Weg; das Passwort ist der zweite.

**Abgelegt wird nur ein Argon2id-Hash.** Die Parameter sind die zweite Empfehlung aus RFC 9106
(64 MiB, drei Durchgänge, vier Fäden) und stehen im Hash selbst. Wer sie später anhebt, muss
nichts umrechnen: `veraltet` meldet einen Hash mit alten Parametern, und die nächste gelungene
Anmeldung schreibt ihn neu.

**Die Regeln sind kurz.** Mindestens zwölf Zeichen, keine Vorschrift über Ziffern oder
Sonderzeichen. Solche Vorschriften machen Passwörter nicht stärker, sondern vorhersehbar; die
Länge ist, was zählt. Die Obergrenze gibt es, damit niemand den Dienst ein Megabyte verhaschen
lässt.

**Vor dem Verhaschen wird normalisiert (NFKC).** Ein „ü" kommt vom iPhone anders zusammengesetzt
als von einer Tastatur am Rechner. Ohne Normalisierung passte dasselbe Passwort an einem Gerät
und am anderen nicht.

**Höchstens zwei Hashes zugleich.** Jeder braucht 64 MiB. Ohne Grenze füllte eine Flut von
Anmeldeversuchen mit erfundenen Adressen den Speicher des Hausgeräts. Wer nach drei Sekunden
keinen Platz bekommt, wird abgelehnt, statt weiter einen Faden festzuhalten.
"""

from __future__ import annotations

import asyncio
import threading
import unicodedata
from functools import lru_cache

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

__all__ = [
    "HOECHSTLAENGE",
    "MINDESTLAENGE",
    "PasswortError",
    "pruefen",
    "stimmt",
    "veraltet",
    "verhaschen",
]

MINDESTLAENGE = 12
HOECHSTLAENGE = 200

#: So lange wartet ein Hash auf einen freien Platz, dann gibt er auf.
WARTEN_S = 3.0

_HASHER = PasswordHasher()
_GLEICHZEITIG = threading.BoundedSemaphore(2)


class PasswortError(ValueError):
    """Das Passwort wird nicht angenommen. Der Text ist für die Oberfläche gedacht."""


def _normal(klartext: str) -> str:
    return unicodedata.normalize("NFKC", klartext or "")


def pruefen(klartext: str, email: str = "") -> None:
    """Hält ein neues Passwort gegen die Regeln; wirft `PasswortError` mit dem Satz dazu."""
    passwort = _normal(klartext)
    if len(passwort) < MINDESTLAENGE:
        raise PasswortError(f"Das Passwort braucht mindestens {MINDESTLAENGE} Zeichen.")
    if len(passwort) > HOECHSTLAENGE:
        raise PasswortError(f"Das Passwort darf höchstens {HOECHSTLAENGE} Zeichen haben.")
    if email and passwort.strip().lower() == email.strip().lower():
        raise PasswortError("Das Passwort darf nicht die E-Mail-Adresse sein.")


def _verhaschen(passwort: str) -> str:
    if not _GLEICHZEITIG.acquire(timeout=WARTEN_S):
        raise PasswortError(
            "Der Dienst ist gerade ausgelastet. Bitte gleich noch einmal versuchen."
        )
    try:
        return _HASHER.hash(passwort)
    finally:
        _GLEICHZEITIG.release()


def _stimmt(gespeichert: str, passwort: str) -> bool:
    # Wer keinen Platz bekommt, wird abgelehnt und nicht angestellt: eine Schlange ohne Ende
    # hielte die Fäden fest, die der übrige Dienst braucht.
    if not _GLEICHZEITIG.acquire(timeout=WARTEN_S):
        return False
    try:
        return _HASHER.verify(gespeichert, passwort)
    except (VerificationError, InvalidHashError):
        return False
    finally:
        _GLEICHZEITIG.release()


@lru_cache(maxsize=1)
def _attrappe() -> str:
    """Ein Hash, zu dem niemand das Passwort kennt. Gegen ihn wird geprüft, wenn es zu einer
    Adresse kein Passwort gibt, damit die Antwortzeit nicht verrät, ob die Adresse existiert."""
    return _HASHER.hash("attrappe ohne passwort")


async def verhaschen(klartext: str) -> str:
    """Der Argon2id-Hash eines Passworts. Rechnet in einem eigenen Faden, damit der Dienst
    währenddessen weiter antwortet."""
    return await asyncio.to_thread(_verhaschen, _normal(klartext))


async def stimmt(gespeichert: str | None, klartext: str) -> bool:
    """Ob das Passwort zum abgelegten Hash passt.

    Ohne abgelegten Hash wird trotzdem gerechnet, gegen die Attrappe, und abgelehnt. Ein
    überlanges Passwort wird abgelehnt, ohne zu rechnen: es kann nie gesetzt worden sein.
    """
    passwort = _normal(klartext)
    if not passwort or len(passwort) > HOECHSTLAENGE:
        return False
    if not gespeichert:
        await asyncio.to_thread(_stimmt, _attrappe(), passwort)
        return False
    return await asyncio.to_thread(_stimmt, gespeichert, passwort)


def veraltet(gespeichert: str) -> bool:
    """Ob der Hash mit älteren Parametern gerechnet ist als denen von heute."""
    try:
        return _HASHER.check_needs_rehash(gespeichert)
    except InvalidHashError:
        return False
