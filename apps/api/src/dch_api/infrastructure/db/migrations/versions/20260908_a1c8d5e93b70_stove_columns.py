"""measurements_minute - eigene Spalten für den Pelletofen

Die Ofengrößen landeten bisher in `extra`, weil beim Bau der Quelle noch nicht feststand, welche
Felder die Firmware dieses Geräts überhaupt füllt. Inzwischen ist klar, dass die Feldliste vom
Protokoll vorgegeben ist und nicht vom Gerät: was diese Firmware nicht kennt, bleibt schlicht leer.

Deshalb bekommen alle vierzehn Größen eine eigene Spalte, auch die, die hier womöglich nie belegt
werden. Eine leere Spalte kostet in Postgres ein Bit in der NULL-Maske. Ein JSON-Feld je Minute
kostet über zehn Jahre ein Vielfaches davon, und eine zweite Migration später kostet Stillstand.

Bestehende Zeilen bleiben leer. Was vor dieser Migration in `extra` gelandet ist, bleibt dort und
geht nicht verloren.

Revision ID: a1c8d5e93b70
Revises: f7a2b9c40e13
Create Date: 2026-09-08 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a1c8d5e93b70"
down_revision = "f7a2b9c40e13"
branch_labels = None
depends_on = None

_STOVE_COLUMNS = (
    "stove_state",  # Zustandscode der Maestro-Firmware
    "stove_running",  # abgeleitet: erzeugt er gerade Wärme
    "stove_power_level",  # Leistungsstufe 1 bis 5
    "stove_fume_temp_c",  # Rauchgastemperatur, der ehrlichste Betriebsindikator
    "stove_fume_fan_rpm",  # Rauchgasgebläse
    "stove_auger_rpm",  # Förderschnecke: der Brennstoffeintrag
    "stove_boiler_temp_c",  # Vorlauf des Ofenkreises
    "stove_return_temp_c",  # Rücklauf des Ofenkreises
    "stove_buffer_temp_c",  # eigener Pufferfühler des Ofens
    "stove_ambient_temp_c",  # Raumfühler des Ofens
    "stove_pump_pct",  # Modulation der Ofenpumpe
    "stove_dhw_mode",  # Dreiwegeventil: 1 = Warmwasser
    "stove_operating_hours",  # Betriebsstundenzähler, monoton
    "stove_ignitions",  # Zündungszähler, monoton
)


def upgrade() -> None:
    op.add_column("measurements_minute", sa.Column("stove_state", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_running", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_power_level", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_fume_temp_c", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_fume_fan_rpm", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_auger_rpm", sa.Float(), nullable=True))
    op.add_column(
        "measurements_minute", sa.Column("stove_boiler_temp_c", sa.Float(), nullable=True)
    )
    op.add_column(
        "measurements_minute", sa.Column("stove_return_temp_c", sa.Float(), nullable=True)
    )
    op.add_column(
        "measurements_minute", sa.Column("stove_buffer_temp_c", sa.Float(), nullable=True)
    )
    op.add_column(
        "measurements_minute", sa.Column("stove_ambient_temp_c", sa.Float(), nullable=True)
    )
    op.add_column("measurements_minute", sa.Column("stove_pump_pct", sa.Float(), nullable=True))
    op.add_column("measurements_minute", sa.Column("stove_dhw_mode", sa.Float(), nullable=True))
    op.add_column(
        "measurements_minute", sa.Column("stove_operating_hours", sa.Float(), nullable=True)
    )
    op.add_column("measurements_minute", sa.Column("stove_ignitions", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("measurements_minute", "stove_ignitions")
    op.drop_column("measurements_minute", "stove_operating_hours")
    op.drop_column("measurements_minute", "stove_dhw_mode")
    op.drop_column("measurements_minute", "stove_pump_pct")
    op.drop_column("measurements_minute", "stove_ambient_temp_c")
    op.drop_column("measurements_minute", "stove_buffer_temp_c")
    op.drop_column("measurements_minute", "stove_return_temp_c")
    op.drop_column("measurements_minute", "stove_boiler_temp_c")
    op.drop_column("measurements_minute", "stove_auger_rpm")
    op.drop_column("measurements_minute", "stove_fume_fan_rpm")
    op.drop_column("measurements_minute", "stove_fume_temp_c")
    op.drop_column("measurements_minute", "stove_power_level")
    op.drop_column("measurements_minute", "stove_running")
    op.drop_column("measurements_minute", "stove_state")
