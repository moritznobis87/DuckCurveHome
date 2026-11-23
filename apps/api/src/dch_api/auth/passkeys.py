"""Die WebAuthn-Zeremonien: Passkey anlegen, mit Passkey anmelden, Passkeys verwalten.

Ein Passkey ist ein Schlüsselpaar je Gerät. Der private Schlüssel bleibt beim Nutzer (Telefon,
Rechner, Sicherheitsschlüssel) und wird mit Fingerabdruck, Gesicht oder Geräte-PIN freigegeben;
hier liegt nur der öffentliche. Portiert aus `duckcurve/auth/passkeys.py` - die Regeln gelten
unverändert, die Datenbankzugriffe sind asynchron:

* **Gebunden an `settings.passkey_rp_id`** (`home.duckcurve.de`) - und nur daran: ein Passkey
  dieses Hauses taucht in keinem anderen Auswahldialog auf. Geprüfte Herkunft:
  `settings.passkey_herkuenfte`.
* **Nutzerprüfung ist Pflicht** (`user_verification=required`). Damit ist ein Passkey Besitz plus
  Wissen oder Merkmal; ein zweiter Faktor daneben wäre eine Wiederholung.
* **Auffindbare Passkeys** (`resident_key=required`): die Anmeldung beginnt ohne E-Mail-Adresse,
  der Browser bietet die Passkeys an.
* **Jede Ablehnung hat denselben Text.** Welcher der Gründe zutraf, bleibt im Dienst: ob es den
  Passkey nicht gibt, die Person abgeschaltet ist oder die Signatur nicht passte, ist für den
  Ablehnten dieselbe Auskunft - und für einen Angreifer wäre es eine.

Dieses Modul verwaltet keine Sitzungen: es bekommt eine offene Datenbanksitzung und gibt Zeilen
zurück. Wer eine Anmeldung daraus macht, ist `dienst.AuthDienst`.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import webauthn
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from webauthn.helpers import base64url_to_bytes
from webauthn.helpers.exceptions import (
    InvalidAuthenticationResponse,
    InvalidRegistrationResponse,
)
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    PublicKeyCredentialDescriptor,
    ResidentKeyRequirement,
    UserVerificationRequirement,
)

from dch_api.infrastructure.db import models as m
from dch_api.settings import Settings

from . import token

__all__ = [
    "LetzterPasskeyError",
    "PasskeyError",
    "Passkeyangaben",
    "Zeremonie",
    "anmeldung_beginnen",
    "liste",
    "loeschen",
    "pruefe_anmeldung",
    "pruefe_registrierung",
    "registrierung_beginnen",
    "umbenennen",
]

#: Wie lange eine angefangene Zeremonie gilt. Fünf Minuten sind reichlich für „Finger auf den
#: Sensor" und kurz genug, dass eine offene Challenge nicht herumliegt.
SCHRITT_MINUTEN = 5
#: So viele offene Anmeldeschritte gibt es gleichzeitig. Darüber weicht der älteste - verdrängen
#: statt ablehnen, damit eine Flut von außen echte Anmeldungen nicht aussperrt.
OFFENE_ANMELDESCHRITTE_MAX = 200
NAME_LAENGE = 80


def jetzt() -> datetime:
    return datetime.now(UTC)


def bewusst(wert: datetime) -> datetime:
    """Ein Zeitstempel mit Zeitzone.

    PostgreSQL gibt `DateTime(timezone=True)` bewusst zurueck, SQLite nicht - dort kommt eine
    zeitzonenlose Zeit, und jeder Vergleich mit `jetzt()` wirft. Die Tests laufen gegen SQLite,
    der Betrieb gegen Postgres; ohne diese Stelle faellt der Unterschied erst im einen oder
    anderen auf. Dieselbe Hilfe steht in `repositories.SqlRepositories._aware`.
    """
    return wert if wert.tzinfo is not None else wert.replace(tzinfo=UTC)


class PasskeyError(Exception):
    """Etwas an der Zeremonie ging schief - der Text ist für die Oberfläche gedacht."""


class LetzterPasskeyError(PasskeyError):
    """Der letzte Passkey einer Person bleibt: sonst käme sie nur noch über einen Link herein."""


@dataclass(frozen=True, slots=True)
class Zeremonie:
    """Der Beginn einer Zeremonie: der Schritt (zurückzureichen) und die Optionen für
    `navigator.credentials` als JSON-Text."""

    schritt: str
    optionen: str


@dataclass(frozen=True, slots=True)
class Passkeyangaben:
    id: str
    name: str
    gesichert: bool
    erstellt_am: datetime
    zuletzt_benutzt_am: datetime | None


def _name(name: str | None) -> str:
    name = " ".join((name or "").split())[:NAME_LAENGE]
    return name or "Passkey"


def _transports(antwort: dict[str, Any] | str) -> list[str]:
    """Wie der Browser das Gerät erreicht - für den nächsten Dialog, nicht für die Prüfung."""
    try:
        roh = json.loads(antwort) if isinstance(antwort, str) else antwort
        werte = (roh.get("response") or {}).get("transports") or []
        return [str(w)[:16] for w in werte][:8]
    except (ValueError, AttributeError):
        return []


async def _schritt_anlegen(
    s: AsyncSession, zweck: str, challenge: bytes, person_id: UUID | None
) -> str:
    klartext = token.neu()
    s.add(
        m.PasskeySchritt(
            token_hash=token.verhaschen(klartext),
            zweck=zweck,
            challenge=challenge,
            person_id=person_id,
            erstellt_am=jetzt(),
            laeuft_ab_am=jetzt() + timedelta(minutes=SCHRITT_MINUTEN),
        )
    )
    return klartext


async def _schritt_einloesen(s: AsyncSession, schritt: str, zweck: str) -> m.PasskeySchritt | None:
    """Der offene, gültige Schritt - einmal: er gilt danach als eingelöst.

    `with_for_update` sperrt die Zeile, damit Prüfen und Entwerten in derselben Transaktion
    zusammenbleiben: zwei gleichzeitige Antworten auf dieselbe Challenge gingen sonst beide
    durch, und die Einmaligkeit ist die halbe Sicherheit dieses Verfahrens. PostgreSQL sperrt
    damit wirklich; SQLite lässt `FOR UPDATE` weg (dort gibt es ohnehin nur einen Schreiber).
    """
    if not schritt:
        return None
    zeile = (
        await s.execute(
            select(m.PasskeySchritt)
            .where(
                m.PasskeySchritt.token_hash == token.verhaschen(schritt),
                m.PasskeySchritt.zweck == zweck,
            )
            .with_for_update()
        )
    ).scalar_one_or_none()
    if zeile is None or zeile.eingeloest_am is not None or bewusst(zeile.laeuft_ab_am) <= jetzt():
        return None
    zeile.eingeloest_am = jetzt()
    return zeile


async def hat_passkey(s: AsyncSession, person_id: UUID) -> bool:
    anzahl = await s.scalar(
        select(func.count()).select_from(m.Passkey).where(m.Passkey.person_id == person_id)
    )
    return bool(anzahl)


# ---------------------------------------------------------------------------
# Anlegen
# ---------------------------------------------------------------------------


async def registrierung_beginnen(
    s: AsyncSession, settings: Settings, person: m.Person
) -> Zeremonie:
    """Die Optionen für `navigator.credentials.create`.

    `exclude_credentials` nennt die Passkeys, die diese Person schon hat: so legt dasselbe Gerät
    nicht versehentlich einen zweiten an und der Browser sagt es gleich.
    """
    vorhandene = (
        (await s.execute(select(m.Passkey).where(m.Passkey.person_id == person.id))).scalars().all()
    )
    optionen = webauthn.generate_registration_options(
        rp_id=settings.passkey_rp_id,
        rp_name=settings.passkey_rp_name,
        user_id=str(person.id).encode("ascii"),
        user_name=person.email,
        user_display_name=person.anzeigename or person.email,
        timeout=SCHRITT_MINUTEN * 60_000,
        authenticator_selection=AuthenticatorSelectionCriteria(
            resident_key=ResidentKeyRequirement.REQUIRED,
            user_verification=UserVerificationRequirement.REQUIRED,
        ),
        exclude_credentials=[PublicKeyCredentialDescriptor(id=p.credential_id) for p in vorhandene],
    )
    schritt = await _schritt_anlegen(s, "registrierung", optionen.challenge, person.id)
    return Zeremonie(schritt=schritt, optionen=webauthn.options_to_json(optionen))


async def pruefe_registrierung(
    s: AsyncSession,
    settings: Settings,
    schritt: str,
    antwort: dict[str, Any] | str,
    person: m.Person,
    name: str | None = None,
) -> m.Passkey:
    """Prüft die Antwort des Geräts und legt den Passkey an. Die Sitzung macht der Aufrufer."""
    zeile = await _schritt_einloesen(s, schritt, "registrierung")
    if zeile is None or zeile.person_id != person.id:
        raise PasskeyError("Die Anfrage ist abgelaufen. Bitte noch einmal versuchen.")
    try:
        geprueft = webauthn.verify_registration_response(
            credential=antwort,
            expected_challenge=zeile.challenge,
            expected_rp_id=settings.passkey_rp_id,
            expected_origin=list(settings.passkey_herkuenfte),
            require_user_verification=True,
        )
    except (InvalidRegistrationResponse, ValueError, KeyError, TypeError) as fehler:
        raise PasskeyError(
            "Der Passkey ließ sich nicht prüfen. Bitte noch einmal versuchen."
        ) from fehler
    schon_da = (
        await s.execute(select(m.Passkey).where(m.Passkey.credential_id == geprueft.credential_id))
    ).scalar_one_or_none()
    if schon_da is not None:
        raise PasskeyError("Diesen Passkey gibt es schon.")
    passkey = m.Passkey(
        person_id=person.id,
        credential_id=geprueft.credential_id,
        oeffentlicher_schluessel=geprueft.credential_public_key,
        zaehler=geprueft.sign_count,
        transports=_transports(antwort),
        name=_name(name),
        gesichert=bool(geprueft.credential_backed_up),
        erstellt_am=jetzt(),
    )
    s.add(passkey)
    await s.flush()
    return passkey


# ---------------------------------------------------------------------------
# Anmelden
# ---------------------------------------------------------------------------


async def anmeldung_beginnen(s: AsyncSession, settings: Settings) -> Zeremonie:
    """Die Optionen für `navigator.credentials.get` - ohne Person.

    Öffentlich: wer „Mit Passkey anmelden" wählt, bekommt eine Challenge. Abgelaufene Schritte
    fallen hier weg, und mehr als `OFFENE_ANMELDESCHRITTE_MAX` offene gibt es nicht.
    """
    optionen = webauthn.generate_authentication_options(
        rp_id=settings.passkey_rp_id,
        timeout=SCHRITT_MINUTEN * 60_000,
        user_verification=UserVerificationRequirement.REQUIRED,
    )
    await s.execute(delete(m.PasskeySchritt).where(m.PasskeySchritt.laeuft_ab_am <= jetzt()))
    offen = list(
        (
            await s.execute(
                select(m.PasskeySchritt.id)
                .where(
                    m.PasskeySchritt.zweck == "anmeldung",
                    m.PasskeySchritt.eingeloest_am.is_(None),
                )
                .order_by(m.PasskeySchritt.erstellt_am, m.PasskeySchritt.id)
            )
        )
        .scalars()
        .all()
    )
    ueberzaehlig = offen[: max(0, len(offen) - OFFENE_ANMELDESCHRITTE_MAX + 1)]
    if ueberzaehlig:
        await s.execute(delete(m.PasskeySchritt).where(m.PasskeySchritt.id.in_(ueberzaehlig)))
    schritt = await _schritt_anlegen(s, "anmeldung", optionen.challenge, None)
    return Zeremonie(schritt=schritt, optionen=webauthn.options_to_json(optionen))


async def pruefe_anmeldung(
    s: AsyncSession, settings: Settings, schritt: str, antwort: dict[str, Any] | str
) -> tuple[m.Passkey, m.Person]:
    """Prüft die Antwort des Geräts und gibt Passkey und Person zurück.

    Kein zweiter Faktor danach: der Passkey ist mit Nutzerprüfung selbst zwei Faktoren. Die
    Person muss aktiv sein, wie bei jeder Anmeldung.
    """
    try:
        roh = json.loads(antwort) if isinstance(antwort, str) else dict(antwort)
        kennung = base64url_to_bytes(str(roh.get("rawId") or roh.get("id") or ""))
    except (ValueError, TypeError) as fehler:
        raise PasskeyError("Antwort unlesbar") from fehler
    zeile = await _schritt_einloesen(s, schritt, "anmeldung")
    if zeile is None:
        raise PasskeyError("Passkey-Schritt ungültig")
    passkey = (
        await s.execute(select(m.Passkey).where(m.Passkey.credential_id == kennung))
    ).scalar_one_or_none()
    if passkey is None:
        raise PasskeyError("unbekannter Passkey")
    try:
        geprueft = webauthn.verify_authentication_response(
            credential=roh,
            expected_challenge=zeile.challenge,
            expected_rp_id=settings.passkey_rp_id,
            expected_origin=list(settings.passkey_herkuenfte),
            credential_public_key=passkey.oeffentlicher_schluessel,
            credential_current_sign_count=passkey.zaehler,
            require_user_verification=True,
        )
    except (InvalidAuthenticationResponse, ValueError, KeyError, TypeError) as fehler:
        raise PasskeyError("Passkey-Antwort ungültig") from fehler
    person = await s.get(m.Person, passkey.person_id)
    if person is None or not person.aktiv:
        raise PasskeyError("Person abgeschaltet")
    passkey.zaehler = geprueft.new_sign_count
    passkey.gesichert = bool(geprueft.credential_backed_up)
    passkey.zuletzt_benutzt_am = jetzt()
    return passkey, person


# ---------------------------------------------------------------------------
# Verwalten
# ---------------------------------------------------------------------------


async def liste(s: AsyncSession, person_id: UUID) -> list[Passkeyangaben]:
    zeilen = (
        (
            await s.execute(
                select(m.Passkey)
                .where(m.Passkey.person_id == person_id)
                .order_by(m.Passkey.erstellt_am)
            )
        )
        .scalars()
        .all()
    )
    return [
        Passkeyangaben(
            str(p.id),
            p.name,
            p.gesichert,
            bewusst(p.erstellt_am),
            bewusst(p.zuletzt_benutzt_am) if p.zuletzt_benutzt_am else None,
        )
        for p in zeilen
    ]


async def _eigener(s: AsyncSession, person_id: UUID, passkey_id: str) -> m.Passkey:
    try:
        kennung = UUID(passkey_id)
    except (ValueError, AttributeError) as fehler:
        raise PasskeyError("Diesen Passkey gibt es nicht.") from fehler
    passkey = await s.get(m.Passkey, kennung)
    if passkey is None or passkey.person_id != person_id:
        # Derselbe Text für „gibt es nicht" und „gehört jemand anderem": sonst wäre die
        # Fehlermeldung eine Auskunft über die Passkeys anderer Leute.
        raise PasskeyError("Diesen Passkey gibt es nicht.")
    return passkey


async def umbenennen(s: AsyncSession, person_id: UUID, passkey_id: str, name: str) -> None:
    (await _eigener(s, person_id, passkey_id)).name = _name(name)


async def loeschen(s: AsyncSession, person_id: UUID, passkey_id: str) -> None:
    """Löscht einen eigenen Passkey - nicht den letzten: die Person käme sonst nur noch über
    einen Wiederherstellungscode oder einen Link des Hausherrn herein."""
    passkey = await _eigener(s, person_id, passkey_id)
    anzahl = await s.scalar(
        select(func.count()).select_from(m.Passkey).where(m.Passkey.person_id == person_id)
    )
    if (anzahl or 0) <= 1:
        raise LetzterPasskeyError(
            "Das ist der letzte Passkey. Erst einen weiteren anlegen, dann diesen löschen."
        )
    await s.delete(passkey)
