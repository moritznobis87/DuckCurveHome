"""Qualität eines Messwerts. Ein Wert ohne Qualität ist im System nicht erlaubt."""

from __future__ import annotations

from enum import StrEnum


class Quality(StrEnum):
    OK = "ok"  # frischer, plausibler Wert
    STALE = "stale"  # letzter Wert älter als der Schwellwert des Sensors
    UNAVAILABLE = "unavailable"  # Quelle meldet sich nicht / Gerät offline
    UNKNOWN = "unknown"  # Quelle liefert keinen interpretierbaren Wert
    DERIVED = "derived"  # aus anderen Werten berechnet (Bilanz)
    INCONSISTENT = "inconsistent"  # Bilanzverletzung über Toleranz

    @property
    def usable(self) -> bool:
        """Darf der Wert für Regelung und Bilanz verwendet werden?"""
        return self in (Quality.OK, Quality.DERIVED)
