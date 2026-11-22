"""Der Regelkreis des Hauses: Struktur, Entwurf nach SIMC, Schätzer und Übernahmeprüfung."""

from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta
from itertools import pairwise
from zoneinfo import ZoneInfo

import pytest

from hems_core.domain.config import HeatDemandConfig, HemsConfig, StoveConfig
from hems_core.regelkreis import entwurf, glied, karte, messung, parameter, schaetzer, struktur
from hems_core.thermal import kontaktwirkung
from hems_core.thermal.kennlinie import Ausgleich

T0 = datetime(2026, 6, 1, 12, 0, tzinfo=UTC)
CFG = HemsConfig()


# --------------------------------------------------------------------------- Struktur


def test_struktur_prueft_sich_selbst() -> None:
    """Keine doppelten Kennungen, keine Kante ins Leere, kein Regler ohne Kreis."""
    struktur.pruefe_struktur()


def test_jede_stoergroesse_sagt_wie_sie_behandelt_wird() -> None:
    """Der eigentliche Befund an einer Störgröße ist nicht ihr Name, sondern ob sie aufgeschaltet
    oder nur ausgeregelt wird. Fehlt die Angabe, ist die Karte unvollständig."""
    stoer = struktur.stoergroessen()
    assert len(stoer) >= 8
    for s in stoer:
        assert s.behandlung is not None
        assert s.quelle, f"{s.id} nennt keine Quelle"


def test_jeder_parameter_hat_einen_block_und_eine_begruendung() -> None:
    for pid, p in parameter.PARAMETER.items():
        assert p.block in struktur.NACH_ID, pid
        assert len(p.warum) > 30, pid
        assert p.unten < p.oben, pid


def test_jeder_startwert_loest_sich_auf_und_liegt_in_den_grenzen() -> None:
    """Ein Startwert, der außerhalb seiner eigenen Plausibilitätsgrenzen liegt, wäre ein Fehler im
    Register - die Übernahmeprüfung würde später jede Messung ablehnen, die ihn korrigiert."""
    for pid, wert in parameter.startwerte(CFG).items():
        p = parameter.PARAMETER[pid]
        assert p.unten <= wert <= p.oben, f"{pid}: {wert} nicht in [{p.unten}, {p.oben}]"


def test_startwert_folgt_der_konfiguration() -> None:
    """Wer die Wärmeannahmen auf der Einstellungsseite ändert, ändert den Startwert hier mit.
    Doppelt gepflegte Zahlen gibt es nicht."""
    assert parameter.startwert("h_haus", CFG) == pytest.approx(0.22)
    anders = CFG.model_copy(update={"heat_demand": HeatDemandConfig(heat_loss_kw_per_k=0.17)})
    assert parameter.startwert("h_haus", anders) == pytest.approx(0.17)


def test_verlustbeiwert_des_puffers_wird_in_watt_je_kelvin_gezeigt() -> None:
    """Die Konfiguration rechnet in kW/K, die Karte zeigt W/K - 0,004 kW/K sind 4 W/K."""
    assert parameter.startwert("puffer_ua", CFG) == pytest.approx(4.0)


def test_pufferkapazitaet_kommt_aus_dem_volumen() -> None:
    """1000 Liter Wasser sind 1,163 kWh/K. Geometrie, nichts zu lernen."""
    assert parameter.startwert("puffer_c", CFG) == pytest.approx(1.163, abs=0.001)


def test_cop_ebene_trifft_die_kennlinie_am_zielpunkt() -> None:
    """Die Konfiguration kennt den COP nur über der Außentemperatur, gültig bei Zieltemperatur des
    Puffers. Die Startebene muss sie dort treffen, sonst beginnt das Lernen mit einem Sprung."""
    a, b, c = parameter.cop_ebene(CFG)
    ziel = CFG.buffer.target_temperature_c
    for aussen, erwartet in CFG.heat_demand.cop_curve:
        gerade = a + b * aussen + c * ziel
        assert gerade == pytest.approx(erwartet, abs=0.25), aussen
    assert b > 0, "wärmer draußen muss mehr Arbeitszahl heißen"
    assert c < 0, "wärmerer Vorlauf muss weniger Arbeitszahl heißen"


# --------------------------------------------------------------------------- Entwurf


def test_simc_fuer_strecke_erster_ordnung_mit_totzeit() -> None:
    """Lehrbuchfall: K = 2, T1 = 10 min, Tt = 2 min, λ = 2 min.

    KR = T1/(K(λ+Tt)) = 10/(2·4) = 1,25.  Tn = min(T1, 4(λ+Tt)) = min(10, 16) = 10 min.
    """
    s = entwurf.Strecke(art="foptd", k=2.0, t1=10.0, totzeit=2.0)
    r = entwurf.simc(s, lam=2.0)
    assert r.kp == pytest.approx(1.25)
    assert r.tn == pytest.approx(10.0)


def test_simc_begrenzt_die_nachstellzeit_bei_traegen_strecken() -> None:
    """Bei T1 = 300 min und λ + Tt = 40 min greift die Begrenzung: Tn = 160 min statt 300.

    Das ist der Teil der Regel, der gegen Laststörungen hilft. Ohne ihn bliebe eine Störung am
    Estrich stundenlang stehen, weil der Integralanteil zu langsam arbeitet.
    """
    s = entwurf.Strecke(art="foptd", k=0.1, t1=300.0, totzeit=20.0)
    r = entwurf.simc(s, lam=20.0)
    assert r.tn == pytest.approx(160.0)


def test_simc_fuer_den_integrierer() -> None:
    """k′ = 0,1 K/min, Tt = 5 min, λ = 5 min: KR = 1/(0,1·10) = 1,0, Tn = 4·10 = 40 min."""
    s = entwurf.Strecke(art="iptd", k=0.1, totzeit=5.0)
    r = entwurf.simc(s, lam=5.0)
    assert r.kp == pytest.approx(1.0)
    assert r.tn == pytest.approx(40.0)


def test_halbregel_schlaegt_die_halbe_kleine_zeitkonstante_zu() -> None:
    """T1 = 300, T2 = 20, Tt = 20 → T1′ = 310, Tt′ = 30. Die Trägheit bleibt Trägheit, die
    verlorene Phase bleibt verlorene Phase."""
    s = entwurf.Strecke(art="foptd", k=1.0, t1=300.0, t2=20.0, totzeit=20.0)
    h = s.halbregel()
    assert h.t1 == pytest.approx(310.0)
    assert h.totzeit == pytest.approx(30.0)
    assert h.t2 == 0.0


def test_entwurf_verlangt_die_halbregel_vor_dem_rechnen() -> None:
    s = entwurf.Strecke(art="foptd", k=1.0, t1=300.0, t2=20.0, totzeit=20.0)
    with pytest.raises(ValueError, match="Halbregel"):
        entwurf.simc(s, lam=10.0)


