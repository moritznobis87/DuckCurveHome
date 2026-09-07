"""Der eigene WebSocket-Client gegen einen Ofen, der sich nicht an die Norm hält.

Die Firmware des MCZ-Maestro maskiert ihre Antwortrahmen, obwohl RFC 6455 das nur in der
Gegenrichtung erlaubt. Eine normkonforme Bibliothek beendet die Verbindung daraufhin mit
`1002 protocol error`. Genau deshalb spricht die Bridge den WebSocket selbst.

Der Server hier ist absichtlich falsch gebaut: er maskiert, wie das echte Gerät. Ein Test, der einen
korrekten Server nachstellt, würde die Eigenschaft prüfen, auf die es nicht ankommt.
"""

from __future__ import annotations

import asyncio
import base64
import os

import pytest

from dch_bridge.sources.mcz_maestro import (
    OPCODE_PING,
    OPCODE_TEXT,
    MaestroStove,
    _client_frame,
    _read_frame,
)

INFO_FRAME = "01|" + "|".join(
    format(v, "X")
    for v in [
        15,  # 1 Stove_State
        0,
        0,
        0,
        155,  # 5 Rauchgas
        44,  # 6 Raum 22,0
        118,  # 7 Puffer 59,0
        160,  # 8 Kessel 80,0
        255,  # 9 NTC3: kein Fühler
        *[0] * 2,
        708,  # 12 Rauchgasgebläse
        0,
        300,  # 14 Förderschnecke
        0,
        100,  # 16 Pumpe
        *[0] * 12,
        5,  # 29 Leistungsstufe
        *[0] * 7,
        307 * 3600,  # 37 Betriebsstunden
        *[0] * 7,
        170,  # 45 Zündungen
        *[0] * 13,
        128,  # 59 Rücklauf 64,0
        0,
    ]
)


def _server_frame(opcode: int, payload: bytes, *, masked: bool) -> bytes:
    """Rahmen vom Server. `masked=True` ist der Normverstoß, den der echte Ofen begeht.

    Die erweiterte Länge muss sein: ein Info-Rahmen hat über 60 Felder und sprengt die 125 Bytes,
    die in das kurze Längenfeld passen.
    """
    n = len(payload)
    flag = 0x80 if masked else 0
    if n < 126:
        header = bytes([0x80 | opcode, flag | n])
    elif n < 1 << 16:
        header = bytes([0x80 | opcode, flag | 126]) + n.to_bytes(2, "big")
    else:
        header = bytes([0x80 | opcode, flag | 127]) + n.to_bytes(8, "big")
    if not masked:
        return header + payload
    mask = os.urandom(4)
    return header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload))


class FakeStove:
    """Ein Ofen aus rohem TCP: Handschlag von Hand, Antwort maskiert."""

    def __init__(self, *, masked: bool = True, send_ping: bool = False) -> None:
        self.masked = masked
        self.send_ping = send_ping
        self.requests: list[bytes] = []
        self.pongs = 0
        self._server: asyncio.Server | None = None

    @property
    def port(self) -> int:
        assert self._server is not None
        return self._server.sockets[0].getsockname()[1]

    async def __aenter__(self) -> FakeStove:
        self._server = await asyncio.start_server(self._handle, "127.0.0.1", 0)
        return self

    async def __aexit__(self, *exc: object) -> None:
        assert self._server is not None
        self._server.close()
        await self._server.wait_closed()

    async def _handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            await reader.readuntil(b"\r\n\r\n")
            accept = base64.b64encode(os.urandom(20)).decode()
            writer.write(
                (
                    "HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
                ).encode()
            )
            await writer.drain()
            if self.send_ping:
                writer.write(_server_frame(OPCODE_PING, b"hallo", masked=self.masked))
                await writer.drain()
            while True:
                opcode, payload = await _read_frame(reader)
                if opcode == OPCODE_TEXT:
                    self.requests.append(payload)
                    writer.write(_server_frame(OPCODE_TEXT, b"PING", masked=self.masked))
                    writer.write(
                        _server_frame(OPCODE_TEXT, INFO_FRAME.encode(), masked=self.masked)
                    )
                    await writer.drain()
                else:
                    self.pongs += 1
        except (asyncio.IncompleteReadError, ConnectionError, asyncio.CancelledError):
            pass
        finally:
            writer.close()


