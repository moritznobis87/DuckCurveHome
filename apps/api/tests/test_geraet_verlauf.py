"""Der Verlauf des Hausgeräts: Messpunkt aus dem Bericht, Abschnitte, Zähler mit Neustart,
Prognose, Ausdünnen und der Sammler im Live-Betrieb (application/geraet_verlauf.py)."""

from __future__ import annotations

import json
import time
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.application import geraet_verlauf as gv
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.main import create_app
from dch_api.settings import Settings

AUTH = {"authorization": "Bearer api-geheim"}
JETZT = datetime(2026, 11, 20, 12, 0, tzinfo=UTC)


def bericht(erstellt: datetime = JETZT, **rechner: Any) -> dict[str, Any]:
    r: dict[str, Any] = {
        "name": "duckcurve",
        "laufzeit_s": 3600,
        "kerne": 4,
        "last": [0.4, 0.3, 0.2],
        "temperatur_c": 51.5,
        "drosselung": "0x50000",
        "speicher_gesamt_mb": 4096,
        "speicher_frei_mb": 3000,
        "swap_gesamt_mb": 512,
        "swap_frei_mb": 500,
        "cpu_prozent": 7.5,
        "takt_mhz": 1500,
        "eingangsspannung_v": 5.08,
        "platten": [
            {"ort": "/", "gesamt_bytes": 500_000_000_000, "frei_bytes": 400_000_000_000},
            {"ort": "/mnt/stick", "gesamt_bytes": 64_000_000_000, "frei_bytes": 60_000_000_000},
        ],
        "netz": {
            "schnittstelle": "eth0",
            "empfangen_bytes": 1_000_000,
            "gesendet_bytes": 2_000_000,
        },
        "ssd": {
            "geraet": "nvme0n1",
            "temperatur_c": 41,
            "abnutzung_prozent": 1,
            "geschrieben_bytes": 9_000_000_000,
        },
        "docker_platz": {
            "images_bytes": 3_000_000_000,
            "container_bytes": 1_000_000,
            "volumes_bytes": 800_000_000,
            "cache_bytes": None,
        },
    }
    r.update(rechner)
    return {
        "erstellt_am": erstellt.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "docker_laeuft": True,
        "rechner": r,
        "dienste": [
            {
                "name": "api",
                "zustand": "running",
                "gesundheit": "healthy",
                "cpu_prozent": 2.0,
                "speicher_mb": 180.0,
            },
            {
                "name": "web",
                "zustand": "running",
                "gesundheit": "unhealthy",
                "cpu_prozent": 0.5,
                "speicher_mb": 90.0,
            },
        ],
        "sicherung": {"anzahl": 3, "gesamt_bytes": 12_000_000},
    }


def test_messpunkt_aus_dem_bericht() -> None:
    z = gv.messpunkt(bericht(JETZT + timedelta(minutes=3, seconds=40)), datenbank_bytes=70_000_000)
    assert z is not None
    assert z["ts"] == JETZT  # auf fünf Minuten abgerundet
    assert z["stuendlich"] is True
    assert z["speicher_belegt_mb"] == 1096 and z["swap_belegt_mb"] == 12
    assert z["platte_belegt_bytes"] == 100_000_000_000  # nur "/", nicht der Stick
    assert z["drosselung"] == 0x50000
    assert z["docker_bytes"] == 3_801_000_000
    assert z["datenbank_bytes"] == 70_000_000 and z["sicherung_bytes"] == 12_000_000
    assert z["dienste"]["web"] == {"cpu_prozent": 0.5, "speicher_mb": 90.0, "gesund": False}
    assert gv.messpunkt({"erstellt_am": "kaputt", "rechner": {}}) is None
    assert gv.messpunkt({"erstellt_am": "2026-11-20T12:00:00Z"}) is None


def test_ohne_pi_werte_bleiben_die_felder_leer() -> None:
    z = gv.messpunkt(
        bericht(
            temperatur_c=None,
            drosselung=None,
            eingangsspannung_v=None,
            ssd=None,
            netz=None,
            docker_platz=None,
        )
    )
    assert z is not None
    assert (
        z["temperatur_c"] is None and z["drosselung"] is None and z["ssd_geschrieben_bytes"] is None
    )
    assert z["netz_empfangen_bytes"] is None and z["docker_bytes"] is None


