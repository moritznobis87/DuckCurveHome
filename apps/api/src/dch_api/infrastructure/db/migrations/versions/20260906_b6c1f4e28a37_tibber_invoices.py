"""tibber_invoices – geprüfte Tibber-Rechnungen mit Befunden

Revision ID: b6c1f4e28a37
Revises: a4b8c2d1e9f0
Create Date: 2026-09-06 12:50:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "b6c1f4e28a37"
down_revision = "a4b8c2d1e9f0"
branch_labels = None
depends_on = None

JsonType = sa.JSON().with_variant(JSONB(), "postgresql")


def upgrade() -> None:
    op.create_table(
        "tibber_invoices",
        sa.Column("number", sa.String(length=32), nullable=False),
        sa.Column("issued_on", sa.Date(), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("period_label", sa.String(length=32), nullable=False),
        sa.Column("kwh", sa.Float(), nullable=False),
        sa.Column("total_net_eur", sa.Float(), nullable=False),
        sa.Column("total_gross_eur", sa.Float(), nullable=False),
        sa.Column("avg_ct_kwh_gross", sa.Float(), nullable=False),
        sa.Column("verdict", sa.String(length=16), nullable=False),
        sa.Column("invoice", JsonType, nullable=False),
        sa.Column("findings", JsonType, nullable=False),
        sa.Column("file_sha256", sa.String(length=64), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=True),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("checked_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("number"),
    )
    op.create_index("ix_tibber_invoices_period_start", "tibber_invoices", ["period_start"])


def downgrade() -> None:
    op.drop_index("ix_tibber_invoices_period_start", table_name="tibber_invoices")
    op.drop_table("tibber_invoices")
