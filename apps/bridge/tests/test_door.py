"""Die Kette vom Gesichtsscan zum Schloss - und die Stellen, an denen sie absichtlich reißt.

Der wichtigste Test ist `test_without_the_release_the_lock_is_never_touched`: im
Beobachtungsbetrieb muss das Schloss unberührt bleiben, sonst wäre die Lernphase eine Attrappe.
"""

from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from dch_bridge.door import DoorService
from dch_bridge.sources.nuki_lock import ACTION_UNLATCH, NukiError, NukiLock
from dch_bridge.sources.opener import HomeAssistantOpener, NukiBridgeOpener, OpenerError
from dch_bridge.sources.unifi_access import UnifiAccessEvents, parse_event, unreadable
from hems_core.control import AccessEvent, DoorPolicy

NOW = datetime(2026, 9, 17, 18, 30, tzinfo=UTC)
PUBLISHED = int(NOW.timestamp() * 1000)


def _frame(**over: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "published": PUBLISHED,
        "actor": {"type": "user", "display_name": "Moritz"},
        "target": [{"type": "door", "display_name": "Haustür"}],
        "authentication_type": "FACE",
        "result": "Access Granted",
    }
    data.update(over)
    return {"event": "access.logs.add", "data": data}


def test_a_door_event_is_translated() -> None:
    e = parse_event(_frame(), NOW)
    assert e is not None
    assert (e.door, e.actor, e.method, e.granted) == ("Haustür", "Moritz", "FACE", True)
    assert e.at == NOW


def test_the_payload_may_sit_at_the_top_level() -> None:
    """Je nach Firmware liegen die Nutzdaten unter `data` oder direkt im Rahmen. Beides gilt."""
    flat = {"event": "access.logs.add", **_frame()["data"]}
    e = parse_event(flat, NOW)
    assert e is not None and e.actor == "Moritz"


def test_other_frames_are_ignored() -> None:
    assert parse_event({"event": "access.device.update", "data": {}}, NOW) is None
    assert parse_event({}, NOW) is None


def test_a_denied_result_is_carried_through_honestly() -> None:
    e = parse_event(_frame(result="Access Denied"), NOW)
    assert e is not None and not e.granted


def test_a_frame_without_a_timestamp_falls_back_to_now() -> None:
    e = parse_event(_frame(published=None), NOW)
    assert e is not None and e.at == NOW


def _nested_frame() -> dict[str, Any]:
    """Die Bauform der Entwickler-Schnittstelle: Ergebnis und Zeit unter `event`, Verfahren unter
    `authentication`. Genau an ihr sind uns beim ersten echten Scan alle Felder leer geblieben."""
    return {
        "event": "access.logs.add",
        "data": {
            "actor": {"type": "user", "display_name": "Moritz"},
            "target": [{"type": "door", "display_name": "Haustür"}],
            "authentication": {"credential_provider": "Face"},
            "event": {"result": "ACCESS GRANTED", "published": PUBLISHED},
        },
    }


def test_the_nested_shape_of_the_developer_api_is_read_too() -> None:
    e = parse_event(_nested_frame(), NOW)
    assert e is not None
    assert (e.door, e.actor, e.method, e.granted) == ("Haustür", "Moritz", "Face", True)
    assert e.at == NOW
    assert not unreadable(e)


def test_a_frame_in_neither_shape_is_marked_unreadable() -> None:
    """Dann ist der Rahmen selbst die einzige Auskunft, und er gehört ins Protokoll."""
    e = parse_event({"event": "access.logs.add", "data": {"_id": "abc"}}, NOW)
    assert e is not None
    assert unreadable(e)


class _Lock(NukiLock):
    def __init__(self, fail: bool = False) -> None:
        super().__init__("192.0.2.9", "token")
        self.actions: list[int] = []
        self.fail = fail

    async def _action(self, action: int) -> dict[str, Any]:
        self.actions.append(action)
        if self.fail:
            raise NukiError("Schloss nicht erreichbar: ConnectError")
        return {"success": True}


def _service(lock: NukiLock, **policy: Any) -> DoorService:
    args: dict[str, Any] = {
        "enabled": True,
        "doors": ["Haustür"],
        "actors": ["Moritz"],
        "methods": ["FACE"],
    }
    args.update(policy)
    events = UnifiAccessEvents("192.0.2.8", "t")
    return DoorService(events, NukiBridgeOpener(lock), DoorPolicy.of(**args))


def _event(**over: Any) -> AccessEvent:
    args: dict[str, Any] = {
        "at": datetime.now(UTC),
        "door": "Haustür",
        "actor": "Moritz",
        "method": "FACE",
        "granted": True,
    }
    args.update(over)
    return AccessEvent(**args)


