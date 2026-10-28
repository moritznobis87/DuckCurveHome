"""Repositories - die einzige Stelle mit SQL. Der Demo-Modus nutzt In-Memory-Varianten."""

from __future__ import annotations

import csv
import io
import json
from collections.abc import AsyncIterator, Mapping
from datetime import UTC, datetime, timedelta
from typing import Any, cast
from uuid import UUID

from sqlalchemy import CursorResult, delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker
from sqlalchemy.sql import Executable

from dch_api.infrastructure.db import models as m
from dch_api.infrastructure.history import SERIES
from hems_core.accounting import HourlyEnergy
from hems_core.domain import Decision, OperatingMode, Quality
from hems_core.protocol import RawReading
from hems_core.thermal import HeatHourInput

QUALITY_CODE = {q: i for i, q in enumerate(Quality)}
CODE_QUALITY = {i: q for q, i in QUALITY_CODE.items()}

Row = dict[str, Any]


# Spalten der dauerhaften Minutentabelle. Sie entsprechen den Reihen der Historie; der Aktor trägt in
# den Rohwerten den Präfix "actuator:", als Spaltenname wäre das ungültig.
MINUTE_COLUMNS: tuple[str, ...] = SERIES
MINUTE_KEY_TO_COLUMN: dict[str, str] = {
    ("actuator:hp_release_contact" if k == "hp_release_contact" else k): k for k in SERIES
}


def _csv_line(values: list[Any]) -> str:
    """Eine CSV-Zeile nach RFC 4180: Komma als Trennzeichen, Punkt als Dezimalzeichen, leer für NULL.

    Bewusst nicht im deutschen Excel-Dialekt (Semikolon, Dezimalkomma): das hier ist das Archiv, das
    einen Anbieterwechsel und ein Jahrzehnt überstehen soll, und es wird von jedem Werkzeug gelesen.
    """
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerow(["" if v is None else v for v in values])
    return buf.getvalue()


