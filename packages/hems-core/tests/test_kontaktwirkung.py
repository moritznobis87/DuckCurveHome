"""Die Ereignisstudie zu K1: was nach dem Schließen geschieht, und was ohnehin geschähe."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

import pytest

from hems_core.thermal.kontaktwirkung import (
    FOLGE_MIN,
    NACH_MIN,
    VOR_MIN,
    Probe,
    auswerten,
    wilson,
)

T0 = datetime(2026, 11, 1, 0, 0, tzinfo=UTC)
TAG = 1440
SCHWELLE = 0.5


def reihe(
    minuten: int,
    kontakt: Callable[[int], bool | None],
    kw: Callable[[int], float | None],
) -> list[Probe]:
    """Eine Minutenreihe ab `T0`. Beide Funktionen bekommen die Minute seit Beginn."""
    return [Probe(T0 + timedelta(minutes=m), kontakt(m), kw(m)) for m in range(minuten)]


def stunde(t: datetime) -> int:
    return t.hour


def werte(proben: list[Probe]):  # type: ignore[no-untyped-def]
    return auswerten(proben, schwelle_kw=SCHWELLE, stunde=stunde)


def zwischen(m: int, von: int, bis: int) -> bool:
    return von <= m < bis


# ---------------------------------------------------------------------------- Wilson


def test_wilson_bleibt_zwischen_null_und_eins_und_wird_bei_sieben_von_sieben_nicht_null_breit() -> (
    None
):
    # Die Schulformel gäbe hier 100 bis 100 Prozent. Sieben Beobachtungen belegen das nicht.
    lo, hi = wilson(7, 7) or (0, 0)
    assert hi == 1.0
    assert 0.55 < lo < 0.70


def test_wilson_trifft_den_bekannten_wert() -> None:
    lo, hi = wilson(8, 10) or (0, 0)
    assert lo == pytest.approx(0.490, abs=0.002)
    assert hi == pytest.approx(0.943, abs=0.002)


def test_wilson_kennt_ohne_beobachtung_keinen_bereich() -> None:
    assert wilson(0, 0) is None


# ---------------------------------------------------------------------------- Ereignisse


def test_ein_schliessvorgang_wird_gefunden_und_die_verzoegerung_gezaehlt() -> None:
    # K1 schließt in Minute 100 für eine Stunde, die Maschine läuft vier Minuten später an.
    k = werte(
        reihe(
            400,
            lambda m: zwischen(m, 100, 160),
            lambda m: 4.2 if zwischen(m, 104, 170) else 0.02,
        )
    )
    assert k.n == 1
    e = k.ereignisse[0]
    assert e.at == T0 + timedelta(minutes=100)
    assert not e.lief_schon
    assert e.auswertbar
    assert e.gefolgt is True
    assert e.verzoegerung_min == 4
    assert e.kontakt_min == 60
    # Der Ausschnitt reicht von -30 bis +120, und der Nullpunkt liegt, wo er hingehört.
    assert len(e.kw) == VOR_MIN + NACH_MIN + 1
    assert e.kw[VOR_MIN] == 0.02
    assert e.kw[VOR_MIN + 4] == 4.2
    assert k.gefolgt == 1
    assert k.quote == 1.0
    assert k.verzoegerung_median_min == 4.0


def test_flattern_ist_ein_ereignis_und_nicht_zehn() -> None:
    # Der Kontakt wechselt alle drei Minuten. Nur das erste Schließen folgt auf zehn Minuten Ruhe.
    k = werte(reihe(300, lambda m: zwischen(m, 100, 130) and (m // 3) % 2 == 0, lambda m: 0.02))
    assert k.n == 1


def test_eine_schon_laufende_maschine_sagt_nichts_ueber_die_wirkung() -> None:
    k = werte(
        reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 4.0 if zwischen(m, 80, 200) else 0.0)
    )
    e = k.ereignisse[0]
    assert e.lief_schon
    assert not e.auswertbar
    assert e.gefolgt is None
    assert e.verzoegerung_min is None
    assert k.n == 1 and k.n_lief_schon == 1 and k.n_auswertbar == 0
    assert k.quote is None
    assert any("schon laufende" in h for h in k.hinweise_de)


def test_ueber_eine_luecke_hinweg_entsteht_kein_ereignis() -> None:
    # Von Minute 90 bis 99 ist der Kontakt unbekannt, danach geschlossen. Wann er schloss, weiß
    # niemand; ein Ereignis bei Minute 100 wäre erfunden.
    k = werte(
        reihe(
            400,
            lambda m: None if zwischen(m, 90, 100) else zwischen(m, 100, 160),
            lambda m: 0.0,
        )
    )
    assert k.n == 0


def test_fehlt_die_leistung_im_folgefenster_ist_das_ausbleiben_keine_aussage() -> None:
    k = werte(
        reihe(
            400,
            lambda m: zwischen(m, 100, 160),
            lambda m: None if zwischen(m, 102, 140) else 0.0,
        )
    )
    e = k.ereignisse[0]
    assert not e.auswertbar
    assert e.gefolgt is None
    assert any("nicht auswertbar" in h for h in k.hinweise_de)


def test_standby_ist_kein_anlauf_und_die_schwelle_selbst_zaehlt() -> None:
    # 0,3 kW ist die Grundlast der Anlage, kein Verdichter. Genau 0,5 kW zählt, wie überall.
    standby = werte(reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 0.3))
    assert standby.ereignisse[0].gefolgt is False
    grenze = werte(reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 0.5 if m >= 110 else 0.3))
    assert grenze.ereignisse[0].gefolgt is True
    assert grenze.ereignisse[0].verzoegerung_min == 10


def test_ein_anlauf_nach_dem_folgefenster_zaehlt_nicht_als_folge_steht_aber_da() -> None:
    k = werte(
        reihe(
            400, lambda m: zwischen(m, 100, 200), lambda m: 4.0 if m >= 100 + FOLGE_MIN + 5 else 0.0
        )
    )
    e = k.ereignisse[0]
    assert e.gefolgt is False
    assert e.verzoegerung_min == FOLGE_MIN + 5
    assert k.verzoegerung_median_min is None


def test_die_sekunden_im_zeitstempel_stoeren_nicht() -> None:
    proben = [
        Probe(p.ts + timedelta(seconds=17), p.kontakt, p.kw)
        for p in reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 4.0 if m >= 103 else 0.0)
    ]
    k = werte(proben)
    assert k.n == 1
    assert k.ereignisse[0].verzoegerung_min == 3


# ---------------------------------------------------------------------------- Fächer


def test_der_faecher_legt_die_ereignisse_am_nullpunkt_uebereinander() -> None:
    # Drei Tage, je ein Schließen um 12 Uhr, die Maschine folgt nach 2, 4 und 6 Minuten.
    def kw(m: int) -> float:
        tag, im_tag = divmod(m, TAG)
        return 4.0 if zwischen(im_tag, 722 + 2 * tag, 800) else 0.0

    k = werte(reihe(3 * TAG, lambda m: zwischen(m % TAG, 720, 780), kw))
    f = k.faecher
    assert f.minuten[0] == -VOR_MIN and f.minuten[-1] == NACH_MIN
    null = f.minuten.index(0)
    assert f.n[null] == 3
    assert f.anteil_laeuft[null] == 0.0
    assert f.anteil_laeuft[null + 3] == pytest.approx(1 / 3, abs=0.001)
    assert f.anteil_laeuft[null + 5] == pytest.approx(2 / 3, abs=0.001)
    assert f.anteil_laeuft[null + 7] == 1.0
    assert f.median_kw[null + 5] == 4.0
    # Das Mittel ist Anteil mal Leistung: zwei von dreien laufen mit 4 kW.
    assert f.mittel_kw[null + 5] == pytest.approx(8 / 3, abs=0.001)
    assert f.q25_kw[null + 5] == 2.0


def test_ohne_ereignis_ist_der_faecher_leer_und_das_urteil_offen() -> None:
    k = werte(reihe(TAG, lambda m: False, lambda m: 0.0))
    assert k.n == 0
    assert k.urteil == "offen"
    assert "kein einziges Mal" in k.urteil_de
    assert len(k.faecher.minuten) == VOR_MIN + NACH_MIN + 1
    assert all(w is None for w in k.faecher.median_kw)


def test_ohne_eine_einzige_minute_bricht_nichts() -> None:
    k = werte([])
    assert k.von is None and k.bis is None
    assert k.n == 0
    assert k.vergleich.n == 0


# ---------------------------------------------------------------------------- Vergleich


def test_der_vergleich_zaehlt_bloecke_die_sich_nicht_ueberlappen() -> None:
    # Ein Tag, die Maschine steht, der Kontakt ist offen. Der erste Block fällt weg, weil vor ihm
    # nichts gemessen ist; die übrigen 47 halben Stunden zählen je einmal.
    k = werte(reihe(TAG, lambda m: False, lambda m: 0.0))
    assert k.vergleich.n == 47
    assert k.vergleich.gefolgt == 0
    assert k.vergleich.quote_gesamt == 0.0


def test_ein_block_mit_schliessvorgang_ist_kein_vergleich() -> None:
    ohne = werte(reihe(TAG, lambda m: False, lambda m: 0.0))
    mit = werte(reihe(TAG, lambda m: zwischen(m, 725, 745), lambda m: 0.0))
    # Der Block ab 12:00 enthält das Schließen. Der ab 12:30 fällt auch weg: der Kontakt öffnete
    # erst um 12:25, und verlangt sind zehn Minuten Ruhe davor.
    assert mit.vergleich.n == ohne.vergleich.n - 2
    # Öffnet er früh genug, zählt der zweite Block wieder.
    kurz = werte(reihe(TAG, lambda m: zwischen(m, 725, 740), lambda m: 0.0))
    assert kurz.vergleich.n == ohne.vergleich.n - 1


def tage_abwechselnd(tage: int, kw: Callable[[int, int], float]) -> list[Probe]:
    """An geraden Tagen schließt K1 um 12 Uhr für eine Stunde, an ungeraden nie."""
    return reihe(
        tage * TAG,
        lambda m: (m // TAG) % 2 == 0 and zwischen(m % TAG, 720, 780),
        lambda m: kw(m // TAG, m % TAG),
    )


def test_folgt_die_maschine_und_laeuft_sonst_nicht_an_dann_wirkt_k1() -> None:
    # Gerade Tage: K1 um 12 Uhr, die Maschine folgt nach drei Minuten. Ungerade Tage: um 12 Uhr
    # geschieht nichts. Ein Lauf um 3 Uhr an jedem Tag, damit die Maschine überhaupt ein Eigenleben
    # hat.
    def kw(tag: int, m: int) -> float:
        if zwischen(m, 180, 210):
            return 4.0
        return 4.0 if tag % 2 == 0 and zwischen(m, 723, 790) else 0.0

    k = werte(tage_abwechselnd(40, kw))
    assert k.n == 20 and k.n_auswertbar == 20 and k.gefolgt == 20
    assert k.vergleich.ereignisse_gedeckt == 20
    assert k.vergleich.n_gleiche_stunde == 40  # zwei Blöcke je ungeradem Tag
    assert k.vergleich.quote == 0.0
    assert k.urteil == "wirkt"
    assert "100 %" in k.urteil_de and "0 %" in k.urteil_de


def test_laeuft_die_maschine_ohnehin_staendig_an_ist_kein_unterschied_gesichert() -> None:
    # Die Maschine taktet von selbst: 20 Minuten an, 27 aus, ohne Rücksicht auf den Kontakt. Nach
    # jedem Schließen läuft sie binnen einer halben Stunde an - und ohne Schließen genauso.
    def kw(tag: int, m: int) -> float:
        return 4.0 if (tag * TAG + m) % 47 < 20 else 0.0

    k = werte(tage_abwechselnd(60, kw))
    assert k.n_auswertbar >= 8
    assert k.quote == 1.0
    assert k.vergleich.quote == 1.0
    assert k.urteil == "kein_unterschied"


def test_laeuft_sie_nach_dem_schliessen_seltener_an_steht_auch_das_da() -> None:
    # Ungerade Tage: die Maschine läuft um 12:05 und 12:35 von selbst. Gerade Tage: K1 schließt,
    # und sie bleibt aus. Das Urteil darf nicht nur eine Richtung kennen.
    def kw(tag: int, m: int) -> float:
        if tag % 2 == 1 and (zwischen(m, 725, 735) or zwischen(m, 755, 765)):
            return 4.0
        return 0.0

    k = werte(tage_abwechselnd(40, kw))
    assert k.quote == 0.0
    assert k.vergleich.quote == 1.0
    assert k.urteil == "seltener"


def test_der_vergleich_gilt_zur_selben_tageszeit_und_nicht_ueber_den_ganzen_tag() -> None:
    # Die Maschine läuft jede Nacht stündlich an, mittags nie. K1 schließt mittags. Über den ganzen
    # Tag gerechnet läge der Vergleich bei rund einem Viertel; zur Mittagszeit liegt er bei null.
    def kw(tag: int, m: int) -> float:
        nachts = m < 360 and m % 60 < 15
        return 4.0 if nachts or (tag % 2 == 0 and zwischen(m, 723, 790)) else 0.0

    k = werte(tage_abwechselnd(40, kw))
    assert k.vergleich.quote == 0.0
    assert k.vergleich.quote_gesamt is not None and k.vergleich.quote_gesamt > 0.1


def test_zu_wenige_ereignisse_ergeben_zahlen_aber_kein_urteil() -> None:
    def kw(tag: int, m: int) -> float:
        return 4.0 if tag % 2 == 0 and zwischen(m, 723, 790) else 0.0

    k = werte(tage_abwechselnd(6, kw))
    assert k.n_auswertbar == 3 and k.quote == 1.0
    assert k.urteil == "offen"
    assert "Zu wenige" in k.urteil_de


def test_schliesst_k1_immer_zur_selben_stunde_fehlt_der_vergleich_und_das_wird_gesagt() -> None:
    # Jeden Tag um 12 Uhr: dann gibt es um 12 Uhr keinen einzigen Moment ohne K1.
    k = werte(
        reihe(
            20 * TAG,
            lambda m: zwischen(m % TAG, 720, 780),
            lambda m: 4.0 if zwischen(m % TAG, 723, 790) else 0.0,
        )
    )
    assert k.n_auswertbar == 20
    assert k.vergleich.quote is None
    assert k.urteil == "offen"
    assert "selben Tageszeit" in k.urteil_de
    assert any("keinen Vergleichsmoment" in h for h in k.hinweise_de)


# ---------------------------------------------------------------------------- Nachlauf


def test_nach_dem_oeffnen_wird_der_nachlauf_gemessen() -> None:
    # K1 öffnet in Minute 160, die Maschine läuft noch bis Minute 172.
    k = werte(
        reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 4.0 if zwischen(m, 104, 172) else 0.0)
    )
    assert k.nachlauf_n == 1
    assert k.nachlauf_median_min == 12.0
    assert any("12 Minuten" in h for h in k.hinweise_de)


def test_der_zeitraum_ist_der_gefragte_wenn_der_aufrufer_ihn_nennt() -> None:
    von = T0 - timedelta(days=5)
    bis = T0 + timedelta(days=5)
    k = auswerten(
        reihe(60, lambda m: False, lambda m: 0.0),
        schwelle_kw=SCHWELLE,
        stunde=stunde,
        von=von,
        bis=bis,
    )
    assert k.von == von and k.bis == bis


# ---------------------------------------------------------------------------- Die Anlaufkurven


def test_die_anlaufkurve_steigt_nur_und_endet_auf_der_folgequote() -> None:
    # Drei Tage, Anlauf nach 2, 4 und 6 Minuten.
    def kw(m: int) -> float:
        tag, im_tag = divmod(m, TAG)
        return 4.0 if zwischen(im_tag, 722 + 2 * tag, 800) else 0.0

    k = werte(reihe(3 * TAG, lambda m: zwischen(m % TAG, 720, 780), kw))
    f = k.faecher
    null = f.minuten.index(0)
    kurve = f.anteil_angelaufen
    assert all(w is None for w in kurve[:null]), "vor dem Schließen gibt es keinen Anlauf zu zählen"
    assert kurve[null] == 0.0
    assert kurve[null + 2] == pytest.approx(1 / 3, abs=0.001)
    assert kurve[null + 4] == pytest.approx(2 / 3, abs=0.001)
    assert kurve[null + 6] == 1.0
    danach = [w for w in kurve[null:] if w is not None]
    assert danach == sorted(danach)
    assert kurve[null + FOLGE_MIN - 1] == k.quote


def test_die_vergleichskurve_endet_auf_der_vergleichsquote() -> None:
    # Ungerade Tage: die Maschine läuft um 12:05 und 12:35 von selbst an, also in jedem der beiden
    # Blöcke nach fünf Minuten.
    def kw(tag: int, m: int) -> float:
        if tag % 2 == 1 and (zwischen(m, 725, 735) or zwischen(m, 755, 765)):
            return 4.0
        return 0.0

    k = werte(tage_abwechselnd(40, kw))
    kurve = k.vergleich.angelaufen_bis
    assert len(kurve) == FOLGE_MIN
    assert kurve[4] == 0.0
    assert kurve[5] == 1.0
    assert kurve[-1] == k.vergleich.quote


def test_ohne_vergleich_zur_selben_tageszeit_gibt_es_keine_vergleichskurve() -> None:
    k = werte(reihe(TAG, lambda m: False, lambda m: 0.0))
    assert k.vergleich.angelaufen_bis == []


def test_die_hinweise_kennen_einzahl_und_mehrzahl() -> None:
    eins = werte(
        reihe(
            400, lambda m: zwischen(m, 100, 160), lambda m: None if zwischen(m, 102, 140) else 0.0
        )
    )
    assert any(h.startswith("1 Anforderung ist nicht auswertbar") for h in eins.hinweise_de)


def test_die_abdeckung_zaehlt_gegen_den_gefragten_zeitraum_und_wird_gemeldet() -> None:
    # Gefragt sind zehn Stunden, gemessen ist die Leistung durchgehend, der Kontakt nur in jeder
    # vierten Minute. So sah ein Bestand aus, dessen Quelle nur bei Änderung schrieb.
    proben = reihe(600, lambda m: False if m % 4 == 0 else None, lambda m: 0.0)
    k = auswerten(
        proben,
        schwelle_kw=SCHWELLE,
        stunde=stunde,
        von=T0,
        bis=T0 + timedelta(minutes=599),
    )
    assert k.abdeckung_leistung == 1.0
    assert k.abdeckung_kontakt == 0.25
    assert any("Der Zustand der Anforderung ist nur in 25 %" in h for h in k.hinweise_de)
    assert not any("Die Leistung der Wärmepumpe ist nur" in h for h in k.hinweise_de)
    # Und die Folge davon: ohne durchgehend bekannten Kontakt gibt es keinen Vergleich.
    assert k.vergleich.n == 0


def test_ein_halb_leerer_zeitraum_hat_halbe_abdeckung() -> None:
    k = auswerten(
        reihe(300, lambda m: False, lambda m: 0.0),
        schwelle_kw=SCHWELLE,
        stunde=stunde,
        von=T0,
        bis=T0 + timedelta(minutes=599),
    )
    assert k.abdeckung_kontakt == 0.5
    assert k.abdeckung_leistung == 0.5


def test_die_methode_steht_getrennt_von_dem_was_fuer_den_zeitraum_gilt() -> None:
    """Was immer gilt, darf die Oberfläche einklappen. Was nur hier gilt, nicht."""
    k = werte(
        reihe(400, lambda m: zwischen(m, 100, 160), lambda m: 4.0 if zwischen(m, 80, 200) else 0.0)
    )
    assert any("keine Ursache" in m for m in k.methode_de)
    assert not any("keine Ursache" in h for h in k.hinweise_de)
    assert any("schon laufende" in h for h in k.hinweise_de), "das gilt für diesen Zeitraum"
    ohne = werte(reihe(TAG, lambda m: False, lambda m: 0.0))
    assert ohne.hinweise_de == [], "ohne Besonderheit im Zeitraum gibt es keinen Hinweis"
    assert ohne.methode_de == k.methode_de
