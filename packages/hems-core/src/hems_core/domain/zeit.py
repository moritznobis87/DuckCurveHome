"""Die Zeitzone des Hauses - eine Stelle, und nicht die des Prozesses.

Jede Uhrzeit, die ein Mensch hier liest, steht in Ortszeit: „läuft bis 14:30", „heute 6 Uhr",
der Tagesabschluss um Mitternacht. Gerechnet wird durchweg in UTC; die Zone kommt erst beim
Anzeigen dazu.

**Warum als benannte Konstante und nicht über die Zeitzone des Prozesses.** `datetime.astimezone()`
ohne Argument nimmt die Zone, auf die das Betriebssystem gerade eingestellt ist. Im Container ist
das UTC: weder `deploy/haus/compose.yaml` noch `env.vorlage` setzen `TZ`, und auf Railway erst
recht niemand. Genau so stand der Satz des Reglers („Die Wärmepumpe läuft, von Hand eingeschaltet
bis 13:30.") im Winter eine Stunde zu früh an der Wand, während im Haus 14:30 gemeint war - still,
weil UTC eine gültige Uhrzeit ergibt und nur die falsche. Ein `TZ` in der Umgebung hätte das auch
geheilt, aber nur, solange es jemand bei jeder neuen Umgebung mitdenkt; eine Konstante im Code
gilt überall.

Die Zone steht hier und nicht in `HemsConfig`, weil sie kein Parameter dieses Hauses ist, den man
einstellt, sondern wo es steht. Zieht das Haus um, ändert sich diese Zeile.
"""

from __future__ import annotations

from zoneinfo import ZoneInfo

#: Ortszeit des Hauses. Alles, was ein Mensch als Uhrzeit liest, wird hierin formatiert.
HAUS_ZONE = ZoneInfo("Europe/Berlin")
