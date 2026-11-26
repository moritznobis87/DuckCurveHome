"""Die Version, die Dashboard und App unter Rechenkern zeigen (dch_api/fassung.py)."""

from __future__ import annotations

import pytest

from dch_api.fassung import anzeige, fassung


@pytest.mark.parametrize(
    ("roh", "erwartet"),
    [
        ("2026.11.1", "2026.11.1"),
        ("2026.11.1+entwicklung", "Entwicklungsstand nach 2026.11.1"),
        ("", "Entwicklungsstand"),
        (None, "Entwicklungsstand"),
        ("  2026.12.3 ", "2026.12.3"),
    ],
)
def test_anzeige(roh: str | None, erwartet: str) -> None:
    assert anzeige(roh) == erwartet


def test_aus_der_umgebung(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DCH_FASSUNG", "2026.11.1")
    assert fassung() == "2026.11.1"
    monkeypatch.delenv("DCH_FASSUNG")
    assert fassung() == "Entwicklungsstand"
