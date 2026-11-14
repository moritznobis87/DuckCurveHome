"""Die Wärmepumpe über eBUS: was ebusd auf den Broker legt, wird zu Messwerten.

Die Nutzdaten in dieser Datei sind am 13.11.2026 aufgezeichnet: ebusd 26.1 mit der
Bus-Beschreibung der Ariston-Gruppe (Fassung f2c9a631) an einem nachgestellten Adapter, der zwei
Telegramme spielt. Nicht aus der Anleitung abgeschrieben.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

from dch_bridge.mapping import EntityMap
from dch_bridge.sources.ebusd_mqtt import EbusdDevice, felder
from hems_core.domain.quality import Quality

T0 = datetime(2026, 11, 13, 21, 48, tzinfo=UTC)
AUSSEN = b'{\n     "0": {"name": "", "value": 8.6}}'
KUEHLKREIS = (
    b'{\n     "LWT_temp": {"value": 35.2},\n     "EWT_temp": {"value": 30.1},\n'
    b'     "evaporator_temp": {"value": 2.5},\n     "coolant_temp": {"value": 40.0}}'
)
FUEHLER_FEHLT = b'{\n     "0": {"name": "", "value": 3276.7}}'
#: Erster Lauf an der Wärmepumpe, 13.11.2026 23:20. Die Zahlen stehen so im Protokoll des Add-ons
#: (`heatpump_ext_unit_info ...: 4.6;9` und `coolat_data: 32.3;-30.9;5.3;28.0`); die Form ist die
#: der oben aufgezeichneten Nachricht mit benannten Feldern.
HAUS_AUSSENGERAET = (
    b'{\n     "ext_temp": {"value": 4.6},\n     "inverter_nominal_power": {"value": 9}}'
)
HAUS_KUEHLKREIS = (
    b'{\n     "LWT_temp": {"value": 32.3},\n     "EWT_temp": {"value": -30.9},\n'
    b'     "evaporator_temp": {"value": 5.3},\n     "coolant_temp": {"value": 28.0}}'
)
ZUORDNUNG = {
    "energymgr/ext_temp": "outdoor_temp_c",
    "heatpump/coolat_data": {"LWT_temp": "flow_temp_c"},
}


def geraet() -> EbusdDevice:
    return EbusdDevice(topic_prefix="ebusd", components=dict(ZUORDNUNG))


def werte(d: EbusdDevice, at: datetime) -> dict[str, float | None]:
    return {r.key: r.value for r in d.emit(at)}


def test_die_aufgezeichneten_nachrichten_werden_gelesen() -> None:
    assert felder(AUSSEN) == {"0": 8.6}
    assert felder(KUEHLKREIS) == {
        "LWT_temp": 35.2,
        "EWT_temp": 30.1,
        "evaporator_temp": 2.5,
        "coolant_temp": 40.0,
    }
    # Wörter sind keine Messwerte, Unlesbares ist keine Nachricht.
    assert felder(b'{"heatpump_mode": {"value": "Heating"}}') == {}
    assert felder(b"kein json") is None
    assert felder(b"[1, 2]") is None


def test_aussentemperatur_und_vorlauf_werden_messwerte() -> None:
    d = geraet()
    assert d.topics() == ["ebusd/#"]
    assert d.owned_keys == {"outdoor_temp_c", "flow_temp_c"}
    assert d.apply("ebusd/energymgr/ext_temp", AUSSEN, T0)
    assert d.apply("ebusd/heatpump/coolat_data", KUEHLKREIS, T0)
    messungen = d.emit(T0 + timedelta(seconds=5))
    assert {r.key: r.value for r in messungen} == {"outdoor_temp_c": 8.6, "flow_temp_c": 35.2}
    assert all(r.quality is Quality.OK and r.observed_at == T0 for r in messungen)
    assert all(r.source == "mqtt:ebusd" for r in messungen)
    assert d.fresh("outdoor_temp_c", T0) and not d.fresh("buffer_temp_top_c", T0)


def test_ein_fehlender_fuehler_ist_kein_messwert() -> None:
    """Der Bus meldet für einen nicht angeschlossenen Fühler 3276,7 (0x7FFF durch zehn)."""
    d = geraet()
    d.apply("ebusd/energymgr/ext_temp", FUEHLER_FEHLT, T0)
    assert werte(d, T0) == {}
    assert d.rejected == 1
    # Ein guter Wert danach zählt wieder; der Marker hat ihn nicht verdrängt.
    d.apply("ebusd/energymgr/ext_temp", AUSSEN, T0)
    d.apply("ebusd/energymgr/ext_temp", FUEHLER_FEHLT, T0 + timedelta(minutes=1))
    assert werte(d, T0 + timedelta(minutes=2)) == {"outdoor_temp_c": 8.6}


def test_alte_werte_gehen_nicht_weiter_damit_home_assistant_einspringen_kann() -> None:
    """Schweigt der Bus zu einem Schlüssel, meldet die Quelle nichts, auch kein „nicht
    verfügbar": die Bridge reicht dann die Entität aus Home Assistant durch, wo es eine gibt."""
    d = geraet()
    d.apply("ebusd/energymgr/ext_temp", AUSSEN, T0)
    spaeter = T0 + timedelta(seconds=d.stale_s + 1)
    assert werte(d, spaeter) == {}
    assert not d.fresh("outdoor_temp_c", spaeter)


