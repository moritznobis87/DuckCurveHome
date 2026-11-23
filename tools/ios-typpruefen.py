#!/usr/bin/env python3
"""Ein Typprüfer für die Fehler, die ohne Xcode durchgehen – und die ich wirklich mache.

**Warum das existiert.** Die SwiftUI-Schicht lässt sich ohne macOS nur parsen, nicht
typprüfen. Ein Parser findet Klammern und Kommata; er findet nicht, dass ein Feld im Schema
`Messwert` heißt und nicht `Double`, dass eine Reihe nie wahlfrei ist, oder dass zwei
Argumente in der falschen Reihenfolge stehen. Genau das waren die Fehler des ersten und
zweiten Übersetzungslaufs: 33 Fehler, kein einziger syntaktischer.

**Was es nicht kann, und das ist eine harte Grenze.** Es löst keine Typen auf. Es kennt
Feldnamen und alle Typen, mit denen ein Name irgendwo deklariert ist – nicht aber den Typ des
Empfängers in `e.protokoll`. Darum gilt die Regel „nie wahlfrei" über **alle** Deklarationen
eines Namens: sonst gäbe es Fehlalarme. Der Preis ist eine Lücke, und sie ist real – ein
echter Fehler an `e.protokoll` blieb unentdeckt, weil zwei Ansichten ein `@State private var
protokoll: DoorLogOut?` haben und der Name damit irgendwo wahlfrei ist. Diese Lücke zu
schließen heißt, Typen aufzulösen, und das ist ein Compiler. Dafür ist der Mac da.

Dieses Skript ist kein Compiler und gibt sich nicht dafür aus. Es prüft die **sechs
Fehlerarten**, die in zwei Läufen tatsächlich aufgetreten sind, mechanisch gegen
`Schema.swift`. Sein Test ist, dass es die 33 bekannten Fehler findet.

    tools/ios-typpruefen.py

Was es prüft:

1. **Optionale Verkettung auf einem Feld, das nie wahlfrei ist** (`k.punkte?`).
2. **`if let` / `guard let` auf so einem Feld** (`if let a = k.annahme`). Dieselbe Sache, andere
   Schreibweise – im ersten Lauf hatte ich nur nach Form 1 gesucht und Form 2 übersehen.
3. **Ein Aufzählungsfeld gegen eine Zeichenkette verglichen** (`k.side == "w"`). Der Generator
   macht aus `"type": "string"` mit `enum` eine Swift-Aufzählung; der Vergleich mit einem
   Literal übersetzt nicht.
4. **Ein Zahlenfeld gegen eine Zeichenkette verglichen** (`alarm?.state == "armed_away"`).
   Fällt auf, wenn ein Feld laut Schema eine Zahl ist.
5. **Ein `Messwert` da, wo eine Zahl hingehört** (`Formate.zahl(w.waermeleistungKw, …)`). Ein
   `Messwert` trägt Wert, Güte und Zeitstempel; die Zahl daraus heißt `.belastbar`.
6. **Ein unvollständiger `switch` über eine Aufzählung** (`switch rolle` ohne sechs ihrer
   Fälle, ohne `default:`). Der Fehler des elften Laufs: `Fahrplanbild.Rolle` bekam sechs Fälle
   dazu, die Ansicht blieb bei sechs. Syntaktisch einwandfrei, für den Compiler ein Abbruch.
   Gemeldet wird nur, wenn die Fallnamen eine **echte Teilmenge genau einer** Aufzählung sind;
   passen sie auf mehrere oder auf eine genau, bleibt es still.
7. **Ein Aufruf mit Argumenten, die der Typ nicht hat** (`Leitungen(flaeche:kanten:fassung:)`,
   während `Leitungen` nur zwei Felder hat). Der Fehler des zwölften Laufs, und der teuerste:
   er kostet jedes Mal einen ganzen Übersetzungslauf auf dem Mac. Geprüft wird gegen die
   Erklärung des Typs – jeden ausgeschriebenen `init`, auch den in einer `extension`, sonst
   den gemerkten Anfangswert aus den gespeicherten Feldern. Nur Typen, die das Projekt selbst
   erklärt; eine `extension Path` sagt nichts darüber, was SwiftUIs `Path` sonst kann.
8. **Ein Name, der benutzt wird und nirgends erklärt ist** (`zahlgroesse`, `modellhinweis`).
   Der Fehler des dreizehnten Laufs, zweimal in einem Lauf: ein Block ging bei einer Änderung
   verloren, die denselben Ankerkommentar traf, und seine drei Aufrufer blieben stehen; ein
   zweiter Name wurde aufgerufen und nie geschrieben. Geprüft werden nur Namen **ohne Punkt
   davor** – dort ist `self` der Empfänger, und `self` ist das Projekt. Was von draussen ohne
   Punkt kommt (`max`, `withAnimation`, die `kSec`-Konstanten), steht in
   `tools/ios-bekannte-namen.txt`. Kleingeschriebene Namen; Typnamen bleiben aussen vor, dort
   wären ohne eine Liste aller SwiftUI-Typen alle Treffer Fehlalarme.
9. **`dazu` und `farbe` in der falschen Reihenfolge.** Bei `Zeile` und `Kacheldaten` sind die
   Felder die Argumente. Hier zählt echtes Klammernzählen: mein erster Versuch benutzte ein
   Muster für eine Klammerebene und hat deshalb einen Aufruf übersehen, der eine zweite hatte.
"""

from __future__ import annotations

import os
import re
import sys

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERN = os.path.join(WURZEL, "apps", "ios", "DuckCurveKit", "Sources", "DuckCurveKit")
SCHEMA = os.path.join(KERN, "Modelle", "Schema.swift")
APP = os.path.join(WURZEL, "apps", "ios", "DuckCurveHome")

# Argumente, deren Reihenfolge festliegt, weil die Felder die Argumente sind.
REIHENFOLGE = [("Zeile", "dazu", "farbe"), ("Kacheldaten", "dazu", "farbe")]


def klammerblock(text: str, auf: int) -> str:
    """Der Inhalt zwischen `text[auf]` (einer `{`) und der passenden `}`.

    Echtes Zaehlen und nicht ein Muster: der Rumpf eines `switch` enthaelt Verschlusse,
    Wortzwischenraeume und weitere Klammern. Zeichenketten werden uebersprungen, damit eine
    `{` in einem Text nicht zaehlt.
    """
    tiefe = 0
    i = auf
    while i < len(text):
        c = text[i]
        if c == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == "{":
            tiefe += 1
        elif c == "}":
            tiefe -= 1
            if tiefe == 0:
                return text[auf + 1:i]
        i += 1
    return text[auf + 1:]


def ausserhalb_trennen(zeile: str) -> list[str]:
    """Am Komma trennen, aber nur ausserhalb von Klammern."""
    stuecke: list[str] = []
    tiefe = 0
    jetzt = ""
    for c in zeile:
        if c in "([<":
            tiefe += 1
        elif c in ")]>":
            tiefe -= 1
        if c == "," and tiefe <= 0:
            stuecke.append(jetzt)
            jetzt = ""
        else:
            jetzt += c
    stuecke.append(jetzt)
    return stuecke


