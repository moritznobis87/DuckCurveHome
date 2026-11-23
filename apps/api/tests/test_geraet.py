"""Technik -> Hausgerät: Bericht lesen und bewerten, Handgriffe anfragen, Protokolle liefern
(routers/geraet.py, deploy/haus/dch). Docker erreicht die API nicht; hier geht es um die Dateien."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.routers.geraet import bewerte_rechner, bewerte_sicherung, drosselung_de, zeit_zustand
from dch_api.schemas import GeraetRechnerOut, GeraetSicherungOut
from dch_api.settings import Settings

WURZEL = Path(__file__).resolve().parents[3]
DCH = WURZEL / "deploy" / "haus" / "dch"


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


def test_uhrzustand_bewerten() -> None:
    # Ohne timedatectl (Railway, Entwicklung) ist der Zustand unbekannt und darf nicht warnen.
    assert zeit_zustand(None, None) == ("", "aus")
    assert zeit_zustand(None, True) == ("", "aus")
    assert zeit_zustand(True, False) == ("", "gut")
    # Mit laufendem Zeitdienst nennt der Satz nur, dass kein Zeitserver zu erreichen ist, und
    # behauptet nicht, die Uhr gehe falsch: nach 32 000 s ohne Antwort setzt der Kernel
    # STA_UNSYNC von selbst, auch wenn die Uhr dann noch auf Zehntelsekunden stimmt.
    text, ampel = zeit_zustand(False, True)
    assert ampel == "warn" and "erreicht keinen Zeitserver" in text
    assert "ist nicht gestellt" not in text
    text, ampel = zeit_zustand(False, False)
    assert ampel == "schlecht" and "kein Zeitdienst eingeschaltet" in text
    # Ohne Auskunft über den Dienst bleibt es schlecht, behauptet aber keine Ursache.
    text, ampel = zeit_zustand(False, None)
    assert ampel == "schlecht" and "Zeitdienst" not in text


def _uhr(ordner: Path, **felder: Any) -> None:
    """Die Uhrfelder, die `dch zustand` aus `timedatectl` in den Bericht schreibt, nachgebaut."""
    bericht = json.loads((ordner / "geraet.json").read_text())
    bericht["rechner"].update(zeitzone="Europe/Berlin", **felder)
    (ordner / "geraet.json").write_text(json.dumps(bericht))


def test_nicht_gestellte_uhr_bestimmt_das_urteil(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    _uhr(ordner, zeit_synchron=False, zeitdienst_an=False)
    antwort = geraet.get("/api/v1/system/geraet").json()
    rechner = antwort["rechner"]
    assert rechner["zeitzone"] == "Europe/Berlin" and rechner["zeit_ampel"] == "schlecht"
    # Das Gesamturteil sagt, was aus der falschen Uhr folgt - sonst sucht niemand dort.
    assert antwort["ampel"] == "schlecht"
    assert "Wandanzeige" in antwort["text_de"] and "Zeitstempel" in antwort["text_de"]


def test_eine_fremde_zeitzone_macht_die_uhr_nicht_schlecht(
    geraet: TestClient, ordner: Path
) -> None:
    """Die Zeitzone des Geraets wird gemeldet und nicht bewertet - absichtlich.

    Keine Uhrzeit im Haus haengt an ihr: der Dienst formatiert in `hems_core.domain.zeit`, die
    Oberflaeche in Europe/Berlin, die App in der Zone des Telefons. Ein Geraet auf Etc/UTC mit
    synchroner Uhr ist also in Ordnung, und die Seite behauptet nichts anderes. Der Test haelt
    das fest, damit die Entscheidung eine Entscheidung bleibt und keine Luecke wird.
    """
    _bericht(ordner)
    _uhr(ordner, zeit_synchron=True, zeitdienst_an=True)
    bericht = json.loads((ordner / "geraet.json").read_text())
    bericht["rechner"]["zeitzone"] = "Etc/UTC"
    (ordner / "geraet.json").write_text(json.dumps(bericht))
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["rechner"]["zeitzone"] == "Etc/UTC"
    assert antwort["rechner"]["zeit_ampel"] == "gut"
    assert antwort["rechner"]["zeit_de"] == ""


def test_laufender_zeitdienst_warnt_nur(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    _uhr(ordner, zeit_synchron=False, zeitdienst_an=True)
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["rechner"]["zeit_ampel"] == "warn"
    assert antwort["ampel"] in ("warn", "schlecht")


def test_unbekannte_uhr_bleibt_stumm(geraet: TestClient, ordner: Path) -> None:
    # Der Bericht eines Geraets ohne systemd (und der einer aelteren dch-Fassung) hat die Felder
    # nicht: Dann ist die Uhr unbekannt, und die Seite schweigt darueber.
    _bericht(ordner)
    antwort = geraet.get("/api/v1/system/geraet").json()
    rechner = antwort["rechner"]
    assert rechner["zeit_synchron"] is None and rechner["zeitzone"] is None
    assert rechner["zeit_ampel"] == "aus" and rechner["zeit_de"] == ""
    assert "Uhr" not in antwort["text_de"]


def test_synchrone_uhr_ist_gut(geraet: TestClient, ordner: Path) -> None:
    _bericht(ordner)
    _uhr(ordner, zeit_synchron=True, zeitdienst_an=True)
    antwort = geraet.get("/api/v1/system/geraet").json()
    assert antwort["rechner"]["zeit_ampel"] == "gut"
    assert antwort["rechner"]["zeit_de"] == ""
    if antwort["api"]["ampel"] == "gut":
        assert antwort["ampel"] == "gut"


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


# ------------------------------------------------------- Die Uhrfelder kommen aus einem Shell-Skript


def _uhr_aus_dch(tmp_path: Path, ausgabe: str | None, *, rueckgabe: int = 0) -> Any:
    """`uhr()` aus `deploy/haus/dch` wirklich ausführen, mit `timedatectl` als Attrappe.

    Die Funktion wird aus dem Quelltext geschnitten (von `^uhr()` bis zur ersten Zeile, die nur
    aus `}` besteht) und in einer eigenen Shell ausgeführt. Damit prüft der Test die Zeilen, die
    auf dem Hausgerät laufen, und nicht eine Nachbildung davon.

    `ausgabe` ist `None` für „es gibt kein `timedatectl`"; sonst das, was es auf die Standardausgabe
    schreibt. `rueckgabe` ist sein Beendigungscode.
    """
    quelle = DCH.read_text().splitlines()
    beginn = quelle.index("uhr() {")
    ende = next(i for i in range(beginn, len(quelle)) if quelle[i] == "}")
    funktion = "\n".join(quelle[beginn : ende + 1])

    attrappen = tmp_path / "bin"
    attrappen.mkdir()
    if ausgabe is not None:
        falsch = attrappen / "timedatectl"
        # Als Hier-Dokument und nicht als `printf`-Zeichenkette: `printf '%s'` lässt \n stehen,
        # und dann steht die ganze Ausgabe in einem Feld - der erste Anlauf dieses Tests war
        # darum grün für die falsche Sache.
        falsch.write_text("#!/bin/sh\ncat <<'AUSGABE'\n" + ausgabe + f"AUSGABE\nexit {rueckgabe}\n")
        falsch.chmod(0o755)
    # Ein eigenes PATH mit nur den nötigen Werkzeugen: Läge das echte `timedatectl` noch darin,
    # würde der Test auf einer systemd-Maschine etwas anderes messen als hier.
    noetig = tmp_path / "werkzeuge"
    noetig.mkdir()
    for werkzeug in ("bash", "sh", "sed", "jq", "cat"):
        ort = shutil.which(werkzeug)
        if ort:
            (noetig / werkzeug).symlink_to(ort)

    lauf = subprocess.run(
        ["bash", "-c", f"{funktion}\nuhr"],
        capture_output=True,
        text=True,
        env={
            "PATH": f"{attrappen}:{noetig}",
            # Die Naht aus `dch`: der Prüfstand hat kein /run/systemd/system.
            "DCH_SYSTEMD_PFAD": str(tmp_path),
        },
    )
    assert lauf.returncode == 0, f"uhr() brach ab: {lauf.stderr}"
    return json.loads(lauf.stdout)


@pytest.mark.skipif(not shutil.which("jq"), reason="ohne jq kann `dch` kein JSON bauen")
@pytest.mark.parametrize(
    ("ntp", "synchron", "erwartet_dienst", "erwartet_synchron", "ampel"),
    [
        ("yes", "yes", True, True, "gut"),
        # Ein anderer Zeitdienst als systemd-timesyncd: der Kernel sagt synchron, `timedated`
        # kennt den Dienst vielleicht nicht. Die Uhr ist gestellt, also gut.
        ("no", "yes", False, True, "gut"),
        ("yes", "no", True, False, "warn"),
        ("no", "no", False, False, "schlecht"),
        # Eine Fassung, die true/false schreibt statt yes/no.
        ("true", "false", True, False, "warn"),
        # Etwas Unverständliches darf nicht als „nicht synchron" durchgehen.
        ("vielleicht", "vielleicht", None, None, "aus"),
    ],
)
def test_die_uhrfelder_aus_dch_tragen_bis_zur_ampel(
    tmp_path: Path,
    ntp: str,
    synchron: str,
    erwartet_dienst: bool | None,
    erwartet_synchron: bool | None,
    ampel: str,
) -> None:
    """Von `timedatectl` über `dch` und das Schema bis zur Ampel - der ganze Weg in einem Zug.

    Dieser Test ist die einzige Prüfung im Baum, die `deploy/haus/dch` wirklich ausführt. Ohne ihn
    überlebt dort jede Änderung per Bauart: Es gibt für die Shell-Dateien des Hausgeräts weder
    `shellcheck` noch `bash -n` in den Abläufen, und das JSON, das `dch` schreibt, ist der Vertrag
    mit `GeraetRechnerOut` - bricht er, zeigt die App stumm nichts an.
    """
    roh = _uhr_aus_dch(tmp_path, f"Timezone=Europe/Berlin\nNTP={ntp}\nNTPSynchronized={synchron}\n")
    assert roh == {
        "zeitzone": "Europe/Berlin",
        "zeitdienst_an": erwartet_dienst,
        "zeit_synchron": erwartet_synchron,
    }
    # Dieselben Schlüssel, die der Bericht trägt, in das Schema und durch die Bewertung.
    r = bewerte_rechner(GeraetRechnerOut(**roh))
    assert r.zeit_ampel == ampel
    assert bool(r.zeit_de) is (ampel not in ("gut", "aus"))


@pytest.mark.skipif(not shutil.which("jq"), reason="ohne jq kann `dch` kein JSON bauen")
@pytest.mark.parametrize(
    ("ausgabe", "rueckgabe"),
    [
        # Kein timedatectl: Railway, Entwicklung, ein Container ohne systemd.
        (None, 0),
        # Vorhanden, aber ohne systemd als Init - genau die Lage im Prüfbehälter.
        ("", 1),
        # Antwortet, sagt aber nichts über die Uhr.
        ("Timezone=Europe/Berlin\n", 0),
    ],
)
def test_eine_nicht_zu_erfragende_uhr_wird_unbekannt_und_nicht_schlecht(
    tmp_path: Path, ausgabe: str | None, rueckgabe: int
) -> None:
    """Unbekannt heißt `null` beziehungsweise `None`, und `None` heißt Ampel aus.

    Der teuerste Fehler dieser Art wäre eine Dauerwarnung in der Entwicklung und auf Railway: Sie
    nimmt der echten Meldung den Glauben, und die echte Meldung ist der Grund, warum es die Felder
    überhaupt gibt.
    """
    roh = _uhr_aus_dch(tmp_path, ausgabe, rueckgabe=rueckgabe)
    if roh is None:
        r = bewerte_rechner(GeraetRechnerOut())
    else:
        assert roh["zeit_synchron"] is None
        r = bewerte_rechner(GeraetRechnerOut(**roh))
    assert (r.zeit_ampel, r.zeit_de) == ("aus", "")


def test_der_pfad_der_systemd_naht_ist_in_dch_wirklich_so_geschrieben() -> None:
    """Die Naht, auf der die beiden Tests darüber stehen - und ihr Vorgabewert.

    Stünde in `dch` wieder `/run/systemd/system` fest, liefen die Tests darüber weiter, prüften
    aber nur noch den unbekannt-Fall: Der Prüfbehälter hat dieses Verzeichnis nicht, und ein
    stillschweigend halbierter Test ist schlimmer als keiner.
    """
    text = DCH.read_text()
    assert '[ -d "${DCH_SYSTEMD_PFAD:-/run/systemd/system}" ]' in text
    assert os.environ.get("DCH_SYSTEMD_PFAD") is None, "der Vorgabewert gilt im Betrieb"
