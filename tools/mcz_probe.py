#!/usr/bin/env python3
"""Den MCZ-Ofen einmal abfragen - von jedem Rechner im Heimnetz, ohne irgendetwas zu installieren.

    python3 tools/mcz_probe.py 192.168.1.22

Gedacht für die erste Inbetriebnahme: antwortet die Maestro-Platine über die Heimnetz-Adresse, und
welche Fühler hat dieser Ofen überhaupt? Das Skript kommt bewusst mit der Standardbibliothek aus,
also mit jedem Python 3, das auf einem Mac oder einem Raspberry ohnehin liegt. Der WebSocket wird
darum von Hand gesprochen, statt eine Bibliothek zu verlangen.

**Es wird nur gelesen.** Der einzige Rahmen, der hinausgeht, ist `C|RecuperoInfo`. Am Ofen ändert
sich nichts.

Die Feldtabelle ist eine Kopie aus `dch_bridge.sources.mcz_maestro`, damit dieses Skript allein
lauffähig bleibt. Dass beide übereinstimmen, prüft `apps/bridge/tests/test_mcz_maestro.py`.
"""

from __future__ import annotations

import base64
import os
import socket
import sys

GET_INFO = "C|RecuperoInfo"
INFO_MESSAGE_TYPE = "01"
NO_PROBE_RAW = 255

# (Feldposition, Name, Umrechnung) - siehe MAESTRO_FIELDS in der Bridge.
FIELDS: tuple[tuple[int, str, str], ...] = (
    (1, "stove_state", "int"),
    (5, "stove_fume_temp_c", "int"),
    (6, "stove_ambient_temp_c", "half"),
    (7, "stove_buffer_temp_c", "half"),
    (8, "stove_boiler_temp_c", "half"),
    (12, "stove_fume_fan_rpm", "int"),
    (14, "stove_auger_rpm", "int"),
    (15, "stove_dhw_mode", "flag"),
    (16, "stove_pump_pct", "int"),
    (29, "stove_power_level", "int"),
    (37, "stove_operating_hours", "hours"),
    (45, "stove_ignitions", "int"),
    (59, "stove_return_temp_c", "half"),
)


# --------------------------------------------------------------------- WebSocket von Hand
def _handshake(sock: socket.socket, host: str, port: int) -> bytes:
    """HTTP-Upgrade nach RFC 6455. Gibt zurück, was schon zum WebSocket-Strom gehört."""
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall(
        (
            "GET / HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        ).encode()
    )
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("Verbindung beim Handshake geschlossen")
        buf += chunk
    head, rest = buf.split(b"\r\n\r\n", 1)
    status = head.split(b"\r\n", 1)[0].decode("latin-1")
    if " 101" not in status:
        raise ConnectionError(f"kein WebSocket-Upgrade, Antwort war: {status}")
    return rest


def _send_text(sock: socket.socket, text: str) -> None:
    """Textrahmen, maskiert - vom Client zum Server ist die Maske Pflicht."""
    data = text.encode()
    mask = os.urandom(4)
    n = len(data)
    if n < 126:
        header = bytes([0x81, 0x80 | n])
    elif n < 1 << 16:
        header = bytes([0x81, 0x80 | 126]) + n.to_bytes(2, "big")
    else:
        header = bytes([0x81, 0x80 | 127]) + n.to_bytes(8, "big")
    sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


class Frames:
    """Rahmen aus dem Strom lesen. Klein gehalten: der Ofen schickt kurze Textrahmen."""

    def __init__(self, sock: socket.socket, initial: bytes = b"") -> None:
        self.sock = sock
        self.buf = initial

    def _take(self, n: int) -> bytes:
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("Verbindung geschlossen")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def next(self) -> tuple[int, bytes]:
        b0, b1 = self._take(2)
        opcode = b0 & 0x0F
        length = b1 & 0x7F
        if length == 126:
            length = int.from_bytes(self._take(2), "big")
        elif length == 127:
            length = int.from_bytes(self._take(8), "big")
        mask = self._take(4) if b1 & 0x80 else b""
        payload = self._take(length)
        if mask:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        return opcode, payload


# --------------------------------------------------------------------- Deutung
def parse_info(frame: str) -> dict[str, float | None]:
    parts = frame.split("|")
    if not parts or parts[0] != INFO_MESSAGE_TYPE:
        return {}
    out: dict[str, float | None] = {}
    for index, name, kind in FIELDS:
        if index >= len(parts):
            continue
        try:
            raw = int(parts[index], 16)
        except ValueError:
            continue
        if kind == "half":
            out[name] = None if raw == NO_PROBE_RAW else raw / 2
        elif kind == "hours":
            out[name] = raw / 3600
        elif kind == "flag":
            out[name] = 1.0 if raw == 1 else 0.0
        else:
            out[name] = float(raw)
    return out


def report(values: dict[str, float | None]) -> None:
    have = {k: v for k, v in values.items() if v is not None}
    missing = [k for k, v in values.items() if v is None]
    print("\nGelesene Werte:")
    for key, value in have.items():
        print(f"  {key:26} {value:g}")
    if missing:
        print("\nKein Fühler angeschlossen (Rohwert 255):")
        for key in missing:
            print(f"  {key}")
    boiler, ret = have.get("stove_boiler_temp_c"), have.get("stove_return_temp_c")
    if boiler is not None and ret is not None:
        print(f"\nSpreizung des Ofenkreises: {boiler - ret:.1f} K")


def main(host: str, port: int = 81, timeout_s: float = 20.0) -> int:
    print(f"verbinde mit ws://{host}:{port}/ ...")
    try:
        sock = socket.create_connection((host, port), timeout=10)
    except OSError as exc:
        print(f"keine Verbindung: {exc}")
        print("Prüfen: richtige IP? Gleiches Netz? Der Ofen muss im WLAN angemeldet sein.")
        return 1
    sock.settimeout(timeout_s)
    try:
        rest = _handshake(sock, host, port)
        _send_text(sock, GET_INFO)
        frames = Frames(sock, rest)
        while True:
            opcode, payload = frames.next()
            if opcode == 0x9:  # Ping
                continue
            if opcode == 0x8:  # Close
                print("Ofen hat die Verbindung geschlossen, ohne zu antworten")
                return 1
            if opcode != 0x1:
                continue
            text = payload.decode("utf-8", "replace")
            print(f"\nroh: {text}")
            values = parse_info(text)
            if not values:
                continue  # Ping- oder Textnachricht, weiter warten
            report(values)
            return 0
    except TimeoutError:
        print("verbunden, aber kein Info-Rahmen innerhalb der Wartezeit")
        return 1
    except Exception as exc:  # Prüfmodus: jeder Grund soll im Klartext auf dem Schirm stehen
        print(f"fehlgeschlagen: {exc}")
        return 1
    finally:
        sock.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Aufruf: python3 tools/mcz_probe.py <ip-des-ofens> [port]")
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 81))
