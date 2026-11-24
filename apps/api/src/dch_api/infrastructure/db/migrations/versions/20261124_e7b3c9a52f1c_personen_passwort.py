"""personen.passwort_hash, personen.passwort_gesetzt_am - Anmeldung mit Passwort neben dem Passkey

Der Hausherr hat am 24.11.2026 entschieden, dass es neben dem Passkey ein Passwort geben muss,
fuer Leute, die keinen Passkey verwenden moechten. Abgelegt wird nur ein Argon2id-Hash
(dch_api/auth/passwort.py). Beide Spalten sind leer, solange eine Person kein Passwort hat; an
den bestehenden Zeilen aendert sich nichts. Entscheidung und Begruendung im Nachtrag vom
24.11.2026 zu docs/decisions/ADR-0002-identitaet-und-berechtigung.md.

Revision ID: e7b3c9a52f1c
Revises: d6a2b8f41e0b
Create Date: 2026-11-24 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e7b3c9a52f1c"
down_revision = "d6a2b8f41e0b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("personen", sa.Column("passwort_hash", sa.Text(), nullable=True))
    op.add_column(
        "personen", sa.Column("passwort_gesetzt_am", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("personen", "passwort_gesetzt_am")
    op.drop_column("personen", "passwort_hash")
