"""Darf dieses Zutrittsereignis die Haustür öffnen?

**Warum diese Entscheidung hier steht und nicht bei der Tür.** Eine Feuerstätte, die fälschlich
anspringt, kostet Pellets. Eine Haustür, die fälschlich aufgeht, ist etwas anderes. Die Prüfung
gehört deshalb dorthin, wo sie ohne Netz, ohne Geräte und ohne Zeitbezug geprüft werden kann: in
eine reine Funktion mit Tests, nicht in den Rumpf einer Ereignisschleife.

**Die Regel ist eine Erlaubnisliste, keine Sperrliste.** Alles, was nicht ausdrücklich zugelassen
ist, öffnet nicht. Das gilt für die Tür, die Person und das Verfahren gleichermaßen. Eine
Sperrliste wäre hier der falsche Weg: sie ist genau dann unvollständig, wenn ein neues Gerät, ein
neuer Benutzer oder ein Firmware-Update einen Fall hinzufügt, an den niemand gedacht hat.

**Sechs Gründe abzulehnen**, und jeder ist ein eigener Fall, weil man im Protokoll sehen will,
welcher es war:

* aus dem Ereignis war nichts zu lesen (dann liegt der Fehler bei uns, nicht an der Tür),
* das Ereignis meldet keinen Erfolg (die Konsole hat selbst schon abgelehnt),
* die Tür steht nicht in der Liste,
* die Person steht nicht in der Liste,
* das Verfahren steht nicht in der Liste (ein PIN ist kein Gesichtsscan),
* dieselbe Person hat eben erst geöffnet (Wiederholsperre).

Die Wiederholsperre ist kein Komfort, sondern Schutz. Ein Reader, der bei einem Verbindungsfehler
sein letztes Ereignis erneut sendet, darf keine zweite Öffnung auslösen; und ein Ereignisstrom, der
nach einem Neuaufbau die Historie nachliefert, erst recht nicht.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta

# Nach einer Öffnung bleibt die Tür für diese Zeit taub gegenüber demselben Ereignis. Zwei Sekunden
# reichen nicht: die Konsole kann ein Ereignis nach einem Verbindungsabbruch erneut zustellen.
REPEAT_LOCK_S = 8.0
# Ereignisse, die älter sind als das, werden nicht mehr ausgeführt. Nach einem Neuaufbau der
# Verbindung liefert die Konsole zurückliegende Einträge nach - eine Tür, die aufgeht, weil vor
# zwanzig Minuten jemand davorstand, ist ein Fehler und kein Nachholen.
MAX_EVENT_AGE_S = 30.0


@dataclass(frozen=True)
class AccessEvent:
    """Ein Zutrittsereignis, auf das Wesentliche reduziert. Die Quelle übersetzt, hier wird gewertet."""

    at: datetime
    door: str
    actor: str
    method: str
    granted: bool


def _norm(values: list[str]) -> frozenset[str]:
    return frozenset(v.strip().lower() for v in values if v.strip())


@dataclass(frozen=True)
class DoorPolicy:
    """Wer darf womit welche Tür öffnen. Leere Listen heißen: niemand, nichts, keine."""

    enabled: bool = False
    doors: frozenset[str] = frozenset()
    actors: frozenset[str] = frozenset()
    methods: frozenset[str] = frozenset()

    @staticmethod
    def of(
        *,
        enabled: bool,
        doors: list[str],
        actors: list[str],
        methods: list[str],
    ) -> DoorPolicy:
        """Aus der Konfiguration. Groß- und Kleinschreibung spielt keine Rolle, Leerzeichen auch nicht."""
        return DoorPolicy(
            enabled=enabled,
            doors=_norm(doors),
            actors=_norm(actors),
            methods=_norm(methods),
        )


@dataclass(frozen=True)
class DoorDecision:
    open_door: bool
    reason_de: str


@dataclass
class DoorGate:
    """Die Prüfung mit Gedächtnis: sie weiß, wann zuletzt geöffnet wurde."""

    policy: DoorPolicy
    last_open: dict[str, datetime] = field(default_factory=dict)

    def decide(self, event: AccessEvent, now: datetime) -> DoorDecision:
        who = event.actor.strip().lower()
        door = event.door.strip().lower()
        method = event.method.strip().lower()
        if not self.policy.enabled:
            return DoorDecision(False, "Türöffnung ist nicht freigegeben (Beobachtungsbetrieb).")
        if not (door or who or method):
            # Nicht dasselbe wie eine Ablehnung, und die Unterscheidung ist teuer erkauft: ein
            # Rahmen, dessen Felder wir nicht finden, sah im Protokoll aus wie eine Konsole, die
            # den Zutritt verweigert. Das schickt bei der Fehlersuche in die falsche Richtung.
            return DoorDecision(
                False,
                "Aus dem Ereignis war nichts zu lesen - weder Tür noch Person noch Verfahren.",
            )
        if not event.granted:
            return DoorDecision(False, "Die Konsole hat den Zutritt selbst abgelehnt.")
        age = (now - event.at).total_seconds()
        if age > MAX_EVENT_AGE_S:
            return DoorDecision(False, f"Ereignis ist {age:.0f} s alt und wird nicht nachgeholt.")
        if door not in self.policy.doors:
            return DoorDecision(False, f"Tür „{event.door}“ ist nicht freigegeben.")
        if who not in self.policy.actors:
            return DoorDecision(False, f"Person „{event.actor}“ ist nicht freigegeben.")
        if method not in self.policy.methods:
            return DoorDecision(False, f"Verfahren „{event.method}“ ist nicht freigegeben.")
        last = self.last_open.get(who)
        if last is not None and (now - last).total_seconds() < REPEAT_LOCK_S:
            return DoorDecision(False, "Eben erst geöffnet - Wiederholung wird übergangen.")
        return DoorDecision(True, f"{event.actor} an „{event.door}“ per {event.method}.")

    def note_open(self, actor: str, now: datetime) -> None:
        """Eine tatsächlich ausgeführte Öffnung vermerken.

        Getrennt von `decide`, weil eine Entscheidung noch keine Öffnung ist: scheitert der Aufruf
        am Schloss, soll der nächste Versuch nicht an der eigenen Wiederholsperre hängenbleiben.
        """
        self.last_open[actor.strip().lower()] = now

    def forget_before(self, cutoff: datetime) -> None:
        """Alte Einträge aufräumen, damit das Gedächtnis nicht mit den Jahren wächst."""
        self.last_open = {k: v for k, v in self.last_open.items() if v >= cutoff}


def stale_cutoff(now: datetime) -> datetime:
    return now - timedelta(hours=1)
