"""FastAPI-Abhängigkeiten: Runtime-Zugriff und wer gerade fragt.

**Hier steht die Tür.** Bis zur Anmeldung mit Personen prüfte diese Datei ein einziges statisches
Token, und wer es hatte, durfte alles (ADR-8). Jetzt gibt es drei Wege herein, und sie stehen
nebeneinander, weil sie drei verschiedene Dinge sind (ADR-0002):

    Person   ein angemeldeter Mensch mit Passkey; Sitzungstoken, widerrufbar, Rolle an der Person
    Dienst   das API-Token: Bridge, Zeitplan, iOS-App, das BFF für Geräte- und Gastsitzungen
    offen    kein Token eingetragen - Entwicklung und Demo, wie bisher

Das Ermitteln passiert einmal je Anfrage in der Middleware (`main.zugang_und_urheber`) und liegt
danach in `request.state.ausweis`. Die Abhängigkeiten hier lesen nur noch nach - kein Endpunkt
schlägt selbst nach, wer fragt.
"""

from __future__ import annotations

import hmac
from dataclasses import replace

from fastapi import Request

from dch_api import urheber
from dch_api.application.runtime import Runtime
from dch_api.auth import rechte
from dch_api.auth.ausweis import DIENST, Ausweis
from dch_api.auth.dienst import AuthDienst
from dch_api.errors import DchError

#: Der Präfix, unter dem die Endpunkte hängen. Die Rechtematrix kennt die Pfade ohne ihn.
API_PREFIX = "/api/v1"


def get_runner(request: Request) -> Runtime:
    runtime: Runtime = request.app.state.runner
    return runtime


def get_auth(request: Request) -> AuthDienst | None:
    """Der Anmeldedienst - `None` im Demo-Modus, wo es keine Datenbank gibt."""
    dienst: AuthDienst | None = getattr(request.app.state, "auth", None)
    return dienst


def _bearer(request: Request) -> str:
    header = request.headers.get("authorization", "")
    return header[7:].strip() if header.lower().startswith("bearer ") else ""


async def ausweis_ermitteln(request: Request) -> Ausweis | None:
    """Wer stellt diese Anfrage? `None`, wenn kein brauchbarer Nachweis mitkam.

    **Das API-Token zuerst**, und zwar ohne Datenbank: die Bridge, die Wandanzeige und die
    iOS-App kommen so herein, viele Male je Minute. Erst wenn das Token nicht passt, wird ein
    Sitzungstoken nachgeschlagen - eine indizierte Abfrage, und genau die ist der Preis dafür,
    dass eine Sitzung sofort widerrufbar ist.
    """
    token = _bearer(request)
    if not token:
        return None
    erwartet: str = request.app.state.settings.api_token
    if erwartet and hmac.compare_digest(token, erwartet):
        # Das Token sagt nicht, wer davor sitzt. Das BFF schickt es für gepaarte Geräte und
        # Gastsitzungen mit und nennt den Urheber in Kopfzeilen - wie bisher.
        return _dienst_mit_kopfzeilen(request)
    auth = get_auth(request)
    if auth is None:
        return None
    return await auth.sitzung_aufloesen(token)


def _dienst_mit_kopfzeilen(request: Request) -> Ausweis:
    """Der Ausweis für das API-Token, angereichert um das, was das BFF über das Gerät sagt.

    Geglaubt wird die Angabe, weil hinter derselben Tür das Token steht: wer es hat, könnte jeden
    Urheber behaupten - er könnte aber ohnehin alles. Eine Zuordnung, keine Beweisführung
    (docs/URHEBER.md).

    Die **Rolle** aus der Kopfzeile wird dagegen durchgesetzt: so bleibt der Gastlink ein
    Gastlink, auch wenn eine Anfrage nicht über den Proxy des Dashboards kommt.
    """
    kopf = urheber.aus_kopfzeilen(request.headers)
    if kopf is None:
        return DIENST
    rolle = kopf.rolle if kopf.rolle in rechte.ROLLEN else ""
    if kopf.rolle == "owner":
        rolle = "hausherr"  # das alte Wort aus dem Kiosk-Cookie
    elif kopf.rolle == "guest":
        rolle = "gast"
    return Ausweis(
        art="gast" if rolle == "gast" else "geraet",
        rolle=rolle or "hausherr",  # type: ignore[arg-type]
        name=kopf.name,
        geraet=kopf.geraet or kopf.name,
    )


