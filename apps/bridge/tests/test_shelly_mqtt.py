"""Shelly 3EM über MQTT: Topics, Aggregation, Validierung, Takt, Online/Offline, Reconnect, Vergleich."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import pytest

from dch_bridge.sources.shelly_mqtt import (
    COUNTER_RESET_AFTER,
    Comparator,
    Shelly3EmState,
    ShellyMqttSource,
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

    @property
    def messages(self) -> AsyncIterator[FakeMessage]:
        async def gen() -> AsyncIterator[FakeMessage]:
            for m in self._messages:
                yield m
            await asyncio.sleep(3600)  # Verbindung bleibt offen

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

    src = ShellyMqttSource(
        session_factory=lambda: next(calls),
        topic_prefix=P,
        device_id="485519DB56D2",
        key_prefix="heat_pump",
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

    src = ShellyMqttSource(
        session_factory=lambda: FakeSession([]),
        topic_prefix=P,
        device_id="X",
        key_prefix="heat_pump",
        on_readings=sink,
        stale_s=90,
    )
    for m in sample_messages():
        src.state.apply(m.topic, m.payload, T0)
    assert (
        len(await src.emit_once(T0 + timedelta(seconds=10))) == 2 + 3 * 2
    )  # Summen + je Phase Leistung/Zähler
    assert await src.emit_once(T0 + timedelta(seconds=20)) == []  # nichts Neues → kein Datensatz
    src.state.apply(f"{P}/online", b"false", T0 + timedelta(seconds=25))
    items = await src.emit_once(T0 + timedelta(seconds=30))
    assert {r.key for r in items} == {"heat_pump_power_kw", "heat_pump_energy_kwh"}
    assert all(r.value is None and r.quality == Quality.UNAVAILABLE for r in items)
    assert await src.emit_once(T0 + timedelta(seconds=40)) == []  # Offline wird nur einmal gemeldet
    # zurück online mit frischen Werten
    for m in sample_messages((10, 10, 10)):
        src.state.apply(m.topic, m.payload, T0 + timedelta(seconds=50))
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
    src = ShellyMqttSource(
        session_factory=lambda: FakeSession([]),
        topic_prefix=P,
        device_id="X",
        key_prefix="heat_pump",
        on_readings=sink,
        comparator=comp,
        forward=False,
    )
    comp.note_ha(0.5, T0)
    for m in sample_messages((300, 200, 100)):  # 0,6 kW gegen 0,5 kW aus HA
        src.state.apply(m.topic, m.payload, T0)
    items = await src.emit_once(T0 + timedelta(seconds=5))
    assert items and not received  # gemessen, aber nichts an die API
    assert comp.samples == 1 and comp.deviations == 1 and comp.max_delta_kw == pytest.approx(0.1)
    comp.note_ha(0.6, T0)
    for m in sample_messages((300, 200, 100)):
        src.state.apply(m.topic, m.payload, T0 + timedelta(seconds=6))
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