def _zeile(t: datetime, **werte: Any) -> dict[str, Any]:
    return {"ts": t, **werte}


def test_abschnitte_mittel_spitzen_und_zaehler_mit_neustart() -> None:
    beginn = JETZT - timedelta(hours=1)
    zeilen = [
        _zeile(
            beginn + timedelta(minutes=5 * i),
            cpu_prozent=float(i),
            temperatur_c=50.0 + i,
            netz_empfangen_bytes=1000 * i,
            platte_belegt_bytes=100 + i,
        )
        for i in range(6)
    ]
    # Neustart des Geräts: der Zähler beginnt wieder unten.
    zeilen.append(
        _zeile(
            beginn + timedelta(minutes=30),
            cpu_prozent=1.0,
            netz_empfangen_bytes=200,
            platte_belegt_bytes=106,
        )
    )
    zeilen.append(
        _zeile(
            beginn + timedelta(minutes=35),
            cpu_prozent=1.0,
            netz_empfangen_bytes=500,
            platte_belegt_bytes=106,
        )
    )
    v = gv.verlauf(zeilen, "woche", JETZT)
    assert v["schritt_min"] == 30
    a, b = v["punkte"][-2], v["punkte"][-1]
    assert a["cpu_prozent"] == 2.5 and a["cpu_prozent_max"] == 5.0
    assert a["temperatur_c_max"] == 55.0
    assert a["platte_belegt_bytes"] == 105  # Stand am Ende, kein Mittel
    # 5 Zuwächse zu je 1000 Bytes in 30 Minuten; der Rückgang zählt nicht, danach +300.
    assert a["netz_empfangen_bytes_s"] == round(5000 / 1800, 1)
    assert b["netz_empfangen_bytes_s"] == round(300 / 1800, 1)


def test_tag_hat_fuenf_minuten_und_dienste() -> None:
    zeilen = [
        _zeile(
            JETZT - timedelta(minutes=10),
            dienste={"api": {"cpu_prozent": 2.0, "speicher_mb": 100.0}},
        ),
        _zeile(
            JETZT - timedelta(minutes=5),
            dienste={"api": {"cpu_prozent": 4.0, "speicher_mb": 110.0}},
        ),
        _zeile(JETZT - timedelta(days=2), cpu_prozent=99.0),  # ausserhalb der Spanne
    ]
    v = gv.verlauf(zeilen, "tag", JETZT)
    assert v["schritt_min"] == 5 and len(v["punkte"]) == 2
    assert v["punkte"][1]["dienste"]["api"] == {"cpu_prozent": 4.0, "speicher_mb": 110.0}
    assert all(p["cpu_prozent"] is None for p in v["punkte"])


def test_prognose_wann_die_ssd_voll_ist() -> None:
    gesamt = 500_000_000_000
    zeilen = [
        _zeile(
            JETZT - timedelta(days=20 - d),
            platte_belegt_bytes=100_000_000_000 + d * 1_000_000_000,
            platte_gesamt_bytes=gesamt,
            datenbank_bytes=50_000_000 + d * 2_000_000,
        )
        for d in range(21)
    ]
    p = gv.prognose(zeilen, JETZT)
    assert p["tage_verlauf"] == 20.0
    assert p["platte_bytes_pro_tag"] == 1_000_000_000
    assert p["platte_voll_in_tagen"] == 380  # 380 GB frei, 1 GB am Tag
    assert p["datenbank_bytes_pro_tag"] == 2_000_000
    # Unter sieben Tagen Verlauf keine Gerade.
    assert gv.prognose(zeilen[-5:], JETZT)["platte_bytes_pro_tag"] is None


def test_prognose_schrumpfende_platte_wird_nie_voll() -> None:
    zeilen = [
        _zeile(
            JETZT - timedelta(days=10 - d), platte_belegt_bytes=200 - d, platte_gesamt_bytes=1000
        )
        for d in range(11)
    ]
    assert gv.prognose(zeilen, JETZT)["platte_voll_in_tagen"] is None


