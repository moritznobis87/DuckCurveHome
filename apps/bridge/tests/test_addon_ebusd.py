"""Das Add-on „Duck Curve eBUS": Optionen, Startskript und Übungsadapter passen zusammen.

Dasselbe Muster wie beim Add-on der Bridge: eine Option, die in `config.yaml` steht und im
Startskript nicht gelesen wird, wirkt nicht und meldet keinen Fehler.
"""

from __future__ import annotations

import importlib.util
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

WURZEL = Path(__file__).resolve().parents[3]
ADDON = WURZEL / "addons" / "duckcurve_ebusd"


def test_schema_und_optionen_decken_sich() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    assert set(config["options"]) == set(config["schema"])
    # Zum Einstieg nur lesend, und ohne Adapter startet nichts.
    assert config["options"]["read_only"] is True
    assert config["options"]["adapter"] == ""
    # Abgefragt wird seit 0.3.0 (Entscheidung des Hausherrn vom 14.11.2026), höchstens alle 5 s.
    assert config["options"]["abfragen"] is True
    assert config["options"]["abfrage_takt_s"] == 10
    assert config["schema"]["abfrage_takt_s"] == "int(5,300)"


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
        "energymgr/flag_1b45",
        "heatpump/wp_vorgabe",
    } <= namen
    dockerfile = (ADDON / "Dockerfile").read_text(encoding="utf-8")
    assert "COPY aerotop_split.csv /etc/duckcurve/aerotop_split.csv" in dockerfile
    run_sh = (ADDON / "run.sh").read_text(encoding="utf-8")
    assert 'EIGENE="${DCH_EBUSD_EIGENE:-/etc/duckcurve}"' in run_sh
    assert '"$EIGENE/aerotop_split.csv"' in run_sh


def test_die_zeilen_zum_abfragen_fragen_nur_und_sind_zugeordnet() -> None:
    """`aerotop_abfragen.csv`: die Werte, die das Add-on ab 0.3.0 selbst abfragt. Jede Zeile
    ist eine Frage (`r1` bis `r9`, Dienst 2000). Eine Zeile zum Stellen (`w`, Dienst 2020) darf
    hier nie stehen: es ist die einzige Datei, mit der das Add-on von sich aus sendet."""
    zeilen = [
        z.split(",")
        for z in (ADDON / "aerotop_abfragen.csv").read_text(encoding="utf-8").splitlines()
        if z and not z.startswith("#")
    ]
    # Fünf Größen der Maschine und (ab 0.4.0) zwölf Einstellungen des Reglers, diese selten.
    assert len(zeilen) == 17
    assert sum(1 for z in zeilen if z[0] == "r9") == 12
    assert all(z[2].startswith("e_") and z[5] == "18" for z in zeilen if z[0] == "r9")
    for spalten in zeilen:
        assert re.fullmatch(r"r[1-9]", spalten[0]), spalten[0]
        assert spalten[5] in {"18", "1e"} and spalten[6] == "2000"
        assert (len(spalten) - 8) % 6 == 0, spalten
    # Die erste Zeile der Datei ist ein Kommentar: sonst liest ebusd sie als Spaltenkopf und
    # verwirft die erste Frage ("missing name in column 4", im Probelauf gesehen).
    assert (ADDON / "aerotop_abfragen.csv").read_text(encoding="utf-8").startswith("#")
    karte = yaml.safe_load((WURZEL / "config" / "entities.home.yaml").read_text(encoding="utf-8"))
    ebus = next(m for m in karte["mqtt"] if m.get("kind") == "ebusd")
    for spalten in zeilen:
        assert f"{spalten[1]}/{spalten[2]}" in ebus["components"]

    # Betriebszustand und Frequenz (ab 0.3.1): dieselbe Frage, die der Regler stellt, mit
    # denselben Feldern wie die Zeile zum Mitlesen. Nur die Art unterscheidet sich; so gilt
    # dieselbe Zuordnung, ob der Regler fragt oder das Add-on.
    def betrieb(datei: str) -> list[str]:
        return next(
            z.split(",")
            for z in (ADDON / datei).read_text(encoding="utf-8").splitlines()
            if ",hp_betrieb," in z and not z.startswith("#")
        )

    assert betrieb("aerotop_abfragen.csv")[0] == "r1" and betrieb("aerotop_split.csv")[0] == "g"
    assert betrieb("aerotop_abfragen.csv")[1:] == betrieb("aerotop_split.csv")[1:]
    assert "COPY aerotop_abfragen.csv /etc/duckcurve/aerotop_abfragen.csv" in (
        ADDON / "Dockerfile"
    ).read_text(encoding="utf-8")