def test_simc_laesst_dem_kreis_reserve() -> None:
    """Die Regel ist so gebaut, dass λ = Tt eine brauchbare Reserve gibt: über 45° Phase und mehr
    als Faktor zwei in der Amplitude. Das ist die Zusage, die den Entwurf ohne Handarbeit trägt."""
    s = entwurf.Strecke(art="foptd", k=2.0, t1=10.0, totzeit=2.0)
    r = entwurf.simc(s, lam=2.0)
    res = entwurf.reserven(r, s)
    assert res.durchtritt is not None
    assert res.phasenreserve is not None and res.phasenreserve > 45.0
    assert res.amplitudenreserve is not None and res.amplitudenreserve > 2.0
    assert res.gut


def test_groesseres_lambda_gibt_mehr_reserve_und_weniger_bandbreite() -> None:
    """Der Zielkonflikt des Entwurfs, in Zahlen: λ ist die eine Zahl, mit der man ihn einstellt."""
    s = entwurf.Strecke(art="iptd", k=0.15, totzeit=4.6)
    schnell = entwurf.reserven(entwurf.simc(s, lam=2.0), s)
    langsam = entwurf.reserven(entwurf.simc(s, lam=40.0), s)
    assert schnell.durchtritt is not None and langsam.durchtritt is not None
    assert schnell.durchtritt > langsam.durchtritt
    assert schnell.phasenreserve is not None and langsam.phasenreserve is not None
    assert langsam.phasenreserve > schnell.phasenreserve


def test_zu_kleines_lambda_frisst_die_reserve_auf() -> None:
    """Wer bei 4,6 Minuten Totzeit eine halbe Minute Ersatzzeitkonstante verlangt, bekommt einen
    Kreis ohne Reserve. Die Karte muss das sagen können, statt es zu verschweigen."""
    s = entwurf.Strecke(art="iptd", k=0.15, totzeit=4.6)
    res = entwurf.reserven(entwurf.simc(s, lam=0.2), s)
    assert res.phasenreserve is not None and res.phasenreserve < 45.0
    assert not res.gut


def test_phase_faellt_monoton_und_ohne_ruecksprung() -> None:
    """Die Phase einer Totzeit wächst ohne Grenze. Würde sie auf ±180° zurückgefaltet, wäre die
    Suche nach dem Durchtritt nicht eindeutig - deshalb wird sie summiert und nicht aus einem
    komplexen Zeiger gelesen."""
    s = entwurf.Strecke(art="foptd", k=1.0, t1=5.0, totzeit=3.0)
    r = entwurf.simc(s, lam=3.0)
    werte = [entwurf.phase_grad(r, s, w) for w in (0.001, 0.01, 0.1, 1.0, 10.0)]
    assert werte == sorted(werte, reverse=True)
    assert werte[-1] < -360.0


def test_hysterese_folgt_der_taktzahlgrenze() -> None:
    """Acht Starts am Tag sind 180 Minuten Zyklus. Mit 0,11 K/min Ladesteigung und 0,055 K/min
    Entladung: Δ = 180/(1/0,11 + 1/0,055) = 6,6 K.

    Mehr erlaubte Starts heißt engere Hysterese - das ist der Zielkonflikt zwischen Taktzahl und
    Temperaturband, und er wird gerechnet und nicht geraten.
    """
    breit = entwurf.hysterese(auf_k_min=0.11, ab_k_min=0.055, starts_je_tag=8)
    assert breit == pytest.approx(6.6, abs=0.1)
    eng = entwurf.hysterese(auf_k_min=0.11, ab_k_min=0.055, starts_je_tag=24)
    assert eng < breit


def test_hysterese_wird_breiter_wenn_mehr_entnommen_wird() -> None:
    """Steigt der Verbrauch, muss das Band breiter werden, sonst steigt die Taktzahl."""
    wenig = entwurf.hysterese(auf_k_min=0.11, ab_k_min=0.02, starts_je_tag=8)
    viel = entwurf.hysterese(auf_k_min=0.08, ab_k_min=0.05, starts_je_tag=8)
    assert viel > wenig


def test_raumstrecke_hat_den_estrich_als_dominante_zeitkonstante() -> None:
    """0,86 kWh/K mal 6,25 K/kW sind 5,4 Stunden - und die Luft dagegen eine Viertelstunde. Diese
    Spreizung ist der Grund, warum der Raumkreis eine Nachstellzeit in Stunden bekommt."""
    s = entwurf.raum_strecke(
        c_estrich_kwh_k=0.86,
        r_estrich_luft_k_kw=6.25,
        c_luft_kwh_k=0.052,
        h_raum_kw_k=0.029,
        q_max_kw=1.2,
        autoritaet=0.34,
        totzeit_min=22.0,
    )
    assert s.t1 / 60.0 == pytest.approx(5.4, abs=0.1)
    assert 10.0 < s.t2 < 25.0
    assert s.t1 > 10 * s.t2
    r = entwurf.simc(s.halbregel(), lam=30.0)
    assert r.tn / 60.0 > 2.0


def test_pufferstrecke_ist_ein_integrierer() -> None:
    """11,2 kW thermisch in 1,149 kWh/K sind 9,7 K/h, also 0,162 K je Minute und Freigabeeinheit."""
    s = entwurf.puffer_strecke(waerme_kw=11.2, kapazitaet_kwh_k=1.149, totzeit_min=4.6)
    assert s.art == "iptd"
    assert s.k == pytest.approx(0.162, abs=0.002)


# --------------------------------------------------------------------------- Schätzer


def _rauschen(i: int) -> float:
    """Reproduzierbares Rauschen. Ein Test, der an einem Zufallszahlengenerator hängt, ist kein
    Test, sondern eine Wette."""
    return 0.08 * math.sin(i * 2.399) + 0.03 * math.sin(i * 0.731)


def test_rls_findet_den_verlustkoeffizienten_zurueck() -> None:
    """Modell: Wärmestrom = H·ΔT − Q̇int, linear in H und Q̇int.

    Wahre Werte 0,186 kW/K und 0,62 kW, Startwerte 0,22 und 0,40 - so wie es im Haus steht. Nach
    zweihundert Nachtfenstern muss der Schätzer beide finden, und seine eigene Unsicherheit muss
    kleiner geworden sein als der Fehler, den er korrigiert hat.
    """
    r = schaetzer.Rls.start(theta0=[0.22, -0.40], sigma0=[0.05, 0.25], rauschen=0.1)
    assert r.sigma(0) == pytest.approx(0.05), (
        "am ersten Tag ist die Unsicherheit die des Startwerts"
    )
    assert r.rmse() is None, "einen Restfehler gibt es erst, wenn Residuen vorliegen"
    sigma_anfang = r.sigma(0)
    for i in range(200):
        d_t = 5.0 + (i % 17)
        y = 0.186 * d_t - 0.62 + _rauschen(i)
        r.schritt([d_t, 1.0], y, at=T0 + timedelta(hours=i))
    assert r.theta[0] == pytest.approx(0.186, abs=0.01)
    assert -r.theta[1] == pytest.approx(0.62, abs=0.08)
    assert r.sigma(0) < sigma_anfang / 5.0
    assert r.rmse() is not None and r.rmse() < 0.15
    assert r.n == 200
    assert r.stand == T0 + timedelta(hours=199)


