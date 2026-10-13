"""heat_hours - die Eingangsgroessen der Waermebilanz je Stunde

Die Waermeseite wird gerechnet, nicht gemessen: es gibt keinen Waermemengenzaehler. Fuer einen Tag
laesst sich das aus Minutenwerten tun, fuer ein Jahr nicht - das waeren 525 000 Zeilen fuer zwoelf
Balken.

Gespeichert werden deshalb **Eingaenge** je Stunde und keine Ergebnisse: Strom der Waermepumpe,
Temperaturen, Ofenminuten. Was das Modell daraus macht, entsteht beim Lesen. Der Unterschied
entscheidet, ob eine geaenderte Annahme die Vergangenheit erreicht - wer den Wirkungsgrad oder die
Arbeitszahl auf der Einstellungsseite dreht, will die Jahreszahlen mit den neuen Werten sehen und
nicht mit denen von damals. Ergebnisse einzufrieren hiesse, jede Korrektur nur noch nach vorn wirken
zu lassen, und niemand wuerde es merken.

Revision ID: e6b3f0a52d41
Revises: d5a2c9e41f83
Create Date: 2026-10-13 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e6b3f0a52d41"
down_revision = "d5a2c9e41f83"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "heat_hours",
        sa.Column("hour_start", sa.DateTime(timezone=True), primary_key=True),
        sa.Column("minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("electric_kwh", sa.Float(), nullable=False, server_default="0"),
        sa.Column("outdoor_c", sa.Float(), nullable=True),
        sa.Column("buffer_top_c", sa.Float(), nullable=True),
        sa.Column("buffer_mean_c", sa.Float(), nullable=True),
        sa.Column("room_c", sa.Float(), nullable=True),
        sa.Column("buffer_kwh_end", sa.Float(), nullable=True),
        sa.Column("stove_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("stove_level_mean", sa.Float(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("heat_hours")
