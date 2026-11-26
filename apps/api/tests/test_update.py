"""Updates aus der App: Die API liest den Stand des Update-Dienstes und legt Anfragen ab
(routers/update.py, deploy/haus/dch). Docker erreicht sie nicht; hier geht es nur um die Dateien."""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
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


def _status(ordner: Path, **felder: object) -> None:
    (ordner / "status.json").write_text(json.dumps(felder), encoding="utf-8")


def test_ohne_hausgeraet_keine_updates(client: TestClient) -> None:
    assert client.get("/api/v1/system/update").json()["unterstuetzt"] is False
    antwort = client.post("/api/v1/system/update", json={"aktion": "pruefen"})
    assert antwort.status_code == 409


def test_frisch_eingerichtet_ohne_befund(geraet: TestClient) -> None:
    status = geraet.get("/api/v1/system/update").json()
    assert status["unterstuetzt"] is True and status["update_verfuegbar"] is False


def test_der_stand_des_dienstes_kommt_an(geraet: TestClient, ordner: Path) -> None:
    _status(
        ordner,
        aktuell="2026.11.1",
        verfuegbar="2026.12.1",
        update_verfuegbar=True,
        neuerungen=[
            {"version": "2026.12.1", "bereich": "Alfred", "text": "Alfred liest Rechnungen."}
        ],
        geprueft_am="2026-11-20T07:00:00Z",
        zustand="bereit",
        unbekanntes_feld="stoert nicht",
    )
    status = geraet.get("/api/v1/system/update").json()
    assert status["update_verfuegbar"] is True
    assert status["neuerungen"] == [
        {"version": "2026.12.1", "bereich": "Alfred", "text": "Alfred liest Rechnungen."}
    ]
    assert status["anfrage_offen"] is False


def test_commit_titel_eines_alten_dienstes_erscheinen_nicht(
    geraet: TestClient, ordner: Path
) -> None:
    """Ein Update-Dienst von vor dem 26.11.2026 schrieb Commit-Titel. Die sind nicht für
    Außenstehende geschrieben; bis zur nächsten Prüfung steht dann keine Liste da."""
    _status(
        ordner,
        update_verfuegbar=True,
        neuerungen=[{"sha": "bbbbbbb", "titel": "Hausgeraet: interner Umbau"}],
    )
    status = geraet.get("/api/v1/system/update").json()
    assert status["update_verfuegbar"] is True and status["neuerungen"] == []
    assert status["meldung"] is None


def test_installieren_legt_nur_eine_anfrage_ab(geraet: TestClient, ordner: Path) -> None:
    _status(ordner, update_verfuegbar=True, aktuell="a", verfuegbar="b")
    antwort = geraet.post(
        "/api/v1/system/update",
        json={"aktion": "installieren"},
        headers={"x-dch-urheber-name": "iPad Flur"},
    )
    assert antwort.status_code == 202 and antwort.json()["anfrage_offen"] is True
    anfrage = json.loads((ordner / "anfrage" / "anfrage.json").read_text(encoding="utf-8"))
    assert anfrage["aktion"] == "installieren" and anfrage["von"] == "iPad Flur"
    # Keine halbe Datei bleibt liegen.
    assert list((ordner / "anfrage").iterdir()) == [ordner / "anfrage" / "anfrage.json"]
    # Eine zweite Anfrage, solange die erste wartet: abgewiesen.
    assert geraet.post("/api/v1/system/update", json={"aktion": "installieren"}).status_code == 409


def test_kein_update_ohne_neue_fassung_und_nicht_waehrend_eines_laufs(
    geraet: TestClient, ordner: Path
) -> None:
    _status(ordner, update_verfuegbar=False)
    assert geraet.post("/api/v1/system/update", json={"aktion": "installieren"}).status_code == 409
    # Pruefen geht immer.
    assert geraet.post("/api/v1/system/update", json={"aktion": "pruefen"}).status_code == 202
    (ordner / "anfrage" / "anfrage.json").unlink()
    _status(ordner, update_verfuegbar=True, zustand="laeuft", schritt="Laden")
    assert geraet.post("/api/v1/system/update", json={"aktion": "installieren"}).status_code == 409


def test_unbekannte_aktion_abgewiesen(geraet: TestClient) -> None:
    assert geraet.post("/api/v1/system/update", json={"aktion": "rm -rf"}).status_code == 422


def test_unlesbarer_stand(geraet: TestClient, ordner: Path) -> None:
    (ordner / "status.json").write_text("{kaputt", encoding="utf-8")
    status = geraet.get("/api/v1/system/update").json()
    assert status["unterstuetzt"] is True and "unlesbar" in status["meldung"]
