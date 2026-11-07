"""forecast_runs - welcher Lauf eines Tages fuer immer bleibt

Ab jetzt werden Prognoselaeufe ueberhaupt erst abgelegt; die beiden Tabellen lagen seit der
Grundmigration unbeschrieben da. Aufbewahrt werden alle Laeufe 30 Tage, dazu ein kanonischer
Day-ahead-Lauf je Ortstag fuer immer, und dieser Vermerk sagt, welcher das ist.

Eine Spalte und keine abgeleitete Regel: kanonisch ist der letzte Lauf, der zur kanonischen Stunde
noch gueltig war, und wer der letzte war, steht erst am Ende des Tages fest. Die Markierung faellt
deshalb beim Tagesabschluss, und das Loeschen liest sie nur noch.

Kein eigener Index. Geloescht wird nach `issued_at`, und darauf liegt seit der Grundmigration einer;
der Vermerk ist nur das Filter danach.

Revision ID: e5b1c7a93f24
Revises: d4a9b2e51c07
Create Date: 2026-11-07 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e5b1c7a93f24"
down_revision = "d4a9b2e51c07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("forecast_runs", sa.Column("canonical_day", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("forecast_runs", "canonical_day")
