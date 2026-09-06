"""Shelly 3EM über MQTT: Topics, Aggregation, Validierung, Takt, Online/Offline, Reconnect, Vergleich."""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from dch_bridge.sources.shelly_mqtt import (
    COUNTER_RESET_AFTER,
    Comparator,
    Em3Device,
    Gen2Device,
    MqttHub,
    Shelly3EmState,
    readings_from_snapshot,
)
from hems_core.domain.quality import Quality
from hems_core.protocol import RawReading

P = "shellies/shellyem3-485519DB56D2"
T0 = datetime(2026, 9, 6, 12, 0, tzinfo=UTC)


def feed(state: Shelly3EmState, phase: int, at: datetime, **fields: float) -> None:
    for fld, val in fields.items():
        assert state.apply(f"{P}/emeter/{phase}/{fld}", str(val).encode(), at)


def test_all_topics_aggregate_to_consistent_snapshot() -> None:
    st = Shelly3EmState(P)
    assert st.apply(f"{P}/online", b"true", T0)
    for ph, pw in enumerate((1200.5, 800.25, 400.0)):
        feed(
            st,
            ph,
            T0,
            power=pw,
            voltage=231.2,
            current=pw / 231.2,
            pf=0.98,
            total=10_000 + ph,
            total_returned=5,
        )
    snap = st.snapshot(T0 + timedelta(seconds=1), timedelta(seconds=90))
    assert snap is not None and snap.online is True
    assert snap.power_w == pytest.approx(2400.75)  # Summe der drei aktuellen Leistungen
    assert snap.energy_wh == pytest.approx(30_003)  # Summe der drei total-Zähler
    assert snap.energy_returned_wh == pytest.approx(15)
    assert snap.at == T0
    readings = {r.key: r for r in readings_from_snapshot(snap, "heat_pump", "485519DB56D2")}
    assert readings["heat_pump_power_kw"].value == pytest.approx(2.40075, abs=1e-4)  # W → kW
    assert readings["heat_pump_energy_kwh"].value == pytest.approx(30.003)  # Wh → kWh
    assert readings["heat_pump_power_l1_kw"].value == pytest.approx(1.2005)
    assert readings["heat_pump_voltage_l3_v"].value == 231.2
    assert readings["heat_pump_energy_returned_l2_kwh"].value == pytest.approx(0.005)
    assert all(
        r.source == "mqtt:shellyem3-485519DB56D2" and r.observed_at == T0 for r in readings.values()
    )
    assert len(readings) == 3 + 3 * 6


def test_incomplete_or_stale_phases_give_no_snapshot() -> None:
    st = Shelly3EmState(P)
    feed(st, 0, T0, power=100)
    feed(st, 1, T0, power=100)
    assert st.snapshot(T0, timedelta(seconds=90)) is None  # Phase 3 fehlt
    feed(st, 2, T0 - timedelta(minutes=5), power=100)
    assert st.snapshot(T0, timedelta(seconds=90)) is None  # Phase 3 veraltet
    feed(st, 2, T0, power=100)
    snap = st.snapshot(T0, timedelta(seconds=90))
    assert (
        snap is not None and snap.energy_wh is None
    )  # keine Zähler → keine Energie, aber Leistung


def test_invalid_payloads_are_rejected_without_crash() -> None:
    st = Shelly3EmState(P)
    bad = [b"", b"abc", b"nan", b"inf", b"1e12", b"-40000", "\xff\xfe".encode("latin-1")]
    for payload in bad:
        assert not st.apply(f"{P}/emeter/0/power", payload, T0)
    assert not st.apply(f"{P}/emeter/0/voltage", b"999", T0)
    assert not st.apply(f"{P}/emeter/1/pf", b"1.5", T0)
    assert not st.apply(f"{P}/emeter/7/power", b"100", T0)  # unbekannte Phase
    assert not st.apply(f"{P}/emeter/0/energy", b"100", T0)  # flüchtiger Zähler wird ignoriert
    assert not st.apply("shellies/other/emeter/0/power", b"100", T0)
    assert not st.apply(f"{P}/online", b"maybe", T0)
    assert st.rejected == len(bad) + 3 and st.phases["0"] == {}


