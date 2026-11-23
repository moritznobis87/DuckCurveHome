#!/usr/bin/env python3
"""Wacht darueber, dass eine Aenderung am Add-on-Abbild auch das Haus erreicht.

**Der Anlass.** Am 23.11.2026 kam ein Add-on-Update nicht auf dem Hausgeraet an. Die Ursache
war ein toter Standardzweig, aber dahinter kam der eigentliche Fund zum Vorschein: *das Etikett
entscheidet, ob eine Aenderung das Haus je erreicht.* Home Assistant bietet ein Update nur an,
wenn `version` in `addons/<name>/config.yaml` steigt. Wird der Bridge-Code geaendert und die
Nummer nicht angehoben, baut der Supervisor das Abbild nicht neu - im Haus laeuft weiter der
alte Stand, waehrend `main` schon den neuen zeigt. Kein Test faellt, kein Protokoll klagt; es
passiert einfach nichts. Was dann wirklich geschieht, steht zwei Absaetze weiter, und es ist
nicht das Naheliegende.

Gemessen im `git log` der letzten 60 Tage (Stand 23.11.2026): 10 Commits beruehrten
`apps/bridge/src`, 8 davon hoben die Add-on-Fassung an. Die beiden anderen sind nachgelesen,
und sie belegen *nicht* den naheliegenden Satz "erreichten das Haus nie" - der ist falsch, und
er stand hier zuerst, darum diese Warnung an seiner Stelle.
`1c12a27` holte den Ortszeit-Fix in `door.py` bei Fassung 0.15.0 herein;
ausgeliefert wurde er mit `bd01eea` als 0.15.1. `d97bbe4` aenderte an beobachtetem Code allein
die Zeile `VERSION = "0.15.1"`, also das Etikett im Code selbst. **Verloren ging nichts.**

Der Grund dafuer steht im Lieferweg: `build.yaml` setzt `DCH_REF: main`, das Dockerfile
installiert `git+...@main`. Das Abbild wird beim Bau aus **main** gebaut, nicht aus dem Commit,
der die Nummer angehoben hat. Eine Aenderung ohne Anhebung bleibt also nicht fuer immer
draussen - und genau das macht sie leise statt harmlos: sie faehrt mit der **naechsten**
Anhebung mit, ungebuendelt und von niemandem fuer das Haus entschieden. Bis dahin laeuft im Haus
der alte Stand, waehrend `main` den neuen zeigt; danach bekommt das Haus Code, den der
Changelog-Eintrag jener Fassung nicht erwaehnt. Dagegen wacht diese Pruefung: nicht gegen einen
Verlust, sondern gegen eine Auslieferung, die niemand bemerkt hat.

**Das Etikett im Code gehoert in dieselbe Aenderung wie das Etikett in `config.yaml`.**
`apps/bridge/tests/test_addon_optionen.py::test_die_eingebaute_nummer_folgt_dem_etikett`
verlangt `dch_bridge.main.VERSION == config.yaml:version`. Wer die Nummer in `config.yaml`
anhebt und `VERSION` erst in einer spaeteren Aenderung nachzieht, bekommt von dieser Pruefung
zu Recht rot: in jenem Vergleich ist `main.py` beobachtet geaendert und die Fassung nicht
gestiegen. Genau das ist `d97bbe4` passiert, der einzige echte Fehlalarm der letzten 60 Tage -
`bd01eea` hob an und liess `main.py` stehen, ein eigener PR zog nach. Beide Zeilen in einer
Aenderung, und es faellt nichts (gemessen: `--basis bd01eea^ --kopf 53acb0a` ist in Ordnung).

**Die Regel.** Fuer jedes Add-on unter `addons/` gilt: hat sich etwas geaendert, was in sein
Abbild oder seine Darstellung im Add-on-Store eingeht, muss `version` in seiner `config.yaml`
gestiegen sein, und die `CHANGELOG.md` muss einen Abschnitt fuer die neue Fassung haben.

**Was beobachtet wird, und warum gerade das.** Die Liste ist aus den Dockerfiles gelesen, nicht
geraten:

* `addons/<name>/**` - der Ordner ist der Build-Kontext des Supervisors. Was darin liegt, geht
  entweder per `COPY` ins Abbild (`run.sh`, die CSV-Listen des eBUS-Add-ons) oder steuert den
  Bau und den Store-Eintrag (`Dockerfile`, `build.yaml`, `config.yaml` mit `options` und
  `schema`).
* `apps/bridge/src/**` und `apps/bridge/pyproject.toml` - nur fuer `duckcurve_bridge`. Sein
  Dockerfile installiert `"dch-bridge @ git+...@${DCH_REF}#subdirectory=apps/bridge"`. Der Code
  im Abbild kommt also aus diesem Ordner, nicht aus dem Add-on-Ordner.

**Die Ausnahmen innerhalb des Add-on-Ordners**, jede gegen das Dockerfile begruendet - keine
dieser Dateien wird vom Dockerfile kopiert oder vom Supervisor als Metadaten gelesen:

* `CHANGELOG.md` - **die wichtigste Ausnahme.** Ohne sie waere die Pflicht zirkulaer: den
  Eintrag fuer 0.15.2 zu schreiben waere eine beobachtete Aenderung und wuerde 0.15.3
  verlangen, deren Eintrag 0.15.4, und so weiter ohne Ende.
* `DOCS.md` - zeigt der Supervisor aus dem geklonten Zweig an, ohne Neubau des Abbilds.
* `icon.png`, `logo.png` - desgleichen, reine Store-Darstellung.
* `entities.example.yaml` - eine Vorlage zum Abschreiben in `/config`. Kein `COPY` fasst sie an.

**`packages/hems-core/**` wird NICHT beobachtet, obwohl der Dockerfile es nachweislich
mitinstalliert** (`"hems-core @ git+...#subdirectory=packages/hems-core"`). Das ist eine
bewusste Entscheidung, und ihr Preis gehoert hierhin statt verschwiegen zu werden. Gemessen
wie oben: 29 Commits in 60 Tagen beruehrten `packages/hems-core/src`, davon hob genau einer die
Bridge-Fassung an. Das sind **28 Commits ohne Anhebung - gezaehlt als Commits, nicht als
CI-Laeufe.** Die CI laeuft je Schub und je Pull Request, mehrere Commits also in einem Lauf,
und nicht jeder dieser 28 waere ein Fehlalarm gewesen: bei manchem waere eine Anhebung sachlich
richtig. Die Groessenordnung bleibt, und sie genuegt fuer die Entscheidung - eine Pruefung, die
staendig falsch anschlaegt, wird umgangen, und dann wacht sie auch dort nicht mehr, wo sie recht
hat.

Der Preis: **eine Aenderung allein in hems-core erreicht das Haus erst mit der naechsten
Bridge-Anhebung.** Wie ernst das ist, zeigt der Fall direkt daneben: der Ortszeit-Fix von 0.15.1
haengt an `HAUS_ZONE` aus `packages/hems-core/src/hems_core/domain/zeit.py`. Diese eine Zeile
stellt jede Uhrzeit, die im Haus gelesen wird. Wer sie aendert, bekommt von hier kein Rot und
keine Erinnerung. Wer in hems-core etwas aendert, worauf es im Haus ankommt, hebt die
Bridge-Fassung selbst an.

**Nicht alles muss ueberhaupt durch ein Abbild.** `entities_url` zeigt ab Werk auf
`.../main/config/entities.home.yaml`; die Zuordnung der Entitaeten erreicht das Haus beim
Neustart des Add-ons, ohne Neubau und ohne Nummer. Dieser Weg braucht zu Recht keine Anhebung.

**Die Fassung muss steigen, nicht nur sich unterscheiden.** Verglichen wird als Zahlentupel.
Ein Zeichenkettenvergleich waere hier falsch: `"0.9.0" > "0.10.0"` ist als Text wahr und als
Fassung falsch.

**Die Changelog-Pflicht greift, sobald das Add-on eine `CHANGELOG.md` fuehrt** - in der Basis
oder im Kopf. Das ist noetig, weil die Datei am 23.11.2026 noch gar nicht existierte: eine
unbedingte Pflicht waere rueckwirkend auf jedem Commit der Vorgeschichte rot und damit beim
ersten Lauf nicht von einem echten Befund zu unterscheiden. Dass die Basis mitzaehlt, schliesst
den Ausweg: wer die Datei loescht, um der Pflicht zu entgehen, bekommt sie trotzdem.

**Aufruf.**

    uv run python tools/addon-fassung-pruefen.py --basis origin/main
    uv run python tools/addon-fassung-pruefen.py --basis <commit>^ --kopf <commit>

Ohne `--kopf` wird der Arbeitsbaum verglichen. Dabei sieht `git diff` nur nachverfolgte
Dateien - eine voellig neue, noch nicht hinzugefuegte Datei bleibt unsichtbar. In der CI spielt
das keine Rolle, dort liegt alles im Commit.

`--ersatzbasis` fuer den Fall, dass die Basis nicht zu gebrauchen ist. Nach einem Force-Push ist
`github.event.before` unerreichbar, bei einem neuen Zweig sind es vierzig Nullen; dann wird gegen
den Merge-Base mit der Ersatzbasis verglichen. Laesst sich auch die nicht aufloesen, wird die
Pruefung uebersprungen (Rueckgabewert 0) statt abzubrechen - ein unbrauchbarer Vergleichspunkt
ist kein Befund.

**Die Basis entscheidet, ob die Pruefung die richtige Frage stellt**, und das ist an einem echten
Fehlalarm gelernt. Der Ablauf lief zuerst auch bei `push` auf einen Entwicklungszweig. Dort ist
`github.event.before` der vorige Zweigkopf - wer seit dem letzten Push main hereingemergt hat,
bekommt dessen Aenderungen an `apps/bridge` als die eigenen vorgehalten. Der erste Push dieses
Zweiges wurde genau so rot, wegen `main.py` aus einem fremden PR. Die Frage, auf die es ankommt,
ist nicht "was hat dieser Schub gebracht", sondern **"was aendert dieser Zweig gegenueber main"**
- und die stellt der `pull_request`-Lauf mit `origin/<base_ref>` als Basis. Darum laeuft `push`
nur noch auf main, wo `github.event.before` der vorige main-Stand und damit das Richtige ist.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections.abc import Iterable

import yaml

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_WURZEL = "addons"
LEERE_REVISION = "0" * 40

# Dateien im Add-on-Ordner, die allein keine Pflicht ausloesen. Begruendung je Datei im
# Modul-Docstring - keine davon wird vom Dockerfile kopiert.
NICHT_IM_ABBILD = frozenset(
    {
        "CHANGELOG.md",
        "DOCS.md",
        "icon.png",
        "logo.png",
        "entities.example.yaml",
    }
)

# Pfade ausserhalb des Add-on-Ordners, die in sein Abbild eingehen. Ein Eintrag mit Schraegstrich
# am Ende meint den ganzen Baum darunter, einer ohne genau diese Datei.
ZUSATZPFADE: dict[str, tuple[str, ...]] = {
    "duckcurve_bridge": ("apps/bridge/src/", "apps/bridge/pyproject.toml"),
}

# So viele ausloesende Dateien nennt die Meldung einzeln; der Rest wird gezaehlt.
HOECHSTENS_GENANNT = 10


# ----------------------------------------------------------------------- Baeume


class Baum:
    """Ein Dateibaum, aus dem die Pruefung liest.

    Es gibt zwei: eine Git-Revision und ein Ordner auf der Platte. Die Pruefung selbst soll von
    beidem nichts wissen - so laesst sie sich in Tests gegen zwei Ordner unter `tmp_path`
    fahren, ohne dass dafuer ein Repository angelegt werden muss.
    """

    def lesen(self, pfad: str) -> str | None:
        """Den Textinhalt einer Datei oder None, wenn sie in diesem Baum nicht liegt."""
        raise NotImplementedError

    def addons(self) -> list[str]:
        """Die Namen der Add-ons in diesem Baum - ein Ordner mit `config.yaml` darin."""
        raise NotImplementedError


class GitBaum(Baum):
    """Der Baum einer Git-Revision, gelesen mit `git show` und `git ls-tree`."""

    def __init__(self, revision: str) -> None:
        self.revision = revision

    def lesen(self, pfad: str) -> str | None:
        ergebnis = subprocess.run(
            ["git", "-C", WURZEL, "show", f"{self.revision}:{pfad}"],
            capture_output=True,
        )
        if ergebnis.returncode != 0:
            return None
        return ergebnis.stdout.decode("utf-8", "replace")

    def addons(self) -> list[str]:
        ergebnis = subprocess.run(
            [
                "git",
                "-C",
                WURZEL,
                "ls-tree",
                "-r",
                "--name-only",
                self.revision,
                "--",
                ADDON_WURZEL,
            ],
            capture_output=True,
            text=True,
        )
        if ergebnis.returncode != 0:
            return []
        namen = []
        for zeile in ergebnis.stdout.splitlines():
            teile = zeile.strip().split("/")
            if len(teile) == 3 and teile[0] == ADDON_WURZEL and teile[2] == "config.yaml":
                namen.append(teile[1])
        return sorted(namen)


class OrdnerBaum(Baum):
    """Der Baum eines Ordners auf der Platte - der Arbeitsbaum, oder einer aus `tmp_path`."""

    def __init__(self, wurzel: str) -> None:
        self.wurzel = wurzel

    def lesen(self, pfad: str) -> str | None:
        try:
            with open(os.path.join(self.wurzel, *pfad.split("/")), encoding="utf-8") as datei:
                return datei.read()
        except OSError:
            return None

    def addons(self) -> list[str]:
        verzeichnis = os.path.join(self.wurzel, ADDON_WURZEL)
        if not os.path.isdir(verzeichnis):
            return []
        namen = [
            name
            for name in os.listdir(verzeichnis)
            if os.path.isfile(os.path.join(verzeichnis, name, "config.yaml"))
        ]
        return sorted(namen)


# ------------------------------------------------------------------- Fassungen


def fassung_lesen(baum: Baum, addon: str) -> str | None:
    """`version` aus der config.yaml des Add-ons, oder None, wenn da keine lesbare steht."""
    rohtext = baum.lesen(f"{ADDON_WURZEL}/{addon}/config.yaml")
    if rohtext is None:
        return None
    try:
        daten = yaml.safe_load(rohtext)
    except yaml.YAMLError:
        return None
    if not isinstance(daten, dict) or daten.get("version") is None:
        return None
    return str(daten["version"]).strip()


def als_zahlen(fassung: str) -> tuple[int, ...] | None:
    """`0.15.1` -> `(0, 15, 1)`. None, wenn die Fassung nicht aus Zahlen besteht."""
    teile = fassung.split(".")
    if not teile or not all(teil.isdigit() for teil in teile):
        return None
    return tuple(int(teil) for teil in teile)


def gestiegen(alt: str, neu: str) -> bool:
    """Ist `neu` hoeher als `alt`?

    Verglichen wird als Zahlentupel, auf gleiche Laenge mit Nullen aufgefuellt: 0.9.0 < 0.10.0,
    und 0.15 < 0.15.1. Als Zeichenketten waere beides falsch. Eine Fassung, die sich nicht in
    Zahlen lesen laesst, gilt als nicht gestiegen - lieber ein Befund als eine stille Annahme.
    """
    zahlen_alt = als_zahlen(alt)
    zahlen_neu = als_zahlen(neu)
    if zahlen_alt is None or zahlen_neu is None:
        return False
    laenge = max(len(zahlen_alt), len(zahlen_neu))
    gefuellt_alt = zahlen_alt + (0,) * (laenge - len(zahlen_alt))
    gefuellt_neu = zahlen_neu + (0,) * (laenge - len(zahlen_neu))
    return gefuellt_neu > gefuellt_alt


def abschnitt_vorhanden(changelog: str, fassung: str) -> bool:
    """Steht in der CHANGELOG.md eine Ueberschrift, die diese Fassung nennt?

    Die Form der Zeile ist absichtlich nicht vorgeschrieben - `## 0.15.2 - 2026-11-23` und
    `## [0.15.2]` zaehlen beide. Nur abgrenzen muss sich die Nummer: `0.15.2` darf nicht aus
    der Ueberschrift fuer `0.15.20` herausgelesen werden.
    """
    muster = re.compile(
        r"^\s{0,3}#{1,6}\s.*(?<![\d.])" + re.escape(fassung) + r"(?![\d.])",
        re.MULTILINE,
    )
    return muster.search(changelog) is not None


# ----------------------------------------------------------------- die Pruefung


def beobachtet(addon: str, pfad: str) -> bool:
    """Geht diese geaenderte Datei in das Abbild oder den Store-Eintrag dieses Add-ons ein?"""
    praefix = f"{ADDON_WURZEL}/{addon}/"
    if pfad.startswith(praefix):
        return pfad[len(praefix) :] not in NICHT_IM_ABBILD
    for zusatz in ZUSATZPFADE.get(addon, ()):
        if zusatz.endswith("/"):
            if pfad.startswith(zusatz):
                return True
        elif pfad == zusatz:
            return True
    return False


def _ausloeser_auflisten(ausloeser: list[str]) -> str:
    sichtbar = ausloeser[:HOECHSTENS_GENANNT]
    zeilen = [f"    - {pfad}" for pfad in sichtbar]
    uebrig = len(ausloeser) - len(sichtbar)
    if uebrig:
        zeilen.append(f"    - ... und {uebrig} weitere")
    return "\n".join(zeilen)


def _meldung_fassung(addon: str, fassung: str, hinweis: str, ausloeser: list[str]) -> str:
    return (
        f"Add-on {addon}: {hinweis}\n"
        f"{_ausloeser_auflisten(ausloeser)}\n"
        f"  Diese Dateien gehen in das Abbild des Add-ons ein. Home Assistant bietet ein Update\n"
        f"  nur an, wenn `version` in {ADDON_WURZEL}/{addon}/config.yaml steigt; ohne hoehere\n"
        f"  Nummer baut der Supervisor das Abbild nie neu, und der neue Code laeuft im Haus nicht\n"
        f"  - ohne jede Meldung.\n"
        f"  Zu tun: `version` in {ADDON_WURZEL}/{addon}/config.yaml anheben (dort steht "
        f"{fassung}) und\n"
        f"  in {ADDON_WURZEL}/{addon}/CHANGELOG.md einen Abschnitt fuer die neue Fassung anlegen."
    )


def _meldung_changelog(addon: str, fassung: str) -> str:
    return (
        f"Add-on {addon}: `version` steht auf {fassung}, aber "
        f"{ADDON_WURZEL}/{addon}/CHANGELOG.md\n"
        f"  nennt diese Fassung in keiner Ueberschrift.\n"
        f"  Der Eintrag ist die einzige Stelle, an der spaeter nachzulesen ist, was mit dieser\n"
        f"  Nummer ins Haus gegangen ist - die Nummer selbst sagt es nicht.\n"
        f"  Zu tun: in {ADDON_WURZEL}/{addon}/CHANGELOG.md einen Abschnitt `## {fassung}` "
        f"anlegen."
    )


def pruefen(
    basis: Baum,
    kopf: Baum,
    aenderungen: Iterable[str],
    notizen: list[str] | None = None,
) -> list[str]:
    """Die Pruefung selbst: eine Meldung je Befund, leere Liste heisst in Ordnung.

    Ein neu angelegtes Add-on (in der Basis noch nicht vorhanden) faellt nicht - es gibt keine
    Vorgaengerfassung, gegen die etwas steigen koennte, und das Haus kennt das Add-on noch
    nicht. Ein geloeschtes faellt ebenso nicht: es steht im Kopf nicht mehr, und ein Abbild, das
    nicht mehr gebaut wird, braucht keine Nummer.

    Beides sind Loecher, durch die eine beobachtete Aenderung stumm hindurchgeht: wer den
    Add-on-Ordner umbenennt oder seine `config.yaml` loescht, bekommt kein Rot. Realistisch ist
    das nicht - es bricht das Add-on -, aber stumm soll es nicht bleiben. Wird `notizen`
    uebergeben, haengt die Pruefung dort je uebersprungenem Add-on eine Zeile an, die `main`
    ausgibt. Ein Loch, das man liest, ist ein anderes als eines, das keiner sieht.
    """
    geaendert = sorted(set(aenderungen))
    in_basis = set(basis.addons())
    in_kopf = set(kopf.addons())
    befunde: list[str] = []

    if notizen is not None:
        for addon in sorted(in_basis - in_kopf):
            if [pfad for pfad in geaendert if beobachtet(addon, pfad)]:
                notizen.append(
                    f"Hinweis: Add-on {addon} ist im Kopf nicht mehr vorhanden (keine lesbare "
                    f"config.yaml) - nicht geprueft, obwohl beobachtete Dateien geaendert sind."
                )

    for addon in kopf.addons():
        if addon not in in_basis:
            if notizen is not None and [p for p in geaendert if beobachtet(addon, p)]:
                notizen.append(
                    f"Hinweis: Add-on {addon} ist in der Basis nicht vorhanden (neu oder "
                    f"umbenannt) - nicht geprueft, es gibt keine Vorgaengerfassung."
                )
            continue
        ausloeser = [pfad for pfad in geaendert if beobachtet(addon, pfad)]
        fassung_basis = fassung_lesen(basis, addon)
        fassung_kopf = fassung_lesen(kopf, addon)

        if fassung_kopf is None:
            if ausloeser:
                befunde.append(
                    f"Add-on {addon}: in {ADDON_WURZEL}/{addon}/config.yaml steht keine lesbare\n"
                    f"  `version`. Ohne sie weiss der Supervisor nicht, dass es ein Update gibt."
                )
            continue

        if ausloeser:
            if fassung_basis is None:
                hinweis = "in der Basis stand keine lesbare `version`, geaendert wurde aber:"
                befunde.append(_meldung_fassung(addon, fassung_kopf, hinweis, ausloeser))
            elif not gestiegen(fassung_basis, fassung_kopf):
                if fassung_basis == fassung_kopf:
                    hinweis = f"`version` steht weiter auf {fassung_kopf}, geaendert wurde aber:"
                else:
                    hinweis = (
                        f"`version` ist von {fassung_basis} auf {fassung_kopf} gesetzt - das ist "
                        f"nicht hoeher. Geaendert wurde:"
                    )
                befunde.append(_meldung_fassung(addon, fassung_kopf, hinweis, ausloeser))

        # Die Changelog-Pflicht gilt nur fuer eine Fassung, die in diesem Vergleich neu ist, und
        # nur wenn das Add-on ueberhaupt eine CHANGELOG.md fuehrt (siehe Modul-Docstring).
        if fassung_basis is None or fassung_kopf == fassung_basis:
            continue
        changelog_pfad = f"{ADDON_WURZEL}/{addon}/CHANGELOG.md"
        im_kopf = kopf.lesen(changelog_pfad)
        if im_kopf is None and basis.lesen(changelog_pfad) is None:
            continue  # Das Add-on fuehrt (noch) keine CHANGELOG.md - die Pflicht schlaeft.
        # Im Kopf geloescht, in der Basis vorhanden: dann gilt sie als leer, nicht als abwesend.
        if not abschnitt_vorhanden(im_kopf or "", fassung_kopf):
            befunde.append(_meldung_changelog(addon, fassung_kopf))

    return befunde


# ------------------------------------------------------------------ Git-Zugaenge


def revision_aufloesen(revision: str) -> str | None:
    """Die Revision als Commit-Hash, oder None, wenn Git sie nicht kennt."""
    ergebnis = subprocess.run(
        ["git", "-C", WURZEL, "rev-parse", "--verify", "--quiet", f"{revision}^{{commit}}"],
        capture_output=True,
        text=True,
    )
    return ergebnis.stdout.strip() or None


def merge_base(eine: str, andere: str) -> str | None:
    ergebnis = subprocess.run(
        ["git", "-C", WURZEL, "merge-base", eine, andere],
        capture_output=True,
        text=True,
    )
    return ergebnis.stdout.strip() or None


def git_aenderungen(basis: str, kopf: str | None) -> list[str]:
    """Die Pfade, die sich zwischen Basis und Kopf geaendert haben.

    Ohne Kopf vergleicht `git diff` gegen den Arbeitsbaum. `--no-renames` ist Absicht, und
    gemessen statt vermutet: in einem Probe-Repository `addons/a/Dockerfile` nach
    `addons/a/DOCS.md` umbenannt - mit Umbenennungserkennung meldet `git diff --name-only` nur
    `addons/a/DOCS.md`, einen ausgenommenen Namen, und die Pruefung bliebe stumm. Mit
    `--no-renames` meldet git beide Pfade, und der alte loest die Pflicht aus.
    """
    befehl = ["git", "-C", WURZEL, "diff", "--name-only", "--no-renames", basis]
    if kopf is not None:
        befehl.append(kopf)
    befehl.append("--")
    ergebnis = subprocess.run(befehl, capture_output=True, text=True, check=True)
    return [zeile for zeile in ergebnis.stdout.splitlines() if zeile]


def basis_bestimmen(
    basis: str, ersatzbasis: str | None, kopf: str | None
) -> tuple[str | None, str]:
    """Welchen Vergleichspunkt die Pruefung nimmt - und was sie darueber zu sagen hat.

    GitHub liefert bei `push` auf einen neuen Zweig vierzig Nullen als Vorgaenger. Das ist kein
    Commit, und ein Abbruch waere hier das falsche Verhalten: nicht die Aenderung ist schuld,
    sondern der fehlende Vergleichspunkt.
    """
    if set(basis) == {"0"}:
        # Eigener Zweig, bevor Git befragt wird: vierzig Nullen loesen sich nie auf, und die
        # Meldung soll den Grund nennen, nicht nur dass Git die Revision nicht kennt.
        grund = "vierzig Nullen (neuer Zweig)"
    elif revision_aufloesen(basis) is None:
        grund = f"Git kennt '{basis}' nicht"
    else:
        return basis, f"Basis: {basis}"
    if ersatzbasis is None:
        return None, f"Keine brauchbare Basis - {grund}, und keine Ersatzbasis angegeben."
    if revision_aufloesen(ersatzbasis) is None:
        return None, f"Keine brauchbare Basis - {grund}, und '{ersatzbasis}' kennt Git auch nicht."
    gemeinsam = merge_base(ersatzbasis, kopf or "HEAD")
    if gemeinsam is None:
        return None, (
            f"Keine brauchbare Basis - {grund}, und mit '{ersatzbasis}' gibt es keinen "
            f"gemeinsamen Vorfahren."
        )
    return gemeinsam, f"Basis: Merge-Base mit {ersatzbasis} ({gemeinsam[:12]}), weil {grund}."


def main(argv: list[str] | None = None) -> int:
    zerleger = argparse.ArgumentParser(
        description="Haelt die Add-on-Fassung gegen das, was ins Abbild geht.",
    )
    zerleger.add_argument("--basis", required=True, help="Revision, gegen die verglichen wird")
    zerleger.add_argument(
        "--kopf",
        default=None,
        help="Revision des neuen Stands; ohne Angabe der Arbeitsbaum",
    )
    zerleger.add_argument(
        "--ersatzbasis",
        default=None,
        help="Revision, deren Merge-Base einspringt, wenn die Basis nicht zu gebrauchen ist",
    )
    argumente = zerleger.parse_args(argv)

    basis, auskunft = basis_bestimmen(argumente.basis, argumente.ersatzbasis, argumente.kopf)
    if basis is None:
        print(f"{auskunft} Pruefung uebersprungen.")
        return 0
    print(auskunft)

    aenderungen = git_aenderungen(basis, argumente.kopf)
    notizen: list[str] = []
    befunde = pruefen(
        GitBaum(basis),
        GitBaum(argumente.kopf) if argumente.kopf else OrdnerBaum(WURZEL),
        aenderungen,
        notizen,
    )
    for notiz in notizen:
        print(notiz)
    if not befunde:
        print(f"In Ordnung ({len(aenderungen)} geaenderte Dateien geprueft).")
        return 0
    for befund in befunde:
        print(f"\n{befund}", file=sys.stderr)
    print(
        f"\n{len(befunde)} Befund(e). Hintergrund: addons/duckcurve_bridge/DOCS.md, "
        f"Abschnitt Build-Hinweis.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
