"""measurements_minute - die Einstellungen des Reglers der Waermepumpe

Zwoelf Einstellungen, die das eBUS-Add-on ab 0.4.0 liest (Heizkurve, Raumtemperaturen,
Warmwasser, Fluestermodus). Sie aendern sich selten; gespeichert werden sie trotzdem, damit
sich spaeter sagen laesst, wann eine Einstellung wie stand. Das wird wichtig, sobald eine von
ihnen von hier aus verstellt werden kann: der Verlauf ist dann der Beleg, was vorher galt.

Kennungen aus der Bus-Beschreibung einer verwandten Anlage, im Haus noch nicht bestaetigt
(docs/SENSORIK.md, "Die Einstellungen des Reglers, gelesen").

Revision ID: a3d9e5c18b7e
Revises: f2c8d4b07a6d
Create Date: 2026-11-15 12:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a3d9e5c18b7e"
down_revision = "f2c8d4b07a6d"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_set_slope",
    "heat_pump_set_offset_k",
    "heat_pump_set_flow_max_c",
    "heat_pump_set_flow_min_c",
    "heat_pump_set_flow_fixed_c",
    "heat_pump_set_curve_type",
    "heat_pump_set_room_day_c",
    "heat_pump_set_room_night_c",
    "heat_pump_set_dhw_comfort_c",
    "heat_pump_set_dhw_eco_c",
    "heat_pump_set_dhw_mode",
    "heat_pump_set_silent",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
