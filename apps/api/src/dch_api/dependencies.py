"""FastAPI-Abhängigkeiten: Runtime-Zugriff und Bearer-Prüfung für das Web-BFF."""

from __future__ import annotations

import hmac

from fastapi import Request

from dch_api.application.runtime import Runtime
from dch_api.errors import DchError


def get_runner(request: Request) -> Runtime:
    runtime: Runtime = request.app.state.runner
    return runtime


async def require_api_token(request: Request) -> None:
    expected: str = request.app.state.settings.api_token
    if not expected:
        return  # Entwicklung/Demo ohne Token
    header = request.headers.get("authorization", "")
    token = header[7:].strip() if header.lower().startswith("bearer ") else ""
    if not hmac.compare_digest(token, expected):
        raise DchError("unauthorized", "Kein gültiges API-Token.", 401)