def urheber_der_anfrage(request: Request, ausweis: Ausweis | None) -> urheber.Urheber | None:
    """Wer ins Protokoll geschrieben wird.

    Bei einer Person kommt er aus dem Ausweis - mit Kennung, Namen und `art: person`, und das
    Gerät bleibt daneben, soweit die Anfrage es nennt. Bei allem anderen bleibt es bei den
    Kopfzeilen, die das BFF schickt: das ist der heutige Stand, und alte Zeilen behaupten nie
    eine Person.
    """
    if ausweis is not None and ausweis.ist_person:
        geraet = urheber.aus_kopfzeilen(request.headers)
        ueber = geraet.ueber if geraet is not None else ""
        # `replace` und nicht neu bauen: der Ausweis hat `slots=True` und kein __dict__, und
        # eine Aufzählung aller Felder wäre die Stelle, an der beim nächsten Feld eines fehlt.
        mit_geraet = (
            replace(ausweis, geraet=geraet.geraet)
            if geraet is not None and geraet.geraet
            else ausweis
        )
        return mit_geraet.als_urheber(ueber)
    return urheber.aus_kopfzeilen(request.headers)


def get_ausweis(request: Request) -> Ausweis:
    """Der Ausweis dieser Anfrage. Setzt voraus, dass `require_zugang` schon lief."""
    ausweis: Ausweis | None = getattr(request.state, "ausweis", None)
    return ausweis or DIENST


async def require_zugang(request: Request) -> Ausweis:
    """Die Tür: angemeldet sein und für diesen Pfad zuständig sein.

    Zwei Antworten, und sie sagen verschiedene Dinge: **401** heißt „ich weiß nicht, wer du bist"
    und lässt die Oberfläche zur Anmeldung umleiten; **403** heißt „ich weiß es, und du darfst
    das nicht" - dann hilft kein erneutes Anmelden.
    """
    settings = request.app.state.settings
    ausweis: Ausweis | None = getattr(request.state, "ausweis", None)
    if ausweis is None:
        if not settings.api_token:
            return DIENST  # Entwicklung/Demo ohne Token - unverändert offen
        raise DchError("unauthorized", "Nicht angemeldet.", 401)
    pfad = request.url.path.removeprefix(API_PREFIX)
    if not rechte.darf(ausweis.rolle, request.method, pfad):
        raise DchError("forbidden", _warum(ausweis.rolle, pfad), 403)
    return ausweis


def _warum(rolle: str, pfad: str) -> str:
    if rechte.ist_akte(pfad):
        return "Das sieht nur der Hausherr."
    if rolle == "gast":
        return "Gastzugang: nur Ansicht."
    return "Dafür fehlt die Berechtigung."


async def require_person(request: Request) -> Ausweis:
    """Für die eigenen Sachen: Passkeys, Sitzungen, Wiederherstellungscodes.

    Ein Gerät mit dem API-Token hat keine eigenen Passkeys - es ist keine Person. Darum hier ein
    eigener Wächter und nicht `require_zugang`.
    """
    ausweis = await require_zugang(request)
    if not ausweis.ist_person:
        raise DchError("forbidden", "Das geht nur als angemeldete Person.", 403)
    return ausweis


async def require_hausherr(request: Request) -> Ausweis:
    """Für die Personenverwaltung.

    Ein gepaartes Gerät mit Vollzugriff darf das auch: so kommt der Hausherr an die Verwaltung,
    bevor es die erste Person gibt (docs/ZUGANG.md, „Der erste Hausherr"). Das ist kein neues
    Vertrauen - wer das Kiosk-Token hat, durfte immer schon alles.
    """
    ausweis = await require_zugang(request)
    if ausweis.rolle != "hausherr":
        raise DchError("forbidden", "Das darf nur der Hausherr.", 403)
    return ausweis


async def auth_oder_fehler(request: Request) -> AuthDienst:
    """Der Anmeldedienst, oder eine klare Meldung statt eines Absturzes."""
    auth = get_auth(request)
    if auth is None:
        raise DchError(
            "unavailable",
            "Die Anmeldung braucht eine Datenbank; dieser Dienst läuft im Demo-Modus.",
            503,
        )
    return auth
