from __future__ import annotations

from fastapi.testclient import TestClient


def test_health(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_live_state_is_consistent(client: TestClient) -> None:
    r = client.get("/api/v1/live/state")
    assert r.status_code == 200
    body = r.json()
    snap = body["snapshot"]
    assert snap["pv_power_kw"]["quality"] == "ok"
    assert body["buffer"]["soc"] is not None
    assert body["decision"] is not None
    assert body["decision"]["explanation_de"]
    assert body["system"]["mode"] == "demo"
    assert "pv_kwh" in body["today_kwh"]


def test_history_today_has_rows(client: TestClient) -> None:
    r = client.get("/api/v1/history", params={"range": "today"})
    assert r.status_code == 200
    rows = r.json()["rows"]
    assert len(rows) > 60
    assert "pv_power_kw" in rows[0]


def test_history_custom_validation(client: TestClient) -> None:
    r = client.get("/api/v1/history", params={"range": "custom"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "missing_range"


def test_plan(client: TestClient) -> None:
    r = client.get("/api/v1/plan")
    assert r.status_code == 200
    plan = r.json()
    assert plan["planner"] == "rule_based_v1"
    assert len(plan["intervals"]) >= 96
    assert plan["pv_forecast_today_kwh"] > 0


def test_switch_actuator_and_reject_heat_pump_contacts(client: TestClient) -> None:
    r = client.post(
        "/api/v1/control/actuators/coffee_machine", json={"state": True, "duration_min": 60}
    )
    assert r.status_code == 200 and r.json()["ok"] is True
    state = client.get("/api/v1/live/state").json()
    assert state["snapshot"]["actuators"]["coffee_machine"]["value"] == 1.0
    r = client.post("/api/v1/control/actuators/hp_release_contact", json={"state": True})
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "unknown_actuator"


def test_manual_mode_sets_override_and_returns_to_auto(client: TestClient) -> None:
    r = client.post(
        "/api/v1/control/heat-pump/mode",
        json={"system_mode": "manual", "manual_state": "on", "duration_min": 30},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["system_mode"] == "manual" and body["override"]["kind"] == "force_release"
    state = client.get("/api/v1/live/state").json()
    assert state["decision"]["controller_state"] == "manual"
    r = client.post("/api/v1/control/heat-pump/mode", json={"system_mode": "manual"})
    assert r.status_code == 422
    r = client.post(
        "/api/v1/control/heat-pump/mode", json={"system_mode": "auto", "auto_profile": "pv"}
    )
    assert r.json()["override"] is None and r.json()["auto_profile"] == "pv"


def test_demo_fault_injection(client: TestClient) -> None:
    r = client.post(
        "/api/v1/demo",
        json={"fault_key": "grid_power_kw", "fault_quality": "unavailable", "fault_duration_s": 60},
    )
    assert r.status_code == 200
    r = client.post("/api/v1/demo", json={"speed": 60})
    assert r.json()["speed"] == 60


def test_decisions_endpoint(client: TestClient) -> None:
    r = client.get("/api/v1/control/decisions", params={"limit": 5})
    assert r.status_code == 200
    assert 1 <= len(r.json()) <= 5


def test_unknown_route_uses_error_envelope(client: TestClient) -> None:
    r = client.get("/api/v1/nope")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "not_found"


def test_sse_broker_coalesces_snapshots_but_keeps_decisions() -> None:
    import asyncio

    from dch_api.infrastructure.sse_broker import SseBroker

    async def run() -> list[str]:
        broker = SseBroker()
        sub = broker.subscribe()
        for i in range(12):
            broker.publish("snapshot", {"i": i})
        broker.publish("decision", {"d": 1})
        for i in range(12):
            broker.publish("snapshot", {"i": 100 + i})
        events: list[str] = []
        while not sub.queue.empty():
            events.append(sub.queue.get_nowait()[1])
        broker.unsubscribe(sub)
        return events

    events = asyncio.run(run())
    assert "decision" in events
    assert len(events) <= 8
    assert events[-1] == "snapshot"
