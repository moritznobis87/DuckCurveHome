"""energy_hourly - Minuten aus grober Eingangsauflösung getrennt zählen

Stunden, die der Historienimport aus Stundenmitteln gebildet hat, tragen richtige Summen, aber eine
geschätzte Aufteilung auf PV, Speicher und Netz: in einem Stundenmittel löschen sich der PV-Überschuss
der Sonnenminuten und der Netzbezug der Wolkenminuten gegenseitig aus, und die Differenz erscheint als
Netzladung des Speichers. Die Spalte hält fest, wie viele Minuten einer Stunde so entstanden sind,
damit eine Jahresansicht nicht zwei Rechnungsarten mischt, ohne dass man es ihr ansieht.

Bestehende Zeilen bekommen 0. Der Wert wird beim nächsten Neurechnen gesetzt.

Revision ID: b2e7f4a10c65
Revises: a1c8d5e93b70
Create Date: 2026-09-08 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "b2e7f4a10c65"
down_revision = "a1c8d5e93b70"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "energy_hourly",
        sa.Column("coarse_minutes", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("energy_hourly", "coarse_minutes")
