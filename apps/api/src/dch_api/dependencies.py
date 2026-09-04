"""FastAPI-Abhängigkeiten."""

from __future__ import annotations

from fastapi import Request

from dch_api.application.demo_runner import DemoRunner


def get_runner(request: Request) -> DemoRunner:
    runner: DemoRunner = request.app.state.runner
    return runner
