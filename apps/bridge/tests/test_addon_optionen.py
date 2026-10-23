"""Jede Option des Add-ons erreicht die Bridge.

Die Controme-Optionen standen ab 0.8.7 in `config.yaml`, aber `run.sh` reichte sie nicht als
Umgebungsvariable weiter (gefunden am 22.10.2026): Wer sie eintrug, sah keine Wirkung und keinen
Fehler. Dieser Test liest die Optionsliste und verlangt für jede einen `bashio::config`-Aufruf.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ADDON = Path(__file__).resolve().parents[3] / "addons" / "duckcurve_bridge"


def test_jede_option_wird_exportiert() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    run_sh = (ADDON / "run.sh").read_text(encoding="utf-8")
    gelesen = set(re.findall(r"bashio::config '([a-z0-9_]+)'", run_sh))
    fehlend = sorted(set(config["options"]) - gelesen)
    assert not fehlend, f"in run.sh nicht weitergereicht: {fehlend}"


def test_die_eingebaute_nummer_folgt_dem_etikett() -> None:
    """`VERSION` im Code und `version` in der Add-on-Beschreibung sind dieselbe Zahl.

    Die Startzeile der Bridge nennt beide nebeneinander: `version` ist der eingebaute Code,
    `addon` das Etikett aus dem Bau. Laufen sie auseinander, hat der Supervisor ein altes Abbild
    behalten - das ist der Zweck der Gegenüberstellung. Sie taugt aber nur, wenn die Zahl im Code
    überhaupt mitgezogen wird; am 23.10.2026 stand dort noch 0.8.7, während das Etikett bei
    0.10.0 war, und die Anlage meldete einen Fehlalarm.
    """
    from dch_bridge.main import VERSION

    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    assert config["version"] == VERSION


def test_schema_und_optionen_decken_sich() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    assert set(config["options"]) == set(config["schema"])
