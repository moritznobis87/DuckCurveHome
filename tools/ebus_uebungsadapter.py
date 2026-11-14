"""Ein eBUS-Adapter zum Üben: spielt zwei Telegramme, ohne dass eine Heizung daran hängt.

Wozu: Das Add-on „Duck Curve eBUS" lässt ebusd an einem Netzwerk-Adapter lauschen. Ob die Kette
vom Adapter über ebusd und den Broker bis zur Bridge hält, soll sich prüfen lassen, bevor sie an
der Wärmepumpe hängt. Dieses Skript gibt sich auf Port 9999 als Adapter aus, spricht dessen
erweitertes Protokoll und spielt im Takt eines echten Busses zwei Telegramme:

- den Rundruf der Außentemperatur (`energymgr/ext_temp`), 8,6 °C,
- eine abgehörte Frage mit Antwort (`heatpump/coolat_data`): Vorlauf 35,2, Rücklauf 30,1,
  Verdampfer 2,5 und Kältemittel 40,0 °C.

Dazu drei Telegramme, wie sie am 13.11.2026 um 23:30 im Haus über den Bus gingen (aus dem
Protokoll des Add-ons, bei laufender Maschine): die Leistungsaufnahme (1,448 kW), der Rundruf
mit den Temperaturen 759e und 769e (47,6 und 36,5 °C) und der Rundruf der Außentemperatur
(4,7 °C). Sie prüfen die eigenen Zeilen des Add-ons (`aerotop_split.csv`).

Es schreibt mit, was ebusd an den Adapter schickt. Im Nur-Lese-Betrieb sind das genau zwei
Nachrichten an den Adapter selbst (`c081` Anmeldung, `cc80` Abfrage der Fassung) und nichts für
den Bus.

Seit dem Add-on 0.3.0 fragt ebusd auf Wunsch vier Werte selbst ab. Dafür spielt das Skript auch
die Gegenseite: es gibt ebusd den Bus frei, gibt jedes gesendete Byte zurück, wie ein Adapter am
Bus es hört, und antwortet auf die vier Fragen aus `ANTWORTEN` als Regler oder Wärmepumpe. Jede
Frage steht als `EBUSD FRAGT` im Protokoll, jede andere als `OHNE ANTWORT`: so zeigt sich auch,
ob ebusd etwas sendet, das es nicht senden soll.

Aufruf:  python3 tools/ebus_uebungsadapter.py [Sekunden]

Dann das Add-on (oder ebusd) mit `ens:<dieser Rechner>:9999` starten.

Zwei Dinge, an denen die erste Fassung gescheitert ist (13.11.2026):

- **Ohne den Ruhetakt hört ebusd nichts.** Auf einem echten Bus kommt alle rund 40 ms ein SYN,
  solange niemand spricht. Bleibt er aus, hält ebusd die Leitung nach rund 170 ms für gestört
  und überhört das nächste Telegramm, ohne etwas zu melden.
- **Die Prüfsumme** ist die des eBUS (Polynom 0x9B), geprüft am bekannten Telegramm
  `10 08 b5 11 01 01` mit der Prüfsumme `89`.
"""

from __future__ import annotations

import socket
import sys
import threading
import time

SYN = b"\xaa"
RUHETAKT_S = 0.035
BYTE_S = 0.005  # ein Byte bei 2400 Baud dauert gut 4 ms


def crc8(data: bytes) -> int:
    crc = 0
    for byte in data:
        b = byte
        for _ in range(8):
            poly = 0x9B if crc & 0x80 else 0
            crc = ((crc & 0x7F) << 1) & 0xFF
            if b & 0x80:
                crc |= 1
            crc ^= poly
            b = (b << 1) & 0xFF
    return crc


def erweitert(raw: bytes) -> bytes:
    """Empfangene Bytes im erweiterten Protokoll: unter 0x80 unverändert, sonst als Paar."""
    out = bytearray()
    for b in raw:
        if b < 0x80:
            out.append(b)
        else:
            out += bytes([0xC0 | (1 << 2) | (b >> 6), 0x80 | (b & 0x3F)])
    return bytes(out)


def rundruf() -> bytes:
    m = bytes.fromhex("13fe200f04" + "7647" + "5600")
    return m + bytes([crc8(m)])


def frage_und_antwort() -> bytes:
    q = bytes.fromhex("131e200008" + "7610771079107117")
    a = bytes.fromhex("09" + "00" + "6001" + "2d01" + "1900" + "9001")
    return q + bytes([crc8(q)]) + b"\x00" + a + bytes([crc8(a)]) + b"\x00"


def telegramm(frage: str, antwort: str | None = None) -> bytes:
    """Ein Telegramm aus Hex, so wie es im Protokoll von ebusd steht (ohne Prüfsummen)."""
    q = bytes.fromhex(frage)
    out = q + bytes([crc8(q)])
    if antwort is not None:
        a = bytes.fromhex(antwort)
        out += b"\x00" + a + bytes([crc8(a)]) + b"\x00"
    return out


#: Aus dem Protokoll des Hauses, 13.11.2026 23:30.
HAUS = (
    telegramm("131e2000027c4f", "0301a805"),
    telegramm("13fe20100f759edc0100769e6d0100779e000000"),
    telegramm("13fe20100576472f0000"),
    # 14.11.2026 00:06: Außentemperatur, Durchfluss, Zustand 15, Verdichter 0 Hz.
    telegramm("131e20000878106e13ca46cb46", "070f210000000f00"),
)


