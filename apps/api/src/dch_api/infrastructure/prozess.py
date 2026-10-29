"""Was der eigene Vorgang gerade belegt. Nur Linux, nur lesend, ohne Fremdpaket."""

from __future__ import annotations

import gc
import sys
from collections import Counter


def speicher_mb() -> tuple[float | None, float | None]:
    """Belegter Arbeitsspeicher jetzt und Höchststand seit dem Start, in MB.

    Railway rechnet Speicher ab und zeigt ihn je Dienst. Von aussen ist damit nicht zu sehen,
    welcher der drei Dienste die Summe treibt, und wer das nicht weiss, spart am falschen Ende.

    Der Höchststand (`VmHWM`) trennt zwei Fälle, die in der Momentaufnahme gleich aussehen:
    dauerhaft viel belegt, oder einmal viel gebraucht und wieder hergegeben. Das einmalige
    Neurechnen der Stundenbilanzen beim Start ist genau so ein Fall.

    Gelesen wird `/proc/self/status`. Wo es die Datei nicht gibt, bleiben beide Werte leer.
    """
    jetzt: float | None = None
    hoechst: float | None = None
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    jetzt = round(int(line.split()[1]) / 1024, 1)
                elif line.startswith("VmHWM:"):
                    hoechst = round(int(line.split()[1]) / 1024, 1)
    except OSError:
        return None, None
    return jetzt, hoechst


def objekte_nach_typ(limit: int = 12) -> tuple[int, float, list[tuple[str, int, float]]]:
    """Die grössten Objektgruppen im Python-Haufen: Typ, Anzahl, Grösse in MB.

    **Wofür das gut ist.** Die Summe aus `/proc` sagt, dass 300 MB belegt sind, nicht wofür. Diese
    Liste beantwortet die eine Frage, die dann zählt: Liegt irgendwo eine Million Zeilen herum,
    die dort nicht hingehört? Eine Zeile „tuple, 2,4 Mio, 180 MB" ist eine Spur; „nichts über
    5 MB" ist die Antwort, dass der Rest Bibliothek ist und am Code nichts zu holen.

    **Was hier nicht mitgezählt wird, und das ist kein Mangel, sondern Absicht.** Gemessen wird
    `sys.getsizeof`, also die flache Grösse: Eine Liste zählt ihre Zeiger, nicht die Objekte
    daran, und die stehen ohnehin als eigene Zeile in der Liste. Nicht enthalten sind der
    Interpreter selbst, der Speicher von C-Erweiterungen (numpy, scipy, asyncpg) und alles, was
    die Speicherverwaltung über den Bedarf hinaus hält. Die Differenz zu `rss_mb` ist deshalb
    normal und gross; sie ist die Bibliothek, nicht der Verlust.

    Teuer ist der Durchlauf auch: `gc.get_objects()` baut eine Liste über alle verwalteten
    Objekte. Für eine Auskunft auf Abruf ist das in Ordnung, für einen Takt nicht.
    """
    anzahl: Counter[str] = Counter()
    groesse: Counter[str] = Counter()
    gesamt = 0
    for o in gc.get_objects():
        name = type(o).__name__
        anzahl[name] += 1
        try:
            b = sys.getsizeof(o)
        except Exception:  # pragma: no cover - exotische Typen ohne __sizeof__
            continue
        groesse[name] += b
        gesamt += b
    oben = [
        (name, anzahl[name], round(b / (1024 * 1024), 2)) for name, b in groesse.most_common(limit)
    ]
    return sum(anzahl.values()), round(gesamt / (1024 * 1024), 1), oben
