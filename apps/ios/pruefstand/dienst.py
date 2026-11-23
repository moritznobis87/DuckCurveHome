#!/usr/bin/env python3
"""Ein Dienst zum Draufhalten: genug API, um die Netzschicht der App wirklich zu pruefen.

**Warum das hier steht.** `swift test` prueft, dass der API-Client kompiliert und dass der
SSE-Leser Bytes richtig zerlegt. Was es nicht prueft: ob die Anfrage, die am Ende das Netz
verlaesst, die Kopfzeilen traegt, die der Dienst erwartet - und ob der Ereignisstrom im
Zusammenspiel von Delegate, Actor und Leser tatsaechlich Nachrichten liefert. Das ist genau die
Naht, an der eine Netzschicht typischerweise bricht, und sie laesst sich mit Attrappen nicht
pruefen, weil die Attrappe die Naht ersetzt.

Dieser Dienst antwortet darum echtes HTTP auf einem echten Port:

- `GET /api/v1/live/state` - ein Augenblicksbild
- `GET /api/v1/plan` - ein Plan
- `GET /api/v1/history?range=...` - ein paar Minutenzeilen
- `GET /api/v1/energy/diagnose?day=...` - reiner Text, kein JSON
- `GET /api/v1/live/stream` - der Ereignisstrom, in absichtlich zerhackten Stuecken
- `POST /api/v1/rooms/{id}/setpoint` - gibt die Kopfzeilen zurueck, die ankamen
- `GET /api/v1/kaputt` - ein Fehler im Umschlag des Dienstes
- `GET /api/v1/langsam` - antwortet nie (fuer die Aufsicht)

Das Token ist `pruefstand`. Ohne `Authorization: Bearer pruefstand` kommt 401 - dieselbe Antwort
wie vom echten Dienst, damit auch der Weg durch `ApiFehler` geprueft wird.

    python3 dienst.py 8111
"""

from __future__ import annotations

import contextlib
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

TOKEN = "pruefstand"
JETZT = "2026-02-24T14:35:00Z"


def messwert(wert: float | None, guete: str = "ok") -> dict[str, Any]:
    return {
        "value": wert,
        "observed_at": JETZT,
        "quality": "unavailable" if wert is None else guete,
        "source": "pruefstand",
    }


def augenblick(
    pv: float = 4.2, wp: float = 2.1, preis: float = 18.4, zeit: str = JETZT
) -> dict[str, Any]:
    return {
        "timestamp": zeit,
        "pv_power_kw": messwert(pv),
        "grid_power_kw": messwert(-1.1),
        "battery_power_kw": messwert(-0.6),
        "battery_soc": messwert(0.74),
        "house_power_kw": messwert(2.5),
        "base_load_kw": messwert(0.4),
        "heat_pump_power_kw": messwert(wp),
        "ev_power_kw": messwert(0.0),
        "electricity_price_ct_kwh": messwert(preis),
        "outdoor_temp_c": messwert(6.3),
        "buffer_temps_c": {
            "top": messwert(52.4),
            "mid_top": messwert(47.1),
            "mid_bottom": messwert(38.6),
            "bottom": messwert(31.2),
        },
        "hp_release_contact": messwert(1),
        "hp_block_contact": messwert(0),
        "actuators": {},
        "balance_residual_kw": 0.0,
    }