def test_was_der_bus_meldet_steht_im_zustand_auch_ohne_zuordnung() -> None:
    """Welche Namen diese Anlage meldet, weiß vorab niemand. Die Quelle merkt sich jeden."""
    d = EbusdDevice(topic_prefix="ebusd", components={})
    assert d.owned_keys == set()
    d.apply("ebusd/energymgr/ext_temp", AUSSEN, T0)
    d.apply("ebusd/heatpump/coolat_data", KUEHLKREIS, T0)
    d.apply("ebusd/global/signal", b"true", T0)
    d.apply("ebusd/global/uptime", b"16", T0)
    assert werte(d, T0) == {}
    zustand = d.status()
    assert zustand["signal"] is True
    assert zustand["messages"] == 2
    assert zustand["gesehen"] == {
        "energymgr/ext_temp": ["0"],
        "heatpump/coolat_data": ["EWT_temp", "LWT_temp", "coolant_temp", "evaporator_temp"],
    }


def test_fremde_themen_und_unlesbares_stoeren_nicht() -> None:
    d = geraet()
    assert d.apply("shellies/irgendwas/online", b"true", T0) is False
    assert d.apply("ebusd/heatpump/coolat_data", b"kaputt", T0) is True
    assert d.apply("ebusd/heatpump/heatpump_ext_temp/get", b"", T0) is True
    assert d.rejected == 1 and d.messages == 0


def test_gelesen_wird_nur() -> None:
    d = geraet()
    assert d.command("outdoor_temp_c", True, None) is None
    assert d.poll() is None
    assert d.observed("outdoor_temp_c") is None


#: Mit ebusd 26.1 und `aerotop_split.csv` aus Telegrammen des Hauses vom 14.11.2026, 00:06,
#: aufgezeichnet: `13fe20100f759e0e0200769e8c0100779e000000` und
#: `131e20000878106e13ca46cb46 / 070f210000000f00`.
SYSTEM_TEMPS = (
    b'{\n     "t_759e": {"value": 52.6},\n     "kennung_2": {"value": "76 9e"},\n'
    b'     "t_769e": {"value": 39.6}}'
)
HP_BETRIEB = (
    b'{\n     "ext_temp": {"value": 3.3},\n     "flow": {"value": 0.0},\n'
    b'     "mode": {"value": 15},\n     "compressor_hz": {"value": 0}}'
)


def test_eine_liste_mit_anderer_zusammensetzung_wird_nicht_gelesen() -> None:
    """Der Regler meldet manche Werte in Listen, und ebusd liest sie mit einer festen Schablone.

    Am 14.11.2026 stand einmal „Hauptpumpe 0; 46; 48715" im Protokoll: eine Liste mit derselben
    ersten Kennung, aber anderem Inhalt, ohne Fehler gelesen. Die Zuordnung des Rücklaufs
    verlangt deshalb, dass vor dem Wert wirklich die Kennung 769e steht.
    """
    zuordnung = {
        "energymgr/system_temps": {"kennung_2": "=76 9e", "t_769e": "heat_pump_return_temp_c"}
    }
    d = EbusdDevice(topic_prefix="ebusd", components=dict(zuordnung))
    # Die Bedingung ist kein Schlüssel.
    assert d.owned_keys == {"heat_pump_return_temp_c"}
    anders = SYSTEM_TEMPS.replace(b"76 9e", b"c9 4b")
    d.apply("ebusd/energymgr/system_temps", anders, T0)
    assert werte(d, T0) == {} and d.rejected == 1
    d.apply("ebusd/energymgr/system_temps", SYSTEM_TEMPS, T0)
    assert werte(d, T0) == {"heat_pump_return_temp_c": 39.6}
    # Fehlt das Feld der Bedingung ganz (älteres Add-on), geht ebenfalls nichts weiter.
    alt = b'{"t_759e": {"value": 47.4}, "t_769e": {"value": 36.9}}'
    d2 = EbusdDevice(topic_prefix="ebusd", components=dict(zuordnung))
    d2.apply("ebusd/energymgr/system_temps", alt, T0)
    assert werte(d2, T0) == {}