def test_rls_folgt_einer_aenderung_des_hauses() -> None:
    """Nach der Dämmung ist H kleiner. Der Vergessensfaktor ist der Grund, warum der Schätzer das
    nachvollzieht, statt den alten Wert über Jahre mitzuschleppen."""
    r = schaetzer.Rls.start(theta0=[0.22, -0.40], sigma0=[0.05, 0.25], rauschen=0.1)
    for i in range(200):
        d_t = 5.0 + (i % 17)
        r.schritt([d_t, 1.0], 0.186 * d_t - 0.62 + _rauschen(i), at=T0 + timedelta(hours=i))
    alt = r.theta[0]
    assert alt == pytest.approx(0.186, abs=0.01)
    for i in range(200, 700):
        d_t = 5.0 + (i % 17)
        r.schritt([d_t, 1.0], 0.120 * d_t - 0.62 + _rauschen(i), at=T0 + timedelta(hours=i))
    assert r.theta[0] < alt
    assert r.theta[0] == pytest.approx(0.120, abs=0.012)


def test_rls_weist_den_falschen_regressor_ab() -> None:
    r = schaetzer.Rls.start(theta0=[1.0], sigma0=[1.0])
    with pytest.raises(ValueError, match="Regressor"):
        r.schritt([1.0, 2.0], 3.0)


def test_ewma_zieht_den_prognosefaktor_in_richtung_messung() -> None:
    e = schaetzer.EwmaVerhaeltnis(halbwertszeit_tage=10.0)
    for i in range(40):
        e.schritt(ist=9.3, erwartet=10.0, at=T0 + timedelta(days=i))
    assert e.wert == pytest.approx(0.93, abs=0.01)


# --------------------------------------------------------------- Übernahmeprüfung


def test_uebernahme_bei_belegter_abweichung() -> None:
    p = schaetzer.pruefe(
        "h_haus",
        geltend=0.22,
        kandidat=0.186,
        sigma=0.004,
        n=120,
        tage_seit_uebernahme=None,
        rmse_alt=1.0,
        rmse_neu=0.8,
    )
    assert p.uebernehmen and p.code == "uebernommen"
    assert "kleiner" in p.grund


def test_keine_uebernahme_ohne_daten() -> None:
    p = schaetzer.pruefe("h_haus", geltend=0.22, kandidat=0.186, sigma=0.004, n=5)
    assert not p.uebernehmen and p.code == "zu_wenig_daten"
    assert "Stützstellen" in p.grund


def test_keine_uebernahme_innerhalb_der_unsicherheit() -> None:
    """Der Kandidat weicht ab, aber nicht mehr als seine eigene Unsicherheit. Dann ist die
    Abweichung Rauschen und kein Befund."""
    p = schaetzer.pruefe("h_haus", geltend=0.22, kandidat=0.215, sigma=0.02, n=120)
    assert not p.uebernehmen and p.code == "innerhalb_unsicherheit"


def test_keine_uebernahme_vor_ablauf_der_wartezeit() -> None:
    p = schaetzer.pruefe(
        "h_haus", geltend=0.22, kandidat=0.186, sigma=0.004, n=120, tage_seit_uebernahme=3.0
    )
    assert not p.uebernehmen and p.code == "zu_frueh"


def test_kandidat_ausserhalb_der_grenzen_wird_abgelehnt_und_nicht_beschnitten() -> None:
    """Ein Verlustkoeffizient von 2 kW/K ist kein Erkenntnisgewinn, sondern ein Fühlerausfall. Er
    wird gemeldet und nicht stillschweigend auf die Grenze gezogen."""
    p = schaetzer.pruefe("h_haus", geltend=0.22, kandidat=2.0, sigma=0.01, n=500)
    assert not p.uebernehmen and p.code == "grenzen"
    assert "Plausibilitätsgrenzen" in p.grund


def test_keine_uebernahme_ohne_guetegewinn() -> None:
    p = schaetzer.pruefe(
        "h_haus",
        geltend=0.22,
        kandidat=0.186,
        sigma=0.004,
        n=120,
        tage_seit_uebernahme=30.0,
        rmse_alt=1.0,
        rmse_neu=0.999,
    )
    assert not p.uebernehmen and p.code == "nicht_besser"


def test_jeder_pruefcode_hat_einen_eigenen_satz() -> None:
    """Wie bei den Reason-Codes des Reglers: kein Code ohne deutschen Satz, keine zwei Codes mit
    demselben."""
    saetze = {
        schaetzer.pruefe("h_haus", geltend=0.22, kandidat=0.186, sigma=0.004, n=5).grund,
        schaetzer.pruefe("h_haus", geltend=0.22, kandidat=2.0, sigma=0.01, n=500).grund,
        schaetzer.pruefe("h_haus", geltend=0.22, kandidat=0.215, sigma=0.02, n=120).grund,
        schaetzer.pruefe(
            "h_haus", geltend=0.22, kandidat=0.186, sigma=0.004, n=120, tage_seit_uebernahme=3.0
        ).grund,
        schaetzer.pruefe(
            "h_haus",
            geltend=0.22,
            kandidat=0.186,
            sigma=0.004,
            n=120,
            tage_seit_uebernahme=30.0,
            rmse_alt=1.0,
            rmse_neu=0.999,
        ).grund,
        schaetzer.pruefe(
            "h_haus", geltend=0.22, kandidat=0.186, sigma=0.004, n=120, rmse_alt=1.0, rmse_neu=0.7
        ).grund,
    }
    assert len(saetze) == 6


# --------------------------------------------------------------- Schätzstand


def test_meldung_uebernimmt_und_schreibt_das_protokoll() -> None:
    stand = schaetzer.Schaetzstand()
    p = stand.melde("h_haus", kandidat=0.186, sigma=0.004, n=120, jetzt=T0, startwert=0.22)
    assert p.uebernehmen
    eintrag = stand.parameter["h_haus"]
    assert eintrag.geltend == pytest.approx(0.186)
    assert len(eintrag.protokoll) == 1
    assert eintrag.protokoll[0].alt == pytest.approx(0.22)
    assert eintrag.protokoll[0].neu == pytest.approx(0.186)
    assert stand.seit == T0


def test_zweite_meldung_wartet_die_frist_ab() -> None:
    """Zwei Übernahmen in derselben Woche wären kein Lernen, sondern ein Zittern."""
    stand = schaetzer.Schaetzstand()
    stand.melde("h_haus", kandidat=0.186, sigma=0.004, n=120, jetzt=T0, startwert=0.22)
    p = stand.melde(
        "h_haus",
        kandidat=0.150,
        sigma=0.004,
        n=200,
        jetzt=T0 + timedelta(days=3),
        startwert=0.22,
    )
    assert not p.uebernehmen and p.code == "zu_frueh"
    assert stand.parameter["h_haus"].geltend == pytest.approx(0.186)
    # Die Schätzung wird trotzdem mitgeschrieben - sonst wäre nicht zu sehen, was er gesagt hätte.
    assert stand.parameter["h_haus"].schaetzung == pytest.approx(0.150)


