"""Die Speicherprüfung: trennt sie die drei Erklärungen einer hohen Netzladung?

Die Prüfungen bauen drei Welten, die in `battery_power_kw` **identisch** aussehen und sich nur in
den beiden Zeugen unterscheiden: Ladestand und Hausverbrauch des Hubs. Genau das ist der Zweck der
Prüfung, und genau das muss sie zeigen.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from hc_helpers import T0

from hems_core.accounting.battery_check import (
    Abschnitt,
    SpeicherProbe,
    abschnitt,
    aufteilung,
    pruefe_speicher,
    ruhe_befund,
    speicher_urteil,
    summe_abschnitte,
    tief_nachladungen,
    wirkungsgrade,
)

KAP = 5.1


def reihe(
    minuten: int,
    *,
    batterie: float,
    soc_start: float,
    soc_rate: float = 0.0,
    pv: float = 0.0,
    haus: float | None = None,
    start_min: int = 0,
) -> list[SpeicherProbe]:
    """Eine gleichförmige Strecke. `soc_rate` ist die Änderung je Stunde, auf Prozent gerundet.

    Das Runden ist nicht Kosmetik: Der Speicher meldet ganze Prozent, und die Prüfung lebt davon,
    dass sie mit dieser groben Stufe umgeht.
    """
    out: list[SpeicherProbe] = []
    for i in range(minuten):
        soc = round(soc_start + soc_rate * i / 60.0, 2)
        # Netz deckt, was PV nicht deckt: Haus = PV + Netz + Speicher, sofern nicht anders gesagt.
        netz = (haus if haus is not None else 0.4) - pv - batterie
        out.append(
            SpeicherProbe(
                at=T0 + timedelta(minutes=start_min + i),
                pv_kw=pv,
                grid_kw=round(netz, 4),
                battery_kw=batterie,
                house_kw=haus if haus is not None else 0.4,
                soc=soc,
            )
        )
    return out


# ------------------------------------------------------------------ Bausteine


def test_ein_abschnitt_zaehlt_laden_entladen_und_dunkel() -> None:
    # 60 min mit 1,2 kW Ladung bei Nacht, dann 60 min mit 0,6 kW Entladung.
    proben = reihe(60, batterie=-1.2, soc_start=0.5, soc_rate=0.22) + reihe(
        60, batterie=0.6, soc_start=0.72, soc_rate=-0.12, start_min=60
    )
    a = abschnitt(proben, KAP)
    assert a.minuten == 120
    assert a.laden_kwh == pytest.approx(1.2, abs=0.02)
    assert a.entladen_kwh == pytest.approx(0.6, abs=0.02)
    # Ohne Erzeugung: die ganze Ladung ist dunkel.
    assert a.laden_dunkel_kwh == pytest.approx(1.2, abs=0.02)
    assert a.restglied_kw == pytest.approx(0.0, abs=1e-6)


def test_bei_sonne_ist_die_ladung_nicht_dunkel() -> None:
    a = abschnitt(reihe(60, batterie=-1.2, soc_start=0.5, soc_rate=0.22, pv=3.0), KAP)
    assert a.laden_kwh == pytest.approx(1.2, abs=0.02)
    assert a.laden_dunkel_kwh == 0.0


def test_eine_fehlende_pv_messung_ist_nicht_dunkel() -> None:
    proben = [
        SpeicherProbe(at=T0 + timedelta(minutes=i), pv_kw=None, battery_kw=-1.2, soc=0.5)
        for i in range(60)
    ]
    assert abschnitt(proben, KAP).laden_dunkel_kwh == 0.0


def test_der_verlust_ist_was_weder_herauskam_noch_ankam() -> None:
    # 2 kWh hinein, Ladestand steigt um 35 Prozentpunkte = 1,785 kWh. Verlust 0,215 kWh.
    a = abschnitt(reihe(120, batterie=-1.0, soc_start=0.2, soc_rate=0.175), KAP)
    assert a.delta_speicher_kwh == pytest.approx(0.35 * KAP, abs=0.03)
    assert a.verlust_kwh == pytest.approx(2.0 - 0.35 * KAP, abs=0.05)
    assert a.verlust_anteil == pytest.approx(0.107, abs=0.02)


# ------------------------------------------------------------------ Ruhe


def test_ruhe_findet_die_gemeldete_leistung_bei_stehendem_zeiger() -> None:
    # Vier Stunden: der Ladestand ruehrt sich nicht, die Messung meldet 0,12 kW Ladung.
    befund, voll = ruhe_befund(reihe(240, batterie=-0.12, soc_start=0.4))
    assert befund.strecken == 1 and befund.minuten == 240
    assert befund.mittel_kw == pytest.approx(0.12, abs=0.001)
    # Eine Stufe auf vier Stunden: 0,0025 kW. Die gemeldete Leistung ist ein Vielfaches davon.
    assert befund.schranke_kw == pytest.approx(0.01 / 4, abs=1e-4)
    assert voll == 0


def test_kurze_strecken_sagen_nichts() -> None:
    befund, _ = ruhe_befund(reihe(30, batterie=-0.12, soc_start=0.4))
    assert befund.minuten == 0 and befund.mittel_kw is None


def test_am_vollen_speicher_zaehlt_stillstand_nicht() -> None:
    befund, voll = ruhe_befund(reihe(240, batterie=-0.12, soc_start=0.99))
    assert befund.minuten == 0
    assert voll == 240


def test_eine_luecke_beendet_die_strecke() -> None:
    vorne = reihe(50, batterie=-0.12, soc_start=0.4)
    hinten = reihe(50, batterie=-0.12, soc_start=0.4, start_min=200)
    befund, _ = ruhe_befund(vorne + hinten)
    # Zwei Strecken zu je 50 Minuten, beide zu kurz: nichts zaehlt.
    assert befund.minuten == 0


# ------------------------------------------------------------------ Wirkungsgrad


def test_wirkungsgrad_aus_reinen_strecken() -> None:
    # Laden: 2 kWh hinein, 35 Punkte = 1,785 kWh angekommen → 89 %.
    laden = reihe(120, batterie=-1.0, soc_start=0.2, soc_rate=0.175)
    # Entladen: 30 Punkte = 1,53 kWh verloren, 1,4 kWh herausgekommen → 92 %.
    entladen = reihe(120, batterie=0.7, soc_start=0.55, soc_rate=-0.15, start_min=130)
    w = wirkungsgrade(laden + entladen, KAP)
    assert w.laden == pytest.approx(0.89, abs=0.03) and w.laden_strecken == 1
    assert w.entladen == pytest.approx(0.92, abs=0.04) and w.entladen_strecken == 1


def test_ohne_bewegung_im_ladestand_kein_wirkungsgrad() -> None:
    w = wirkungsgrade(reihe(240, batterie=-0.12, soc_start=0.4), KAP)
    assert w.laden is None and w.laden_strecken == 0


# ------------------------------------------------------------------ Die drei Welten


def _tag_gesund() -> list[SpeicherProbe]:
    """Speicher laedt mit 1 kW, Ladestand folgt mit 90 %, entlaedt wieder. Bilanz geht auf."""
    return reihe(180, batterie=-1.0, soc_start=0.2, soc_rate=0.176, pv=3.0) + reihe(
        240, batterie=0.65, soc_start=0.73, soc_rate=-0.138, start_min=180
    )


def test_welt_eins_gesunder_speicher_ist_unauffaellig() -> None:
    b = pruefe_speicher(_tag_gesund(), KAP)
    assert b.gesamt.verlust_anteil is not None and b.gesamt.verlust_anteil < 0.25
    assert "Unauffällig" in speicher_urteil(b)[0]


def test_welt_zwei_echte_netzladung_ist_unauffaellig() -> None:
    """Der Speicher laedt nachts wirklich aus dem Netz - der Ladestand steigt mit."""
    nacht = reihe(300, batterie=-1.0, soc_start=0.1, soc_rate=0.176)
    b = pruefe_speicher(nacht, KAP)
    assert b.gesamt.laden_dunkel_kwh == pytest.approx(5.0, abs=0.1)
    text = " ".join(speicher_urteil(b))
    assert "Unauffällig" in text
    # Die Prüfung widerspricht der Auswertung hier nicht: die Netzladung ist echt.


def test_welt_drei_das_geraet_verbraucht_es_selbst() -> None:
    """Dauerhafte 0,12 kW „Ladung", Ladestand ruehrt sich nicht - aber der Hub sieht den Strom."""
    # Haus = PV + Netz + Speicher ist erfuellt: das Restglied bleibt null.
    proben = reihe(600, batterie=-0.12, soc_start=0.4)
    b = pruefe_speicher(proben, KAP)
    text = " ".join(speicher_urteil(b))
    assert "Auffällig" in text
    assert "im Speicher nie angekommen" in text
    assert "Verbraucher, keine Ladung" in text
    assert "Stromwandler" not in text


