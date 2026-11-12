"""Mitteilungen: Schlüssel holen, Gerät anmelden, Gerät abmelden, Probe senden, Geräte ansehen."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from dch_api.application.push import Mitteilung, PushService, Zustellung
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import (
    MorgenbriefIn,
    MorgenbriefOut,
    PushGeraeteOut,
    PushGeraetOut,
    PushKeyOut,
    PushResultOut,
    PushSubscribeIn,
    PushUnsubscribeIn,
)

router = APIRouter(prefix="/push", tags=["System"])


def get_push(request: Request) -> PushService:
    push: PushService = request.app.state.push
    return push


@router.get("/key", response_model=PushKeyOut, summary="Öffentlicher Schlüssel für Mitteilungen")
async def key(push: Annotated[PushService, Depends(get_push)]) -> PushKeyOut:
    return PushKeyOut(public_key=await push.public_key(), devices=await push.count())


@router.post("/subscribe", response_model=PushResultOut, summary="Dieses Gerät anmelden")
async def subscribe(
    body: PushSubscribeIn, push: Annotated[PushService, Depends(get_push)]
) -> PushResultOut:
    await push.subscribe(body.endpoint, body.p256dh, body.auth, body.label, body.origin)
    return PushResultOut(
        ok=True, devices=await push.count(), message_de="Dieses Gerät bekommt jetzt Mitteilungen."
    )


@router.post("/unsubscribe", response_model=PushResultOut, summary="Dieses Gerät abmelden")
async def unsubscribe(
    body: PushUnsubscribeIn, push: Annotated[PushService, Depends(get_push)]
) -> PushResultOut:
    weg = await push.unsubscribe(body.endpoint)
    return PushResultOut(
        ok=weg,
        devices=await push.count(),
        message_de="Dieses Gerät bekommt keine Mitteilungen mehr."
        if weg
        else "Dieses Gerät war nicht angemeldet.",
    )


@router.post("/test", response_model=PushResultOut, summary="Probemitteilung senden")
async def test(push: Annotated[PushService, Depends(get_push)]) -> PushResultOut:
    """Eine Probe an alle angemeldeten Geräte.

    Der Weg hat viele Glieder - Browser, Push-Dienst, Schlüssel, Service Worker -, und jedes kann
    still versagen. Ohne eine Probe merkt man das erst, wenn die erste echte Meldung ausbleibt,
    also genau dann, wenn sie gebraucht wird.
    """
    bericht = await push.send_bericht(
        Mitteilung(
            title="Duck Curve Home",
            body="Probe: Mitteilungen kommen an.",
            tag="probe",
            url="/",
        )
    )
    return _ergebnis("Die Probe", bericht, await push.count())


def _ergebnis(was: str, bericht: list[Zustellung], jetzt_angemeldet: int) -> PushResultOut:
    """Aus dem Bericht je Gerät die Antwort für die Seite: ein Satz und der Grund je Gerät.

    „Angenommen" heißt: Der Push-Dienst von Apple, Google oder Mozilla hat die Mitteilung
    entgegengenommen. Ob das Gerät sie zeigt, entscheidet es selbst (Fokus, Nicht stören,
    Mitteilungen für die App abgeschaltet); das sieht der Dienst nicht, und so steht es da.
    """
    if not bericht:
        return PushResultOut(
            ok=False,
            devices=jetzt_angemeldet,
            message_de="Kein Gerät ist für Mitteilungen angemeldet.",
        )
    erreicht = sum(1 for z in bericht if z.ok)
    wort = "1 Gerät" if len(bericht) == 1 else f"{len(bericht)} Geräte"
    return PushResultOut(
        ok=erreicht > 0,
        devices=jetzt_angemeldet,
        message_de=f"{was} ging an {wort}; der Push-Dienst hat {erreicht} davon angenommen.",
        details_de=[z.satz_de for z in bericht],
    )


@router.get(
    "/geraete", response_model=PushGeraeteOut, summary="Die angemeldeten Geräte und ihr Stand"
)
async def geraete(push: Annotated[PushService, Depends(get_push)]) -> PushGeraeteOut:
    """Welche Geräte angemeldet sind, wann zuletzt eine Mitteilung angenommen wurde und woran
    die letzte gescheitert ist. Die Adresse des Geräts beim Push-Dienst bleibt im Dienst; die
    Seite braucht sie nicht."""
    return PushGeraeteOut(
        devices=[
            PushGeraetOut(
                label=str(getattr(abo, "label", "") or "Gerät"),
                seit=getattr(abo, "created_at", None),
                zuletzt_ok=getattr(abo, "last_ok_at", None),
                fehlversuche=int(getattr(abo, "failures", 0) or 0),
                letzter_fehler_de=fehler,
            )
            for abo, fehler in await push.geraete()
        ]
    )


@router.get(
    "/morgenbrief",
    response_model=MorgenbriefOut,
    summary="Der Morgenbrief: ob er kommt und was heute darin stünde",
)
async def morgenbrief(
    runner: Annotated[Runtime, Depends(get_runner)],
    push: Annotated[PushService, Depends(get_push)],
) -> MorgenbriefOut:
    stand = await runner.morgenbrief()
    return stand.model_copy(update={"geraete": await push.count()})


@router.put(
    "/morgenbrief", response_model=MorgenbriefOut, summary="Den Morgenbrief ein- oder ausschalten"
)
async def set_morgenbrief(
    body: MorgenbriefIn,
    runner: Annotated[Runtime, Depends(get_runner)],
    push: Annotated[PushService, Depends(get_push)],
) -> MorgenbriefOut:
    stand = await runner.set_morgenbrief(body.enabled)
    return stand.model_copy(update={"geraete": await push.count()})


@router.post(
    "/morgenbrief/senden", response_model=PushResultOut, summary="Den Morgenbrief jetzt senden"
)
async def morgenbrief_senden(
    runner: Annotated[Runtime, Depends(get_runner)],
    push: Annotated[PushService, Depends(get_push)],
) -> PushResultOut:
    """Den Brief von heute sofort an alle angemeldeten Geräte schicken.

    Zum Ansehen, wie er auf dem eigenen Telefon aussieht, ohne bis morgen früh zu warten. Der
    Versand am Morgen bleibt davon unberührt.
    """
    stand = await runner.morgenbrief()
    geraete = await push.count()
    if not stand.zeilen or stand.titel is None:
        return PushResultOut(ok=False, devices=geraete, message_de=stand.hinweis_de)
    bericht = await push.send_bericht(
        Mitteilung(title=stand.titel, body="\n".join(stand.zeilen), tag="morgenbrief", url="/")
    )
    return _ergebnis("Der Brief", bericht, await push.count())
