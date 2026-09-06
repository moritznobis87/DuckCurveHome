"""Repositories – die einzige Stelle mit SQL. Der Demo-Modus nutzt In-Memory-Varianten."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import UTC, datetime, timedelta
from typing import Any, cast
from uuid import UUID

from sqlalchemy import CursorResult, delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker
from sqlalchemy.sql import Executable

from dch_api.infrastructure.db import models as m
from hems_core.accounting import HourlyEnergy
from hems_core.domain import Decision, OperatingMode, Quality
from hems_core.protocol import RawReading

QUALITY_CODE = {q: i for i, q in enumerate(Quality)}
CODE_QUALITY = {i: q for q, i in QUALITY_CODE.items()}

Row = dict[str, Any]


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
        """Minutenmittel direkt aus Rohwerten; ein Aggregationsjob füllt später die 1-min-Tabelle."""
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
            .where(m.MeasurementRaw.sensor_key.in_(keys), m.MeasurementRaw.quality.in_([0, 4]))
            .group_by("bucket", m.MeasurementRaw.sensor_key)
            .order_by("bucket")
        )
        async with self.maker() as s:
            rows = (await s.execute(stmt)).all()
        by_bucket: dict[str, dict[str, float | str | None]] = {}
        for b, key, avg in rows:
            ts = (
                self._aware(b).astimezone(UTC).isoformat().replace("+00:00", "Z")
                if isinstance(b, datetime)
                else str(b).replace("+00:00", "Z")
            )
            row = by_bucket.setdefault(ts, {"ts": ts})
            row[key] = None if avg is None else round(float(avg), 3)
        out = list(by_bucket.values())
        for row in out:
            for k in keys:
                row.setdefault(k, None)
        return out

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
        self, severity: str, code: str, message: str, context: Mapping[str, object] | None = None
    ) -> None:
        async with self.maker() as s:
            s.add(
                m.SystemEvent(
                    at=datetime.now(UTC),
                    severity=severity,
                    code=code,
                    message=message,
                    context=dict(context or {}),
                )
            )
            await s.commit()

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

    async def last_energy_hour(self) -> datetime | None:
        async with self.maker() as s:
            v = (await s.execute(select(func.max(m.EnergyHour.hour_start)))).scalar_one_or_none()
        return None if v is None else self._aware(v)

    async def first_measurement_at(self) -> datetime | None:
        async with self.maker() as s:
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