def live_zustand(pv: float = 4.2, zeit: str = JETZT) -> dict[str, Any]:
    return {
        "snapshot": augenblick(pv=pv, zeit=zeit),
        "buffer": {
            "soc": 0.74,
            "usable_energy_kwh": 13.8,
            "capacity_kwh": 18.6,
            "volume_liters": 800,
            "mean_temp_c": 42.3,
            "status": "warm",
            "method": "layered_energy_v1",
            "headroom_soc": 0.21,
        },
        "heat_pump": {
            "running": True,
            "running_since": JETZT,
            "stopped_since": None,
            "power_kw": 2.1,
            "release_contact_on": True,
            "block_contact_on": False,
            "starts_today": 3,
            "power_known": True,
        },
        "decision": None,
        "operating_mode": {"system_mode": "auto", "auto_profile": "smart", "override": None},
        "stove": None,
        "price_rank": 0.31,
        "today_kwh": {"pv": 14.2, "heat_pump": 7.4},
        "alarm": None,
        "system": {
            "mode": "demo",
            "server_time": JETZT,
            "sim_speed": 1,
            "bridge_online": True,
            "sse_clients": 1,
            "version": "pruefstand",
            "connection_label_de": "Verbunden",
            "sources": [],
            "watch": [],
            "outdoor_shown_c": 6.3,
            "outdoor_source_de": "Prüfstand",
            "hp_actuation": False,
            "hp_actuation_de": "Der Regler entscheidet, schaltet aber nicht.",
        },
    }


PLAN = {
    "created_at": JETZT,
    "planner": "pruefstand",
    "planner_status": "ok",
    "planner_note_de": "Ein Plan vom Prüfstand.",
    "planner_warn_de": None,
    "hp_actuation": False,
    "horizon_start": JETZT,
    "horizon_end": "2026-02-25T14:35:00Z",
    "windows": [],
    "intervals": [],
    "pv_forecast_today_kwh": 16.4,
    "next_cheap_window": None,
    "buffer_capacity_kwh": 18.6,
    "buffer_min_kwh": 4.0,
}


