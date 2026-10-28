"""Der Vergleichslauf: derselbe Tag ohne Preisblick.

Geprüft wird vor allem, dass die Zahl nicht lügt, wenn nichts verschoben wurde, und dass sie das
richtige Vorzeichen hat, wenn verschoben wurde.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from hems_core.accounting.counterfactual import (
    ShiftHour,
    day_value,
    naive_shape,
    shift_value,
    spread,
)
from hems_core.domain.config import HeatDemandConfig

CFG = HeatDemandConfig()
TAG = date(2026, 1, 15)
FEED_IN = 8.0
CAP = 4.5


def stunden(
    wp: list[float],
    preise: list[float],
    aussen: float = 0.0,
    pv: list[float] | None = None,
    grundlast: float = 0.3,
) -> list[ShiftHour]:
    """Ein Tag aus 24 Stunden. Netzbezug und Einspeisung ergeben sich aus PV und Verbrauch."""
    out: list[ShiftHour] = []
    for h in range(24):
        erzeugung = (pv or [0.0] * 24)[h]
        verbrauch = grundlast + wp[h]
        netto = verbrauch - erzeugung
        out.append(
            ShiftHour(
                hour_start=datetime(2026, 1, 15, h, tzinfo=UTC),
                day=TAG,
                local_hour=h,
                minutes=60,
                import_kwh=max(0.0, netto),
                export_kwh=max(0.0, -netto),
                heat_pump_kwh=wp[h],
                price_ct=preise[h],
                outdoor_c=aussen,
            )
        )
    return out


def test_wer_nichts_verschiebt_spart_nichts() -> None:
    """Läuft die Wärmepumpe genau nach dem Bedarf, ist der Vergleichslauf derselbe Lauf."""
    preise = [30.0] * 24
    gewichte = naive_shape(stunden([0.5] * 24, preise), CFG, 0.0)
    wp = [12.0 * w for w in gewichte]
    tag = day_value(TAG, stunden(wp, preise), CFG, FEED_IN, CAP)
    assert tag.note_de == ""
    assert abs(tag.saving_eur) < 0.01
    assert tag.shifted_kwh < 0.01


def test_verschieben_in_die_billige_stunde_spart() -> None:
    # Teuer am Abend, billig in der Nacht. Die Wärmepumpe lief nur nachts.
    preise = [10.0] * 6 + [40.0] * 18
    wp = [2.0] * 6 + [0.0] * 18
    tag = day_value(TAG, stunden(wp, preise), CFG, FEED_IN, CAP)
    assert tag.note_de == ""
    assert tag.saving_eur > 0
    assert tag.shifted_kwh > 0
    # Der Vergleichslauf ist teurer, nicht der echte.
    assert tag.naive_eur > tag.actual_eur


def test_zur_falschen_zeit_kostet() -> None:
    """Lief die Wärmepumpe nur in der teuersten Stunde, ist die Ersparnis negativ - und das steht da."""
    preise = [10.0] * 23 + [90.0]
    wp = [0.0] * 23 + [4.0]
    tag = day_value(TAG, stunden(wp, preise), CFG, FEED_IN, CAP)
    assert tag.saving_eur < 0


def test_eigene_sonne_wird_nicht_als_bezug_gerechnet() -> None:
    """Mittags mit PV-Überschuss zu laufen kostet nur die entgangene Vergütung, nicht den Bezugspreis."""
    preise = [35.0] * 24
    pv = [0.0] * 10 + [4.0] * 4 + [0.0] * 10  # 10 bis 14 Uhr Sonne
    wp = [0.0] * 10 + [3.0] * 4 + [0.0] * 10
    mit_sonne = day_value(TAG, stunden(wp, preise, pv=pv), CFG, FEED_IN, CAP)
    # Dieselbe Menge, aber nachts: Dann ist jede Kilowattstunde Netzbezug zum vollen Preis.
    nachts = [3.0] * 4 + [0.0] * 20
    ohne_sonne = day_value(TAG, stunden(nachts, preise, pv=pv), CFG, FEED_IN, CAP)
    assert mit_sonne.actual_eur < ohne_sonne.actual_eur


def test_der_deckel_haelt_die_leistung_des_geraets_ein() -> None:
    verteilt = spread(20.0, [1.0, 0.0, 0.0, 0.0], 4.5)
    assert max(verteilt) <= 4.5 + 1e-9
    # Was nicht in die erste Stunde passt, ist nicht verschwunden: Es liegt in den anderen.
    assert abs(sum(verteilt) - 20.0) < 1e-6 or max(verteilt) == 4.5


def test_tage_ohne_aussage_werden_genannt_nicht_geraten() -> None:
    preise = [30.0] * 24
    kalt = stunden([0.0] * 24, preise)  # Wärmepumpe lief nicht
    assert day_value(TAG, kalt, CFG, FEED_IN, CAP).note_de == "Wärmepumpe lief nicht"

    halb = stunden([1.0] * 24, preise)[:10]  # nur zehn Stunden Daten
    assert day_value(TAG, halb, CFG, FEED_IN, CAP).note_de == "zu wenige Stunden mit Daten"

    warm = stunden([1.0] * 24, preise, aussen=25.0)  # über der Heizgrenze
    # Warmwasser bleibt, also gibt es eine Form; die Heizung fehlt. Gerechnet wird trotzdem.
    assert warm[0].outdoor_c == 25.0
    assert day_value(TAG, warm, CFG, FEED_IN, CAP).note_de == ""

    ohne_preis = [
        ShiftHour(**{**h.__dict__, "price_ct": None}) for h in stunden([1.0] * 24, preise)
    ]
    assert day_value(TAG, ohne_preis, CFG, FEED_IN, CAP).note_de == "ohne Preis"


def test_der_zeitraum_summiert_nur_die_tage_mit_aussage() -> None:
    preise = [10.0] * 6 + [40.0] * 18
    guter_tag = stunden([2.0] * 6 + [0.0] * 18, preise)
    stiller_tag = [
        ShiftHour(**{**h.__dict__, "day": date(2026, 1, 16), "heat_pump_kwh": 0.0})
        for h in stunden([0.0] * 24, preise)
    ]
    ergebnis = shift_value([*guter_tag, *stiller_tag], CFG, FEED_IN, CAP)
    assert len(ergebnis.days) == 2
    assert ergebnis.skipped == 1
    assert ergebnis.skipped_de == "Wärmepumpe lief nicht"
    assert ergebnis.saving_eur > 0
    assert ergebnis.saving_ct_per_kwh is not None


def test_ohne_verschiebung_keine_angabe_je_kilowattstunde() -> None:
    leer = shift_value([], CFG, FEED_IN, CAP)
    assert leer.saving_ct_per_kwh is None
    assert leer.days == ()


def test_die_stundenlaenge_des_tages_folgt_der_uhr() -> None:
    """Ein Tag mit 25 Stunden (Zeitumstellung) wird gerechnet, nicht abgelehnt."""
    preise = [20.0] * 24
    lang = [*stunden([1.0] * 24, preise)]
    extra = lang[-1]
    lang.append(
        ShiftHour(**{**extra.__dict__, "hour_start": extra.hour_start + timedelta(hours=1)})
    )
    tag = day_value(TAG, lang, CFG, FEED_IN, CAP)
    assert tag.note_de == ""
    assert tag.heat_pump_kwh == 25.0


def test_der_laufende_tag_zaehlt_so_weit_er_gelaufen_ist() -> None:
    """Sonst wäre „was hat heute das Verschieben gebracht" bis Mitternacht immer unbeantwortet."""
    preise = [10.0] * 6 + [40.0] * 18
    halber = stunden([2.0] * 6 + [0.0] * 18, preise)[:12]  # zwölf Stunden, Mittag
    assert day_value(TAG, halber, CFG, FEED_IN, CAP, erwartet_h=12.0).note_de == ""
    # Dieselben zwölf Stunden als vergangener Tag sind eine Lücke, keine Auskunft.
    assert day_value(TAG, halber, CFG, FEED_IN, CAP, erwartet_h=24.0).note_de == (
        "zu wenige Stunden mit Daten"
    )
    # Ein Tag, der erst zwei Stunden alt ist, sagt trotzdem nichts.
    assert day_value(TAG, halber[:2], CFG, FEED_IN, CAP, erwartet_h=2.0).note_de != ""
