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
7. **`dazu` und `farbe` in der falschen Reihenfolge.** Bei `Zeile` und `Kacheldaten` sind die
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


def main() -> int:
    felder, aufzaehlungen = schema_lesen()
    nie_wahlfrei = {n for n, ts in felder.items() if all(not t.endswith("?") for t in ts)}
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
        benutzt = sorted({n for n in kerntypen if re.search(rf"\b{n}\b", text)})
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

    print(f"{len(dateien)} Dateien geprüft, {len(felder)} Schemafelder als Maßstab.")
    if maengel:
        print(f"\n{len(maengel)} Fund(e):", file=sys.stderr)
        for kurz, nr, satz in sorted(set(maengel)):
            print(f"  {kurz}:{nr}  {satz}", file=sys.stderr)
        return 1
    print("Keine der elf geprüften Fehlerarten gefunden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