def test_uebersteuerung_haelt_die_uebernahme_an_und_gewinnt() -> None:
    stand = schaetzer.Schaetzstand()
    stand.uebersteuere("h_haus", 0.25)
    stand.melde("h_haus", kandidat=0.186, sigma=0.004, n=120, jetzt=T0, startwert=0.22)
    assert stand.wert("h_haus", 0.22) == pytest.approx(0.25)
    assert not stand.parameter["h_haus"].protokoll
    stand.freigeben("h_haus")
    assert stand.wert("h_haus", 0.22) == pytest.approx(0.22)


def test_uebersteuerung_wird_auf_die_grenzen_beschnitten() -> None:
    """Hier wird beschnitten und nicht abgelehnt: ein Mensch, der 9 kW/K eintippt, hat sich
    vertippt, und die Regelung soll trotzdem weiterlaufen."""
    stand = schaetzer.Schaetzstand()
    stand.uebersteuere("h_haus", 9.0)
    assert stand.wert("h_haus", 0.22) == pytest.approx(parameter.PARAMETER["h_haus"].oben)


def test_schaetzstand_ist_serialisierbar() -> None:
    """Er liegt im Betrieb als ein Eintrag in model_calibrations. Was nicht durch JSON geht, ist
    nach dem nächsten Neustart verloren."""
    stand = schaetzer.Schaetzstand()
    stand.melde("h_haus", kandidat=0.186, sigma=0.004, n=120, jetzt=T0, startwert=0.22)
    stand.uebersteuere("cop_a", 3.9)
    stand.rls["waermebedarf"] = schaetzer.Rls.start([0.22, -0.4], [0.05, 0.25])
    roh = stand.model_dump(mode="json")
    zurueck = schaetzer.Schaetzstand.model_validate(roh)
    assert zurueck.parameter["h_haus"].geltend == pytest.approx(0.186)
    assert zurueck.uebersteuert["cop_a"] == pytest.approx(3.9)
    assert zurueck.rls["waermebedarf"].theta == [0.22, -0.4]
    assert zurueck.seit == T0


def test_protokoll_waechst_nicht_unbegrenzt() -> None:
    stand = schaetzer.Schaetzstand()
    wert = 0.22
    for i in range(60):
        wert = 0.22 if i % 2 else 0.30
        stand.melde(
            "h_haus",
            kandidat=wert,
            sigma=0.004,
            n=500,
            jetzt=T0 + timedelta(days=20 * i),
            startwert=0.22,
        )
    assert len(stand.parameter["h_haus"].protokoll) == schaetzer.PROTOKOLL_LAENGE


# --------------------------------------------------------------------------- Karte


def test_karte_nennt_den_arbeitspunkt_und_die_herkunft_jeder_zahl() -> None:
    """Ohne Messung gilt der Auslegungspunkt, und die Karte sagt das: `gemessen` ist falsch.

    Am Anfang ist keine Zahl gemessen. Die Karte muss das zugeben, statt Annahmen wie Messungen
    aussehen zu lassen - das ist der ganze Zweck der Spalte.
    """
    k = karte.aufbauen(CFG, schaetzer.Schaetzstand(), jetzt=T0)
    assert not k.arbeitspunkt.aussen_gemessen
    assert k.tage is None
    herkunft = {p.id: p.herkunft for p in k.parameter}
    assert herkunft["h_haus"] == "annahme"
    assert herkunft["puffer_c"] == "fest"
    assert herkunft["lam_r2"] == "entwurf"
    assert k.uebernahmen == 0


def test_vorlaufsollwert_folgt_der_heizkennlinie() -> None:
    """Bei 21 °C Sollwert, Steilheit 1,2 und 0 °C draußen: 21 + 1,2·21^1,1 = 52,5 °C, begrenzt auf
    die Höchsttemperatur des Puffers. Eine zu steile Kennlinie kostet jeden Tag Arbeitszahl."""
    w = karte.werte(CFG, schaetzer.Schaetzstand())
    kalt = karte.vorlauf_sollwert(CFG, w, 0.0)
    mild = karte.vorlauf_sollwert(CFG, w, 14.0)
    assert kalt > mild >= 26.0
    assert kalt <= CFG.buffer.max_temperature_c


def test_karte_trennt_gemessen_von_geschaetzt() -> None:
    """Gemessen heißt: unmittelbar aus Messwerten abgelesen - die Ausgleichsebene aus Wärme und
    Strom, die Anlaufverzögerung aus dem Abstand zweier Zeitpunkte. Geschätzt heißt: durch ein
    Modell hindurch, das selbst Annahmen enthält. Der Verlustbeiwert des Speichers rechnet gegen
    eine angenommene Aufstellraumtemperatur und gehört deshalb in die zweite Gruppe."""
    stand = schaetzer.Schaetzstand()
    stand.melde("cop_a", kandidat=3.9, sigma=0.05, n=400, jetzt=T0, startwert=5.0)
    stand.melde("wp_totzeit", kandidat=4.6, sigma=0.3, n=40, jetzt=T0, startwert=3.0)
    stand.melde("h_haus", kandidat=0.186, sigma=0.004, n=120, jetzt=T0, startwert=0.22)
    stand.melde("puffer_ua", kandidat=5.6, sigma=0.4, n=35, jetzt=T0, startwert=4.0)
    k = karte.aufbauen(CFG, stand, jetzt=T0)
    herkunft = {p.id: p.herkunft for p in k.parameter}
    assert herkunft["cop_a"] == "gemessen"
    assert herkunft["wp_totzeit"] == "gemessen"
    assert herkunft["h_haus"] == "geschaetzt"
    assert herkunft["puffer_ua"] == "geschaetzt"
    assert k.uebernahmen == 4


def test_jede_schaetzart_hat_einen_satz() -> None:
    """Die Oberfläche zeigt neben jedem Parameter, wie er gewonnen wird. Ein Verfahren ohne Satz
    stünde dort als leere Zeile - und eine Beschreibung, die nicht zum Verfahren passt, wäre
    schlimmer: die drei Größen der Wärmebilanz kommen aus einem gleitenden Fenster und nicht aus
    einem rekursiven Schätzer."""
    for p in parameter.PARAMETER.values():
        assert p.schaetzart in parameter.SCHAETZART_TEXT
        assert len(parameter.SCHAETZART_TEXT[p.schaetzart]) > 20
    assert parameter.PARAMETER["h_haus"].schaetzart == "fenster"
    assert parameter.PARAMETER["puffer_ua"].schaetzart == "stillstand"


def test_karte_entwirft_die_regler_aus_den_geltenden_parametern() -> None:
    """Der Beleg für den selbsteinstellenden Teil: eine längere Totzeit der Wärmepumpe macht den
    Pufferregler schwächer, ohne dass jemand am Regler dreht."""
    stand = schaetzer.Schaetzstand()
    vorher = karte.aufbauen(CFG, stand, jetzt=T0)
    stand.uebersteuere("wp_totzeit", 12.0)
    nachher = karte.aufbauen(CFG, stand, jetzt=T0)
    r2_vorher = next(k for k in vorher.kreise if k.id == "R2")
    r2_nachher = next(k for k in nachher.kreise if k.id == "R2")
    assert r2_vorher.regler is not None and r2_nachher.regler is not None
    assert r2_nachher.regler.kp < r2_vorher.regler.kp
    assert r2_nachher.regler.tn > r2_vorher.regler.tn
    assert "wp_totzeit" in nachher.uebersteuert