def test_welt_vier_der_stromwandler_meldet_etwas_das_niemand_sieht() -> None:
    """Dieselbe Reihe, aber der Hub sieht die Leistung nicht: das Restglied klafft."""
    proben = [
        SpeicherProbe(
            at=T0 + timedelta(minutes=i),
            pv_kw=0.0,
            grid_kw=0.4,  # das Netz liefert nur den Hausverbrauch, keine Ladung
            battery_kw=-0.12,
            house_kw=0.4,
            soc=0.4,
        )
        for i in range(600)
    ]
    b = pruefe_speicher(proben, KAP)
    assert b.gesamt.restglied_kw == pytest.approx(-0.12, abs=1e-6)
    text = " ".join(speicher_urteil(b))
    assert "Auffällig" in text
    assert "Stromwandler" in text
    assert "Verbraucher, keine Ladung" not in text


def test_ohne_ladestand_sagt_die_pruefung_das_auch() -> None:
    proben = [
        SpeicherProbe(at=T0 + timedelta(minutes=i), pv_kw=0.0, battery_kw=-0.12) for i in range(600)
    ]
    b = pruefe_speicher(proben, KAP)
    assert b.gesamt.verlust_kwh is None
    assert "Kein Ladestand" in speicher_urteil(b)[0]


def test_tagesabschnitte_folgen_den_grenzen() -> None:
    proben = reihe(600, batterie=-0.12, soc_start=0.4)
    grenzen = [T0, T0 + timedelta(hours=5)]
    b = pruefe_speicher(proben, KAP, grenzen)
    assert len(b.tage) == 2
    assert b.tage[0].minuten == 300 and b.tage[1].minuten == 300


