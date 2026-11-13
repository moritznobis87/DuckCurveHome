"""measurements_minute - was die Waermepumpe ueber ihren eigenen Bus meldet

Seit dem 13.11.2026 haengt ein Adapter am Bus der Waermepumpe (ELCO Aerotop Split, BridgeNet, ein
eBUS-Dialekt), und ebusd liest mit. Vier Groessen bekommen damit eine Spalte:

- `heat_pump_flow_l_min`: der Durchflussmesser der Maschine. Beim ersten Lauf rund 30 Liter je
  Minute bei laufender, null bei stehender Maschine.
- `heat_pump_return_temp_c`: der Ruecklauf. Die Kennung (769e im Rundruf des Reglers) ist nicht
  aus einer Dokumentation, sondern aus drei Beobachtungen zugeordnet: der Wert liegt rund 3,4 K
  unter dem Vorlauf, nahe an der Temperatur der Fluessigkeitsleitung, und ergibt mit Durchfluss
  und Leistungsaufnahme eine Arbeitszahl um 4,9 bei 4,6 Grad Aussentemperatur. Am Bediengeraet
  zu bestaetigen; siehe docs/SENSORIK.md.
- `heat_pump_flow_setpoint_c`: der Vorlauf-Sollwert, den der Regler der Maschine vorgibt.
- `heat_pump_bus_power_kw`: die Leistungsaufnahme nach eigener Auskunft der Maschine. Die
  gemessene steht weiter in `heat_pump_power_kw` (Zaehler am Zuleitungskabel); die beiden
  nebeneinander zeigen, was die Auskunft der Maschine wert ist.

Zusammen mit `flow_temp_c` laesst sich daraus zum ersten Mal eine Waermeleistung rechnen:
Durchfluss mal Spreizung. Dass der Durchflussmesser nicht geeicht ist, bleibt dabei wahr.

Kein Vorbelegungswert, aus demselben Grund wie bei `flow_temp_c`: NULL ist die fehlende Messung.

Revision ID: a7d3e9c52b18
Revises: f6c2d8b41a93
Create Date: 2026-11-13 00:00:00+00:00
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a7d3e9c52b18"
down_revision = "f6c2d8b41a93"
branch_labels = None
depends_on = None

SPALTEN = (
    "heat_pump_flow_l_min",
    "heat_pump_return_temp_c",
    "heat_pump_flow_setpoint_c",
    "heat_pump_bus_power_kw",
)


def upgrade() -> None:
    for spalte in SPALTEN:
        op.add_column("measurements_minute", sa.Column(spalte, sa.Float(), nullable=True))


def downgrade() -> None:
    for spalte in reversed(SPALTEN):
        op.drop_column("measurements_minute", spalte)