def test_karte_warnt_wenn_die_reserve_zu_klein_wird() -> None:
    stand = schaetzer.Schaetzstand()
    stand.uebersteuere("lam_r2", 2.0)
    k = karte.aufbauen(CFG, stand, jetzt=T0)
    r2 = next(x for x in k.kreise if x.id == "R2")
    assert r2.reserven is not None and not r2.reserven.gut
    assert r2.hinweis is not None and "Phasenreserve" in r2.hinweis


def test_hybride_kreise_bekommen_keine_frequenzkennlinie() -> None:
    """Die Zuordnung ist eine Entscheidung zwischen zwei Maschinen mit Mindestzeiten, der Fahrplan
    ein gleitender Horizont. Eine Phasenreserve wäre dort eine Zahl ohne Bedeutung."""
    k = karte.aufbauen(CFG, schaetzer.Schaetzstand(), jetzt=T0)
    for kreis in k.kreise:
        if kreis.art in ("hybrid", "planung"):
            assert kreis.regler is None and kreis.reserven is None and not kreis.kennlinie
        else:
            assert kreis.regler is not None and kreis.kennlinie


def test_nur_der_zweipunktregler_hat_eine_hysterese() -> None:
    k = karte.aufbauen(CFG, schaetzer.Schaetzstand(), jetzt=T0)
    mit = {kreis.id for kreis in k.kreise if kreis.hysterese_k is not None}
    assert mit == {"R2"}
    r2 = next(x for x in k.kreise if x.id == "R2")
    assert r2.hysterese_k is not None and 1.0 <= r2.hysterese_k <= 15.0


def test_umschaltpunkt_wandert_mit_dem_strompreis() -> None:
    """Die Zahl, die ein Mensch behalten kann: unterhalb dieser Außentemperatur ist der Ofen die
    billigere Kilowattstunde. Bei hohem Strompreis liegt sie höher."""
    stand = schaetzer.Schaetzstand()
    guenstig = karte.aufbauen(
        CFG,
        stand,
        jetzt=T0,
        arbeitspunkt=karte.Arbeitspunkt(
            aussen_c=2.0, vorlauf_c=38.0, strompreis_eur_kwh=0.12, aussen_gemessen=True
        ),
    )
    teuer = karte.aufbauen(
        CFG,
        stand,
        jetzt=T0,
        arbeitspunkt=karte.Arbeitspunkt(
            aussen_c=2.0, vorlauf_c=38.0, strompreis_eur_kwh=0.42, aussen_gemessen=True
        ),
    )
    assert guenstig.kosten.waermepumpe_ct_kwh < guenstig.kosten.ofen_ct_kwh
    assert teuer.kosten.cop_umschalt > guenstig.kosten.cop_umschalt
    assert teuer.kosten.umschalt_aussen_c is not None
    if guenstig.kosten.umschalt_aussen_c is not None:
        assert teuer.kosten.umschalt_aussen_c > guenstig.kosten.umschalt_aussen_c


def test_ofenkosten_folgen_dem_pelletpreis_und_dem_wirkungsgrad() -> None:
    """450 €/t bei 4,9 kWh/kg und 91,1 % sind 10,1 ct je Kilowattstunde Wärme."""
    w = karte.werte(CFG, schaetzer.Schaetzstand())
    assert karte.ofen_kosten_eur_kwh(CFG, w) * 100 == pytest.approx(10.1, abs=0.1)
    teuer = CFG.model_copy(update={"stove": StoveConfig(pellet_price_eur_per_t=600.0)})
    w2 = karte.werte(teuer, schaetzer.Schaetzstand())
    assert karte.ofen_kosten_eur_kwh(teuer, w2) > karte.ofen_kosten_eur_kwh(CFG, w)


def test_kaelterer_tag_senkt_die_verstaerkung_des_erzeugers() -> None:
    """Verstärkungsplanung, sichtbar gemacht: dieselbe Anlage, zwei Tage, zwei Regler."""
    stand = schaetzer.Schaetzstand()
    mild = karte.aufbauen(
        CFG,
        stand,
        jetzt=T0,
        arbeitspunkt=karte.Arbeitspunkt(
            aussen_c=10.0, vorlauf_c=32.0, strompreis_eur_kwh=0.3, aussen_gemessen=True
        ),
    )
    kalt = karte.aufbauen(
        CFG,
        stand,
        jetzt=T0,
        arbeitspunkt=karte.Arbeitspunkt(
            aussen_c=-8.0, vorlauf_c=46.0, strompreis_eur_kwh=0.3, aussen_gemessen=True
        ),
    )
    assert kalt.kosten.cop < mild.kosten.cop
    r2_mild = next(k for k in mild.kreise if k.id == "R2")
    r2_kalt = next(k for k in kalt.kreise if k.id == "R2")
    assert r2_mild.strecke is not None and r2_kalt.strecke is not None
    assert r2_kalt.strecke.k < r2_mild.strecke.k
    assert r2_kalt.regler is not None and r2_mild.regler is not None
    assert r2_kalt.regler.kp > r2_mild.regler.kp


def test_jeder_block_der_karte_hat_text_und_jede_kante_ein_ziel() -> None:
    k = karte.aufbauen(CFG, schaetzer.Schaetzstand(), jetzt=T0)
    kennungen = {b.id for b in k.bloecke}
    for kante in k.kanten:
        assert kante.von in kennungen and kante.nach in kennungen
    for b in k.bloecke:
        if b.rolle != "summierstelle":
            assert b.erklaerung, b.id
    blockparameter = {pid for b in k.bloecke for pid in b.parameter}
    assert blockparameter == set(parameter.PARAMETER)


# --------------------------------------------------------------- Aus bestehenden Auswertungen


def test_kandidaten_aus_der_gemessenen_kennlinie() -> None:
    """Die Ausgleichsebene liefert a, b und c samt Restfehler - also genau das, was der Entwurf
    braucht. Die Unsicherheit der Steigung hängt an der Spanne der Punkte: eine Kennlinie aus
    einer einzigen Kältewoche gibt die Vorlaufabhängigkeit nicht her."""
    a = Ausgleich(
        art="ebene",
        a=3.93,
        b_aussen=0.16,
        c_vorlauf=-0.035,
        n=120,
        rmse=0.18,
        r2=0.86,
        aussen_von_c=-6.0,
        aussen_bis_c=14.0,
        vorlauf_von_c=30.0,
        vorlauf_bis_c=48.0,
    )
    kandidaten = {k.pid: k for k in messung.aus_kennlinie(a)}
    assert set(kandidaten) == {"cop_a", "cop_b", "cop_c"}
    assert kandidaten["cop_b"].wert == pytest.approx(0.16)
    assert kandidaten["cop_b"].n == 120
    assert kandidaten["cop_b"].rmse == pytest.approx(0.18)
    assert 0.0 < kandidaten["cop_b"].sigma < 0.01


