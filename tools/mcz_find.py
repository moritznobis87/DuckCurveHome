#!/usr/bin/env python3
"""Den MCZ-Ofen im Heimnetz suchen, wenn die vermutete Adresse nicht antwortet.

    python3 tools/mcz_find.py                # ganzes /24 des eigenen Netzes absuchen
    python3 tools/mcz_find.py 192.168.1.22   # nur diesen einen Host, alle Kandidatenports

Warum es das braucht: `Connection refused` auf Port 81 heißt, dass ein Gerät antwortet, dort aber
nichts lauscht - im Unterschied zu einem Timeout, hinter dem gar kein Host steckt. Zwei Ursachen
kommen dann infrage. Entweder ist die Adresse nicht der Ofen, oder die Maestro-Platine bedient den
WebSocket nur auf ihrem eigenen Hotspot und nicht auf der Heimnetz-Schnittstelle. Genau darauf weist
`hackximus/MCZ-Maestro-API` hin, das deshalb zwei Netzwerkkarten verlangt.

Das Skript unterscheidet die beiden Fälle: es sucht jeden Host, der überhaupt einen der
Kandidatenports offen hat, und spricht ihn dann an. Ein Gerät, das auf `C|RecuperoInfo` mit einem
Info-Rahmen antwortet, ist der Ofen. Alles andere ist es nicht.

Nur Standardbibliothek, damit es auf jedem Mac und jedem Raspberry ohne Installation läuft. Es wird
ausschließlich gelesen; der einzige Rahmen, der hinausgeht, ist `C|RecuperoInfo`.
"""

from __future__ import annotations

import base64
import os
import socket
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

GET_INFO = "C|RecuperoInfo"
# 81 ist der dokumentierte Port. Die anderen sind das, was Wifi-Module dieser Bauart sonst gern
# belegen - lieber ein paar Verbindungsversuche zu viel als eine Suche, die zu früh aufgibt.
CANDIDATE_PORTS = (81, 80, 8080, 8081, 8000, 5000, 5001, 9000)
CONNECT_TIMEOUT_S = 0.4


def local_subnet() -> str:
    """Das eigene /24 bestimmen, ohne ein Paket zu senden."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("192.0.2.1", 9))  # TEST-NET-1, wird nie erreicht
        ip = sock.getsockname()[0]
    finally:
        sock.close()
    return ip.rsplit(".", 1)[0]


def port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=CONNECT_TIMEOUT_S):
            return True
    except OSError:
        return False


def sweep(subnet: str) -> list[tuple[str, int]]:
    targets = [(f"{subnet}.{n}", p) for n in range(1, 255) for p in CANDIDATE_PORTS]
    with ThreadPoolExecutor(max_workers=200) as pool:
        results = pool.map(lambda t: (t, port_open(*t)), targets)
    return [t for t, ok in results if ok]


def mac_table() -> dict[str, str]:
    """`arp -a` auswerten, damit sich ein Fund gegen die MAC in der MCZ-App prüfen lässt."""
    try:
        # Festes Kommando, keine Nutzereingabe im Argumentvektor.
        out = subprocess.run(
            ["arp", "-a"], capture_output=True, text=True, timeout=10, check=False
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    table: dict[str, str] = {}
    for line in out.splitlines():
        if "(" not in line or ")" not in line:
            continue
        ip = line.split("(", 1)[1].split(")", 1)[0]
        parts = line.split()
        for i, word in enumerate(parts):
            if word == "at" and i + 1 < len(parts):
                table[ip] = parts[i + 1]
                break
    return table


def speaks_maestro(host: str, port: int, timeout_s: float = 6.0) -> str | None:
    """Einen Info-Rahmen anfordern. Gibt ihn roh zurück, oder None, wenn dort kein Maestro sitzt."""
    try:
        sock = socket.create_connection((host, port), timeout=timeout_s)
    except OSError:
        return None
    sock.settimeout(timeout_s)
    try:
        sock.sendall(
            (
                "GET / HTTP/1.1\r\n"
                f"Host: {host}:{port}\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {base64.b64encode(os.urandom(16)).decode()}\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                return None
            buf += chunk
        head, buf = buf.split(b"\r\n\r\n", 1)
        if b" 101" not in head.split(b"\r\n")[0]:
            return None
        payload = GET_INFO.encode()
        mask = os.urandom(4)
        sock.sendall(
            bytes([0x81, 0x80 | len(payload)])
            + mask
            + bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        )

        def take(n: int) -> bytes:
            nonlocal buf
            while len(buf) < n:
                chunk = sock.recv(65536)
                if not chunk:
                    raise ConnectionError
                buf += chunk
            out, buf = buf[:n], buf[n:]
            return out

        for _ in range(10):  # ein paar Rahmen Rauschen abwarten, dann aufgeben
            b0, b1 = take(2)
            opcode, length = b0 & 0x0F, b1 & 0x7F
            if length == 126:
                length = int.from_bytes(take(2), "big")
            elif length == 127:
                length = int.from_bytes(take(8), "big")
            frame_mask = take(4) if b1 & 0x80 else b""
            data = take(length)
            if frame_mask:
                data = bytes(b ^ frame_mask[i % 4] for i, b in enumerate(data))
            if opcode != 0x1:
                continue
            text = data.decode("utf-8", "replace")
            if text.split("|", 1)[0] == "01":
                return text
        return None
    except OSError:
        return None
    finally:
        sock.close()


def main(argv: list[str]) -> int:
    macs = mac_table()
    if argv:
        host = argv[0]
        print(f"prüfe {host} auf {len(CANDIDATE_PORTS)} Ports ...")
        found = [(host, p) for p in CANDIDATE_PORTS if port_open(host, p)]
        if not found:
            print(f"\n{host} hat keinen dieser Ports offen: {', '.join(map(str, CANDIDATE_PORTS))}")
            print("Entweder ist es nicht der Ofen, oder die Platine lauscht nur auf ihrem Hotspot.")
            print("Nächster Schritt: python3 tools/mcz_find.py  (ohne Adresse, sucht das ganze Netz)")
            return 1
    else:
        subnet = local_subnet()
        print(f"suche in {subnet}.0/24 ... das dauert einige Sekunden")
        found = sweep(subnet)
        if not found:
            print("\nkein Gerät mit einem der Kandidatenports gefunden")
            return 1

    print(f"\n{len(found)} offene Ports gefunden, spreche sie an:\n")
    hits = 0
    for host, port in found:
        mac = macs.get(host, "")
        frame = speaks_maestro(host, port)
        if frame:
            hits += 1
            print(f"  ★ {host}:{port}  {mac}  spricht Maestro")
            print(f"    roh: {frame}")
        else:
            print(f"    {host}:{port}  {mac}  offen, aber kein Maestro")

    if hits:
        print("\nDie mit ★ markierte Adresse in mcz_host eintragen.")
        return 0
    print("\nOffene Ports ja, Maestro nein. Vergleiche die MAC oben mit der in der MCZ-App unter")
    print("SOFTWARE VERSIONEN. Steht sie nicht dabei, ist der Ofen im Heimnetz nicht erreichbar,")
    print("und die Platine bedient den WebSocket nur auf ihrem eigenen Hotspot.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