def einzelwert(zahl: float) -> bytes:
    return f'{{\n     "0": {{"name": "", "value": {zahl}}}}}'.encode()


def test_die_zuordnung_des_hauses_liest_was_die_waermepumpe_wirklich_meldet() -> None:
    """`config/entities.home.yaml` mit den Werten aus dem Protokoll des Hauses, 13.11.2026 23:30,
    bei laufender Maschine.

    Die Außentemperatur kommt vom Außengerät (`heatpump_ext_unit_info`), nicht aus dem Rundruf
    `energymgr/ext_temp`: den sendet diese Anlage in einer Form, die die Bus-Beschreibung nicht
    erkennt. Leistung und Rücklauf kommen aus den eigenen Zeilen des Add-ons
    (`aerotop_split.csv`), die an genau diesen Telegrammen mit ebusd geprüft sind.
    """
    datei = Path(__file__).resolve().parents[3] / "config" / "entities.home.yaml"
    karte = EntityMap.load(datei)
    ebus = [m for m in karte.mqtt if m.kind == "ebusd"]
    assert len(ebus) == 1 and ebus[0].prefix == "ebusd"
    # Die Schlüssel zählen als über den Broker geliefert: nur dann lässt die Bridge Home
    # Assistant bei frischen Werten aus. Die Wetterstation bleibt als Rückfallebene eingetragen.
    assert {"outdoor_temp_c", "flow_temp_c"} <= karte.mqtt_keys()
    assert "outdoor_temp_c" in {s.key for s in karte.sensors}
    d = EbusdDevice(topic_prefix=ebus[0].prefix, components=ebus[0].components)
    d.apply("ebusd/heatpump/heatpump_ext_unit_info", HAUS_AUSSENGERAET, T0)
    d.apply(
        "ebusd/heatpump/coolat_data",
        HAUS_KUEHLKREIS.replace(b"32.3", b"39.9").replace(b"28.0", b"36.6"),
        T0,
    )
    d.apply("ebusd/heatpump/heatpump_flowmeter", einzelwert(29.8), T0)
    d.apply("ebusd/energymgr/hybrid_LWT_setpoint", einzelwert(45.0), T0)
    d.apply("ebusd/heatpump/hp_power", b'{\n     "power_kw": {"value": 1.448}}', T0)
    d.apply("ebusd/energymgr/system_temps", SYSTEM_TEMPS, T0)
    d.apply("ebusd/heatpump/hp_betrieb", HP_BETRIEB, T0)
    d.apply(
        "ebusd/heatpump/hp_kaeltekreis",
        b'{"suction_temp": {"value": 3.3}, "discharge_temp": {"value": 46.4}}',
        T0,
    )
    # Mitgelesen, aber nicht zugeordnet: bleibt im Zustand sichtbar und geht nicht weiter.
    d.apply("ebusd/energymgr/speicher_info", b'{"store_temp": {"value": 53.5}}', T0)
    assert werte(d, T0) == {
        "outdoor_temp_c": 4.6,
        "flow_temp_c": 39.9,
        "heat_pump_flow_l_min": 29.8,
        "heat_pump_flow_setpoint_c": 45.0,
        "heat_pump_bus_power_kw": 1.448,
        "heat_pump_return_temp_c": 39.6,
        "heat_pump_compressor_hz": 0.0,
        "heat_pump_mode_code": 15.0,
        "heat_pump_evaporator_temp_c": 5.3,
        "heat_pump_liquid_temp_c": 36.6,
        "heat_pump_suction_temp_c": 3.3,
        "heat_pump_discharge_temp_c": 46.4,
        "heat_pump_tank_temp_c": 52.6,
    }
    assert "energymgr/speicher_info" in d.status()["gesehen"]