#: Steht an der Stelle von ebusd: sagt bei der Prüfung, wie viele Zeilen zum Abfragen da sind
#: (mit Rückgabewert 1, wie das echte Programm bei dieser Bus-Beschreibung), sonst seinen Aufruf.
ERSATZ = """#!/bin/sh
for a in "$@"; do case "$a" in --configpath=*) p="${a#--configpath=}";; --checkconfig) c=1;; esac; done
if [ -n "$c" ]; then
  n=$(cat "$p"/*.csv | grep -c '^r[1-9],')
  echo "found messages: 9 (0 conditional on 0 conditions, $n poll, 0 update)"
  exit 1
fi
echo "EBUSD $*"
"""

FREMD = """# fremde Bus-Beschreibung, verkleinert
r,heatpump,heatpump_3way_valve_dhw_heat,HP 3Way valve,,18,2000,0601,,s,IGN:1,,,,,,UCH,,,
r,heatpump,heatpump_mode,Mode,,18,2000,ca46,,s,IGN:1,,,,,,UCH,,,
w,energymgr,dhw_status,DHW Status,,fe,2020,0220,,s,UCH,,,
r;w,energymgr,beides,Lesen und Stellen,,18,2000,aa11,,s,UCH,,,
*w,energymgr,,,,fe,2020
uw,energymgr,mitgelesen,Fremde Stellnachricht,,fe,2020,bb22,,m,UCH,,,
b,energymgr,rundruf,Rundruf,,fe,2010,7647,temp,m,UIN,,,
g,heatpump,hp_betrieb,Mitlesen,,1e,2000,78106e13ca46cb46,,s,IGN:1,,,,mode,s,UCH,,,
"""


