"""SQLite-Outbox: Telemetrie-Frames bleiben gespeichert, bis die API sie bestätigt hat (Nachlieferung)."""

from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path


class Outbox:
    def __init__(self, path: Path, max_age: timedelta) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(path, isolation_level=None)
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.execute(
            "CREATE TABLE IF NOT EXISTS outbox ("
            "seq INTEGER PRIMARY KEY, created_at TEXT NOT NULL, payload TEXT NOT NULL)"
        )
        self.max_age = max_age

    def next_seq(self) -> int:
        row = self._db.execute("SELECT COALESCE(MAX(seq), 0) FROM outbox").fetchone()
        return int(row[0]) + 1

    def put(self, seq: int, payload: dict[str, object]) -> None:
        self._db.execute(
            "INSERT OR REPLACE INTO outbox (seq, created_at, payload) VALUES (?, ?, ?)",
            (seq, datetime.now(UTC).isoformat(), json.dumps(payload, default=str)),
        )

    def ack(self, seq: int) -> None:
        self._db.execute("DELETE FROM outbox WHERE seq <= ?", (seq,))

    def pending(self, after_seq: int, limit: int = 50) -> list[tuple[int, dict[str, object]]]:
        rows = self._db.execute(
            "SELECT seq, payload FROM outbox WHERE seq > ? ORDER BY seq LIMIT ?", (after_seq, limit)
        ).fetchall()
        return [(int(seq), json.loads(payload)) for seq, payload in rows]

    def count(self) -> int:
        return int(self._db.execute("SELECT COUNT(*) FROM outbox").fetchone()[0])

    def prune(self) -> int:
        cutoff = (datetime.now(UTC) - self.max_age).isoformat()
        cur = self._db.execute("DELETE FROM outbox WHERE created_at < ?", (cutoff,))
        return int(cur.rowcount)

    def close(self) -> None:
        self._db.close()
