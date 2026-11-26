"""Sonnenaufgang und Sonnenuntergang: gegen veröffentlichte Zeiten gehalten, nicht gegen sich selbst."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from hems_core.forecasting import GeoPoint, sonnenzeiten

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
