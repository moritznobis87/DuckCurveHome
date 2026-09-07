"""energy_hourly - Netzladung der Batterie bei Dunkelheit getrennt zählen

Die Spalte trennt zwei Ursachen, die in `grid_to_battery_kwh` bisher zusammenfielen: Netzladung in
Minuten ganz ohne PV-Leistung ist eine echte Entscheidung des Speichers, Netzladung bei Sonne fast
immer ein Messartefakt aus drei Quellen mit eigenen Abtastzeitpunkten.

Bestehende Zeilen bekommen 0,0. Für sie lässt sich die Unterscheidung nicht nachträglich treffen,
solange keine Minutenwerte mehr vorliegen.

Revision ID: f7a2b9c40e13
Revises: e5f2a8c31d47
Create Date: 2026-09-07 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f7a2b9c40e13"
down_revision = "e5f2a8c31d47"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "energy_hourly",
        sa.Column("grid_to_battery_dark_kwh", sa.Float(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("energy_hourly", "grid_to_battery_dark_kwh")
