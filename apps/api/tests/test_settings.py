from __future__ import annotations

import pytest

from dch_api.settings import Settings, parse_list


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ('["a", "b"]', ["a", "b"]),
        ("3f9a0c", ["3f9a0c"]),
        ("tok1, tok2", ["tok1", "tok2"]),
        ('"tok1"', ["tok1"]),
        ("", []),
        (["x", " y "], ["x", "y"]),
    ],
)
def test_parse_list(raw: object, expected: list[str]) -> None:
    assert parse_list(raw) == expected


def test_settings_accept_bare_token_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DCH_BRIDGE_TOKENS", "abc123")
    monkeypatch.setenv("DCH_CORS_ORIGINS", "https://a.example, https://b.example")
    s = Settings(_env_file=None)  # type: ignore[call-arg]
    assert s.bridge_tokens == ["abc123"]
    assert s.cors_origins == ["https://a.example", "https://b.example"]


def test_settings_accept_json_list(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DCH_BRIDGE_TOKENS", '["abc123", "def456"]')
    s = Settings(_env_file=None)  # type: ignore[call-arg]
    assert s.bridge_tokens == ["abc123", "def456"]