class SqlRepositories:
    def __init__(self, engine: AsyncEngine) -> None:
        self.engine = engine
        self.maker = async_sessionmaker(engine, expire_on_commit=False)
        self.dialect = engine.dialect.name

    # ------------------------------------------------------------------ Hilfen
    def _upsert(
        self,
        table: Any,
        rows: list[Row],
        pk: list[str],
        update: list[str],
        newer_col: str | None = None,
    ) -> Executable:
        """INSERT … ON CONFLICT DO UPDATE; mit newer_col nur, wenn der neue Wert nicht älter ist."""
        ins: Any = (
            sqlite_insert(table).values(rows)
            if self.dialect == "sqlite"
            else pg_insert(table).values(rows)
        )
        set_ = {c: getattr(ins.excluded, c) for c in update}
        where = None
        if newer_col is not None:
            where = getattr(table, newer_col) <= getattr(ins.excluded, newer_col)
        return cast(
            Executable, ins.on_conflict_do_update(index_elements=pk, set_=set_, where=where)
        )

    @staticmethod
    def _aware(dt: datetime) -> datetime:
        return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)

    # ------------------------------------------------------------------ Messwerte
    async def add_readings(self, readings: list[RawReading]) -> None:
        if not readings:
            return
        now = datetime.now(UTC)
        raw_rows: list[Row] = [
            {
                "sensor_key": r.key,
                "observed_at": r.observed_at,
                "value": r.value,
                "quality": QUALITY_CODE[r.quality],
            }
            for r in readings
        ]
        latest: dict[str, RawReading] = {}
        for r in readings:
            if r.key not in latest or r.observed_at >= latest[r.key].observed_at:
                latest[r.key] = r
        live_rows: list[Row] = [
            {
                "sensor_key": r.key,
                "value": r.value,
                "observed_at": r.observed_at,
                "quality": r.quality.value,
                "source": r.source,
                "received_at": now,
            }
            for r in latest.values()
        ]
        # Duplikate innerhalb eines Batches (gleicher Schlüssel, gleiche Zeit) zusammenfassen
        dedup: dict[tuple[str, datetime], Row] = {
            (r["sensor_key"], r["observed_at"]): r for r in raw_rows
        }
        async with self.maker() as s:
            await s.execute(
                self._upsert(
                    m.MeasurementRaw,
                    list(dedup.values()),
                    ["sensor_key", "observed_at"],
                    ["value", "quality"],
                )
            )
            await s.execute(
                self._upsert(
                    m.LiveStateRow,
                    live_rows,
                    ["sensor_key"],
                    ["value", "observed_at", "quality", "source", "received_at"],
                    newer_col="observed_at",
                )
            )
            await s.commit()

    async def latest(self) -> list[RawReading]:
        async with self.maker() as s:
            rows = (await s.execute(select(m.LiveStateRow))).scalars().all()
        return [
            RawReading(
                key=r.sensor_key,
                value=r.value,
                observed_at=self._aware(r.observed_at),
                quality=Quality(r.quality),
                source=r.source,
            )
            for r in rows
        ]

    async def minute_series(
        self, start: datetime, end: datetime, keys: list[str]
    ) -> list[dict[str, float | str | None]]:
        """Minutenmittel eines Zeitraums, aus dem dauerhaften Bestand und den frischen Rohwerten.

        Beide Quellen werden gelesen und zusammengeführt: `measurements_minute` reicht beliebig weit
        zurück, endet aber am letzten verdichteten Bin, und die Minuten danach stehen nur in den
        Rohwerten. Bei Überschneidung gewinnt der verdichtete Wert - er ist aus denselben Rohwerten
        entstanden, nur bereits abgeschlossen.
        """
        by_bucket: dict[str, dict[str, float | str | None]] = {}
        for ts, values in await self._stored_minutes(start, end):
            row = by_bucket.setdefault(ts, {"ts": ts})
            for k in keys:
                if k in values:
                    row[k] = values[k]
        for ts, key, avg in await self._raw_minutes(start, end, keys):
            row = by_bucket.setdefault(ts, {"ts": ts})
            row.setdefault(key, None if avg is None else round(avg, 3))
        out = [by_bucket[ts] for ts in sorted(by_bucket)]
        for row in out:
            for k in keys:
                row.setdefault(k, None)
        return out

    async def _raw_minutes(
        self, start: datetime, end: datetime, keys: list[str] | None = None
    ) -> list[tuple[str, str, float | None]]:
        """Rohwerte zu Minutenmitteln gruppiert: (Zeitstempel, Reihe, Mittelwert)."""
        if self.dialect == "sqlite":
            bucket: Any = func.strftime("%Y-%m-%dT%H:%M:00+00:00", m.MeasurementRaw.observed_at)
        else:
            bucket = func.date_trunc("minute", m.MeasurementRaw.observed_at)
        stmt = (
            select(
                bucket.label("bucket"),
                m.MeasurementRaw.sensor_key,
                func.avg(m.MeasurementRaw.value),
            )
            .where(m.MeasurementRaw.observed_at >= start, m.MeasurementRaw.observed_at < end)
            .where(m.MeasurementRaw.quality.in_([0, 4]))
            .group_by("bucket", m.MeasurementRaw.sensor_key)
            .order_by("bucket")
        )
        if keys is not None:
            stmt = stmt.where(m.MeasurementRaw.sensor_key.in_(keys))
        async with self.maker() as s:
            rows = (await s.execute(stmt)).all()
        return [
            (self._bucket_iso(b), key, None if avg is None else float(avg)) for b, key, avg in rows
        ]

    def _bucket_iso(self, b: object) -> str:
        if isinstance(b, datetime):
            return self._aware(b).astimezone(UTC).isoformat().replace("+00:00", "Z")
        return str(b).replace("+00:00", "Z")

    async def _stored_minutes(
        self, start: datetime, end: datetime
    ) -> list[tuple[str, dict[str, float | None]]]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.MeasurementMinute)
                        .where(m.MeasurementMinute.bucket >= start)
                        .where(m.MeasurementMinute.bucket < end)
                        .order_by(m.MeasurementMinute.bucket)
                    )
                )
                .scalars()
                .all()
            )
        out: list[tuple[str, dict[str, float | None]]] = []
        for r in rows:
            values: dict[str, float | None] = {k: getattr(r, k) for k in MINUTE_COLUMNS}
            for k, v in (r.extra or {}).items():
                values[k] = v
            out.append((self._bucket_iso(self._aware(r.bucket)), values))
        return out

    async def last_minute_bucket(self) -> datetime | None:
        async with self.maker() as s:
            v = (await s.execute(select(func.max(m.MeasurementMinute.bucket)))).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def rollup_minutes(self, start: datetime, end: datetime) -> int:
        """Rohwerte des Zeitraums zu Minutenzeilen verdichten und dauerhaft ablegen.

        Läuft mehrfach über denselben Zeitraum ohne Schaden: jede Minute wird ersetzt, nicht ergänzt.
        Reihen ohne eigene Spalte wandern nach `extra`, damit ein neu hinzugekommener Sensor nicht
        stillschweigend verloren geht, bevor jemand ihm eine Spalte gibt.
        """
        grouped: dict[str, dict[str, float | None]] = {}
        for ts, key, avg in await self._raw_minutes(start, end):
            grouped.setdefault(ts, {})[key] = None if avg is None else round(avg, 3)
        if not grouped:
            return 0
        rows: list[dict[str, Any]] = []
        for ts, values in grouped.items():
            row: dict[str, Any] = {"bucket": datetime.fromisoformat(ts.replace("Z", "+00:00"))}
            extra: dict[str, float] = {}
            for key, value in values.items():
                column = MINUTE_KEY_TO_COLUMN.get(key)
                if column is not None:
                    row[column] = value
                elif value is not None:
                    extra[key] = value
            for column in MINUTE_COLUMNS:
                row.setdefault(column, None)
            row["extra"] = extra or None
            rows.append(row)
        async with self.maker() as s:
            await s.execute(
                self._upsert(
                    m.MeasurementMinute,
                    rows,
                    ["bucket"],
                    [*MINUTE_COLUMNS, "extra"],
                )
            )
            await s.commit()
        return len(rows)

    # ------------------------------------------------------------------ Export
    async def stream_minutes_csv(
        self, start: datetime, end: datetime, batch: int = 5000
    ) -> AsyncIterator[str]:
        """Minutenwerte als CSV, seitenweise.

        Geblättert wird über den Zeitstempel, nicht über OFFSET: ein Jahr sind 525 600 Zeilen, und
        OFFSET ließe die Datenbank für jede Seite erneut alles davor durchzählen. Nichts von alldem
        liegt gleichzeitig im Speicher - weder hier noch beim Empfänger, der es als Datei mitschreibt.
        """
        columns = [*MINUTE_COLUMNS, "extra"]
        yield _csv_line(["ts", *columns])
        cursor = start
        while True:
            async with self.maker() as s:
                rows = (
                    (
                        await s.execute(
                            select(m.MeasurementMinute)
                            .where(m.MeasurementMinute.bucket >= cursor)
                            .where(m.MeasurementMinute.bucket < end)
                            .order_by(m.MeasurementMinute.bucket)
                            .limit(batch)
                        )
                    )
                    .scalars()
                    .all()
                )
            if not rows:
                return
            out: list[str] = []
            for r in rows:
                values = [getattr(r, c) for c in MINUTE_COLUMNS]
                extra = r.extra
                out.append(
                    _csv_line(
                        [
                            self._bucket_iso(self._aware(r.bucket)),
                            *values,
                            json.dumps(extra, sort_keys=True) if extra else None,
                        ]
                    )
                )
            yield "".join(out)
            cursor = self._aware(rows[-1].bucket) + timedelta(microseconds=1)

    async def stream_hours_csv(
        self, start: datetime, end: datetime, batch: int = 2000
    ) -> AsyncIterator[str]:
        """Stundenbilanz als CSV - Energien, Herkunft, Kosten und die Grundlagen der PV-Abrechnung."""
        columns = [c.name for c in m.EnergyHour.__table__.columns if c.name != "hour_start"]
        yield _csv_line(["hour_start", *columns])
        cursor = start
        while True:
            async with self.maker() as s:
                rows = (
                    (
                        await s.execute(
                            select(m.EnergyHour)
                            .where(m.EnergyHour.hour_start >= cursor)
                            .where(m.EnergyHour.hour_start < end)
                            .order_by(m.EnergyHour.hour_start)
                            .limit(batch)
                        )
                    )
                    .scalars()
                    .all()
                )
            if not rows:
                return
            out: list[str] = []
            for r in rows:
                out.append(
                    _csv_line(
                        [
                            self._bucket_iso(self._aware(r.hour_start)),
                            *[getattr(r, c) for c in columns],
                        ]
                    )
                )
            yield "".join(out)
            cursor = self._aware(rows[-1].hour_start) + timedelta(microseconds=1)

    async def hourly_coverage(
        self, keys: list[str], start: datetime, end: datetime
    ) -> dict[str, list[tuple[str, int]]]:
        """Je Reihe und Stunde: wie viele der 60 Minuten haben einen Wert.

        Die Frage dahinter ist nicht „wie hoch war die Leistung", sondern „kam überhaupt etwas an".
        Ein Zähler, dessen Verbindung nachts abreißt, ist in einer Leistungskurve schwer zu sehen -
        eine Null sieht aus wie eine Null. In einer Karte aus Tagen und Stunden ist er ein Streifen.

        Gezählt wird ausschließlich auf der Stunde, nicht auf der Minute: eine volle Stunde braucht
        eine Zahl und keine sechzig, und über vier Wochen ist der Unterschied zwischen 672 Zeilen
        und 40 000 der zwischen einer Abfrage und einem Grund, sie nicht zu stellen.
        """
        cols = [(k, MINUTE_KEY_TO_COLUMN[k]) for k in keys if k in MINUTE_KEY_TO_COLUMN]
        if not cols:
            return {}
        if self.dialect == "sqlite":
            bucket: Any = func.strftime("%Y-%m-%dT%H:00:00+00:00", m.MeasurementMinute.bucket)
        else:
            bucket = func.date_trunc("hour", m.MeasurementMinute.bucket)
        stmt = (
            select(
                bucket.label("hour"),
                *[func.count(getattr(m.MeasurementMinute, col)).label(key) for key, col in cols],
            )
            .where(m.MeasurementMinute.bucket >= start, m.MeasurementMinute.bucket < end)
            .group_by("hour")
            .order_by("hour")
        )
        async with self.maker() as s:
            rows = (await s.execute(stmt)).all()
        out: dict[str, list[tuple[str, int]]] = {key: [] for key, _ in cols}
        for row in rows:
            hour = self._bucket_iso(row[0])
            for i, (key, _col) in enumerate(cols, start=1):
                out[key].append((hour, int(row[i] or 0)))
        return out

    async def last_value_at(self, key: str) -> datetime | None:
        """Wann zuletzt ein Wert dieser Reihe im dauerhaften Bestand stand."""
        col = MINUTE_KEY_TO_COLUMN.get(key)
        if col is None:
            return None
        async with self.maker() as s:
            row = (
                await s.execute(
                    select(func.max(m.MeasurementMinute.bucket)).where(
                        getattr(m.MeasurementMinute, col).is_not(None)
                    )
                )
            ).first()
        # SQLite gibt den Zeitstempel ohne Zone zurück, PostgreSQL mit. Ohne Vereinheitlichung
        # rechnete die Oberfläche das Alter des Werts je nach Datenbank um zwei Stunden daneben.
        return self._aware(row[0]) if row and row[0] else None

    async def storage_report(self) -> list[dict[str, object]]:
        """Platzbedarf je Tabelle, größte zuerst: Daten, Indizes, geschätzte Zeilenzahl.

        Der Speicherplatz einer verwalteten Datenbank ist die Größe, die bei den meisten Anbietern
        die Rechnung treibt - über den Arbeitsspeicher, den der Seitencache belegt, nicht über den
        Plattenplatz allein. Ohne diese Abfrage rät man, welche Tabelle das Geld kostet, und die
        Antwort ist selten die, die man erwartet: Indizes sind bei schmalen Zeilen regelmäßig
        größer als die Daten.

        `reltuples` ist die Schätzung des Planers und wird von Autovacuum gepflegt; sie ist nach
        einem großen Löschlauf kurzzeitig zu hoch. Ein exaktes `count(*)` wäre hier genau die Art
        von Abfrage, deren Kosten wir untersuchen wollen.
        """
        if self.dialect != "postgresql":
            return []
        sql = text(
            """
            SELECT c.relname AS name,
                   pg_total_relation_size(c.oid) AS total_bytes,
                   pg_table_size(c.oid) AS table_bytes,
                   pg_indexes_size(c.oid) AS index_bytes,
                   GREATEST(c.reltuples, 0)::bigint AS rows_estimate
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'r'
            ORDER BY pg_total_relation_size(c.oid) DESC
            """
        )
        async with self.maker() as s:
            rows = (await s.execute(sql)).mappings().all()
        return [dict(r) for r in rows]

    async def prune_raw(self, older_than: timedelta) -> int:
        cutoff = datetime.now(UTC) - older_than
        async with self.maker() as s:
            res = cast(
                CursorResult[Any],
                await s.execute(
                    delete(m.MeasurementRaw).where(m.MeasurementRaw.observed_at < cutoff)
                ),
            )
            await s.commit()
            return int(res.rowcount or 0)

    # ------------------------------------------------------------------ Entscheidungen
    async def add_decision(self, d: Decision) -> None:
        async with self.maker() as s:
            s.add(
                m.ControlDecision(
                    id=d.id,
                    at=d.at,
                    controller_state=d.controller_state.value,
                    k1_release=d.k1_release,
                    k2_block=d.k2_block,
                    reasons=[r.value for r in d.reasons],
                    blocked_by=[r.value for r in d.blocked_by],
                    inputs=d.inputs.model_dump(mode="json"),
                    valid_until=d.valid_until,
                    next_expected=d.next_expected.model_dump(mode="json")
                    if d.next_expected
                    else None,
                    explanation_de=d.explanation_de,
                )
            )
            await s.commit()

    async def recent_decisions(self, limit: int = 20) -> list[Decision]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.ControlDecision).order_by(m.ControlDecision.at.desc()).limit(limit)
                    )
                )
                .scalars()
                .all()
            )
        return [
            Decision.model_validate(
                {
                    "id": r.id,
                    "at": r.at,
                    "controller_state": r.controller_state,
                    "k1_release": r.k1_release,
                    "k2_block": r.k2_block,
                    "reasons": r.reasons,
                    "blocked_by": r.blocked_by,
                    "inputs": r.inputs,
                    "valid_until": r.valid_until,
                    "next_expected": r.next_expected,
                    "explanation_de": r.explanation_de,
                }
            )
            for r in rows
        ]

    # ------------------------------------------------------------------ Modus, Events, Config
    async def save_mode(self, mode: OperatingMode, set_by: str = "dashboard") -> None:
        async with self.maker() as s:
            s.add(
                m.OperatingModeRow(
                    at=datetime.now(UTC),
                    system_mode=mode.system_mode.value,
                    auto_profile=mode.auto_profile.value,
                    override=mode.override.model_dump(mode="json") if mode.override else None,
                    set_by=set_by,
                )
            )
            await s.commit()

    async def load_mode(self) -> OperatingMode | None:
        async with self.maker() as s:
            row = (
                await s.execute(
                    select(m.OperatingModeRow).order_by(m.OperatingModeRow.at.desc()).limit(1)
                )
            ).scalar_one_or_none()
        if row is None:
            return None
        return OperatingMode.model_validate(
            {
                "system_mode": row.system_mode,
                "auto_profile": row.auto_profile,
                "override": row.override,
            }
        )

    async def add_event(
        self,
        severity: str,
        code: str,
        message: str,
        context: Mapping[str, object] | None = None,
        *,
        at: datetime | None = None,
    ) -> None:
        """Ein Ereignis ablegen. `at` ist der Zeitpunkt des Geschehens, nicht der des Eintragens.

        Der Unterschied zählt bei allem, was aus dem Haus gemeldet wird: hat die Leitung eine
        Viertelstunde gestanden, kommen fünf Ereignisse auf einmal an. Mit dem Zeitpunkt des
        Eintragens stünden sie alle in derselben Sekunde, und das Türprotokoll behauptete, um 19:04
        seien vier Leute gleichzeitig vor der Tür gewesen.
        """
        async with self.maker() as s:
            s.add(
                m.SystemEvent(
                    at=at or datetime.now(UTC),
                    severity=severity,
                    code=code,
                    message=message,
                    context=dict(context or {}),
                )
            )
            await s.commit()

    # ------------------------------------------------------------------ Wärmestunden
    async def upsert_heat_hours(self, rows: list[HeatHourInput]) -> None:
        """Eingangsgrößen der Wärmebilanz je Stunde schreiben, vorhandene ersetzen."""
        if not rows:
            return
        now = datetime.now(UTC)
        async with self.maker() as s:
            for r in rows:
                data = r.model_dump()
                data["updated_at"] = now
                row = await s.get(m.HeatHour, r.hour_start)
                if row is None:
                    s.add(m.HeatHour(**data))
                else:
                    for k, v in data.items():
                        setattr(row, k, v)
            await s.commit()

    async def heat_hours(self, start: datetime, end: datetime) -> list[HeatHourInput]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.HeatHour)
                        .where(m.HeatHour.hour_start >= start, m.HeatHour.hour_start < end)
                        .order_by(m.HeatHour.hour_start)
                    )
                )
                .scalars()
                .all()
            )
        fields = [k for k in HeatHourInput.model_fields if k != "hour_start"]
        return [
            HeatHourInput(
                hour_start=self._aware(r.hour_start), **{k: getattr(r, k) for k in fields}
            )
            for r in rows
        ]

    # ------------------------------------------------------------------ Rechnungen
    async def upsert_tibber_invoice(self, data: dict[str, Any]) -> None:
        """Eine geprüfte Rechnung ablegen; dieselbe Rechnungsnummer ersetzt den bisherigen Stand."""
        async with self.maker() as s:
            row = await s.get(m.TibberInvoice, data["number"])
            if row is None:
                s.add(m.TibberInvoice(**data))
            else:
                for k, v in data.items():
                    if k != "uploaded_at":  # der erste Eingang bleibt erhalten
                        setattr(row, k, v)
            await s.commit()

    async def tibber_invoices(self) -> list[m.TibberInvoice]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.TibberInvoice).order_by(m.TibberInvoice.period_start.desc())
                    )
                )
                .scalars()
                .all()
            )
        return list(rows)

    async def has_event(self, code: str) -> bool:
        """Gab es dieses Ereignis schon einmal? Für einmalige Wartungsschritte nach einem Deploy."""
        async with self.maker() as s:
            row = (
                await s.execute(select(m.SystemEvent.id).where(m.SystemEvent.code == code).limit(1))
            ).first()
        return row is not None

    async def events_between(
        self, code: str, start: datetime, end: datetime, limit: int = 200
    ) -> list[m.SystemEvent]:
        """Ereignisse eines Codes in einem Zeitraum, älteste zuerst - für die Tagesdiagnose."""
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.SystemEvent)
                        .where(m.SystemEvent.code == code)
                        .where(m.SystemEvent.at >= start)
                        .where(m.SystemEvent.at < end)
                        .order_by(m.SystemEvent.at)
                        .limit(limit)
                    )
                )
                .scalars()
                .all()
            )
        return list(rows)

    async def events_by_code(
        self, code: str, since: datetime, limit: int = 200
    ) -> list[m.SystemEvent]:
        """Ereignisse eines Codes seit einem Zeitpunkt, jüngste zuerst.

        Getrennt von `events_between`, weil die Blickrichtung eine andere ist: dort wird ein Tag
        nachgelesen, hier die letzte Zeit überblickt. Die Sortierung entscheidet, welche Zeilen die
        Grenze abschneidet - beim Türprotokoll sollen es die ältesten sein.
        """
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.SystemEvent)
                        .where(m.SystemEvent.code == code)
                        .where(m.SystemEvent.at >= since)
                        .order_by(m.SystemEvent.at.desc())
                        .limit(limit)
                    )
                )
                .scalars()
                .all()
            )
        return list(rows)

    async def latest_event(self, code: str) -> m.SystemEvent | None:
        """Der jüngste Eintrag eines Codes, ohne Zeitgrenze.

        Für Ereignisse, die kein Vorfall sind, sondern ein Stand: die Raumliste der
        Einzelraumregelung etwa wird einmal nach dem Start geschickt und danach nur bei Änderung.
        Eine Suche „seit gestern" fände sie nach einem ruhigen Monat nicht mehr.
        """
        async with self.maker() as s:
            row = (
                (
                    await s.execute(
                        select(m.SystemEvent)
                        .where(m.SystemEvent.code == code)
                        .order_by(m.SystemEvent.at.desc())
                        .limit(1)
                    )
                )
                .scalars()
                .first()
            )
        return row

    async def recent_events(self, limit: int = 50) -> list[m.SystemEvent]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.SystemEvent).order_by(m.SystemEvent.at.desc()).limit(limit)
                    )
                )
                .scalars()
                .all()
            )
        return list(rows)

    # ------------------------------------------------------------------ Energiebilanz
    async def upsert_energy_hours(
        self, hours: list[HourlyEnergy], outdoor: dict[datetime, float | None] | None = None
    ) -> None:
        if not hours:
            return
        now = datetime.now(UTC)
        async with self.maker() as s:
            for h in hours:
                data = h.model_dump()
                data["outdoor_temp_c"] = (outdoor or {}).get(h.hour_start)
                data["updated_at"] = now
                row = await s.get(m.EnergyHour, h.hour_start)
                if row is None:
                    s.add(m.EnergyHour(**data))
                else:
                    for k, v in data.items():
                        setattr(row, k, v)
            await s.commit()

    async def energy_hours(
        self, start: datetime, end: datetime
    ) -> list[tuple[HourlyEnergy, float | None]]:
        async with self.maker() as s:
            rows = (
                (
                    await s.execute(
                        select(m.EnergyHour)
                        .where(m.EnergyHour.hour_start >= start, m.EnergyHour.hour_start < end)
                        .order_by(m.EnergyHour.hour_start)
                    )
                )
                .scalars()
                .all()
            )
        out: list[tuple[HourlyEnergy, float | None]] = []
        fields = set(HourlyEnergy.model_fields)
        for r in rows:
            data = {k: getattr(r, k) for k in fields if k != "hour_start"}
            out.append(
                (HourlyEnergy(hour_start=self._aware(r.hour_start), **data), r.outdoor_temp_c)
            )
        return out

    async def first_energy_hour(self) -> datetime | None:
        """Älteste gespeicherte Stundenbilanz.

        Bewusst nicht `first_measurement_at`: die Stundentabelle reicht weiter zurück als jede
        Minutenzeile, weil der Historienimport Stunden direkt geschrieben hat. Wer eine Reparatur der
        Historie bei der ersten Messung beginnen lässt, fasst genau die Monate nicht an, um die es geht.
        """
        async with self.maker() as s:
            v = (await s.execute(select(func.min(m.EnergyHour.hour_start)))).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def last_energy_hour(self) -> datetime | None:
        async with self.maker() as s:
            v = (await s.execute(select(func.max(m.EnergyHour.hour_start)))).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def oldest_raw_at(self) -> datetime | None:
        """Ältester noch vorhandener Rohwert - der Startpunkt einer Verdichtung, die bei null beginnt.

        Bewusst getrennt von `first_measurement_at`: das beantwortet „seit wann zeichnen wir auf" und
        schaut deshalb in die dauerhafte Minutentabelle. Wer damit eine Verdichtung starten wollte,
        begänne vor Jahren statt vor 14 Tagen.
        """
        async with self.maker() as s:
            v = (
                await s.execute(select(func.min(m.MeasurementRaw.observed_at)))
            ).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def first_measurement_at(self) -> datetime | None:
        """Beginn der Aufzeichnung.

        Maßgeblich ist die dauerhafte Minutentabelle, nicht die Rohwerte: die reichen nur 14 Tage
        zurück, und aus ihnen abgeleitet behauptete die Oberfläche auf jeder Berichtsseite, die
        Aufzeichnung habe vor zwei Wochen begonnen. Solange noch nichts verdichtet wurde, gilt der
        älteste Rohwert.
        """
        async with self.maker() as s:
            minute = (
                await s.execute(select(func.min(m.MeasurementMinute.bucket)))
            ).scalar_one_or_none()
            if minute is not None:
                return self._aware(minute)
            v = (
                await s.execute(select(func.min(m.MeasurementRaw.observed_at)))
            ).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def save_calibration(self, model: str, state: dict[str, object]) -> None:
        async with self.maker() as s:
            row = await s.get(m.ModelCalibration, model)
            if row is None:
                s.add(m.ModelCalibration(model=model, updated_at=datetime.now(UTC), state=state))
            else:
                row.state = state
                row.updated_at = datetime.now(UTC)
            await s.commit()

    async def load_calibration(self, model: str) -> dict[str, object] | None:
        async with self.maker() as s:
            row = await s.get(m.ModelCalibration, model)
        return None if row is None else dict(row.state)

    async def active_config(self, kind: str) -> dict[str, object] | None:
        async with self.maker() as s:
            row = (
                await s.execute(
                    select(m.ConfigVersion).where(
                        m.ConfigVersion.kind == kind, m.ConfigVersion.active.is_(True)
                    )
                )
            ).scalar_one_or_none()
        return None if row is None else dict(row.payload)

    async def save_config(
        self,
        kind: str,
        payload: dict[str, object],
        created_by: str = "system",
        comment: str | None = None,
    ) -> UUID:
        async with self.maker() as s:
            await s.execute(
                text("UPDATE config_versions SET active = false WHERE kind = :kind"), {"kind": kind}
            )
            row = m.ConfigVersion(
                created_at=datetime.now(UTC),
                created_by=created_by,
                kind=kind,
                payload=payload,
                comment=comment,
                active=True,
            )
            s.add(row)
            await s.commit()
            return row.id

    # ------------------------------------------------------------------ Bridge-Zugang
    async def bridge_token_valid(self, token_hash: str) -> bool:
        async with self.maker() as s:
            row = (
                await s.execute(
                    select(m.BridgeCredential).where(
                        m.BridgeCredential.token_hash == token_hash,
                        m.BridgeCredential.revoked_at.is_(None),
                    )
                )
            ).scalar_one_or_none()
            if row is None:
                return False
            row.last_seen_at = datetime.now(UTC)
            await s.commit()
            return True

    async def add_bridge_credential(self, name: str, token_hash: str) -> None:
        async with self.maker() as s:
            s.add(
                m.BridgeCredential(name=name, token_hash=token_hash, created_at=datetime.now(UTC))
            )
            await s.commit()

    # ------------------------------------------------------------------ Mitteilungen
    async def push_key(self) -> tuple[str, str] | None:
        """Das gespeicherte VAPID-Paar (privat, öffentlich) oder None, wenn es noch keines gibt."""
        async with self.maker() as s:
            row = await s.get(m.PushKey, 1)
        return None if row is None else (row.private_key, row.public_key)

    async def save_push_key(self, private_key: str, public_key: str) -> None:
        async with self.maker() as s:
            row = await s.get(m.PushKey, 1)
            if row is None:
                s.add(
                    m.PushKey(
                        id=1,
                        private_key=private_key,
                        public_key=public_key,
                        created_at=datetime.now(UTC),
                    )
                )
            else:
                row.private_key = private_key
                row.public_key = public_key
                row.created_at = datetime.now(UTC)
            await s.commit()

    async def add_push_subscription(
        self, endpoint: str, p256dh: str, auth: str, label: str = ""
    ) -> None:
        """Ein Gerät anmelden. Dasselbe Gerät zweimal bleibt ein Gerät: Der Endpunkt ist der Schlüssel."""
        async with self.maker() as s:
            row = await s.get(m.PushSubscription, endpoint)
            if row is None:
                s.add(
                    m.PushSubscription(
                        endpoint=endpoint,
                        p256dh=p256dh,
                        auth=auth,
                        label=label[:64],
                        created_at=datetime.now(UTC),
                        failures=0,
                    )
                )
            else:
                row.p256dh = p256dh
                row.auth = auth
                row.label = label[:64] or row.label
                row.failures = 0
            await s.commit()

    async def push_subscriptions(self) -> list[m.PushSubscription]:
        async with self.maker() as s:
            rows = (await s.execute(select(m.PushSubscription))).scalars().all()
        return list(rows)

    async def drop_push_subscription(self, endpoint: str) -> bool:
        async with self.maker() as s:
            row = await s.get(m.PushSubscription, endpoint)
            if row is None:
                return False
            await s.delete(row)
            await s.commit()
        return True

    async def push_delivered(self, endpoint: str, ok: bool) -> None:
        async with self.maker() as s:
            row = await s.get(m.PushSubscription, endpoint)
            if row is None:
                return
            if ok:
                row.last_ok_at = datetime.now(UTC)
                row.failures = 0
            else:
                row.failures += 1
            await s.commit()

    # ------------------------------------------------------------------ Raumautomatik
    async def room_shift_states(self) -> list[m.RoomShiftState]:
        async with self.maker() as s:
            rows = (await s.execute(select(m.RoomShiftState))).scalars().all()
        return list(rows)

    async def save_room_shift_state(
        self,
        room_id: int,
        base_setpoint_c: float,
        offset_k: float,
        written_setpoint_c: float,
        written_at: datetime,
        phase: str,
        until: datetime | None,
        paused_until: datetime | None,
    ) -> None:
        async with self.maker() as s:
            row = await s.get(m.RoomShiftState, room_id)
            if row is None:
                row = m.RoomShiftState(room_id=room_id, base_setpoint_c=base_setpoint_c)
                s.add(row)
            row.base_setpoint_c = base_setpoint_c
            row.offset_k = offset_k
            row.written_setpoint_c = written_setpoint_c
            row.written_at = written_at
            row.phase = phase
            row.until = until
            row.paused_until = paused_until
            row.updated_at = datetime.now(UTC)
            await s.commit()

    async def drop_room_shift_state(self, room_id: int) -> None:
        async with self.maker() as s:
            row = await s.get(m.RoomShiftState, room_id)
            if row is not None:
                await s.delete(row)
                await s.commit()