def test_was_die_bridge_vom_bus_liefert_hat_im_dienst_einen_platz() -> None:
    """Jeder zugeordnete Schlüssel der Wärmepumpe ist eine Reihe der Minutentabelle. Sonst käme
    der Wert an, stünde eine Minute im Zustand und wäre danach für immer weg."""
    quelle = (
        Path(__file__).resolve().parents[3] / "apps/api/src/dch_api/infrastructure/history.py"
    ).read_text(encoding="utf-8")
    datei = Path(__file__).resolve().parents[3] / "config" / "entities.home.yaml"
    ebus = next(m for m in EntityMap.load(datei).mqtt if m.kind == "ebusd")
    d = EbusdDevice(topic_prefix=ebus.prefix, components=ebus.components)
    fehlend = sorted(k for k in d.owned_keys if f'"{k}"' not in quelle)
    assert not fehlend, f"ohne Reihe in der Minutentabelle: {fehlend}"


def test_die_lage_nennt_die_erste_stelle_an_der_es_haengt() -> None:
    """Broker, ebusd, Bus, Zuordnung, Weitergabe: in der Reihenfolge des Weges.

    Am 14.11.2026 zeigte die Seite der Wärmepumpe im Haus lauter Fragezeichen, und von außen war
    nicht zu sehen, an welcher dieser Stellen es lag. Seitdem sagt es die Bridge.
    """
    from dch_bridge.sources.ebusd_mqtt import LAGEN, STUMM_S

    d = geraet()
    assert d.lage(verbunden=False, weitergabe=True, now=T0) == "broker_getrennt"
    # Angemeldet, aber unter dem Thema kommt nichts: das Add-on läuft nicht oder spricht woanders.
    assert d.lage(verbunden=True, weitergabe=True, now=T0) == "kein_wort"
    # ebusd läuft, hört aber den Bus nicht.
    d.apply("ebusd/global/signal", b"false", T0)
    d.apply("ebusd/heatpump/unbekannt", b'{"0": {"name": "", "value": 1}}', T0)
    assert d.lage(verbunden=True, weitergabe=True, now=T0) == "kein_signal"
    # Signal da, Nachrichten da, aber keine, die zugeordnet ist.
    d.apply("ebusd/global/signal", b"true", T0)
    assert d.lage(verbunden=True, weitergabe=True, now=T0) == "nicht_zugeordnet"
    d.apply("ebusd/heatpump/coolat_data", KUEHLKREIS, T0)
    assert d.lage(verbunden=True, weitergabe=False, now=T0) == "nur_mitlesen"
    assert d.lage(verbunden=True, weitergabe=True, now=T0) == "ok"
    # Zehn Minuten ohne ein Wort: verstummt, auch wenn die alten Werte noch als frisch gelten.
    spaeter = T0 + timedelta(seconds=STUMM_S + 1)
    assert d.fresh("flow_temp_c", spaeter)
    assert d.lage(verbunden=True, weitergabe=True, now=spaeter) == "verstummt"
    # Jede Lage hat eine Einstufung, und nur eine heißt in Ordnung.
    assert [wort for wort, stufe in LAGEN.items() if stufe == "ok"] == ["ok"]
    for wort in (
        "broker_getrennt",
        "kein_wort",
        "kein_signal",
        "nicht_zugeordnet",
        "nur_mitlesen",
        "verstummt",
        "abgeschaltet",
    ):
        assert LAGEN[wort] in ("degraded", "down")


