"""Die Wiedergabe: ein Tag als Folge von Anlagenbildern, aus der Minutenreihe nachgebaut.

Der Kern dieser Prüfungen ist nicht, dass Bilder herauskommen, sondern **dass sie dasselbe Bild
sind**. Es gibt genau eine Zusammensetzung des Anlagenschemas, `anlage.zusammensetzen`, und die
Wiedergabe rekonstruiert ihre Eingänge statt das Bild zweiter Hand zu bauen. Ginge das
auseinander, zeigte die Wiedergabe ein anderes Haus als die Live-Seite, und niemand würde es
merken: beide Bilder sehen für sich genommen plausibel aus.

Festgehalten wird außerdem, was die Wiedergabe **nicht** kann, denn das ist hier die größere
Gefahr. Eine Lücke in der Erfassung darf nicht als ruhiges Haus erscheinen, ein Heizkreis ohne
Ventildaten nicht als geschlossener, und eine Wärmepumpe, die beim ersten Bild schon lief, nicht
als eine, die um Mitternacht anlief.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from dch_api.application import anlage_replay
from dch_api.application.anlage_replay import SCHRITTE, Zeile, bilder, fenster, zusammenstellen
from hems_core.domain import HemsConfig

BERLIN = ZoneInfo("Europe/Berlin")
TAG = date(2026, 11, 7)
#: Ortsmitternacht des 7.11.2026 ist 23:00 UTC am 6.11.
VON = datetime(2026, 11, 6, 23, 0, tzinfo=UTC)
CFG = HemsConfig()


def zeile(ts: datetime, **werte: float) -> Zeile:
    """Eine Minutenzeile. Nur was angegeben ist, steht drin; alles andere fehlt wirklich."""
    z: Zeile = {"ts": ts.isoformat()}
    z.update({k: v for k, v in werte.items()})
    return z


def tag(minuten: int = 180, *, ab: datetime = VON, pv: float = 2.0, wp: float = 0.0) -> list[Zeile]:
    """Zusammenhängende Minuten mit vollständigen Pufferfühlern."""
    return [
        zeile(
            ab + timedelta(minutes=i),
            pv_power_kw=pv,
            grid_power_kw=-1.0,
            battery_power_kw=0.0,
            battery_soc=0.6,
            house_power_kw=1.0 + wp,
            heat_pump_power_kw=wp,
            outdoor_temp_c=4.0,
            electricity_price_ct_kwh=22.0,
            buffer_temp_top_c=58.0,
            buffer_temp_mid_top_c=52.0,
            buffer_temp_mid_bottom_c=44.0,
            buffer_temp_bottom_c=36.0,
        )
        for i in range(minuten)
    ]


# ------------------------------------------------------------------ Das Fenster


def test_der_tag_ist_der_ortstag_und_nicht_der_utc_tag() -> None:
    """Ein Tag beginnt für den Bewohner um Mitternacht, nicht um ein Uhr."""
    von, bis = fenster(TAG, BERLIN)
    assert von == VON
    assert (bis - von) == timedelta(hours=24)
    assert von.astimezone(BERLIN).hour == 0


def test_der_tag_der_zeitumstellung_hat_fuenfundzwanzig_stunden() -> None:
    """Und das ist richtig so: an jenem Sonntag hatte er sie wirklich.

    Wer hier auf 24 Stunden normiert, verliert eine Stunde Wiedergabe genau an dem Tag, an dem die
    Nachtstunde zweimal vorkommt - also an dem Tag, an dem man am genauesten hinsehen will.
    """
    von, bis = fenster(date(2026, 10, 25), BERLIN)
    assert (bis - von) == timedelta(hours=25)


# ------------------------------------------------------------------ Die Bilder


def test_ein_bild_je_schritt_und_jedes_mit_seiner_zeit() -> None:
    zeilen = tag(120)
    rahmen = bilder(zeilen, CFG, von=VON, bis=VON + timedelta(hours=2), step_min=15)
    assert len(rahmen) == 8
    assert [f.at for f in rahmen] == [VON + timedelta(minutes=15 * i) for i in range(8)]
    assert all(f.strom.pv_kw == 2.0 for f in rahmen)


def test_dasselbe_bild_wie_die_live_seite() -> None:
    """Die Wiedergabe baut die Eingänge nach und ruft dieselbe Zusammensetzung.

    Geprüft wird das an einer Stelle, die eine zweite Umsetzung sicher anders machen würde: der
    Pufferinhalt ist nicht abgelesen, sondern aus vier Fühlern gerechnet, samt Anteilen und
    Rundung. Stimmt er, ist es dieselbe Rechnung.
    """
    from hems_core.thermal.buffer_soc import compute_buffer_state

    rahmen = bilder(tag(30), CFG, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    bild = rahmen[0]
    snap = anlage_replay.schnappschuss(tag(1)[0], VON)
    erwartet = compute_buffer_state(snap.buffer_temps_c, CFG.buffer)
    assert bild.speicher.soc == erwartet.soc
    assert bild.speicher.usable_kwh == erwartet.usable_energy_kwh
    assert bild.speicher.temps_c == [58.0, 52.0, 44.0, 36.0]


def test_eine_luecke_bleibt_eine_luecke() -> None:
    """Fehlt zu einem Zeitpunkt jede Messung, entsteht kein Bild - und keine Erfindung.

    Das ist die wichtigste Entscheidung dieses Moduls. Die bequeme Variante waere, den letzten
    bekannten Wert weiterzuschreiben; dann liefe die Wiedergabe durch einen Erfassungsausfall
    hindurch und zeigte ein ruhiges Haus. Ein ruhiges Haus und ein blindes Messsystem sehen im
    Schema gleich aus, und genau das darf nicht sein.
    """
    zeilen = [*tag(30), *tag(30, ab=VON + timedelta(hours=3))]
    rahmen = bilder(zeilen, CFG, von=VON, bis=VON + timedelta(hours=4), step_min=15)
    zeiten = {f.at for f in rahmen}
    assert VON in zeiten
    assert VON + timedelta(hours=1) not in zeiten, "die Stunde ohne Messung ergibt kein Bild"
    assert VON + timedelta(hours=3) in zeiten, "danach geht es weiter"


def test_es_wird_nicht_in_die_zukunft_geschaut() -> None:
    """Ein Bild um 8:00 darf nicht aus einer Messung von 8:04 bestehen.

    Die Wiedergabe soll zeigen, was zu diesem Zeitpunkt bekannt war. Vorwärts zu greifen wäre
    bequem - es füllte jede Lücke - und machte aus der Wiedergabe eine Nachbearbeitung.
    """
    spaeter = zeile(VON + timedelta(minutes=4), pv_power_kw=9.0)
    rahmen = bilder([spaeter], CFG, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    assert rahmen == [], "die einzige Messung liegt hinter dem Zeitpunkt"


def test_der_takt_der_waermepumpe_wird_mitgezaehlt() -> None:
    """`running_since` kommt aus dem Verlauf der Bilder, nicht aus einem Gedächtnis."""
    aus = tag(60, pv=1.0, wp=0.0)
    an = tag(60, ab=VON + timedelta(hours=1), pv=1.0, wp=3.4)
    rahmen = bilder([*aus, *an], CFG, von=VON, bis=VON + timedelta(hours=2), step_min=15)
    assert [f.waermepumpe.running for f in rahmen] == [False] * 4 + [True] * 4
    laeuft = [f for f in rahmen if f.waermepumpe.running]
    assert laeuft[0].waermepumpe.running_since == VON + timedelta(hours=1)
    assert all(f.waermepumpe.running_since == VON + timedelta(hours=1) for f in laeuft), (
        "derselbe Lauf behaelt seinen Anfang, er beginnt nicht in jedem Bild neu"
    )


def test_eine_laufende_pumpe_im_ersten_bild_erfindet_keinen_anfang() -> None:
    """Wie lange sie vorher lief, steht in diesen Zeilen nicht. Also steht es auch nicht da."""
    rahmen = bilder(tag(30, wp=3.4), CFG, von=VON, bis=VON + timedelta(minutes=30), step_min=15)
    assert rahmen[0].waermepumpe.running is True
    assert rahmen[0].waermepumpe.running_since is None


def test_der_heizkreis_bleibt_dunkel_statt_geschlossen_zu_behaupten() -> None:
    """Ohne Ventildaten ist „kein Raum offen" keine Messung, sondern eine fehlende."""
    rahmen = bilder(tag(30), CFG, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    hk = rahmen[0].heizkreis
    assert hk.rooms_total == 0 and hk.running is False
    assert hk.open_share is None, "kein Anteil ohne Nenner"


def test_eine_fehlende_spalte_wird_nicht_zu_null() -> None:
    """Keine Messung heißt keine Messung. Eine Null waere eine Behauptung über die Anlage."""
    karg = [zeile(VON + timedelta(minutes=i)) for i in range(20)]
    rahmen = bilder(karg, CFG, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    assert len(rahmen) == 1
    assert rahmen[0].strom.pv_kw is None
    assert rahmen[0].outdoor_c is None
    assert rahmen[0].speicher.soc is None, "ohne Fuehler kein Ladezustand"


def test_ohne_ofen_in_der_konfiguration_ist_er_abwesend() -> None:
    ohne = HemsConfig.model_validate({"stove": {"present": False}})
    rahmen = bilder(tag(30), ohne, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    assert rahmen[0].ofen.present is False


def test_der_ofen_kommt_aus_seinen_spalten() -> None:
    """Die Ausbrandphase meldet weiter „laeuft", und das Bild soll das zeigen."""
    zeilen = [
        zeile(
            VON + timedelta(minutes=i),
            stove_running=1.0,
            stove_power_level=5.0,
            stove_boiler_temp_c=74.0,
            buffer_temp_top_c=58.0,
            buffer_temp_mid_top_c=52.0,
            buffer_temp_mid_bottom_c=44.0,
            buffer_temp_bottom_c=36.0,
        )
        for i in range(20)
    ]
    rahmen = bilder(zeilen, CFG, von=VON, bis=VON + timedelta(minutes=15), step_min=15)
    ofen = rahmen[0].ofen
    assert ofen.present is True and ofen.running is True
    assert ofen.power_level == 5.0 and ofen.flow_c == 74.0
    assert ofen.water_kw is not None and ofen.water_kw > 0


# ------------------------------------------------------------------ Die Antwort


def test_die_antwort_sagt_wie_viele_bilder_fehlen() -> None:
    """Erst der Vergleich mit `erwartet` macht eine Luecke sichtbar."""
    out = zusammenstellen(tag(60), CFG, TAG, BERLIN, step_min=15)
    assert out.erwartet == 96, "24 Stunden zu einer Viertelstunde"
    # Fuenf und nicht vier: die Zeilen reichen von Minute 0 bis 59, und das Bild zur Minute 60
    # nimmt die Messung von Minute 59 - eine Minute alt ist frisch. Danach ist Schluss.
    assert len(out.frames) == 5, "nur die erste Stunde ist erfasst"
    assert "91 von 96" in out.hinweise_de[0]


def test_ein_leerer_tag_sagt_dass_er_leer_ist() -> None:
    out = zusammenstellen([], CFG, TAG, BERLIN, step_min=5)
    assert out.frames == []
    assert "keine Minutenwerte" in out.hinweise_de[0]
    assert "nicht, dass nichts geschah" in out.hinweise_de[0]


def test_der_laufende_tag_zaehlt_den_abend_nicht_als_luecke() -> None:
    """Gemessen am Vorführtag: „9 von 96 Bildern fehlen", obwohl nur noch nicht Abend war.

    Das ist derselbe Fehler wie eine Null für eine fehlende Messung, nur in der Begründung: er
    behauptet eine Erfassungslücke, wo bloß Zukunft ist. Beim heutigen Tag endet das Erwartete
    deshalb an jetzt.
    """
    mittags = VON + timedelta(hours=12)
    out = zusammenstellen(tag(12 * 60), CFG, TAG, BERLIN, step_min=15, jetzt=mittags)
    assert out.erwartet == 48, "zwölf Stunden zu einer Viertelstunde"
    assert any("Der Tag läuft noch" in h for h in out.hinweise_de)
    assert not any("fehlen" in h for h in out.hinweise_de), "nichts fehlt, es ist nur noch früh"


def test_ein_vergangener_tag_zaehlt_bis_mitternacht() -> None:
    """Ohne `jetzt` oder mit einem `jetzt` danach bleibt der ganze Tag der Maßstab."""
    danach = VON + timedelta(days=3)
    out = zusammenstellen(tag(60), CFG, TAG, BERLIN, step_min=15, jetzt=danach)
    assert out.erwartet == 96
    assert any("fehlen" in h for h in out.hinweise_de)


def test_der_heizkreis_hinweis_steht_in_jeder_antwort_mit_bildern() -> None:
    out = zusammenstellen(tag(60), CFG, TAG, BERLIN, step_min=15)
    assert any("Heizkreis" in h for h in out.hinweise_de)


def test_eine_unsinnige_schrittweite_wird_abgelehnt() -> None:
    with pytest.raises(ValueError):
        bilder(tag(30), CFG, von=VON, bis=VON + timedelta(hours=1), step_min=0)


def test_die_schrittweiten_sind_geschlossen_aufgezaehlt() -> None:
    """Keine freie Zahl: ein Schritt von 7 Minuten ergibt ein Band ohne lesbares Raster."""
    assert SCHRITTE == (1, 5, 15)
    assert all(1440 % s == 0 for s in SCHRITTE), "jeder Schritt muss den Tag glatt teilen"


def test_am_laufenden_tag_entsteht_kein_bild_hinter_jetzt() -> None:
    """Sonst steht in der Kopfzeile „261 von 259 Bildern", und das ist keine Zahl, sondern ein Bug.

    Ein Zeitpunkt darf eine bis zu schrittweite alte Messung annehmen. Am laufenden Tag entstanden
    damit ein, zwei Bilder hinter `jetzt`, während `erwartet` schon an `jetzt` endete - mehr Bilder
    als möglich. Beide Grenzen müssen dieselbe sein.
    """
    mittags = VON + timedelta(hours=12)
    out = zusammenstellen(tag(13 * 60), CFG, TAG, BERLIN, step_min=15, jetzt=mittags)
    assert len(out.frames) <= out.erwartet, "nie mehr Bilder als mögliche"
    assert all(f.at <= mittags for f in out.frames), "kein Bild aus der Zukunft"