def flache_ebene(koerper: str) -> str:
    """Derselbe Text, aber alles in weiteren Klammerebenen durch Leerzeichen ersetzt.

    Damit traegt ein `switch` nur seine eigenen Fallmarken - nicht die eines zweiten, der in
    einem seiner Faelle steht.
    """
    aus = []
    tiefe = 0
    for c in koerper:
        if c == "{":
            tiefe += 1
            aus.append(" ")
        elif c == "}":
            tiefe -= 1
            aus.append(" ")
        else:
            aus.append(c if tiefe == 0 or c == "\n" else " ")
    return "".join(aus)


def schema_lesen() -> tuple[dict[str, set[str]], set[str]]:
    """Feldname -> Menge aller Typen, mit denen er irgendwo deklariert ist.

    **Alle Quellen, nicht nur Schema.swift.** Der erste Entwurf las nur die erzeugten Modelle
    und meldete deshalb Fehler, die keine waren: wenn die App selbst einen Typ mit einem Feld
    desselben Namens hat und es dort wahlfrei ist, ist `if let` richtig. Ein Feld gilt nur dann
    als nie wahlfrei, wenn **keine** Deklaration irgendwo im Projekt wahlfrei ist.
    """
    felder: dict[str, set[str]] = {}
    aufzaehlungen: set[str] = set()
    for wurzel in (KERN, APP):
        for r, _, ds in os.walk(wurzel):
            for d in ds:
                if not d.endswith(".swift"):
                    continue
                text = open(os.path.join(r, d), encoding="utf-8").read()
                for name, typ in re.findall(
                    # Beliebiger Vorsatz: `@State private var`, `public var`, `let`. Der
                    # erste Entwurf zaehlte nur die Zugriffsworte auf und hat jede Angabe mit
                    # `@State` verloren - und damit genau die wahlfreien Zustaende der Ansichten.
                    # Der Typ darf mit `[` beginnen: eine Reihe ist ein Typ.
                    r"\b(?:var|let) (\w+): ([A-Z\[(][\w.<>\[\]:, ?()]*?)\s*(?:=|\{|$)",
                    text, re.M
                ):
                    felder.setdefault(name, set()).add(typ.strip())
                aufzaehlungen |= set(re.findall(r"^public enum (\w+): String, Codable", text, re.M))
    return felder, aufzaehlungen


def aufrufe(text: str, name: str):
    """Jeden Aufruf `name(...)` mit ausgeglichenen Klammern, als (Versatz, Rumpf).

    Klammern wirklich zählen und nicht mustern: ein Aufruf mit einer zweiten Klammerebene
    rutscht sonst durch, und genau das ist passiert.
    """
    for m in re.finditer(rf"\b{name}\(", text):
        i = m.end()
        tiefe = 1
        in_text = False
        while i < len(text) and tiefe > 0:
            z = text[i]
            if in_text:
                if z == "\\":
                    i += 1
                elif z == '"':
                    in_text = False
            elif z == '"':
                in_text = True
            elif z == "(":
                tiefe += 1
            elif z == ")":
                tiefe -= 1
            i += 1
        if tiefe == 0:
            yield m.start(), text[m.end():i - 1]


def arg_namen(rumpf: str) -> list[str]:
    """Die Argumentnamen der obersten Ebene, in ihrer Reihenfolge."""
    namen, tiefe, in_text, wort = [], 0, False, ""
    i = 0
    while i < len(rumpf):
        z = rumpf[i]
        if in_text:
            if z == "\\":
                i += 1
            elif z == '"':
                in_text = False
        elif z == '"':
            in_text = True
        elif z in "([{":
            tiefe += 1
        elif z in ")]}":
            tiefe -= 1
        elif tiefe == 0:
            if z == ",":
                wort = ""
                i += 1
                continue
            if z == ":" and wort.strip() and re.fullmatch(r"\w+", wort.strip()):
                namen.append(wort.strip())
                wort = ""
                i += 1
                continue
            wort += z
        i += 1
    return namen


def ohne_kommentare(text: str) -> str:
    """Derselbe Text ohne Kommentare, Zeichenketten durch leere ersetzt.

    **Warum das sein muss.** Dieses Projekt schreibt deutsche Anführungszeichen, und die
    schliessende ist oft die gerade `"` – „sonst streckt man die Seite unnötig". Wer Klammern
    zählt, ohne Kommentare zu entfernen, hält das für den Anfang einer Zeichenkette und
    verschluckt den Rest der Datei. Genau daran ist der erste Entwurf von Regel 12
    gescheitert: der Rumpf einer Ansicht reichte bis in die übernächste.
    """
    aus: list[str] = []
    i, n = 0, len(text)
    while i < n:
        z = text[i]
        if z == '"':
            # Dreifache Anführungszeichen zählen als eine Zeichenkette bis zum nächsten Dreier.
            if text.startswith('"""', i):
                ende = text.find('"""', i + 3)
                i = n if ende < 0 else ende + 3
                aus.append('""')
                continue
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            aus.append('""')
            continue
        if text.startswith("//", i):
            ende = text.find("\n", i)
            i = n if ende < 0 else ende
            continue
        if text.startswith("/*", i):
            ende = text.find("*/", i + 2)
            i = n if ende < 0 else ende + 2
            continue
        aus.append(z)
        i += 1
    return "".join(aus)


