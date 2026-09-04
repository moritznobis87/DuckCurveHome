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
