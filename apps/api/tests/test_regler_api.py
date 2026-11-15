"""Die Einstellungen des Reglers: gelesen über den Bus, als Liste für die Seite „Regler“."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import yaml
from fastapi.testclient import TestClient

from dch_api.application import regler as logik
from hems_core.domain.measurement import Measurement, Quality

JETZT = datetime(2026, 11, 15, 10, 0, tzinfo=UTC)


def mess_aus(werte: dict[str, float], alter_s: float = 60.0):  # type: ignore[no-untyped-def]
    def mess(key: str) -> Measurement:
        if key not in werte:
            return Measurement.missing(Quality.UNAVAILABLE, JETZT, key)
        m = Measurement.ok(werte[key], JETZT - timedelta(seconds=alter_s), "mqtt:ebusd")
        return m.aged(JETZT, logik.STALE_S)

    return mess


def test_gelesene_einstellungen_stehen_mit_wert_und_lesart_da() -> None:
    aus = logik.zusammensetzen(now=JETZT, mess=mess_aus(logik.vorfuehrung()))
    assert aus.gelesen == 22 and len(aus.werte) == 22
    assert aus.satz_de == "Alle 22 Einstellungen gelesen."
    nach = {w.schluessel: w for w in aus.werte}
    steil = nach["heat_pump_set_slope"]
    assert (steil.wert.value, steil.stellen, steil.gruppe_de, steil.kennung) == (
        0.7,
        2,
        "Heizkurve",
        "6a71",
    )
    assert (steil.stellbar, steil.von, steil.bis, steil.schritt, steil.art) == (
        True,
        0.2,
        3.5,
        0.1,
        "zahl",
    )
    # Eine Kennzahl bleibt eine Zahl; was die Busbeschreibung dazu sagt, steht daneben.
    art = nach["heat_pump_set_curve_type"]
    assert art.wert.value == 2.0 and art.lesart_de == "nach Außentemperatur"
    assert not art.stellbar and art.art == "wahl" and art.wahl["0"] == "fester Vorlauf"
    assert nach["heat_pump_set_flow_max_c"].lesart_de is None
    assert [w.gruppe_de for w in aus.werte].count("Warmwasser") == 5
    assert sum(1 for w in aus.werte if w.stellbar) == 14
    # Ohne Vermerk ist nichts verglichen, und stellen lässt sich ohne Angabe nichts.
    assert not any(w.bestaetigt for w in aus.werte) and not aus.stellen_moeglich
    gruen = nach["heat_pump_set_heat_mode"]
    assert gruen.muster and gruen.wahl == {"0": "Green", "1": "Standard"}


def test_fehlende_und_alte_einstellungen_werden_nicht_als_gelesen_gezaehlt() -> None:
    leer = logik.zusammensetzen(now=JETZT, mess=mess_aus({}))
    assert leer.gelesen == 0 and leer.satz_de.startswith("Noch keine Einstellung gelesen.")
    teil = logik.zusammensetzen(
        now=JETZT, mess=mess_aus({"heat_pump_set_slope": 1.2, "heat_pump_set_dhw_mode": 7.0})
    )
    assert teil.gelesen == 2 and teil.satz_de.startswith("2 von 22 Einstellungen gelesen.")
    # Eine Zahl, die die Busbeschreibung nicht kennt, bekommt keine Lesart.
    assert {w.schluessel: w for w in teil.werte}["heat_pump_set_dhw_mode"].lesart_de is None
    # Älter als eine Dreiviertelstunde gilt nicht mehr als gelesen.
    alt = logik.zusammensetzen(now=JETZT, mess=mess_aus(logik.vorfuehrung(), alter_s=3600.0))
    assert alt.gelesen == 0


def test_die_vier_sicherungen_vor_dem_stellen() -> None:
    """Stellbar, gerade gelesen, mit dem Bediengerät verglichen, in Grenzen und Raster, nicht
    zu oft am Tag: in dieser Reihenfolge, und jede Ablehnung ist ein Satz."""
    steil = logik.NACH_KEY["heat_pump_set_slope"]
    gelesen = Measurement.ok(0.7, JETZT, "mqtt:ebusd")

    def grund(e, wert, **kw):  # type: ignore[no-untyped-def]
        angaben = {"gelesen": gelesen, "bestaetigt": True, "heute_gestellt": 0, **kw}
        return logik.pruefen(e, wert, **angaben)

    assert grund(steil, 0.8) is None
    assert grund(None, 0.8) == "Diese Einstellung ist nicht bekannt."
    nur_lesen = logik.NACH_KEY["heat_pump_set_curve_type"]
    assert grund(nur_lesen, 0.0) == "„Art der Vorlaufregelung“ lässt sich von hier nur lesen."
    assert "gerade nicht gelesen" in (grund(steil, 0.8, gelesen=None) or "")
    alt = Measurement.ok(0.7, JETZT - timedelta(hours=2), "mqtt:ebusd").aged(JETZT, logik.STALE_S)
    assert "gerade nicht gelesen" in (grund(steil, 0.8, gelesen=alt) or "")
    assert "noch nicht mit dem Bediengerät verglichen" in (
        grund(steil, 0.8, bestaetigt=False) or ""
    )
    assert (
        grund(steil, 3.6) == "„Steilheit“ lässt sich von hier nur zwischen 0,20 und 3,50 stellen."
    )
    assert grund(steil, 0.75) == "„Steilheit“ lässt sich nur in Schritten von 0,10 stellen."
    assert "heute schon 12-mal gestellt" in (grund(steil, 0.8, heute_gestellt=12) or "")
    # Eine Verschiebung von null und eine negative sind Werte wie andere.
    versch = logik.NACH_KEY["heat_pump_set_offset_k"]
    assert grund(versch, 0.0) is None and grund(versch, -2.5) is None
    assert grund(versch, -7.5) == (
        "„Verschiebung“ lässt sich von hier nur zwischen −7,0 K und 7,0 K stellen."
    )
    assert logik.runde(versch, -2.4) == -2.5 and logik.runde(steil, 0.84) == 0.8
    assert logik.text(versch, -2.5) == "−2,5 K"
    assert logik.text(logik.NACH_KEY["heat_pump_set_heat_mode"], 0.0) == "0 (Green)"


def test_ein_gesendeter_wert_wartet_auf_die_rueckmeldung_des_reglers() -> None:
    gesendet = {"heat_pump_set_slope": (0.8, JETZT - timedelta(minutes=2))}
    # Noch der alte Wert gelesen: der gesendete wartet.
    assert logik.offen(gesendet, mess_aus({"heat_pump_set_slope": 0.7}), JETZT) == gesendet
    # Der Regler meldet den neuen Wert, nach dem Senden gelesen: erledigt.
    assert logik.offen(gesendet, mess_aus({"heat_pump_set_slope": 0.8}, alter_s=30.0), JETZT) == {}
    # Derselbe Wert, aber vor dem Senden gelesen, zählt nicht als Rückmeldung.
    assert (
        logik.offen(gesendet, mess_aus({"heat_pump_set_slope": 0.8}, alter_s=600.0), JETZT)
        == gesendet
    )
    # Nach einer halben Stunde ohne Rückmeldung gilt er als nicht übernommen.
    alt = {"heat_pump_set_slope": (0.8, JETZT - timedelta(minutes=31))}
    assert logik.offen(alt, mess_aus({"heat_pump_set_slope": 0.7}), JETZT) == {}
    aus = logik.zusammensetzen(
        now=JETZT, mess=mess_aus(logik.vorfuehrung()), gesendet=gesendet, stellen_moeglich=True
    )
    wert = {w.schluessel: w for w in aus.werte}["heat_pump_set_slope"]
    assert wert.gesendet is not None and wert.gesendet.wert == 0.8 and wert.wert.value == 0.7


def test_liste_add_on_und_zuordnung_kennen_dieselben_einstellungen() -> None:
    """Vier Stellen müssen übereinstimmen: die Liste hier, die Zeilen des Add-ons zum Abfragen
    und zum Stellen, und die Zuordnung der Bridge. Die Zeilen des Add-ons entstehen aus der
    Liste; weicht eine ab, bleibt ein Wert still leer oder, schlimmer, wird etwas stellbar, das
    es nicht sein soll."""
    from pathlib import Path

    wurzel = Path(__file__).resolve().parents[3]
    addon = wurzel / "addons" / "duckcurve_ebusd"

    def zeilen(datei: str, art: str) -> list[str]:
        return [
            z for z in (addon / datei).read_text(encoding="utf-8").splitlines() if z.startswith(art)
        ]

    assert zeilen("aerotop_abfragen.csv", "r9,") == [
        logik.zeile_lesen(e) for e in logik.EINSTELLUNGEN
    ]
    stellbar = [e for e in logik.EINSTELLUNGEN if e.stellbar]
    assert zeilen("aerotop_stellen.csv", "w") == [logik.zeile_stellen(e) for e in stellbar]
    assert len(stellbar) == 14
    # In der Datei zum Stellen steht nichts anderes als Kommentare und diese Zeilen.
    andere = [
        z
        for z in (addon / "aerotop_stellen.csv").read_text(encoding="utf-8").splitlines()
        if z and not z.startswith(("#", "w,energymgr,e_"))
    ]
    assert andere == []
    karte = yaml.safe_load((wurzel / "config" / "entities.home.yaml").read_text(encoding="utf-8"))
    ebus = next(m for m in karte["mqtt"] if m.get("kind") == "ebusd")
    for e in logik.EINSTELLUNGEN:
        assert ebus["components"][f"energymgr/{e.thema}"] == {"wert": e.key}, e.key
    assert logik.vorfuehrung().keys() == logik.NACH_KEY.keys()


def test_in_der_vorfuehrung_laesst_sich_vergleichen_stellen_und_nachlesen(
    client: TestClient,
) -> None:
    basis = "/api/v1/waermepumpe/einstellungen"
    d = client.get(basis).json()
    assert (
        d["gelesen"] == 22
        and d["stellen_moeglich"]
        and d["hinweise_de"][0].startswith("Vorführung")
    )
    # Ohne Vergleich mit dem Bediengerät wird nicht gestellt.
    r = client.post(f"{basis}/heat_pump_set_offset_k", json={"wert": -2.0})
    assert r.status_code == 409 and "Bediengerät" in r.json()["error"]["message"]
    r = client.post(f"{basis}/heat_pump_set_offset_k/bestaetigen", json={"bestaetigt": True})
    assert r.status_code == 200 and r.json()["ok"]
    r = client.post(f"{basis}/heat_pump_set_offset_k", json={"wert": -2.0})
    assert r.status_code == 200 and r.json()["ok"]
    stand = {w["schluessel"]: w for w in r.json()["einstellungen"]["werte"]}
    assert stand["heat_pump_set_offset_k"]["wert"]["value"] == -2.0
    assert stand["heat_pump_set_offset_k"]["bestaetigt"]
    zeile = r.json()["einstellungen"]["protokoll"][0]
    assert (zeile["von_de"], zeile["auf_de"]) == ("0,0 K", "−2,0 K")
    # Außerhalb der Grenzen, nur lesbar, unbekannt: jeweils eine klare Absage.
    assert client.post(f"{basis}/heat_pump_set_offset_k", json={"wert": 9.0}).status_code == 409
    assert client.post(f"{basis}/heat_pump_set_curve_type", json={"wert": 0}).status_code == 409
    assert client.post(f"{basis}/gibt_es_nicht", json={"wert": 1}).status_code == 404
    # Zurück auf den alten Wert, damit andere Tests dieselbe Vorführung vorfinden.
    client.post(f"{basis}/heat_pump_set_offset_k", json={"wert": 0.0})
    client.post(f"{basis}/heat_pump_set_offset_k/bestaetigen", json={"bestaetigt": False})


async def test_im_haus_geht_der_befehl_an_die_bridge_und_steht_im_protokoll(tmp_path) -> None:  # type: ignore[no-untyped-def]
    """Der echte Weg: Dienst, Bridge, Protokoll. Die Bridge ist hier ein Platzhalter, der den
    Befehl festhält; dass sie ihn an ebusd weitergibt, prüft `test_ebusd_mqtt.py`."""
    import uuid

    import pytest

    from dch_api.application.config_loader import load_app_config
    from dch_api.application.forecast_service import ForecastService
    from dch_api.application.live_runtime import LiveRuntime
    from dch_api.errors import DchError
    from dch_api.infrastructure.bridge_hub import BridgeHub
    from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
    from dch_api.infrastructure.db.repositories import SqlRepositories
    from dch_api.settings import Settings
    from hems_core.protocol import CommandResultFrame, RawReading

    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'regler.sqlite'}",
        db_create_all=True,
        weather_refresh_min=0,
        role="api",
        actuation_enabled=True,
    )
    engine = make_engine(settings.database_url)
    await create_all_for_tests(engine)
    cfg = load_app_config(None)
    hub = BridgeHub("test")
    rt = LiveRuntime(
        settings,
        cfg,
        SqlRepositories(engine),
        hub,
        ForecastService(cfg.site, cfg.pv_system, weather=None, prices=None),
    )
    gesendet: list[tuple[str, float | None]] = []

    async def send_command(key, state, ttl_s, decision_id, timeout_s=10.0, value=None):  # type: ignore[no-untyped-def]
        gesendet.append((key, value))
        return CommandResultFrame(command_id=uuid.uuid4(), ok=True, observed_state=None, at=rt.now)

    hub.send_command = send_command  # type: ignore[method-assign]
    key = "heat_pump_set_offset_k"
    rt.live.apply([RawReading(key=key, value=0.0, observed_at=rt.now, source="mqtt:ebusd")])

    # Keine Bridge verbunden: stellen ist nicht möglich, und die Antwort sagt es.
    stand = await rt.regler_einstellungen()
    assert not stand.stellen_moeglich and stand.hindernis_de == "Die Bridge ist nicht verbunden."

    hub._ws = object()  # type: ignore[assignment]
    hub.last_frame_at = datetime.now(UTC)
    hub.bridge_version = "0.14.5"
    assert "ab 0.15.0" in ((await rt.regler_einstellungen()).hindernis_de or "")
    hub.bridge_version = "0.15.0"
    assert (await rt.regler_einstellungen()).stellen_moeglich

    # Nicht verglichen: abgelehnt, und nichts geht hinaus.
    with pytest.raises(DchError) as abgelehnt:
        await rt.regler_stellen(key, -2.0)
    assert "Bediengerät" in abgelehnt.value.message and gesendet == []

    assert (await rt.regler_bestaetigen(key, True)).ok
    aus = await rt.regler_stellen(key, -2.0)
    assert aus.ok and gesendet == [("ebus:heat_pump_set_offset_k:stellen", -2.0)]
    wert = {w.schluessel: w for w in aus.einstellungen.werte}[key]
    # Die Anzeige bekommt keinen Wert geschenkt: gelesen ist weiter 0,0, gesendet −2,0.
    assert wert.wert.value == 0.0 and wert.gesendet is not None and wert.gesendet.wert == -2.0
    zeile = aus.einstellungen.protokoll[0]
    assert (zeile.schluessel, zeile.von_de, zeile.auf_de) == (key, "0,0 K", "−2,0 K")

    # Der Regler meldet den neuen Wert: der gesendete ist erledigt.
    rt.live.apply([RawReading(key=key, value=-2.0, observed_at=rt.now, source="mqtt:ebusd")])
    wert = {w.schluessel: w for w in (await rt.regler_einstellungen()).werte}[key]
    assert wert.wert.value == -2.0 and wert.gesendet is None
    await engine.dispose()
