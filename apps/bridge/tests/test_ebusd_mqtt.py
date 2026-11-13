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


def test_die_zuordnung_des_hauses_kennt_die_waermepumpe() -> None:
    """`config/entities.home.yaml` trägt das Gerät ein, und die Schlüssel zählen als über den
    Broker geliefert: nur dann lässt die Bridge Home Assistant bei frischen Werten aus."""
    datei = Path(__file__).resolve().parents[3] / "config" / "entities.home.yaml"
    karte = EntityMap.load(datei)
    ebus = [m for m in karte.mqtt if m.kind == "ebusd"]
    assert len(ebus) == 1 and ebus[0].prefix == "ebusd"
    assert {"outdoor_temp_c", "flow_temp_c"} <= karte.mqtt_keys()
    d = EbusdDevice(topic_prefix=ebus[0].prefix, components=ebus[0].components)
    d.apply("ebusd/energymgr/ext_temp", AUSSEN, T0)
    d.apply("ebusd/heatpump/coolat_data", KUEHLKREIS, T0)
    assert werte(d, T0) == {"outdoor_temp_c": 8.6, "flow_temp_c": 35.2}
