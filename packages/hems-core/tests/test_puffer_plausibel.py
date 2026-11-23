"""Die beiden Prüfungen, die am Foto der Wandanzeige gefehlt haben.

Auf dem Foto vom 22.11.2026 steht die Puffersäule auf `40°, 40°, 40°, 39°`, daneben
„PUFFER 18 % kalt". Säule, Zahl und Wort passen zueinander - und trotzdem kann niemand sagen, ob
die vier Fühler noch leben. Diese Datei hält beide Antworten fest: ein Wert, der sich nicht mehr
bewegt (`eingefroren`), und eine Säule, die nicht zueinander passt (`schichtungsbefund`).

Die Säule des Fotos selbst ist dabei **kein** Befund, und das ist nachgerechnet und nicht
nachgelassen: vier verschiedene Fühler, 18 % richtig, ein Kelvin Spanne bei einem entleerten
Speicher physikalisch möglich. Was dem Haus fehlte, war nicht eine Meldung über diese Säule,
sondern die Fähigkeit, eine kaputte von ihr zu unterscheiden.
"""

from __future__ import annotations

import pytest

from hems_core.domain import BufferConfig
from hems_core.thermal import schichtungsbefund
from hems_core.watch import Fuehlerstand, abkuehlzeit_min, eingefroren, standzeit_min

CFG = BufferConfig()


def stand(
    wert: float | None, minuten: float, meldungen: int = 400, key: str = "buffer_temp_top_c"
) -> Fuehlerstand:
    return Fuehlerstand(key=key, wert=wert, unveraendert_min=minuten, meldungen=meldungen)


# --------------------------------------------------------------------- Der eingefrorene Fühler


def test_die_frist_kommt_aus_dem_abkuehlen_des_speichers() -> None:
    """1000 l, 0,004 kW/K, 17 °C Technikraum: bei 40 °C sind das 0,079 K/h.

    0,1 K - die Auflösung der Fühler - braucht also 76 Minuten, mit Sicherheitsfaktor 2 sind es
    152. Ein heißer Speicher kühlt schneller und bekommt weniger Zeit.
    """
    assert standzeit_min(40.0, CFG) == pytest.approx(151.7, abs=0.5)
    assert standzeit_min(62.0, CFG) == pytest.approx(77.5, abs=0.5)
    assert standzeit_min(36.0, CFG) == pytest.approx(183.6, abs=0.5)
    # Ohne Übertemperatur sagt die Physik nichts - dann gibt es keine Frist.
    assert standzeit_min(17.0, CFG) is None


def test_ohne_gefaelle_zum_aufstellraum_gibt_es_keinen_befund() -> None:
    """Ein Fühler, der nicht wärmer ist als der Technikraum, muss sich nicht bewegen.

    Dann sagt die Physik nichts über eine Mindeständerung, und die Prüfung sagt auch nichts. Ein
    dort eingefrorener Fühler bleibt unsichtbar; das ist die ehrliche Auskunft. Es hängt auch
    nichts daran, denn unterhalb der nutzbaren Temperatur ist der Ladezustand null.
    """
    assert abkuehlzeit_min(16.0, CFG) is None
    assert standzeit_min(16.0, CFG) is None
    assert eingefroren([stand(16.0, 400)], CFG) == []
    assert eingefroren([stand(16.0, 5000)], CFG) == []


def test_ein_ruhender_lauwarmer_speicher_ist_kein_fehlalarm() -> None:
    """Die Gegenprobe, die die Obergrenze von sechs Stunden gekostet hat.

    Nachgerechnet am ruhenden Speicher (nur Verlust gegen den Aufstellraum, Anzeige auf eine
    Dezimale): bei 22 °C steht derselbe Wert 370 Minuten, bei 20 °C 600. Mit einer Deckelung über
    alle Temperaturen hätte ein völlig gesunder Pufferboden nach sechs Stunden einen **Alarm**
    gemeldet - im Sommer ohne Heizung jede Nacht. Die Deckelung lag dort unter der Physik, auf die
    sie sich beruft; ihr Argument ist die Warmwasserentnahme, und die gibt es unterhalb der
    nutzbaren Temperatur nicht.
    """
    for temp, gemessene_standzeit in ((22.0, 370.0), (20.0, 600.0), (25.0, 232.0)):
        frist = standzeit_min(temp, CFG)
        assert frist is not None
        assert frist > gemessene_standzeit, f"{temp} °C: Frist {frist} < Standzeit"
        assert eingefroren([stand(temp, gemessene_standzeit)], CFG) == []
    # Über der nutzbaren Temperatur deckelt sie weiter - dort wird entnommen.
    assert standzeit_min(36.0, CFG) == pytest.approx(183.6, abs=0.5)
    assert all((standzeit_min(t, CFG) or 0.0) <= 360.0 for t in (36.0, 40.0, 45.0, 50.0, 62.0))


def test_sechs_stunden_derselbe_wert_ist_ein_befund() -> None:
    """Der ausgeführte Fall: sechs Stunden Minutentakt mit festsitzendem `buffer_temp_top_c`.

    Vorher blieben alle vier Fühler `ok` und `usable`, und der Ladezustand wurde gerechnet.
    """
    (befund,) = eingefroren([stand(40.0, 360, meldungen=360)], CFG)
    assert befund.name == "frozen:buffer_temp_top_c"
    assert befund.title_de == "Der Pufferfühler oben"
    assert befund.severity == "alarm"
    assert befund.silent_min == 360.0
    assert "unverändert 40,0 °C" in befund.text_de
    assert "seit 6 Stunden" in befund.text_de
    # Der Satz sagt die Folge, nicht nur den Zustand.
    assert "Ladezustand" in befund.text_de


