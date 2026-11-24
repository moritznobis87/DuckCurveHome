"""Sitzungen, Einladungen, Personen - alles, was eine Datenbank braucht.

Der Dienst hängt an der Sitzungsfabrik der Datenbank und ist der einzige Ort, an dem Anmeldungen
entstehen und vergehen. Er gibt `Ausweis` heraus und nichts sonst: wer ihn hat, weiß, wer fragt
und was er darf, und muss nicht nachschlagen (ADR-0002, Festlegung 3).

**Ohne Datenbank gibt es ihn nicht.** Im Demo-Modus läuft die API ohne Postgres; dann steht in
`app.state.auth` nichts, und die Anmeldung ist aus - wie bisher, wenn kein Token gesetzt war.

**Jede Ablehnung hat denselben Text.** Welcher Grund zutraf, bleibt hier.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, cast
from uuid import UUID

import structlog
from sqlalchemy import CursorResult, delete, func, select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from dch_api.auth import drossel, passkeys, passwort, wiederherstellung
from dch_api.auth.ausweis import Ausweis
from dch_api.auth.passkeys import bewusst
from dch_api.auth.rechte import ROLLEN, Rolle
from dch_api.infrastructure.db import models as m
from dch_api.settings import Settings

from . import token

log = structlog.get_logger("auth")

__all__ = [
    "Angemeldet",
    "AngemeldetError",
    "AuthDienst",
    "LetzterWegError",
    "PersonAngaben",
    "SitzungAngaben",
    "ZugangError",
]

#: Nach dieser Zeit wird `zuletzt_benutzt_am` einer Sitzung neu geschrieben. Der Vermerk dient der
#: Anzeige „zuletzt aktiv", nicht der Gültigkeit - die hängt an `laeuft_ab_am`. Ihn bei jeder
#: Anfrage zu schreiben hieße, für eine Anzeige in Minuten einen Schreibvorgang je Tastendruck zu
#: bezahlen, und auf dem Hausgerät steht die Datenbank auf einer SSD, die sich abnutzt.
VERMERK_S = 300


def jetzt() -> datetime:
    return datetime.now(UTC)


class ZugangError(Exception):
    """Der Link oder die Eingabe gilt nicht. Der Text ist für die Oberfläche."""


class LetzterWegError(Exception):
    """Der letzte Weg herein bleibt: das Passwort geht nur, solange ein Passkey da ist."""


class AngemeldetError(Exception):
    """Die Anmeldung ist abgelehnt - immer mit demselben Text."""


ABGELEHNT = "Die Anmeldung ist nicht möglich."


@dataclass(frozen=True, slots=True)
class Angemeldet:
    """Das Ergebnis einer Anmeldung: das Token im Klartext, der Ausweis, die Frist."""

    token: str
    ausweis: Ausweis
    laeuft_ab_am: datetime


@dataclass(frozen=True, slots=True)
class PersonAngaben:
    id: str
    email: str
    anzeigename: str
    rolle: str
    aktiv: bool
    erstellt_am: datetime
    zuletzt_angemeldet_am: datetime | None
    passkeys: int
    #: Ob die Person ein Passwort hat. Nie das Passwort selbst und nie sein Hash.
    passwort: bool
    #: Wie viele Wiederherstellungscodes noch ungenutzt sind.
    codes_offen: int
    #: Ob ein Einladungslink offen ist (ausgestellt, nicht eingelöst, nicht abgelaufen).
    einladung_offen: bool


@dataclass(frozen=True, slots=True)
class SitzungAngaben:
    id: str
    erstellt_am: datetime
    laeuft_ab_am: datetime
    zuletzt_benutzt_am: datetime | None
    herkunft: str
    #: Ob das die Sitzung ist, mit der gerade gefragt wird.
    diese: bool


def _email(roh: str) -> str:
    email = (roh or "").strip().lower()
    if "@" not in email or len(email) > 254 or " " in email:
        raise ZugangError("Das ist keine E-Mail-Adresse.")
    return email


def _rolle(roh: str) -> Rolle:
    if roh not in ROLLEN:
        raise ZugangError(f"Unbekannte Rolle „{roh}“.")
    return roh  # type: ignore[return-value]


def _kennung(roh: str) -> UUID:
    try:
        return UUID(roh)
    except (ValueError, AttributeError, TypeError) as fehler:
        raise ZugangError("Diese Person gibt es nicht.") from fehler


class AuthDienst:
    """Die Anmeldung dieses Hauses."""

    def __init__(self, engine: AsyncEngine, settings: Settings) -> None:
        self.maker: async_sessionmaker[AsyncSession] = async_sessionmaker(
            engine, expire_on_commit=False
        )
        self.settings = settings

    # ------------------------------------------------------------------ Ausweis
    def _ausweis(self, person: m.Person, sitzung_id: UUID | None = None) -> Ausweis:
        return Ausweis(
            art="person",
            rolle=_rolle(person.rolle),
            person_id=str(person.id),
            name=person.anzeigename or person.email,
            email=person.email,
            sitzung_id=str(sitzung_id) if sitzung_id else "",
        )

    async def _sitzung_anlegen(
        self, s: AsyncSession, person: m.Person, herkunft: str
    ) -> Angemeldet:
        klartext = token.neu()
        ablauf = jetzt() + timedelta(days=self.settings.sitzung_tage)
        sitzung = m.PersonSitzung(
            person_id=person.id,
            token_hash=token.verhaschen(klartext),
            erstellt_am=jetzt(),
            laeuft_ab_am=ablauf,
            herkunft=(herkunft or "")[:120],
        )
        s.add(sitzung)
        person.zuletzt_angemeldet_am = jetzt()
        await s.flush()
        return Angemeldet(
            token=klartext, ausweis=self._ausweis(person, sitzung.id), laeuft_ab_am=ablauf
        )

    async def sitzung_aufloesen(self, klartext: str) -> Ausweis | None:
        """Wer steckt hinter diesem Token - oder `None`.

        **Eine Abfrage, und sie prüft alles auf einmal:** Token bekannt, nicht abgelaufen, Person
        aktiv. Genau das ist der Grund für opake Token statt JWT - wer eine Person abschaltet, hat
        sie im nächsten Augenblick draußen und nicht erst in dreißig Tagen.

        Eine abgelaufene Sitzung wird gleich gelöscht: sie ist wertlos, und was nicht mehr da ist,
        kann nicht versehentlich wieder gelten.

        **Die Frist gleitet mit.** Wird eine Sitzung benutzt, rückt `laeuft_ab_am` nach vorn. Eine
        Wandanzeige, die den ganzen Tag dasselbe Haus zeigt, fiele sonst nach
        `DCH_SITZUNG_TAGE` heraus und müsste von jemandem mit Fingerabdruck wieder angemeldet
        werden - das war der Grund, warum es früher ein Gerätecookie mit einem halben Jahr Frist
        gab. Eine liegengebliebene Sitzung läuft weiterhin ab; widerrufen wird ohnehin durch
        Löschen der Zeile und nicht durch Warten.
        """
        if not klartext:
            return None
        async with self.maker() as s:
            treffer = (
                await s.execute(
                    select(m.PersonSitzung, m.Person)
                    .join(m.Person, m.Person.id == m.PersonSitzung.person_id)
                    .where(m.PersonSitzung.token_hash == token.verhaschen(klartext))
                )
            ).first()
            if treffer is None:
                return None
            sitzung, person = treffer
            if bewusst(sitzung.laeuft_ab_am) <= jetzt():
                await s.delete(sitzung)
                await s.commit()
                return None
            if not person.aktiv:
                return None
            vermerk = sitzung.zuletzt_benutzt_am
            if vermerk is None or (jetzt() - bewusst(vermerk)).total_seconds() > VERMERK_S:
                sitzung.zuletzt_benutzt_am = jetzt()
                sitzung.laeuft_ab_am = jetzt() + timedelta(days=self.settings.sitzung_tage)
                await s.commit()
            return self._ausweis(person, sitzung.id)

    async def abmelden(self, klartext: str) -> bool:
        """Beendet EINE Sitzung. Ein Abmelden ohne gültige Sitzung ist kein Fehler: der Anwender
        wollte abgemeldet sein, und das ist er."""
        if not klartext:
            return False
        async with self.maker() as s:
            ergebnis = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.PersonSitzung).where(
                        m.PersonSitzung.token_hash == token.verhaschen(klartext)
                    )
                ),
            )
            await s.commit()
            return bool(ergebnis.rowcount)

    async def sitzungen(self, person_id: str, diese: str = "") -> list[SitzungAngaben]:
        async with self.maker() as s:
            zeilen = (
                (
                    await s.execute(
                        select(m.PersonSitzung)
                        .where(m.PersonSitzung.person_id == _kennung(person_id))
                        .order_by(m.PersonSitzung.erstellt_am.desc())
                    )
                )
                .scalars()
                .all()
            )
        return [
            SitzungAngaben(
                id=str(z.id),
                erstellt_am=bewusst(z.erstellt_am),
                laeuft_ab_am=bewusst(z.laeuft_ab_am),
                zuletzt_benutzt_am=bewusst(z.zuletzt_benutzt_am) if z.zuletzt_benutzt_am else None,
                herkunft=z.herkunft,
                diese=str(z.id) == diese,
            )
            for z in zeilen
        ]

    async def sitzung_beenden(self, person_id: str, sitzung_id: str) -> bool:
        """Beendet eine EIGENE Sitzung - für „dieses Gerät abmelden" aus der Ferne."""
        async with self.maker() as s:
            ergebnis = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.PersonSitzung).where(
                        m.PersonSitzung.id == _kennung(sitzung_id),
                        m.PersonSitzung.person_id == _kennung(person_id),
                    )
                ),
            )
            await s.commit()
            return bool(ergebnis.rowcount)

    async def alle_sitzungen_beenden(self, person_id: str) -> int:
        async with self.maker() as s:
            ergebnis = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.PersonSitzung).where(m.PersonSitzung.person_id == _kennung(person_id))
                ),
            )
            await s.commit()
            return int(ergebnis.rowcount or 0)

    # ------------------------------------------------------------------ Personen
    async def anzahl(self) -> int:
        async with self.maker() as s:
            return int(await s.scalar(select(func.count()).select_from(m.Person)) or 0)

    async def _angaben(self, s: AsyncSession, person: m.Person) -> PersonAngaben:
        anzahl_passkeys = await s.scalar(
            select(func.count()).select_from(m.Passkey).where(m.Passkey.person_id == person.id)
        )
        offen = await s.scalar(
            select(func.count())
            .select_from(m.Zugangstoken)
            .where(
                m.Zugangstoken.person_id == person.id,
                m.Zugangstoken.eingeloest_am.is_(None),
                m.Zugangstoken.laeuft_ab_am > jetzt(),
            )
        )
        return PersonAngaben(
            id=str(person.id),
            email=person.email,
            anzeigename=person.anzeigename,
            rolle=person.rolle,
            aktiv=person.aktiv,
            erstellt_am=bewusst(person.erstellt_am),
            zuletzt_angemeldet_am=(
                bewusst(person.zuletzt_angemeldet_am) if person.zuletzt_angemeldet_am else None
            ),
            passkeys=int(anzahl_passkeys or 0),
            passwort=bool(person.passwort_hash),
            codes_offen=len(person.wiederherstellungscodes or []),
            einladung_offen=bool(offen),
        )

    async def personen(self) -> list[PersonAngaben]:
        async with self.maker() as s:
            zeilen = (
                (await s.execute(select(m.Person).order_by(m.Person.erstellt_am))).scalars().all()
            )
            return [await self._angaben(s, p) for p in zeilen]

    async def person(self, person_id: str) -> PersonAngaben:
        async with self.maker() as s:
            person = await s.get(m.Person, _kennung(person_id))
            if person is None:
                raise ZugangError("Diese Person gibt es nicht.")
            return await self._angaben(s, person)

    async def person_anlegen(
        self, email: str, anzeigename: str, rolle: str
    ) -> tuple[PersonAngaben, str]:
        """Legt eine Person an und gibt sie samt Einladungstoken im Klartext zurück.

        Kein vorläufiges Passwort und kein Passwort überhaupt: über den Link legt die Person
        einen Passkey an, und damit ist sie angemeldet.
        """
        adresse = _email(email)
        art = _rolle(rolle)
        async with self.maker() as s:
            schon_da = (
                await s.execute(select(m.Person).where(m.Person.email == adresse))
            ).scalar_one_or_none()
            if schon_da is not None:
                raise ZugangError("Diese E-Mail-Adresse hat schon einen Zugang.")
            person = m.Person(
                email=adresse,
                anzeigename=" ".join((anzeigename or "").split())[:80],
                rolle=art,
                aktiv=True,
                erstellt_am=jetzt(),
            )
            s.add(person)
            await s.flush()
            klartext = await self._token_anlegen(s, person.id, "einladung")
            angaben = await self._angaben(s, person)
            await s.commit()
        log.info("person angelegt", rolle=art, email=_verkuerzt(adresse))
        return angaben, klartext

    async def person_aendern(
        self,
        person_id: str,
        *,
        rolle: str | None = None,
        aktiv: bool | None = None,
        anzeigename: str | None = None,
    ) -> PersonAngaben:
        """Rolle, Name oder Zustand ändern.

        Wer abgeschaltet wird, verliert seine Sitzungen sofort: eine abgeschaltete Person, die
        noch eine Stunde weiterklicken kann, ist nicht abgeschaltet. Die Passkeys bleiben liegen
        und nützen nichts, solange `aktiv` falsch ist - so lässt sich jemand wieder einschalten,
        ohne dass er neu einrichten muss.
        """
        async with self.maker() as s:
            person = await s.get(m.Person, _kennung(person_id))
            if person is None:
                raise ZugangError("Diese Person gibt es nicht.")
            if rolle is not None:
                neue_rolle = _rolle(rolle)
                if person.rolle == "hausherr" and neue_rolle != "hausherr":
                    await self._letzter_hausherr_pruefen(s, person.id)
                person.rolle = neue_rolle
            if anzeigename is not None:
                person.anzeigename = " ".join(anzeigename.split())[:80]
            if aktiv is not None and aktiv != person.aktiv:
                if not aktiv and person.rolle == "hausherr":
                    await self._letzter_hausherr_pruefen(s, person.id)
                person.aktiv = aktiv
                if not aktiv:
                    await s.execute(
                        delete(m.PersonSitzung).where(m.PersonSitzung.person_id == person.id)
                    )
            angaben = await self._angaben(s, person)
            await s.commit()
            return angaben

    async def person_loeschen(self, person_id: str) -> None:
        """Löscht eine Person samt Passkeys, Sitzungen und offenen Links (`ON DELETE CASCADE`)."""
        async with self.maker() as s:
            person = await s.get(m.Person, _kennung(person_id))
            if person is None:
                raise ZugangError("Diese Person gibt es nicht.")
            if person.rolle == "hausherr":
                await self._letzter_hausherr_pruefen(s, person.id)
            await s.delete(person)
            await s.commit()

    async def _letzter_hausherr_pruefen(self, s: AsyncSession, ausser: UUID) -> None:
        """Es muss ein aktiver Hausherr übrig bleiben.

        Ohne diese Prüfung lässt sich das Haus aussperren: der letzte Hausherr schaltet sich
        selbst ab, und danach kann niemand mehr Personen verwalten. Der Weg zurück wäre die
        Datenbank von Hand - auf einem Hausgerät beim Kunden ist das keiner.
        """
        weitere = await s.scalar(
            select(func.count())
            .select_from(m.Person)
            .where(m.Person.rolle == "hausherr", m.Person.aktiv.is_(True), m.Person.id != ausser)
        )
        if not weitere:
            raise ZugangError(
                "Das ist der letzte aktive Hausherr. Erst einen zweiten einrichten, "
                "sonst kommt niemand mehr an die Verwaltung."
            )

    # ------------------------------------------------------------------ Einladung
    async def _token_anlegen(self, s: AsyncSession, person_id: UUID, zweck: str) -> str:
        """Ein einmaliger Link; ein älterer offener desselben Zwecks wird entwertet.

        Zwei gültige Einladungslinks für dieselbe Person sind einer zu viel.
        """
        await s.execute(
            delete(m.Zugangstoken).where(
                m.Zugangstoken.person_id == person_id,
                m.Zugangstoken.zweck == zweck,
                m.Zugangstoken.eingeloest_am.is_(None),
            )
        )
        klartext = token.neu()
        s.add(
            m.Zugangstoken(
                person_id=person_id,
                token_hash=token.verhaschen(klartext),
                zweck=zweck,
                erstellt_am=jetzt(),
                laeuft_ab_am=jetzt() + timedelta(hours=self.settings.zugangstoken_stunden),
            )
        )
        return klartext

    async def einladen(self, person_id: str, zweck: str = "einladung") -> tuple[str, str]:
        """Ein neuer Link für diese Person. Zurück kommen Token und E-Mail-Adresse."""
        if zweck not in ("einladung", "wiederherstellung"):
            raise ZugangError("Unbekannter Zweck.")
        async with self.maker() as s:
            person = await s.get(m.Person, _kennung(person_id))
            if person is None:
                raise ZugangError("Diese Person gibt es nicht.")
            klartext = await self._token_anlegen(s, person.id, zweck)
            adresse = person.email
            await s.commit()
        return klartext, adresse

    async def notzugang(self, email: str) -> tuple[PersonAngaben, str]:
        """Der Rückweg, wenn niemand mehr hereinkommt. Legt einen Link für diese Adresse auf.

        **Warum es das gibt.** Alle anderen Wege setzen voraus, dass irgendjemand noch
        hereinkommt: ein zweiter Passkey, ein Wiederherstellungscode, ein Link des Hausherrn.
        Fällt alles zugleich aus - der einzige Passkey ist an eine alte RP-ID gebunden, die Codes
        sind nicht aufgehoben -, bliebe sonst nur, die Personentabelle von Hand zu leeren, damit
        `DCH_ERSTE_PERSON` wieder greift. Das ist auf einem Hausgerät beim Kunden kein Weg.

        **Was er kann und was das heißt.** Er macht die genannte Person wieder aktiv, setzt sie auf
        `hausherr` und stellt ihr einen Einladungslink aus; gibt es sie nicht, legt er sie an. Wer
        die Umgebung des Dienstes setzen kann, kann sich damit Zugang verschaffen - das konnte er
        vorher auch schon, nur über die Datenbank. Darum gehört der Schalter nach Gebrauch wieder
        weg, und der Dienst sagt das bei jedem Start, solange er steht.
        """
        adresse = _email(email)
        async with self.maker() as s:
            person = (
                await s.execute(select(m.Person).where(m.Person.email == adresse))
            ).scalar_one_or_none()
            if person is None:
                person = m.Person(
                    email=adresse,
                    anzeigename="",
                    rolle="hausherr",
                    aktiv=True,
                    erstellt_am=jetzt(),
                )
                s.add(person)
                await s.flush()
            else:
                person.aktiv = True
                person.rolle = "hausherr"
            klartext = await self._token_anlegen(s, person.id, "einladung")
            angaben = await self._angaben(s, person)
            await s.commit()
        log.warning("notzugang ausgestellt", email=_verkuerzt(adresse))
        return angaben, klartext

    def link(self, klartext: str) -> str:
        """Die vollständige Adresse, die in die Einladung gehört."""
        return f"{self.settings.anmeldung_url}/anmeldung/einrichten?token={klartext}"

    async def _zugangstoken(self, s: AsyncSession, klartext: str) -> m.Zugangstoken:
        if not klartext:
            raise ZugangError("Der Link ist unvollständig.")
        # Gesperrt gelesen, damit Prüfen und Einlösen zusammenbleiben: zwei gleichzeitige
        # Aufrufe mit demselben Link legten sonst beide einen Passkey an. PostgreSQL sperrt,
        # SQLite lässt `FOR UPDATE` weg.
        eintrag = (
            await s.execute(
                select(m.Zugangstoken)
                .where(m.Zugangstoken.token_hash == token.verhaschen(klartext))
                .with_for_update()
            )
        ).scalar_one_or_none()
        if eintrag is None:
            raise ZugangError("Der Link ist ungültig.")
        if eintrag.eingeloest_am is not None:
            raise ZugangError("Der Link wurde schon benutzt.")
        if bewusst(eintrag.laeuft_ab_am) <= jetzt():
            raise ZugangError("Der Link ist abgelaufen.")
        return eintrag

    async def einladung_pruefen(self, klartext: str) -> PersonAngaben:
        """Für die Seite hinter dem Link: zu wem gehört er? Löst ihn nicht ein."""
        async with self.maker() as s:
            eintrag = await self._zugangstoken(s, klartext)
            person = await s.get(m.Person, eintrag.person_id)
            if person is None or not person.aktiv:
                raise ZugangError("Der Link ist ungültig.")
            return await self._angaben(s, person)

    # ------------------------------------------------------------------ Passkeys
    async def registrierung_beginnen(
        self, *, person_id: str = "", zugangstoken: str = ""
    ) -> passkeys.Zeremonie:
        """Die Optionen für einen neuen Passkey - für die angemeldete Person oder über einen Link."""
        async with self.maker() as s:
            person = await self._person_fuer_registrierung(s, person_id, zugangstoken)
            zeremonie = await passkeys.registrierung_beginnen(s, self.settings, person)
            await s.commit()
            return zeremonie

    async def _person_fuer_registrierung(
        self, s: AsyncSession, person_id: str, zugangstoken: str
    ) -> m.Person:
        if zugangstoken:
            eintrag = await self._zugangstoken(s, zugangstoken)
            person = await s.get(m.Person, eintrag.person_id)
        else:
            person = await s.get(m.Person, _kennung(person_id)) if person_id else None
        if person is None or not person.aktiv:
            raise ZugangError("Der Link ist ungültig.")
        return person

    async def passkey_anlegen(
        self,
        *,
        schritt: str,
        antwort: dict[str, Any] | str,
        name: str = "",
        person_id: str = "",
        zugangstoken: str = "",
        herkunft: str = "",
    ) -> passkeys.Passkeyangaben | Angemeldet:
        """Prüft die Antwort des Geräts und legt den Passkey an.

        Angemeldet: zurück kommen die Angaben des neuen Passkeys. Über einen Link: der Link ist
        danach eingelöst, alle offenen Links der Person entfallen, und zurück kommt eine Sitzung -
        angemeldet mit eben diesem Passkey. Beim ersten Passkey entstehen dabei die zehn
        Wiederherstellungscodes; sie gehen im Klartext einmal an die Oberfläche.
        """
        async with self.maker() as s:
            person = await self._person_fuer_registrierung(s, person_id, zugangstoken)
            passkey = await passkeys.pruefe_registrierung(
                s, self.settings, schritt, antwort, person, name
            )
            if not zugangstoken:
                await s.commit()
                return passkeys.Passkeyangaben(
                    str(passkey.id),
                    passkey.name,
                    passkey.gesichert,
                    bewusst(passkey.erstellt_am),
                    None,
                )
            eintrag = await self._zugangstoken(s, zugangstoken)
            eintrag.eingeloest_am = jetzt()
            await s.execute(
                delete(m.Zugangstoken).where(
                    m.Zugangstoken.person_id == person.id,
                    m.Zugangstoken.eingeloest_am.is_(None),
                )
            )
            # Der Link hat jemand anderem gehört, bis er eingelöst wurde: alte Sitzungen enden.
            await s.execute(delete(m.PersonSitzung).where(m.PersonSitzung.person_id == person.id))
            passkey.zuletzt_benutzt_am = jetzt()
            angemeldet = await self._sitzung_anlegen(s, person, herkunft)
            await s.commit()
            return angemeldet

    async def anmeldung_beginnen(self) -> passkeys.Zeremonie:
        async with self.maker() as s:
            zeremonie = await passkeys.anmeldung_beginnen(s, self.settings)
            await s.commit()
            return zeremonie

    async def anmelden(
        self, schritt: str, antwort: dict[str, Any] | str, herkunft: str = ""
    ) -> Angemeldet:
        async with self.maker() as s:
            try:
                _, person = await passkeys.pruefe_anmeldung(s, self.settings, schritt, antwort)
            except passkeys.PasskeyError as fehler:
                log.info("anmeldung abgelehnt", grund=str(fehler))
                raise AngemeldetError(ABGELEHNT) from fehler
            angemeldet = await self._sitzung_anlegen(s, person, herkunft)
            await s.commit()
        log.info("angemeldet", weg="passkey", person=angemeldet.ausweis.person_id)
        return angemeldet

    async def passkeys_der_person(self, person_id: str) -> list[passkeys.Passkeyangaben]:
        async with self.maker() as s:
            return await passkeys.liste(s, _kennung(person_id))

    async def passkey_umbenennen(self, person_id: str, passkey_id: str, name: str) -> None:
        async with self.maker() as s:
            await passkeys.umbenennen(s, _kennung(person_id), passkey_id, name)
            await s.commit()

    async def passkey_loeschen(self, person_id: str, passkey_id: str) -> None:
        """Löscht einen eigenen Passkey. Der letzte bleibt, außer die Person hat ein Passwort:
        dann kommt sie auch ohne Passkey herein."""
        async with self.maker() as s:
            # Gesperrt gelesen, wie in `passwort_entfernen`: die beiden Wege herein werden nie
            # gleichzeitig geprüft und entfernt.
            person = await s.get(m.Person, _kennung(person_id), with_for_update=True)
            await passkeys.loeschen(
                s,
                _kennung(person_id),
                passkey_id,
                letzter_darf_gehen=person is not None and bool(person.passwort_hash),
            )
            await s.commit()

    # ------------------------------------------------------------------ Passwort
    async def anmelden_mit_passwort(
        self, email: str, klartext: str, herkunft: str = ""
    ) -> Angemeldet:
        """Anmeldung mit E-Mail-Adresse und Passwort.

        Gebremst je Adresse, mit derselben Zählung wie die Wiederherstellungscodes: wer rät,
        bekommt nicht zehn Versuche für das Passwort und zehn weitere für die Codes. Gerechnet
        wird auch dann, wenn es die Adresse nicht gibt oder sie kein Passwort hat, damit die
        Antwortzeit nichts darüber verrät.
        """
        adresse = (email or "").strip().lower()
        if not adresse or not klartext:
            raise AngemeldetError(ABGELEHNT)
        if drossel.gesperrt(adresse):
            log.info("passwortanmeldung gesperrt", email=_verkuerzt(adresse))
            raise AngemeldetError(ABGELEHNT)
        async with self.maker() as s:
            person = (
                await s.execute(select(m.Person).where(m.Person.email == adresse))
            ).scalar_one_or_none()
            gespeichert = person.passwort_hash if person is not None and person.aktiv else None
            kennung = person.id if person is not None else None
        # Außerhalb der Datenbanksitzung: der Hash braucht einen Augenblick, und so lange soll
        # keine Verbindung offen stehen.
        if not await passwort.stimmt(gespeichert, klartext) or kennung is None:
            drossel.fehlversuch(adresse)
            log.info("passwortanmeldung abgelehnt", email=_verkuerzt(adresse))
            raise AngemeldetError(ABGELEHNT)
        neuer_hash = (
            await passwort.verhaschen(klartext)
            if gespeichert and passwort.veraltet(gespeichert)
            else None
        )
        async with self.maker() as s:
            person = await s.get(m.Person, kennung)
            # Zwischen Lesen und Schreiben kann die Person abgeschaltet oder ihr Passwort
            # gewechselt worden sein. Dann gilt die Prüfung von eben nicht mehr.
            if person is None or not person.aktiv or person.passwort_hash != gespeichert:
                drossel.fehlversuch(adresse)
                raise AngemeldetError(ABGELEHNT)
            if neuer_hash:
                person.passwort_hash = neuer_hash
            angemeldet = await self._sitzung_anlegen(s, person, herkunft)
            await s.commit()
        drossel.vergessen(adresse)
        log.info("angemeldet", weg="passwort", person=angemeldet.ausweis.person_id)
        return angemeldet

    async def passwort_ueber_link(
        self, zugangstoken: str, klartext: str, herkunft: str = ""
    ) -> Angemeldet:
        """Setzt das Passwort über einen Einladungslink, löst den Link ein und meldet an.

        Derselbe Ablauf wie beim Passkey über den Link: alle offenen Links der Person
        entfallen, und ihre alten Sitzungen enden, weil der Link bis zum Einlösen jemand anderem
        gehört haben kann. Ein Passwort, das die Person schon hatte, wird ersetzt. Das ist der
        Weg, wenn sie es vergessen hat.
        """
        async with self.maker() as s:
            eingeladen = await self._person_fuer_registrierung(s, "", zugangstoken)
            passwort.pruefen(klartext, eingeladen.email)
        neuer_hash = await passwort.verhaschen(klartext)
        async with self.maker() as s:
            # Noch einmal und diesmal gesperrt gelesen: Prüfen und Einlösen bleiben zusammen.
            eintrag = await self._zugangstoken(s, zugangstoken)
            person = await s.get(m.Person, eintrag.person_id)
            if person is None or not person.aktiv:
                raise ZugangError("Der Link ist ungültig.")
            adresse = person.email
            person.passwort_hash = neuer_hash
            person.passwort_gesetzt_am = jetzt()
            eintrag.eingeloest_am = jetzt()
            await s.execute(
                delete(m.Zugangstoken).where(
                    m.Zugangstoken.person_id == person.id,
                    m.Zugangstoken.eingeloest_am.is_(None),
                )
            )
            await s.execute(delete(m.PersonSitzung).where(m.PersonSitzung.person_id == person.id))
            angemeldet = await self._sitzung_anlegen(s, person, herkunft)
            await s.commit()
        drossel.vergessen(adresse)
        log.info("passwort gesetzt", weg="link", person=angemeldet.ausweis.person_id)
        return angemeldet

    async def passwort_setzen(
        self, person_id: str, neu: str, bisher: str = "", sitzung_id: str | None = None
    ) -> int:
        """Setzt oder wechselt das Passwort der angemeldeten Person.

        Wer schon eines hat, nennt das bisherige: eine Sitzung an einem liegengelassenen Gerät
        soll nicht genügen, um den Besitzer auszusperren. Danach enden alle anderen Sitzungen
        der Person; zurück kommt ihre Zahl.
        """
        kennung = _kennung(person_id)
        async with self.maker() as s:
            person = await s.get(m.Person, kennung)
            if person is None or not person.aktiv:
                raise ZugangError("Diese Person gibt es nicht.")
            email, gespeichert = person.email, person.passwort_hash
        if gespeichert:
            if drossel.gesperrt(email):
                raise passwort.PasswortError("Zu viele Versuche. Bitte in fünf Minuten erneut.")
            if not await passwort.stimmt(gespeichert, bisher):
                drossel.fehlversuch(email)
                raise passwort.PasswortError("Das bisherige Passwort stimmt nicht.")
        passwort.pruefen(neu, email)
        neuer_hash = await passwort.verhaschen(neu)
        async with self.maker() as s:
            person = await s.get(m.Person, kennung)
            if person is None or not person.aktiv or person.passwort_hash != gespeichert:
                raise ZugangError("Das Passwort wurde inzwischen an anderer Stelle geändert.")
            person.passwort_hash = neuer_hash
            person.passwort_gesetzt_am = jetzt()
            andere = delete(m.PersonSitzung).where(m.PersonSitzung.person_id == kennung)
            if sitzung_id:
                andere = andere.where(m.PersonSitzung.id != _kennung(sitzung_id))
            ergebnis = cast(CursorResult[Any], await s.execute(andere))
            await s.commit()
        log.info("passwort gesetzt", weg="angemeldet", person=person_id)
        return int(ergebnis.rowcount or 0)

    async def passwort_entfernen(self, person_id: str, bisher: str) -> None:
        """Nimmt das Passwort weg. Nur mit mindestens einem Passkey: sonst käme die Person nur
        noch über einen Wiederherstellungscode oder einen Link des Hausherrn herein.

        **Auch hier wird das bisherige Passwort verlangt.** Ohne das ließe sich die Prüfung beim
        Wechseln umgehen: entfernen, dann ein neues vergeben, und der Besitzer wäre aus einer
        liegengelassenen Sitzung heraus ausgesperrt (Fund im Review von PR 31).
        """
        kennung = _kennung(person_id)
        async with self.maker() as s:
            person = await s.get(m.Person, kennung)
            if person is None or not person.aktiv:
                raise ZugangError("Diese Person gibt es nicht.")
            email, gespeichert = person.email, person.passwort_hash
        if not gespeichert:
            raise passwort.PasswortError("Es gibt kein Passwort, das sich entfernen ließe.")
        if drossel.gesperrt(email):
            raise passwort.PasswortError("Zu viele Versuche. Bitte in fünf Minuten erneut.")
        if not await passwort.stimmt(gespeichert, bisher):
            drossel.fehlversuch(email)
            raise passwort.PasswortError("Das bisherige Passwort stimmt nicht.")
        async with self.maker() as s:
            # Die Zeile der Person gesperrt gelesen, wie in `passkey_loeschen`: zwei gleichzeitige
            # Anfragen, die den letzten Passkey und das Passwort entfernen, sähen sonst jede noch
            # den anderen Weg und ließen zusammen keinen übrig.
            person = await s.get(m.Person, kennung, with_for_update=True)
            if person is None or not person.aktiv or person.passwort_hash != gespeichert:
                raise ZugangError("Das Passwort wurde inzwischen an anderer Stelle geändert.")
            anzahl = await s.scalar(
                select(func.count()).select_from(m.Passkey).where(m.Passkey.person_id == kennung)
            )
            if not anzahl:
                raise LetzterWegError(
                    "Das Passwort ist der einzige Weg herein. Erst einen Passkey anlegen, "
                    "dann das Passwort entfernen."
                )
            person.passwort_hash = None
            person.passwort_gesetzt_am = None
            await s.commit()
        log.info("passwort entfernt", person=person_id)

    # ------------------------------------------------------------------ Wiederherstellung
    async def codes_neu(self, person_id: str) -> list[str]:
        """Zehn neue Codes; die alten gelten nicht mehr. Klartext nur hier, einmal."""
        async with self.maker() as s:
            person = await s.get(m.Person, _kennung(person_id))
            if person is None:
                raise ZugangError("Diese Person gibt es nicht.")
            klartext, hashes = wiederherstellung.neue()
            person.wiederherstellungscodes = hashes
            await s.commit()
        return klartext

    async def wiederherstellen(self, email: str, code: str, herkunft: str = "") -> Angemeldet:
        """Anmeldung mit E-Mail-Adresse und Wiederherstellungscode. Der Code gilt einmal.

        Der Weg für „alle Geräte verloren". Danach gehört der erste Griff in das Konto: einen
        neuen Passkey anlegen und neue Codes holen.
        """
        adresse = (email or "").strip().lower()
        if not adresse or not code:
            raise AngemeldetError(ABGELEHNT)
        if drossel.gesperrt(adresse):
            log.info("wiederherstellung gesperrt", email=_verkuerzt(adresse))
            raise AngemeldetError(ABGELEHNT)
        async with self.maker() as s:
            person = (
                await s.execute(select(m.Person).where(m.Person.email == adresse))
            ).scalar_one_or_none()
            rest = (
                wiederherstellung.einloesen(list(person.wiederherstellungscodes or []), code)
                if person is not None and person.aktiv
                else None
            )
            if person is None or rest is None:
                drossel.fehlversuch(adresse)
                log.info("wiederherstellung abgelehnt", email=_verkuerzt(adresse))
                raise AngemeldetError(ABGELEHNT)
            person.wiederherstellungscodes = rest
            angemeldet = await self._sitzung_anlegen(s, person, herkunft)
            await s.commit()
        drossel.vergessen(adresse)
        log.info("angemeldet", weg="wiederherstellung", person=angemeldet.ausweis.person_id)
        return angemeldet

    # ------------------------------------------------------------------ Pflege
    async def aufraeumen(self) -> tuple[int, int, int]:
        """Abgelaufene Sitzungen, Schritte und Links weg. Zurück: wie viele je Sorte."""
        async with self.maker() as s:
            sitzungen = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.PersonSitzung).where(m.PersonSitzung.laeuft_ab_am <= jetzt())
                ),
            )
            schritte = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.PasskeySchritt).where(m.PasskeySchritt.laeuft_ab_am <= jetzt())
                ),
            )
            links = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.Zugangstoken).where(
                        m.Zugangstoken.laeuft_ab_am <= jetzt(),
                        m.Zugangstoken.eingeloest_am.is_(None),
                    )
                ),
            )
            await s.commit()
        return (
            int(sitzungen.rowcount or 0),
            int(schritte.rowcount or 0),
            int(links.rowcount or 0),
        )


def _verkuerzt(email: str) -> str:
    """Eine Adresse für das Protokoll: erster Buchstabe und Domäne.

    Protokolle wandern in Fremdsysteme; die vollständige Adresse einer Person gehört nicht hinein.
    Zum Zuordnen genügt der Rest.
    """
    name, _, domaene = email.partition("@")
    return f"{name[:1]}…@{domaene}" if domaene else "(ohne Adresse)"
