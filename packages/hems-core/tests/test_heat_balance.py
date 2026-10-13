"""Die Wärmebilanz ohne Wärmemengenzähler.

Der wichtigste Test ist `test_was_nicht_aufgeht_steht_als_rest_da`. Die Entnahme ist der Rest einer
Umkehrrechnung; jeder Fehler der drei anderen Größen landet in ihr. Ein Modell, das diesen Fehler
still in die Entnahme schiebt, sieht immer plausibel aus und ist dann nichts mehr wert.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.domain.config import BufferConfig, HeatDemandConfig, StoveConfig
from hems_core.thermal import (
    HeatSample,
    cop_for,
    heat_series,
    heat_totals,
    mean_temperature_c,
    stored_energy_kwh,
    stove_output_kw,
)

NOW = datetime(2026, 10, 13, 6, 0, tzinfo=UTC)
BUFFER = BufferConfig()
HEAT = HeatDemandConfig()
STOVE = StoveConfig()


def _reihe(n: int, **feld: object) -> list[HeatSample]:
    args: dict[str, object] = {
        "heat_pump_kw": None,
        "outdoor_c": 5.0,
        "buffer_c": (50.0, 50.0, 50.0, 50.0),
        "room_c": 21.0,
        "stove_running": False,
        "stove_level": None,
    }
    args.update(feld)
    return [HeatSample(at=NOW + timedelta(minutes=i), **args) for i in range(n)]  # type: ignore[arg-type]


# ------------------------------------------------------------------ Speicherinhalt


def test_der_inhalt_wird_nicht_gekappt() -> None:
    """Der Unterschied zum Ladezustand, und der Grund für eine eigene Funktion.

    `usable_energy_kwh` zählt nur oberhalb der Nutzgrenze und deckelt bei der Kapazität. Für eine
    Ableitung über die Zeit wäre das fatal: unterhalb von 35 Grad stünde sie still, und die Bilanz
    verlöre genau die Wärme, die dort hineingeht.
    """
    kalt = stored_energy_kwh((20.0, 20.0, 20.0, 20.0), BUFFER)
    waermer = stored_energy_kwh((21.0, 21.0, 21.0, 21.0), BUFFER)
    # 1000 Liter um ein Kelvin: 1000 * 4,186 kJ / 3600 = 1,163 kWh
    assert round(waermer - kalt, 3) == 1.163
    heiss = stored_energy_kwh((80.0, 80.0, 80.0, 80.0), BUFFER)
    assert heiss > stored_energy_kwh((70.0, 70.0, 70.0, 70.0), BUFFER)


def test_die_bezugstemperatur_kuerzt_sich_heraus() -> None:
    a = (55.0, 50.0, 45.0, 40.0)
    b = (56.0, 51.0, 46.0, 41.0)
    d0 = stored_energy_kwh(b, BUFFER, 0.0) - stored_energy_kwh(a, BUFFER, 0.0)
    d20 = stored_energy_kwh(b, BUFFER, 20.0) - stored_energy_kwh(a, BUFFER, 20.0)
    assert round(d0 - d20, 9) == 0.0


def test_die_mitteltemperatur_ist_volumengewichtet() -> None:
    assert mean_temperature_c((60.0, 50.0, 40.0, 30.0), BUFFER) == 45.0


# ------------------------------------------------------------------ Arbeitszahl


def test_der_hub_veraendert_die_arbeitszahl() -> None:
    """Dieselbe Maschine, derselbe Tag, zwei Vorlauftemperaturen."""
    kalt_vorlauf = cop_for(5.0, 40.0, HEAT, BUFFER)
    heiss_vorlauf = cop_for(5.0, 58.0, HEAT, BUFFER)
    assert kalt_vorlauf > heiss_vorlauf
    # Bei Zieltemperatur steht die Kennlinie unverändert da.
    assert cop_for(5.0, BUFFER.target_temperature_c, HEAT, BUFFER) == cop_for(
        5.0, None, HEAT, BUFFER
    )


def test_die_arbeitszahl_faellt_nie_unter_eins() -> None:
    """Eine Wärmepumpe, die weniger liefert, als sie an Strom nimmt, gibt es nicht."""
    assert cop_for(-20.0, 70.0, HEAT, BUFFER) >= 1.0


def test_ein_verschwindender_hub_sprengt_die_rechnung_nicht() -> None:
    assert cop_for(55.0, 55.0, HEAT, BUFFER) > 0


# ------------------------------------------------------------------ Ofen


def test_die_ofenleistung_liegt_zwischen_den_beiden_datenblattpunkten() -> None:
    w1, r1 = stove_output_kw(1.0, STOVE)
    w5, r5 = stove_output_kw(5.0, STOVE)
    assert (w1, round(w1 + r1, 1)) == (STOVE.min_water_heat_kw, STOVE.min_heat_kw)
    assert (w5, round(w5 + r5, 1)) == (STOVE.water_heat_kw, STOVE.nominal_heat_kw)
    w3, _ = stove_output_kw(3.0, STOVE)
    assert w1 < w3 < w5


def test_ohne_gemeldete_stufe_gilt_volllast() -> None:
    """Eine brennende Flamme mit null Wärme zu verbuchen waere die schlechtere Annahme."""
    assert stove_output_kw(None, STOVE) == stove_output_kw(5.0, STOVE)


# ------------------------------------------------------------------ Bilanz


def test_ein_stehender_speicher_ohne_erzeuger_verliert_nur() -> None:
    punkte = heat_series(_reihe(10), stove=STOVE, heat=HEAT, buffer=BUFFER)
    letzter = punkte[-1]
    # 0,004 kW/K mal 29 K Übertemperatur
    assert letzter.loss_kw == round(BUFFER.loss_kw_per_k * (50.0 - 21.0), 3)
    assert letzter.heat_pump_kw == 0.0
    assert letzter.draw_kw == 0.0
    assert letzter.residual_kw < 0.0  # der Verlust ist unerklärte Abfuhr, keine Entnahme


def test_die_waermepumpe_liefert_strom_mal_arbeitszahl() -> None:
    punkte = heat_series(_reihe(5, heat_pump_kw=2.0), stove=STOVE, heat=HEAT, buffer=BUFFER)
    p = punkte[-1]
    assert p.cop is not None
    assert p.heat_pump_kw == round(2.0 * p.cop, 3)


def test_ein_ladender_speicher_zaehlt_als_ladung_und_nicht_als_entnahme() -> None:
    """Steigende Temperaturen heissen: die Wärme ist im Speicher geblieben, nicht im Heizkreis.

    0,1 K je Minute auf 1000 Liter sind rund 7 kW - ein Wert, den eine Wärmepumpe wirklich liefert.
    Mit 1 K je Minute, wie dieser Test ihn einmal hatte, wären es 70 kW gewesen, und die gibt es in
    diesem Haus nicht; die Bilanz sagt dazu inzwischen „unbekannt" statt einer Zahl.
    """
    samples = [
        HeatSample(
            at=NOW + timedelta(minutes=i),
            heat_pump_kw=3.0,
            outdoor_c=5.0,
            buffer_c=((40.0 + 0.1 * i,) * 4),
            room_c=21.0,
        )
        for i in range(20)
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    mitte = punkte[10]
    assert not mitte.unknown
    assert 5.0 < mitte.buffer_change_kw < 9.0
    # Was die Pumpe liefert, steckt zum grössten Teil im Speicher: die Entnahme bleibt klein.
    assert mitte.draw_kw < mitte.heat_pump_kw


def test_ein_entladender_speicher_ergibt_eine_entnahme() -> None:
    samples = [
        HeatSample(
            at=NOW + timedelta(minutes=i),
            heat_pump_kw=None,
            outdoor_c=5.0,
            buffer_c=(55.0 - 0.1 * i,) * 4,
            room_c=21.0,
        )
        for i in range(6)
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    assert punkte[-1].buffer_change_kw < 0
    assert punkte[-1].draw_kw > 0


def test_was_nicht_aufgeht_steht_als_rest_da() -> None:
    """Der Kern des Moduls: die Entnahme ist der Rest, also darf sie nicht alles schlucken.

    Hier wird dem Speicher Wärme zugeführt, die kein Erzeuger erklärt. Eine Bilanz, die das in die
    Entnahme schiebt, behauptet, jemand habe geduscht.
    """
    samples = [
        HeatSample(
            at=NOW + timedelta(minutes=i),
            buffer_c=(45.0 + 0.1 * i,) * 4,
            room_c=21.0,
            outdoor_c=5.0,
        )
        for i in range(20)
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    mitte = punkte[10]
    assert not mitte.unknown
    assert mitte.draw_kw == 0.0
    assert mitte.residual_kw < -1.0


def test_eine_luecke_wird_nicht_ueberbrueckt() -> None:
    """Zwei Temperaturen im Abstand einer Stunde sind keine Leistung."""
    samples = [
        HeatSample(at=NOW, buffer_c=(50.0,) * 4, room_c=21.0, outdoor_c=5.0),
        HeatSample(at=NOW + timedelta(hours=1), buffer_c=(40.0,) * 4, room_c=21.0, outdoor_c=5.0),
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    assert punkte[-1].buffer_change_kw == 0.0


def test_der_ofen_zaehlt_wasser_und_raum_getrennt() -> None:
    punkte = heat_series(
        _reihe(5, stove_running=True, stove_level=5.0), stove=STOVE, heat=HEAT, buffer=BUFFER
    )
    p = punkte[-1]
    assert p.stove_water_kw == STOVE.water_heat_kw
    assert p.stove_room_kw > 0
    assert round(p.stove_water_kw + p.stove_room_kw, 1) == STOVE.nominal_heat_kw


# ------------------------------------------------------------------ Summen


def test_die_summen_rechnen_in_kilowattstunden() -> None:
    samples = _reihe(60, heat_pump_kw=2.0)
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    summen = heat_totals(punkte, samples)
    assert summen.minutes == 60
    assert summen.electric_kwh == 2.0  # eine Stunde mal zwei Kilowatt
    assert summen.cop_mean is not None and summen.cop_mean > 1.0
    assert summen.heat_pump_kwh == round(2.0 * summen.cop_mean, 2)


def test_die_speicheraenderung_ist_eine_differenz_und_keine_summe() -> None:
    """Sonst summieren sich Lücken auf, und der Speicher hat über Nacht Energie erfunden."""
    samples = [
        HeatSample(at=NOW + timedelta(minutes=i), buffer_c=(50.0 + i,) * 4, room_c=21.0)
        for i in range(5)
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    summen = heat_totals(punkte, samples)
    erwartet = stored_energy_kwh((54.0,) * 4, BUFFER) - stored_energy_kwh((50.0,) * 4, BUFFER)
    assert summen.buffer_change_kwh == round(erwartet, 2)


def test_ein_leerer_zeitraum_sagt_es() -> None:
    summen = heat_totals([], [])
    assert summen.minutes == 0
    assert "keine" in summen.note_de


def test_der_satz_nennt_die_aufteilung_und_warnt_bei_grossem_rest() -> None:
    samples = _reihe(60, heat_pump_kw=2.0, stove_running=True, stove_level=5.0)
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    summen = heat_totals(punkte, samples)
    assert "%" in summen.note_de


# ------------------------------------------------------------------ Stundenraster


def test_die_stunde_verdichtet_minuten_ohne_das_modell_zu_wechseln() -> None:
    from hems_core.thermal import hourly_inputs, samples_from_hours

    samples = _reihe(60, heat_pump_kw=2.0, stove_running=True, stove_level=4.0)
    stunden = hourly_inputs(samples, BUFFER)
    assert len(stunden) == 1
    h = stunden[0]
    assert h.minutes == 60
    assert h.electric_kwh == 2.0
    assert h.stove_minutes == 60
    assert h.stove_level_mean == 4.0
    assert h.buffer_top_c == 50.0

    # Dieselbe Bilanz, nur gröber: die Größenordnung muss stehen.
    grob = heat_series(samples_from_hours(stunden), stove=STOVE, heat=HEAT, buffer=BUFFER)
    fein = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    assert abs(grob[0].heat_pump_kw - fein[-1].heat_pump_kw) < 0.3
    assert grob[0].stove_water_kw == fein[-1].stove_water_kw


def test_die_stundeneingaenge_speichern_eingaenge_und_keine_ergebnisse() -> None:
    """Sonst erreichte eine geänderte Annahme die Vergangenheit nicht."""
    from hems_core.thermal import HeatHourInput

    felder = set(HeatHourInput.model_fields)
    assert "electric_kwh" in felder  # gemessen
    assert not felder & {"heat_pump_kwh", "cop", "draw_kwh", "stove_water_kwh"}  # gerechnet


def test_eine_stunde_ohne_ofen_meldet_null_minuten() -> None:
    from hems_core.thermal import hourly_inputs

    stunden = hourly_inputs(_reihe(30), BUFFER)
    assert stunden[0].stove_minutes == 0
    assert stunden[0].stove_level_mean is None


# ------------------------------------------------------------------ Speicherleistung


def _stufe(n: int, sprung_bei: int, hoehe: float) -> list[HeatSample]:
    """Konstante Temperaturen mit einem einzigen Sprung - der Fall, der 50 kW erzeugt hat."""
    return [
        HeatSample(
            at=NOW + timedelta(minutes=i),
            buffer_c=((50.0 + (hoehe if i >= sprung_bei else 0.0)),) * 4,
            room_c=21.0,
            outdoor_c=5.0,
        )
        for i in range(n)
    ]


def test_ein_fuehlersprung_wird_nicht_zu_fuenfzig_kilowatt() -> None:
    """Der gemeldete Fehler: einmal in fünf Minuten eine Entnahme von 50 kW.

    1000 Liter sind 1,16 kWh je Kelvin. Über eine Minute abgeleitet sind 0,72 K fast 50 kW - durch
    ein Rohr dieses Hauses passen keine 50 kW. Über ein Fenster gebildet bleibt davon der Betrag,
    der wirklich geflossen sein kann.
    """
    punkte = heat_series(_stufe(30, 15, 0.72), stove=STOVE, heat=HEAT, buffer=BUFFER)
    spitze = max(abs(p.buffer_change_kw) for p in punkte)
    assert spitze < 10.0, spitze
    # Und die Entnahme erbt die Spitze nicht.
    assert max(p.draw_kw for p in punkte) < 10.0


def test_das_fenster_verliert_die_energie_nicht() -> None:
    """Geglättet werden darf nur die Verteilung, nicht die Menge."""
    from hems_core.thermal.heat_balance import buffer_power_kw

    samples = _stufe(40, 20, 1.0)
    leistungen = [p for p in buffer_power_kw(samples, BUFFER) if p is not None]
    # Summe der Leistungen mal Zeitschritt gegen die Differenz der Bestände.
    integral = sum(leistungen) / 60.0
    echt = stored_energy_kwh((51.0,) * 4, BUFFER) - stored_energy_kwh((50.0,) * 4, BUFFER)
    assert abs(integral - echt) < 0.25 * echt, (integral, echt)


def test_ohne_speicherleistung_wird_keine_entnahme_behauptet() -> None:
    """Sonst sähe eine Datenlücke aus wie ein Verbrauch in voller Höhe der Erzeugung."""
    samples = [
        HeatSample(at=NOW + timedelta(minutes=i), heat_pump_kw=3.0, outdoor_c=5.0, room_c=21.0)
        for i in range(10)
    ]
    punkte = heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER)
    assert all(p.draw_kw == 0.0 for p in punkte)
    assert all(p.residual_kw == 0.0 for p in punkte)
    assert all(p.heat_pump_kw > 0 for p in punkte)  # die Erzeugung steht trotzdem da


def test_ein_unmoeglicher_betrag_sagt_nichts_statt_etwas_falsches() -> None:
    """Was durch kein Rohr des Hauses passt, ist ein Fühlersprung und kein Wärmestrom.

    Ihn auf die Grenze zu beschneiden wäre die schlechtere Antwort: dann stünde dort eine Entnahme
    in Höhe der Grenze, also eine erfundene Zahl an der Stelle einer unbekannten.
    """
    punkte = heat_series(_stufe(6, 3, -10.0), stove=STOVE, heat=HEAT, buffer=BUFFER)
    betroffen = [p for p in punkte if p.unknown]
    assert betroffen, "ein Sprung von 10 K muss auffallen"
    assert all(p.draw_kw == 0.0 and p.residual_kw == 0.0 for p in betroffen)


def test_die_summen_zaehlen_die_minuten_ohne_aussage() -> None:
    """Schweigen über eine Lücke sieht aus wie eine Null, und eine Null sieht aus wie eine Messung."""
    samples = [
        HeatSample(at=NOW + timedelta(minutes=i), heat_pump_kw=3.0, outdoor_c=5.0, room_c=21.0)
        for i in range(30)
    ]
    summen = heat_totals(heat_series(samples, stove=STOVE, heat=HEAT, buffer=BUFFER), samples)
    assert summen.unknown_minutes == 30
    assert "nichts sagen" in summen.note_de