def test_kennlinie_ohne_vorlaufspanne_schlaegt_c_nicht_vor() -> None:
    """`ausgleich` setzt einen Term auf null, den die Punkte nicht hergeben. Eine Null ist keine
    Messung und darf deshalb nicht als Kandidat auftreten."""
    a = Ausgleich(
        art="aussen",
        a=3.9,
        b_aussen=0.16,
        c_vorlauf=0.0,
        n=40,
        rmse=0.2,
        r2=0.7,
        aussen_von_c=-2.0,
        aussen_bis_c=9.0,
        vorlauf_von_c=37.0,
        vorlauf_bis_c=37.4,
    )
    assert {k.pid for k in messung.aus_kennlinie(a)} == {"cop_a", "cop_b"}


def _vergleich() -> kontaktwirkung.Vergleich:
    return kontaktwirkung.Vergleich(
        n=40, gefolgt=6, quote_gesamt=0.15, quote=0.14, ereignisse_gedeckt=9
    )


def _ereignis(verzug: int | None) -> kontaktwirkung.Ereignis:
    return kontaktwirkung.Ereignis(
        at=T0,
        lief_schon=False,
        auswertbar=True,
        gefolgt=verzug is not None,
        verzoegerung_min=verzug,
        kontakt_min=30,
        kw=[],
    )


def test_totzeit_und_zeitkonstante_aus_der_ereignisstudie() -> None:
    """Zehn Schließvorgänge mit Anlaufverzögerungen um vier bis sechs Minuten, und ein Fächer,
    dessen Median nach gut fünfzehn Minuten 63 % seines Endwerts erreicht.

    Erwartet: Totzeit 5 min (Median, nicht Mittel - der Ausreißer mit 19 Minuten darf sie nicht
    tragen), Zeitkonstante die Differenz bis zur Schwelle.
    """
    minuten = list(range(-30, 121))
    median: list[float | None] = []
    for m in minuten:
        if m < 0 or m < 5:
            median.append(0.05)
        else:
            median.append(0.05 + 3.8 * (1.0 - math.exp(-(m - 5) / 11.0)))
    w = kontaktwirkung.Kontaktwirkung(
        von=T0,
        bis=T0 + timedelta(days=14),
        schwelle_kw=0.5,
        ereignisse=[_ereignis(v) for v in (4, 5, 4, 6, 5, 5, 4, 6, 19, 5)],
        faecher=kontaktwirkung.Faecher(
            minuten=minuten,
            median_kw=median,
            q25_kw=median,
            q75_kw=median,
            anteil_laeuft=[None] * len(minuten),
            n=[10] * len(minuten),
        ),
        n=10,
        n_auswertbar=10,
        gefolgt=10,
        verzoegerung_median_min=5.0,
        vergleich=_vergleich(),
    )
    kandidaten = {k.pid: k for k in messung.aus_kontaktwirkung(w)}
    assert kandidaten["wp_totzeit"].wert == pytest.approx(5.0)
    assert kandidaten["wp_totzeit"].n == 10
    assert kandidaten["wp_t1"].wert == pytest.approx(11.0, abs=2.0)


def test_zu_wenige_ereignisse_geben_keine_totzeit() -> None:
    w = kontaktwirkung.Kontaktwirkung(
        von=T0,
        bis=T0,
        schwelle_kw=0.5,
        ereignisse=[_ereignis(5) for _ in range(3)],
        faecher=kontaktwirkung.Faecher(
            minuten=[], median_kw=[], q25_kw=[], q75_kw=[], anteil_laeuft=[], n=[]
        ),
        vergleich=_vergleich(),
    )
    assert messung.aus_kontaktwirkung(w) == []


def test_verlustbeiwert_aus_einer_nacht_ohne_betrieb() -> None:
    """1,163 kWh/K, 0,15 K/h Abkühlung bei 30 K Übertemperatur: UA = 1,163·0,15/30 = 5,8 W/K.

    Die saubere Messung der Wärmeseite, weil in dieser Nacht alles andere stillsteht.
    """
    k = messung.aus_abkuehlung(
        kelvin_je_stunde=0.15,
        uebertemperatur_k=30.0,
        kapazitaet_kwh_k=1.163,
        stunden=6.0,
        streuung_k_je_stunde=0.02,
    )
    assert k is not None
    assert k.pid == "puffer_ua"
    assert k.wert == pytest.approx(5.8, abs=0.1)
    assert k.sigma == pytest.approx(0.78, abs=0.1)


def test_nacht_ohne_uebertemperatur_gibt_nichts_her() -> None:
    assert (
        messung.aus_abkuehlung(
            kelvin_je_stunde=0.15,
            uebertemperatur_k=2.0,
            kapazitaet_kwh_k=1.163,
            stunden=6.0,
            streuung_k_je_stunde=0.02,
        )
        is None
    )


def test_kandidaten_tragen_die_kennungen_des_registers() -> None:
    """Ein Kandidat für einen Parameter, den das Register nicht kennt, würde in der Prüfung mit
    einem KeyError auffallen - besser hier."""
    a = Ausgleich(
        art="ebene",
        a=3.9,
        b_aussen=0.16,
        c_vorlauf=-0.035,
        n=50,
        rmse=0.2,
        r2=0.8,
        aussen_von_c=-5.0,
        aussen_bis_c=12.0,
        vorlauf_von_c=31.0,
        vorlauf_bis_c=47.0,
    )
    for k in messung.aus_kennlinie(a):
        assert k.pid in parameter.PARAMETER


# --------------------------------------------------------------- Übertragungsglieder


def test_jeder_block_sagt_was_fuer_ein_glied_er_ist() -> None:
    """Störgrößen und Summierstellen ausgenommen: eine Störgröße ist kein Glied, sondern ein
    Eingang, und eine Summierstelle überträgt nicht, sie addiert."""
    for b in struktur.BLOECKE:
        if b.rolle in ("stoergroesse", "summierstelle"):
            assert b.glied is None, b.id
        else:
            assert b.glied in glied.GLIEDER, b.id


def test_der_pufferkreis_nennt_entwurf_und_ausfuehrung_getrennt() -> None:
    """Ausgelegt wird ein PI-Regler, ausgeführt wird ein Zweipunktregler. Wer nur das eine sieht,
    versteht entweder die Hysterese nicht oder die Einstellregel nicht."""
    b = struktur.NACH_ID["puffer_regler"]
    assert b.glied == "zweipunkt"
    assert b.glied_entwurf == "pi_regler"


def test_der_puffer_ist_ein_integrierer_mit_verzoegerungskette() -> None:
    """Die Einordnung, aus der der ganze Entwurf folgt: über die Energie ein Integrierer, über die
    Schichtung eine Kette. Ein Verzögerungsglied wäre die falsche Behauptung - wer die Freigabe
    stehen lässt, kocht den Speicher, er läuft nicht in einen Endwert."""
    assert struktur.NACH_ID["puffer"].glied == "itn"
    assert glied.GLIEDER["itn"].kategorie == "strecke"


def test_jedes_glied_hat_eine_kurve_im_einheitsquadrat() -> None:
    """Die Bilder sind gerechnet und nicht gemalt; sie müssen in ihr Kästchen passen."""
    for g in glied.GLIEDER.values():
        assert len(g.kurve) >= 3, g.id
        for x, y in (*g.kurve, *g.kurve2):
            assert -0.01 <= x <= 1.01, (g.id, x)
            assert -0.01 <= y <= 1.01, (g.id, y)
        assert g.g_s and g.erkennen


