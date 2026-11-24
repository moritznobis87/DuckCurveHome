#!/usr/bin/env python3
"""Die Zeichen des Dashboards nach Swift uebernehmen.

`apps/web/src/components/ui/Icon.tsx` haelt 25 Zeichen als SVG-Fragmente auf einem 24-px-Raster,
von Hand gesetzt und seit Monaten so, wie sie aussehen sollen. Dieses Werkzeug uebertraegt sie
nach `apps/ios/DuckCurveHome/Gestalt/Zeichendaten.swift`, damit sie nicht abgetippt werden
muessen und bei einer Aenderung nur an einer Stelle gepflegt werden.

Uebernommen werden `<path d="...">`, `<circle>` und `<rect>`. Kreise und Rechtecke werden zu
Pfadangaben gerechnet - der Leser auf der Swift-Seite kennt nur Pfade, und ein abgerundetes
Rechteck als vier Bezier-Ecken zu schreiben ist weniger Arbeit, als ihm zwei weitere Formen
beizubringen.

    tools/gen-zeichen.py
    tools/gen-zeichen.py --pruefen
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "apps" / "web" / "src" / "components" / "ui" / "Icon.tsx"
# Die Zeichendaten liegen im Kern und nicht in der App: es sind Zeichenketten, kein SwiftUI, und
# so laesst sich auf dem Pruefrechner nachweisen, dass alle Pfade vom Leser verstanden werden.
ZIEL = (
    WURZEL / "apps" / "ios" / "DuckCurveKit" / "Sources" / "DuckCurveKit"
    / "Gestalt" / "Zeichendaten.swift"
)

# Der Kreisbogen als Bezier: vier Viertel mit diesem Griffmass treffen den Kreis auf
# ein Zehntausendstel genau. Die Zahl ist (4/3)·(√2−1).
KAPPA = 0.5522847498307936


def kreis_als_pfad(cx: float, cy: float, r: float) -> str:
    k = r * KAPPA
    return (
        f"M {cx} {cy - r} "
        f"C {cx + k} {cy - r} {cx + r} {cy - k} {cx + r} {cy} "
        f"C {cx + r} {cy + k} {cx + k} {cy + r} {cx} {cy + r} "
        f"C {cx - k} {cy + r} {cx - r} {cy + k} {cx - r} {cy} "
        f"C {cx - r} {cy - k} {cx - k} {cy - r} {cx} {cy - r} Z"
    )


def rechteck_als_pfad(x: float, y: float, w: float, h: float, rx: float) -> str:
    r = min(rx, w / 2, h / 2)
    if r <= 0:
        return f"M {x} {y} L {x + w} {y} L {x + w} {y + h} L {x} {y + h} Z"
    k = r * KAPPA
    return (
        f"M {x + r} {y} "
        f"L {x + w - r} {y} "
        f"C {x + w - r + k} {y} {x + w} {y + r - k} {x + w} {y + r} "
        f"L {x + w} {y + h - r} "
        f"C {x + w} {y + h - r + k} {x + w - r + k} {y + h} {x + w - r} {y + h} "
        f"L {x + r} {y + h} "
        f"C {x + r - k} {y + h} {x} {y + h - r + k} {x} {y + h - r} "
        f"L {x} {y + r} "
        f"C {x} {y + r - k} {x + r - k} {y} {x + r} {y} Z"
    )


def zahl(s: str | None, vorgabe: float = 0.0) -> float:
    return float(s) if s is not None else vorgabe


def formen(fragment: str) -> list[tuple[str, bool]]:
    """Die Formen eines Zeichens als (Pfadangabe, gefuellt?)."""
    aus: list[tuple[str, bool]] = []
    for treffer in re.finditer(r"<(path|circle|rect)\b([^>]*)/?>", fragment):
        art, attr = treffer.group(1), treffer.group(2)
        gefuellt = 'fill="currentColor"' in attr

        if art == "path":
            d = re.search(r'\bd="([^"]*)"', attr)
            if d:
                aus.append((d.group(1).strip(), gefuellt))
        elif art == "circle":
            cx = zahl(hol(attr, "cx"))
            cy = zahl(hol(attr, "cy"))
            r = zahl(hol(attr, "r"))
            aus.append((kreis_als_pfad(cx, cy, r), gefuellt))
        elif art == "rect":
            aus.append((
                rechteck_als_pfad(
                    zahl(hol(attr, "x")), zahl(hol(attr, "y")),
                    zahl(hol(attr, "width")), zahl(hol(attr, "height")),
                    zahl(hol(attr, "rx")),
                ),
                gefuellt,
            ))
    return aus


def hol(attr: str, name: str) -> str | None:
    m = re.search(rf'\b{name}="([^"]*)"', attr)
    return m.group(1) if m else None


def lies_zeichen() -> dict[str, str]:
    text = QUELLE.read_text(encoding="utf-8")
    anfang = text.index("const PATHS")
    # Bis zur schliessenden Klammer des Objekts.
    ende = text.index("\n};", anfang)
    block = text[anfang:ende]
    gefunden: dict[str, str] = {}
    for m in re.finditer(r"^  ([a-zA-Z][a-zA-Z0-9]*):\s*'(.*)',\s*$", block, re.MULTILINE):
        gefunden[m.group(1)] = m.group(2)
    return gefunden


def swift_name(name: str) -> str:
    """Die deutschen Namen, unter denen die Zeichen in der App stehen."""
    tabelle = {
        "duck": "ente", "bolt": "blitz", "flame": "flamme", "euro": "euro", "gear": "zahnrad",
        "moon": "mond", "sun": "sonne", "home": "haus", "house": "haus", "grid": "netz",
        "battery": "batterie", "pump": "waermepumpe", "car": "auto", "stove": "ofen",
        "thermo": "thermometer", "bulb": "lampe", "coffee": "kaffee", "door": "tuer",
        "shield": "schild", "alert": "warnung", "clock": "uhr", "calendar": "kalender",
        "chart": "diagramm", "table": "tabelle", "dashboard": "anzeige",
    }
    return tabelle.get(name, name)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pruefen", action="store_true")
    args = ap.parse_args()

    zeichen = lies_zeichen()
    if not zeichen:
        print("In Icon.tsx keine Zeichen gefunden.", file=sys.stderr)
        return 1

    zeilen = [
        "// Erzeugt von tools/gen-zeichen.py aus apps/web/src/components/ui/Icon.tsx.",
        "// Nicht von Hand aendern - neu erzeugen mit `tools/gen-zeichen.py`.",
        "//",
        "// Die Zeichen des Dashboards: 25 Strichzeichnungen auf einem 24-Punkt-Raster, 1,75 Punkt",
        "// Strich, runde Enden, kein Emoji. Kreise und Rechtecke sind beim Uebernehmen zu",
        "// Pfadangaben gerechnet worden.",
        "",
        "/// Die Zeichen, unter ihren Namen in der App.",
        "public enum Zeichenart: String, Sendable, Hashable, CaseIterable {",
    ]
    namen = sorted({swift_name(n) for n in zeichen})
    for n in namen:
        zeilen.append(f"    case {n}")
    zeilen.append("}")
    zeilen.append("")
    zeilen.append("extension Zeichenart {")
    zeilen.append("    /// Das Raster, auf dem alle Zeichen gezeichnet sind.")
    zeilen.append("    public static let raster: Double = 24")
    zeilen.append("")
    zeilen.append("    /// Die Formen dieses Zeichens: Pfadangabe und ob sie gefuellt wird.")
    zeilen.append("    public var formen: [(d: String, gefuellt: Bool)] {")
    zeilen.append("        switch self {")

    # Nach Swift-Namen gruppieren (home und house sind dieselbe Zeichnung).
    nach_swift: dict[str, list[tuple[str, bool]]] = {}
    for roh, fragment in zeichen.items():
        s = swift_name(roh)
        if s not in nach_swift:
            nach_swift[s] = formen(fragment)

    for n in namen:
        teile = nach_swift[n]
        if not teile:
            zeilen.append(f"        case .{n}: return []")
            continue
        zeilen.append(f"        case .{n}:")
        zeilen.append("            return [")
        for d, gefuellt in teile:
            sauber = " ".join(d.split())
            zeilen.append(f'                (d: "{sauber}", gefuellt: {str(gefuellt).lower()}),')
        zeilen.append("            ]")
    zeilen.append("        }")
    zeilen.append("    }")
    zeilen.append("}")
    text = "\n".join(zeilen) + "\n"

    if args.pruefen:
        alt = ZIEL.read_text(encoding="utf-8") if ZIEL.exists() else ""
        if alt != text:
            print(f"{ZIEL.relative_to(WURZEL)} ist nicht auf dem Stand von Icon.tsx.", file=sys.stderr)
            return 1
        print(f"{ZIEL.relative_to(WURZEL)} ist aktuell.")
        return 0

    ZIEL.parent.mkdir(parents=True, exist_ok=True)
    ZIEL.write_text(text, encoding="utf-8")
    print(f"{ZIEL.relative_to(WURZEL)}: {len(namen)} Zeichen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
