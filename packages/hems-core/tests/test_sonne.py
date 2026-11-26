"""Sonnenaufgang und Sonnenuntergang: gegen veröffentlichte Zeiten gehalten, nicht gegen sich selbst."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from hems_core.forecasting import GeoPoint, solar_elevation_deg, sonnenzeiten

BERLIN_ZEIT = ZoneInfo("Europe/Berlin")
BERLIN = GeoPoint(latitude=52.52, longitude=13.405)
FRANKFURT = GeoPoint(latitude=50.11, longitude=8.68)
TROMSOE = GeoPoint(latitude=69.65, longitude=18.96)

# Veröffentlichte Zeiten, auf die Minute. Berlin am 17.11.2026 nach alpenglowapp.com, Berlin am
# 1. und 30.11. nach weatherspark.com, Frankfurt nach sterngucker.de (frühester Untergang am
# 12.12., spätester Aufgang am 31.12.). Abgerufen am 26.11.2026.
VEROEFFENTLICHT = [
    (BERLIN, date(2026, 11, 17), "07:31", "16:10"),
    (BERLIN, date(2026, 11, 1), "07:02", "16:36"),
    (BERLIN, date(2026, 11, 30), "07:52", "15:56"),
    (FRANKFURT, date(2026, 12, 12), None, "16:22"),
    (FRANKFURT, date(2026, 12, 31), "08:24", None),
]


def _ortszeit(tag: date, hhmm: str) -> datetime:
    stunde, minute = (int(x) for x in hhmm.split(":"))
    return datetime(tag.year, tag.month, tag.day, stunde, minute, tzinfo=BERLIN_ZEIT)


@pytest.mark.parametrize(("ort", "tag", "auf", "unter"), VEROEFFENTLICHT)
def test_die_zeiten_stimmen_mit_veroeffentlichten_auf_die_minute(
    ort: GeoPoint, tag: date, auf: str | None, unter: str | None
) -> None:
    zeiten = sonnenzeiten(tag, ort)
    assert zeiten is not None
    for gerechnet, soll in ((zeiten.sunrise, auf), (zeiten.sunset, unter)):
        if soll is None:
            continue
        # Eine veröffentlichte Minute meint die ganze Minute: 07:31 ist 07:31:00 bis 07:31:59.
        beginn = _ortszeit(tag, soll)
        assert beginn <= gerechnet < beginn + timedelta(minutes=1), (soll, gerechnet)


def test_der_tag_gehoert_zum_ort_und_der_aufgang_liegt_vor_dem_untergang() -> None:
    tag = date(2026, 11, 26)
    zeiten = sonnenzeiten(tag, BERLIN)
    assert zeiten is not None
    assert zeiten.day == tag
    assert zeiten.sunrise < zeiten.sunset
    assert zeiten.sunrise.astimezone(BERLIN_ZEIT).date() == tag
    assert zeiten.sunset.astimezone(BERLIN_ZEIT).date() == tag


def test_im_sommer_ist_der_tag_laenger_als_im_winter() -> None:
    sommer = sonnenzeiten(date(2026, 6, 21), BERLIN)
    winter = sonnenzeiten(date(2026, 12, 21), BERLIN)
    assert sommer is not None and winter is not None
    assert sommer.sunset - sommer.sunrise > timedelta(hours=16)
    assert winter.sunset - winter.sunrise < timedelta(hours=8)


def test_ohne_aufgang_oder_untergang_gibt_es_keine_zeiten() -> None:
    # Tromsø: Polarnacht im Dezember, Mitternachtssonne im Juni.
    assert sonnenzeiten(date(2026, 12, 21), TROMSOE) is None
    assert sonnenzeiten(date(2026, 6, 21), TROMSOE) is None


# ---------------------------------------------------------------- Die Höhe der Sonne


def _hoechster_stand(tag: date, ort: GeoPoint) -> tuple[datetime, float]:
    """Zeitpunkt und Höhe des Sonnenmittags, minutenweise gesucht."""
    beginn = datetime(tag.year, tag.month, tag.day, tzinfo=BERLIN_ZEIT)
    minuten = (beginn + timedelta(minutes=m) for m in range(24 * 60))
    return max(
        ((t, solar_elevation_deg(t, ort.latitude, ort.longitude)) for t in minuten),
        key=lambda paar: paar[1],
    )


@pytest.mark.parametrize(
    ("tag", "deklination"),
    [(date(2026, 6, 21), 23.44), (date(2026, 12, 21), -23.44)],
)
def test_am_mittag_der_sonnenwenden_steht_die_sonne_so_hoch_wie_die_geometrie_es_verlangt(
    tag: date, deklination: float
) -> None:
    # Mittagshöhe = 90 Grad - Breite + Deklination; an den Sonnenwenden ist die Deklination die
    # Schiefe der Erdachse. Für Berlin sind das 60,92 und 14,04 Grad.
    _, hoehe = _hoechster_stand(tag, BERLIN)
    assert hoehe == pytest.approx(90.0 - BERLIN.latitude + deklination, abs=0.02)


def test_der_sonnenmittag_folgt_der_zeitgleichung() -> None:
    """Ende November geht die Sonne vor, Mitte Februar nach.

    Auf dem Längengrad von Berlin läge der Mittag ohne Zeitgleichung das ganze Jahr bei 12:06
    Uhr Winterzeit. Die Formel bis zum 26.11.2026 rechnete so und verschob damit die ganze
    erwartete Erzeugung: im November um knapp 13 Minuten nach hinten, im Februar um gut 14 nach
    vorn.
    """
    november, _ = _hoechster_stand(date(2026, 11, 26), BERLIN)
    februar, _ = _hoechster_stand(date(2026, 2, 11), BERLIN)
    assert (november.hour, november.minute) in {(11, 53), (11, 54)}
    assert (februar.hour, februar.minute) in {(12, 20), (12, 21)}


@pytest.mark.parametrize("tag", [date(2026, 2, 11), date(2026, 6, 21), date(2026, 11, 26)])
def test_bei_aufgang_und_untergang_steht_die_sonnenmitte_knapp_unter_dem_horizont(
    tag: date,
) -> None:
    # Beide Rechnungen müssen zusammenpassen: Aufgang ist, wenn der obere Rand erscheint, also
    # die Mitte 0,833 Grad unter dem Horizont steht.
    zeiten = sonnenzeiten(tag, BERLIN)
    assert zeiten is not None
    for zeit in (zeiten.sunrise, zeiten.sunset):
        hoehe = solar_elevation_deg(zeit, BERLIN.latitude, BERLIN.longitude)
        assert hoehe == pytest.approx(-0.833, abs=0.01)


def test_nachts_steht_die_sonne_unter_dem_horizont() -> None:
    mitternacht = datetime(2026, 11, 26, 0, 0, tzinfo=BERLIN_ZEIT)
    assert solar_elevation_deg(mitternacht, BERLIN.latitude, BERLIN.longitude) < -30
