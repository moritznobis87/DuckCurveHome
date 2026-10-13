"""Ein Fehler-Envelope für alle Antworten: {"error": {"code", "message", "details"}}."""

from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class DchError(Exception):
    def __init__(self, code: str, message: str, status: int = 400, details: object = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
        self.details = details


def _lesbar(errors: Sequence[Any]) -> list[dict[str, Any]]:
    """Die Befundliste einer Eingabeprüfung JSON-tauglich machen.

    Pydantic legt bei einer eigenen Prüfung die **Ausnahme selbst** unter `ctx.error` ab, und daran
    scheitert die Umwandlung nach JSON: statt der 422 bekäme der Aufrufer einen Serverfehler, und die
    Meldung, die ihm sagen würde, was er falsch gemacht hat, ginge genau dabei verloren. Bei den
    eingebauten Regeln fällt das nie auf, weil deren Zusatzangaben Zahlen sind; die erste eigene
    Prüfung im Projekt hat es aufgedeckt.
    """
    out: list[dict[str, Any]] = []
    for e in errors:
        if not isinstance(e, dict):
            out.append({"msg": str(e)})
            continue
        item = dict(e)
        ctx = item.get("ctx")
        if isinstance(ctx, dict):
            item["ctx"] = {
                k: v if isinstance(v, str | int | float | bool | type(None)) else str(v)
                for k, v in ctx.items()
            }
        out.append(item)
    return out


def _envelope(code: str, message: str, status: int, details: object = None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"error": {"code": code, "message": message, "details": details}},
    )


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DchError)
    async def _dch(_: Request, exc: DchError) -> JSONResponse:
        return _envelope(exc.code, exc.message, exc.status, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "method_not_allowed"}.get(exc.status_code, "http_error")
        return _envelope(code, str(exc.detail), exc.status_code)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        return _envelope("validation_error", "Anfrage ungültig.", 422, _lesbar(exc.errors()))