def test_die_sprungantworten_haben_die_form_ihres_glieds() -> None:
    """Die Probe aufs Exempel: ein PT1 steigt am Anfang am steilsten, ein PT2 beginnt flach, ein
    Totzeitglied tut erst gar nichts, und ein Integrierer kommt nie zum Stillstand."""

    def wert(gid: str, x: float) -> float:
        """Zwischen den Stützstellen geradlinig - so zeichnet die Anzeige die Kurve auch."""
        punkte = glied.GLIEDER[gid].kurve
        for (x0, y0), (x1, y1) in pairwise(punkte):
            if x0 <= x <= x1:
                f = 0.0 if x1 == x0 else (x - x0) / (x1 - x0)
                return y0 + f * (y1 - y0)
        return punkte[-1][1]

    # PT1: nach einem Viertel der Zeit schon mehr als die Hälfte des Endwerts.
    assert wert("pt1", 0.4) > 0.5 * wert("pt1", 1.0)
    # PT2: zu diesem Zeitpunkt deutlich weniger - der Wendepunkt liegt später.
    assert wert("pt2_tt", 0.4) < wert("pt1", 0.4)
    # Totzeit: am Anfang genau null.
    assert wert("tt", 0.2) == 0.0
    assert wert("tt", 0.9) > 0.5
    # Integrierer: steigt bis zum Rand.
    assert wert("i", 1.0) > wert("i", 0.6) > wert("i", 0.3)
    # PI-Regler: springt sofort und steigt danach weiter.
    assert wert("pi_regler", 0.13) > 0.2
    assert wert("pi_regler", 1.0) > wert("pi_regler", 0.13)


def test_nichtlineare_glieder_zeigen_eine_kennlinie_statt_einer_sprungantwort() -> None:
    """Bei einer Begrenzung ist die Zeit nicht interessant, die Krümmung sehr."""
    for gid in ("begrenzung", "auswahl", "p_kennlinie", "p_kennfeld", "hysterese"):
        assert glied.GLIEDER[gid].art == "kennlinie"
        assert glied.GLIEDER[gid].nichtlinear


def test_die_karte_liefert_den_katalog_der_vorkommenden_glieder() -> None:
    k = karte.aufbauen(CFG, schaetzer.Schaetzstand(), jetzt=T0)
    katalog = {g.id for g in k.glieder}
    benutzt = {b.glied for b in k.bloecke if b.glied} | {
        b.glied_entwurf for b in k.bloecke if b.glied_entwurf
    }
    assert katalog == benutzt
    assert "itn" in katalog and "zweipunkt" in katalog and "pi_regler" in katalog


def test_umschaltpunkt_ausserhalb_der_hausgrenzen_wird_nicht_gemeldet() -> None:
    """Bei billigem Strom liegt der rechnerische Schnittpunkt bei minus zwanzig Grad. Dort gilt
    die COP-Ebene nicht mehr, und die Zahl liest sich wie eine Auskunft, ohne eine zu sein."""
    stand = schaetzer.Schaetzstand()
    guenstig = karte.aufbauen(
        CFG,
        stand,
        jetzt=T0,
        arbeitspunkt=karte.Arbeitspunkt(
            aussen_c=6.0, vorlauf_c=40.0, strompreis_eur_kwh=0.08, aussen_gemessen=True
        ),
    )
    assert guenstig.kosten.umschalt_aussen_c is None
    assert guenstig.kosten.cop_umschalt < 1.5


# --------------------------------------------------- Schätzer über der Wärmebilanz

BERLIN = ZoneInfo("Europe/Berlin")
#: Die Zahlen, die der Schätzer wiederfinden soll - dieselben, die das Haus vermutlich hat.
H_WAHR = 0.186
INT_WAHR = 0.62
WW_WAHR = 6.4


def _bilanz_reihe(tage: int = 6, rauschen: float = 0.0) -> tuple[list, list]:
    """Minutenreihe eines Hauses, das sich genau an das Modell hält.

    Die Außentemperatur wandert über die Tage und über den Tag, damit die Steigung bestimmt ist;
    ohne Spanne in der Temperaturdifferenz ließe sich H nicht von den Gewinnen trennen.
    """
    from hems_core.thermal.heat_balance import HeatPoint, HeatSample

    profil = list(HeatDemandConfig().dhw_profile)
    gewicht = [w / sum(profil) for w in profil]
    proben: list[HeatSample] = []
    punkte: list[HeatPoint] = []
    start = datetime(2026, 1, 5, 0, 0, tzinfo=BERLIN)
    for stunde in range(tage * 24):
        at = start + timedelta(hours=stunde)
        tag = stunde // 24
        aussen = -4.0 + 2.6 * tag + 4.0 * math.sin(stunde * math.pi / 12.0)
        bedarf = (
            H_WAHR * (21.0 - aussen)
            - INT_WAHR
            + WW_WAHR * gewicht[at.hour]
            + rauschen * math.sin(stunde * 2.399)
        )
        for minute in range(60):
            proben.append(HeatSample(at=at + timedelta(minutes=minute), outdoor_c=aussen))
            punkte.append(HeatPoint(at=at + timedelta(minutes=minute), draw_kw=max(0.0, bedarf)))
    return proben, punkte


def test_waermebilanz_findet_verlust_gewinne_und_warmwasser() -> None:
    """Drei Größen aus einer Reihe: die Steigung über der Temperaturdifferenz ist H, der
    Achsabschnitt sind die inneren Gewinne, und die Form des Tages ist das Warmwasser.

    Wer nur gegen die Temperaturdifferenz anpasst, schreibt die Zapfungen in den
    Verlustkoeffizienten hinein - das Haus sähe undichter aus, als es ist.
    """
    proben, punkte = _bilanz_reihe()
    kandidaten = {
        k.pid: k
        for k in messung.aus_waermebilanz(proben, punkte, heat=HeatDemandConfig(), zeitzone=BERLIN)
    }
    assert kandidaten["h_haus"].wert == pytest.approx(H_WAHR, abs=0.004)
    assert kandidaten["q_intern"].wert == pytest.approx(INT_WAHR, abs=0.05)
    assert kandidaten["ww_tag"].wert == pytest.approx(WW_WAHR, abs=0.4)
    assert kandidaten["h_haus"].n > 50
    assert kandidaten["h_haus"].rmse is not None and kandidaten["h_haus"].rmse < 0.05


def test_waermebilanz_meldet_ihre_unsicherheit_mit() -> None:
    """Mit Rauschen in der Reihe wird die Unsicherheit größer - sonst wäre sie keine."""
    sauber = {
        k.pid: k
        for k in messung.aus_waermebilanz(
            *_bilanz_reihe(), heat=HeatDemandConfig(), zeitzone=BERLIN
        )
    }
    verrauscht = {
        k.pid: k
        for k in messung.aus_waermebilanz(
            *_bilanz_reihe(rauschen=0.8), heat=HeatDemandConfig(), zeitzone=BERLIN
        )
    }
    assert verrauscht["h_haus"].sigma > sauber["h_haus"].sigma * 5
    assert verrauscht["h_haus"].rmse is not None
    assert verrauscht["h_haus"].rmse > 0.3


