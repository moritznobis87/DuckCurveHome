"""energy_hourly - Eigenverbrauch, Herkunft der Speicherentladung, Wiederbeschaffungswert

Fünf Spalten für die steuerliche Auswertung der PV. Vier davon sind Summanden wie die übrigen Energien
und Beträge; battery_pv_stored_kwh und battery_grid_stored_kwh sind ein Bestand am Stundenende und
dürfen nicht aufsummiert werden - sie stehen hier, damit eine Neuberechnung das Herkunftskonto des
Speichers dort fortsetzen kann, wo die vorige Rechnung es verlassen hat.

Bestehende Zeilen bekommen 0,0. Sie sind damit nicht falsch, sondern unbewertet: für Zeiträume vor
dieser Migration weist die Abrechnungsseite keinen Eigenverbrauch aus, solange die Stunden nicht aus
den Minutenwerten neu gerechnet wurden (die Rohwerte reichen 14 Tage zurück).

Revision ID: c3d9e1a75b24
Revises: b6c1f4e28a37
Create Date: 2026-09-07 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c3d9e1a75b24"
down_revision = "b6c1f4e28a37"
branch_labels = None
depends_on = None

_COLUMNS = (
    "battery_pv_to_house_kwh",
    "battery_origin_estimated_kwh",
    "self_consumption_value_eur",
    "battery_pv_stored_kwh",
    "battery_grid_stored_kwh",
)


def upgrade() -> None:
    for name in _COLUMNS:
        op.add_column(
            "energy_hourly",
            sa.Column(name, sa.Float(), nullable=False, server_default="0"),
        )


def downgrade() -> None:
    for name in _COLUMNS:
        op.drop_column("energy_hourly", name)
