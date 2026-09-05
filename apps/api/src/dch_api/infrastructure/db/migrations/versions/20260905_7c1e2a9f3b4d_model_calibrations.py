"""model_calibrations – gelernter Zustand je Modell (PV-Bias-Korrektor)

Revision ID: 7c1e2a9f3b4d
Revises: 440a3f9346c1
Create Date: 2026-09-05 12:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "7c1e2a9f3b4d"
down_revision = "440a3f9346c1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "model_calibrations",
        sa.Column("model", sa.String(length=32), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "state", sa.JSON().with_variant(postgresql.JSONB(), "postgresql"), nullable=False
        ),
        sa.PrimaryKeyConstraint("model"),
    )


def downgrade() -> None:
    op.drop_table("model_calibrations")
