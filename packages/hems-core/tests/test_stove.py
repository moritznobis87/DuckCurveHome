"""Kennzahlen des Pelletofens: Brennphasen, Brennstoffeintrag, Sonderfälle."""

from __future__ import annotations

from hems_core.thermal.stove import StoveSample, fuel_note, stove_stats


def burn(level: int = 3, auger: float = 300.0, fume: float = 150.0, **kw: object) -> StoveSample:
    return StoveSample(
        running=True,
        power_level=level,
        auger_rpm=auger,
        fume_temp_c=fume,
        boiler_temp_c=kw.get("boiler", 80.0),  # type: ignore[arg-type]
        return_temp_c=kw.get("ret", 64.0),  # type: ignore[arg-type]
        pump_pct=kw.get("pump", 100.0),  # type: ignore[arg-type]
        dhw=bool(kw.get("dhw", False)),
    )


IDLE = StoveSample(running=False, power_level=0, auger_rpm=0.0, fume_temp_c=20.0, pump_pct=0.0)
GAP = StoveSample()  # keine Daten für diese Minute


def test_ohne_daten_kein_ergebnis() -> None:
    s = stove_stats([GAP, GAP])
    assert s.available is False
    assert "keine Ofendaten" in s.note_de


def test_eine_brennphase_wird_gezaehlt_und_vermessen() -> None:
    s = stove_stats([IDLE, *[burn()] * 30, IDLE])
    assert s.available is True
    assert s.runs == 1
    assert s.running_minutes == 30
    assert s.burning_minutes == 30
    assert s.longest_run_min == 30
    assert s.spread_k == 16.0
    assert s.minutes_by_level == {"3": 30}


def test_brennstoffeintrag_ist_das_integral_der_schneckendrehzahl() -> None:
    """300 Umdrehungen je Minute über 10 Minuten sind 3000. Das ist der Vergleichsmaßstab."""
    s = stove_stats([burn(auger=300.0)] * 10)
    assert s.auger_revolutions == 3000.0
    doppelt = stove_stats([burn(auger=600.0)] * 10)
    assert doppelt.auger_revolutions == 2 * s.auger_revolutions


def test_zuenden_zaehlt_als_laufzeit_aber_nicht_als_feuer() -> None:
    """Der Zustandscode meldet früh „an". Erst heißes Rauchgas heißt, dass es wirklich brennt."""
    s = stove_stats([burn(fume=25.0)] * 5 + [burn(fume=180.0)] * 20)
    assert s.running_minutes == 25
    assert s.burning_minutes == 20
    assert "Zünden oder Ausbrand" in s.note_de


def test_eine_datenluecke_beendet_die_phase_statt_sie_zu_ueberbruecken() -> None:
    s = stove_stats([*[burn()] * 10, GAP, GAP, *[burn()] * 10])
    assert s.runs == 2, "zwei Läufe mit Lücke sind nicht ein Lauf"
    assert s.running_minutes == 20
    assert s.longest_run_min == 10


def test_spreizung_nur_wenn_die_pumpe_foerdert() -> None:
    """Ohne Zirkulation ist die Differenz der beiden Fühler eine Zufallszahl."""
    s = stove_stats([burn(pump=0.0, boiler=80.0, ret=20.0)] * 10)
    assert s.pumping_minutes == 0
    assert s.spread_k is None


def test_warmwasser_und_leistungsstufen_werden_getrennt_gezaehlt() -> None:
    s = stove_stats([burn(level=5, dhw=True)] * 12 + [burn(level=2)] * 8)
    assert s.dhw_minutes == 12
    assert s.minutes_by_level == {"2": 8, "5": 12}


def test_ofen_aus_wird_klar_benannt() -> None:
    s = stove_stats([IDLE] * 60)
    assert s.available is True
    assert s.runs == 0
    assert s.note_de == "Der Ofen lief in diesem Zeitraum nicht."


def test_fehlende_einzelfelder_kippen_die_rechnung_nicht() -> None:
    """Eine Firmware ohne Rücklauffühler liefert trotzdem Laufzeit und Brennstoff."""
    samples = [StoveSample(running=True, auger_rpm=250.0, power_level=3)] * 10
    s = stove_stats(samples)
    assert s.running_minutes == 10
    assert s.auger_revolutions == 2500.0
    assert s.spread_k is None
    assert s.fume_temp_max_c is None


def test_brennstoff_wird_nicht_als_kilogramm_ausgegeben_ohne_faktor() -> None:
    text = fuel_note(3000.0)
    assert "Schneckenumdrehungen" in text
    assert "kg" not in text
    assert "1.5 kg" in fuel_note(3000.0, kg_per_revolution=0.0005)
    assert fuel_note(0.0) == "Kein Brennstoffeintrag im Zeitraum."
