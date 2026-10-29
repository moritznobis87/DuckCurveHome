from __future__ import annotations

import os
from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner

router = APIRouter(tags=["System"])


def running_commit() -> str:
    """Welcher Stand hier gerade läuft, aus der Umgebung der Plattform.

    Ohne das ist „ist mein Fehler schon behoben?" nicht zu beantworten, ohne im Deployment-Verlauf
    zu suchen: `version` ist eine Konstante im Quelltext und ändert sich mit keinem Deploy.
    Railway setzt `RAILWAY_GIT_COMMIT_SHA`; lokal steht hier `dev`.
    """
    sha = os.environ.get("RAILWAY_GIT_COMMIT_SHA") or os.environ.get("GIT_COMMIT_SHA") or ""
    return sha[:7] if sha else "dev"


def speicher_mb() -> tuple[float | None, float | None]:
    """Wie viel Arbeitsspeicher dieser Vorgang gerade belegt und je belegt hat (MB).

    Railway rechnet Speicher ab und zeigt ihn je Dienst in der Oberfläche. Von aussen ist damit
    nicht zu sehen, welcher der drei Dienste die Summe treibt, und wer das nicht weiss, spart am
    falschen Ende. Die Zahl steht deshalb hier, wo sie ohne Anmeldung und ohne Dashboard zu lesen
    ist.

    Der zweite Wert ist der Hoechststand seit dem Start (`VmHWM`). Er trennt zwei Faelle, die in
    der Momentaufnahme gleich aussehen: dauerhaft viel belegt, oder einmal viel gebraucht und
    wieder hergegeben. Das einmalige Neurechnen der Stundenbilanzen beim Start ist genau so ein
    Fall.

    Gelesen wird `/proc/self/status`. Wo es die Datei nicht gibt, bleiben beide Felder leer.
    """
    jetzt: float | None = None
    hoechst: float | None = None
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    jetzt = round(int(line.split()[1]) / 1024, 1)
                elif line.startswith("VmHWM:"):
                    hoechst = round(int(line.split()[1]) / 1024, 1)
    except OSError:
        return None, None
    return jetzt, hoechst


@router.get("/", summary="Wegweiser", include_in_schema=False)
def root() -> dict[str, object]:
    return {
        "service": "Duck Curve Home API",
        "hint": "Das Dashboard läuft im Web-Service. Diese API nutzen Bridge (/bridge/ws) und Web-BFF (/api/v1).",
        "health": "/health",
        "docs": "/docs",
    }


@router.get("/health", summary="Gesundheitszustand")
def health(runner: Annotated[Runtime, Depends(get_runner)]) -> dict[str, object]:
    jetzt, hoechst = speicher_mb()
    return {
        "status": "ok",
        "version": runner.live_state().system.version,
        "commit": running_commit(),
        "mode": runner.settings.mode,
        # Einmalige Wartungsschritte laufen im Hintergrund. Ohne diese Zeile ist von aussen nicht zu
        # sehen, ob sie liefen, noch laufen oder gescheitert sind - und dann sucht man den Fehler in
        # der Rechnung, obwohl er im Ablauf liegt.
        "energy_rebuild": getattr(runner, "energy_rebuild", "unbekannt"),
        "server_time": runner.now.isoformat(),
        "sse_clients": runner.broker.client_count,
        "rss_mb": jetzt,
        "rss_peak_mb": hoechst,
    }
