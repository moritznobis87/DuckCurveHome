from __future__ import annotations

import pytest

from hems_core.domain import HemsConfig


@pytest.fixture
def cfg() -> HemsConfig:
    return HemsConfig()
