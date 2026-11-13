"""measurements_minute - Verdichterfrequenz und Betriebszustand der Waermepumpe

Beide stehen im selben Telegramm des Busses (Kennungen cb46 und ca46), das erst im dritten
Protokoll des Hauses auffiel (14.11.2026, 00:06):

- `heat_pump_compressor_hz`: die Verdichterfrequenz. Sie sagt, wie weit die Maschine moduliert,
  und ist damit die Groesse, an der sich Teillast von Takten unterscheiden laesst.
- `heat_pump_mode_code`: der Betriebszustand als Zahl der Maschine. 3 heizt, 9 taut ab, 15
  steht (in der fremden Liste heisst 15 "Soft_fail", an dieser Anlage ist es der Stillstand).
  Als Zahl und nicht als Wort, weil die Minutentabelle Zahlen haelt; ein Minutenmittel ist bei
  einem Zustand nur dann der Zustand, wenn er sich in der Minute nicht aendert. Abtauen ist
  damit zum ersten Mal ueberhaupt sichtbar.

Eine eigene Migration und nicht ein Nachtrag zu a7d3e9c52b18: die ist schon ausgeliefert.

Revision ID: b8e4f0d63c29
Revises: a7d3e9c52b18
Create Date: 2026-11-14 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "b8e4f0d63c29"
down_revision = "a7d3e9c52b18"
branch_labels = None
depends_on = None

SPALTEN = ("heat_pump_compressor_hz", "heat_pump_mode_code")


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
