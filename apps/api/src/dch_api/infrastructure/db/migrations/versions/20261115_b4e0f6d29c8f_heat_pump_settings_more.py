"""measurements_minute - zehn weitere Einstellungen des Reglers

Mit dem eBUS-Add-on 0.5.0 liest die Bridge zehn weitere Einstellungen (Einfluss der
Raumtemperatur, Temperaturbereich, Korrektur des Vorlaufs, Legionellenprogramm, Zuschlag bei
Sonnenstrom, Heizbetrieb Green oder Standard, Komfortstufe, Umwaelzpumpe, Abschaltgrenze,
Sommerbetrieb). Einige davon lassen sich ab derselben Fassung von der Seite "Regler" stellen; der
Verlauf hier ist der Beleg, wann welche Einstellung galt.

Revision ID: b4e0f6d29c8f
Revises: a3d9e5c18b7e
Create Date: 2026-11-15 16:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "b4e0f6d29c8f"
down_revision = "a3d9e5c18b7e"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_set_room_influence",
    "heat_pump_set_temp_range",
    "heat_pump_set_flow_correction_k",
    "heat_pump_set_dhw_cleansing",
    "heat_pump_set_dhw_pv_delta_k",
    "heat_pump_set_heat_mode",
    "heat_pump_set_comfort_level",
    "heat_pump_set_pump_mode",
    "heat_pump_set_disable_below_c",
    "heat_pump_set_summer_above_c",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
