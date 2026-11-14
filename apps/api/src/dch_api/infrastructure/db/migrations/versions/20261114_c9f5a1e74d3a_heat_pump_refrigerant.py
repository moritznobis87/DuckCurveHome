"""measurements_minute - Kaeltekreis und Speicherfuehler der Waermepumpe

Fuer die Technikseite der Waermepumpe (Nutzerwunsch 14.11.2026: Aussen- und Inneneinheit mit
allen Messungen an ihrer Stelle). Fuenf Groessen, die der Bus meldet und die bisher nur im
Protokoll des Add-ons standen:

- `heat_pump_evaporator_temp_c`: Verdampfer am Aussengeraet.
- `heat_pump_suction_temp_c`, `heat_pump_discharge_temp_c`: Sauggas vor und Heissgas nach dem
  Verdichter.
- `heat_pump_liquid_temp_c`: die Fluessigkeitsleitung zurueck zum Aussengeraet.
- `heat_pump_tank_temp_c`: ein Fuehler des Reglers (Kennung 759e), der sich wie ein
  Speicherfuehler verhaelt. Die Lesart ist nicht bestaetigt; siehe docs/SENSORIK.md.

Revision ID: c9f5a1e74d3a
Revises: b8e4f0d63c29
Create Date: 2026-11-14 01:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c9f5a1e74d3a"
down_revision = "b8e4f0d63c29"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_evaporator_temp_c",
    "heat_pump_suction_temp_c",
    "heat_pump_discharge_temp_c",
    "heat_pump_liquid_temp_c",
    "heat_pump_tank_temp_c",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
