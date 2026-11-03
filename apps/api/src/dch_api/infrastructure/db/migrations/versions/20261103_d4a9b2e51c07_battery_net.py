"""energy_hourly - was der Speicher gebracht und was er gekostet hat, getrennt

Bisher stand nur `battery_savings_eur` da: die Entladung ins Haus mal der Spanne zwischen
Bezugspreis und Einspeisevergütung. Was in den Speicher hineinging und nie wieder herauskam, stand
nirgends - ein Speicher mit 25 % Verlust sah damit aus wie einer ohne Verlust.

Die beiden Spalten schließen den Kreis: der vermiedene Bezug auf der einen Seite, die Kosten des
Füllens auf der anderen. Ihre Differenz ist der Nutzen, und sie enthält die Verluste von selbst.

Bestehende Zeilen bekommen 0,0; gefüllt werden sie von der Neuberechnung aus den Minutenwerten
(`energy.rebuild_device_v9`).

Revision ID: d4a9b2e51c07
Revises: c3f8a1d20b94
Create Date: 2026-11-03 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "d4a9b2e51c07"
down_revision = "c3f8a1d20b94"
branch_labels = None
depends_on = None

SPALTEN = ("battery_discharge_value_eur", "battery_charge_cost_eur")


def upgrade() -> None:
    for name in SPALTEN:
        op.add_column(
            "energy_hourly", sa.Column(name, sa.Float(), nullable=False, server_default="0")
        )


def downgrade() -> None:
    for name in reversed(SPALTEN):
        op.drop_column("energy_hourly", name)
