#!/usr/bin/env python3
"""Das App-Symbol: die Marken-Ente, aus der Markendatei gezeichnet.

    tools/gen-appicon.py            # schreiben
    tools/gen-appicon.py --pruefen  # nur pruefen, ob es zur Quelle passt

**Warum nicht die Entenkurve.** Hier stand sie: die Lastkurve als Linie, darunter Balken.
Auf dem Startbildschirm ist ein Symbol 60 Punkte gross, und dann sind die Balken weg und die
Kurve ein Kringel - ein Diagramm ist kein Zeichen. Im Dashboard ist genau dieser Fehler
schon einmal gemacht und wieder behoben worden; der Kommentar in `apps/web/public/favicon.svg`
sagt es deutlich: „genau der Fehler der Entenkurve, die vorher hier stand. Diese Ente ist
reine Flaeche."

**Darum dieselbe Ente wie ueberall.** Sie wird aus `favicon.svg` gelesen und nicht
abgezeichnet - eine Quelle, wie bei `gen-zeichen.py` und `gen-swift.py`. Aendert sich die
Marke, aendert sich das Symbol beim naechsten Lauf mit.

**Was anders ist als im Favicon:** keine runden Ecken. iOS legt seine eigene Maske darueber;
eine mitgezeichnete Rundung ergaebe einen hellen Saum. Die Flaeche geht bis an den Rand.
"""

from __future__ import annotations

import argparse
import io
import math
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

WURZEL = Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "apps" / "web" / "public" / "favicon.svg"
ZIEL = (
    WURZEL / "apps" / "ios" / "DuckCurveHome" / "Ressourcen"
    / "Assets.xcassets" / "AppIcon.appiconset"
)
KANTE = 1024
# Vierfach zeichnen und verkleinern: PIL kann Polygone nicht glaetten, das Verkleinern schon.
UEBER = 4

CONTENTS = """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "tools/gen-appicon.py",
    "version" : 1
  }
}
"""
ASSETS_CONTENTS = """{
  "info" : {
    "author" : "tools/gen-appicon.py",
    "version" : 1
  }
}
"""


# ────────────────────────────────── SVG lesen ───────────────────────────────

def zahlen(text: str) -> list[float]:
    """Alle Zahlen eines Pfadstuecks, auch `12-3` und `.5.5` ohne Trenner."""
    return [float(t) for t in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", text)]


def kurve(p0, p1, p2, p3, schritte: int = 48):
    """Eine kubische Bezierkurve als Punktzug."""
    aus = []
    for i in range(1, schritte + 1):
        t = i / schritte
        u = 1 - t
        aus.append((
            u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
            u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
        ))
    return aus


def pfad_zu_punkten(d: str) -> list[list[tuple[float, float]]]:
    """Ein `d`-Attribut zu Polygonzuegen.

    Es werden die Befehle gelesen, die in den Markendateien vorkommen: M/m, L/l, H/h, V/v,
    C/c, S/s, Z/z. Mehr braucht es nicht, und mehr zu koennen hiesse, Fehler stillschweigend
    hinzunehmen - ein unbekannter Befehl wirft.
    """
    zuege: list[list[tuple[float, float]]] = []
    jetzt: list[tuple[float, float]] = []
    x = y = 0.0
    anfang = (0.0, 0.0)
    # Der zweite Kontrollpunkt der letzten Kurve - fuer `s`/`S`.
    letzte_c2: tuple[float, float] | None = None

    for befehl, rest in re.findall(r"([MmLlHhVvCcSsZz])([^MmLlHhVvCcSsZz]*)", d):
        w = zahlen(rest)
        rel = befehl.islower()
        gross = befehl.upper()

        if gross == "Z":
            if jetzt:
                zuege.append(jetzt)
                jetzt = []
            x, y = anfang
            letzte_c2 = None
            continue

        if gross == "M":
            for i in range(0, len(w), 2):
                nx, ny = (x + w[i], y + w[i + 1]) if rel else (w[i], w[i + 1])
                if i == 0:
                    if jetzt:
                        zuege.append(jetzt)
                    jetzt = [(nx, ny)]
                    anfang = (nx, ny)
                else:
                    jetzt.append((nx, ny))
                x, y = nx, ny
            letzte_c2 = None
        elif gross in ("L", "H", "V"):
            schritt = {"L": 2, "H": 1, "V": 1}[gross]
            for i in range(0, len(w), schritt):
                if gross == "L":
                    nx, ny = (x + w[i], y + w[i + 1]) if rel else (w[i], w[i + 1])
                elif gross == "H":
                    nx, ny = (x + w[i], y) if rel else (w[i], y)
                else:
                    nx, ny = (x, y + w[i]) if rel else (x, w[i])
                jetzt.append((nx, ny))
                x, y = nx, ny
            letzte_c2 = None
        elif gross == "C":
            for i in range(0, len(w), 6):
                a = w[i:i + 6]
                pts = [(x + a[k], y + a[k + 1]) if rel else (a[k], a[k + 1]) for k in (0, 2, 4)]
                jetzt += kurve((x, y), pts[0], pts[1], pts[2])
                letzte_c2 = pts[1]
                x, y = pts[2]
        elif gross == "S":
            for i in range(0, len(w), 4):
                a = w[i:i + 4]
                # Der erste Kontrollpunkt ist die Spiegelung des letzten zweiten.
                c1 = (2 * x - letzte_c2[0], 2 * y - letzte_c2[1]) if letzte_c2 else (x, y)
                c2 = (x + a[0], y + a[1]) if rel else (a[0], a[1])
                e = (x + a[2], y + a[3]) if rel else (a[2], a[3])
                jetzt += kurve((x, y), c1, c2, e)
                letzte_c2 = c2
                x, y = e
        else:
            raise ValueError(f"Unbekannter Pfadbefehl: {befehl}")

    if jetzt:
        zuege.append(jetzt)
    return zuege


def kreis_zu_punkten(cx: float, cy: float, r: float, schritte: int = 180):
    return [[
        (cx + r * math.cos(2 * math.pi * i / schritte),
         cy + r * math.sin(2 * math.pi * i / schritte))
        for i in range(schritte)
    ]]


def formen(svg: str) -> list[tuple[str, list[list[tuple[float, float]]]]]:
    """Die Formen der Datei, in ihrer Reihenfolge, mit ihrer Farbe.

    Nur die Gruppe mit der Ente wird gelesen; die weisse Kachel darunter faellt weg, denn das
    Symbol bekommt seine Flaeche bis an den Rand.
    """
    # Kommentare raus - darin stehen Pfade als Prosa.
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S)
    g = re.search(r'<g transform="translate\(([-\d.]+)\s+([-\d.]+)\)\s*scale\(([\d.]+)\)"\s*>'
                  r"(.*?)</g>", svg, re.S)
    if not g:
        raise ValueError("Die Gruppe mit der Ente steht nicht wie erwartet in der Datei.")
    vx, vy, s = float(g.group(1)), float(g.group(2)), float(g.group(3))

    def um(zuege):
        return [[(vx + s * px, vy + s * py) for px, py in z] for z in zuege]

    aus = []
    for stueck in re.findall(r"<(path|circle)\b([^>]*)/?>", g.group(4)):
        art, attr = stueck
        farbe = (re.search(r'fill="([^"]+)"', attr) or [None, "#000000"])[1]
        if art == "path":
            d = re.search(r'\sd="([^"]+)"', attr).group(1)
            aus.append((farbe, um(pfad_zu_punkten(d))))
        else:
            cx = float(re.search(r'cx="([-\d.]+)"', attr).group(1))
            cy = float(re.search(r'cy="([-\d.]+)"', attr).group(1))
            r = float(re.search(r'r="([-\d.]+)"', attr).group(1))
            aus.append((farbe, um(kreis_zu_punkten(cx, cy, r))))
    return aus


