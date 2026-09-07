"""Die Auflösung der Preishistorie wird im Schema erfragt, nicht geraten."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import pytest

from dch_api.integrations.tibber import client as tc

START = datetime(2026, 9, 6, tzinfo=UTC)


def _nodes(step_min: int, count: int) -> list[dict[str, Any]]:
    return [
        {
            "startsAt": (START + timedelta(minutes=step_min * i)).isoformat(),
            "total": 0.30 + 0.01 * i,
        }
        for i in range(count)
    ]


def _provider(
    monkeypatch: pytest.MonkeyPatch, enum_values: list[str], step_min: int
) -> tuple[tc.TibberPriceProvider, list[str]]:
    seen: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        query = json.loads(request.content)["query"]
        seen.append(query)
        if "__type" in query:
            return httpx.Response(
                200,
                json={"data": {"__type": {"enumValues": [{"name": n} for n in enum_values]}}},
            )
        return httpx.Response(
            200,
            json={
                "data": {
                    "viewer": {
                        "homes": [
                            {
                                "id": "h1",
                                "currentSubscription": {
                                    "priceInfo": {
                                        "range": {
                                            "pageInfo": {
                                                "hasPreviousPage": False,
                                                "startCursor": None,
                                            },
                                            "nodes": _nodes(step_min, 8),
                                        }
                                    }
                                },
                            }
                        ]
                    }
                }
            },
        )

    transport = httpx.MockTransport(handler)
    original = httpx.AsyncClient

    def factory(**kwargs: Any) -> httpx.AsyncClient:
        kwargs.pop("transport", None)
        return original(transport=transport, **kwargs)

    monkeypatch.setattr(tc.httpx, "AsyncClient", factory)
    return tc.TibberPriceProvider("token", "h1"), seen


async def test_picks_quarter_hourly_when_the_schema_offers_it(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    provider, seen = _provider(
        monkeypatch, ["QUARTER_HOURLY", "HOURLY", "DAILY", "MONTHLY"], step_min=15
    )
    points = await provider.fetch_range(START, START + timedelta(hours=2))
    assert any("resolution: QUARTER_HOURLY" in q for q in seen)
    # Intervallgrenzen kommen aus den Daten, nicht aus einer Annahme
    assert points[0].end - points[0].start == timedelta(minutes=15)


async def test_quarterly_is_not_mistaken_for_a_quarter_hour(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """QUARTERLY neben MONTHLY und ANNUAL ist ein Quartal - gröber, nicht feiner."""
    provider, seen = _provider(
        monkeypatch, ["HOURLY", "DAILY", "WEEKLY", "QUARTERLY", "ANNUAL"], step_min=60
    )
    await provider.fetch_range(START, START + timedelta(hours=4))
    assert any("resolution: HOURLY" in q for q in seen)
    assert not any("QUARTERLY" in q for q in seen)


async def test_falls_back_to_hourly_without_introspection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    provider, seen = _provider(monkeypatch, [], step_min=60)
    points = await provider.fetch_range(START, START + timedelta(hours=4))
    assert any("resolution: HOURLY" in q for q in seen)
    assert points[0].end - points[0].start == timedelta(hours=1)


async def test_explicit_setting_skips_introspection(monkeypatch: pytest.MonkeyPatch) -> None:
    provider, seen = _provider(monkeypatch, ["QUARTER_HOURLY", "HOURLY"], step_min=60)
    provider.resolution = "HOURLY"
    provider._resolved = "HOURLY"
    await provider.fetch_range(START, START + timedelta(hours=4))
    assert not any("__type" in q for q in seen)
