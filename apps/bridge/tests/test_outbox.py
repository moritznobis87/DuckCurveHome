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


def test_sequence_keeps_climbing_after_everything_was_acknowledged(tmp_path: Path) -> None:
    """Der Zähler darf nicht bei 1 neu beginnen, sobald die Outbox leer läuft.

    Die API nimmt ein Telemetriepaket nur an, wenn seine Nummer größer ist als die zuletzt gesehene -
    bestätigt es aber in jedem Fall. Eine wiederholte 1 wurde deshalb stillschweigend verworfen, und die
    Bridge löschte sie danach als erledigt. So ging über Stunden jede Messung verloren.
    """
    ob = Outbox(tmp_path / "o.sqlite", timedelta(hours=1))
    seen = []
    for _ in range(5):
        seq = ob.next_seq()
        ob.put(seq, {"seq": seq})
        ob.ack(seq)  # bestätigt → Zeile weg, Tabelle wieder leer
        seen.append(seq)
    assert seen == [1, 2, 3, 4, 5]
    assert ob.count() == 0
    ob.close()

    # Auch über einen Neustart hinweg, obwohl keine einzige Zeile mehr existiert
    reopened = Outbox(tmp_path / "o.sqlite", timedelta(hours=1))
    assert reopened.next_seq() == 6
    reopened.close()
