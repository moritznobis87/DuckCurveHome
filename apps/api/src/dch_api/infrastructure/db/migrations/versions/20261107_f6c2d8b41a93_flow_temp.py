"""measurements_minute - die Vorlauftemperatur des Waermepumpenkreises

Die Reihe existiert ab jetzt, der Wert noch nicht. Beides ist Absicht.

Die Vorlauftemperatur ist die Senkentemperatur im COP. Ohne sie bleibt der Wirkungsgrad der
Waermepumpe eine Annahme: die Kennlinie in HeatDemandConfig rechnet allein ueber die
Aussentemperatur, und `thermal/heat_balance.py` kann ihre Carnot-Skalierung nicht nutzen, weil ihm
die Senke fehlt. Liefert eine Quelle sie - die noch nicht zugeordnete Entitaet aus Home Assistant
oder der eBUS-Adapter -, landet sie damit vom ersten Wert an dauerhaft in der Minutentabelle,
statt dass die Spalte erst dann angelegt wird und die ersten Tage fehlen.

Kein Vorbelegungswert. Bestehende Zeilen bleiben NULL, und neue bleiben es, solange niemand
liefert. Ein NaN in der Spalte waere die naheliegende Alternative, aber es ist in JSON nicht
darstellbar und wuerde jedes Minutenmittel und jede Stundenbilanz vergiften, in die es einmal
eingeht. Die Aussage ist dieselbe, und die Anzeige trifft sie ohnehin im Klartext: auf der
Anlagenseite steht "Vorlauf ?", solange nichts da ist.

Revision ID: f6c2d8b41a93
Revises: e5b1c7a93f24
Create Date: 2026-11-07 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f6c2d8b41a93"
down_revision = "e5b1c7a93f24"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("measurements_minute", sa.Column("flow_temp_c", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("measurements_minute", "flow_temp_c")