#: Was Regler (18) und Wärmepumpe (1e) auf die Fragen des Add-ons antworten: Ziel, Befehl und
#: Kennung der Frage, dazu die Antwort ohne Prüfsumme (Länge, ein Byte Status, der Wert).
ANTWORTEN = {
    "1820000601": "020001",  # Umschaltventil: Stellung 1
    "1820001c45": "020000",  # Heizstab: 0
    "1e2000714f": "03004e00",  # Strom des Verdichters: 7,8 A
    "1e20006e4f": "03005802",  # Lüfter: 600
}


def paar(befehl: int, wert: int) -> bytes:
    """Eine Nachricht des erweiterten Protokolls: vier Bit Befehl, acht Bit Wert, in zwei Bytes."""
    return bytes([0xC0 | (befehl << 2) | (wert >> 6), 0x80 | (wert & 0x3F)])


def zerlegen(daten: bytes) -> list[tuple[int, int]]:
    """Was ebusd schickt, als Folge von (Befehl, Wert): 0 Anmeldung, 1 Senden, 2 Bus anfordern,
    3 Auskunft. Ein einzelnes Byte unter 0x80 ist ein gesendetes Byte in Kurzform."""
    aus: list[tuple[int, int]] = []
    i = 0
    while i < len(daten):
        b = daten[i]
        if b & 0xC0 == 0xC0 and i + 1 < len(daten):
            aus.append(((b >> 2) & 0x0F, ((b & 0x03) << 6) | (daten[i + 1] & 0x3F)))
            i += 2
        else:
            aus.append((1, b))
            i += 1
    return aus


def main() -> None:
    dauer = float(sys.argv[1]) if len(sys.argv) > 1 else 60.0
    assert crc8(bytes.fromhex("1008b5110101")) == 0x89
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", 9999))
    srv.listen(1)
    print("Übungsadapter wartet auf Port 9999", flush=True)
    conn, _ = srv.accept()
    print("ebusd verbunden", flush=True)

    # Der Bus gehört immer einem: entweder der Schleife unten, die den Ruhetakt und die
    # abgehörten Telegramme spielt, oder ebusd, solange es selbst fragt.
    bus = threading.Lock()
    frage: bytearray | None = None
    frei_um = 0.0

    def gehoert(roh: bytes) -> None:
        conn.sendall(erweitert(roh))

    def freigeben() -> None:
        nonlocal frage
        frage = None
        if bus.locked():
            bus.release()

    def lesen() -> None:
        nonlocal frage, frei_um
        while True:
            d = conn.recv(256)
            if not d:
                return
            for befehl, wert in zerlegen(d):
                if befehl == 0:  # Anmeldung: ein echter Adapter antwortet mit „zurückgesetzt"
                    print("VON EBUSD: Anmeldung", flush=True)
                    conn.sendall(paar(0, 1))
                elif befehl == 3:  # Auskunft verlangt: Länge 2, dann zwei Bytes
                    print("VON EBUSD: Auskunft", flush=True)
                    for teil in (2, 1, 1):
                        conn.sendall(paar(3, teil))
                elif befehl == 2:  # ebusd will senden: Bus freigeben, sobald er ruht
                    bus.acquire()
                    frei_um = time.time() + 0.6
                    frage = bytearray([wert])
                    conn.sendall(paar(2, wert))
                elif befehl == 1:
                    gehoert(bytes([wert]))  # ein Adapter hört, was er selbst sendet
                    if wert == 0xAA:  # ebusd schließt mit dem Ruhezeichen
                        freigeben()
                        continue
                    if frage is None:
                        continue
                    frage.append(wert)
                    if len(frage) >= 5 and len(frage) == 6 + frage[4]:
                        kopf = bytes(frage[:-1])
                        schluessel = kopf[1:4].hex() + kopf[5:].hex()
                        antwort = ANTWORTEN.get(schluessel)
                        gut = crc8(kopf) == frage[-1]
                        if antwort is None or not gut or kopf[1] == 0xFE:
                            print(
                                "OHNE ANTWORT:",
                                kopf.hex(),
                                "" if gut else "(Prüfsumme falsch)",
                                flush=True,
                            )
                        else:
                            print("EBUSD FRAGT:", kopf.hex(), "->", antwort, flush=True)
                            a = bytes.fromhex(antwort)
                            for b in b"\x00" + a + bytes([crc8(a)]):
                                gehoert(bytes([b]))
                                time.sleep(BYTE_S)
                        frage = bytearray()  # was jetzt noch kommt, ist die Quittung

    threading.Thread(target=lesen, daemon=True).start()

    def sende(teil: bytes) -> None:
        with bus:
            for b in teil:
                conn.sendall(erweitert(bytes([b])))
                time.sleep(BYTE_S)

    def waechter() -> None:
        # Lässt ebusd den Bus nicht von selbst los, bekommt ihn die Schleife nach 0,6 s zurück.
        while True:
            time.sleep(0.1)
            if bus.locked() and frage is not None and time.time() > frei_um:
                freigeben()

    threading.Thread(target=waechter, daemon=True).start()

    ende = time.time() + dauer
    n = 0
    while time.time() < ende:
        n += 1
        sende(SYN)
        if n % 25 == 0:
            sende(rundruf())
        elif n % 25 == 12:
            sende(frage_und_antwort())
        elif n % 25 in (5, 9, 17, 21):
            sende(HAUS[(5, 9, 17, 21).index(n % 25)])
        else:
            time.sleep(RUHETAKT_S)
    print("Übungsadapter fertig", flush=True)


if __name__ == "__main__":
    main()
