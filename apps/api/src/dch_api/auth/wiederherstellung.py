"""Wiederherstellungscodes: der Rückweg, wenn alle Passkeys weg sind.

Zehn Codes, je einmal gültig, abgelegt nur als Hash. Sie tragen 35 Bit Zufall - für eine Zeichenkette,
die jemand abtippt, ist das die Obergrenze des Erträglichen, und mehr ist auch nicht nötig: ein Code
gilt nur zusammen mit der E-Mail-Adresse, die Anmeldung hat eine Bremse (`drossel.py`), und nach zehn
Fehlversuchen in fünf Minuten ist Schluss.

Ein schneller Hash genügt, aus demselben Grund wie bei den Token (`token.py`): die Codes sind Zufall
und stehen in keiner Wortliste.

Übernommen aus `duckcurve/auth/zweiter_faktor.py` - nur der Teil für die Wiederherstellung. Einen
TOTP-Faktor gibt es hier nicht: ein Passkey mit verlangter Nutzerprüfung ist selbst zwei Faktoren.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets

__all__ = ["ANZAHL", "einloesen", "neue"]

ANZAHL = 10


def _normal(eingabe: str) -> str:
    """Nur Buchstaben und Ziffern, klein. So ist der Bindestrich Zierde und kein Teil des Codes,
    und wer den Code aus einer E-Mail kopiert, scheitert nicht an einem Leerzeichen."""
    return "".join(z for z in (eingabe or "").lower() if z.isalnum())


def neue() -> tuple[list[str], list[str]]:
    """Klartext (einmal anzuzeigen) und Hashes (abzulegen)."""
    klartext = []
    for _ in range(ANZAHL):
        roh = base64.b32encode(secrets.token_bytes(7)).decode("ascii").rstrip("=").lower()[:10]
        klartext.append(f"{roh[:5]}-{roh[5:]}")
    return klartext, [hashlib.sha256(_normal(k).encode()).hexdigest() for k in klartext]


def einloesen(hashes: list[str], eingabe: str) -> list[str] | None:
    """Die verbleibenden Hashes, wenn die Eingabe einer von ihnen ist - sonst `None`.

    Der Code verschwindet mit dem Einlösen: ein Code, der zweimal gilt, ist ein Passwort mit
    Verfallsdatum.
    """
    if not eingabe:
        return None
    h = hashlib.sha256(_normal(eingabe).encode()).hexdigest()
    for i, gespeichert in enumerate(hashes):
        if hmac.compare_digest(gespeichert, h):
            return hashes[:i] + hashes[i + 1 :]
    return None
