#!/usr/bin/env python3
"""OpenAPI -> Swift: Codable-Typen fuer die iOS-App.

Das Gegenstueck zu `tools/gen-types.sh`, das dasselbe Schema nach TypeScript uebersetzt. Die App
holt ihre Modelle also aus derselben Quelle wie das Dashboard, und ein Feld, das in der API
umbenannt wird, faellt beim naechsten Lauf auf.

    tools/gen-swift.py            # schreibt apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift
    tools/gen-swift.py --pruefen  # schreibt nichts, meldet nur Abweichungen (fuer die CI)

**Warum ein eigener Generator und nicht openapi-generator.** Der erzeugt fuer dieses Schema
mehrere hundert Dateien samt eigener Netzschicht, Alamofire-Abhaengigkeit und einem
Namensschema, das `message_de` zu `messageDe` macht und `t_c_1` zu `tC1` verstuemmelt. Hier
werden nur Typen gebraucht: 177 Strukturen, sieben Aufzaehlungen, keine Abhaengigkeit.

**Nachsichtig beim Lesen.** Listen und Woerterbuecher, die fehlen, werden leer; wahlfreie Felder
werden `nil`. Nur Pflichtfelder mit einem Einzelwert muessen wirklich da sein - ein fehlendes
`pv_power_kw` soll auffallen und nicht als 0,0 kW an der Wand stehen. Das nimmt dem Client genau
die Handarbeit ab, die `apps/web/src/lib/api/client.ts` heute mit `?? []` leistet.
"""

from __future__ import annotations

import argparse
import json
import keyword as _py_keyword
import re
import sys
from pathlib import Path
from typing import Any

WURZEL = Path(__file__).resolve().parent.parent
SCHEMA = WURZEL / "docs" / "openapi.json"
ZIEL = WURZEL / "apps" / "ios" / "DuckCurveKit" / "Sources" / "DuckCurveKit" / "Modelle" / "Schema.swift"

# Swift-Schluesselwoerter, die als Eigenschaftsname mit Gegenstrichen geschrieben werden muessen.
SWIFT_RESERVIERT = {
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import",
    "init", "inout", "internal", "let", "open", "operator", "private", "precedencegroup",
    "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var",
    "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough",
    "for", "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while",
    "as", "any", "await", "catch", "false", "is", "nil", "rethrows", "self", "Self", "super",
    "throw", "throws", "true", "try", "Type", "Protocol", "description", "hash", "hashValue",
}


def camel(name: str) -> str:
    """`heat_pump_power_kw` -> `heatPumpPowerKw`. Ziffern bleiben, wo sie stehen."""
    stuecke = [s for s in name.split("_") if s != ""]
    if not stuecke:
        return "feld"
    kopf = stuecke[0]
    kopf = kopf[0].lower() + kopf[1:] if kopf else kopf
    rest = "".join(s[0].upper() + s[1:] if s else "" for s in stuecke[1:])
    aus = kopf + rest
    if aus[0].isdigit():
        aus = "n" + aus
    return aus


def swift_name(name: str) -> str:
    c = camel(name)
    return f"`{c}`" if c in SWIFT_RESERVIERT else c


# Aufzaehlungswerte, die nur aus Satzzeichen bestehen, haben nach dem Saeubern keinen Namen
# mehr. `Literal["+", "-"]` wurde darum zweimal zu `case feld` - und zwei Faelle gleichen
# Namens uebersetzt Swift nicht: die erzeugte Datei war unbrauchbar, und zwar erst beim
# Bauen, nicht beim Erzeugen. Die gelaeufigen Zeichen bekommen deshalb ein Wort.
ZEICHENWORT = {
    "+": "plus",
    "-": "minus",
    "±": "plusminus",
    "*": "stern",
    "/": "schraegstrich",
    "\\": "umgekehrterSchraegstrich",
    "%": "prozent",
    "=": "gleich",
    "==": "gleich",
    "!=": "ungleich",
    "<": "kleiner",
    ">": "groesser",
    "<=": "kleinerGleich",
    ">=": "groesserGleich",
    "?": "fragezeichen",
    "!": "ausruf",
    "#": "raute",
    "&": "und",
    "|": "oder",
    "~": "welle",
    "@": "at",
    "—": "strich",
    "–": "strich",
    "": "leer",
}