def test_teilabschnitte_addieren_sich_wie_der_ganze_zeitraum() -> None:
    proben = reihe(300, batterie=-1.0, soc_start=0.1, soc_rate=0.176)
    ganz = abschnitt(proben, KAP)
    teile = [abschnitt(proben[:120], KAP), abschnitt(proben[120:], KAP)]
    summe = summe_abschnitte(teile)
    assert summe.minuten == ganz.minuten
    assert summe.laden_kwh == pytest.approx(ganz.laden_kwh, abs=0.01)
    assert summe.laden_dunkel_kwh == pytest.approx(ganz.laden_dunkel_kwh, abs=0.01)
    assert summe.soc_von == ganz.soc_von and summe.soc_bis == ganz.soc_bis
    assert summe.delta_speicher_kwh == pytest.approx(ganz.delta_speicher_kwh or 0.0, abs=0.01)
    assert summe.restglied_kw == pytest.approx(ganz.restglied_kw or 0.0, abs=1e-6)


def test_die_summe_gewichtet_das_restglied_nach_minuten() -> None:
    viel = reihe(600, batterie=-0.12, soc_start=0.4)
    wenig = [
        SpeicherProbe(
            at=T0 + timedelta(minutes=700 + i),
            pv_kw=0.0,
            grid_kw=0.4,
            battery_kw=-0.12,
            house_kw=0.4,
            soc=0.4,
        )
        for i in range(20)
    ]
    summe = summe_abschnitte([abschnitt(viel, KAP), abschnitt(wenig, KAP)])
    # 600 Minuten mit Restglied 0 und 20 mit -0,12: das Mittel liegt nahe null, nicht bei -0,06.
    assert summe.restglied_kw == pytest.approx(-0.12 * 20 / 620, abs=1e-4)


def test_wirkungsgrade_addieren_sich() -> None:
    a = wirkungsgrade(reihe(120, batterie=-1.0, soc_start=0.2, soc_rate=0.175), KAP)
    b = wirkungsgrade(reihe(120, batterie=-1.0, soc_start=0.2, soc_rate=0.175, start_min=300), KAP)
    zusammen = a.plus(b)
    assert zusammen.laden_strecken == 2
    assert zusammen.laden == pytest.approx(a.laden or 0.0, abs=0.01)


# ------------------------------------------------------------------ Nachladung am leeren Speicher


def test_nachladung_am_leeren_speicher_wird_erkannt() -> None:
    # Der Speicher steht bei 1 %, holt sich 20 Minuten lang 1 kW aus dem Netz und faellt zurueck.
    leer = reihe(120, batterie=0.0, soc_start=0.01)
    hol = reihe(20, batterie=-1.0, soc_start=0.01, soc_rate=0.18, start_min=120)
    danach = reihe(180, batterie=0.0, soc_start=0.07, start_min=140)
    t = tief_nachladungen(leer + hol + danach)
    assert t.anzahl == 1
    assert t.kwh == pytest.approx(1.0 / 3, abs=0.02)
    assert t.beispiele[0].soc == pytest.approx(0.01, abs=1e-6)


