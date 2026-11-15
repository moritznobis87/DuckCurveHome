"""Die Technikseite der Wärmepumpe: alle Messwerte des Augenblicks in einer Antwort."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Body, Depends, Query

from dch_api.application import betrieb as betrieb_logic
from dch_api.application import kennlinie as kennlinie_logic
from dch_api.application import reglerkennzahl as kennzahl_logic
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.schemas import (
    BetriebOut,
    KennlinieOut,
    ReglerBestaetigenIn,
    ReglerEinstellungenOut,
    ReglerKennzahlenOut,
    ReglerStellenIn,
    ReglerStellenOut,
    WaermepumpeOut,
)

router = APIRouter(prefix="/waermepumpe", tags=["Anlage"])


@router.get("", response_model=WaermepumpeOut, summary="Die Wärmepumpe im Augenblick")
async def waermepumpe(runner: Annotated[Runtime, Depends(get_runner)]) -> WaermepumpeOut:
    """Außengerät, Kältekreis, Innengerät und Speicher, je mit Zeitpunkt und Güte des Werts,
    dazu Spreizung, Wärmeleistung und Arbeitszahl als Abschätzung."""
    return await runner.waermepumpe()


@router.get("/kennlinie", response_model=KennlinieOut, summary="Die gemessene Kennlinie")
async def kennlinie(
    runner: Annotated[Runtime, Depends(get_runner)],
    tage: Annotated[
        int,
        Query(ge=1, le=kennlinie_logic.TAGE_HOECHSTENS, description="Rückblick in Tagen"),
    ] = kennlinie_logic.TAGE_STANDARD,
) -> KennlinieOut:
    """Arbeitszahl über Außen- und Vorlauftemperatur: Messpunkte aus dem Heizbetrieb, die
    Ausgleichsfläche nach kleinsten Quadraten und die Kennlinie, mit der der Fahrplan rechnet."""
    return await runner.kennlinie(tage)


@router.get("/kennzahlen", response_model=ReglerKennzahlenOut, summary="Die Kennzahlen des Reglers")
async def kennzahlen(
    runner: Annotated[Runtime, Depends(get_runner)],
    tage: Annotated[
        int,
        Query(ge=1, le=kennzahl_logic.TAGE_HOECHSTENS, description="Rückblick in Tagen"),
    ] = kennzahl_logic.TAGE_STANDARD,
) -> ReglerKennzahlenOut:
    """Was die Wärmepumpe unter welcher Kennzahl ihres Reglers tat: Minuten, Lauf, Vorlauf,
    Sollwert, Erwärmung des Speichers oben und unten. Belege, keine Deutung."""
    return await runner.reglerkennzahlen(tage)


@router.get("/betrieb", response_model=BetriebOut, summary="Der Betrieb über Tage")
async def betrieb(
    runner: Annotated[Runtime, Depends(get_runner)],
    tage: Annotated[
        int,
        Query(ge=1, le=betrieb_logic.TAGE_HOECHSTENS, description="Rückblick in Tagen"),
    ] = betrieb_logic.TAGE_STANDARD,
) -> BetriebOut:
    """Läufe, Starts und Lauflängen, Abtauen, die Arbeitszahl je Tag mit und ohne Abtauen und
    die Heizkurve, die der Regler der Maschine vorgibt. Eine Auszählung gespeicherter Minuten."""
    return await runner.betrieb(tage)


@router.get(
    "/einstellungen",
    response_model=ReglerEinstellungenOut,
    summary="Die Einstellungen des Reglers",
)
async def einstellungen(runner: Annotated[Runtime, Depends(get_runner)]) -> ReglerEinstellungenOut:
    """Heizkurve, Raumtemperaturen und Warmwasser, wie sie am Regler eingestellt sind: über
    den Bus gelesen, je mit Zeitpunkt. Verstellt wird damit nichts."""
    return await runner.regler_einstellungen()


@router.post(
    "/einstellungen/{schluessel}",
    response_model=ReglerStellenOut,
    summary="Eine Einstellung des Reglers stellen",
)
async def einstellung_stellen(
    runner: Annotated[Runtime, Depends(get_runner)],
    schluessel: str,
    body: Annotated[ReglerStellenIn, Body()],
) -> ReglerStellenOut:
    """Eine Einstellung aus der festen Liste der stellbaren stellen. Abgelehnt wird, was nicht
    in der Liste steht, gerade nicht gelesen ist, nicht mit dem Bediengerät verglichen wurde,
    außerhalb der Grenzen liegt oder heute schon zu oft gestellt wurde; der Grund steht in der
    Antwort. Gestellt ist der Wert erst, wenn der Regler ihn zurückmeldet."""
    return await runner.regler_stellen(schluessel, body.wert)


@router.post(
    "/einstellungen/{schluessel}/bestaetigen",
    response_model=ReglerStellenOut,
    summary="Eine Einstellung als mit dem Bediengerät verglichen vermerken",
)
async def einstellung_bestaetigen(
    runner: Annotated[Runtime, Depends(get_runner)],
    schluessel: str,
    body: Annotated[ReglerBestaetigenIn, Body()],
) -> ReglerStellenOut:
    """Festhalten, dass die Zahl auf der Seite mit der am Bediengerät übereinstimmt (oder das
    zurücknehmen). Erst danach lässt sich die Einstellung stellen."""
    return await runner.regler_bestaetigen(schluessel, body.bestaetigt)
