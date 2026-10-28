"""room_shift_states - die Rueckfahrkarte der Automatik

Hebt die Automatik den Sollwert eines Raums vor einem Preishoch an, muss sie wissen, worauf sie
ihn zurueckstellt. Dieses Wissen darf einen Neustart nicht ueberleben muessen, sondern einen
Absturz: Ohne die Zeile bliebe ein Raum fuer immer einen halben Grad zu warm, und niemand wuesste,
warum.

Geschrieben wird sie deshalb vor dem Stellen, nicht danach.

Revision ID: b2e5f9a14c77
Revises: a1d9e4c73b58
Create Date: 2026-10-28 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "b2e5f9a14c77"
down_revision = "a1d9e4c73b58"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "room_shift_states",
        sa.Column("room_id", sa.Integer(), primary_key=True),
        sa.Column("base_setpoint_c", sa.Float(), nullable=False),
        sa.Column("offset_k", sa.Float(), nullable=False, server_default="0"),
        sa.Column("written_setpoint_c", sa.Float(), nullable=False),
        sa.Column("written_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("phase", sa.String(length=16), nullable=False, server_default="aus"),
        sa.Column("until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paused_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("room_shift_states")
