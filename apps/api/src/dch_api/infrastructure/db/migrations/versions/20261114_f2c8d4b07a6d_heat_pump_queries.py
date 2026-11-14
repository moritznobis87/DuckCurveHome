"""measurements_minute - was das eBUS-Add-on selbst abfragt

Vier Groessen, die nie von selbst ueber den Bus gehen und die das Add-on ab 0.3.0 abfragt
(Entscheidung des Hausherrn vom 14.11.2026):

- `heat_pump_valve_code`: Stellung des Umschaltventils (Kennung 0601). Laut Bus-Beschreibung
  0 Warmwasser, 1 Heizung; im Haus noch nicht gegengeprueft.
- `heat_pump_heater_code`: elektrische Zusatzheizung (Kennung 1c45), laut Bus-Beschreibung
  0 aus, 1 an.
- `heat_pump_compressor_a`: Strom des Verdichters in Ampere (Kennung 714f).
- `heat_pump_fan_speed`: Drehzahl des Luefters (Kennung 6e4f), Einheit nicht belegt.

Gespeichert als Zahlen: was sie in diesem Haus bedeuten, zeigt der Verlauf neben Speicher und
Zaehler (docs/SENSORIK.md, "Was das Add-on selbst abfragt").

Revision ID: f2c8d4b07a6d
Revises: e1b7c3a96f5c
Create Date: 2026-11-14 22:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f2c8d4b07a6d"
down_revision = "e1b7c3a96f5c"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_valve_code",
    "heat_pump_heater_code",
    "heat_pump_compressor_a",
    "heat_pump_fan_speed",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
