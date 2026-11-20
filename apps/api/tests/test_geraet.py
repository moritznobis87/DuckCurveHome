"""Technik -> Hausgerät: Bericht lesen und bewerten, Handgriffe anfragen, Protokolle liefern
(routers/geraet.py, deploy/haus/dch). Docker erreicht die API nicht; hier geht es um die Dateien."""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.routers.geraet import bewerte_sicherung, drosselung_de
from dch_api.schemas import GeraetSicherungOut
from dch_api.settings import Settings


@pytest.fixture
def ordner(tmp_path: Path) -> Path:
    (tmp_path / "anfrage").mkdir()
    return tmp_path


@pytest.fixture
def geraet(ordner: Path) -> Iterator[TestClient]:
    settings = Settings(
        demo_autostart=False,
        demo_warmup_hours=1.0,
        demo_start=datetime(2026, 9, 4, 11, 30, tzinfo=UTC),
        geraet_dir=str(ordner),
    )
    with TestClient(create_app(settings)) as c:
        yield c


def _jetzt(minuten: float = 0) -> str:
    return (datetime.now(UTC) - timedelta(minutes=minuten)).strftime("%Y-%m-%dT%H:%M:%SZ")


def _dienst(name: str, **felder: Any) -> dict[str, Any]:
    return {
        "name": name,
        "zustand": "running",
        "gesundheit": "healthy",
        "gestartet_am": _jetzt(60),
        "neustarts": 0,
        **felder,
    }


def _bericht(ordner: Path, **felder: Any) -> None:
    bericht: dict[str, Any] = {
        "erstellt_am": _jetzt(),
        "kanal": "main",
        "fernzugang": False,
        "rechner": {
            "name": "duckcurve",
            "modell": "Raspberry Pi Compute Module 5 Rev 1.0",
            "laufzeit_s": 3600,
            "kerne": 4,
            "last": [0.2, 0.3, 0.3],
            "temperatur_c": 52.1,
            "drosselung": "0x0",
            "speicher_gesamt_mb": 4096,
            "speicher_frei_mb": 2900,
            "platten": [
                {"ort": "/", "gesamt_bytes": 500_000_000_000, "frei_bytes": 400_000_000_000}
            ],
        },
        "dienste": [
            _dienst("api"),
            _dienst("web"),
            _dienst("postgres"),
            _dienst("caddy", gesundheit=None),
        ],
        "einheiten": [
            {
                "name": "duckcurve-zustand.timer",
                "aktiv": "active",
                "unterzustand": "waiting",
                "eingeschaltet": True,
            },
        ],
        "sicherung": {
            "letzte": "dch-1.dump",
            "letzte_am": _jetzt(300),
            "anzahl": 3,
            "ausser_haus": "r2:dch",
        },
    }
    bericht.update(felder)
    (ordner / "geraet.json").write_text(json.dumps(bericht), encoding="utf-8")


def test_ohne_hausgeraet_nur_die_api(client: TestClient) -> None:
    antwort = client.get("/api/v1/system/geraet").json()
    assert antwort["unterstuetzt"] is False
    assert antwort["dienste"] == []
    assert antwort["api"]["version"] and antwort["api"]["commit"]
    assert antwort["api"]["laufzeit_s"] >= 0
    # Handgriffe gibt es dort nicht.
    r = client.post("/api/v1/system/geraet/aktion", json={"aktion": "sichern"})
    assert r.status_code == 409


def test_alles_gut(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["unterstuetzt"] is True and antwort["bericht_alt"] is False
    assert [d["ampel"] for d in antwort["dienste"]] == ["gut"] * 4
    assert antwort["dienste"][3]["text_de"] == "Läuft."  # caddy ohne Prüfung
    assert antwort["rechner"]["temperatur_ampel"] == "gut"
    assert antwort["rechner"]["drosselung_ampel"] == "gut"
    assert antwort["einheiten"][0]["text_de"] == "Wartet auf den nächsten Lauf."
    assert antwort["sicherung"]["ampel"] == "gut"
    # Die Vorführung hat keine Bridge; das Gesamturteil folgt dem schlechtesten Teil.
    if antwort["api"]["ampel"] == "gut":
        assert antwort["ampel"] == "gut" and antwort["text_de"] == "Alles in Ordnung."


def test_kranker_dienst_bestimmt_das_urteil(geraet: TestClient, ordner: Path) -> None:
    _bericht(
        ordner,
        dienste=[
            _dienst(
                "api",
                gesundheit="unhealthy",
                pruefung_fehlschlaege=4,
                pruefung="connection refused",
            ),
            _dienst("web"),
            {"name": "caddy", "zustand": "fehlt"},
        ],
    )
    antwort = geraet.get("/api/v1/system/geraet").json()
    api, _, caddy = antwort["dienste"]
    assert api["ampel"] == "schlecht"
    assert api["text_de"] == "Läuft, aber die Prüfung schlägt fehl, 4-mal in Folge."
    assert caddy["ampel"] == "schlecht" and "Nicht angelegt" in caddy["text_de"]
    assert antwort["ampel"] == "schlecht"
    assert antwort["text_de"].startswith("api: ")


def test_unterspannung_und_hitze(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    bericht = json.loads((ordner / "geraet.json").read_text())
    bericht["rechner"].update(temperatur_c=73.4, drosselung="0x50005")
    (ordner / "geraet.json").write_text(json.dumps(bericht))
    rechner = geraet.get("/api/v1/system/geraet").json()["rechner"]
    assert rechner["temperatur_ampel"] == "warn"
    assert rechner["drosselung_ampel"] == "schlecht"
    assert rechner["drosselung_de"][0].startswith("Die Spannung ist gerade zu niedrig")


def test_alter_bericht_faellt_auf(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner, erstellt_am=_jetzt(10))
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["bericht_alt"] is True
    assert antwort["ampel"] in ("warn", "schlecht")


def test_ohne_bericht_unterstuetzt_aber_alt(geraet: TestClient) -> None:
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["unterstuetzt"] is True and antwort["bericht_alt"] is True
    assert antwort["rechner"] is None


def test_neustart_anfragen(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    r = geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "neustart", "dienst": "web"})
    assert r.status_code == 202, r.text
    anfrage = json.loads((ordner / "anfrage" / "anfrage.json").read_text())
    assert anfrage["aktion"] == "neustart" and anfrage["dienst"] == "web"
    # Eine Anfrage zur Zeit.
    r = geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "sichern"})
    assert r.status_code == 409
    assert (
        geraet.get("/api/v1/system/geraet").json()["beschaeftigt"]
        == "Eine Anfrage wird gerade bearbeitet."
    )


