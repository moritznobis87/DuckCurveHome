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
    ofen: Callable[[float], bool | None] = lambda h: None,
    waerme: Callable[[float], float | None] = lambda h: None,
    strom_eur: Callable[[float], float | None] = lambda h: None,
    pellet_eur: Callable[[float], float | None] = lambda h: None,
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
        out.append(
            Viertel(
                ts=ts,
                preis_ct=preis(h),
                pv_kw=pv(h),
                wp=wp(h),
                ofen=ofen(h),
                waerme_kw=waerme(h),
                strom_eur=strom_eur(h),
                pellet_eur=pellet_eur(h),
            )
        )
    return out


def brief(**kw: object) -> list[str]:
    b = morgenbrief(tag(**kw), jetzt=SIEBEN, tz=BERLIN)  # type: ignore[arg-type]
    assert b is not None
    assert b.titel == "Morning Briefing"
    return list(b.zeilen)


def zeile(zeichen: str, zeilen: list[str]) -> str:
    treffer = [z for z in zeilen if z.startswith(zeichen)]
    assert len(treffer) == 1, zeilen
    return treffer[0]


def test_das_ganze_briefing_in_der_gewuenschten_form() -> None:
    """Nutzerwunsch 13.11.2026: Titel „Morning Briefing", vier kurze Zeilen mit Zeichen vorweg."""
    zeilen = brief(
        pv=lambda h: max(0.0, 3.0 - abs(h - 12.5) * 0.8),
        preis=lambda h: 18.0 if 13 <= h < 15 else 47.0 if 18 <= h < 19 else 30.0,
        wp=lambda h: 12 <= h < 15,
        ofen=lambda h: 17 <= h < 19,
        waerme=lambda h: 3.0,
        strom_eur=lambda h: 0.20 if 12 <= h < 15 else 0.0,
        pellet_eur=lambda h: 0.25 if 17 <= h < 19 else 0.0,
    )
    assert zeilen == [
        "☀️ 11 kWh erwartet, im Wesentlichen zwischen 10:30 und 14:45 Uhr",
        "⚡ Ø 30 ct, am günstigsten 13:00 bis 15:00 Uhr (18 ct)",
        "🔥 51 kWh Wärme: Wärmepumpe 3 h, Ofen 2 h",
        "💶 Wärme: 2,40 € Strom; 2,00 € Pellets",
    ]
    # Kurz: keine Zeile länger, als auf dem Sperrbildschirm in zwei Zeilen passt.
    assert max(len(z) for z in zeilen) <= 64


def test_die_sonne_nennt_die_zeit_in_der_vier_fuenftel_anfallen() -> None:
    # Ein Rechteck von 9 bis 16 Uhr: vier Fünftel von 28 Viertelstunden sind 23, aufgerundet.
    flach = zeile("☀️", brief(pv=lambda h: 0.6 if 9 <= h < 16 else 0.0))
    assert flach == "☀️ 4 kWh erwartet, im Wesentlichen zwischen 09:00 und 14:45 Uhr"
    # Eine Spitze am Mittag zieht die Zeit um sich zusammen: die Stunde der Spitze sind 77 %,
    # mit einer Stunde davor sind es 81 %.
    spitz = zeile("☀️", brief(pv=lambda h: 4.0 if 12 <= h < 13 else 0.2 if 9 <= h < 16 else 0.0))
    assert spitz == "☀️ 5 kWh erwartet, im Wesentlichen zwischen 11:00 und 13:00 Uhr"


def test_ein_trueber_tag_sagt_kaum_sonne_und_nennt_keine_zeit() -> None:
    assert zeile("☀️", brief(pv=lambda h: 0.2 if 11 <= h < 14 else 0.0)) == ("☀️ kaum Sonne erwartet")


def test_bei_fast_gleichem_preis_gibt_es_kein_fenster() -> None:
    # Zwischen 30 und knapp 32 ct, im Mittel knapp 31: zu wenig Unterschied für ein Fenster.
    assert zeile("⚡", brief(preis=lambda h: 30.0 + (h % 2))) == "⚡ Ø 31 ct, kaum Schwankung"


