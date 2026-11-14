"""measurements_minute - was der Regler der Waermepumpe vorgibt

Aus dem Protokoll des Hauses vom 14.11.2026, 16:41 (Start in den Heizbetrieb). Fuenf Groessen,
die der Bus von selbst sendet:

- `heat_pump_heat_request`: Heizanforderung der ersten Zone, 1 an, 0 aus.
- `heat_pump_room_setpoint_c`: ihr Raum-Sollwert (22,0 am Tag, 10,0 in der Nacht).
- `heat_pump_flag_1b45`: die Kennung 1b45. Bedeutung offen; sie liegt neben der des
  elektrischen Heizstabs (1c45) und stand nachts auf 0, am Nachmittag auf 1.
- `heat_pump_cmd_mode_code`, `heat_pump_cmd_target_c`: Vorgaben des Reglers an die Maschine
  (Kennungen cd46 und 6a47). cd46 wechselte beim Start von 0 auf 3, 6a47 von 60,0 auf 55,0;
  was 6a47 bedeutet, ist offen.

Gespeichert werden auch die nicht entschluesselten, damit sich ihre Bedeutung aus dem Verlauf
ablesen laesst (docs/SENSORIK.md).

Revision ID: e1b7c3a96f5c
Revises: d0a6b2f85e4b
Create Date: 2026-11-14 16:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e1b7c3a96f5c"
down_revision = "d0a6b2f85e4b"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_heat_request",
    "heat_pump_room_setpoint_c",
    "heat_pump_flag_1b45",
    "heat_pump_cmd_mode_code",
    "heat_pump_cmd_target_c",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