async def _collect_one(stove: MaestroStove, seen: list[list]) -> None:
    """Die Quelle laufen lassen, bis der erste Satz Messwerte da ist."""
    task = asyncio.create_task(stove.run())
    try:
        for _ in range(200):
            if seen:
                return
            await asyncio.sleep(0.02)
        raise AssertionError("keine Messwerte innerhalb der Wartezeit")
    finally:
        task.cancel()
        try:  # noqa: SIM105 - contextlib.suppress verdeckt hier den Abbruchpfad
            await task
        except asyncio.CancelledError:
            pass


@pytest.mark.parametrize("masked", [True, False])
async def test_maskierte_und_unmaskierte_antworten_werden_beide_gelesen(masked: bool) -> None:
    """Der echte Ofen maskiert. Ein normgerechtes Gerät täte es nicht. Beides muss gehen."""
    seen: list[list] = []

    async def collect(items: list) -> None:
        seen.append(items)

    async with FakeStove(masked=masked) as server:
        stove = MaestroStove(
            url=f"ws://127.0.0.1:{server.port}/",
            on_readings=collect,
            poll_interval_s=0.05,
        )
        await _collect_one(stove, seen)

    assert server.requests[0] == b"C|RecuperoInfo", "es wird nur gelesen, nie geschrieben"
    values = {r.key: r.value for r in seen[0]}
    assert values["stove_state"] == 15
    assert values["stove_buffer_temp_c"] == 59.0
    assert values["stove_boiler_temp_c"] == 80.0
    assert values["stove_return_temp_c"] == 64.0
    assert values["stove_auger_rpm"] == 300
    assert values["stove_running"] == 1.0


async def test_ping_wird_beantwortet_und_nicht_gedeutet() -> None:
    """Ein Ping darf weder als Messwert durchgehen noch die Verbindung beenden."""
    seen: list[list] = []

    async def collect(items: list) -> None:
        seen.append(items)

    async with FakeStove(send_ping=True) as server:
        stove = MaestroStove(
            url=f"ws://127.0.0.1:{server.port}/",
            on_readings=collect,
            poll_interval_s=0.05,
        )
        await _collect_one(stove, seen)
        assert server.pongs >= 1, "auf einen Ping gehört ein Pong"

    assert {r.key for r in seen[0]} >= {"stove_state", "stove_running"}


async def test_ohne_upgrade_kein_ofen() -> None:
    """Ein Server, der nicht auf WebSocket umschaltet, führt zu einer klaren Ausnahme."""

    async def plain(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        await reader.readuntil(b"\r\n\r\n")
        writer.write(b"HTTP/1.1 404 Not Found\r\n\r\n")
        await writer.drain()
        writer.close()

    server = await asyncio.start_server(plain, "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    try:
        from dch_bridge.sources.mcz_maestro import _handshake

        with pytest.raises(ConnectionError, match="kein WebSocket-Upgrade"):
            await _handshake("127.0.0.1", port, timeout_s=5.0)
    finally:
        server.close()
        await server.wait_closed()


def test_client_rahmen_sind_immer_maskiert() -> None:
    """In dieser Richtung schreibt die Norm die Maske vor, und daran halten wir uns."""
    frame = _client_frame(OPCODE_TEXT, b"C|RecuperoInfo")
    assert frame[0] == 0x81
    assert frame[1] & 0x80, "Maskenbit fehlt"
    mask = frame[2:6]
    assert bytes(b ^ mask[i % 4] for i, b in enumerate(frame[6:])) == b"C|RecuperoInfo"