def test_zwei_stunden_sind_noch_kein_befund() -> None:
    # 120 Minuten liegen unter der Frist von 152 bei 40 °C: ein Speicher, der gerade hält, darf
    # so lange auf derselben Stelle stehen.
    assert eingefroren([stand(40.0, 120)], CFG) == []


def test_ein_heisser_fuehler_faellt_frueher_auf() -> None:
    # Dieselben 120 Minuten bei 62 °C: dort müsste er sich längst bewegt haben (Frist 78).
    (befund,) = eingefroren([stand(62.0, 120)], CFG)
    assert "unverändert 62,0 °C" in befund.text_de


def test_zwei_gleiche_werte_mit_einer_luecke_dazwischen_sind_kein_stillstand() -> None:
    """Der Fall, der die Prüfung sonst zum Fehlalarm macht.

    Nach einem Ausfall der Brücke liegen zwei gleiche Werte drei Stunden auseinander - und mehr
    weiß niemand. Dass dazwischen nichts kam, ist Sache der Stille-Regel; ein eingefrorener
    Fühler zeigt sich daran, dass er **oft** dasselbe meldet.
    """
    assert eingefroren([stand(40.0, 180, meldungen=2)], CFG) == []


def test_ohne_wert_kein_stillstand() -> None:
    assert eingefroren([stand(None, 600)], CFG) == []


def test_jeder_fuehler_wird_einzeln_genannt() -> None:
    befunde = eingefroren(
        [stand(40.0, 400), stand(39.0, 400, key="buffer_temp_bottom_c")],
        CFG,
    )
    assert [b.title_de for b in befunde] == [
        "Der Pufferfühler oben",
        "Der Pufferfühler unten",
    ]


# --------------------------------------------------------------------- Die Schichtung


def test_die_saeule_vom_foto_ist_kein_befund() -> None:
    """`40°, 40°, 40°, 39°` - nachgerechnet in Ordnung, also kein Wort dazu.

    Vier verschiedene Fühler, 18 % rechnerisch richtig, ein Kelvin Spanne bei einem entleerten
    Speicher physikalisch möglich. Eine Prüfung, die diese Säule anmeckert, hängt eine
    Dauerwarnung für einen gesunden Speicher an die Wand. Und ob die Säule *stehen bleibt*, statt
    zu fallen, sieht eine Momentaufnahme nicht - das ist die Frage von `eingefroren`.
    """
    assert schichtungsbefund([40.0, 40.0, 40.0, 39.0], CFG) is None


def test_eine_flache_saeule_in_betrieb_ist_ein_befund() -> None:
    """Oberhalb der Komforttemperatur muss eine Stufe zu sehen sein.

    Die Oberkante liefert Komfortwärme, der Speicher ist in Betrieb - eingespeist und entnommen
    wird oben. Vier gleiche Werte heißen dann, dass zwei Fühler an derselben Stelle sitzen oder am
    selben Wert hängen.
    """
    befund = schichtungsbefund([44.0, 44.0, 44.0, 43.5], CFG)
    assert befund is not None
    assert befund.name == "buffer_flat"
    assert befund.severity == "warn"
    assert "innerhalb von 0,5 K" in befund.text_de
    assert "Komfortwärme" in befund.text_de


def test_unten_waermer_als_oben_wird_bemerkt() -> None:
    befund = schichtungsbefund([45.0, 46.0, 47.0, 48.5], CFG)
    assert befund is not None
    assert befund.name == "buffer_inversion"
    assert "unten (48,5 °C) ist 3,5 K wärmer als oben (45,0 °C)" in befund.text_de


def test_eine_inversion_in_der_groesse_der_fuehlergenauigkeit_ist_kein_befund() -> None:
    # 0,2 K zwischen „Mitte unten" und „unten", bei sonst sauberer Schichtung: zwei DS18B20
    # können sich um 1 K unterscheiden, ohne dass einer falsch ist.
    assert schichtungsbefund([55.0, 50.0, 45.0, 45.2], CFG) is None


def test_die_flachen_saeulen_die_es_wirklich_gibt() -> None:
    # Durchgeladen (die Wärmepumpe zieht die ganze Säule auf die Zieltemperatur) und unterhalb der
    # Komforttemperatur, wo der Speicher nicht mehr angefahren wird und über Tage im Stillstand
    # ausgleicht. Zwischen beidem liegt der Bereich, in dem eine Stufe zu sehen sein muss.
    assert schichtungsbefund([60.0, 60.0, 60.0, 60.0], CFG) is None
    assert schichtungsbefund([30.0, 30.0, 30.0, 30.0], CFG) is None
    assert schichtungsbefund([41.5, 41.5, 41.5, 41.0], CFG) is None


def test_eine_gewoehnliche_schichtung_ist_kein_befund() -> None:
    assert schichtungsbefund([60.0, 55.0, 48.0, 40.0], CFG) is None


def test_die_pruefung_verlangt_vier_werte() -> None:
    with pytest.raises(ValueError, match="vier Temperaturen"):
        schichtungsbefund([40.0, 40.0, 40.0], CFG)
