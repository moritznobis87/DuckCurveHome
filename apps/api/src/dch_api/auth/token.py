"""Token - erzeugen, hashen, vergleichen.

Zwei Sorten, dasselbe Verfahren:

    Sitzungstoken     der Ausweis einer angemeldeten Person
    Zugangstoken      der einmalige Link für Einladung und Wiederherstellung

Ein Token besteht aus 256 Bit des Zufallsgenerators des Betriebssystems und hat damit keine
ratbare Struktur. Deshalb genügt SHA-256, wo ein Passwort Argon2id verlangt: ein langsamer Hash
schützt gegen Wortlisten, die es für Zufallszahlen nicht gibt.

Abgelegt wird nur der Hash, damit ein Lesezugriff auf die Datenbank keine Anmeldung erlaubt. Der
Klartext existiert genau einmal - in der Antwort an den Anmeldenden - und ist danach nicht mehr
nachschlagbar, sondern nur ersetzbar.

Übernommen aus `duckcurve/auth/token.py`; die Begründungen gelten unverändert.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets

__all__ = ["BYTES", "gleich", "neu", "verhaschen"]

#: Länge eines Tokens in Byte; 32 Byte = 256 Bit, als Text 43 Zeichen (base64url ohne
#: Füllzeichen). Das Token ist der vollständige Ausweis; da es nicht abgetippt wird, wäre eine
#: kürzere Fassung nicht bequemer, sondern nur schwächer.
BYTES = 32


def neu() -> str:
    """Ein neues Token im Klartext, `BYTES` Byte Entropie.

    `secrets` und nicht `random`: der Mersenne-Twister von `random` lässt sich aus hinreichend
    vielen Ausgaben rekonstruieren und ist für einen Ausweis ungeeignet.
    """
    return secrets.token_urlsafe(BYTES)


def verhaschen(token: str) -> str:
    """Der SHA-256 eines Tokens, hexadezimal - so liegt er in der Datenbank.

    Ohne Salz: Salz verhindert, dass gleiche Eingaben gleiche Hashes ergeben und sich vorberechnen
    lassen. Token sind paarweise verschieden, und ein Raum von 2^256 ist nicht vorberechenbar.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def gleich(links: str, rechts: str) -> bool:
    """Vergleicht zwei Hashes in konstanter Zeit.

    `==` bricht beim ersten abweichenden Zeichen ab; aus der Laufzeit ließe sich der erwartete Wert
    zeichenweise ableiten. Im Betrieb findet der Vergleich meist über einen Datenbankindex statt;
    die Funktion steht bereit, damit ein Vergleich im Speicher nicht versehentlich mit `==`
    geschrieben wird.
    """
    return hmac.compare_digest(links, rechts)
