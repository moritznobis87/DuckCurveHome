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
6. **`dazu` und `farbe` in der falschen Reihenfolge.** Bei `Zeile` und `Kacheldaten` sind die
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
    KETTE = r"((?:\w+(?:\(\))?[.?]+)*)(\w+)"

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

        # 5. Reihenfolge der Argumente, mit echtem Klammernzählen
        for name, zuerst, danach in REIHENFOLGE:
            for versatz, rumpf in aufrufe(text, name):
                namen = arg_namen(rumpf)
                if zuerst in namen and danach in namen and namen.index(danach) < namen.index(zuerst):
                    nr = text[:versatz].count("\n") + 1
                    maengel.append((kurz, nr, f"{name}(…): „{danach}“ steht vor „{zuerst}“ - "
                                              f"die Felder sind die Argumente"))

    print(f"{len(dateien)} Dateien geprüft, {len(felder)} Schemafelder als Maßstab.")
    if maengel:
        print(f"\n{len(maengel)} Fund(e):", file=sys.stderr)
        for kurz, nr, satz in sorted(set(maengel)):
            print(f"  {kurz}:{nr}  {satz}", file=sys.stderr)
        return 1
    print("Keine der sechs geprüften Fehlerarten gefunden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