# ────────────────────────────────── zeichnen ────────────────────────────────

def zeichne() -> Image.Image:
    svg = QUELLE.read_text(encoding="utf-8")
    kachel = (re.search(r'<rect[^>]*fill="(#[0-9A-Fa-f]{6})"', svg) or [None, "#FFFFFF"])[1]
    sicht = re.search(r'viewBox="([-\d.\s]+)"', svg).group(1).split()
    vb = [float(t) for t in sicht]
    # Die Kachel geht bis an den Rand: iOS legt seine eigene Rundung darueber.
    bild = Image.new("RGB", (KANTE * UEBER, KANTE * UEBER), kachel)
    stift = ImageDraw.Draw(bild)
    massstab = KANTE * UEBER / vb[2]

    for farbe, zuege in formen(svg):
        for zug in zuege:
            if len(zug) < 3:
                continue
            stift.polygon(
                [((px - vb[0]) * massstab, (py - vb[1]) * massstab) for px, py in zug],
                fill=farbe,
            )
    return bild.resize((KANTE, KANTE), Image.LANCZOS)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pruefen", action="store_true", help="nur pruefen, nichts schreiben")
    args = ap.parse_args()

    png = ZIEL / "AppIcon.png"
    neu = zeichne()
    puffer = io.BytesIO()
    neu.save(puffer, "PNG", optimize=True)
    roh = puffer.getvalue()

    if args.pruefen:
        if not png.exists():
            print(f"{png} fehlt - erzeugen mit tools/gen-appicon.py", file=sys.stderr)
            return 1
        if png.read_bytes() != roh:
            print(f"{png} passt nicht mehr zu {QUELLE.name} - neu erzeugen mit "
                  f"tools/gen-appicon.py", file=sys.stderr)
            return 1
        print(f"{png.relative_to(WURZEL)} ist auf dem Stand von {QUELLE.name}.")
        return 0

    ZIEL.mkdir(parents=True, exist_ok=True)
    png.write_bytes(roh)
    (ZIEL / "Contents.json").write_text(CONTENTS, encoding="utf-8")
    (ZIEL.parent / "Contents.json").write_text(ASSETS_CONTENTS, encoding="utf-8")
    print(f"{png.relative_to(WURZEL)} geschrieben ({len(roh)} Bytes), aus {QUELLE.name}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