@pytest.mark.asyncio
async def test_the_expected_case_pulls_the_latch() -> None:
    lock = _Lock()
    svc = _service(lock)
    await svc.handle(_event(), {})
    # 3 und nicht 1: die Falle, nicht bloß der Riegel. Genau das war die Anforderung.
    assert lock.actions == [ACTION_UNLATCH]
    assert svc.opened == 1 and svc.refused == 0


@pytest.mark.asyncio
async def test_without_the_release_the_lock_is_never_touched() -> None:
    """Der Beobachtungsbetrieb muss einer sein. Ein Protokolleintrag genügt nicht, wenn die Tür aufgeht."""
    lock = _Lock()
    svc = _service(lock, enabled=False)
    await svc.handle(_event(), {})
    assert lock.actions == []
    assert svc.opened == 0 and svc.refused == 1


@pytest.mark.asyncio
async def test_an_unknown_person_does_not_reach_the_lock() -> None:
    lock = _Lock()
    svc = _service(lock)
    await svc.handle(_event(actor="Fremder"), {})
    assert lock.actions == []
    assert "nicht freigegeben" in svc.last_de


@pytest.mark.asyncio
async def test_a_repeat_within_the_lock_window_is_swallowed() -> None:
    lock = _Lock()
    svc = _service(lock)
    await svc.handle(_event(), {})
    await svc.handle(_event(), {})
    assert lock.actions == [ACTION_UNLATCH]
    assert svc.opened == 1 and svc.refused == 1


@pytest.mark.asyncio
async def test_a_failing_lock_is_counted_and_may_be_retried_at_once() -> None:
    lock = _Lock(fail=True)
    svc = _service(lock)
    await svc.handle(_event(), {})
    assert svc.failed == 1 and svc.opened == 0
    # Kein Eintrag in der Wiederholsperre: der zweite Versuch kommt durch bis zum Schloss.
    await svc.handle(_event(), {})
    assert lock.actions == [ACTION_UNLATCH, ACTION_UNLATCH]
    assert svc.failed == 2


@pytest.mark.asyncio
async def test_the_status_says_whether_it_is_released() -> None:
    svc = _service(_Lock(), enabled=False)
    st = svc.status()
    assert st["enabled"] is False
    assert st["online"] is False  # ohne laufende Verbindung
    assert "opened" in st and "last_event_at" in st


def test_the_event_stream_has_no_receiver_until_the_service_sets_one() -> None:
    """Ohne Türdienst läuft die Verbindung und zählt, öffnet aber nichts."""
    events = UnifiAccessEvents("192.0.2.8", "t")
    assert events.on_event is None
    assert events.url == "wss://192.0.2.8:12445/api/v1/developer/devices/notifications"
    svc = DoorService(
        events, _Lock(), DoorPolicy.of(enabled=False, doors=[], actors=[], methods=[])
    )
    assert events.on_event == svc.handle


def test_the_lock_url_is_local_and_carries_no_cloud() -> None:
    lock = NukiLock("192.168.1.50", "geheim", port=8080)
    assert lock.base == "http://192.168.1.50:8080"
    assert timedelta(seconds=lock.timeout_s) <= timedelta(seconds=10)


def test_the_allowlist_comes_out_of_the_environment_intact(monkeypatch: Any) -> None:
    """Die Liste steht als Text in der Umgebung. Wird sie falsch zerlegt, ist die Freigabe wirkungslos."""
    from dch_bridge.settings import BridgeSettings

    monkeypatch.setenv("DCH_BRIDGE_DOOR_ACTORS", "Moritz, Anna")
    monkeypatch.setenv("DCH_BRIDGE_DOOR_METHODS", '["FACE", "NFC"]')
    monkeypatch.setenv("DCH_BRIDGE_DOOR_DOORS", "Haustür")
    s = BridgeSettings(_env_file=None)  # type: ignore[call-arg]
    assert s.door_actors == ["Moritz", "Anna"]
    assert s.door_methods == ["FACE", "NFC"]
    assert s.door_doors == ["Haustür"]
    # Ohne Angabe bleibt die Liste leer, und leer heißt niemand.
    monkeypatch.delenv("DCH_BRIDGE_DOOR_ACTORS")
    assert BridgeSettings(_env_file=None).door_actors == []  # type: ignore[call-arg]


