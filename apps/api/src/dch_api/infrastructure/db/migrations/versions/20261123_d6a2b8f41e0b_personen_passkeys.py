"""personen, passkeys, passkey_schritte, person_sitzungen, zugangstoken - Anmeldung mit Passkey

Vier Tabellen fuer die Anmeldung eines Menschen, dazu der einmalige Einladungslink. Sie stehen
neben `kiosk_devices` und ersetzen es nicht: ein gepaartes Geraet ist keine Person.

Kein Passwort: angemeldet wird mit Passkey, der Rueckweg sind zehn Wiederherstellungscodes (nur
als Hash) und ein Einladungslink des Hausherrn. Entscheidung und Begruendung in
docs/decisions/ADR-0002-identitaet-und-berechtigung.md.

Revision ID: d6a2b8f41e0b
Revises: c5f1a7e30d9a
Create Date: 2026-11-23 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "d6a2b8f41e0b"
down_revision = "c5f1a7e30d9a"
branch_labels = None
depends_on = None

#: Die Liste steht auch in models.Person und in auth/rechte.py. Hier als Pruefbedingung, damit
#: eine unbekannte Rolle nicht erst in der Anwendung auffaellt - eine Zeile mit einer Rolle, die
#: niemand kennt, waere ein Zugang, dessen Rechte niemand kennt.
ROLLEN = "rolle IN ('hausherr', 'bewohner', 'gast', 'service')"


def upgrade() -> None:
    op.create_table(
        "personen",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("email", sa.String(length=254), nullable=False, unique=True),
        sa.Column("anzeigename", sa.String(length=80), nullable=False, server_default=""),
        sa.Column("rolle", sa.String(length=16), nullable=False, server_default="bewohner"),
        sa.Column("aktiv", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "wiederherstellungscodes",
            sa.JSON().with_variant(postgresql.JSONB(), "postgresql"),
            nullable=True,
        ),
        sa.Column("erstellt_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("zuletzt_angemeldet_am", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(ROLLEN, name="ck_personen_rolle"),
    )
    op.create_table(
        "passkeys",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "person_id",
            sa.Uuid(),
            sa.ForeignKey("personen.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("credential_id", sa.LargeBinary(), nullable=False, unique=True),
        sa.Column("oeffentlicher_schluessel", sa.LargeBinary(), nullable=False),
        sa.Column("zaehler", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column(
            "transports", sa.JSON().with_variant(postgresql.JSONB(), "postgresql"), nullable=True
        ),
        sa.Column("name", sa.String(length=80), nullable=False, server_default="Passkey"),
        sa.Column("gesichert", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("erstellt_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("zuletzt_benutzt_am", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_passkeys_person_id", "passkeys", ["person_id"])
    op.create_table(
        "passkey_schritte",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("token_hash", sa.String(length=64), nullable=False, unique=True),
        sa.Column("zweck", sa.String(length=16), nullable=False),
        sa.Column("challenge", sa.LargeBinary(), nullable=False),
        sa.Column(
            "person_id",
            sa.Uuid(),
            sa.ForeignKey("personen.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column("erstellt_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("laeuft_ab_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("eingeloest_am", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "zweck IN ('registrierung', 'anmeldung')", name="ck_passkey_schritte_zweck"
        ),
    )
    op.create_table(
        "person_sitzungen",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "person_id",
            sa.Uuid(),
            sa.ForeignKey("personen.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=64), nullable=False, unique=True),
        sa.Column("erstellt_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("laeuft_ab_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("zuletzt_benutzt_am", sa.DateTime(timezone=True), nullable=True),
        sa.Column("herkunft", sa.String(length=120), nullable=False, server_default=""),
    )
    op.create_index("ix_person_sitzungen_person_id", "person_sitzungen", ["person_id"])
    op.create_table(
        "zugangstoken",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "person_id",
            sa.Uuid(),
            sa.ForeignKey("personen.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=64), nullable=False, unique=True),
        sa.Column("zweck", sa.String(length=20), nullable=False),
        sa.Column("erstellt_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("laeuft_ab_am", sa.DateTime(timezone=True), nullable=False),
        sa.Column("eingeloest_am", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "zweck IN ('einladung', 'wiederherstellung')", name="ck_zugangstoken_zweck"
        ),
    )
    op.create_index("ix_zugangstoken_person_id", "zugangstoken", ["person_id"])


def downgrade() -> None:
    op.drop_table("zugangstoken")
    op.drop_table("person_sitzungen")
    op.drop_table("passkey_schritte")
    op.drop_table("passkeys")
    op.drop_table("personen")