def fallname(wert: str, vergeben: set[str]) -> str:
    """Der Swift-Name eines Aufzaehlungsfalls, eindeutig innerhalb seiner Aufzaehlung.

    Eindeutig heisst: wo zwei Werte auf denselben Namen fallen, wird der zweite
    durchnummeriert. Lieber ein haesslicher Name als eine Datei, die nicht uebersetzt.
    """
    roh = re.sub(r"[^0-9a-zA-Z_]", "_", wert).strip("_")
    fall = camel(roh) if roh else ZEICHENWORT.get(wert.strip(), "wert")
    grund = fall
    n = 2
    while fall in vergeben:
        fall = f"{grund}{n}"
        n += 1
    vergeben.add(fall)
    return f"`{fall}`" if fall in SWIFT_RESERVIERT else fall


# Schemanamen, die unter Swift nicht so heissen duerfen, wie sie im Schema heissen.
#
# `Measurement` ist in Foundation vergeben (`Measurement<UnitType>`, die Groesse mit Einheit), und
# ein Typ dieses Namens laesst sich in einer Datei, die Foundation einbindet, nicht mehr eindeutig
# nennen: der Compiler meldet „ambiguous for type lookup" an jeder Stelle. Das faellt nicht beim
# Erzeugen auf, sondern beim ersten Gebrauch - und dann an dreissig Stellen gleichzeitig.
#
# Umbenannt wird nur der Swift-Name. Am JSON aendert sich nichts: die Felder behalten ihre
# Schluessel, und `$ref` wird hier mit aufgeloest.
UMBENANNT = {
    "Measurement": "Messwert",
}


def typ_name(ref: str) -> str:
    roh = ref.rsplit("/", 1)[-1]
    return UMBENANNT.get(roh, roh)