def test_the_door_service_stays_off_until_both_halves_are_configured(monkeypatch: Any) -> None:
    """Ereignisse **und** ein Weg zum Schloss. Eine Hälfte allein startet nichts."""
    from dch_bridge.settings import BridgeSettings

    for k in ("UNIFI_HOST", "UNIFI_TOKEN", "NUKI_HOST", "NUKI_TOKEN", "DOOR_ENTITY", "DOOR_OPENER"):
        monkeypatch.delenv(f"DCH_BRIDGE_{k}", raising=False)
    assert not BridgeSettings(_env_file=None).door_configured  # type: ignore[call-arg]

    monkeypatch.setenv("DCH_BRIDGE_UNIFI_HOST", "192.0.2.8")
    monkeypatch.setenv("DCH_BRIDGE_UNIFI_TOKEN", "t")
    # Nur die Ereignisseite: ohne Ziel bleibt der Dienst aus.
    assert not BridgeSettings(_env_file=None).door_configured  # type: ignore[call-arg]

    # Vorgabe ist Home Assistant; dort genügt die Entität.
    monkeypatch.setenv("DCH_BRIDGE_DOOR_ENTITY", "lock.haupteingang_nuki")
    s = BridgeSettings(_env_file=None)  # type: ignore[call-arg]
    assert s.door_opener == "home_assistant" and s.door_configured
    assert s.door_service == "lock.open"

    # Auf der Nuki-Bridge zählt stattdessen deren Adresse - die Entität hilft dort nicht.
    monkeypatch.setenv("DCH_BRIDGE_DOOR_OPENER", "nuki_bridge")
    assert not BridgeSettings(_env_file=None).door_configured  # type: ignore[call-arg]
    monkeypatch.setenv("DCH_BRIDGE_NUKI_HOST", "192.0.2.9")
    monkeypatch.setenv("DCH_BRIDGE_NUKI_TOKEN", "t")
    assert BridgeSettings(_env_file=None).door_configured  # type: ignore[call-arg]


class _Rest:
    """Home Assistant, so weit die Tür es braucht: ein Dienstaufruf und ein Zustand."""

    def __init__(self, state: str | None = "locked", fail: bool = False) -> None:
        self.calls: list[tuple[str, str, str]] = []
        self.state = state
        self.fail = fail

    async def call_service(self, domain: str, service: str, entity_id: str) -> Any:
        self.calls.append((domain, service, entity_id))
        if self.fail:
            raise RuntimeError("500 Internal Server Error")
        return []

    async def state_of(self, entity_id: str) -> str | None:
        if self.fail:
            raise RuntimeError("timeout")
        return self.state


@pytest.mark.asyncio
async def test_home_assistant_opener_calls_the_configured_service() -> None:
    rest = _Rest()
    op = HomeAssistantOpener(rest, "lock.haupteingang_nuki")  # type: ignore[arg-type]
    await op.open_door()
    # lock.open zieht die Falle. Der Dienstname ist Einstellung, nicht Quelltext - ob die
    # Matter-Anbindung ihn hergibt, entscheidet das Gerät.
    assert rest.calls == [("lock", "open", "lock.haupteingang_nuki")]


@pytest.mark.asyncio
async def test_a_different_service_can_be_configured_without_a_code_change() -> None:
    rest = _Rest()
    op = HomeAssistantOpener(rest, "lock.haupteingang_nuki", "lock.unlock")  # type: ignore[arg-type]
    await op.open_door()
    assert rest.calls == [("lock", "unlock", "lock.haupteingang_nuki")]


@pytest.mark.asyncio
async def test_a_failing_service_call_raises_instead_of_going_quiet() -> None:
    op = HomeAssistantOpener(_Rest(fail=True), "lock.x")  # type: ignore[arg-type]
    with pytest.raises(OpenerError):
        await op.open_door()


@pytest.mark.asyncio
async def test_reachability_distinguishes_unavailable_from_a_real_state() -> None:
    """Genau diese Größe entscheidet später, ob der Türweg bei HA bleibt."""
    assert await HomeAssistantOpener(_Rest("locked"), "lock.x").reachable()  # type: ignore[arg-type]
    assert await HomeAssistantOpener(_Rest("unlocked"), "lock.x").reachable()  # type: ignore[arg-type]
    assert not await HomeAssistantOpener(_Rest("unavailable"), "lock.x").reachable()  # type: ignore[arg-type]
    assert not await HomeAssistantOpener(_Rest("unknown"), "lock.x").reachable()  # type: ignore[arg-type]
    assert not await HomeAssistantOpener(_Rest(None), "lock.x").reachable()  # type: ignore[arg-type]
    assert not await HomeAssistantOpener(_Rest(fail=True), "lock.x").reachable()  # type: ignore[arg-type]


@pytest.mark.asyncio
async def test_the_probe_is_written_as_a_measurement_series() -> None:
    """Die Vermutung „die Strecke ist brüchig" wird damit zu einer Reihe in der Verfügbarkeitskarte."""
    seen: list[Any] = []

    async def collect(items: list[Any]) -> None:
        seen.extend(items)

    events = UnifiAccessEvents("192.0.2.8", "t")
    op = HomeAssistantOpener(_Rest("locked"), "lock.x")  # type: ignore[arg-type]
    svc = DoorService(
        events, op, DoorPolicy.of(enabled=False, doors=[], actors=[], methods=[]), collect
    )
    assert await svc.probe()
    assert [(r.key, r.value) for r in seen] == [("door_lock_online", 1.0)]

    op.rest = _Rest("unavailable")  # type: ignore[assignment]
    assert not await svc.probe()
    assert seen[-1].value == 0.0
    assert svc.status()["opener"] == "home_assistant"