def test_eine_ladung_bei_halbvollem_speicher_ist_keine_nachladung() -> None:
    assert tief_nachladungen(reihe(60, batterie=-1.0, soc_start=0.5, soc_rate=0.18)).anzahl == 0


def test_bei_sonne_ist_es_keine_netznachladung() -> None:
    hol = reihe(60, batterie=-1.0, soc_start=0.02, soc_rate=0.18, pv=2.0)
    assert tief_nachladungen(hol).anzahl == 0


def test_das_urteil_nennt_den_mechanismus() -> None:
    # Viele kleine Nachladungen am leeren Speicher, die nie wieder herauskommen.
    proben: list[SpeicherProbe] = []
    for runde in range(12):
        basis = runde * 120
        proben += reihe(100, batterie=0.0, soc_start=0.01, start_min=basis)
        proben += reihe(20, batterie=-1.0, soc_start=0.01, start_min=basis + 100)
    b = pruefe_speicher(proben, KAP)
    text = " ".join(speicher_urteil(b))
    assert "SoC Recovery" in text
    assert b.tief.anzahl == 12


# ------------------------------------------------------------------ Woran der Verlust haengt


def _tag_mit(aktiv_min: int, kw: float, grundlast_w: float, anteil: float, tag: int) -> Abschnitt:
    """Ein Tag, bei dem der Verlust nach Bauart aus Zeit und Menge entsteht."""
    laden = kw * aktiv_min / 60.0
    durchsatz = 2 * laden  # gleich viel hinein wie heraus
    verlust = grundlast_w / 1000.0 * aktiv_min / 60.0 + anteil * durchsatz
    # dSpeicher so gewaehlt, dass genau dieser Verlust herauskommt.
    delta = laden - laden - verlust
    return Abschnitt(
        von=T0 + timedelta(days=tag),
        bis=T0 + timedelta(days=tag, hours=23),
        minuten=1440,
        laden_kwh=laden,
        entladen_kwh=laden,
        laden_dunkel_kwh=0.0,
        soc_von=0.5,
        soc_bis=0.5 + delta / KAP,
        delta_speicher_kwh=delta,
        restglied_kw=None,
        restglied_minuten=0,
        aktiv_minuten=aktiv_min,
    )


def test_die_aufteilung_findet_grundlast_und_anteil_wieder() -> None:
    # Tage, die sich im Verhaeltnis von aktiver Zeit zu Durchsatz unterscheiden - sonst waere
    # die Gerade nicht bestimmt.
    tage = [
        _tag_mit(aktiv, kw, 120.0, 0.05, i)
        for i, (aktiv, kw) in enumerate(
            [(600, 0.5), (700, 1.2), (400, 2.0), (800, 0.4), (500, 1.5), (900, 0.8), (300, 2.4)]
        )
    ]
    a = aufteilung(tage)
    assert a.tage == 7
    assert a.grundlast_w == pytest.approx(120.0, abs=2.0)
    assert a.anteil == pytest.approx(0.05, abs=0.005)
    assert a.streuung_kwh is not None and a.streuung_kwh < 0.01


def test_ohne_genug_tage_keine_aufteilung() -> None:
    tage = [_tag_mit(600, 1.0, 120.0, 0.05, i) for i in range(3)]
    assert aufteilung(tage).grundlast_w is None


def test_ein_reiner_umwandlungsverlust_zeigt_keine_grundlast() -> None:
    tage = [
        _tag_mit(aktiv, kw, 0.0, 0.12, i)
        for i, (aktiv, kw) in enumerate(
            [(600, 0.5), (700, 1.2), (400, 2.0), (800, 0.4), (500, 1.5), (900, 0.8)]
        )
    ]
    a = aufteilung(tage)
    assert a.grundlast_w == pytest.approx(0.0, abs=2.0)
    assert a.anteil == pytest.approx(0.12, abs=0.005)


def test_aktive_minuten_zaehlen_nur_was_sich_bewegt() -> None:
    proben = reihe(60, batterie=-1.0, soc_start=0.3, soc_rate=0.18) + reihe(
        120, batterie=0.0, soc_start=0.48, start_min=60
    )
    a = abschnitt(proben, KAP)
    assert a.minuten == 180 and a.aktiv_minuten == 60
