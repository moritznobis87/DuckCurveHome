"""geraet_messwerte - der Verlauf des Hausgeraets (Seite Technik -> Hausgeraet)

Alle fuenf Minuten ein Punkt aus dem Bericht des Geraets: CPU, Temperatur, Spannung, Speicher,
Platz, SSD, Netz, Datenbank, Sicherungen und je Dienst CPU und Speicher. Fuenf-Minuten-Punkte
bleiben 30 Tage, stuendliche zwei Jahre (models.GeraetMesswert).

Revision ID: c5f1a7e30d9a
Revises: b4e0f6d29c8f
Create Date: 2026-11-20 12:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c5f1a7e30d9a"
down_revision = "b4e0f6d29c8f"
branch_labels = None
depends_on = None

ZAHLEN = (
    "cpu_prozent",
    "last1",
    "temperatur_c",
    "takt_mhz",
    "eingangsspannung_v",
    "speicher_belegt_mb",
    "speicher_gesamt_mb",
    "swap_belegt_mb",
    "ssd_temperatur_c",
    "ssd_abnutzung_prozent",
)
GROSSE_ZAHLEN = (
    "platte_belegt_bytes",
    "platte_gesamt_bytes",
    "ssd_geschrieben_bytes",
    "netz_empfangen_bytes",
    "netz_gesendet_bytes",
    "datenbank_bytes",
    "sicherung_bytes",
    "docker_bytes",
)


def upgrade() -> None:
    op.create_table(
        "geraet_messwerte",
        sa.Column("ts", sa.DateTime(timezone=True), primary_key=True),
        sa.Column("stuendlich", sa.Boolean(), nullable=False, server_default=sa.false()),
        *(sa.Column(name, sa.Float(), nullable=True) for name in ZAHLEN),
        sa.Column("drosselung", sa.Integer(), nullable=True),
        *(sa.Column(name, sa.BigInteger(), nullable=True) for name in GROSSE_ZAHLEN),
        sa.Column(
            "dienste", sa.JSON().with_variant(postgresql.JSONB(), "postgresql"), nullable=True
        ),
    )


def downgrade() -> None:
    op.drop_table("geraet_messwerte")
