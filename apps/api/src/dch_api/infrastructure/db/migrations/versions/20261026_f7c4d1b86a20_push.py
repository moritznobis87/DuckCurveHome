"""push_keys und push_subscriptions - Mitteilungen auf das Telefon

Der Waechter (`hems_core.watch`) sieht, wenn eine Quelle schweigt. Damit das jemanden erreicht,
der nicht gerade auf die Wand sieht, braucht es zwei Tabellen: das Schluesselpaar des Dienstes und
die Geraete, die sich angemeldet haben.

Das Schluesselpaar steht in der Datenbank und nicht in der Umgebung, weil ein privater Schluessel
ein Geheimnis ist: So muss ihn niemand sehen, kopieren oder irgendwo eintragen. Der Dienst erzeugt
ihn beim ersten Mal selbst.

Revision ID: f7c4d1b86a20
Revises: e6b3f0a52d41
Create Date: 2026-10-26 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f7c4d1b86a20"
down_revision = "e6b3f0a52d41"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "push_keys",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("private_key", sa.String(length=128), nullable=False),
        sa.Column("public_key", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "push_subscriptions",
        sa.Column("endpoint", sa.String(length=512), primary_key=True),
        sa.Column("p256dh", sa.String(length=255), nullable=False),
        sa.Column("auth", sa.String(length=64), nullable=False),
        sa.Column("label", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_ok_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failures", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_table("push_subscriptions")
    op.drop_table("push_keys")
