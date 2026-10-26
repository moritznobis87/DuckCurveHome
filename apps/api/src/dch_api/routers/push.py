"""Mitteilungen: Schlüssel holen, Gerät anmelden, Gerät abmelden, Probe senden."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from dch_api.application.push import Mitteilung, PushService
from dch_api.schemas import PushKeyOut, PushResultOut, PushSubscribeIn, PushUnsubscribeIn

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
    await push.subscribe(body.endpoint, body.p256dh, body.auth, body.label)
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
    erreicht = await push.send(
        Mitteilung(
            title="Duck Curve Home",
            body="Probe: Mitteilungen kommen an.",
            tag="probe",
            url="/",
        )
    )
    gesamt = await push.count()
    return PushResultOut(
        ok=erreicht > 0,
        devices=gesamt,
        message_de=f"Probe an {erreicht} von {gesamt} Geräten zugestellt."
        if gesamt
        else "Kein Gerät angemeldet.",
    )