class Generator:
    def __init__(self, schemas: dict[str, Any]) -> None:
        self.schemas = schemas
        self.enums: dict[str, list[str]] = {}

    # ------------------------------------------------------------------ Typen

    def swift_typ(self, p: dict[str, Any], pfad: str) -> tuple[str, bool]:
        """Swift-Typ zu einem Schemastueck. Rueckgabe: (Typ, optional?)."""
        if "$ref" in p:
            return typ_name(p["$ref"]), False

        if "anyOf" in p:
            zweige = p["anyOf"]
            ohne_null = [z for z in zweige if z.get("type") != "null"]
            nullbar = len(ohne_null) != len(zweige)
            if len(ohne_null) == 1:
                t, _ = self.swift_typ(ohne_null[0], pfad)
                return t, nullbar
            # Mehrere echte Zweige: ein Mischwert traegt alles, was JSON kann - `null` davon
            # eingeschlossen. Ein zusaetzliches `?` waere doppelt gemoppelt und zwingt jeden
            # Aufrufer zu zwei Auspackungen fuer einen Wert (`zeile["ts"]??`).
            return "Mischwert", False

        if "allOf" in p and len(p["allOf"]) == 1:
            return self.swift_typ(p["allOf"][0], pfad)

        if "enum" in p and p.get("type") in (None, "string"):
            # Aufzaehlung an der Eigenschaft selbst (nicht als eigenes Schema).
            name = pfad + "Wahl"
            self.enums[name] = [str(v) for v in p["enum"]]
            return name, False

        t = p.get("type")

        if t == "array":
            items = p.get("items")
            if items is None:
                # `prefixItems` ohne `items`: ein Tupel fester Laenge.
                return self.tupel_typ(p.get("prefixItems", []), pfad), False
            inner, inner_opt = self.swift_typ(items, pfad)
            return f"[{inner}{'?' if inner_opt else ''}]", False

        if t == "object":
            addl = p.get("additionalProperties")
            if isinstance(addl, dict) and addl:
                inner, inner_opt = self.swift_typ(addl, pfad)
                return f"[String: {inner}{'?' if inner_opt else ''}]", False
            return "[String: Mischwert]", False

        einfach = {"number": "Double", "integer": "Int", "string": "String", "boolean": "Bool"}
        if t in einfach:
            return einfach[t], False
        if t == "null":
            return "Mischwert", True
        # Ohne Typangabe (etwa `ValidationError.input`): alles ist moeglich.
        return "Mischwert", True

    def tupel_typ(self, prefix: list[dict[str, Any]], pfad: str) -> str:
        """Ein JSON-Tupel. Gleichartig -> `[Double]`, gemischt -> `[Mischwert]`.

        Swift-Tupel sind nicht `Codable`, und eine eigene Struktur je Stelle waere hier Unfug:
        `Deck.shell` ist eine Folge von Punkten, `CoverageSeriesOut.hours` eine Folge von
        Stunde-und-Zahl. Beide liest die App als Liste und greift mit `[0]`/`[1]` zu - genau so,
        wie das Dashboard es mit dem TypeScript-Tupel tut.
        """
        typen = {x.get("type") for x in prefix}
        if typen == {"number"} or typen == {"integer"} or typen == {"number", "integer"}:
            return "[Double]"
        if typen == {"string"}:
            return "[String]"
        return "[Mischwert]"

    # -------------------------------------------------------------- Strukturen

    def enum_block(self, name: str, werte: list[str]) -> str:
        zeilen = [
            "/// Aus dem Schema erzeugt. Unbekannte Werte landen in `.unbekannt`, damit eine neue",
            "/// Spielart im Dienst die App nicht stehen laesst.",
            f"public enum {name}: String, Codable, Sendable, Hashable, CaseIterable {{",
        ]
        vergeben = {"unbekannt"}
        for w in werte:
            zeilen.append(f'    case {fallname(w, vergeben)} = "{w}"')
        zeilen.append("    case unbekannt = \"—unbekannt—\"")
        zeilen.append("")
        zeilen.append("    public init(from decoder: any Decoder) throws {")
        zeilen.append("        let roh = try decoder.singleValueContainer().decode(String.self)")
        zeilen.append(f"        self = {name}(rawValue: roh) ?? .unbekannt")
        zeilen.append("    }")
        zeilen.append("}")
        return "\n".join(zeilen)

    def struct_block(self, name: str, v: dict[str, Any]) -> str:
        props: dict[str, Any] = v.get("properties") or {}
        pflicht = set(v.get("required") or [])
        doku = (v.get("description") or "").strip()

        felder: list[tuple[str, str, str, bool, str | None]] = []
        # (jsonName, swiftName, swiftTyp, optional, vorgabe)
        for pn, p in props.items():
            pfad = name + camel(pn)[0].upper() + camel(pn)[1:]
            t, nullbar = self.swift_typ(p, pfad)
            ist_pflicht = pn in pflicht
            vorgabe: str | None = None
            optional = nullbar or not ist_pflicht

            # Sammlungen bekommen eine leere Vorgabe statt `nil`: so braucht die Oberflaeche
            # kein `?? []` und eine fehlende Liste ist eine leere Liste, kein Sonderfall.
            if t.startswith("[") and not nullbar:
                vorgabe = "[]" if not t.startswith("[String:") else "[:]"
                optional = False
            elif t.startswith("[") and nullbar:
                optional = True

            felder.append((pn, swift_name(pn), t, optional, vorgabe))

        zeilen: list[str] = []
        if doku:
            for z in doku.splitlines():
                zeilen.append(f"/// {z}".rstrip())
        zeilen.append(f"public struct {name}: Codable, Sendable, Hashable {{")
        for pn, sn, t, opt, vorgabe in felder:
            zeilen.append(f"    public var {sn}: {t}{'?' if opt else ''}")
        if not felder:
            zeilen.append("    public init() {}")
            zeilen.append("}")
            return "\n".join(zeilen)

        # CodingKeys nur, wenn mindestens ein Name abweicht.
        braucht_keys = any(camel(pn) != pn for pn, _, _, _, _ in felder)
        if braucht_keys:
            zeilen.append("")
            zeilen.append("    public enum CodingKeys: String, CodingKey {")
            for pn, sn, _, _, _ in felder:
                nackt = sn.strip("`")
                zeilen.append(f'        case {sn} = "{pn}"' if nackt != pn else f"        case {sn}")
            zeilen.append("    }")

        # Erzeuger mit Vorgaben: so laesst sich ein Wert auch in Tests und Vorschauen bauen.
        zeilen.append("")
        args = []
        for pn, sn, t, opt, vorgabe in felder:
            nackt = sn.strip("`")
            if vorgabe is not None:
                args.append(f"{nackt}: {t} = {vorgabe}")
            elif opt:
                args.append(f"{nackt}: {t}? = nil")
            else:
                args.append(f"{nackt}: {t}")
        zeilen.append(f"    public init({', '.join(args)}) {{")
        for pn, sn, _, _, _ in felder:
            zeilen.append(f"        self.{sn} = {sn.strip('`')}")
        zeilen.append("    }")

        # Nachsichtiges Lesen.
        zeilen.append("")
        zeilen.append("    public init(from decoder: any Decoder) throws {")
        zeilen.append("        let c = try decoder.container(keyedBy: CodingKeys.self)")
        for pn, sn, t, opt, vorgabe in felder:
            if vorgabe is not None:
                zeilen.append(
                    f"        self.{sn} = try c.decodeIfPresent({t}.self, forKey: .{sn}) ?? {vorgabe}"
                )
            elif opt:
                zeilen.append(f"        self.{sn} = try c.decodeIfPresent({t}.self, forKey: .{sn})")
            else:
                zeilen.append(f"        self.{sn} = try c.decode({t}.self, forKey: .{sn})")
        zeilen.append("    }")
        zeilen.append("}")
        return "\n".join(zeilen)

    def lauf(self) -> str:
        teile: list[str] = []
        for roh in sorted(self.schemas):
            v = self.schemas[roh]
            name = UMBENANNT.get(roh, roh)
            if "enum" in v:
                self.enums[name] = [str(x) for x in v["enum"]]
                continue
            teile.append(self.struct_block(name, v))

        enum_teile = [self.enum_block(n, w) for n, w in sorted(self.enums.items())]

        kopf = '''// Erzeugt von tools/gen-swift.py aus docs/openapi.json. Nicht von Hand aendern.
//
// Dieselbe Quelle, aus der apps/web/src/lib/api/types.ts entsteht. Neu erzeugen mit
// `tools/gen-swift.py`, pruefen mit `tools/gen-swift.py --pruefen`.

import Foundation

// MARK: - Aufzaehlungen

'''
        return kopf + "\n\n".join(enum_teile) + "\n\n// MARK: - Strukturen\n\n" + "\n\n".join(teile) + "\n"


