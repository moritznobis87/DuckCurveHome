"""measurements_minute - Betriebsart des Reglers der Waermepumpe

Der Regler sendet seine Betriebsart im Rundruf (Kennung c94b): 0 Bereitschaft, 2 Heizen,
3 Warmwasser, 16 PV-Nutzung. Aus ihr folgt, wohin die Waermepumpe in den Speicher einspeist:
bei Warmwasser oben, im Heizbetrieb tiefer (Auskunft des Hausherrn, 14.11.2026). Die Spalte
haelt sie fest, damit die Kennlinie spaeter nach Betriebsart getrennt werden kann.

Als Zahl gespeichert wie der Betriebszustand der Maschine; das Minutenmittel ist nur dort eine
Betriebsart, wo sie in der Minute nicht gewechselt hat.

Revision ID: d0a6b2f85e4b
Revises: c9f5a1e74d3a
Create Date: 2026-11-14 10:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "d0a6b2f85e4b"
down_revision = "c9f5a1e74d3a"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "measurements_minute", sa.Column("heat_pump_cycle_code", sa.Float(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("measurements_minute", "heat_pump_cycle_code")
