"""Wann ein Live-Zustand an die Bildschirme geht - und wann nicht.

**Das Problem.** Der Strom an die offenen Bildschirme schickte den vollständigen Zustand einmal je
Sekunde. Eine Momentaufnahme ist rund 4,5 kB; gemessen am 03.11.2026 waren das 6,4 kB je Sekunde,
also 549 MB am Tag und 16,5 GB im Monat - je offenem Bildschirm. Den Takt hat nie jemand
entschieden, er stand als `>= 1.0` in einer Drosselung.

**Warum die Sekunde nichts bringt.** Die Fühler dahinter melden alle 15 bis 30 Sekunden, der
Hausanschluss im besten Fall alle paar Sekunden. Zwischen zwei Meldungen wiederholt der Strom
dieselben Zahlen. Die übrigen Seiten der App fragen ohnehin nur alle 20 bis 30 Sekunden nach.

**Zwei Bremsen, die zusammenwirken.**

* *Mindestabstand.* Häufiger als alle paar Sekunden wird nicht gesendet. Das allein senkt die Menge
  um den Faktor, um den der Abstand wächst.
* *Wiederholungsfilter.* Gleicht der neue Zustand dem zuletzt gesendeten, wird er nicht gesendet.
  Nachts, wenn sich stundenlang nichts rührt, bleibt davon fast nichts übrig.

Verglichen wird ohne die Felder, die sich von selbst bewegen, ohne etwas auszusagen - die Uhrzeit
des Servers ist in jeder Momentaufnahme neu und machte jeden Vergleich sinnlos.

**Der Höchstabstand ist die Gegenprobe zum Filter.** Ohne ihn bliebe ein Bildschirm, der eine
Meldung verpasst hat, beliebig lange auf dem alten Stand. Einmal je Minute geht der Zustand
deshalb auch dann hinaus, wenn er sich nicht geändert hat. Das kostet rund 6 MB am Tag.

Reine Entscheidungslogik, kein I/O. Was gesendet wird, entscheidet die Runtime.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

#: Schlüssel, die in jeder Momentaufnahme neu sind, ohne dass sich etwas geändert hat. Gemessen
#: am 04.11.2026 an zwei Zuständen fünf Sekunden auseinander: sieben von 66 Feldern bewegten sich
#: allein durch den Zeitfortschritt, und ohne diese Ausnahme wäre jeder Zustand neu.
#:
#: `observed_at` steht überall im Baum. Bei einem echten Messwert ist es die Zeit des Fühlers und
#: bleibt stehen; bei einem **abgeleiteten** (Hausverbrauch, Grundlast) und bei einem **fehlenden**
#: ist es schlicht „jetzt". Die beiden auseinanderzuhalten hieße, die Qualität mitzulesen und an
#: zwei Stellen dieselbe Regel zu pflegen. Stattdessen zählt `observed_at` nirgends zum Kern.
#:
#: **Was das kostet.** Meldet ein Fühler unverändert denselben Wert, erfährt der Bildschirm das
#: erst beim nächsten Höchstabstand; sein Altersvermerk kann also bis zu eine Minute zu alt sein.
#: Die Anzeige rechnet das Alter ohnehin gegen ihre eigene Uhr, und sie zeigt Minuten. Wird ein
#: Messwert wirklich alt, wechselt seine `quality`, und das steht im Kern.
FLUECHTIGE_SCHLUESSEL = frozenset({"observed_at"})
#: Dazu zwei Felder, die nur an ihrer Stelle flüchtig sind: die Zeit der Momentaufnahme und die
#: Uhr des Servers.
FLUECHTIGE_PFADE: tuple[tuple[str, ...], ...] = (
    ("snapshot", "timestamp"),
    ("system", "server_time"),
)


def _ohne_fluechtige(wert: Any, pfad: tuple[str, ...] = ()) -> Any:
    if isinstance(wert, dict):
        return {
            k: _ohne_fluechtige(v, (*pfad, k))
            for k, v in wert.items()
            if k not in FLUECHTIGE_SCHLUESSEL and (*pfad, k) not in FLUECHTIGE_PFADE
        }
    if isinstance(wert, list):
        return [_ohne_fluechtige(v, pfad) for v in wert]
    return wert


def kern(zustand: dict[str, Any]) -> str:
    """Der Teil des Zustands, an dem sich „hat sich etwas geändert" entscheidet.

    Eine Zeichenkette und kein Wörterbuch: Sie lässt sich in einem Schritt vergleichen und hält
    den vorigen Stand fest, ohne ihn gegen spätere Änderungen schützen zu müssen.
    """
    return json.dumps(_ohne_fluechtige(zustand), sort_keys=True, default=str, ensure_ascii=False)


@dataclass
class Takt:
    """Entscheidet je Aufruf, ob der Zustand hinausgeht. Hält dafür den zuletzt gesendeten fest."""

    mindestabstand_s: float = 5.0
    hoechstabstand_s: float = 60.0
    _gesendet_s: float | None = field(default=None, repr=False)
    _kern: str | None = field(default=None, repr=False)

    def naechster(
        self,
        jetzt_s: float,
        bauen: Callable[[], dict[str, Any]],
        *,
        erzwinge: bool = False,
    ) -> dict[str, Any] | None:
        """Den Zustand liefern, wenn er gesendet werden soll, sonst `None`.

        `bauen` wird nur aufgerufen, wenn der Mindestabstand vorbei ist. Den vollständigen Zustand
        zusammenzusetzen und wieder zu verwerfen wäre bei jeder eintreffenden Messung Arbeit für
        nichts, und davon gibt es viele.

        `erzwinge` ist für Ereignisse, die ein Mensch ausgelöst hat: Wer eine Schaltfläche drückt,
        soll die Wirkung sofort sehen und nicht erst beim nächsten Takt.
        """
        alter = None if self._gesendet_s is None else jetzt_s - self._gesendet_s
        if not erzwinge and alter is not None and alter < self.mindestabstand_s:
            return None
        zustand = bauen()
        neu = kern(zustand)
        if erzwinge or alter is None or neu != self._kern or alter >= self.hoechstabstand_s:
            self._gesendet_s = jetzt_s
            self._kern = neu
            return zustand
        return None
