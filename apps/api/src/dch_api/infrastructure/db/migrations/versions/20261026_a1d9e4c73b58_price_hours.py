"""energy_hourly.price_hours_ct - der Preis einer Stunde, auch ohne Netzbezug

`price_weighted_ct` ist die Summe aus Bezug mal Preis. Daraus laesst sich der Mittelpreis des
bezogenen Stroms rechnen, aber nicht der Preis einer Stunde, in der nichts bezogen wurde - und
genau den braucht der Vergleichslauf: Ohne Preisblick waere in einer Mittagsstunde voller Sonne
vielleicht Bezug angefallen, und der haette etwas gekostet.

Die neue Spalte ist die Summe aus Preis mal Stunden. Geteilt durch die bewerteten Stunden ergibt
sie den zeitlichen Mittelpreis; fuer eine volle Stunde ist das genau ihr Preis.

Alte Zeilen stehen auf null. Sie fuellt der einmalige Neuaufbau der Stundenbilanzen
(`energy.rebuild_*` in der Laufzeit), der aus den Minutenwerten neu rechnet.

Revision ID: a1d9e4c73b58
Revises: f7c4d1b86a20
Create Date: 2026-10-26 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a1d9e4c73b58"
down_revision = "f7c4d1b86a20"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "energy_hourly",
        sa.Column("price_hours_ct", sa.Float(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("energy_hourly", "price_hours_ct")