def addon_start(
    tmp_path: Path, **optionen: object
) -> tuple[subprocess.CompletedProcess[str], Path]:
    """Das Startskript mit einem Ersatz für ebusd und einer kleinen eigenen Bus-Beschreibung."""
    (tmp_path / "bin").mkdir(exist_ok=True)
    ersatz = tmp_path / "bin" / "ebusd"
    ersatz.write_text(ERSATZ, encoding="utf-8")
    ersatz.chmod(0o755)
    lokal = tmp_path / "lokal"
    lokal.mkdir(exist_ok=True)
    (lokal / "fremd.csv").write_text(FREMD, encoding="utf-8")
    (tmp_path / "options.json").write_text(
        json.dumps({"adapter": "ens:192.0.2.1", "extra_args": [], **optionen}), encoding="utf-8"
    )
    lauf = subprocess.run(
        ["bash", str(ADDON / "run.sh")],
        env={
            **os.environ,
            "PATH": f"{tmp_path / 'bin'}:{os.environ['PATH']}",
            "DCH_EBUSD_OPTIONS": str(tmp_path / "options.json"),
            "DCH_EBUSD_DATA": str(tmp_path / "data"),
            "DCH_EBUSD_LOCAL": str(lokal),
            "DCH_EBUSD_EIGENE": str(ADDON),
            "DCH_EBUSD_FEHLERPAUSE": "0",
        },
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    return lauf, tmp_path / "data" / "ebusd-config" / "aktiv"


def arten(datei: Path) -> list[str]:
    return [z.split(",")[0] for z in datei.read_text(encoding="utf-8").splitlines() if z[:1] != "#"]


@pytest.mark.skipif(shutil.which("jq") is None, reason="das Startskript braucht jq")
def test_mit_abfragen_fragt_ebusd_und_kennt_keine_zeile_zum_stellen(tmp_path: Path) -> None:
    """Abfragen heißt senden, also ohne `--readonly`. Damit daraus kein Weg zum Verstellen wird,
    entfernt das Startskript jede Zeile zum Stellen aus der Arbeitsfassung. Im Probelauf mit dem
    echten ebusd (14.11.2026) sendete es danach auf eine Stellnachricht über den Broker nichts;
    mit den Zeilen sendete es `31fe2020...`."""
    lauf, aktiv = addon_start(tmp_path, read_only=True, abfragen=True, abfrage_takt_s=10)
    assert lauf.returncode == 0, lauf.stdout + lauf.stderr
    aufruf = next(z for z in lauf.stdout.splitlines() if z.startswith("EBUSD "))
    assert "--pollinterval=10" in aufruf and "--readonly" not in aufruf
    assert "Stellen kann ebusd nichts: 3 Zeilen zum Stellen" in lauf.stdout
    # w und *w sind weg, aus "r;w" wurde "r", die mitgelesene fremde Stellnachricht bleibt.
    assert arten(aktiv / "fremd.csv") == ["r", "r", "uw", "b"]
    # Auch die Zeile zum Mitlesen von Betriebszustand und Frequenz weicht: die Frage liest mit.
    assert "78106e13ca46cb46" not in (aktiv / "fremd.csv").read_text(encoding="utf-8")
    # Die fremde Zeile mit derselben Kennung wie eine eigene Frage ist gewichen ("duplicate ID").
    fremd = (aktiv / "fremd.csv").read_text(encoding="utf-8")
    assert "0601" not in fremd and "ca46" in fremd
    assert arten(aktiv / "aerotop_abfragen.csv") == ["r1", "r1", "r1", "r2", "r2"] + ["r9"] * 12
    # Die Quelle bleibt, wie sie war.
    assert (tmp_path / "lokal" / "fremd.csv").read_text(encoding="utf-8") == FREMD


@pytest.mark.skipif(shutil.which("jq") is None, reason="das Startskript braucht jq")
def test_ohne_abfragen_lauscht_ebusd_nur(tmp_path: Path) -> None:
    for optionen in ({"read_only": True, "abfragen": False}, {}):
        lauf, aktiv = addon_start(tmp_path, **optionen)
        aufruf = next(z for z in lauf.stdout.splitlines() if z.startswith("EBUSD "))
        assert "--readonly" in aufruf and "--pollinterval" not in aufruf
        assert not (aktiv / "aerotop_abfragen.csv").exists()


@pytest.mark.skipif(shutil.which("jq") is None, reason="das Startskript braucht jq")
def test_ein_ausgeschalteter_schalter_wird_als_aus_gelesen(tmp_path: Path) -> None:
    """Bis 0.2.3 las das Skript mit `.[$k] // $d`; für jq ist auch `false` „nichts", und
    `read_only: false` blieb wirkungslos."""
    lauf, aktiv = addon_start(tmp_path, read_only=False, abfragen=False)
    aufruf = next(z for z in lauf.stdout.splitlines() if z.startswith("EBUSD "))
    assert "--readonly" not in aufruf and "ACHTUNG: read_only ist aus" in lauf.stdout
    assert "w" in arten(aktiv / "fremd.csv")
    # Ohne Abfragen bleibt die Zeile zum Mitlesen, wo sie ist.
    assert "g" in arten(aktiv / "fremd.csv")


@pytest.mark.skipif(shutil.which("jq") is None, reason="das Startskript braucht jq")
def test_schalter_die_beliebige_telegramme_erlauben_vertragen_sich_nicht_mit_read_only(
    tmp_path: Path,
) -> None:
    lauf, _ = addon_start(tmp_path, read_only=True, abfragen=True, extra_args=["--enablehex"])
    assert lauf.returncode == 1 and "verträgt sich nicht mit read_only" in lauf.stdout
    assert not any(z.startswith("EBUSD --foreground") for z in lauf.stdout.splitlines())
