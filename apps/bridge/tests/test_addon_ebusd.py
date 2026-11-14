"""Das Add-on „Duck Curve eBUS": Optionen, Startskript und Übungsadapter passen zusammen.

Dasselbe Muster wie beim Add-on der Bridge: eine Option, die in `config.yaml` steht und im
Startskript nicht gelesen wird, wirkt nicht und meldet keinen Fehler.
"""

from __future__ import annotations

import importlib.util
import re
from pathlib import Path

import yaml

WURZEL = Path(__file__).resolve().parents[3]
ADDON = WURZEL / "addons" / "duckcurve_ebusd"


def test_schema_und_optionen_decken_sich() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    assert set(config["options"]) == set(config["schema"])
    # Zum Einstieg nur lesend, und ohne Adapter startet nichts.
    assert config["options"]["read_only"] is True
    assert config["options"]["adapter"] == ""


def test_jede_option_wird_im_startskript_gelesen() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    run_sh = (ADDON / "run.sh").read_text(encoding="utf-8")
    gelesen = set(re.findall(r"\bopt ([a-z0-9_]+)", run_sh)) | set(
        re.findall(r"\.([a-z0-9_]+) // \[\]", run_sh)
    )
    fehlend = sorted(set(config["options"]) - gelesen)
    assert not fehlend, f"in run.sh nicht gelesen: {fehlend}"


def test_das_startskript_bekommt_die_umgebung_und_prueft_die_bus_beschreibung() -> None:
    run_sh = (ADDON / "run.sh").read_text(encoding="utf-8")
    # Ohne `with-contenv` kommen unter s6 weder die Fassung noch SUPERVISOR_TOKEN an.
    assert run_sh.splitlines()[0] == "#!/usr/bin/with-contenv bash"
    ref = re.search(r'PINNED_REF="([0-9a-f]{40})"', run_sh)
    assert ref is not None
    summen = re.findall(r"([0-9a-f]{64})  ([\w.]+)", run_sh)
    assert sorted(name for _, name in summen) == ["_templates.csv", "ariston.csv"]
    assert "sha256sum -c" in run_sh
    # Das Passwort steht nicht im Protokoll.
    assert "--mqttpass=***" in run_sh


def test_der_uebungsadapter_rechnet_die_pruefsumme_des_busses() -> None:
    spec = importlib.util.spec_from_file_location(
        "ebus_uebungsadapter", WURZEL / "tools" / "ebus_uebungsadapter.py"
    )
    assert spec is not None and spec.loader is not None
    modul = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modul)
    # Das bekannte Telegramm 10 08 b5 11 01 01 hat die Prüfsumme 89.
    assert modul.crc8(bytes.fromhex("1008b5110101")) == 0x89
    # Bytes ab 0x80 gehen im erweiterten Protokoll als Paar über die Leitung.
    assert modul.erweitert(b"\x13\xaa") == bytes([0x13, 0xC6, 0xAA])
    # Rundruf: 9 Bytes und die Prüfsumme. Frage und Antwort: 13 + Prüfsumme + Quittung, dann
    # 10 + Prüfsumme + Quittung.
    assert len(modul.rundruf()) == 10 and len(modul.frage_und_antwort()) == 27


def test_die_eigenen_zeilen_fuer_die_aerotop_haben_die_form_die_ebusd_liest() -> None:
    """`aerotop_split.csv`: acht Spalten Kopf, dann je Feld sechs. Eine verrutschte Spalte liest
    ebusd nicht als Fehler, sondern als anderes Feld (am 13.11.2026 an `pumpe_status` gesehen:
    ein Byte zu viel übersprungen, „invalid position").

    Ob die Zeilen die Telegramme des Hauses richtig entschlüsseln, prüft kein Test hier: das ist
    mit ebusd selbst an den Telegrammen aus dem Protokoll geschehen (docs/SENSORIK.md).
    """
    zeilen = [
        z
        for z in (ADDON / "aerotop_split.csv").read_text(encoding="utf-8").splitlines()
        if z and not z.startswith("#")
    ]
    namen = set()
    for z in zeilen:
        spalten = z.split(",")
        assert spalten[0] in {"g", "b"}, "nur mitlesen, nie fragen oder schreiben"
        assert (len(spalten) - 8) % 6 == 0, z
        namen.add(f"{spalten[1]}/{spalten[2]}")
    assert {
        "heatpump/hp_power",
        "energymgr/system_temps",
        "energymgr/aussen_rundruf",
        "energymgr/pumpe_status",
        "energymgr/betriebsart",
    } <= namen
    dockerfile = (ADDON / "Dockerfile").read_text(encoding="utf-8")
    assert "COPY aerotop_split.csv /etc/duckcurve/aerotop_split.csv" in dockerfile
    assert "/etc/duckcurve/aerotop_split.csv" in (ADDON / "run.sh").read_text(encoding="utf-8")