@pytest.mark.asyncio
async def test_ablage_sammeln_doppelt_und_ausduennen(tmp_path: Path) -> None:
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'v.sqlite'}")
    await create_all_for_tests(engine)
    repos = SqlRepositories(engine)
    (tmp_path / "geraet.json").write_text(json.dumps(bericht(JETZT + timedelta(minutes=1))))
    assert await gv.sammeln(repos, tmp_path) is True
    # Dieselben fünf Minuten: kein zweiter Punkt.
    (tmp_path / "geraet.json").write_text(json.dumps(bericht(JETZT + timedelta(minutes=3))))
    assert await gv.sammeln(repos, tmp_path) is False
    # Alte Punkte: einer zur vollen Stunde, einer nicht, einer jenseits von zwei Jahren.
    for t in (
        JETZT - timedelta(days=40),
        JETZT - timedelta(days=40, minutes=-5),
        JETZT - timedelta(days=800),
    ):
        z = gv.messpunkt(bericht(t))
        assert z is not None
        await repos.geraet_messwert_speichern(z)
    weg = await repos.geraet_messwerte_ausduennen(
        JETZT - gv.FEIN_BEHALTEN, JETZT - gv.ALLES_BEHALTEN
    )
    assert weg == 2
    rest = await repos.geraet_messwerte(JETZT - timedelta(days=1000), JETZT + timedelta(days=1))
    assert [z["ts"] for z in rest] == [JETZT - timedelta(days=40), JETZT]
    assert rest[1]["dienste"]["api"]["speicher_mb"] == 180.0
    assert await repos.datenbank_bytes() is None  # SQLite
    await engine.dispose()


@pytest.fixture
def live(tmp_path: Path) -> Iterator[tuple[TestClient, Path]]:
    ordner = tmp_path / "geraet"
    (ordner / "anfrage").mkdir(parents=True)
    (ordner / "geraet.json").write_text(json.dumps(bericht(datetime.now(UTC))))
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'live.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
        geraet_dir=str(ordner),
    )
    with TestClient(create_app(settings)) as c:
        yield c, ordner


def test_der_sammler_laeuft_im_live_betrieb(live: tuple[TestClient, Path]) -> None:
    client, _ = live
    punkte: list[Any] = []
    for _ in range(30):
        antwort = client.get("/api/v1/system/geraet/verlauf?spanne=tag", headers=AUTH).json()
        punkte = antwort["punkte"]
        if punkte:
            break
        time.sleep(0.1)
    assert antwort["unterstuetzt"] is True and antwort["schritt_min"] == 5
    assert len(punkte) == 1
    assert punkte[0]["cpu_prozent"] == 7.5 and punkte[0]["dienste"]["web"]["speicher_mb"] == 90.0
    # Das Augenblicksbild hat die neuen Werte, bewertet.
    g = client.get("/api/v1/system/geraet", headers=AUTH).json()
    assert g["docker_laeuft"] is True
    assert g["rechner"]["ssd"]["ampel"] == "gut" and g["rechner"]["ssd"]["text_de"].startswith(
        "Gesund"
    )
    assert g["rechner"]["spannung_ampel"] == "gut"
    assert (
        client.get("/api/v1/system/geraet/verlauf?spanne=quartal", headers=AUTH).status_code == 422
    )


def test_ohne_hausgeraet_kein_verlauf(client: TestClient) -> None:
    assert client.get("/api/v1/system/geraet/verlauf").json()["unterstuetzt"] is False


def test_docker_aus_faerbt_alle_dienste(live: tuple[TestClient, Path]) -> None:
    client, ordner = live
    b = bericht(datetime.now(UTC))
    b["docker_laeuft"] = False
    (ordner / "geraet.json").write_text(json.dumps(b))
    g = client.get("/api/v1/system/geraet", headers=AUTH).json()
    assert all(d["ampel"] == "schlecht" for d in g["dienste"])
    assert g["text_de"].startswith("Docker läuft nicht")


def test_ssd_mit_fehler(live: tuple[TestClient, Path]) -> None:
    client, ordner = live
    b = bericht(
        datetime.now(UTC), ssd={"geraet": "nvme0n1", "gesund": False, "abnutzung_prozent": 12}
    )
    (ordner / "geraet.json").write_text(json.dumps(b))
    g = client.get("/api/v1/system/geraet", headers=AUTH).json()
    assert g["rechner"]["ssd"]["ampel"] == "schlecht"
    assert g["ampel"] == "schlecht"
