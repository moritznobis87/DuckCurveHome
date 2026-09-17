"""Wer darf die Haustür öffnen - und vor allem: wer nicht.

Eine Feuerstätte, die fälschlich anspringt, kostet Pellets. Eine Haustür, die fälschlich aufgeht,
ist etwas anderes. Die Tests hier sind deshalb überwiegend Ablehnungen: jede Bedingung der
Erlaubnisliste wird einzeln verletzt, damit keine davon versehentlich wirkungslos werden kann.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.control import AccessEvent, DoorGate, DoorPolicy

NOW = datetime(2026, 9, 17, 18, 30, tzinfo=UTC)


def _policy(**over: object) -> DoorPolicy:
    args: dict[str, object] = {
        "enabled": True,
        "doors": ["Haustür"],
        "actors": ["Moritz"],
        "methods": ["FACE"],
    }
    args.update(over)
    return DoorPolicy.of(**args)  # type: ignore[arg-type]


def _event(**over: object) -> AccessEvent:
    args: dict[str, object] = {
        "at": NOW,
        "door": "Haustür",
        "actor": "Moritz",
        "method": "FACE",
        "granted": True,
    }
    args.update(over)
    return AccessEvent(**args)  # type: ignore[arg-type]


def test_the_expected_case_opens() -> None:
    d = DoorGate(_policy()).decide(_event(), NOW)
    assert d.open_door
    assert "Moritz" in d.reason_de


def test_case_and_spaces_do_not_matter() -> None:
    """An der Wand steht „Haustür", in der Konsole vielleicht „haustuer  ". Beides ist dieselbe Tür."""
    gate = DoorGate(
        DoorPolicy.of(enabled=True, doors=[" HAUSTÜR "], actors=["moritz"], methods=["face"])
    )
    assert gate.decide(_event(door="Haustür", actor="Moritz", method="FACE"), NOW).open_door


def test_without_the_release_nothing_opens() -> None:
    """Die Vorgabe ist Beobachtung. Alles andere wäre die falsche Vorgabe für eine Haustür."""
    d = DoorGate(_policy(enabled=False)).decide(_event(), NOW)
    assert not d.open_door
    assert "Beobachtung" in d.reason_de


def test_a_refused_access_stays_refused() -> None:
    d = DoorGate(_policy()).decide(_event(granted=False), NOW)
    assert not d.open_door
    assert "abgelehnt" in d.reason_de


def test_another_door_does_not_open_this_one() -> None:
    assert not DoorGate(_policy()).decide(_event(door="Garage"), NOW).open_door


def test_another_person_does_not_open() -> None:
    assert not DoorGate(_policy()).decide(_event(actor="Unbekannt"), NOW).open_door


def test_another_method_does_not_open() -> None:
    """Ein PIN ist kein Gesichtsscan, auch wenn die Konsole beides erlaubt."""
    d = DoorGate(_policy()).decide(_event(method="PIN_CODE"), NOW)
    assert not d.open_door
    assert "Verfahren" in d.reason_de


def test_an_empty_list_lets_nobody_through() -> None:
    """Eine leere Erlaubnisliste heißt „niemand" und nicht „alle" - der teuerste denkbare Fehler."""
    gate = DoorGate(DoorPolicy.of(enabled=True, doors=[], actors=[], methods=[]))
    assert not gate.decide(_event(), NOW).open_door


def test_a_replayed_event_does_not_open_twice() -> None:
    """Die Konsole stellt nach einem Verbindungsabbruch erneut zu. Das darf keine zweite Öffnung sein."""
    gate = DoorGate(_policy())
    assert gate.decide(_event(), NOW).open_door
    gate.note_open("Moritz", NOW)
    again = gate.decide(_event(), NOW + timedelta(seconds=3))
    assert not again.open_door
    assert "Wiederholung" in again.reason_de
    # Nach Ablauf der Sperre geht es wieder.
    assert gate.decide(
        _event(at=NOW + timedelta(seconds=20)), NOW + timedelta(seconds=20)
    ).open_door


def test_an_old_event_is_not_caught_up() -> None:
    """Nach einem Neuaufbau liefert die Konsole die Historie nach. Die Tür holt nichts nach."""
    gate = DoorGate(_policy())
    d = gate.decide(_event(at=NOW - timedelta(minutes=20)), NOW)
    assert not d.open_door
    assert "nicht nachgeholt" in d.reason_de


def test_a_failed_open_does_not_block_the_next_attempt() -> None:
    """Die Sperre wird erst durch `note_open` gesetzt - wer einen Fehlschlag erlebt, darf sofort erneut."""
    gate = DoorGate(_policy())
    assert gate.decide(_event(), NOW).open_door  # Schloss antwortet nicht, note_open bleibt aus
    assert gate.decide(_event(at=NOW + timedelta(seconds=2)), NOW + timedelta(seconds=2)).open_door


def test_the_memory_does_not_grow_forever() -> None:
    gate = DoorGate(_policy())
    gate.note_open("gast", NOW - timedelta(days=2))
    gate.note_open("moritz", NOW)
    gate.forget_before(NOW - timedelta(hours=1))
    assert set(gate.last_open) == {"moritz"}
