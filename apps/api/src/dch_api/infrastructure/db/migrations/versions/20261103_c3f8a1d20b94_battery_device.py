"""energy_hourly - Eigenverbrauch des Speichergeräts als eigene Zeilen

Der Stromwandler des Libbi sitzt auf der Wechselstromseite und sieht alles, was in das Gerät
fließt, auch das, was die Zellen nie erreicht. Als Ladung gebucht blähte es die geladene Menge auf,
nachts als Netzladung, und drückte den Umlauf, weil es nie wieder herauskam. Diese Spalten trennen
es heraus und bepreisen es wie jeden anderen Verbraucher: Netzanteil zum Bezugspreis, PV-Anteil zur
entgangenen Einspeisevergütung.

Bestehende Zeilen bekommen 0,0. Richtig gefüllt werden sie nicht hier, sondern von der
Neuberechnung aus den Minutenwerten (`energy.rebuild_device_v8`); nur Stunden ohne Minutenwerte
bleiben bei 0, und dort fehlt die Grundlage für den Abzug ohnehin.

Revision ID: c3f8a1d20b94
Revises: b2e5f9a14c77
Create Date: 2026-11-03 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c3f8a1d20b94"
down_revision = "b2e5f9a14c77"
branch_labels = None
depends_on = None

SPALTEN = (
    "battery_device_kwh",
    "battery_device_pv_kwh",
    "battery_device_grid_kwh",
    "battery_device_cost_eur",
    "battery_device_opportunity_eur",
)


def upgrade() -> None:
    for name in SPALTEN:
        op.add_column(
            "energy_hourly", sa.Column(name, sa.Float(), nullable=False, server_default="0")
        )


def downgrade() -> None:
    for name in reversed(SPALTEN):
        op.drop_column("energy_hourly", name)
