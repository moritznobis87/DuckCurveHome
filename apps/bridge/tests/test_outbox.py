from __future__ import annotations

from datetime import timedelta
from pathlib import Path

from dch_bridge.outbox import Outbox


def test_outbox_sequence_ack_and_pending(tmp_path: Path) -> None:
    ob = Outbox(tmp_path / "o.sqlite", timedelta(hours=1))
    assert ob.next_seq() == 1
    for i in range(1, 6):
        ob.put(i, {"seq": i})
    assert ob.count() == 5
    ob.ack(3)
    assert [s for s, _ in ob.pending(0)] == [4, 5]
    assert ob.next_seq() == 6
    ob.close()


def test_outbox_survives_restart(tmp_path: Path) -> None:
    """Nicht bestätigte Frames bleiben nach einem Neustart der Bridge erhalten."""
    path = tmp_path / "o.sqlite"
    ob = Outbox(path, timedelta(hours=1))
    ob.put(1, {"seq": 1, "items": ["a"]})
    ob.put(2, {"seq": 2, "items": ["b"]})
    ob.ack(1)
    ob.close()
    reopened = Outbox(path, timedelta(hours=1))
    assert [(s, p["items"]) for s, p in reopened.pending(0)] == [(2, ["b"])]
    assert reopened.next_seq() == 3  # Sequenz läuft weiter, keine Wiederverwendung
    reopened.close()
