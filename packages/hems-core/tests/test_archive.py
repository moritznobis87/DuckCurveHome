"""Was ein Prognoselauf ist, und welcher für immer bleibt.

Der Fingerabdruck trägt die Last: er unterscheidet einen neuen Lauf von einer Wiederholung, und
wenn er die Erstellungszeit mitzählte, wäre jeder Abruf neu und die Tabelle liefe mit nahezu
gleichen Preisläufen voll.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from hems_core.forecasting.archive import (
    PREIS,
    PV,
    WETTER,
    WETTER_GROESSEN,
    Punkt,
    fingerabdruck,
    kanonisch,
    preis_lauf,
    pv_lauf,
    wetter_lauf,
)
from hems_core.forecasting.models import (
    GeoPoint,
    PvForecast,
    PvPoint,
    WeatherForecast,
    WeatherPoint,
)
from hems_core.planning import PricePoint

BERLIN = ZoneInfo("Europe/Berlin")
T0 = datetime(2026, 11, 7, 6, 0, tzinfo=UTC)


def punkt(stunde: int = 0, wert: float = 1.0, variable: str = "temp_c") -> Punkt:
    return Punkt(ts=T0 + timedelta(hours=stunde), variable=variable, wert=wert)


# ------------------------------------------------------------------ Fingerabdruck


def test_die_erstellungszeit_zaehlt_nicht_zum_fingerabdruck() -> None:
    """Sonst wäre jeder Abruf ein neuer Lauf und der Wiederholungsfilter wirkungslos."""
    assert fingerabdruck([punkt()]) == fingerabdruck([punkt()])


def test_ein_geaenderter_wert_zaehlt_sehr_wohl() -> None:
    assert fingerabdruck([punkt(wert=1.0)]) != fingerabdruck([punkt(wert=1.1)])


def test_der_fingerabdruck_haengt_nicht_an_der_reihenfolge() -> None:
    a = [punkt(0), punkt(1), punkt(2)]
    assert fingerabdruck(a) == fingerabdruck(list(reversed(a)))


def test_eine_aenderung_jenseits_der_rundung_zaehlt_nicht() -> None:
    """Das letzte Bit einer Gleitkommazahl ist keine neue Prognose."""
    assert fingerabdruck([punkt(wert=1.0)]) == fingerabdruck([punkt(wert=1.000001)])


def test_ein_geaendertes_band_zaehlt() -> None:
    a = Punkt(ts=T0, variable="ac_kw", wert=2.0, lo=1.4, hi=2.5)
    b = Punkt(ts=T0, variable="ac_kw", wert=2.0, lo=1.2, hi=2.5)
    assert fingerabdruck([a]) != fingerabdruck([b])


def test_ein_fehlender_wert_bricht_den_fingerabdruck_nicht() -> None:
    """Sortiert wird nach Zeit und Name; ein Vergleich der Werte selbst scheiterte an None."""
    a = Punkt(ts=T0, variable="temp_c", wert=None)
    b = Punkt(ts=T0, variable="cloud_cover", wert=None)
    assert fingerabdruck([a, b]) == fingerabdruck([b, a])


def test_verschiedene_reihen_zur_selben_zeit_sind_verschieden() -> None:
    a = punkt(variable="temp_c", wert=3.0)
    b = punkt(variable="cloud_cover", wert=3.0)
    assert fingerabdruck([a]) != fingerabdruck([b])


# ------------------------------------------------------------------ Wetter


def wetter(
    *, temp: float | None = 4.0, wolken: float | None = 0.3, ghi: float | None = 120.0
) -> WeatherForecast:
    return WeatherForecast(
        provider="open_meteo",
        issued_at=T0,
        location=GeoPoint(latitude=50.97, longitude=6.12),
        resolution_min=60,
        points=[
            WeatherPoint(ts=T0, temp_c=temp, cloud_cover=wolken, ghi_w_m2=ghi),
            WeatherPoint(ts=T0 + timedelta(hours=1), temp_c=temp, cloud_cover=wolken, ghi_w_m2=ghi),
        ],
    )


def test_der_wetterlauf_nimmt_genau_die_erklaerten_groessen() -> None:
    lauf = wetter_lauf(wetter())
    assert lauf is not None
    assert lauf.art == WETTER
    assert {p.variable for p in lauf.punkte} == set(WETTER_GROESSEN)


def test_der_wetterlauf_spannt_den_horizont_ueber_alle_punkte() -> None:
    lauf = wetter_lauf(wetter())
    assert lauf is not None
    assert lauf.von == T0
    assert lauf.bis == T0 + timedelta(hours=1)
    assert lauf.schritt_min == 60


def test_fehlende_groessen_werden_weggelassen_und_nicht_als_null_abgelegt() -> None:
    """Eine Reihe, die der Anbieter nicht liefert, soll nicht als Reihe aus Nullen erscheinen."""
    lauf = wetter_lauf(wetter(ghi=None))
    assert lauf is not None
    assert "ghi_w_m2" not in {p.variable for p in lauf.punkte}


def test_eine_prognose_ohne_punkte_ist_kein_lauf() -> None:
    leer = WeatherForecast(
        provider="open_meteo",
        issued_at=T0,
        location=GeoPoint(latitude=50.97, longitude=6.12),
        resolution_min=60,
        points=[],
    )
    assert wetter_lauf(leer) is None
    assert wetter_lauf(None) is None


def test_eine_prognose_ohne_jeden_wert_ist_kein_lauf() -> None:
    assert wetter_lauf(wetter(temp=None, wolken=None, ghi=None)) is None


# ------------------------------------------------------------------ PV


def test_der_pv_lauf_traegt_das_band_mit() -> None:
    lauf = pv_lauf(
        PvForecast(
            provider="simple_clear_sky_v1",
            issued_at=T0,
            resolution_min=15,
            points=[PvPoint(ts=T0, ac_kw=2.0, ac_kw_lo=1.4, ac_kw_hi=2.5)],
        )
    )
    assert lauf is not None
    assert lauf.art == PV
    assert lauf.schritt_min == 15
    assert lauf.punkte[0].lo == 1.4
    assert lauf.punkte[0].hi == 2.5


def test_eine_pv_prognose_ohne_punkte_ist_kein_lauf() -> None:
    assert pv_lauf(None) is None
    assert pv_lauf(PvForecast(provider="x", issued_at=T0, resolution_min=15, points=[])) is None


# ------------------------------------------------------------------ Preis


def preise(schritt_min: int = 60, anzahl: int = 3) -> list[PricePoint]:
    schritt = timedelta(minutes=schritt_min)
    return [
        PricePoint(start=T0 + schritt * i, end=T0 + schritt * (i + 1), ct_kwh=20.0 + i)
        for i in range(anzahl)
    ]


def test_der_preislauf_leitet_das_raster_aus_der_dauer_eines_punktes_ab() -> None:
    """Tibber liefert je nach Schema Stunden oder Viertelstunden; beides soll richtig vermerkt sein."""
    stunden = preis_lauf(preise(60), T0, "tibber")
    viertel = preis_lauf(preise(15), T0, "tibber")
    assert stunden is not None and viertel is not None
    assert stunden.schritt_min == 60
    assert viertel.schritt_min == 15


def test_der_preislauf_spannt_bis_zum_ende_des_letzten_punktes() -> None:
    lauf = preis_lauf(preise(60, 3), T0, "tibber")
    assert lauf is not None
    assert lauf.art == PREIS
    assert lauf.von == T0
    assert lauf.bis == T0 + timedelta(hours=3)


def test_der_preislauf_sortiert_eine_verdrehte_liste() -> None:
    verdreht = list(reversed(preise(60, 3)))
    lauf = preis_lauf(verdreht, T0, "tibber")
    assert lauf is not None
    assert lauf.von == T0
    assert [p.ts for p in lauf.punkte] == sorted(p.ts for p in lauf.punkte)


def test_eine_leere_preisliste_ist_kein_lauf() -> None:
    assert preis_lauf([], T0, "tibber") is None


# ------------------------------------------------------------------ Kanonischer Lauf


def test_kanonisch_ist_der_letzte_lauf_vor_der_stunde() -> None:
    tag = date(2026, 11, 7)
    laeufe = [
        ("a", datetime(2026, 11, 7, 3, 0, tzinfo=BERLIN)),
        ("b", datetime(2026, 11, 7, 5, 45, tzinfo=BERLIN)),
        ("c", datetime(2026, 11, 7, 6, 15, tzinfo=BERLIN)),
    ]
    assert kanonisch(laeufe, tag, 6, BERLIN) == "b"


def test_ein_lauf_genau_zur_stunde_gilt_noch() -> None:
    tag = date(2026, 11, 7)
    laeufe = [
        ("a", datetime(2026, 11, 7, 5, 0, tzinfo=BERLIN)),
        ("b", datetime(2026, 11, 7, 6, 0, tzinfo=BERLIN)),
    ]
    assert kanonisch(laeufe, tag, 6, BERLIN) == "b"


def test_ohne_lauf_vor_der_stunde_bleibt_der_frueheste_des_tages() -> None:
    """Sonst behielte ein Tag, an dem der Dienst spaeter startete, fuer immer nichts."""
    tag = date(2026, 11, 7)
    laeufe = [
        ("spaet", datetime(2026, 11, 7, 14, 0, tzinfo=BERLIN)),
        ("frueh", datetime(2026, 11, 7, 10, 0, tzinfo=BERLIN)),
    ]
    assert kanonisch(laeufe, tag, 6, BERLIN) == "frueh"


def test_gezaehlt_wird_der_ortstag_und_nicht_der_utc_tag() -> None:
    """23:30 UTC ist im Winter in Berlin schon der naechste Tag, und die Wertung rechnet oertlich."""
    laeufe = [("nacht", datetime(2026, 11, 6, 23, 30, tzinfo=UTC))]
    assert kanonisch(laeufe, date(2026, 11, 6), 6, BERLIN) is None
    assert kanonisch(laeufe, date(2026, 11, 7), 6, BERLIN) == "nacht"


def test_ein_tag_ohne_lauf_hat_keinen_kanonischen() -> None:
    laeufe = [("a", datetime(2026, 11, 7, 5, 0, tzinfo=BERLIN))]
    assert kanonisch(laeufe, date(2026, 11, 8), 6, BERLIN) is None
    assert kanonisch([], date(2026, 11, 7), 6, BERLIN) is None
