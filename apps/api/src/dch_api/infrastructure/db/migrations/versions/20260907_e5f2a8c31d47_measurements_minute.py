"""measurements_minute – dauerhaftes Minutengedächtnis, breit statt schmal

Bisher gab es unterhalb der Stunde nur die Rohwerte, und die werden nach 14 Tagen gelöscht: ein Blick
in einen Tag vor zwei Jahren zeigte nichts Feineres als ein Stundenmittel. Diese Tabelle hält die
Minutenmittel dauerhaft.

Eine Zeile je Minute mit einer Spalte je Reihe, nicht eine Zeile je Messwert. Der Zeilenkopf von
Postgres (rund 27 Byte) fällt damit einmal für fünfzehn Werte an statt fünfzehnmal — ungefähr 1 GB
statt 9 GB in zehn Jahren. Deshalb ist Minutenauflösung dauerhaft tragbar und die sonst übliche
Verdichtung auf Viertelstunden unnötig.

measurements_1min entfällt: die Tabelle stand seit dem Grundschema da, wurde nie beschrieben und nie
gelesen (die Minutenmittel entstanden bei jeder Abfrage neu aus den Rohwerten). Sie ist leer; ihr
Wegfall verliert nichts.

Revision ID: e5f2a8c31d47
Revises: c3d9e1a75b24
Create Date: 2026-09-07 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "e5f2a8c31d47"
down_revision = "c3d9e1a75b24"
branch_labels = None
depends_on = None

_SERIES = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "battery_soc",
    "house_power_kw",
    "base_load_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
    "hp_release_contact",
)
_JSON = sa.JSON().with_variant(JSONB(), "postgresql")


def upgrade() -> None:
    op.create_table(
        "measurements_minute",
        sa.Column("bucket", sa.DateTime(timezone=True), nullable=False),
        *[sa.Column(name, sa.Float(), nullable=True) for name in _SERIES],
        sa.Column("extra", _JSON, nullable=True),
        sa.PrimaryKeyConstraint("bucket"),
    )
    op.drop_table("measurements_1min")


def downgrade() -> None:
    op.create_table(
        "measurements_1min",
        sa.Column("sensor_key", sa.String(length=64), nullable=False),
        sa.Column("bucket", sa.DateTime(timezone=True), nullable=False),
        sa.Column("avg", sa.Float(), nullable=True),
        sa.Column("min", sa.Float(), nullable=True),
        sa.Column("max", sa.Float(), nullable=True),
        sa.Column("samples", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("sensor_key", "bucket"),
    )
    op.drop_table("measurements_minute")