def test_waermebilanz_rechnet_die_raumwaerme_des_ofens_dazu() -> None:
    """Sonst sähe jede Ofenstunde aus wie ein dichteres Haus: der Ofen deckt Bedarf, der sonst
    durch den Speicher gegangen wäre."""
    from hems_core.thermal.heat_balance import HeatPoint

    proben, punkte = _bilanz_reihe()
    ohne_ofen = [
        HeatPoint(at=p.at, draw_kw=max(0.0, p.draw_kw - 1.5), stove_room_kw=1.5) for p in punkte
    ]
    mit = {
        k.pid: k
        for k in messung.aus_waermebilanz(
            proben, ohne_ofen, heat=HeatDemandConfig(), zeitzone=BERLIN
        )
    }
    assert mit["h_haus"].wert == pytest.approx(H_WAHR, abs=0.01)


def test_waermebilanz_ohne_heiztage_gibt_nichts_her() -> None:
    """Über der Heizgrenze ist das Modell nicht gemeint, und ein Schätzer, der dort trotzdem
    rechnet, liefert eine Zahl ohne Deckung."""
    from hems_core.thermal.heat_balance import HeatPoint, HeatSample

    proben = [
        HeatSample(
            at=datetime(2026, 7, 1, 12, tzinfo=BERLIN) + timedelta(minutes=i), outdoor_c=24.0
        )
        for i in range(600)
    ]
    punkte = [HeatPoint(at=p.at, draw_kw=0.4) for p in proben]
    assert messung.aus_waermebilanz(proben, punkte, heat=HeatDemandConfig(), zeitzone=BERLIN) == []


def _nacht(stunden: float, von_c: float, bis_c: float, oben_extra: float = 0.0) -> list:
    """Eine Strecke, in der nichts läuft: vier gleiche Schichten, die gleichmäßig fallen."""
    from hems_core.thermal.heat_balance import HeatSample

    aus = []
    schritte = int(stunden * 60)
    for i in range(schritte + 1):
        f = i / schritte
        t = von_c + (bis_c - von_c) * f
        oben = t - oben_extra * f
        aus.append(
            HeatSample(
                at=datetime(2026, 1, 10, 1, 0, tzinfo=BERLIN) + timedelta(minutes=i),
                heat_pump_kw=0.0,
                outdoor_c=18.0,
                buffer_c=(oben, t, t, t + oben_extra * f),
                stove_running=False,
            )
        )
    return aus


def test_stille_strecke_wird_gefunden_und_liefert_den_verlustbeiwert() -> None:
    """1,163 kWh/K, 0,15 K/h Abkühlung bei 31 K Übertemperatur sind 5,6 W/K.

    Die sauberste Messung der Wärmeseite: in dieser Nacht steht alles andere still.
    """
    proben = _nacht(6.0, 49.0, 48.1)
    strecken = messung.stille_strecken(proben, buffer=CFG.buffer, heat=CFG.heat_demand)
    assert len(strecken) == 1
    assert strecken[0].stunden == pytest.approx(6.0, abs=0.1)
    assert strecken[0].kelvin_je_stunde == pytest.approx(0.15, abs=0.01)
    k = messung.aus_naechten(
        proben, buffer=CFG.buffer, heat=CFG.heat_demand, kapazitaet_kwh_k=1.163
    )
    assert k is not None and k.pid == "puffer_ua"
    assert k.wert == pytest.approx(5.6, abs=0.3)
    assert k.n == 1, "eine Nacht ist eine Beobachtung, nicht dreihundertsechzig"


def test_eine_zapfung_faellt_aus_der_messung() -> None:
    """Ein stehender Speicher verliert Zehntelgrade je Stunde; wer Wasser zapft, sieht Grade."""
    assert (
        messung.stille_strecken(_nacht(6.0, 49.0, 40.0), buffer=CFG.buffer, heat=CFG.heat_demand)
        == []
    )


def test_eine_entnahme_oben_faellt_auf() -> None:
    """Die Handschrift einer Zapfung: die oberste Schicht fällt deutlich schneller als das Mittel,
    auch wenn das Mittel noch harmlos aussieht."""
    assert (
        messung.stille_strecken(
            _nacht(6.0, 49.0, 48.1, oben_extra=3.0), buffer=CFG.buffer, heat=CFG.heat_demand
        )
        == []
    )


def test_laufende_waermepumpe_unterbricht_die_strecke() -> None:
    from hems_core.thermal.heat_balance import HeatSample

    proben = _nacht(3.0, 49.0, 48.6)
    stoerung = HeatSample(
        at=proben[-1].at + timedelta(minutes=1),
        heat_pump_kw=3.4,
        outdoor_c=18.0,
        buffer_c=(48.6, 48.6, 48.6, 48.6),
        stove_running=False,
    )
    weiter = _nacht(3.0, 48.6, 48.2)
    versetzt = [s.__class__(**{**s.__dict__, "at": s.at + timedelta(hours=4)}) for s in weiter]
    strecken = messung.stille_strecken(
        [*proben, stoerung, *versetzt], buffer=CFG.buffer, heat=CFG.heat_demand
    )
    assert len(strecken) == 2, "vor und nach dem Lauf je eine Strecke, nicht eine durchgehende"


def test_naechte_nehmen_den_median_und_nicht_das_mittel() -> None:
    """Eine einzelne Nacht mit einer unbemerkten Zapfung soll das Ergebnis nicht tragen."""
    gut = _nacht(4.0, 49.0, 48.4)
    schnell = [
        s.__class__(**{**s.__dict__, "at": s.at + timedelta(hours=10)})
        for s in _nacht(4.0, 49.0, 48.0)
    ]
    nur_gut = messung.aus_naechten(
        gut, buffer=CFG.buffer, heat=CFG.heat_demand, kapazitaet_kwh_k=1.163
    )
    beide = messung.aus_naechten(
        [*gut, *schnell], buffer=CFG.buffer, heat=CFG.heat_demand, kapazitaet_kwh_k=1.163
    )
    assert nur_gut is not None and beide is not None
    assert beide.n == 2
    assert beide.wert > nur_gut.wert  # der Median zweier Punkte liegt dazwischen
    assert beide.wert < 1.6 * nur_gut.wert


def test_in_der_heizzeit_gibt_es_keine_stille_nacht() -> None:
    """Solange geheizt wird, zieht der Heizkreis auch nachts - und zwar um ein Vielfaches mehr,
    als die Hülle des Speichers verliert. Wer dort misst, schreibt die Heizung in den
    Verlustbeiwert und bekommt einen Speicher, der fünfmal schlechter gedämmt ist, als er ist.
    """
    winter = [s.__class__(**{**s.__dict__, "outdoor_c": -2.0}) for s in _nacht(6.0, 49.0, 48.1)]
    assert messung.stille_strecken(winter, buffer=CFG.buffer, heat=CFG.heat_demand) == []
    assert (
        messung.aus_naechten(
            winter, buffer=CFG.buffer, heat=CFG.heat_demand, kapazitaet_kwh_k=1.163
        )
        is None
    )