def doppelt_melden(text: str) -> None:
    """Haelt fest, dass in keiner Aufzaehlung zwei Faelle gleich heissen.

    **Warum das geprueft wird.** `Literal["+", "-"]` ergab zweimal `case feld`, weil beide
    Werte nach dem Saeubern keinen Namen mehr hatten. Das faellt beim Erzeugen nicht auf - die
    Datei entsteht, sieht richtig aus und laesst sich nur nicht uebersetzen, und zwar erst auf
    dem Mac, Tage spaeter. ``fallname`` macht Namen inzwischen eindeutig; diese Pruefung
    schlaegt an, falls das wieder auseinanderfaellt.
    """
    name = ""
    gesehen: set[str] = set()
    for zeile in text.splitlines():
        if zeile.startswith("public enum "):
            name = zeile.split()[2].rstrip(":")
            gesehen = set()
        elif zeile.startswith("    case "):
            fall = zeile.split()[1].strip("`")
            if fall in gesehen:
                raise SystemExit(f"{name}: der Fall {fall} kommt zweimal vor.")
            gesehen.add(fall)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pruefen", action="store_true", help="nur vergleichen, nichts schreiben")
    args = ap.parse_args()

    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    text = Generator(schema["components"]["schemas"]).lauf()
    doppelt_melden(text)

    if args.pruefen:
        alt = ZIEL.read_text(encoding="utf-8") if ZIEL.exists() else ""
        if alt != text:
            print(f"{ZIEL.relative_to(WURZEL)} ist nicht auf dem Stand von docs/openapi.json.", file=sys.stderr)
            print("Neu erzeugen mit: tools/gen-swift.py", file=sys.stderr)
            return 1
        print(f"{ZIEL.relative_to(WURZEL)} ist aktuell.")
        return 0

    ZIEL.parent.mkdir(parents=True, exist_ok=True)
    ZIEL.write_text(text, encoding="utf-8")
    zahl = text.count("public struct ")
    aufz = text.count("public enum ") - text.count("public enum CodingKeys")
    print(f"{ZIEL.relative_to(WURZEL)}: {zahl} Strukturen, {aufz} Aufzaehlungen, {len(text.splitlines())} Zeilen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