def test_counter_must_not_decrease_until_reset() -> None:
    st = Shelly3EmState(P)
    feed(st, 0, T0, total=5000)
    assert not st.apply(f"{P}/emeter/0/total", b"4000", T0)  # gesunken → verworfen
    assert st.phases["0"]["total"].value == 5000
    assert st.apply(f"{P}/emeter/0/total", b"5000.5", T0)  # gleich/leicht höher ok
    for _ in range(COUNTER_RESET_AFTER - 1):
        assert not st.apply(f"{P}/emeter/0/total", b"12", T0)
    assert st.apply(
        f"{P}/emeter/0/total", b"12", T0
    )  # dauerhaft niedriger → Zählerreset akzeptiert
    assert st.phases["0"]["total"].value == 12


class FakeMessage:
    def __init__(self, topic: str, payload: bytes) -> None:
        self.topic = topic
        self.payload = payload


class FakeSession:
    """Attrappe des MQTT-Clients: liefert vorbereitete Nachrichten, kann beim Verbinden scheitern."""

    def __init__(self, messages: list[FakeMessage], fail_connect: bool = False) -> None:
        self._messages = messages
        self.fail_connect = fail_connect
        self.subscribed: list[tuple[str, int]] = []
        self.published: list[tuple[str, str, int]] = []
        self.echo: Callable[[str, str], FakeMessage | None] | None = None
        self._extra: asyncio.Queue[FakeMessage] = asyncio.Queue()
        self.entered = 0

    async def __aenter__(self) -> FakeSession:
        self.entered += 1
        if self.fail_connect:
            raise ConnectionError("broker weg")
        return self

    async def __aexit__(self, *exc: object) -> None:
        return None

    async def subscribe(self, topic: str, qos: int = 0) -> None:
        self.subscribed.append((topic, qos))

    async def publish(self, topic: str, payload: Any, qos: int = 0) -> None:
        self.published.append((topic, str(payload), qos))
        if self.echo is not None:
            answer = self.echo(topic, str(payload))
            if answer is not None:
                self._extra.put_nowait(answer)

    @property
    def messages(self) -> AsyncIterator[FakeMessage]:
        async def gen() -> AsyncIterator[FakeMessage]:
            for m in self._messages:
                yield m
            while True:  # danach nur noch, was das Gerät auf Kommandos hin meldet
                yield await self._extra.get()

        return gen()


def sample_messages(power: tuple[float, float, float] = (300, 200, 100)) -> list[FakeMessage]:
    out = [FakeMessage(f"{P}/online", b"true")]
    for ph, pw in enumerate(power):
        out.append(FakeMessage(f"{P}/emeter/{ph}/power", str(pw).encode()))
        out.append(FakeMessage(f"{P}/emeter/{ph}/total", str(1000 * (ph + 1)).encode()))
    return out


