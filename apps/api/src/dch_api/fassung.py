"""Welche Version von Duck Curve Home hier läuft, so wie Dashboard und App sie zeigen.

Die CI baut die Version aus docs/versionen.json in das Image (`DCH_FASSUNG`, siehe
.github/workflows/docker.yml): `2026.11.1` für eine veröffentlichte Version,
`2026.11.1+entwicklung` für einen Stand danach. Ein Commit-Hash erscheint nicht
(Festlegung des Hausherrn vom 26.11.2026). Ohne die Angabe, also lokal oder auf einer
Plattform, die selbst baut, heißt der Stand „Entwicklungsstand“.
"""

from __future__ import annotations

import os

ENTWICKLUNG = "+entwicklung"


def anzeige(roh: str | None) -> str:
    wert = (roh or "").strip()
    if not wert:
        return "Entwicklungsstand"
    if wert.endswith(ENTWICKLUNG):
        return f"Entwicklungsstand nach {wert.removesuffix(ENTWICKLUNG)}"
    return wert


def fassung() -> str:
    return anzeige(os.environ.get("DCH_FASSUNG"))
