"""Sequenznummern: eine neu startende Bridge darf nicht ins Leere senden."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from dch_api.infrastructure.bridge_hub import BridgeHub
from hems_core.domain.quality import Quality
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame


class FakeWs:
    def __init__(self) -> None:
        self.sent: list[str] = []

    async def send_text(self, text: str) -> None:
        self.sent.append(text)

    async def close(self, code: int = 1000, reason: str = "") -> None:
        return None


def hello(last_acked: int = 0) -> HelloFrame:
    return HelloFrame(
        bridge_version="t",
        bridge_id="haus",
        clock=datetime.now(UTC),
        entity_map_hash="x",
        keys=["pv_power_kw"],
        last_acked_seq=last_acked,
    )


def telemetry(seq: int, value: float) -> TelemetryFrame:
    return TelemetryFrame(
        seq=seq,
        sent_at=datetime.now(UTC),
        items=[
            RawReading(
                key="pv_power_kw",
                value=value,
                observed_at=datetime.now(UTC),
                quality=Quality.OK,
                source="mqtt:x",
            )
        ],
    )


@pytest.mark.asyncio
async def test_reconnect_accepts_a_restarted_sequence(monkeypatch: pytest.MonkeyPatch) -> None:
    """Beginnt die Bridge nach einem Neustart wieder bei 1, muss die API das annehmen.

    Vorher verglich sie stur mit ihrem eigenen Höchststand, verwarf jedes Paket - und bestätigte es
    trotzdem, sodass die Bridge es löschte. Der Verlust blieb auf beiden Seiten unsichtbar.
    """
    seen: list[list[RawReading]] = []

    async def sink(items: list[RawReading], is_backlog: bool) -> None:
        seen.append(items)

    hub = BridgeHub("test")
    hub.on_telemetry = sink

    await hub.serve(FakeWs(), hello())  # type: ignore[arg-type]
    for seq in (1, 2, 3):
        await hub.handle(telemetry(seq, 1.0))
    assert len(seen) == 3 and hub.last_seq == 3

    # Neue Verbindung, Bridge zählt wieder ab 1
    await hub.serve(FakeWs(), hello(last_acked=0))  # type: ignore[arg-type]
    assert hub.last_seq == 0
    for seq in (1, 2):
        await hub.handle(telemetry(seq, 2.0))
    assert len(seen) == 5
    assert hub.skipped == 0


@pytest.mark.asyncio
async def test_repeated_sequence_within_one_connection_is_reported() -> None:
    """Ein echtes Doppel wird weiterhin übergangen - aber nicht mehr stillschweigend."""
    seen: list[list[RawReading]] = []

    async def sink(items: list[RawReading], is_backlog: bool) -> None:
        seen.append(items)

    hub = BridgeHub("test")
    hub.on_telemetry = sink
    await hub.serve(FakeWs(), hello())  # type: ignore[arg-type]
    await hub.handle(telemetry(1, 1.0))
    await hub.handle(telemetry(1, 2.0))
    assert len(seen) == 1 and hub.skipped == 1


@pytest.mark.asyncio
async def test_der_zustand_einer_quelle_wird_gemerkt_und_nur_der_wechsel_weitergereicht() -> None:
    """Die Bridge meldet die Lage des Busses alle fünf Minuten. Das Ereignisprotokoll bekommt
    davon nur den Wechsel, sonst stünde dort zwölfmal in der Stunde dasselbe."""
    from hems_core.protocol import DeviceHealthFrame

    hub = BridgeHub("test")
    gemeldet: list[str] = []

    async def on_event(frame: object) -> None:
        assert isinstance(frame, DeviceHealthFrame)
        gemeldet.append(frame.details["lage"])

    hub.on_event = on_event  # type: ignore[assignment]
    await hub.serve(FakeWs(), hello())  # type: ignore[arg-type]
    assert hub.bridge_version == "t" and hub.keys == frozenset({"pv_power_kw"})

    def stand(lage: str, status: str) -> DeviceHealthFrame:
        return DeviceHealthFrame(
            at=datetime.now(UTC),
            source="ebusd",
            status=status,  # type: ignore[arg-type]
            details={"lage": lage},
        )

    for lage, status in [("kein_wort", "down"), ("kein_wort", "down"), ("ok", "ok"), ("ok", "ok")]:
        await hub.handle(stand(lage, status))
    assert gemeldet == ["kein_wort", "ok"]
    assert hub.health_by_source["ebusd"].details["lage"] == "ok"
    # Eine neue Verbindung beginnt ohne Vorwissen: was vorher galt, muss nicht mehr gelten.
    await hub.serve(FakeWs(), hello())  # type: ignore[arg-type]
    assert hub.health_by_source == {}