@pytest.mark.asyncio
async def test_reconnect_after_failed_connection_then_emits(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr("dch_bridge.sources.shelly_mqtt.random.uniform", lambda a, b: 0.0)
    sessions = [FakeSession([], fail_connect=True), FakeSession(sample_messages())]
    calls = iter(sessions)
    received: list[list[RawReading]] = []

    async def sink(items: list[RawReading]) -> None:
        received.append(items)

    src = MqttHub(
        session_factory=lambda: next(calls),
        devices=[Em3Device(topic_prefix=P, device_id="485519DB56D2", key_prefix="heat_pump")],
        on_readings=sink,
        publish_interval_s=0.05,
        qos=1,
    )
    task = asyncio.create_task(src.run())
    try:
        for _ in range(100):
            await asyncio.sleep(0.05)
            if received:
                break
        assert src.reconnects == 1 and src.connected
        assert sessions[1].subscribed == [(f"{P}/#", 1)]
        keys = {r.key: r.value for r in received[0]}
        assert keys["heat_pump_power_kw"] == pytest.approx(0.6)
        assert keys["heat_pump_energy_kwh"] == pytest.approx(6.0)
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task


@pytest.mark.asyncio
async def test_emit_only_on_new_data_and_offline_marks_unavailable() -> None:
    received: list[list[RawReading]] = []

    async def sink(items: list[RawReading]) -> None:
        received.append(items)

    device = Em3Device(topic_prefix=P, device_id="X", key_prefix="heat_pump", stale_s=90)
    src = MqttHub(session_factory=lambda: FakeSession([]), devices=[device], on_readings=sink)
    for m in sample_messages():
        device.apply(m.topic, m.payload, T0)
    assert (
        len(await src.emit_once(T0 + timedelta(seconds=10))) == 2 + 3 * 2
    )  # Summen + je Phase Leistung/Zähler
    assert await src.emit_once(T0 + timedelta(seconds=20)) == []  # nichts Neues → kein Datensatz
    device.apply(f"{P}/online", b"false", T0 + timedelta(seconds=25))
    items = await src.emit_once(T0 + timedelta(seconds=30))
    assert {r.key for r in items} == {"heat_pump_power_kw", "heat_pump_energy_kwh"}
    assert all(r.value is None and r.quality == Quality.UNAVAILABLE for r in items)
    assert await src.emit_once(T0 + timedelta(seconds=40)) == []  # Offline wird nur einmal gemeldet
    # zurück online mit frischen Werten
    for m in sample_messages((10, 10, 10)):
        device.apply(m.topic, m.payload, T0 + timedelta(seconds=50))
    items = await src.emit_once(T0 + timedelta(seconds=55))
    assert {r.key: r.value for r in items}["heat_pump_power_kw"] == pytest.approx(0.03)
    # ohne Nachrichten länger als stale_s → erneut nicht verfügbar
    items = await src.emit_once(T0 + timedelta(seconds=200))
    assert items and all(r.quality == Quality.UNAVAILABLE for r in items)
    assert len(received) == 4


@pytest.mark.asyncio
async def test_compare_mode_measures_but_does_not_forward() -> None:
    received: list[list[RawReading]] = []

    async def sink(items: list[RawReading]) -> None:
        received.append(items)

    comp = Comparator(summary_every=1)
    device = Em3Device(topic_prefix=P, device_id="X", key_prefix="heat_pump", comparator=comp)
    src = MqttHub(
        session_factory=lambda: FakeSession([]),
        devices=[device],
        on_readings=sink,
        forward=False,
    )
    comp.note_ha(0.5, T0)
    for m in sample_messages((300, 200, 100)):  # 0,6 kW gegen 0,5 kW aus HA
        device.apply(m.topic, m.payload, T0)
    items = await src.emit_once(T0 + timedelta(seconds=5))
    assert items and not received  # gemessen, aber nichts an die API
    assert comp.samples == 1 and comp.deviations == 1 and comp.max_delta_kw == pytest.approx(0.1)
    comp.note_ha(0.6, T0)
    for m in sample_messages((300, 200, 100)):
        device.apply(m.topic, m.payload, T0 + timedelta(seconds=6))
    await src.emit_once(T0 + timedelta(seconds=8))
    assert comp.samples == 2 and comp.deviations == 1  # innerhalb der Toleranz


def test_compare_ignores_old_ha_values() -> None:
    comp = Comparator()
    comp.note_ha(1.0, T0 - timedelta(minutes=10))
    assert comp.compare(1.5, T0) is None and comp.samples == 0


@pytest.mark.asyncio
async def test_real_client_factory_builds_expected_connection() -> None:
    """Schützt vor stillen Änderungen der aiomqtt-Signatur: MQTT 3.1.1, Sitzung bleibt bestehen."""
    from dch_bridge.sources.shelly_mqtt import aiomqtt_session_factory

    client = aiomqtt_session_factory("core-mosquitto", 1883, "u", "p", "dch-bridge-haus")()
    assert client._client._protocol == 4  # MQTTv311 – der Shelly 3EM Gen1 spricht kein MQTT 5
    assert client._client._clean_session is False  # Abonnement überlebt einen Verbindungsabbruch
    # ohne Zugangsdaten (anonymer Broker) muss der Aufbau ebenfalls gelingen
    assert aiomqtt_session_factory("h", 1883, "", "", "id")() is not None


def test_topic_prefix_accepts_every_spelling() -> None:
    """Die Geräteoberfläche zeigt die Kennung mal als MAC, mal mit Typ, mal als vollen Pfad."""
    from dch_bridge.settings import BridgeSettings

    def prefix(**kw: object) -> str:
        return BridgeSettings(api_token="t", **kw).shelly_topic_prefix  # type: ignore[arg-type]

    assert prefix(shelly_device_id="485519DB56D2") == "shellies/shellyem3-485519DB56D2"
    assert prefix(shelly_device_id="shellyem3-485519DB56D2") == "shellies/shellyem3-485519DB56D2"
    assert (
        prefix(mqtt_topic_prefix="shellies/shellyem3-485519DB56D2/")
        == "shellies/shellyem3-485519DB56D2"
    )
    assert prefix(mqtt_topic_prefix="shellyem3-485519DB56D2") == "shellies/shellyem3-485519DB56D2"
    # ein selbst gesetztes Präfix mit eigenem Pfad bleibt unangetastet
    assert prefix(mqtt_topic_prefix="haus/waermepumpe") == "haus/waermepumpe"
    assert prefix() == ""


# ---------------------------------------------------------------------- Generation 2 (Plus/Pro)
G2 = "shellyplus1-b8d61a86e20c"
BUFFER = {
    "temperature:100": "buffer_temp_top_c",
    "temperature:101": "buffer_temp_mid_top_c",
    "temperature:102": "buffer_temp_mid_bottom_c",
    "temperature:103": "buffer_temp_bottom_c",
}


def notify(components: dict[str, object], method: str = "NotifyStatus") -> bytes:
    body = {"src": G2, "dst": f"{G2}/events", "method": method, "params": {"ts": 1.0, **components}}
    return json.dumps(body).encode()


def test_gen2_reads_temperatures_from_rpc_notification() -> None:
    dev = Gen2Device(topic_prefix=G2, components=BUFFER)
    assert dev.topics() == [f"{G2}/events/rpc", f"{G2}/status/#"]
    assert dev.owned_keys == set(BUFFER.values())
    assert dev.apply(
        f"{G2}/events/rpc", notify({"temperature:100": {"id": 100, "tC": 58.2, "tF": 136.8}}), T0
    )
    assert dev.apply(
        f"{G2}/events/rpc",
        notify(
            {
                "temperature:101": {"id": 101, "tC": 51.0},
                "temperature:103": {"id": 103, "tC": 33.4},
            },
            method="NotifyFullStatus",
        ),
        T0,
    )
    items = {r.key: r.value for r in dev.emit(T0 + timedelta(seconds=1))}
    assert items == {
        "buffer_temp_top_c": 58.2,
        "buffer_temp_mid_top_c": 51.0,
        "buffer_temp_bottom_c": 33.4,
    }
    assert all(
        r.source == f"mqtt:{G2}"
        for r in dev.emit(T0) or [RawReading(key="x", value=1, observed_at=T0, source=f"mqtt:{G2}")]
    )


def test_gen2_reads_status_topic_and_switch_fields() -> None:
    dev = Gen2Device(
        topic_prefix="shellyplus1pm-aabb",
        components={
            "switch:0": {
                "apower": "coffee_power_kw",
                "aenergy.total": "coffee_energy_kwh",
                "output": "actuator:coffee_machine",
            }
        },
    )
    payload = json.dumps(
        {"id": 0, "output": True, "apower": 1450.0, "voltage": 231.1, "aenergy": {"total": 12345.0}}
    ).encode()
    assert dev.apply("shellyplus1pm-aabb/status/switch:0", payload, T0)
    items = {r.key: r.value for r in dev.emit(T0)}
    assert items["coffee_power_kw"] == pytest.approx(1.45)  # W → kW
    assert items["coffee_energy_kwh"] == pytest.approx(12.345)  # Wh → kWh
    assert items["actuator:coffee_machine"] == 1.0  # Schalterzustand als 0/1


def test_gen2_ignores_unknown_and_invalid_messages() -> None:
    dev = Gen2Device(topic_prefix=G2, components=BUFFER)
    assert not dev.apply(f"{G2}/events/rpc", b"kein json", T0)
    assert not dev.apply(f"{G2}/events/rpc", notify({}, method="NotifyEvent"), T0)
    assert not dev.apply(
        f"{G2}/events/rpc", notify({"temperature:199": {"tC": 20.0}}), T0
    )  # nicht gemappt
    assert not dev.apply("anderes-geraet/events/rpc", notify({"temperature:100": {"tC": 20.0}}), T0)
    assert not dev.apply(
        f"{G2}/events/rpc", notify({"temperature:100": {"tC": 900.0}}), T0
    )  # außerhalb
    assert not dev.apply(f"{G2}/events/rpc", notify({"temperature:100": {"tC": "warm"}}), T0)
    assert dev.emit(T0) == [] and dev.state.rejected >= 3


def test_gen2_values_expire_and_only_new_data_is_emitted() -> None:
    dev = Gen2Device(topic_prefix=G2, components=BUFFER, stale_s=300)
    dev.apply(f"{G2}/events/rpc", notify({"temperature:100": {"tC": 58.2}}), T0)
    assert len(dev.emit(T0)) == 1
    assert dev.emit(T0 + timedelta(seconds=10)) == []  # nichts Neues
    dev.apply(
        f"{G2}/events/rpc", notify({"temperature:101": {"tC": 50.0}}), T0 + timedelta(minutes=10)
    )
    fresh = {r.key for r in dev.emit(T0 + timedelta(minutes=10))}
    assert fresh == {"buffer_temp_mid_top_c"}  # der alte Wert von 100 ist zu alt


@pytest.mark.asyncio
async def test_hub_serves_two_generations_over_one_connection() -> None:
    received: list[RawReading] = []

    async def sink(items: list[RawReading]) -> None:
        received.extend(items)

    em3 = Em3Device(topic_prefix=P, device_id="X", key_prefix="heat_pump")
    gen2 = Gen2Device(topic_prefix=G2, components=BUFFER)
    messages = [
        *sample_messages(),
        FakeMessage(f"{G2}/events/rpc", notify({"temperature:100": {"tC": 57.5}})),
    ]
    session = FakeSession(messages)
    hub = MqttHub(
        session_factory=lambda: session,
        devices=[em3, gen2],
        on_readings=sink,
        publish_interval_s=0.05,
    )
    task = asyncio.create_task(hub.run())
    try:
        for _ in range(100):
            await asyncio.sleep(0.05)
            if received:
                break
        assert sorted(t for t, _ in session.subscribed) == [
            f"{P}/#",
            f"{G2}/events/rpc",
            f"{G2}/status/#",
        ]
        keys = {r.key: r.value for r in received}
        assert keys["heat_pump_power_kw"] == pytest.approx(0.6)
        assert keys["buffer_temp_top_c"] == pytest.approx(57.5)
        status = hub.status()
        assert status["connected"] is True and len(status["devices"]) == 2
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task


PLUG = "Lichterkette_Innenhof"
PLUG_COMPONENTS: dict[str, str | dict[str, str]] = {
    "switch:0": {"output": "actuator:courtyard_light", "apower": "courtyard_light_power_kw"}
}


def test_gen2_builds_switch_set_command() -> None:
    dev = Gen2Device(topic_prefix=PLUG, components=PLUG_COMPONENTS)
    built = dev.command("actuator:courtyard_light", True, 1800)
    assert built is not None
    topic, payload = built
    assert topic == f"{PLUG}/rpc"
    body = json.loads(payload)
    assert body["method"] == "Switch.Set"
    assert body["params"] == {"id": 0, "on": True, "toggle_after": 1800}
    assert body["src"] == "dch-bridge"
    # Ohne Laufzeit kein toggle_after; fortlaufende Kennungen je Kommando
    second = dev.command("actuator:courtyard_light", False, None)
    assert second is not None
    body2 = json.loads(second[1])
    assert body2["params"] == {"id": 0, "on": False} and body2["id"] != body["id"]
    # Was kein Schaltausgang ist, lässt sich nicht schalten
    assert dev.command("courtyard_light_power_kw", True, None) is None
    assert (
        Gen2Device(topic_prefix=G2, components=BUFFER).command("buffer_temp_top_c", True, None)
        is None
    )


def test_gen2_observed_state_follows_notifications() -> None:
    dev = Gen2Device(topic_prefix=PLUG, components=PLUG_COMPONENTS)
    assert dev.observed("actuator:courtyard_light") is None
    body = json.dumps(
        {"src": PLUG, "method": "NotifyStatus", "params": {"ts": 1.0, "switch:0": {"output": True}}}
    ).encode()
    assert dev.apply(f"{PLUG}/events/rpc", body, T0)
    assert dev.observed("actuator:courtyard_light") is True


@pytest.mark.asyncio
async def test_hub_switches_and_waits_for_the_device_to_confirm() -> None:
    """Bestätigt wird nicht das Kommando, sondern die Rückmeldung des Geräts."""

    async def sink(items: list[RawReading]) -> None:
        return None

    dev = Gen2Device(topic_prefix=PLUG, components=PLUG_COMPONENTS)
    session = FakeSession([])

    def echo(topic: str, payload: str) -> FakeMessage:
        on = json.loads(payload)["params"]["on"]
        body = json.dumps(
            {
                "src": PLUG,
                "method": "NotifyStatus",
                "params": {"ts": 1.0, "switch:0": {"output": on}},
            }
        ).encode()
        return FakeMessage(f"{PLUG}/events/rpc", body)

    session.echo = echo
    hub = MqttHub(session_factory=lambda: session, devices=[dev], on_readings=sink, qos=1)
    task = asyncio.create_task(hub.run())
    try:
        for _ in range(100):
            await asyncio.sleep(0.02)
            if hub.connected:
                break
        assert hub.can_switch("actuator:courtyard_light")
        assert not hub.can_switch("actuator:coffee_machine")
        assert await hub.switch("actuator:courtyard_light", True, 1800.0) is True
        assert session.published[0][0] == f"{PLUG}/rpc" and session.published[0][2] == 1
        assert await hub.switch("actuator:courtyard_light", False, None) is False
        assert hub.commands == 2 and hub.status()["commands"] == 2
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task


@pytest.mark.asyncio
async def test_switch_without_confirmation_reports_the_last_known_state() -> None:
    async def sink(items: list[RawReading]) -> None:
        return None

    dev = Gen2Device(topic_prefix=PLUG, components=PLUG_COMPONENTS)
    session = FakeSession([])  # antwortet nicht
    hub = MqttHub(session_factory=lambda: session, devices=[dev], on_readings=sink)
    task = asyncio.create_task(hub.run())
    try:
        for _ in range(100):
            await asyncio.sleep(0.02)
            if hub.connected:
                break
        assert await hub.switch("actuator:courtyard_light", True, None, timeout_s=0.1) is None
        with pytest.raises(LookupError):
            await hub.switch("actuator:unbekannt", True, None, timeout_s=0.1)
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task


@pytest.mark.asyncio
async def test_switch_without_connection_raises() -> None:
    async def sink(items: list[RawReading]) -> None:
        return None

    hub = MqttHub(
        session_factory=lambda: FakeSession([]),
        devices=[Gen2Device(topic_prefix=PLUG, components=PLUG_COMPONENTS)],
        on_readings=sink,
    )
    with pytest.raises(RuntimeError):
        await hub.switch("actuator:courtyard_light", True, None)
