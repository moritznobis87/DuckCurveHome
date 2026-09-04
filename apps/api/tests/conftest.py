from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings


@pytest.fixture
def client() -> Iterator[TestClient]:
    settings = Settings(
        demo_autostart=False,
        demo_warmup_hours=26.0,
        demo_start=datetime(2026, 9, 4, 11, 30, tzinfo=UTC),
        demo_seed=3,
    )
    app = create_app(settings)
    with TestClient(app) as c:
        yield c