def nur_code(text: str) -> str:
    """Derselbe Text ohne Kommentare und ohne Wortlaut – Zeichen für Zeichen an seiner Stelle.

    **Warum nicht `ohne_kommentare`.** Das dort reicht fürs Klammernzählen, verschiebt aber
    Zeilen (ein Block in dreifachen Anführungszeichen wird zu zwei Zeichen) und endet an der
    ersten Anführung in einer Einschiebung: in `"… \\(a ? "kein Füllstand" : b)"` wird aus
    `kein Füllstand` Code. Für
    Regel 13 ist beides fatal – sie melden Zeilennummern und deutsche Wörter als Namen.

    Dieses Verfahren ersetzt jedes Zeichen einer Zeichenkette oder eines Kommentars durch ein
    Leerzeichen und jeden Zeilenumbruch durch sich selbst. Länge und Zeilennummern bleiben
    also genau erhalten. Was in `\\( )` steht, bleibt stehen – das ist Code; eine
    Zeichenkette darin ist wieder Wortlaut. Darum ein Stapel und keine Suche nach dem
    nächsten Anführungszeichen.
    """
    aus: list[str] = []
    i, n = 0, len(text)
    stapel: list[str] = []  # "kurz" | "lang" | "ein" (in \( )) | "tiefer"
    while i < n:
        z = text[i]
        oben = stapel[-1] if stapel else None
        if oben in ("kurz", "lang"):
            if z == "\\" and i + 1 < n:
                if text[i + 1] == "(":
                    stapel.append("ein")
                    aus.append("  ")
                    i += 2
                    continue
                aus.append("\n" if text[i + 1] == "\n" else " ")
                aus.append(" ")
                i += 2
                continue
            if oben == "lang" and text.startswith('"""', i):
                stapel.pop()
                aus.append("   ")
                i += 3
                continue
            if oben == "kurz" and z == '"':
                stapel.pop()
                aus.append(" ")
                i += 1
                continue
            aus.append("\n" if z == "\n" else " ")
            i += 1
            continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                aus.append(" ")
                i += 1
            continue
        if text.startswith("/*", i):
            tiefe = 0
            while i < n:
                if text.startswith("/*", i):
                    tiefe += 1
                    aus.append("  ")
                    i += 2
                    continue
                if text.startswith("*/", i):
                    tiefe -= 1
                    aus.append("  ")
                    i += 2
                    if tiefe == 0:
                        break
                    continue
                aus.append("\n" if text[i] == "\n" else " ")
                i += 1
            continue
        if text.startswith('"""', i):
            stapel.append("lang")
            aus.append("   ")
            i += 3
            continue
        if z == '"':
            stapel.append("kurz")
            aus.append(" ")
            i += 1
            continue
        if oben in ("ein", "tiefer"):
            if z == "(":
                stapel.append("tiefer")
            elif z == ")":
                stapel.pop()
                if oben == "ein":
                    aus.append(" ")
                    i += 1
                    continue
        aus.append(z)
        i += 1
    return "".join(aus)


# Wie ein Name erklärt wird. Jede Gruppe eines Treffers zählt, am Komma getrennt.
ERKLAERUNGEN = [
    r"\b(?:let|var)\s+(\w+)",
    r"\b(?:let|var)\s*\(([^)]*)\)",                 # let (a, b) = …
    r"\bfunc\s+(\w+)",
    r"\bcase\s+([\w\s,]+?)(?=[:({=}\n])",            # case auto, manuellAn, manuellAus
    r"\b(?:struct|class|enum|protocol|typealias|actor)\s+(\w+)",
    r"(?:^|[(,])\s*(?:_\s+)?(\w+)\s*:\s*[\w\[(@]",    # name: Typ
    r"(?:^|[(,])\s*(\w+)\s+(\w+)\s*:\s*[\w\[(@]",    # aussen innen: Typ
    r"\b(?:for|if let|guard let|while let|catch let)\s+(\w+)",
    r"\{\s*((?:\w+\s*,\s*)*\w+)\s+in\b",            # { puffer, _ in
]

# Wörter, die Swift selbst mitbringt und die darum kein Name sind.
SCHLUESSELWOERTER = set(
    """let var func if else for in while return self nil true false guard switch case default
    break continue struct class enum protocol extension import public private internal static
    where as is try await async throws rethrows init deinit some any inout defer do catch throw
    repeat typealias associatedtype subscript operator precedencegroup lazy weak unowned open
    final override required convenience mutating nonmutating indirect fileprivate get set
    willSet didSet super Self nonisolated each borrowing consuming fallthrough package dynamic
    infix prefix postfix""".split()
)


def erklaerte_namen(texte: list[str]) -> set[str]:
    """Jeder Name, den das Projekt irgendwo erklärt."""
    namen: set[str] = set()
    for text in texte:
        for muster in ERKLAERUNGEN:
            for m in re.finditer(muster, text, re.M):
                for stueck in m.groups():
                    for name in re.split(r"[,\s]+", stueck or ""):
                        if name:
                            namen.add(name)
        if re.search(r"\b(?:willSet|didSet)\b", text):
            namen |= {"oldValue", "newValue"}
    return namen


def bekannte_namen() -> set[str]:
    """Die Liste der Namen von draussen, aus `tools/ios-bekannte-namen.txt`."""
    pfad = os.path.join(WURZEL, "tools", "ios-bekannte-namen.txt")
    if not os.path.exists(pfad):
        return set()
    zeilen = open(pfad, encoding="utf-8").read().splitlines()
    return {w for z in zeilen if not z.lstrip().startswith("#") for w in z.split()}


def bausteine_lesen(pfade: list[str]) -> dict[str, set[str]]:
    """Jeder im Projekt erklärte Verbundtyp mit den Argumentnamen, die er annimmt.

    **Warum das die wichtigste Regel ist.** Zweimal hat genau dieser Fehler den
    Übersetzungslauf gekostet: ein Aufruf mit Argumenten, die der Typ nicht hat
    (`Leitungen(flaeche:kanten:fassung:)`, während `Leitungen` nur zwei Felder hatte).
    Syntaktisch einwandfrei, für den Parser unsichtbar, für den Compiler ein Abbruch – und
    beide Male erst auf dem Mac aufgefallen, eine Stunde später.

    Gelesen werden die Erklärungen auf der **flachen Ebene** des Rumpfes: jeder dort
    ausgeschriebene `init(...)`, und wenn es keinen gibt, der gemerkte Anfangswert aus den
    gespeicherten Feldern. Ein `.init(` mitten im Rumpf ist ein Aufruf und keine Erklärung –
    daran ist der erste Entwurf gescheitert und hat jeder Ansicht die Argumente von
    `Gradient.Stop` zugeschrieben.

    Berechnete Eigenschaften (`var x: T { … }`) sind keine Felder und zählen nicht mit;
    `static` ebenfalls nicht. Private Felder werden mitgezählt, obwohl Swift sie aus dem
    gemerkten Anfangswert nimmt: ein Fehlalarm wäre schlimmer als eine Lücke.
    """
    aus: dict[str, set[str]] = {}
    # Nur Typen, die das Projekt selbst erklärt. Eine `extension Path` fügt der Vorlage von
    # SwiftUI etwas hinzu und sagt nichts darüber, was sie sonst kann - wer sie für die ganze
    # Erklärung hält, meldet jedes `Path(ellipseIn:)` als Fehler.
    eigene: set[str] = set()
    for pfad in pfade:
        text = ohne_kommentare(open(pfad, encoding="utf-8").read())
        # Auch `extension X { init(...) }`: `Zeichen` hat seinen zweiten Anfangswert dort,
        # und ohne ihn hielte die Regel jeden `Zeichen(bereich:)` für falsch.
        for m in re.finditer(r"^[ \t]*(?:public |internal |private |final |)*"
                             r"(?:struct|class|extension)\s+(\w+)[^{\n]*\{", text, re.M):
            name = m.group(1)
            if not m.group(0).lstrip().startswith("extension"):
                eigene.add(name)
            koerper = klammerblock(text, m.end() - 1)
            flach = flache_ebene(koerper)
            namen = aus.setdefault(name, set())
            # Die Erklärungen stehen auf der flachen Ebene. `init?` und `init` mit
            # Modifikatoren davor zählen mit, `.init(` nicht - dem geht ein Punkt voraus.
            inits = [im for im in re.finditer(r"(?:^|[^.\w])(init\??)\s*\(", flach)]
            echte = []
            for im in inits:
                rumpf = next(iter(aufrufe(flach[im.start(1):], "init")), None)
                if rumpf is None:
                    continue
                if re.search(r"\bfrom\s+decoder\b", rumpf[1]):
                    continue
                echte.append(rumpf[1])
            if m.group(0).lstrip().startswith("extension"):
                # Eine Erweiterung bringt nur Anfangswerte dazu; ihre `var` sind berechnet.
                for rumpf in echte:
                    for stueck in ausserhalb_trennen(rumpf):
                        em = re.match(r"\s*(\w+|_)\s+\w+\s*:", stueck) \
                            or re.match(r"\s*(\w+)\s*:", stueck)
                        if em:
                            namen.add(em.group(1))
                continue
            if echte:
                for rumpf in echte:
                    for stueck in ausserhalb_trennen(rumpf):
                        em = re.match(r"\s*(\w+|_)\s+\w+\s*:", stueck) \
                            or re.match(r"\s*(\w+)\s*:", stueck)
                        if em:
                            namen.add(em.group(1))
                continue
            # `flache_ebene` behält die Zeilen, also steht Zeile für Zeile beides
            # nebeneinander: die flache Fassung sagt, ob die Erklärung zur obersten Ebene
            # gehört, die rohe, ob ein `{` folgt - und dann ist es eine berechnete
            # Eigenschaft und kein Feld.
            for zeile, roh in zip(flach.splitlines(), koerper.splitlines()):
                z = zeile.strip()
                if not z or z.startswith("static") or " static " in z:
                    continue
                kopf = roh.split("=")[0]
                if kopf.rstrip().endswith("{"):
                    continue
                # Mit Typangabe (`let wort: String`) oder ohne (`var gestrichelt = false`).
                # Ohne den zweiten Fall fehlte jedes Feld, dessen Typ der Compiler herleitet -
                # und das sind in dieser App gerade die mit Vorgabewert, also die, die am
                # Aufrufort am ehesten dastehen.
                fm = re.match(r"(?:@\w+(?:\([^)]*\))?\s+)*"
                              r"(?:public |internal |private |fileprivate |)*"
                              r"(?:var|let)\s+(\w+)\s*[:=]", z)
                if fm:
                    namen.add(fm.group(1))
    return {n: a for n, a in aus.items() if n in eigene}


