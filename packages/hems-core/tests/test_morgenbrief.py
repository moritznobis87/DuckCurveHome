from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from hems_core.planning.morgenbrief import SCHRITT, Viertel, morgenbrief

BERLIN = ZoneInfo("Europe/Berlin")
#: Sieben Uhr morgens im Haus, an einem Wintertag (UTC+1).
SIEBEN = datetime(2026, 11, 11, 6, 0, tzinfo=UTC)


def tag(
    *,
    preis: Callable[[float], float | None] = lambda h: 30.0,
    pv: Callable[[float], float] = lambda h: 0.0,
    wp: Callable[[float], bool] = lambda h: False,
    ab: datetime = SIEBEN,
    stunden: int = 30,
) -> list[Viertel]:
    """Viertelstunden ab `ab`. Die Funktionen bekommen die Ortsstunde als Kommazahl."""
    out = []
    for i in range(stunden * 4):
        ts = ab + i * SCHRITT
        lokal = ts.astimezone(BERLIN)
        h = (
            lokal.hour
            + lokal.minute / 60
            + (24 if lokal.date() > ab.astimezone(BERLIN).date() else 0)
        )
        out.append(Viertel(ts=ts, preis_ct=preis(h), pv_kw=pv(h), wp=wp(h)))
    return out


def brief(**kw: object) -> list[str]:
    b = morgenbrief(tag(**kw), jetzt=SIEBEN, tz=BERLIN)  # type: ignore[arg-type]
    assert b is not None
    assert b.titel == "Heute im Haus"
    return list(b.zeilen)


def test_ein_sonniger_tag_nennt_menge_und_beste_zeit() -> None:
    zeilen = brief(pv=lambda h: max(0.0, 3.0 - abs(h - 12.5) * 0.8))
    assert zeilen[0].startswith("Sonne: rund ")
    assert "kWh erwartet, am meisten von 11:30 bis 13:30." in zeilen[0]


def test_ein_trueber_tag_sagt_kaum_sonne_und_nennt_kein_fenster() -> None:
    assert brief(pv=lambda h: 0.2 if 11 <= h < 14 else 0.0)[0] == (
        "Sonne: heute kaum etwas zu erwarten."
    )
    # Genug Energie über den Tag, aber nie ein Kilowatt: Menge ja, Fenster nein.
    flach = brief(pv=lambda h: 0.6 if 9 <= h < 16 else 0.0)[0]
    assert flach == "Sonne: rund 4 kWh erwartet."


def test_der_preis_nennt_die_guenstigsten_zwei_stunden_und_den_teuersten_moment() -> None:
    zeilen = brief(preis=lambda h: 18.0 if 13 <= h < 15 else 47.0 if 18 <= h < 19 else 30.0)
    assert zeilen[1] == (
        "Strom: am günstigsten von 13:00 bis 15:00 (rund 18 ct), am teuersten um 18:00 (47 ct)."
    )


def test_bei_fast_gleichem_preis_gibt_es_kein_fenster() -> None:
    # Zwischen 30 und knapp 32 ct, im Mittel knapp 31: zu wenig Unterschied für ein Fenster.
    assert brief(preis=lambda h: 30.0 + (h % 2))[1] == (
        "Strom: der Preis bleibt heute nahezu gleich, um 31 ct."
    )


def test_ohne_preise_fehlt_die_zeile_und_nichts_wird_geraten() -> None:
    zeilen = brief(preis=lambda h: None)
    assert not any(z.startswith("Strom") for z in zeilen)


def test_die_waermepumpe_nennt_ihre_laeufe_mit_einzahl_und_aufzaehlung() -> None:
    assert brief()[-1] == "Wärmepumpe: heute kein Lauf geplant."
    assert brief(wp=lambda h: 12 <= h < 14.5)[-1] == "Wärmepumpe: geplant von 12:00 bis 14:30."
    zwei = brief(wp=lambda h: 8 <= h < 9 or 12 <= h < 14)[-1]
    assert zwei == "Wärmepumpe: geplant von 08:00 bis 09:00 und 12:00 bis 14:00."
    viele = brief(wp=lambda h: h in (8.0, 10.0, 12.0, 14.0, 16.0))[-1]
    assert viele == (
        "Wärmepumpe: geplant von 08:00 bis 08:15, 10:00 bis 10:15 und 12:00 bis 12:15 "
        "und 2 weitere Male."
    )


def test_der_brief_gilt_fuer_den_rest_von_heute_nicht_fuer_morgen() -> None:
    # Der einzige Lauf und das einzige Preistief liegen nach Mitternacht.
    zeilen = brief(wp=lambda h: 26 <= h < 28, preis=lambda h: 5.0 if h >= 24 else 30.0)
    assert zeilen[-1] == "Wärmepumpe: heute kein Lauf geplant."
    assert zeilen[1] == "Strom: der Preis bleibt heute nahezu gleich, um 30 ct."


def test_ohne_fahrplan_des_optimierers_fehlt_die_zeile_der_waermepumpe() -> None:
    b = morgenbrief(tag(), jetzt=SIEBEN, tz=BERLIN, hat_fahrplan=False)
    assert b is not None
    assert not any(z.startswith("Wärmepumpe") for z in b.zeilen)


def test_ohne_genug_viertelstunden_gibt_es_keinen_brief() -> None:
    assert morgenbrief([], jetzt=SIEBEN, tz=BERLIN) is None
    spaet = datetime(2026, 11, 11, 22, 0, tzinfo=UTC)  # 23 Uhr: der Tag ist fast vorbei
    assert morgenbrief(tag(ab=spaet, stunden=6), jetzt=spaet, tz=BERLIN) is None


def test_der_text_ist_der_rumpf_der_mitteilung() -> None:
    b = morgenbrief(tag(), jetzt=SIEBEN, tz=BERLIN)
    assert b is not None
    assert b.text == "\n".join(b.zeilen)
    assert "K1" not in b.text and "Freigabe" not in b.text
    assert timedelta(minutes=15) == SCHRITT
