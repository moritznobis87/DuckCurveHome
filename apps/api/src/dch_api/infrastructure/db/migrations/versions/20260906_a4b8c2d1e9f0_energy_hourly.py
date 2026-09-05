"""energy_hourly – Energiebilanz je Stunde mit Quellen-Zuordnung und Kosten

Revision ID: a4b8c2d1e9f0
Revises: 7c1e2a9f3b4d
Create Date: 2026-09-06 00:30:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a4b8c2d1e9f0"
down_revision = "7c1e2a9f3b4d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "energy_hourly",
        sa.Column("hour_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=False),
        sa.Column("price_missing_minutes", sa.Integer(), nullable=False),
        sa.Column("pv_kwh", sa.Float(), nullable=False),
        sa.Column("import_kwh", sa.Float(), nullable=False),
        sa.Column("export_kwh", sa.Float(), nullable=False),
        sa.Column("battery_charge_kwh", sa.Float(), nullable=False),
        sa.Column("battery_discharge_kwh", sa.Float(), nullable=False),
        sa.Column("house_kwh", sa.Float(), nullable=False),
        sa.Column("heat_pump_kwh", sa.Float(), nullable=False),
        sa.Column("ev_kwh", sa.Float(), nullable=False),
        sa.Column("base_kwh", sa.Float(), nullable=False),
        sa.Column("pv_direct_kwh", sa.Float(), nullable=False),
        sa.Column("battery_to_house_kwh", sa.Float(), nullable=False),
        sa.Column("grid_to_house_kwh", sa.Float(), nullable=False),
        sa.Column("pv_to_battery_kwh", sa.Float(), nullable=False),
        sa.Column("grid_to_battery_kwh", sa.Float(), nullable=False),
        sa.Column("heat_pump_pv_kwh", sa.Float(), nullable=False),
        sa.Column("heat_pump_battery_kwh", sa.Float(), nullable=False),
        sa.Column("heat_pump_grid_kwh", sa.Float(), nullable=False),
        sa.Column("ev_pv_kwh", sa.Float(), nullable=False),
        sa.Column("ev_battery_kwh", sa.Float(), nullable=False),
        sa.Column("ev_grid_kwh", sa.Float(), nullable=False),
        sa.Column("import_cost_eur", sa.Float(), nullable=False),
        sa.Column("export_revenue_eur", sa.Float(), nullable=False),
        sa.Column("heat_pump_cost_eur", sa.Float(), nullable=False),
        sa.Column("heat_pump_opportunity_eur", sa.Float(), nullable=False),
        sa.Column("ev_cost_eur", sa.Float(), nullable=False),
        sa.Column("ev_opportunity_eur", sa.Float(), nullable=False),
        sa.Column("battery_savings_eur", sa.Float(), nullable=False),
        sa.Column("pv_direct_savings_eur", sa.Float(), nullable=False),
        sa.Column("price_weighted_ct", sa.Float(), nullable=False),
        sa.Column("outdoor_temp_c", sa.Float(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("hour_start"),
    )


def downgrade() -> None:
    op.drop_table("energy_hourly")
