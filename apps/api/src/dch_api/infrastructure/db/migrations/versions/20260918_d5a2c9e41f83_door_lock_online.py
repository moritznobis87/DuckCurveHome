"""measurements_minute - Erreichbarkeit des Türschlosses

Der Verdacht lautet: die Strecke von Home Assistant über den Border Router zum Schloss ist
unzuverlässig, und daran scheitert die Türöffnung. Das ist eine Vermutung, und Vermutungen über
Verfügbarkeit lassen sich messen. Die Bridge fragt den Zustand der Schloss-Entität im Minutentakt
ab und schreibt 1 oder 0; die Verfügbarkeitskarte zeigt daraus dasselbe Bild wie für den Zähler.

Keine Energiegröße, aber dieselbe Frage und damit dieselbe Tabelle: kommt an, was ankommen soll.

Revision ID: d5a2c9e41f83
Revises: c4f1b8d27e90
Create Date: 2026-09-18 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "d5a2c9e41f83"
down_revision = "c4f1b8d27e90"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("measurements_minute", sa.Column("door_lock_online", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("measurements_minute", "door_lock_online")