def test_a_rejected_handshake_says_what_to_check() -> None:
    """Beim Einrichten ist der Grund mehr wert als der Statuscode.

    Der Rumpf der Antwort geht in der Standardmeldung der WebSocket-Bibliothek unter; übrig bleibt
    eine abgeschnittene Kopfzeilenliste, aus der niemand ableiten kann, welcher Token falsch ist.
    """

    class _Resp:
        def __init__(self, code: int) -> None:
            self.status_code = code

    class _HandshakeError(Exception):
        def __init__(self, code: int) -> None:
            self.response = _Resp(code)

    ev = UnifiAccessEvents("192.0.2.8", "t")
    msg = ev._explain(_HandshakeError(401))
    assert "401" in msg and "Access" in msg and "System Log" in msg
    assert "404" in ev._explain(_HandshakeError(404))
    assert "HTTP 500" in ev._explain(_HandshakeError(500))
    # Ohne Antwort bleibt die rohe Ausnahme - besser als eine erfundene Erklärung.
    assert "ValueError" in ev._explain(ValueError("kaputt"))


class _Socket:
    """Ein WebSocket, so weit `pump` ihn braucht: eine Folge von Rahmen, dann Stille."""

    def __init__(self, frames: list[str], then_silent: bool = True) -> None:
        self.frames = list(frames)
        self.then_silent = then_silent

    async def recv(self) -> str:
        if self.frames:
            return self.frames.pop(0)
        if self.then_silent:
            await asyncio.sleep(3600)  # nie - der Totmannschalter muss greifen
        raise RuntimeError("Verbindung zu")


@pytest.mark.asyncio
async def test_the_keepalive_of_the_console_keeps_the_line_alive() -> None:
    """Die Konsole schickt den nackten Text „Hello". Er ist kein Zutritt, aber ein Lebenszeichen."""
    seen: list[AccessEvent] = []

    async def collect(e: AccessEvent, _f: Any) -> None:
        seen.append(e)

    ev = UnifiAccessEvents("192.0.2.8", "t", idle_timeout_s=0.05)
    ev.on_event = collect
    with pytest.raises(ConnectionError, match="kein Rahmen"):
        await ev.pump(_Socket(['"Hello"', '"Hello"', json.dumps(_frame())]))
    # Drei Rahmen gezählt, einer davon ein Zutritt. Die beiden Keepalives gehen nicht verloren:
    # an ihnen sieht man, dass die Leitung lebt, auch wenn niemand vor der Tür steht.
    assert ev.events_seen == 3
    assert ev.access_events == 1
    assert len(seen) == 1 and seen[0].actor == "Moritz"


@pytest.mark.asyncio
async def test_a_line_that_says_nothing_at_all_is_treated_as_dead() -> None:
    """Ohne Protokoll-Pings ist das die einzige Stelle, an der eine tote Leitung auffliegt."""
    ev = UnifiAccessEvents("192.0.2.8", "t", idle_timeout_s=0.05)
    with pytest.raises(ConnectionError, match="kein Keepalive"):
        await ev.pump(_Socket([]))
    assert ev.events_seen == 0


@pytest.mark.asyncio
async def test_unreadable_frames_do_not_end_the_connection() -> None:
    ev = UnifiAccessEvents("192.0.2.8", "t", idle_timeout_s=0.05)
    with pytest.raises(ConnectionError):
        await ev.pump(_Socket(["kein json", "{kaputt", "[]"]))
    assert ev.events_seen == 3 and ev.access_events == 0


@pytest.mark.asyncio
async def test_an_unreadable_access_frame_is_counted_and_still_passed_on() -> None:
    """Zählen statt verschlucken: nur so fällt im Status auf, dass die Deutung nicht greift.

    Weitergereicht wird es trotzdem, damit die Entscheidung an einer Stelle bleibt - dort wird aus
    dem leeren Ereignis ein „nichts zu lesen" und keine erfundene Ablehnung.
    """
    seen: list[AccessEvent] = []

    async def collect(e: AccessEvent, _f: Any) -> None:
        seen.append(e)

    ev = UnifiAccessEvents("192.0.2.8", "t", idle_timeout_s=0.05)
    ev.on_event = collect
    frame = json.dumps({"event": "access.logs.add", "data": {"_id": "abc"}})
    with pytest.raises(ConnectionError):
        await ev.pump(_Socket([frame]))
    assert ev.access_events == 1
    assert ev.unreadable_events == 1
    assert len(seen) == 1
    assert ev.status()["unreadable_events"] == 1
