"""Alfred: Werkzeugschleife, Grenzen, Werkzeuge, Vorschlaege, Auswertungen (docs/ALFRED.md).

Das Sprachmodell ist hier ein `httpx.MockTransport`, der vorgegebene Antworten liefert und jede
Anfrage aufhebt - damit laesst sich pruefen, was an den Anbieter gegangen waere.
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable, Iterator
from datetime import UTC, date, datetime
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from dch_api.alfred import dienst, leitfaeden, papiere, rechnung, werkzeuge, zuordnung
from dch_api.alfred.werkzeuge import Kontext
from dch_api.main import create_app
from dch_api.routers.control import ACTUATOR_LABELS
from dch_api.settings import Settings

SCHLUESSEL = "geheim-123"


def _settings(**mehr: Any) -> Settings:
    return Settings(
        demo_autostart=False,
        demo_warmup_hours=26.0,
        demo_start=datetime(2026, 9, 4, 11, 30, tzinfo=UTC),
        demo_seed=3,
        **mehr,
    )


@pytest.fixture
def mit_modell() -> Iterator[TestClient]:
    app = create_app(_settings(alfred_schluessel=SCHLUESSEL, alfred_fragen_pro_tag=5))
    with TestClient(app) as c:
        yield c


def _nachricht(
    text: str = "", rufe: list[tuple[str, dict[str, Any]]] | None = None
) -> dict[str, Any]:
    msg: dict[str, Any] = {"role": "assistant", "content": text}
    if rufe:
        msg["tool_calls"] = [
            {"id": f"r{i}", "type": "function", "function": {"name": n, "arguments": json.dumps(a)}}
            for i, (n, a) in enumerate(rufe)
        ]
    return {"choices": [{"message": msg}]}


class Modell:
    """Ein Anbieter mit Drehbuch: liefert die Antworten der Reihe nach, die letzte immer wieder."""

    def __init__(self, antworten: list[dict[str, Any]], status: int = 200) -> None:
        self.antworten = antworten
        self.status = status
        self.anfragen: list[httpx.Request] = []

    def rumpf(self, i: int) -> dict[str, Any]:
        wert: dict[str, Any] = json.loads(self.anfragen[i].content)
        return wert

    def transport(self) -> httpx.MockTransport:
        def antworten(request: httpx.Request) -> httpx.Response:
            self.anfragen.append(request)
            if self.status >= 400:
                return httpx.Response(self.status, json={"message": "zitiert die Frage"})
            i = min(len(self.anfragen) - 1, len(self.antworten) - 1)
            return httpx.Response(200, json=self.antworten[i])

        return httpx.MockTransport(antworten)


@pytest.fixture
def modell_einsetzen(monkeypatch: pytest.MonkeyPatch) -> Callable[[Modell], None]:
    """Ersetzt das Netz der Anbieteranfragen durch das Drehbuch-Modell."""

    def einsetzen(m: Modell) -> None:
        echt = dienst.Klient
        monkeypatch.setattr(
            dienst, "Klient", lambda settings, transport=None: echt(settings, m.transport())
        )

    return einsetzen


def _fragen(client: TestClient, frage: str = "Wie viel PV heute?", **mehr: Any) -> httpx.Response:
    return client.post(
        "/api/v1/alfred/ask",
        json={"frage": frage, "wissen": "Seite Strom: zeigt die Bilanz.", **mehr},
    )


# --- Status und ohne Modell -----------------------------------------------------------------------


def test_ohne_schluessel_nicht_bereit(client: TestClient) -> None:
    assert client.get("/api/v1/alfred/status").json() == {
        "bereit": False,
        "anbieter": None,
        "modell": None,
    }
    antwort = _fragen(client).json()
    assert antwort["bereit"] is False and antwort["antwort"] == ""


def test_status_nennt_anbieter_und_vorgabemodell(mit_modell: TestClient) -> None:
    assert mit_modell.get("/api/v1/alfred/status").json() == {
        "bereit": True,
        "anbieter": "Mistral",
        "modell": "mistral-medium-latest",
    }


def test_auswertungen_ohne_schluessel_abgewiesen(client: TestClient) -> None:
    assert client.post("/api/v1/alfred/rechnung", content=b"%PDF").status_code == 409
    assert client.post("/api/v1/alfred/zuordnung", json={"liste": "sensor.x"}).status_code == 409


# --- Schleife -------------------------------------------------------------------------------------


def test_werkzeuge_laufen_und_antwort_kommt(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    m = Modell(
        [
            _nachricht(rufe=[("energiebilanz", {"zeitraum": "woche"}), ("jetzt", {})]),
            _nachricht("Diese Woche **42 kWh** PV."),
        ]
    )
    modell_einsetzen(m)
    antwort = _fragen(mit_modell).json()
    assert antwort == {"bereit": True, "antwort": "Diese Woche **42 kWh** PV.", "vorschlaege": []}

    erste, zweite = m.rumpf(0), m.rumpf(1)
    assert m.anfragen[0].headers["authorization"] == f"Bearer {SCHLUESSEL}"
    assert SCHLUESSEL not in m.anfragen[0].content.decode()
    assert erste["model"] == "mistral-medium-latest"
    assert erste["messages"][0]["role"] == "system"
    assert "Seite Strom: zeigt die Bilanz." in erste["messages"][0]["content"]
    assert {t["function"]["name"] for t in erste["tools"]} >= {"energiebilanz", "jetzt"}
    werkzeugzeilen = [n for n in zweite["messages"] if n["role"] == "tool"]
    assert [n["name"] for n in werkzeugzeilen] == ["energiebilanz", "jetzt"]
    bilanz = json.loads(werkzeugzeilen[0]["content"])
    assert bilanz["zeitraum"] == "week" and "fehler" not in bilanz
    # Was nie hinausgeht: Alarmanlage und Kontakte, auch nicht im Augenblick.
    assert "alarm" not in werkzeugzeilen[1]["content"]


def test_nach_runden_max_ohne_werkzeuge(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    # Das Modell will immer weiter Werkzeuge; die letzte Anfrage geht ohne Liste hinaus.
    m = Modell(
        [_nachricht(rufe=[("jetzt", {"x": 1})])] * dienst.RUNDEN_MAX + [_nachricht("Fertig.")]
    )
    modell_einsetzen(m)
    assert _fragen(mit_modell).json()["antwort"] == "Fertig."
    assert len(m.anfragen) == dienst.RUNDEN_MAX + 1
    assert "tools" not in m.rumpf(dienst.RUNDEN_MAX)
    assert all("tools" in m.rumpf(i) for i in range(dienst.RUNDEN_MAX))


def test_derselbe_aufruf_laeuft_nur_einmal(client: TestClient) -> None:
    settings = _settings(alfred_schluessel=SCHLUESSEL)
    gemeldet: list[str] = []

    async def melden(schritt: dict[str, Any]) -> None:
        gemeldet.append(schritt["werkzeug"])

    m = Modell(
        [
            _nachricht(rufe=[("raeume", {}), ("raeume", {})]),
            _nachricht(rufe=[("raeume", {})]),
            _nachricht("Ok."),
        ]
    )
    runner = client.app.state.runner  # type: ignore[attr-defined]
    antwort = asyncio.run(
        dienst.fragen(
            settings, "Wie warm?", "", Kontext(runner), melden=melden, transport=m.transport()
        )
    )
    assert antwort.text == "Ok."
    assert gemeldet == ["raeume"]


def test_verlauf_beginnt_beim_nutzer_und_wird_gekuerzt(client: TestClient) -> None:
    settings = _settings(alfred_schluessel=SCHLUESSEL, alfred_verlauf_max=3)
    m = Modell([_nachricht("Ja.")])
    runner = client.app.state.runner  # type: ignore[attr-defined]
    verlauf = [
        ("alfred", "Hallo!"),
        ("nutzer", "a"),
        ("alfred", "b"),
        ("nutzer", "c"),
        ("alfred", "d"),
    ]
    asyncio.run(
        dienst.fragen(settings, "Und?", "", Kontext(runner), verlauf, transport=m.transport())
    )
    rollen = [n["role"] for n in m.rumpf(0)["messages"]]
    # Letzte drei Wechsel ("c", "d" - "b" faellt als fuehrende Antwort weg), dann die Frage.
    assert rollen == ["system", "user", "assistant", "user"]


def test_anbieterfehler_ohne_rumpf_und_schluessel(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    modell_einsetzen(Modell([], status=401))
    antwort = _fragen(mit_modell)
    assert antwort.status_code == 502
    text = antwort.text
    assert "HTTP 401" in text
    assert "zitiert die Frage" not in text and SCHLUESSEL not in text


def test_tagesgrenze(mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]) -> None:
    modell_einsetzen(Modell([_nachricht("Ok.")]))
    for _ in range(5):
        assert _fragen(mit_modell).status_code == 200
    zu_viel = _fragen(mit_modell)
    assert zu_viel.status_code == 429
    assert zu_viel.json()["error"]["code"] == "zu_viele_fragen"


def test_strom_meldet_schritte_und_antwort(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    modell_einsetzen(Modell([_nachricht(rufe=[("waermepumpe", {})]), _nachricht("Sie laeuft.")]))
    with mit_modell.stream(
        "POST", "/api/v1/alfred/ask/stream", json={"frage": "Laeuft die WP?"}
    ) as antwort:
        text = "".join(antwort.iter_text())
    ereignisse = [z.split(":", 1)[1].strip() for z in text.splitlines() if z.startswith("event:")]
    assert ereignisse == ["schritt", "antwort"]
    assert '"werkzeug": "waermepumpe"' in text and "Sie laeuft." in text


# --- Werkzeuge ------------------------------------------------------------------------------------


def _beispiel(w: werkzeuge.Werkzeug) -> dict[str, Any]:
    """Gueltige Argumente je Werkzeug, damit jedes einmal wirklich laeuft."""
    beispiele: dict[str, dict[str, Any]] = {
        "leitfaden": {"frage": "warum_teurer"},
        "nachschlagen": {"stichwort": "Kontakt Anforderung Waermepumpe"},
        "schalten_vorschlagen": {"verbraucher": "Licht Terrasse", "an": True},
        "rechnung": {"zeitraum": "Oktober 2026"},
    }
    return beispiele.get(w.name, {})


def test_jedes_werkzeug_laeuft_wirklich(client: TestClient) -> None:
    """Nicht nur der Fehlerfall: Ein umbenanntes Feld soll hier auffallen und nicht still zu None
    werden. Eine Werkzeugmeldung (fehler aus WerkzeugError) ist erlaubt, die allgemeine nicht."""
    runner = client.app.state.runner  # type: ignore[attr-defined]
    raum = asyncio.run(runner.rooms_live()).rooms[0].name
    for w in werkzeuge.WERKZEUGE:
        argumente = _beispiel(w)
        if w.name == "sollwert_vorschlagen":
            argumente = {"raum": raum, "grad": 21}
        ergebnis = asyncio.run(werkzeuge.ausfuehren(w.name, argumente, Kontext(runner)))
        assert ergebnis.get("fehler") not in (
            "Das Werkzeug konnte nichts liefern.",
            "Dem Aufruf fehlt eine Angabe.",
        ), w.name
        assert len(json.dumps(ergebnis, default=str)) < werkzeuge.ERGEBNIS_MAX * 4 + 2000, w.name


def test_unbekanntes_werkzeug_und_fremde_argumente(client: TestClient) -> None:
    runner = client.app.state.runner  # type: ignore[attr-defined]
    k = Kontext(runner)
    assert "gibt es nicht" in asyncio.run(werkzeuge.ausfuehren("loeschen", {}, k))["fehler"]
    # Ein Argument ausserhalb des Schemas wird verworfen und schadet nicht.
    assert "fehler" not in asyncio.run(werkzeuge.ausfuehren("jetzt", {"hack": 1}, k))
    zukunft = asyncio.run(werkzeuge.ausfuehren("nachbetrachtung", {"tag": "2099-01-01"}, k))
    assert "Zukunft" in zukunft["fehler"]


def test_kompakt_streicht_gesperrtes_und_duennt() -> None:
    ergebnis = werkzeuge.kompakt(
        {"alarm": {"state": "armed"}, "Window": 1, "werte": list(range(1000)), "x": 1.23456789}
    )
    assert "alarm" not in ergebnis and "Window" not in ergebnis
    assert ergebnis["x"] == 1.235
    assert ergebnis["werte"]["ausgeduennt"] == f"{werkzeuge.LISTE_MAX} von 1000 Eintraegen"
    assert werkzeuge.kompakt({"z": float("nan")}) == {"z": None}


# --- Vorschlaege ----------------------------------------------------------------------------------


def test_schaltbar_ist_teil_der_steuerung_ohne_waermepumpe() -> None:
    assert set(werkzeuge.SCHALTBAR) <= set(ACTUATOR_LABELS)
    assert "hp_release_contact" not in werkzeuge.SCHALTBAR
    assert "hp_block_contact" not in werkzeuge.SCHALTBAR


def test_vorschlaege_schreiben_nichts_und_landen_in_der_antwort(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    runner = mit_modell.app.state.runner  # type: ignore[attr-defined]
    raeume = asyncio.run(runner.rooms_live()).rooms
    vorher = {r.id: r.setpoint_c for r in raeume}
    modell_einsetzen(
        Modell(
            [
                _nachricht(
                    rufe=[
                        ("schalten_vorschlagen", {"verbraucher": "Licht Innenhof", "an": True}),
                        ("sollwert_vorschlagen", {"raum": raeume[0].name, "grad": 21.3}),
                        ("schalten_vorschlagen", {"verbraucher": "Waermepumpe", "an": True}),
                    ]
                ),
                _nachricht("Ich habe zwei Vorschlaege vorbereitet."),
            ]
        )
    )
    antwort = _fragen(mit_modell, "Licht an und warm machen").json()
    assert antwort["vorschlaege"] == [
        {
            "art": "schalten",
            "ziel": "courtyard_light",
            "name": "Licht Innenhof",
            "an": True,
            "alt": None,
            "neu": None,
        },
        {
            "art": "sollwert",
            "ziel": raeume[0].id,
            "name": raeume[0].name,
            "an": None,
            "alt": raeume[0].setpoint_c,
            "neu": 21.5,
        },
    ]
    nachher = {r.id: r.setpoint_c for r in asyncio.run(runner.rooms_live()).rooms}
    assert nachher == vorher


def test_sollwert_ausserhalb_der_grenzen(client: TestClient) -> None:
    runner = client.app.state.runner  # type: ignore[attr-defined]
    raum = asyncio.run(runner.rooms_live()).rooms[0].name
    k = Kontext(runner)
    ergebnis = asyncio.run(
        werkzeuge.ausfuehren("sollwert_vorschlagen", {"raum": raum, "grad": 40}, k)
    )
    assert "zwischen" in ergebnis["fehler"] and k.vorschlaege == []


# --- Leitfaeden und Papiere -----------------------------------------------------------------------


def test_leitfaeden_nennen_nur_vorhandene_werkzeuge_und_urteilen_nicht() -> None:
    namen = {w.name for w in werkzeuge.WERKZEUGE}
    for ll in leitfaeden.LEITFAEDEN:
        assert set(ll.werkzeuge) <= namen, ll.name
        text = " ".join(ll.bestandteile).lower()
        assert "empfiehl" not in text and "empfehlung" not in text, ll.name


def test_papiere_sind_positivliste() -> None:
    wurzel = papiere.wurzel()
    for p in papiere.PAPIERE:
        assert (wurzel / p.pfad).is_file(), p.pfad
    pfade = {p.pfad for p in papiere.PAPIERE}
    for verboten in (
        "DEPLOYMENT.md",
        "CONFIGURATION.md",
        "docs/OPEN_QUESTIONS.md",
        "docs/TUEROEFFNUNG.md",
    ):
        assert verboten not in pfade
    # Was nur in Betriebspapieren steht, findet Alfred nicht.
    assert all(
        "DATABASE_URL" not in t.text for t in papiere.nachschlagen("DATABASE_URL Railway Token")
    )
    assert papiere.nachschlagen("Kontakt Anforderung")  # und das Eigene schon


def test_papier_ausserhalb_der_liste_bleibt_unsichtbar(tmp_path: Any) -> None:
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "GEHEIM.md").write_text("# Passwort\nDas Passwort lautet hunter2.\n")
    assert papiere.nachschlagen("Passwort", basis=tmp_path) == []


# --- Rechnung anderer Anbieter --------------------------------------------------------------------

RECHNUNG = """Stadtwerke Beispiel GmbH
Max Mustermann
Musterweg 12, 52511 Geilenkirchen
Kundennummer 123456789
IBAN DE89 3704 0044 0532 0130 00
Abrechnungszeitraum 01.08.2026 bis 31.08.2026
Verbrauch 312 kWh
Arbeitspreis 31,20 ct/kWh
Grundpreis 12,50 € je Monat
Rechnungsbetrag brutto 109,84 €
Zähler 1ESY1160123456 Zählerstand 12.345,6
Fragen? Mail an service@stadtwerke.example oder 02451 123456
"""


def test_rechnung_schickt_nur_geschwaerzte_relevante_zeilen() -> None:
    zeilen = rechnung.relevante_zeilen(RECHNUNG)
    text = "\n".join(zeilen)
    for verboten in ("Mustermann", "Musterweg", "123456789", "DE89", "service@", "02451"):
        assert verboten not in text, verboten
    assert "312 kWh" in text and "31,20 ct/kWh" in text and "109,84 €" in text
    assert "01.08.2026 bis 31.08.2026" in text


def test_rechnung_lesen_prueft_typen() -> None:
    gelesen = rechnung.lesen(
        {
            "anbieter": "Stadtwerke",
            "von": "2026-08-31",
            "bis": "2026-08-01",
            "kwh": "1.234,5",
            "brutto_eur": "abc",
        }
    )
    assert gelesen.von == date(2026, 8, 1) and gelesen.bis == date(2026, 8, 31)
    assert gelesen.kwh == 1234.5 and gelesen.brutto_eur is None


def test_rechnung_pruefen_vergleicht_mit_messung(client: TestClient) -> None:
    runner = client.app.state.runner  # type: ignore[attr-defined]
    tag = runner.now.date()
    gelesen = rechnung.GeleseneRechnung(
        von=tag, bis=tag, kwh=5000.0, brutto_eur=100.0, arbeitspreis_ct_kwh=30
    )
    ergebnis = asyncio.run(rechnung.pruefen(runner, gelesen, 9))
    assert ergebnis.gemessen_kwh is not None and ergebnis.abdeckung is not None
    assert ergebnis.mittlerer_preis_ct_kwh == 2.0
    titel = {b.titel for b in ergebnis.befunde}
    assert "Preis unplausibel" in titel
    assert titel & {"Verbrauch gegen eigene Messung", "Messung lueckenhaft"}


# --- Zuordnung ------------------------------------------------------------------------------------


def test_zuordnung_prueft_jede_zeile() -> None:
    liste = (
        "sensor.pv_leistung 4200 W\nsensor.netz 300 W\nsensor.puffer_oben 55 °C\nswitch.licht on"
    )
    zeilen, kennungen = zuordnung.eingabe(liste)
    assert len(zeilen) == 3 and "switch.licht" not in kennungen
    ergebnis = zuordnung.pruefen(
        {
            "zuordnung": [
                {"schluessel": "pv_power_kw", "entitaet": "sensor.pv_leistung", "einheit": "W"},
                {"schluessel": "pv_power_kw", "entitaet": "sensor.netz", "einheit": "W"},
                {"schluessel": "grid_power_kw", "entitaet": "sensor.erfunden", "einheit": "W"},
                {
                    "schluessel": "buffer_temp_top_c",
                    "entitaet": "sensor.puffer_oben",
                    "einheit": "W",
                },
                {"schluessel": "hp_release_contact", "entitaet": "sensor.netz", "einheit": "W"},
            ]
        },
        kennungen,
        len(zeilen),
    )
    assert [z.schluessel for z in ergebnis.zeilen] == ["pv_power_kw"]
    assert ergebnis.zeilen[0].yaml == (
        "  - { key: pv_power_kw, entity: sensor.pv_leistung, unit: W, stale_after_s: 120 }"
    )
    assert len(ergebnis.verworfen) == 4
    assert "grid_power_kw" in ergebnis.offen


def test_zuordnung_endpunkt(
    mit_modell: TestClient, modell_einsetzen: Callable[[Modell], None]
) -> None:
    antwort_json = {
        "zuordnung": [
            {"schluessel": "outdoor_temp_c", "entitaet": "sensor.aussen", "einheit": "°C"}
        ]
    }
    m = Modell([_nachricht(json.dumps(antwort_json))])
    modell_einsetzen(m)
    antwort = mit_modell.post(
        "/api/v1/alfred/zuordnung", json={"liste": "sensor.aussen 8.1 °C"}
    ).json()
    assert antwort["zeilen"][0]["yaml"].endswith('unit: "°C", stale_after_s: 3600 }')
    assert m.rumpf(0)["response_format"] == {"type": "json_object"}
    assert "tools" not in m.rumpf(0)
