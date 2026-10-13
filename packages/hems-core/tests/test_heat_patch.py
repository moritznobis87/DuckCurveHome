"""Geänderte Wärmeannahmen einsetzen, ohne die laufende Konfiguration anzufassen."""

from __future__ import annotations

import pytest

from hems_core.domain import HemsConfig, apply_heat_patch


def test_was_geschickt_wird_aendert_sich_der_rest_bleibt() -> None:
    alt = HemsConfig()
    neu = apply_heat_patch(alt, {"pellet_kwh_per_kg": 5.1, "stove_nominal_heat_kw": None})
    assert neu.stove.pellet_kwh_per_kg == 5.1
    assert neu.stove.nominal_heat_kw == alt.stove.nominal_heat_kw
    assert neu.heat_pump == alt.heat_pump


def test_die_alte_konfiguration_bleibt_unberuehrt() -> None:
    """Die laufende Regelung hält eine Referenz. Ein halb geändertes Objekt wäre ein Unfall."""
    alt = HemsConfig()
    vorher = alt.stove.pellet_kwh_per_kg
    apply_heat_patch(alt, {"pellet_kwh_per_kg": 5.3})
    assert alt.stove.pellet_kwh_per_kg == vorher


def test_felder_landen_in_der_richtigen_gruppe() -> None:
    neu = apply_heat_patch(
        HemsConfig(),
        {
            "cop_curve": [(-7.0, 2.2), (7.0, 3.3)],
            "buffer_volume_liters": 800.0,
            "stove_combustion_efficiency": 0.93,
        },
    )
    assert neu.heat_demand.cop_curve == [(-7.0, 2.2), (7.0, 3.3)]
    assert neu.buffer.volume_liters == 800.0
    assert neu.stove.combustion_efficiency == 0.93


def test_ein_leerer_patch_gibt_dieselbe_konfiguration_zurueck() -> None:
    alt = HemsConfig()
    assert apply_heat_patch(alt, {}) is alt
    assert apply_heat_patch(alt, {"pellet_kwh_per_kg": None}) is alt


@pytest.mark.parametrize(
    ("patch", "wort"),
    [
        ({"stove_water_heat_kw": 20.0}, "Wasseranteil"),
        ({"stove_min_water_heat_kw": 9.0}, "Minimallast"),
        ({"stove_min_heat_kw": 30.0}, "Minimallast"),
        ({"buffer_target_temperature_c": 90.0}, "Höchsttemperatur"),
        ({"buffer_target_temperature_c": 30.0}, "nutzbaren"),
    ],
)
def test_widersprueche_werden_abgelehnt(patch: dict[str, float], wort: str) -> None:
    """Die Prüfung gehört hierher und nicht ins Eingabeschema: sie braucht den Wert daneben.

    Wer nur den Wasseranteil schickt, schickt die Gesamtleistung nicht mit - gegen die muss er aber
    geprüft werden, und die steht im Bestand.
    """
    with pytest.raises(ValueError, match=wort):
        apply_heat_patch(HemsConfig(), patch)


def test_ein_passender_doppelwert_geht_durch() -> None:
    neu = apply_heat_patch(
        HemsConfig(), {"stove_nominal_heat_kw": 20.0, "stove_water_heat_kw": 18.0}
    )
    assert (neu.stove.nominal_heat_kw, neu.stove.water_heat_kw) == (20.0, 18.0)
