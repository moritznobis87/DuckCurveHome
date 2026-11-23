"""Anmeldung, eigene Passkeys, Sitzungen und die Personenverwaltung (ADR-0002).

**Dieser Router hängt nicht an der allgemeinen Tür.** Die anderen Router bekommen in `main.py`
`Depends(require_zugang)` mitgegeben; hier wäre das ein Zirkel - wer sich anmelden will, ist noch
nicht angemeldet. Darum steht an jedem Endpunkt, was er verlangt:

    ohne           Anmeldung, Wiederherstellung, der Weg hinter dem Einladungslink, der Zustand
    require_person die eigenen Sachen: Passkeys, Sitzungen, Codes, Abmelden
    require_hausherr  die Personenverwaltung

Jede Ablehnung einer Anmeldung hat denselben Text. Welcher Grund zutraf, steht im Protokoll des
Dienstes und nicht in der Antwort.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Request

from dch_api import post
from dch_api.auth import dienst as auth_dienst
from dch_api.auth import passkeys
from dch_api.auth.ausweis import Ausweis
from dch_api.dependencies import (
    auth_oder_fehler,
    get_auth,
    require_hausherr,
    require_person,
    require_zugang,
)
from dch_api.errors import DchError
from dch_api.schemas import (
    AngemeldetOut,
    AnmeldenIn,
    AusweisOut,
    EinladenIn,
    EinladungOut,
    EinladungPersonOut,
    IchOut,
    NameIn,
    PasskeyAbschliessenIn,
    PasskeyBeginnenIn,
    PasskeyOut,
    PersonAendernIn,
    PersonAnlegenIn,
    PersonOut,
    SitzungOut,
    VersandOut,
    WiederherstellenIn,
    ZeremonieOut,
    ZugangZustandOut,
)

router = APIRouter(prefix="/auth", tags=["Zugang"])

#: Die beiden Wächter als Typ, wie im übrigen Dienst (`Annotated[..., Depends(...)]`).
Angemeldet = Annotated[Ausweis, Depends(require_zugang)]
AngemeldetePerson = Annotated[Ausweis, Depends(require_person)]
Hausherr = Annotated[Ausweis, Depends(require_hausherr)]

#: Was in `herkunft` einer Sitzung landet: der Browser oder die App, gekürzt. Kein
#: Sicherheitsmerkmal - es steht nur in der Sitzungsliste, damit „welches Gerät ist das?"
#: beantwortbar ist.
HERKUNFT_MAX = 120


def _herkunft(request: Request) -> str:
    return (request.headers.get("user-agent") or "")[:HERKUNFT_MAX]


def _ausweis_out(ausweis: Ausweis) -> AusweisOut:
    return AusweisOut(
        art=ausweis.art,
        rolle=ausweis.rolle,
        person_id=ausweis.person_id,
        name=ausweis.name,
        email=ausweis.email,
    )


def _angemeldet_out(angemeldet: auth_dienst.Angemeldet, codes: list[str]) -> AngemeldetOut:
    return AngemeldetOut(
        token=angemeldet.token,
        laeuft_ab_am=angemeldet.laeuft_ab_am,
        ausweis=_ausweis_out(angemeldet.ausweis),
        codes=codes,
    )


def _person_out(angaben: auth_dienst.PersonAngaben) -> PersonOut:
    return PersonOut(
        id=angaben.id,
        email=angaben.email,
        anzeigename=angaben.anzeigename,
        rolle=angaben.rolle,
        aktiv=angaben.aktiv,
        erstellt_am=angaben.erstellt_am,
        zuletzt_angemeldet_am=angaben.zuletzt_angemeldet_am,
        passkeys=angaben.passkeys,
        codes_offen=angaben.codes_offen,
        einladung_offen=angaben.einladung_offen,
    )


def _passkey_out(angaben: passkeys.Passkeyangaben) -> PasskeyOut:
    return PasskeyOut(
        id=angaben.id,
        name=angaben.name,
        gesichert=angaben.gesichert,
        erstellt_am=angaben.erstellt_am,
        zuletzt_benutzt_am=angaben.zuletzt_benutzt_am,
    )


def _versand_out(request: Request) -> VersandOut:
    settings = request.app.state.settings
    weg = post.versandweg(settings)
    return VersandOut(
        aktiv=post.aktiv(settings),
        weg=weg,
        fehlt=post.fehlende_angaben(settings),
    )


# ---------------------------------------------------------------------------
# Öffentlich: anmelden
# ---------------------------------------------------------------------------


@router.get("/zustand", response_model=ZugangZustandOut, summary="Ist eine Anmeldung nötig?")
async def zustand(request: Request) -> ZugangZustandOut:
    """Was die Anmeldeseite wissen muss, bevor jemand angemeldet ist.

    Wortkarg mit Absicht: `personen` ist eine Zahl, keine Liste. Dass es noch niemanden gibt, muss
    die Seite sagen können („Zugang über das gepaarte Gerät einrichten"); wer das wäre, braucht
    sie nicht.
    """
    auth = get_auth(request)
    return ZugangZustandOut(
        anmeldung=auth is not None,
        personen=await auth.anzahl() if auth is not None else 0,
        rp_id=request.app.state.settings.passkey_rp_id,
        versand=_versand_out(request),
    )


@router.get("/wer", response_model=AusweisOut, summary="Wer stellt diese Anfrage?")
async def wer(ausweis: Angemeldet) -> AusweisOut:
    """Die kleinste Auskunft: Art, Rolle, Name.

    Die Oberfläche fragt das alle zwei Minuten, um keine toten Knöpfe zu zeigen - darum eine
    eigene Antwort und nicht `/auth/ich`, das zusätzlich Passkeys und Sitzungen lädt. Sie
    beantwortet beide Wege herein: eine angemeldete Person ebenso wie ein gepaartes Gerät.
    """
    return _ausweis_out(ausweis)


@router.post(
    "/anmeldung/beginnen", response_model=ZeremonieOut, summary="Anmeldung mit Passkey beginnen"
)
async def anmeldung_beginnen(request: Request) -> ZeremonieOut:
    """Die Optionen für `navigator.credentials.get` - ohne E-Mail-Adresse.

    Der Browser bietet die Passkeys für diese Domain an (auffindbarer Passkey). Erst auf Klick und
    nicht beim Laden der Seite: jede Challenge ist eine Zeile in der Datenbank, und eine Seite,
    die beim blossen Aufruf eine anlegt, ließe sich von jedem Bot fluten.
    """
    auth = await auth_oder_fehler(request)
    zeremonie = await auth.anmeldung_beginnen()
    return ZeremonieOut(schritt=zeremonie.schritt, optionen=zeremonie.optionen)


@router.post(
    "/anmeldung/abschliessen", response_model=AngemeldetOut, summary="Mit Passkey anmelden"
)
async def anmeldung_abschliessen(request: Request, daten: AnmeldenIn) -> AngemeldetOut:
    auth = await auth_oder_fehler(request)
    try:
        angemeldet = await auth.anmelden(daten.schritt, daten.antwort, _herkunft(request))
    except auth_dienst.AngemeldetError as fehler:
        raise DchError("unauthorized", str(fehler), 401) from fehler
    return _angemeldet_out(angemeldet, [])


@router.post(
    "/wiederherstellung", response_model=AngemeldetOut, summary="Mit Wiederherstellungscode anmelden"
)
async def wiederherstellung(request: Request, daten: WiederherstellenIn) -> AngemeldetOut:
    """Der Weg, wenn alle Geräte weg sind. Der Code gilt einmal.

    Danach gehört der erste Griff in das Konto: einen neuen Passkey anlegen und neue Codes holen.
    """
    auth = await auth_oder_fehler(request)
    try:
        angemeldet = await auth.wiederherstellen(daten.email, daten.code, _herkunft(request))
    except auth_dienst.AngemeldetError as fehler:
        raise DchError("unauthorized", str(fehler), 401) from fehler
    return _angemeldet_out(angemeldet, [])


# ---------------------------------------------------------------------------
# Öffentlich: der Weg hinter dem Einladungslink
# ---------------------------------------------------------------------------


@router.get("/einladung", response_model=EinladungPersonOut, summary="Wem gehört dieser Link?")
async def einladung(request: Request, token: str = "") -> EinladungPersonOut:
    """Löst den Link nicht ein - das tut erst der fertige Passkey."""
    auth = await auth_oder_fehler(request)
    try:
        angaben = await auth.einladung_pruefen(token)
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid_token", str(fehler), 404) from fehler
    return EinladungPersonOut(
        email=angaben.email,
        anzeigename=angaben.anzeigename,
        rolle=angaben.rolle,
        passkeys=angaben.passkeys,
    )


@router.post(
    "/einladung/passkey/beginnen",
    response_model=ZeremonieOut,
    summary="Passkey über den Link anlegen: beginnen",
)
async def einladung_passkey_beginnen(request: Request, daten: PasskeyBeginnenIn) -> ZeremonieOut:
    auth = await auth_oder_fehler(request)
    try:
        zeremonie = await auth.registrierung_beginnen(zugangstoken=daten.token)
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid_token", str(fehler), 404) from fehler
    return ZeremonieOut(schritt=zeremonie.schritt, optionen=zeremonie.optionen)


@router.post(
    "/einladung/passkey/abschliessen",
    response_model=AngemeldetOut,
    summary="Passkey über den Link anlegen: abschließen",
)
async def einladung_passkey_abschliessen(
    request: Request, daten: PasskeyAbschliessenIn
) -> AngemeldetOut:
    """Legt den Passkey an, löst den Link ein und meldet an.

    **Jeder eingelöste Link bringt zehn frische Wiederherstellungscodes** und entwertet die alten.
    Das ist Absicht: der Link ist nicht nur die Einladung, sondern auch der Rückweg, und wer ihn
    gebraucht hat, muss davon ausgehen, dass die alten Codes nichts mehr wert sind. Sie gehen
    **einmal** im Klartext hinaus, hier; danach liegen nur ihre Hashes.
    """
    auth = await auth_oder_fehler(request)
    try:
        ergebnis = await auth.passkey_anlegen(
            schritt=daten.schritt,
            antwort=daten.antwort,
            name=daten.name,
            zugangstoken=daten.token,
            herkunft=_herkunft(request),
        )
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid_token", str(fehler), 404) from fehler
    except passkeys.PasskeyError as fehler:
        raise DchError("passkey", str(fehler), 400) from fehler
    if not isinstance(ergebnis, auth_dienst.Angemeldet):  # pragma: no cover - Weg ohne Link
        raise DchError("passkey", "Unerwartete Antwort.", 500)
    codes = await auth.codes_neu(ergebnis.ausweis.person_id)
    return _angemeldet_out(ergebnis, codes)


# ---------------------------------------------------------------------------
# Angemeldet: die eigenen Sachen
# ---------------------------------------------------------------------------


@router.get("/ich", response_model=IchOut, summary="Wer bin ich, und welche Geräte habe ich?")
async def ich(request: Request, ausweis: AngemeldetePerson) -> IchOut:
    auth = await auth_oder_fehler(request)
    angaben = await auth.person(ausweis.person_id)
    return IchOut(
        ausweis=_ausweis_out(ausweis),
        passkeys=[_passkey_out(p) for p in await auth.passkeys_der_person(ausweis.person_id)],
        sitzungen=[
            SitzungOut(
                id=s.id,
                erstellt_am=s.erstellt_am,
                laeuft_ab_am=s.laeuft_ab_am,
                zuletzt_benutzt_am=s.zuletzt_benutzt_am,
                herkunft=s.herkunft,
                diese=s.diese,
            )
            for s in await auth.sitzungen(ausweis.person_id, ausweis.sitzung_id)
        ],
        codes_offen=angaben.codes_offen,
    )


@router.post("/abmelden", summary="Diese Sitzung beenden")
async def abmelden(request: Request, ausweis: AngemeldetePerson) -> dict[str, bool]:
    """Beendet die Sitzung, mit der gefragt wird. Das BFF löscht danach sein Cookie."""
    auth = await auth_oder_fehler(request)
    return {"ok": await auth.sitzung_beenden(ausweis.person_id, ausweis.sitzung_id)}


@router.post("/sitzungen/{sitzung_id}/beenden", summary="Ein anderes Gerät abmelden")
async def sitzung_beenden(
    request: Request, sitzung_id: str, ausweis: AngemeldetePerson
) -> dict[str, bool]:
    auth = await auth_oder_fehler(request)
    return {"ok": await auth.sitzung_beenden(ausweis.person_id, sitzung_id)}


@router.post("/sitzungen/beenden-alle", summary="Überall abmelden")
async def alle_sitzungen_beenden(
    request: Request, ausweis: AngemeldetePerson
) -> dict[str, int]:
    """Der Griff für den Verdachtsfall: alle Sitzungen dieser Person enden, auch die eigene."""
    auth = await auth_oder_fehler(request)
    return {"beendet": await auth.alle_sitzungen_beenden(ausweis.person_id)}


@router.post("/passkeys/beginnen", response_model=ZeremonieOut, summary="Passkey anlegen: beginnen")
async def passkey_beginnen(
    request: Request, ausweis: AngemeldetePerson
) -> ZeremonieOut:
    auth = await auth_oder_fehler(request)
    zeremonie = await auth.registrierung_beginnen(person_id=ausweis.person_id)
    return ZeremonieOut(schritt=zeremonie.schritt, optionen=zeremonie.optionen)


@router.post(
    "/passkeys/abschliessen", response_model=PasskeyOut, summary="Passkey anlegen: abschließen"
)
async def passkey_abschliessen(
    request: Request, daten: PasskeyAbschliessenIn, ausweis: AngemeldetePerson
) -> PasskeyOut:
    auth = await auth_oder_fehler(request)
    try:
        ergebnis = await auth.passkey_anlegen(
            schritt=daten.schritt,
            antwort=daten.antwort,
            name=daten.name,
            person_id=ausweis.person_id,
        )
    except passkeys.PasskeyError as fehler:
        raise DchError("passkey", str(fehler), 400) from fehler
    if isinstance(ergebnis, auth_dienst.Angemeldet):  # pragma: no cover - Weg über den Link
        raise DchError("passkey", "Unerwartete Antwort.", 500)
    return _passkey_out(ergebnis)


@router.post("/passkeys/{passkey_id}/name", summary="Passkey umbenennen")
async def passkey_umbenennen(
    request: Request,
    passkey_id: str,
    daten: NameIn,
    ausweis: AngemeldetePerson,
) -> dict[str, bool]:
    auth = await auth_oder_fehler(request)
    try:
        await auth.passkey_umbenennen(ausweis.person_id, passkey_id, daten.name)
    except passkeys.PasskeyError as fehler:
        raise DchError("passkey", str(fehler), 404) from fehler
    return {"ok": True}


@router.post("/passkeys/{passkey_id}/loeschen", summary="Passkey löschen")
async def passkey_loeschen(
    request: Request, passkey_id: str, ausweis: AngemeldetePerson
) -> dict[str, bool]:
    """Der letzte Passkey bleibt: sonst käme diese Person nur noch über einen Code oder einen
    Link des Hausherrn herein."""
    auth = await auth_oder_fehler(request)
    try:
        await auth.passkey_loeschen(ausweis.person_id, passkey_id)
    except passkeys.LetzterPasskeyError as fehler:
        raise DchError("letzter_passkey", str(fehler), 409) from fehler
    except passkeys.PasskeyError as fehler:
        raise DchError("passkey", str(fehler), 404) from fehler
    return {"ok": True}


@router.post("/codes", summary="Neue Wiederherstellungscodes")
async def codes(request: Request, ausweis: AngemeldetePerson) -> dict[str, object]:
    """Zehn neue Codes; die alten gelten nicht mehr. Klartext nur hier, einmal."""
    auth = await auth_oder_fehler(request)
    return {"codes": await auth.codes_neu(ausweis.person_id)}


# ---------------------------------------------------------------------------
# Hausherr: Personenverwaltung
# ---------------------------------------------------------------------------


@router.get("/personen", response_model=list[PersonOut], summary="Wer Zugang hat")
async def personen(
    request: Request, _: Hausherr
) -> list[PersonOut]:
    auth = await auth_oder_fehler(request)
    return [_person_out(p) for p in await auth.personen()]


@router.post("/personen", response_model=EinladungOut, summary="Person anlegen und einladen")
async def person_anlegen(
    request: Request, daten: PersonAnlegenIn, _: Hausherr
) -> EinladungOut:
    """Legt die Person an und gibt den Einladungslink zurück - immer, auch wenn die E-Mail
    hinausging. Der Versand ist eine Beigabe: schlägt er fehl, ist die Person trotzdem angelegt
    und der Link bleibt kopierbar (`dch_api/post.py`)."""
    auth = await auth_oder_fehler(request)
    try:
        angaben, klartext = await auth.person_anlegen(daten.email, daten.anzeigename, daten.rolle)
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid", str(fehler), 400) from fehler
    verschickt = False
    if daten.einladen:
        verschickt = await post.verschicken(
            request.app.state.settings,
            angaben.email,
            angaben.anzeigename,
            auth.link(klartext),
            "einladung",
        )
    return EinladungOut(
        person=_person_out(angaben),
        link=auth.link(klartext),
        laeuft_ab_am=auth_dienst.jetzt()
        + timedelta(hours=request.app.state.settings.zugangstoken_stunden),
        verschickt=verschickt,
    )


@router.post("/personen/{person_id}", response_model=PersonOut, summary="Rolle oder Zustand ändern")
async def person_aendern(
    request: Request,
    person_id: str,
    daten: PersonAendernIn,
    _: Hausherr,
) -> PersonOut:
    auth = await auth_oder_fehler(request)
    try:
        angaben = await auth.person_aendern(
            person_id, rolle=daten.rolle, aktiv=daten.aktiv, anzeigename=daten.anzeigename
        )
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid", str(fehler), 400) from fehler
    return _person_out(angaben)


@router.post(
    "/personen/{person_id}/einladen", response_model=EinladungOut, summary="Neuen Link ausstellen"
)
async def person_einladen(
    request: Request,
    person_id: str,
    _: Hausherr,
    daten: EinladenIn | None = None,
) -> EinladungOut:
    """Ein neuer Link - für „Einladung kam nicht an" und für „alle Geräte verloren".

    Der alte Link wird dabei entwertet: zwei gültige Links für dieselbe Person sind einer zu viel.
    """
    auth = await auth_oder_fehler(request)
    try:
        klartext, _adresse = await auth.einladen(person_id, "einladung")
        angaben = await auth.person(person_id)
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid", str(fehler), 400) from fehler
    verschickt = False
    if daten is None or daten.einladen:
        verschickt = await post.verschicken(
            request.app.state.settings,
            angaben.email,
            angaben.anzeigename,
            auth.link(klartext),
            "einladung",
        )
    return EinladungOut(
        person=_person_out(angaben),
        link=auth.link(klartext),
        laeuft_ab_am=auth_dienst.jetzt()
        + timedelta(hours=request.app.state.settings.zugangstoken_stunden),
        verschickt=verschickt,
    )


@router.post("/personen/{person_id}/loeschen", summary="Person löschen")
async def person_loeschen(
    request: Request, person_id: str, _: Hausherr
) -> dict[str, bool]:
    """Löscht die Person samt Passkeys, Sitzungen und offenen Links. Der letzte aktive Hausherr
    bleibt - sonst sperrt sich das Haus selbst aus."""
    auth = await auth_oder_fehler(request)
    try:
        await auth.person_loeschen(person_id)
    except auth_dienst.ZugangError as fehler:
        raise DchError("invalid", str(fehler), 400) from fehler
    return {"ok": True}
