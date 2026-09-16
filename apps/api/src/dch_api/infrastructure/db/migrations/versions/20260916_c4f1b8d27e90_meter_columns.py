"""measurements_minute - eigene Spalten für den amtlichen Zähler

Der neue Smartmeter von inexogy liefert dieselbe Größe wie der Stromwandler des Speichers: die
Leistung am Netzanschluss. Führend bleibt vorerst der Wandler. Der Zähler läuft als zweite,
unabhängige Beobachtung mit, damit sich zuerst beantworten lässt, wie stabil er überträgt, und
danach, wie weit die beiden auseinanderliegen.

Genau deshalb eine eigene Spalte statt derselben: würde der Zählerwert nach `grid_power_kw`
laufen, verglichen wir ihn später mit sich selbst, und die Frage wäre nicht mehr zu stellen.

Dazu die beiden Zählerstände. Sie sind für den Vergleich die wichtigeren Zahlen: die beiden Geräte
messen nicht im selben Augenblick, eine mittlere Differenz je Minute misst also vor allem den
Versatz. Über eine Stunde oder einen Tag hebt er sich auf, und die Differenz zweier Zählerstände
ist die ehrlichste Form dieser Summe, weil sie keinerlei Integration von uns enthält.

Bestehende Zeilen bleiben leer.

Revision ID: c4f1b8d27e90
Revises: b2e7f4a10c65
Create Date: 2026-09-16 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c4f1b8d27e90"
down_revision = "b2e7f4a10c65"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "measurements_minute", sa.Column("grid_power_meter_kw", sa.Float(), nullable=True)
    )
    op.add_column(
        "measurements_minute", sa.Column("grid_import_meter_kwh", sa.Float(), nullable=True)
    )
    op.add_column(
        "measurements_minute", sa.Column("grid_export_meter_kwh", sa.Float(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("measurements_minute", "grid_export_meter_kwh")
    op.drop_column("measurements_minute", "grid_import_meter_kwh")
    op.drop_column("measurements_minute", "grid_power_meter_kw")