def test_die_bridge_meldet_die_lage_des_busses_in_die_cloud(tmp_path: Path) -> None:
    """Die ganze Bridge, wie sie im Haus läuft: mit der Zuordnung des Hauses, ohne Broker.

    Ohne Verbindung zum Broker heißt die Lage `broker_getrennt`, mit Verbindung und ohne
    Nachricht `kein_wort`, mit einer zugeordneten Nachricht `ok`. Und was gemeldet wird, steht
    als Zustand der Quelle `ebusd` zum Versand bereit.
    """
    import asyncio

    from dch_bridge.main import VERSION, Bridge
    from dch_bridge.settings import BridgeSettings
    from hems_core.protocol import DeviceHealthFrame

    haus = EntityMap.load(Path(__file__).resolve().parents[3] / "config" / "entities.home.yaml")
    settings = BridgeSettings(api_token="t", outbox_path=tmp_path / "outbox.sqlite")
    b = Bridge(settings, haus)
    assert b.mqtt is not None
    stand = b.ebus_lage(T0)
    assert stand is not None
    lage, einzel = stand
    assert lage == "broker_getrennt"
    assert einzel["bridge"] == VERSION and einzel["thema"] == "ebusd"

    b.mqtt.connected = True
    assert b.ebus_lage(T0) == ("kein_wort", einzel)
    bus = next(d for d in b.mqtt.devices if isinstance(d, EbusdDevice))
    bus.apply("ebusd/heatpump/heatpump_flowmeter", einzelwert(29.8), T0)
    lage, einzel = b.ebus_lage(T0) or ("", {})
    assert lage == "ok"
    assert (einzel["nachrichten"], einzel["namen"], einzel["werte"]) == ("1", "1", "1")

    # Im Modus home_assistant gibt es die Quelle nicht; auch das ist eine Auskunft.
    aus = Bridge(
        BridgeSettings(
            api_token="t", outbox_path=tmp_path / "o2.sqlite", source_mode="home_assistant"
        ),
        haus,
    )
    assert (aus.ebus_lage(T0) or ("", {}))[0] == "abgeschaltet"
    # Eine Zuordnung ohne Bus meldet nichts.
    ohne = Bridge(
        BridgeSettings(api_token="t", outbox_path=tmp_path / "o3.sqlite"),
        EntityMap.model_validate({"sensors": []}),
    )
    assert ohne.ebus_lage(T0) is None

    asyncio.run(b.uplink.emit_health(T0, "ebusd", "down", {"lage": "kein_wort"}))
    wartend = list(b.uplink._events)
    assert len(wartend) == 1 and isinstance(wartend[0], DeviceHealthFrame)
    assert wartend[0].source == "ebusd" and wartend[0].details == {"lage": "kein_wort"}


def test_die_betriebsart_des_reglers_wird_nur_aus_der_richtigen_liste_gelesen() -> None:
    """Der Regler sendet seine Betriebsart (Kennung c94b) in einer Liste mit der Hauptpumpe und
    allein. Die Nachrichten sind die, die ebusd 26.1 am 14.11.2026 aus den Telegrammen des Hauses
    auf den Broker gelegt hat (`13fe20100cc2000100c74b8e00c94b1000`, laufend, PV-Nutzung).

    Am 13.11.2026 kam dieselbe Nachricht einmal anders zusammengesetzt (`0;46;48715`); mit den
    Kennungen als eigene Felder liest die Bridge sie dann nicht.
    """
    datei = Path(__file__).resolve().parents[3] / "config" / "entities.home.yaml"
    ebus = next(m for m in EntityMap.load(datei).mqtt if m.kind == "ebusd")
    d = EbusdDevice(topic_prefix=ebus.prefix, components=ebus.components)
    laufend = (
        b'{\n     "main_pump": {"value": 1},\n     "kennung_2": {"value": "c7 4b"},\n'
        b'     "wert_c74b": {"value": 142},\n     "kennung_3": {"value": "c9 4b"},\n'
        b'     "wert_c94b": {"value": 16}}'
    )
    d.apply("ebusd/energymgr/pumpe_status", laufend, T0)
    assert werte(d, T0)["heat_pump_cycle_code"] == 16.0
    # Anders zusammengesetzt: die Kennungen stimmen nicht, der Wert bleibt der alte.
    verrutscht = laufend.replace(b"c9 4b", b"2e 00").replace(b'"value": 16', b'"value": 48715')
    d.apply("ebusd/energymgr/pumpe_status", verrutscht, T0)
    assert werte(d, T0)["heat_pump_cycle_code"] == 16.0
    # Ein Add-on vor 0.2.2 schickt die Liste ohne Kennungen; auch die wird nicht gelesen.
    alt = b'{"main_pump": {"value": 0}, "wert_c74b": {"value": 190}, "wert_c94b": {"value": 0}}'
    d.apply("ebusd/energymgr/pumpe_status", alt, T0)
    assert werte(d, T0)["heat_pump_cycle_code"] == 16.0
    # Allein im Rundruf: Warmwasser.
    d.apply("ebusd/energymgr/betriebsart", b'{\n     "code": {"value": 3}}', T0)
    assert werte(d, T0)["heat_pump_cycle_code"] == 3.0
