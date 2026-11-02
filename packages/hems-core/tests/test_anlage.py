"""Die beiden gerechneten Größen des Anlagenschemas: Nettoleistung des Speichers, Zapfung."""

from __future__ import annotations

from datetime import timedelta

import pytest
from hc_helpers import T0

from hems_core.domain import BufferConfig
from hems_core.thermal import (
    HAELT_KW,
    TempProbe,
    buffer_net_kw,
    netto_wort,
    zapfung,
)

CFG = BufferConfig()
# 1000 l, ein Kelvin in allen Schichten: 4,186 kJ/(l·K) → kWh
KWH_JE_K = 1000 * 4.186 / 3600


def _reihe(verlauf: list[tuple[int, float]]) -> list[TempProbe]:
    """(Minute, Temperatur in allen vier Schichten) zu Proben."""
    return [TempProbe(at=T0 + timedelta(minutes=mi), temps=(t, t, t, t)) for mi, t in verlauf]


# ------------------------------------------------------------------ Nettoleistung


def test_gleiche_temperaturen_heissen_null() -> None:
    proben = _reihe([(m, 45.0) for m in range(0, 20)])
    assert buffer_net_kw(proben, CFG, T0 + timedelta(minutes=19)) == 0.0


def test_ein_kelvin_je_viertelstunde_sind_viereinhalb_kilowatt() -> None:
    # 1,163 kWh in 15 Minuten: 4,65 kW. Linear steigend, das Fenster trifft genau 15 Minuten.
    proben = _reihe([(m, 40.0 + m / 15.0) for m in range(0, 31)])
    kw = buffer_net_kw(proben, CFG, T0 + timedelta(minutes=30))
    assert kw == pytest.approx(KWH_JE_K * 4, abs=0.02)
    assert netto_wort(kw) == "lädt"


def test_fallende_temperaturen_entladen() -> None:
    proben = _reihe([(m, 50.0 - m / 15.0) for m in range(0, 31)])
    kw = buffer_net_kw(proben, CFG, T0 + timedelta(minutes=30))
    assert kw == pytest.approx(-KWH_JE_K * 4, abs=0.02)
    assert netto_wort(kw) == "entlädt"


def test_unter_der_nutzgrenze_zaehlt_die_aenderung_trotzdem() -> None:
    # Alle Schichten unter 35 °C: die nutzbare Energie wäre konstant null, die Änderung ist es nicht.
    proben = _reihe([(m, 30.0 + m / 15.0) for m in range(0, 31)])
    kw = buffer_net_kw(proben, CFG, T0 + timedelta(minutes=30))
    assert kw is not None and kw > 4.0


def test_zu_wenig_vergangenheit_gibt_keine_zahl() -> None:
    proben = _reihe([(m, 45.0 + m) for m in range(0, 5)])
    assert buffer_net_kw(proben, CFG, T0 + timedelta(minutes=4)) is None


def test_eine_veraltete_probe_gibt_keine_zahl() -> None:
    proben = _reihe([(m, 45.0) for m in range(0, 20)])
    assert buffer_net_kw(proben, CFG, T0 + timedelta(minutes=19 + 6)) is None


def test_eine_luecke_wird_nicht_ueberbrueckt() -> None:
    # Zwei Proben, eine Stunde auseinander: keine Leistung, sondern zwei Temperaturen.
    proben = _reihe([(0, 40.0), (60, 50.0)])
    assert buffer_net_kw(proben, CFG, T0 + timedelta(minutes=60)) is None


def test_ein_halbes_fenster_reicht_gerade() -> None:
    # Acht Minuten Vergangenheit: knapp über der Mindestspanne, also eine Zahl.
    proben = _reihe([(m, 45.0 + m * 0.1) for m in range(0, 9)])
    assert buffer_net_kw(proben, CFG, T0 + timedelta(minutes=8)) is not None


def test_kleine_zahlen_heissen_haelt() -> None:
    assert netto_wort(HAELT_KW / 2) == "hält"
    assert netto_wort(-HAELT_KW / 2) == "hält"
    assert netto_wort(None) == ""


# ------------------------------------------------------------------ Zapfung


def _punkte(verlauf: list[float], start_min: int = 0) -> list[tuple]:
    return [(T0 + timedelta(minutes=start_min + i), t) for i, t in enumerate(verlauf)]


def test_ein_ruhendes_rohr_zapft_nicht() -> None:
    p = _punkte([22.0] * 30)
    assert zapfung(p, T0 + timedelta(minutes=29)) == zapfung([], T0)
    assert not zapfung(p, T0 + timedelta(minutes=29)).aktiv


def test_der_sprung_ist_die_zapfung_und_seit_ist_sein_beginn() -> None:
    # Zehn Minuten Ruhe, dann springt der Auslass binnen zwei Minuten auf 46 °C und bleibt dort.
    p = _punkte([22.0] * 10 + [31.0, 44.0, 46.0, 46.2, 45.9, 46.1])
    z = zapfung(p, T0 + timedelta(minutes=15))
    assert z.aktiv
    assert z.seit == T0 + timedelta(minutes=9)


def test_nach_dem_zudrehen_kuehlt_das_rohr_und_die_zapfung_endet() -> None:
    p = _punkte([22.0] * 10 + [31.0, 44.0, 46.0, 46.2, 45.9, 46.1, 45.6, 44.9, 44.0])
    assert not zapfung(p, T0 + timedelta(minutes=18)).aktiv


def test_ein_plateau_mit_zittern_bleibt_eine_zapfung() -> None:
    p = _punkte([22.0] * 5 + [40.0, 46.0] + [46.0, 45.8, 46.1, 45.9, 46.2, 45.7, 46.0])
    z = zapfung(p, T0 + timedelta(minutes=13))
    assert z.aktiv and z.seit == T0 + timedelta(minutes=4)


def test_eine_langsame_drift_ist_keine_zapfung() -> None:
    # Ein Technikraum, der sich über eine Stunde um drei Kelvin erwärmt: nie ein Kelvin in drei Minuten.
    p = _punkte([20.0 + i * 0.05 for i in range(60)])
    assert not zapfung(p, T0 + timedelta(minutes=59)).aktiv


def test_eine_zweite_zapfung_auf_warmem_rohr_wird_erkannt() -> None:
    # Erste Zapfung, Rohr kühlt auf 40 °C, dann wieder auf. Die neue Phase beginnt am Minimum.
    p = _punkte([22.0] * 3 + [44.0, 46.0, 45.0, 43.0, 41.5, 40.2, 40.0] + [45.0, 46.0, 46.0])
    z = zapfung(p, T0 + timedelta(minutes=12))
    assert z.aktiv and z.seit == T0 + timedelta(minutes=9)


def test_ohne_frische_minute_keine_aussage() -> None:
    p = _punkte([22.0] * 5 + [44.0, 46.0])
    assert not zapfung(p, T0 + timedelta(minutes=6 + 7)).aktiv