def test_ohne_preise_fehlt_die_zeile_und_nichts_wird_geraten() -> None:
    assert not any(z.startswith("⚡") for z in brief(preis=lambda h: None))


def test_die_waerme_nennt_bedarf_und_laufzeiten() -> None:
    assert zeile("🔥", brief()) == "🔥 kein Lauf geplant"
    assert zeile("🔥", brief(waerme=lambda h: 2.0)) == "🔥 34 kWh Wärme, kein Lauf geplant"
    assert zeile("🔥", brief(waerme=lambda h: 2.0, wp=lambda h: 12 <= h < 14.25)) == (
        "🔥 34 kWh Wärme: Wärmepumpe 2:15 h"
    )
    assert zeile("🔥", brief(wp=lambda h: h == 12.0, ofen=lambda h: 18 <= h < 21)) == (
        "🔥 Wärmepumpe 15 min, Ofen 3 h"
    )


def test_die_kosten_stehen_nur_da_wo_der_fahrplan_sie_kennt() -> None:
    assert not any(z.startswith("💶") for z in brief())
    # Ohne Ofenfahrplan gibt es keine Pellets, auch keine null.
    nur_strom = brief(wp=lambda h: 12 <= h < 14, strom_eur=lambda h: 0.3 if 12 <= h < 14 else 0.0)
    assert zeile("💶", nur_strom) == "💶 Wärme: 2,40 € Strom"
    # Mit Ofenfahrplan, der den Ofen aus lässt: die Null ist die Auskunft.
    ofen_aus = brief(
        ofen=lambda h: False,
        strom_eur=lambda h: 0.1 if h < 8 else 0.0,
        pellet_eur=lambda h: 0.0,
    )
    assert zeile("💶", ofen_aus) == "💶 Wärme: 0,40 € Strom; 0,00 € Pellets"


def test_das_briefing_gilt_fuer_den_rest_von_heute_nicht_fuer_morgen() -> None:
    # Der einzige Lauf, das einzige Preistief und alle Kosten liegen nach Mitternacht.
    zeilen = brief(
        wp=lambda h: 26 <= h < 28,
        preis=lambda h: 5.0 if h >= 24 else 30.0,
        strom_eur=lambda h: 1.0 if h >= 24 else 0.0,
    )
    assert zeile("🔥", zeilen) == "🔥 kein Lauf geplant"
    assert zeile("⚡", zeilen) == "⚡ Ø 30 ct, kaum Schwankung"
    assert zeile("💶", zeilen) == "💶 Wärme: 0,00 € Strom"


def test_ohne_fahrplan_des_optimierers_fehlen_laufzeiten_und_kosten() -> None:
    reihe = tag(waerme=lambda h: 2.0, wp=lambda h: True, strom_eur=lambda h: 0.1)
    b = morgenbrief(reihe, jetzt=SIEBEN, tz=BERLIN, hat_fahrplan=False)
    assert b is not None
    assert zeile("🔥", list(b.zeilen)) == "🔥 34 kWh Wärme"
    assert not any(z.startswith("💶") for z in b.zeilen)
    ohne = morgenbrief(tag(), jetzt=SIEBEN, tz=BERLIN, hat_fahrplan=False)
    assert ohne is not None and not any(z.startswith("🔥") for z in ohne.zeilen)


def test_ohne_genug_viertelstunden_gibt_es_kein_briefing() -> None:
    assert morgenbrief([], jetzt=SIEBEN, tz=BERLIN) is None
    spaet = datetime(2026, 11, 11, 22, 0, tzinfo=UTC)  # 23 Uhr: der Tag ist fast vorbei
    assert morgenbrief(tag(ab=spaet, stunden=6), jetzt=spaet, tz=BERLIN) is None


def test_der_text_ist_der_rumpf_der_mitteilung() -> None:
    b = morgenbrief(tag(), jetzt=SIEBEN, tz=BERLIN)
    assert b is not None
    assert b.text == "\n".join(b.zeilen)
    assert "K1" not in b.text and "Freigabe" not in b.text
    assert timedelta(minutes=15) == SCHRITT