@pytest.mark.parametrize(
    ("rumpf", "status"),
    [
        ({"aktion": "neustart"}, 422),
        ({"aktion": "neustart", "dienst": "gibtsnicht"}, 422),
        ({"aktion": "protokoll", "dienst": "alle"}, 422),
        ({"aktion": "neustart", "dienst": "web; reboot"}, 422),
        ({"aktion": "rm -rf"}, 422),
    ],
)
def test_nur_bekannte_handgriffe(
    geraet: TestClient, ordner: Path, rumpf: dict[str, str], status: int
) -> None:
    _bericht(ordner)
    assert geraet.post("/api/v1/system/geraet/aktion", json=rumpf).status_code == status
    assert not (ordner / "anfrage" / "anfrage.json").exists()


def test_alle_neu_starten_ist_erlaubt(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    r = geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "neustart", "dienst": "alle"})
    assert r.status_code == 202


def test_nicht_waehrend_eines_updates(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    (ordner / "status.json").write_text(json.dumps({"zustand": "laeuft"}))
    r = geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "sichern"})
    assert r.status_code == 409 and "Update" in r.json()["error"]["message"]


def test_laufende_aktion_sperrt_verwaiste_nicht(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    aktion = {"aktion": "neustart", "dienst": "api", "zustand": "laeuft", "begonnen_am": _jetzt(1)}
    (ordner / "aktion.json").write_text(json.dumps(aktion))
    assert (
        geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "sichern"}).status_code == 409
    )
    letzte = geraet.get("/api/v1/system/geraet").json()["letzte_aktion"]
    assert letzte["aktion"] == "neustart" and letzte["zustand"] == "laeuft"
    # Seit einer halben Stunde "läuft": abgebrochen, sperrt nicht mehr.
    (ordner / "aktion.json").write_text(json.dumps({**aktion, "begonnen_am": _jetzt(30)}))
    assert (
        geraet.post("/api/v1/system/geraet/aktion", json={"aktion": "sichern"}).status_code == 202
    )


def test_protokoll(geraet: TestClient, ordner: Path) -> None:
    assert geraet.get("/api/v1/system/geraet/protokoll/api").json()["vorhanden"] is False
    (ordner / "protokoll").mkdir()
    (ordner / "protokoll" / "api.txt").write_text("zeile 1\nzeile 2 Bearer ***\n", encoding="utf-8")
    p = geraet.get("/api/v1/system/geraet/protokoll/api").json()
    assert p["vorhanden"] is True and p["zeilen"] == ["zeile 1", "zeile 2 Bearer ***"]
    assert geraet.get("/api/v1/system/geraet/protokoll/..%2Fstatus").status_code in (404, 422)
    assert geraet.get("/api/v1/system/geraet/protokoll/API").status_code == 422


def test_drosselung_bits() -> None:
    assert drosselung_de(None) == ([], "aus")
    assert drosselung_de("0x0") == ([], "gut")
    saetze, ampel = drosselung_de("0x50000")
    assert (
        ampel == "warn" and len(saetze) == 2 and all(s.startswith("Seit dem Start") for s in saetze)
    )
    assert drosselung_de("0x1")[1] == "schlecht"
    assert drosselung_de("kaputt")[1] == "warn"


def test_sicherung_bewerten() -> None:
    jetzt = datetime(2026, 11, 20, 12, tzinfo=UTC)
    assert bewerte_sicherung(GeraetSicherungOut(), jetzt).text_de == "Noch keine Sicherung."
    alt = GeraetSicherungOut(letzte="a", letzte_am=jetzt - timedelta(days=3), anzahl=1)
    assert bewerte_sicherung(alt, jetzt).ampel == "warn"
    frisch = GeraetSicherungOut(letzte="a", letzte_am=jetzt - timedelta(hours=9), anzahl=2)
    s = bewerte_sicherung(frisch, jetzt)
    assert s.ampel == "gut" and "außer Haus" in s.text_de


def test_knapper_platz_sagt_wie_viel(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    bericht = json.loads((ordner / "geraet.json").read_text())
    bericht["rechner"]["platten"] = [
        {"ort": "/", "gesamt_bytes": 256_000_000_000, "frei_bytes": 12_400_000_000}
    ]
    (ordner / "geraet.json").write_text(json.dumps(bericht))
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["rechner"]["platten"][0]["ampel"] == "schlecht"
    assert antwort["ampel"] == "schlecht"
    assert antwort["text_de"] == "Nur noch 12,4 GB frei auf der SSD."
