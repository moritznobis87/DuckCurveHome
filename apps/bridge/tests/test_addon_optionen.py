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


def test_schema_und_optionen_decken_sich() -> None:
    config = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
    assert set(config["options"]) == set(config["schema"])
