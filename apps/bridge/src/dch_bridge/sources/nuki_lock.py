"""Das Nuki-Schloss über seine **lokale** HTTP-API - ohne Nuki-Cloud, ohne Bridge-Gerät.

Das Smart Lock Pro hat WLAN an Bord und bietet dieselbe Schnittstelle an, die sonst die
Nuki-Bridge bereitstellt. Eingeschaltet wird sie in der Nuki-App unter „Geräte verwalten", dort
vergibt man auch den Token (6 bis 20 Zeichen). Danach ist ein Öffnen ein einziges GET im Heimnetz:

    GET http://<schloss-ip>:8080/lockAction?nukiId=<id>&deviceType=0&action=3&token=<token>

**Warum lokal und nicht über die Web-API.** Der Weg über die Cloud führt vom Haus ins Internet zu
Nuki und wieder zurück ins Haus. Er ist langsamer, er fällt mit jeder Störung auf einer der beiden
Strecken aus, und er ist genau die Art von Kette, an der die bisherige Automatisierung gescheitert
ist. Wer vor seiner Tür steht, will nicht wissen, wie es dem Internet geht.

**`action=3` ist „unlatch".** Das zieht die Falle, öffnet die Tür also wirklich, statt nur den
Riegel zurückzudrehen. Ob die Tür das mechanisch hergibt, entscheidet ihr Schloss und nicht diese
Datei; wenn es bisher so funktioniert hat, funktioniert es weiter.

**Dieses Modul kennt nur zwei Befehle**, und öffnen ist einer davon. Abschließen ist der andere,
und den gibt es nur, weil ein Gerät, das man aufsperren kann, auch zusperren können muss. Alles
Weitere, was die Schnittstelle hergibt - Konfiguration, Benutzerverwaltung, Rückrufe -, bleibt
draußen.
"""

from __future__ import annotations

from typing import Any

import httpx
import structlog

log = structlog.get_logger("nuki")

# Aktionen der Nuki-Schnittstelle. Mehr als diese beiden braucht die Türöffnung nicht, und was
# nicht hier steht, kann dieses Modul nicht senden.
ACTION_UNLATCH = 3
ACTION_LOCK = 2
DEVICE_TYPE_SMARTLOCK = 0


class NukiError(RuntimeError):
    pass


class NukiLock:
    """Kleiner, synchroner Gedanke in asynchroner Form: eine Anfrage, eine Antwort, kein Zustand."""

    def __init__(
        self,
        host: str,
        token: str,
        *,
        port: int = 8080,
        nuki_id: str = "",
        timeout_s: float = 6.0,
    ) -> None:
        self.base = f"http://{host.strip()}:{port}"
        self.token = token
        self.nuki_id = nuki_id.strip()
        # Kurz: hinter der Tür steht jemand. Eine Anfrage, die nach sechs Sekunden noch läuft,
        # hilft niemandem mehr, und ein zweiter Versuch ist besser als ein langes Warten.
        self.timeout_s = timeout_s

    async def _get(self, path: str, params: dict[str, Any]) -> Any:
        try:
            async with httpx.AsyncClient(timeout=self.timeout_s) as client:
                r = await client.get(f"{self.base}{path}", params={**params, "token": self.token})
        except httpx.HTTPError as exc:
            raise NukiError(f"Schloss nicht erreichbar: {exc.__class__.__name__}") from exc
        if r.status_code == 401:
            raise NukiError("Token abgelehnt")
        if r.status_code != 200:
            raise NukiError(f"HTTP {r.status_code}")
        try:
            return r.json()
        except ValueError as exc:
            raise NukiError("Antwort ist kein JSON") from exc

    async def devices(self) -> list[dict[str, Any]]:
        data = await self._get("/list", {})
        return [d for d in data if isinstance(d, dict)] if isinstance(data, list) else []

    async def resolve_id(self) -> str:
        """Die nukiId bestimmen. Ohne Angabe gewinnt das erste Schloss - meist gibt es nur eines."""
        if self.nuki_id:
            return self.nuki_id
        for d in await self.devices():
            if int(d.get("deviceType", DEVICE_TYPE_SMARTLOCK)) == DEVICE_TYPE_SMARTLOCK:
                self.nuki_id = str(d.get("nukiId", ""))
                if self.nuki_id:
                    log.info("nuki lock", nuki_id=self.nuki_id, name=d.get("name"))
                    return self.nuki_id
        raise NukiError("Kein Schloss in der Antwort von /list")

    async def state(self) -> dict[str, Any]:
        nuki_id = await self.resolve_id()
        data = await self._get(
            "/lockState", {"nukiId": nuki_id, "deviceType": DEVICE_TYPE_SMARTLOCK}
        )
        return data if isinstance(data, dict) else {}

    async def unlatch(self) -> dict[str, Any]:
        """Die Falle ziehen. Die Tür geht auf."""
        return await self._action(ACTION_UNLATCH)

    async def lock(self) -> dict[str, Any]:
        return await self._action(ACTION_LOCK)

    async def _action(self, action: int) -> dict[str, Any]:
        nuki_id = await self.resolve_id()
        data = await self._get(
            "/lockAction",
            {"nukiId": nuki_id, "deviceType": DEVICE_TYPE_SMARTLOCK, "action": action},
        )
        out = data if isinstance(data, dict) else {}
        if not out.get("success", False):
            raise NukiError(f"Schloss meldet keinen Erfolg: {out}")
        return out
