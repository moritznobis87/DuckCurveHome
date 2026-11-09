"""Die Nachbetrachtung in Euro: eine Rechnung für alle Linien, über dieselben Viertelstunden."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.accounting.nachbetrachtung import (
    Fahrplan,
    Linie,
    Nachbetrachtung,
    Viertel,
    nach_bedarf,
    nachbetrachten,
    strom_eur,
)

T0 = datetime(2026, 11, 8, 23, 0, tzinfo=UTC)  # Ortsmitternacht in Berlin
WP_KW = 4.0  # eine Freigabe zieht im Modell 4 kW, also 1 kWh je Viertelstunde
VERGUETUNG = 8.0


def tag(
    n: int = 16,
    *,
    preis: list[float | None] | float = 30.0,
    ueberschuss: list[float | None] | float = 0.0,
    wp_kwh: list[float | None] | float = 0.0,
    **mehr: object,
) -> list[Viertel]:
    """`n` Viertelstunden ab `T0`. Eine Zahl gilt für alle, eine Liste je Viertelstunde."""

    def je(wert: object, i: int) -> object:
        return wert[i] if isinstance(wert, list) else wert

    return [
        Viertel(
            ts=T0 + timedelta(minutes=15 * i),
            preis_ct=je(preis, i),  # type: ignore[arg-type]
            ueberschuss_kw=je(ueberschuss, i),  # type: ignore[arg-type]
            wp_kwh=je(wp_kwh, i),  # type: ignore[arg-type]
            **{k: je(v, i) for k, v in mehr.items()},  # type: ignore[arg-type]
        )
        for i in range(n)
    ]


def an(n: int, *bereiche: tuple[int, int]) -> list[bool | None]:
    """Ein Fahrplan über `n` Viertelstunden, frei in den genannten Bereichen."""
    return [any(a <= i < b for a, b in bereiche) for i in range(n)]


def rechne(viertel: list[Viertel], **kw: object) -> Nachbetrachtung:
    args: dict[str, object] = {
        "erster": None,
        "letzter": None,
        "perfekt": None,
        "wp_kw": WP_KW,
        "verguetung_ct": VERGUETUNG,
        "hat_ofen": False,
    }
    args.update(kw)
    return nachbetrachten(viertel, **args)  # type: ignore[arg-type]


def linie(n: Nachbetrachtung, key: str) -> Linie:
    return next(x for x in n.linien if x.key == key)


def abstand(n: Nachbetrachtung, key: str) -> float | None:
    return next(a for a in n.abstaende if a.key == key).eur


# ---------------------------------------------------------------------------- Die eine Rechnung


def test_strom_aus_dem_netz_kostet_den_bezugspreis() -> None:
    assert strom_eur(
        1.0, ueberschuss_kw=0.0, preis_ct=30.0, verguetung_ct=8.0, dt_h=0.25
    ) == pytest.approx(0.30)


def test_strom_aus_dem_ueberschuss_kostet_die_entgangene_verguetung() -> None:
    assert strom_eur(
        1.0, ueberschuss_kw=6.0, preis_ct=30.0, verguetung_ct=8.0, dt_h=0.25
    ) == pytest.approx(0.08)


def test_deckt_die_sonne_einen_teil_wird_anteilig_gerechnet() -> None:
    # 1 kWh in der Viertelstunde, 2 kW Überschuss decken davon die Hälfte.
    eur = strom_eur(1.0, ueberschuss_kw=2.0, preis_ct=30.0, verguetung_ct=8.0, dt_h=0.25)
    assert eur == pytest.approx(0.5 * 0.30 + 0.5 * 0.08)


def test_die_nulllinie_verteilt_nach_dem_bedarf_und_nur_im_vergleich() -> None:
    verteilt = nach_bedarf(6.0, [1.0, 2.0, 9.0, 3.0], [True, True, False, True])
    assert verteilt == [1.0, 2.0, None, 3.0]


def test_ohne_gewichte_wird_gleichmaessig_verteilt() -> None:
    assert nach_bedarf(6.0, [None, 1.0, 1.0], [True, True, True]) == [2.0, 2.0, 2.0]
    assert nach_bedarf(6.0, [0.0, 0.0], [True, True]) == [3.0, 3.0]


# ---------------------------------------------------------------------------- Die Treppe


def test_die_treppe_fuehrt_auf_den_cent_vom_versprechen_zur_wirklichkeit() -> None:
    n = 16
    preise = [40.0] * 4 + [20.0] * 4 + [30.0] * 8
    viertel = tag(
        n,
        preis=list(preise),
        wp_kwh=[0.0] * 6 + [0.9] * 5 + [0.0] * 5,
        laufmin=[0.0] * 6 + [15.0] * 5 + [0.0] * 5,
    )
    erster = Fahrplan(wp=an(n, (0, 4)), versprochen_eur=[0.25] * 4 + [0.0] * 12)
    letzter = Fahrplan(wp=an(n, (4, 8)))
    r = rechne(viertel, erster=erster, letzter=letzter)
    versprochen = linie(r, "versprochen").eur
    wirklich = linie(r, "wirklich").eur
    assert versprochen == 1.00
    assert linie(r, "erster").eur == pytest.approx(4 * 0.40)
    assert linie(r, "letzter").eur == pytest.approx(4 * 0.20)
    stufen = [abstand(r, k) for k in ("prognosefehler", "nachfuehren", "eingriff")]
    assert all(s is not None for s in stufen)
    assert versprochen + sum(s or 0.0 for s in stufen) == pytest.approx(wirklich, abs=0.005)
    assert abstand(r, "prognosefehler") == pytest.approx(0.60)
    assert abstand(r, "nachfuehren") == pytest.approx(-0.80)


def test_alle_linien_zaehlen_dieselben_viertelstunden() -> None:
    """Der erste Fahrplan entstand erst zur fünften Viertelstunde. Davor zählt niemand.

    Die Maschine lief auch vorher, und das hat Geld gekostet - aber kein Fahrplan kann dazu etwas
    sagen, also zählt es auch für die Wirklichkeit nicht. Sonst mäße der Abstand die Länge der
    Linien und nicht ihren Unterschied.
    """
    n = 12
    viertel = tag(n, wp_kwh=[1.0] * 12)
    wp: list[bool | None] = [None] * 4 + [True] * 8
    r = rechne(viertel, erster=Fahrplan(wp=wp), letzter=Fahrplan(wp=wp))
    assert r.verglichen == [False] * 4 + [True] * 8
    assert r.n_verglichen == 8
    assert linie(r, "wirklich").eur == pytest.approx(8 * 0.30)
    assert linie(r, "wirklich").wp_kwh == 8.0
    assert linie(r, "wirklich").eur_je[:4] == [None] * 4
    assert any("8 von 12 Viertelstunden" in h for h in r.hinweise_de)


def test_eine_luecke_in_der_messung_faellt_fuer_alle_linien_weg() -> None:
    n = 8
    kwh: list[float | None] = [1.0, 1.0, None, 1.0, 1.0, 1.0, 1.0, 1.0]
    plan = Fahrplan(wp=an(n, (0, 8)))
    r = rechne(tag(n, wp_kwh=kwh), erster=plan, letzter=plan)
    assert r.verglichen[2] is False
    assert linie(r, "letzter").eur == pytest.approx(7 * 0.30)
    # Die aufgelaufenen Kosten bleiben über die Lücke stehen und springen nicht.
    kumuliert = linie(r, "letzter").eur_kumuliert
    assert kumuliert[1] == kumuliert[2] == pytest.approx(0.60)
    assert kumuliert[-1] == pytest.approx(linie(r, "letzter").eur or 0.0)


# ---------------------------------------------------------------------------- Der Eingriff


def test_dieselbe_menge_zu_anderer_zeit_ist_ganz_zeitpunkt() -> None:
    n = 8
    viertel = tag(n, preis=[20.0] * 4 + [40.0] * 4, wp_kwh=[0.0] * 4 + [1.0] * 4)
    plan = Fahrplan(wp=an(n, (0, 4)))
    r = rechne(viertel, erster=plan, letzter=plan)
    e = next(a for a in r.abstaende if a.key == "eingriff")
    assert e.eur == pytest.approx(0.80)
    assert e.menge_eur == 0.0
    assert e.zeit_eur == pytest.approx(0.80)
    assert "durch den Zeitpunkt" in e.satz_de


def test_mehr_strom_zur_selben_zeit_ist_ganz_menge() -> None:
    n = 8
    viertel = tag(n, wp_kwh=[1.5] * 4 + [0.0] * 4)
    plan = Fahrplan(wp=an(n, (0, 4)))
    r = rechne(viertel, erster=plan, letzter=plan)
    e = next(a for a in r.abstaende if a.key == "eingriff")
    assert e.eur == pytest.approx(0.60)
    assert e.menge_eur == pytest.approx(0.60)
    assert e.zeit_eur == 0.0
    assert "6,0 kWh statt 4,0 kWh" in e.satz_de


def test_die_teile_des_eingriffs_ergeben_ihn_auf_den_cent() -> None:
    n = 12
    viertel = tag(
        n,
        preis=[17.3, 22.9, 31.1, 28.4, 35.7, 19.2, 24.6, 33.3, 27.7, 21.5, 30.9, 26.1],
        ueberschuss=[0.0, 0.0, 1.3, 2.2, 0.4, 0.0, 0.0, 0.0, 3.1, 0.0, 0.0, 0.0],
        wp_kwh=[0.0, 0.83, 0.91, 0.0, 0.0, 0.77, 0.86, 0.0, 0.0, 0.0, 0.88, 0.0],
    )
    plan = Fahrplan(wp=an(n, (2, 5), (8, 10)))
    r = rechne(viertel, erster=plan, letzter=plan)
    e = next(a for a in r.abstaende if a.key == "eingriff")
    assert e.eur is not None and e.menge_eur is not None and e.zeit_eur is not None
    assert e.menge_eur + e.zeit_eur + (e.ofen_eur or 0.0) == pytest.approx(e.eur, abs=0.001)


def test_lief_etwas_das_nicht_laufen_sollte_ist_es_ganz_menge() -> None:
    n = 4
    plan = Fahrplan(wp=an(n))
    r = rechne(tag(n, wp_kwh=[1.0] * 4), erster=plan, letzter=plan)
    e = next(a for a in r.abstaende if a.key == "eingriff")
    assert e.menge_eur == pytest.approx(1.20) and e.zeit_eur == 0.0


# ---------------------------------------------------------------------------- Was fehlen darf


def test_ohne_fahrplan_fehlen_seine_linien_mit_grund_und_die_messung_bleibt() -> None:
    r = rechne(tag(8, wp_kwh=[1.0] * 8))
    assert r.n_verglichen == 8
    assert linie(r, "wirklich").eur == pytest.approx(2.40)
    for key in ("versprochen", "erster", "letzter"):
        assert not linie(r, key).verfuegbar
        assert "kein Fahrplan aufbewahrt" in linie(r, key).grund_de
    assert abstand(r, "eingriff") is None
    assert "nicht aufbewahrt" in r.satz_de


def test_ein_fahrplan_ohne_aufbewahrte_kosten_hat_kein_versprechen() -> None:
    """Fahrpläne von vor der Erweiterung der Ablage. Kein Versprechen ist nicht null Euro."""
    n = 8
    plan = Fahrplan(wp=an(n, (0, 4)))
    r = rechne(tag(n), erster=plan, letzter=plan)
    assert not linie(r, "versprochen").verfuegbar
    assert "keine Kosten aufbewahrt" in linie(r, "versprochen").grund_de
    assert abstand(r, "prognosefehler") is None
    assert linie(r, "erster").eur == pytest.approx(1.20), "gehalten lässt sich trotzdem rechnen"
    assert "letzten Stand" in r.satz_de


def test_der_vergleichslauf_fehlt_mit_dem_grund_des_aufrufers() -> None:
    r = rechne(tag(8), perfekt_grund_de="Die Preisreihe reicht nur 3 Stunden.")
    assert linie(r, "perfekt").grund_de == "Die Preisreihe reicht nur 3 Stunden."
    assert abstand(r, "voraussicht") is None


def test_mit_perfekter_voraussicht_steht_da_was_noch_zu_holen_ist() -> None:
    n = 8
    viertel = tag(n, preis=[40.0] * 4 + [10.0] * 4)
    plan = Fahrplan(wp=an(n, (0, 4)))
    r = rechne(viertel, erster=plan, letzter=plan, perfekt=Fahrplan(wp=an(n, (4, 8))))
    assert abstand(r, "voraussicht") == pytest.approx(1.20)
    assert "1,20 € weniger" in next(a for a in r.abstaende if a.key == "voraussicht").satz_de


# ---------------------------------------------------------------------------- Nulllinie, Ofen


def test_ohne_preisblick_ist_dieselbe_menge_und_als_schaetzung_gekennzeichnet() -> None:
    n = 8
    # Die Maschine lief in der billigen Hälfte; der Bedarf war über den Tag gleich.
    viertel = tag(n, preis=[10.0] * 4 + [40.0] * 4, wp_kwh=[1.0] * 4 + [0.0] * 4, gewicht=1.0)
    r = rechne(viertel)
    ohne = linie(r, "ohne_fuehrung")
    assert ohne.geschaetzt
    assert ohne.wp_kwh == linie(r, "wirklich").wp_kwh == 4.0
    assert ohne.eur == pytest.approx(4 * (0.5 * 0.10 + 0.5 * 0.40))
    assert abstand(r, "gebracht") == pytest.approx(0.40 - 1.00)
    assert (
        "hat das Verschieben gebracht"
        in next(a for a in r.abstaende if a.key == "gebracht").satz_de
    )


def test_der_ofen_zaehlt_im_fahrplan_ganz_und_in_der_messung_nach_seinem_anteil() -> None:
    n = 8
    viertel = tag(n, ofen_eur_je_h=0.80, ofen_anteil=[0.5] * 4 + [0.0] * 4)
    plan = Fahrplan(wp=an(n), ofen=an(n, (0, 4)))
    r = rechne(viertel, erster=plan, letzter=plan, hat_ofen=True)
    assert linie(r, "letzter").ofen_eur == pytest.approx(0.80)
    assert linie(r, "letzter").ofen_h == 1.0
    assert linie(r, "wirklich").ofen_eur == pytest.approx(0.40)
    assert linie(r, "wirklich").ofen_h == 0.5
    e = next(a for a in r.abstaende if a.key == "eingriff")
    assert e.ofen_eur == pytest.approx(-0.40)
    assert "durch den Ofen" in e.satz_de


def test_die_grundlast_steht_daneben_und_in_keiner_linie() -> None:
    n = 8
    viertel = tag(n, wp_kwh=0.0, standby_kwh=0.02)
    r = rechne(viertel)
    assert linie(r, "wirklich").eur == 0.0
    assert r.standby_kwh == pytest.approx(0.16)
    assert r.standby_eur == pytest.approx(0.05, abs=0.005)
    assert any("Grundlast" in h for h in r.hinweise_de)


# ---------------------------------------------------------------------------- Der Satz


def test_ein_laufender_tag_sagt_bisher() -> None:
    r = rechne(tag(8, wp_kwh=[1.0] * 8), laeuft_noch=True)
    assert "bisher 2,40 €" in r.satz_de
    assert r.hinweise_de[0].startswith("Der Tag läuft noch")


def test_zu_wenige_viertelstunden_ergeben_zahlen_aber_keinen_vergleich() -> None:
    r = rechne(tag(4, wp_kwh=[1.0] * 4))
    assert "zu wenige Viertelstunden" in r.satz_de


def test_ein_tag_ohne_messung_bricht_nicht() -> None:
    r = rechne(tag(8, wp_kwh=[None] * 8))
    assert r.n_verglichen == 0
    assert linie(r, "wirklich").eur is None
    assert "keine Viertelstunde" in r.satz_de


# ---------------------------------------------------------------------------- Menge und Preis


def test_der_mittlere_preis_haengt_nicht_an_der_menge() -> None:
    """Zwei Linien mit verschiedener Laufzeit: in Euro unvergleichbar, im mittleren Preis nicht."""
    n = 8
    viertel = tag(n, preis=[20.0] * 4 + [40.0] * 4, wp_kwh=[0.0] * 6 + [0.5] * 2)
    plan = Fahrplan(wp=an(n, (0, 4)))
    r = rechne(viertel, erster=plan, letzter=plan)
    assert linie(r, "letzter").ct_je_kwh == 20.0
    assert linie(r, "wirklich").ct_je_kwh == 40.0
    # In Euro sähe die Wirklichkeit günstiger aus: sie zog nur ein Viertel des Stroms.
    assert (linie(r, "wirklich").eur or 0.0) < (linie(r, "letzter").eur or 0.0)


def test_ohne_strom_gibt_es_keinen_mittleren_preis() -> None:
    r = rechne(tag(8, wp_kwh=0.0))
    assert linie(r, "wirklich").ct_je_kwh is None


def test_liegen_die_mengen_weit_auseinander_sagen_satz_und_hinweis_das() -> None:
    n = 16
    # Der Fahrplan sah acht Viertelstunden vor, die Maschine zog ein Viertel davon.
    viertel = tag(n, wp_kwh=[1.0, 1.0] + [0.0] * 14)
    plan = Fahrplan(wp=an(n, (0, 8)), versprochen_eur=[0.3] * 8 + [0.0] * 8)
    r = rechne(viertel, erster=plan, letzter=plan)
    assert "vor allem an der Menge" in r.satz_de
    assert "8,0 kWh Strom, gemessen sind 2,0 kWh" in r.satz_de
    assert any("Bedarfsmodell" in h for h in r.hinweise_de)


def test_bei_aehnlichen_mengen_bleibt_der_satz_beim_betrag() -> None:
    n = 16
    viertel = tag(n, wp_kwh=[0.9] * 8 + [0.0] * 8)
    plan = Fahrplan(wp=an(n, (0, 8)), versprochen_eur=[0.3] * 8 + [0.0] * 8)
    r = rechne(viertel, erster=plan, letzter=plan)
    assert "Menge" not in r.satz_de
    assert not any("Bedarfsmodell" in h for h in r.hinweise_de)