class Hand(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_: Any) -> None:
        pass  # kein Gerede im Testlauf

    # ---------------------------------------------------------------- Werkzeug

    def _token_ok(self) -> bool:
        kopf = self.headers.get("authorization", "")
        return kopf == f"Bearer {TOKEN}"

    def _sende_json(self, rumpf: Any, status: int = 200) -> None:
        roh = json.dumps(rumpf).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(roh)))
        self.end_headers()
        self.wfile.write(roh)

    def _sende_text(self, text: str, status: int = 200) -> None:
        roh = text.encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "text/plain; charset=utf-8")
        self.send_header("content-length", str(len(roh)))
        self.end_headers()
        self.wfile.write(roh)

    def _fehler(self, code: str, meldung: str, status: int) -> None:
        self._sende_json({"error": {"code": code, "message": meldung, "details": None}}, status)

    # ------------------------------------------------------------------- Wege

    def do_GET(self) -> None:
        weg = self.path.split("?")[0]
        frage = self.path.split("?")[1] if "?" in self.path else ""

        if weg == "/health":
            return self._sende_json({"ok": True, "version": "pruefstand"})

        if not self._token_ok():
            return self._fehler("unauthorized", "Kein gültiges API-Token.", 401)

        if weg == "/api/v1/live/state":
            return self._sende_json(live_zustand())

        if weg == "/api/v1/plan":
            return self._sende_json(PLAN)

        if weg == "/api/v1/history":
            zeilen = []
            for i in range(5):
                zeilen.append(
                    {
                        "ts": f"2026-02-24T12:{i:02d}:00Z",
                        "pv_power_kw": 3.0 + i * 0.5,
                        "house_power_kw": 1.2,
                        "grid_power_kw": None,
                        "electricity_price_ct_kwh": 18.4,
                        "hp_release_contact": 1,
                    }
                )
            return self._sende_json(
                {
                    "start": "2026-02-24T12:00:00Z",
                    "end": "2026-02-24T12:05:00Z",
                    "resolution_s": 60,
                    "rows": zeilen,
                }
            )

        if weg == "/api/v1/energy/diagnose":
            return self._sende_text(f"Diagnose für {frage}\nSpalte  Wert\nPV      14,2 kWh\n")

        if weg == "/api/v1/kaputt":
            return self._fehler("buffer_cold", "Der Puffer ist zu kalt für diesen Griff.", 409)

        if weg == "/api/v1/langsam":
            time.sleep(60)
            return

        if weg == "/api/v1/live/stream":
            return self._strom()

        return self._fehler("not_found", f"Kein Weg {weg}.", 404)

    def do_POST(self) -> None:
        weg = self.path.split("?")[0]
        if not self._token_ok():
            return self._fehler("unauthorized", "Kein gültiges API-Token.", 401)
        laenge = int(self.headers.get("content-length") or 0)
        rumpf = self.rfile.read(laenge) if laenge else b""

        if weg.startswith("/api/v1/rooms/") and weg.endswith("/setpoint"):
            # Die Kopfzeilen zurueckgeben, die ankamen: so prueft die App, dass der Urheber
            # wirklich mitreist und nicht nur in `Zugang.kopfzeilen` steht.
            raum_id = int(weg.split("/")[4])
            soll = json.loads(rumpf or b"{}").get("setpoint_c")
            return self._sende_json(
                {
                    "ok": True,
                    "room": {
                        "id": raum_id,
                        "name": "Wohnzimmer",
                        "floor": "EG",
                        "circuits": 2,
                        "temp_c": 21.3,
                        "setpoint_c": soll,
                        "offset_k": 0.0,
                        "target_c": soll,
                        "humidity_pct": 44.0,
                        "valve": 1.0,
                        "window": 0.0,
                        "deviation_k": -0.2,
                        "observed_at": JETZT,
                        "quality": "ok",
                    },
                    "setpoint_c": soll,
                    "message_de": "Gestellt.",
                    "urheber_art": self.headers.get("x-dch-urheber-art"),
                    "urheber_id": self.headers.get("x-dch-urheber-id"),
                    "urheber_name": self.headers.get("x-dch-urheber-name"),
                    "urheber_rolle": self.headers.get("x-dch-urheber-rolle"),
                    "content_type": self.headers.get("content-type"),
                }
            )

        return self._fehler("not_found", f"Kein Weg {weg}.", 404)

    # ---------------------------------------------------------------- Der Strom

    def _strom(self) -> None:
        """Der Ereignisstrom - absichtlich in schlechten Stuecken.

        Ein Dienst, der jeden Rahmen in einem Stueck schickt, prueft den Leser nicht. Hier wird
        mitten in der Zahl geschnitten, ein Kommentar zum Offenhalten eingestreut und ein
        Herzschlag gesendet, damit die Aufsicht der App etwas zu sehen bekommt.
        """
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("x-accel-buffering", "no")
        self.send_header("connection", "keep-alive")
        self.end_headers()

        def schicke(roh: bytes) -> None:
            self.wfile.write(roh)
            self.wfile.flush()

        try:
            erster = json.dumps(live_zustand(pv=4.2)).encode()
            rahmen = b"event: snapshot\nid: 1\ndata: " + erster + b"\n\n"
            # In drei Stuecke zerhacken, eines davon mitten im JSON.
            schnitt = len(rahmen) // 3
            schicke(rahmen[:schnitt])
            time.sleep(0.05)
            schicke(rahmen[schnitt : 2 * schnitt])
            time.sleep(0.05)
            schicke(rahmen[2 * schnitt :])

            schicke(b": offenhalten\n\n")
            schicke(b"event: plan\nid: 2\ndata: " + json.dumps(PLAN).encode() + b"\n\n")
            schicke(b"event: heartbeat\ndata: " + JETZT.encode() + b"\n\n")
            # Ein Ereignis, das die App nicht kennt - sie darf daran nicht scheitern.
            schicke(b'event: kuenftiges\ndata: {"neu":true}\n\n')

            zweiter = json.dumps(live_zustand(pv=5.5, zeit="2026-02-24T14:36:00Z")).encode()
            schicke(b"event: snapshot\nid: 3\ndata: " + zweiter + b"\n\n")
            # Und dann Schluss: die App muss den Abriss bemerken und neu verbinden.
        except (BrokenPipeError, ConnectionResetError):
            pass


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8111
    dienst = ThreadingHTTPServer(("127.0.0.1", port), Hand)
    dienst.daemon_threads = True
    print(f"Prüfstand auf http://127.0.0.1:{port} (Token: {TOKEN})", flush=True)
    with contextlib.suppress(KeyboardInterrupt):
        dienst.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