def feldreihenfolgen(pfade: list[str]) -> dict[str, list[str]]:
    """Jeder Verbund **ohne eigenen `init`** mit seinen Feldern in der Reihenfolge der Erklaerung.

    **Warum die Reihenfolge eine Regel verdient.** Hat ein `struct` keinen ausgeschriebenen
    `init`, dann *ist* der gemerkte Mitglieder-Anfangswert seine Schnittstelle - und der verlangt
    die Argumente in genau der Reihenfolge der Felder. Ein Aufruf, der zwei davon vertauscht,
    nennt lauter Namen, die der Typ wirklich hat; Regel 12 sieht deshalb nichts, `swiftc -parse`
    sieht nichts, und auf Linux uebersetzt die Oberflaeche gar nicht. Gefallen ist es erst im Lauf
    `oberflaeche` auf macOS, zweieinhalb Stunden nach dem Schieben (22.11.2026,
    `KostenSeite.swift:80`: "argument 'nebenfehler' must precede argument 'gerechnetAm'" - ein
    neues Feld war hinten an `Berichtsseite` angehaengt worden, waehrend alle sieben
    Aufrufstellen es vorn nannten).

    **Nur, wo die Antwort eindeutig ist.** Aussen vor bleiben: Typen mit einem ausgeschriebenen
    `init` (dann gilt dessen Reihenfolge, und bei mehreren Anfangswerten gibt es keine eine),
    Typen, die auch in einer `extension` einen `init` bekommen, Namen, die mehr als einmal
    erklaert sind, und `class` - fuer Klassen merkt Swift keinen Anfangswert.

    Mitgezaehlt wird jedes gespeicherte Feld, auch ein privates mit Vorgabewert: es steht am
    Aufrufort nie, verschiebt aber die Reihenfolge der anderen nicht. Berechnete Eigenschaften
    (`var x: T { … }`) und `static` sind keine Felder.
    """
    reihen: dict[str, list[str]] = {}
    mehrfach: set[str] = set()
    mit_init: set[str] = set()
    for pfad in pfade:
        text = ohne_kommentare(open(pfad, encoding="utf-8").read())
        for m in re.finditer(r"^[ \t]*(?:public |internal |private |fileprivate |final |)*"
                             r"(struct|class|extension)\s+(\w+)[^{\n]*\{", text, re.M):
            art, name = m.group(1), m.group(2)
            koerper = klammerblock(text, m.end() - 1)
            flach = flache_ebene(koerper)
            # Ein `.init(` mitten im Rumpf ist ein Aufruf und keine Erklaerung; derselbe
            # Unterschied, an dem schon `bausteine_lesen` haengt.
            if re.search(r"(?:^|[^.\w])init\??\s*\(", flach):
                mit_init.add(name)
            if art != "struct":
                continue
            if name in reihen:
                mehrfach.add(name)
                continue
            felder: list[str] = []
            for zeile, roh in zip(flach.splitlines(), koerper.splitlines()):
                z = zeile.strip()
                if not z or z.startswith("static") or " static " in z:
                    continue
                if roh.split("=")[0].rstrip().endswith("{"):
                    continue
                fm = re.match(r"(?:@\w+(?:\([^)]*\))?\s+)*"
                              r"(?:public |internal |private |fileprivate |)*"
                              r"(?:var|let)\s+(\w+)\s*[:=]", z)
                if fm:
                    felder.append(fm.group(1))
            reihen[name] = felder
    return {n: f for n, f in reihen.items()
            if n not in mehrfach and n not in mit_init and len(f) > 1}


def main() -> int:
    felder, aufzaehlungen = schema_lesen()
    nie_wahlfrei = {n for n, ts in felder.items() if all(not t.endswith("?") for t in ts)}
    # **Namen, die auch Apple vergibt.** `DateComponents` hat `minute`, `hour`, `day` - alle
    # wahlfrei, und `teile.minute ?? 0` ist dort richtig. Sobald das Projekt irgendwo ein
    # eigenes Feld desselben Namens erklärt (`Faecherpunkt.minute: Int`), hielte Regel 1 den
    # Zugriff für einen Fehler. Der Prüfer löst keine Typen auf und kann den Empfänger nicht
    # ansehen; also bleiben die Namen aussen vor, die Foundation selbst führt.
    nie_wahlfrei -= {
        "era", "year", "month", "day", "hour", "minute", "second", "nanosecond",
        "weekday", "weekdayOrdinal", "quarter", "weekOfMonth", "weekOfYear",
        "yearForWeekOfYear", "calendar", "timeZone",
    }
    # Ein Vergleich mit einer Zeichenkette ist nur dann sicher falsch, wenn das Feld in
    # KEINEM Typ eine Zeichenkette ist. `mode` etwa heisst woanders `String` - dort ist der
    # Vergleich richtig, und ein Prueffehler waere schlimmer als eine Luecke.
    nie_text = {n for n, ts in felder.items()
                if ts and all(t.rstrip("?") not in ("String",) for t in ts)}

    maengel: list[tuple[str, int, str]] = []
    dateien = sorted(
        os.path.join(r, d)
        for r, _, ds in os.walk(APP) for d in ds if d.endswith(".swift")
    )

    # Eine Kette wie `haus.zustand?.system.watch` ist als Ganzes wahlfrei - das `?` steht
    # weiter vorn. Wer nur das letzte Feld ansieht, meldet hier einen Fehler, der keiner ist.
    # Genau das ist beim ersten Entwurf dieses Skripts passiert.
    # `$0` muss als Kettenanfang mitgelesen werden. Ohne ihn war ein grosser Teil des Codes
    # unsichtbar: dieses Projekt schreibt fast jede Reihenverarbeitung als `.map { $0.feld }`,
    # und genau dort sass der Fehler des zehnten Laufs.
    KETTE = r"((?:(?:\w+|\$\d+)(?:\(\))?[.?]+)*)(\w+)"

    for pfad in dateien:
        kurz = os.path.relpath(pfad, APP)
        text = open(pfad, encoding="utf-8").read()

        for nr, zeile in enumerate(text.splitlines(), 1):
            # Zeichenketten UND Kommentare weg. Ohne das liest der Prüfer den eigenen
            # Kommentar, in dem der alte, falsche Code zitiert wird - genau das ist passiert.
            ohne_text = re.sub(r'"(?:[^"\\]|\\.)*"', '""', zeile)
            ohne_text = re.sub(r"//.*$", "", ohne_text)

            # 1. optionale Verkettung auf etwas, das nie wahlfrei ist
            for m in re.finditer(KETTE + r"\?", ohne_text):
                kette, feld = m.group(1), m.group(2)
                if feld in nie_wahlfrei and "?" not in kette:
                    maengel.append((kurz, nr, f".{feld}? - im Schema nie wahlfrei "
                                              f"({sorted(felder[feld])})"))

            # 2. if let / guard let auf so einem Feld.
            #
            # **Jede Bindung der Kette, nicht nur die erste.** `if let k = kennzahlen, let
            # zeilen = k.zeilen` hat zwei - und der Fehler sass in der zweiten. Der erste
            # Entwurf sah nur bis zum ersten Komma und hat sie durchgelassen.
            if re.search(r"\b(?:if|guard)\s+let\b", ohne_text):
                bindungen = r"\blet\s+\w+\s*=\s*" + KETTE + r"\b"
            else:
                bindungen = r"(?!x)x"  # nichts
            for m in re.finditer(bindungen, ohne_text):
                kette, feld = m.group(1), m.group(2)
                # Folgt `(` oder `[`, ist es ein Aufruf oder ein Indexzugriff und kein Feld:
                # bei `Fahrplan.zeilen(…).first` und `e.wahl[…]` kommt das Wahlfreie von dort.
                nachher = ohne_text[m.end():m.end() + 1]
                if nachher in ("(", "["):
                    continue
                if feld in nie_wahlfrei and "?" not in kette and kette:
                    maengel.append((kurz, nr, f"if/guard let auf .{feld} - nie wahlfrei "
                                              f"({sorted(felder[feld])})"))

            # 3. `?? ersatz` oder Vergleich mit nil auf so einem Feld
            for m in re.finditer(KETTE + r"\s*(\?\?|[!=]=\s*nil)", ohne_text):
                kette, feld = m.group(1), m.group(2)
                if feld in nie_wahlfrei and "?" not in kette and kette:
                    was = "?? …" if m.group(3).startswith("??") else m.group(3)
                    maengel.append((kurz, nr, f".{feld} {was} - nie wahlfrei "
                                              f"({sorted(felder[feld])})"))

            # 4. Vergleich mit einer Zeichenkette, wo das Feld nirgends eine ist
            for m in re.finditer(r"\.(\w+)\s*[!=]=\s*\"", zeile):
                feld = m.group(1)
                if feld in nie_text:
                    art = ("eine Aufzählung" if any(t.rstrip("?") in aufzaehlungen
                                                    for t in felder[feld]) else "keine Zeichenkette")
                    maengel.append((kurz, nr, f".{feld} ist {art} "
                                              f"({sorted(felder[feld])})"))

        # 6. `if let x = …feld, !x.isEmpty` - die Verwendung verrät den Typ.
        #
        # **Das schließt die Lücke von Runde drei und vier, ohne Typen aufzulösen.** Die Regel
        # „nie wahlfrei" gilt über alle Deklarationen eines Namens, und daran scheiterte sie
        # zweimal: `days` heißt in zwei erzeugten Modellen `Int?` und in einem dritten
        # `[ShiftDayOut]`, `protokoll` ist in zwei Ansichten ein `@State … DoorLogOut?`. Beide
        # echten Fehler blieben deshalb unentdeckt.
        #
        # Der Ausweg: wird die ausgepackte Größe im selben Atemzug mit `!x.isEmpty` geprüft,
        # ist sie eine Sammlung. Ein `Int?` hat kein `isEmpty`. Also zählen hier nur die
        # Deklarationen, die Sammlungen sind - und wenn darunter keine wahlfreie ist, kann der
        # Empfänger nur die nicht-wahlfreie Reihe sein. Kein Typsystem, nur ein Ausschluss.
        for m in re.finditer(
            r"\b(?:if|guard)\s+let\s+(\w+)\s*=\s*(\w[\w.?()\[\]]*?)\.(\w+)\s*,"
            r"\s*!\1\.isEmpty\b", text
        ):
            name, kette, feld = m.group(1), m.group(2), m.group(3)
            if "?" in kette or feld not in felder:
                continue
            sammlungen = {t for t in felder[feld]
                          if t.startswith("[") or t.rstrip("?") in ("String",)}
            if sammlungen and all(not t.endswith("?") for t in sammlungen):
                nr = text[:m.start()].count("\n") + 1
                maengel.append((kurz, nr, f"if let … = .{feld}, !…isEmpty - {feld} ist als "
                                          f"Sammlung nur nicht-wahlfrei deklariert "
                                          f"({sorted(sammlungen)})"))

        # 7. Ein Reihenfeld als Element eines Reihenliterals.
        #
        # Dreimal vorgekommen: `[Formate.hhmm(…), e.quelle, e.urheber]`,
        # `[… , paar.verschiebung?.assumptionsDe, …]`, `[w.methodeDe]`. Steht ein Feld, das
        # laut Schema eine Reihe ist, als *Element* in einem Literal neben Einzelwerten, wird
        # das Literal `[Any]` oder `[[String]]` - und passt auf keine Signatur. Gemeint war
        # jedes Mal: anhängen, nicht einreihen.
        for nr, zeile in enumerate(text.splitlines(), 1):
            m = re.match(r"^\s*[\w.?$]*\.(\w+),\s*$", zeile)
            if not m:
                continue
            feld = m.group(1)
            typen = felder.get(feld, set())
            if typen and all(t.startswith("[") for t in typen):
                maengel.append((kurz, nr, f".{feld} ist eine Reihe ({sorted(typen)}) und steht "
                                          f"als Element in einem Literal - anhängen, nicht "
                                          f"einreihen"))

        # 7b. Dieselbe Verwechslung, andere Stelle: eine Reihe in `Text(…)`.
        for nr, zeile in enumerate(text.splitlines(), 1):
            ohne = re.sub(r"//.*$", "", zeile)
            for m in re.finditer(r"\bText\(\s*[\w.$]*?\.(\w+)\s*\)", ohne):
                typen = felder.get(m.group(1), set())
                if typen and all(t.startswith("[") for t in typen):
                    maengel.append((kurz, nr, f"Text(… .{m.group(1)}) - das ist eine Reihe "
                                              f"({sorted(typen)}) und kein Satz"))

        # 8. Eine ganze Zahl da, wo `Formate` eine Dezimalzahl erwartet.
        #
        # Die `Formate`-Funktionen nehmen `Double?`. Swift wandelt `Int` **nicht** von sich aus
        # um - anders als bei `[String]` zu `[String?]`. Viele Felder des Schemas sind aber
        # `Int`: Läufe, Starts, Minuten, Zündungen. Dazu der Gegenfall: `Int($0.rounded())` auf
        # einem Feld, das schon `Int` ist. Beides war im achten Lauf an sechs Stellen, und der
        # Compiler hatte nur drei davon erreicht.
        for nr, zeile in enumerate(text.splitlines(), 1):
            ohne = re.sub(r"//.*$", "", re.sub(r'"(?:[^"\\]|\\.)*"', '""', zeile))
            for m in re.finditer(r"Formate\.(zahl|prozent|kw|kwh|euro|ct|celsius)\("
                                 r"\s*[\w.$]*?\.(\w+)\s*[,)]", ohne):
                feld = m.group(2)
                typen = felder.get(feld, set())
                if typen and all(t.rstrip("?") == "Int" for t in typen):
                    maengel.append((kurz, nr, f"Formate.{m.group(1)}(… .{feld} …) - {feld} ist "
                                              f"Int, erwartet wird Double; `Double(…)` bzw. "
                                              f"`.map(Double.init)`"))
            for m in re.finditer(r"\.(\w+)\.map \{ Int\(\$0\.rounded\(\)\) \}", ohne):
                feld = m.group(1)
                typen = felder.get(feld, set())
                if typen and all(t.rstrip("?") == "Int" for t in typen):
                    maengel.append((kurz, nr, f".{feld} ist schon Int - das Runden ist falsch"))

        # 10. Ein deutsches Anführungszeichen, mit ASCII geschlossen.
        #
        # **Mein eigener Fehler, dreimal gemacht.** `„am Ziel"` in einem Swift-Text: das
        # öffnende Zeichen ist U+201E, das schließende ein ASCII-Anführungszeichen – und das
        # beendet den String. Der Compiler meldet es („unterminated string literal"), aber
        # erst nach einer Runde; hier kostet es eine Sekunde. Richtig ist U+201C.
        for nr, roh in enumerate(text.splitlines(), 1):
            # **Kommentare zuerst weg.** In einem `//`-Kommentar ist ein ASCII-Zeichen
            # harmlos; dort steht die Erklaerung des Fehlers, nicht der Fehler. Beim ersten
            # Entwurf dieser Regel waren alle drei Treffer genau das.
            zeile = re.sub(r"//.*$", "", roh)
            if "\u201e" in zeile and '"' in zeile.split("\u201e", 1)[1]:
                # Nur melden, wenn kein schliessendes U+201C folgt.
                rest = zeile.split("\u201e", 1)[1]
                if "\u201c" not in rest.split('"', 1)[0]:
                    maengel.append((kurz, nr, "„…\" – ein deutsches Anführungszeichen mit "
                                              "ASCII geschlossen; das beendet den String "
                                              "(richtig: “)"))

        # 5. Reihenfolge der Argumente, mit echtem Klammernzählen
        for name, zuerst, danach in REIHENFOLGE:
            for versatz, rumpf in aufrufe(text, name):
                namen = arg_namen(rumpf)
                if zuerst in namen and danach in namen and namen.index(danach) < namen.index(zuerst):
                    nr = text[:versatz].count("\n") + 1
                    maengel.append((kurz, nr, f"{name}(…): „{danach}“ steht vor „{zuerst}“ - "
                                              f"die Felder sind die Argumente"))

    # 9. Eine Datei, die den Kern benutzt, ohne ihn einzubinden.
    #
    # `Typografie.swift` benutzte `Formate` und hatte nur `import SwiftUI`. Das faellt beim
    # Parsen nicht auf - ein unbekannter Name ist syntaktisch einwandfrei - und erst der
    # Compiler sagt „cannot find 'Formate' in scope".
    ART = r"(?:struct|enum|final class|class|actor|protocol)"
    kerntypen: set[str] = set()
    for r, _, ds in os.walk(KERN):
        for d in ds:
            if d.endswith(".swift"):
                kerntypen |= set(re.findall(
                    rf"public {ART} (\w+)",
                    open(os.path.join(r, d), encoding="utf-8").read()))
    # **Namen, die die App selbst vergibt, zaehlen nicht.** `Seite`, `Fehler` und `Namen` gibt
    # es im Kern und in der Oberflaeche; eine Datei, die nur die eigene `Seite` benutzt,
    # braucht den Kern nicht. Ohne diesen Abzug schluege die Regel irgendwann falsch an.
    eigene: set[str] = set()
    for pfad in dateien:
        eigene |= set(re.findall(rf"^{ART} (\w+)", open(pfad, encoding="utf-8").read(), re.M))
    kerntypen -= eigene
    for pfad in dateien:
        text = open(pfad, encoding="utf-8").read()
        if "import DuckCurveKit" in text:
            continue
        # **Ohne Kommentare und Zeichenketten.** Eine Datei, die `Punkt` nur in einem
        # Dokumentationssatz erwaehnt ("Der Punkt bei `anteil`"), braucht den Kern nicht -
        # genau das hat diese Regel am 17.11. gemeldet. Die Regeln 1 bis 8 raeumen beides
        # laengst weg, bevor sie suchen; hier fehlte es.
        ohne = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
        ohne = re.sub(r"//[^\n]*", "", ohne)
        ohne = re.sub(r"/\*.*?\*/", "", ohne, flags=re.S)
        benutzt = sorted({n for n in kerntypen if re.search(rf"\b{n}\b", ohne)})
        if benutzt:
            maengel.append((os.path.relpath(pfad, APP), 1,
                            f"benutzt {benutzt[:4]} aus dem Kern, ohne `import DuckCurveKit`"))

    # 11. Ein `switch` ueber eine Aufzaehlung des Kerns, der nicht alle Faelle kennt.
    #
    # **Der Fehler des elften Laufs.** `Fahrplanbild.Rolle` bekam sechs Faelle dazu, und der
    # `switch` in `Fahrplanzeichnung.farbe(_:)` blieb bei sechs. Der Parser sieht daran nichts:
    # ein unvollstaendiger `switch` ist syntaktisch einwandfrei. Erst Xcode sagt „switch must be
    # exhaustive" - und das kostet eine Runde ueber den Mac.
    #
    # **Ohne Typauflösung, also vorsichtig.** Gemeldet wird nur, wenn die Fallnamen des `switch`
    # eine **echte Teilmenge** der Faelle **genau einer** Aufzaehlung sind - des Kerns oder der
    # App - und kein `default:` dasteht. Passen sie auf mehrere, bleibt es still: dann weiss
    # dieses Skript nicht, welche gemeint ist, und ein Fehlalarm waere schlimmer als die Luecke.
    # Jede Aufzaehlung einzeln, nicht nach Namen zusammengelegt: `Rolle` gibt es in dieser
    # Anwendung zweimal (Zugangsrolle und Zeichenrolle). Sie zu vereinen hat im ersten Entwurf
    # dieser Regel neun Fehlalarme erzeugt.
    aufzaehlungen: list[tuple[str, set[str]]] = []
    for wurzel in (KERN, APP):
        for r, _, ds in os.walk(wurzel):
            for d in ds:
                if not d.endswith(".swift"):
                    continue
                quelle = open(os.path.join(r, d), encoding="utf-8").read()
                for m in re.finditer(r"\benum (\w+)[^{]*\{", quelle):
                    # Nur die oberste Ebene des Rumpfes: ein `case let (x, y)` in einem
                    # verschachtelten `switch` ist kein Fall dieser Aufzaehlung.
                    koerper = flache_ebene(klammerblock(quelle, m.end() - 1))
                    faelle: set[str] = set()
                    for zeile in koerper.splitlines():
                        z = re.sub(r"//.*$", "", zeile).strip()
                        if not z.startswith("case "):
                            continue
                        for stueck in ausserhalb_trennen(z[5:]):
                            # Ein Fall mit Nutzlast (`case netz(String)`) zaehlt mit - die
                            # Namen seiner Werte nicht. `case kurve(griff1: P, nach: P)` ist
                            # **ein** Fall; am Komma zu trennen machte daraus drei, und genau
                            # das hat im ersten Entwurf einen vollstaendigen `switch`
                            # angemeckert.
                            name = re.match(r"\s*(\w+)", stueck)
                            if name:
                                faelle.add(name.group(1))
                    if len(faelle) >= 2:
                        aufzaehlungen.append((m.group(1), faelle))

    for pfad in dateien:
        kurz = os.path.relpath(pfad, APP)
        text = open(pfad, encoding="utf-8").read()
        for m in re.finditer(r"\bswitch\b[^{\n]*\{", text):
            koerper = klammerblock(text, m.end() - 1)
            # Nur die Fallmarken dieser Ebene: ein `switch` in einem `switch` hat seine eigenen.
            flach = flache_ebene(koerper)
            if re.search(r"^\s*default\s*:", flach, re.M):
                continue
            marken: set[str] = set()
            for zeile in flach.splitlines():
                z = re.sub(r"//.*$", "", zeile).strip()
                if not z.startswith("case ."):
                    continue
                marken |= set(re.findall(r"\.(\w+)", z.split(":")[0]))
            if len(marken) < 2:
                continue
            # Deckt sich die Markenmenge mit *irgendeiner* Aufzaehlung genau, ist der `switch`
            # vollstaendig - fuer die, die er meint.
            if any(marken == f for _, f in aufzaehlungen):
                continue
            passend = [(n, f) for n, f in aufzaehlungen if marken < f]
            if len(passend) == 1:
                name, faelle = passend[0]
                nr = text[:m.start()].count("\n") + 1
                maengel.append((kurz, nr, f"switch ueber {name} ohne `default:` kennt "
                                          f"{len(marken)} von {len(faelle)} Faellen - "
                                          f"es fehlen {sorted(faelle - marken)}"))

    # 12. Ein Aufruf mit Argumenten, die der Typ nicht hat.
    #
    # Geprüft werden nur Typen, die das Projekt selbst erklärt - alles aus SwiftUI und der
    # Standardbibliothek ist unbekannt und bleibt darum still. Gemeldet wird nur ein Name,
    # den der Typ in KEINEM seiner Anfangswerte kennt: ein Typ mit mehreren `init` nimmt
    # ihre Namen zusammen, sonst wäre jede Überladung ein Fehlalarm.
    kernpfade = sorted(
        os.path.join(r, d)
        for r, _, ds in os.walk(KERN) for d in ds if d.endswith(".swift")
    )
    bausteine = bausteine_lesen(dateien + kernpfade)
    # Namen, die auch eine Funktion oder eine Aufzählung sein können, bleiben aussen vor:
    # `Zeichen(...)` ist beides, und der Aufruf einer gleichnamigen Funktion hat andere
    # Argumente. Dasselbe gilt für alles, was nur einmal vorkommt.
    doppeldeutig = set()
    for pfad in dateien + kernpfade:
        t = open(pfad, encoding="utf-8").read()
        for m in re.finditer(r"\b(?:func|enum)\s+(\w+)", t):
            doppeldeutig.add(m.group(1))
    for pfad in dateien:
        kurz = os.path.relpath(pfad, APP)
        text = open(pfad, encoding="utf-8").read()
        ohne = re.sub(r"//[^\n]*", "", text)
        for name, erlaubt in bausteine.items():
            if not erlaubt or name in doppeldeutig:
                continue
            for versatz, rumpf in aufrufe(ohne, name):
                fremd = [a for a in arg_namen(rumpf) if a not in erlaubt]
                if not fremd:
                    continue
                nr = ohne[:versatz].count("\n") + 1
                maengel.append((kurz, nr, f"{name}(...) bekommt {fremd}, kennt aber nur "
                                          f"{sorted(erlaubt)}"))

    # 13. Ein Name, der benutzt wird und nirgends erklärt ist.
    #
    # **Der Fehler des dreizehnten Laufs, und zweimal in einem Lauf.** `zahlgroesse` stand in
    # `Knoten`, bis eine späterere Änderung denselben Ankerkommentar traf und den Block dabei
    # überschrieb; `modellhinweis` wurde in der Wandfassung der Hausseite aufgerufen und war
    # nie geschrieben worden. Drei bzw. ein Aufrufer blieben stehen, der Parser sah nichts, und
    # Xcode sagte „cannot find … in scope". Regel 12 prüft die **Argumente** eines Aufrufs,
    # nicht, ob der aufgerufene Name überhaupt existiert.
    #
    # **Wie das ohne Typauflösung geht.** Gesucht wird nur nach Namen ohne Punkt davor: `self`
    # ist dann der Empfänger, und `self` ist das Projekt. Alles mit Punkt (`haus.zustand`,
    # `$0.name`) bleibt aussen vor – dort entscheidet ein Typ, den dieses Skript nicht kennt.
    # Was von draussen ohne Punkt kommt – `max`, `withAnimation`, die `kSec`-Konstanten, die
    # Mitglieder von `Path`, die eine `extension` ohne `self.` aufruft – steht in
    # `tools/ios-bekannte-namen.txt`. Diese Liste ist der Preis der Regel: Sie ist kurz, und
    # jede Zeile darin hat jemand gelesen.
    #
    # Nur die App, nicht der Kern: der Kern übersetzt hier auf Linux, dort findet der Compiler
    # das selbst und besser.
    code = {pfad: nur_code(open(pfad, encoding="utf-8").read())
            for pfad in dateien + kernpfade}
    erklaert = erklaerte_namen(list(code.values())) | bekannte_namen() | SCHLUESSELWOERTER
    for pfad in dateien:
        kurz = os.path.relpath(pfad, APP)
        text = code[pfad]
        # `@escaping`, `#available`: hinter `@` und `#` steht kein Name des Projekts.
        for m in re.finditer(r"(?<![.\w$`@#])([a-z]\w*)", text):
            name = m.group(1)
            if name in erklaert:
                continue
            # Ein Doppelpunkt dahinter heisst Argumentname oder Fallmarke, kein Zugriff.
            if text[m.end():m.end() + 1] == ":":
                continue
            nr = text[:m.start()].count("\n") + 1
            maengel.append((kurz, nr, f"`{name}` wird benutzt, aber nirgends im Projekt "
                                      f"erklärt (wenn es von draussen kommt: "
                                      f"tools/ios-bekannte-namen.txt)"))

    # 14. Ein `static let` in einer Aufzählung, das so heisst wie einer ihrer Fälle.
    #
    # **Der Fehler des vierzehnten Laufs.** `Ansichtswahl.Form` hatte vier Fälle und für zwei
    # davon ein gleichnamiges `private static let … = Zuschnitt(…)`. Swift lässt das nicht zu:
    # Fall und statische Eigenschaft liegen im selben Namensraum. Xcode meldete zweierlei -
    # „invalid redeclaration" an der Eigenschaft und „cannot convert return expression of type
    # 'Form' to return type 'Zuschnitt'" dort, wo `Self.prognosekopf` den **Fall** traf statt
    # des Maßes. Die vier Maße mit Breitenklasse hiessen `…Breit`/`…Schmal` und stiessen
    # darum nicht an; nur die zwei ohne Variante taten es.
    #
    # **Warum das Gatter es vorher nicht sah.** `swiftc -parse` prüft nur die Form, nicht die
    # Namen; gebaut wird die Oberfläche erst auf dem Mac. Das Muster ist aber ohne jede
    # Typauflösung zu erkennen: Fälle und statische Eigenschaften einer Aufzählung stehen
    # beide auf ihrer flachen Ebene.
    for pfad in dateien + kernpfade:
        kurz = os.path.relpath(pfad, APP if pfad in dateien else KERN)
        text = code[pfad] if pfad in code else nur_code(open(pfad, encoding="utf-8").read())
        for m in re.finditer(r"\benum\s+(\w+)[^{\n]*\{", text):
            koerper = flache_ebene(klammerblock(text, m.end() - 1))
            faelle = set()
            for z in re.finditer(r"^\s*(?:indirect\s+)?case\s+(.+)$", koerper, re.M):
                for stueck in z.group(1).split(","):
                    name = re.match(r"\s*`?(\w+)`?", stueck)
                    if name:
                        faelle.add(name.group(1))
            for z in re.finditer(r"\bstatic\s+(?:let|var)\s+(\w+)", koerper):
                if z.group(1) not in faelle:
                    continue
                nr = text[:m.end() + z.start()].count("\n") + 1
                maengel.append((kurz, nr, f"`static let {z.group(1)}` heisst wie der Fall "
                                          f"`.{z.group(1)}` derselben Aufzaehlung "
                                          f"`{m.group(1)}` - Swift meldet das als doppelte "
                                          f"Erklaerung"))

    # 15. Ein Aufruf, der die Argumente eines Mitglieder-Anfangswerts vertauscht.
    #
    # **Der Fehler des fuenfzehnten Laufs.** `Berichtsseite` bekam ein neues Feld `gerechnetAm`
    # hinten angehaengt, waehrend alle sieben Aufrufstellen es vor `nebenfehler` nannten. Jeder
    # einzelne Name war richtig - Regel 12 prueft genau das und schwieg -, nur die Reihenfolge
    # war es nicht. Auf Linux faellt das nicht auf, weil `swiftc -parse` die Form prueft und
    # nicht die Zuordnung; der Mac brach ab mit "argument 'nebenfehler' must precede argument
    # 'gerechnetAm'", und `main` war zweieinhalb Stunden rot.
    #
    # **Ohne Typauflösung geht das, weil der Mitglieder-Anfangswert keine Freiheit laesst.** Die
    # genannten Argumente muessen eine Teilfolge der Feldreihenfolge sein; was fehlt, hat einen
    # Vorgabewert, und was zu viel ist, meldet Regel 12. Geprueft werden nur Verbunde ohne
    # eigenen `init` (siehe `feldreihenfolgen`) und nur Aufrufe in der App - im Kern findet der
    # Compiler es hier auf Linux selbst und besser.
    reihen = feldreihenfolgen(dateien + kernpfade)
    for pfad in dateien:
        kurz = os.path.relpath(pfad, APP)
        ohne = ohne_kommentare(open(pfad, encoding="utf-8").read())
        for name, felder in reihen.items():
            if name in doppeldeutig:
                continue
            rang = {f: i for i, f in enumerate(felder)}
            for versatz, rumpf in aufrufe(ohne, name):
                genannt = [a for a in arg_namen(rumpf) if a in rang]
                raenge = [rang[a] for a in genannt]
                if raenge == sorted(raenge):
                    continue
                soll = [f for f in felder if f in set(genannt)]
                nr = ohne[:versatz].count("\n") + 1
                maengel.append((kurz, nr, f"{name}(...) nennt {genannt}, der gemerkte "
                                          f"Anfangswert verlangt aber {soll} - Swift meldet "
                                          f"\"argument must precede argument\""))

    print(f"{len(dateien)} Dateien geprüft, {len(felder)} Schemafelder und "
          f"{len(bausteine)} Bausteine als Maßstab.")
    if maengel:
        print(f"\n{len(maengel)} Fund(e):", file=sys.stderr)
        for kurz, nr, satz in sorted(set(maengel)):
            print(f"  {kurz}:{nr}  {satz}", file=sys.stderr)
        return 1
    print("Keine der fünfzehn geprüften Fehlerarten gefunden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
