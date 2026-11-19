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

**Was anders ist als im Favicon.** Die Formen der Ente kommen aus der Quelle, die Buehne
nicht - auf dem Startbildschirm ist die weisse Kachel des Favicons ein greller Fleck ohne Tiefe:

- Der Grund ist Petrol mit einem Verlauf, die Ente darauf hell. Koerper- und Kachelfarbe der
  Quelle tauschen die Plaetze, der Schnabel behaelt seine.
- Hinter dem Kopf steht die Sonne, in der Farbe des Schnabels. Sie ist der Bezug zum Thema,
  und sie ist Flaeche: bei 60 Punkten bleibt sie ein Kreis und wird kein Kringel.
- Die Ente bekommt einen Fluegel, einen Ton dunkler als der Koerper. Im Favicon waere er bei
  16 Pixeln Matsch; hier nimmt er der Ente das Gestempelte.
- Die Ente ist kleiner gesetzt. Schnabel und Schwanz hielten im Favicon nur ein Zehntel
  Abstand zum Rand, und die Rundung von iOS kam ihnen zu nah.
- Keine runden Ecken. iOS legt seine eigene Maske darueber; eine mitgezeichnete Rundung
  ergaebe einen Saum. Der Grund geht bis an den Rand.
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

# ─────────────────────────── was nur das Symbol hat ─────────────────────────
# Alle Masse gelten fuer die Kante von 1024.

# Der Grund: Petrol, oben heller als unten.
GRUND_OBEN = (0x1D, 0x52, 0x69)
GRUND_UNTEN = (0x0A, 0x22, 0x2E)
# Die Sonne: Mitte x, Mitte y, Halbmesser. Am Rand hat sie die Farbe des Schnabels, zur Mitte
# hin wird sie heller. Sie reicht ueber die Kerbe am Schwanz hinaus: endete sie knapp davor,
# bliebe dort ein duenner dunkler Spalt stehen.
SONNE = (660.0, 355.0, 240.0)
SONNE_MITTE = (0xFF, 0xC5, 0x33)
SONNE_RINGE = 64
# Wohin die Ente kommt: Verschiebung x, y und Massstab, auf die Koordinaten der Quelle
# angewandt. Die Lage, die sie im Favicon hat, wird nicht uebernommen.
ENTE = (-40.0, 215.0, 0.74)
# Der Fluegel, in den Koordinaten der Ente. Er liegt ganz im Koerper.
FLUEGEL = "M520 545c95-30 215-15 330 50-30 120-150 185-270 160-85-18-110-120-60-210z"
FLUEGEL_FARBE = "#C9DCE5"

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
    """Die Formen der Ente, in ihrer Reihenfolge, mit ihrer Farbe.

    Nur die Gruppe mit der Ente wird gelesen, und zwar in ihren eigenen Koordinaten: Kachel
    und Lage gehoeren dem Favicon, das Symbol setzt die Ente selbst (`ENTE`).
    """
    # Kommentare raus - darin stehen Pfade als Prosa.
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S)
    g = re.search(r'<g transform="translate\(([-\d.]+)\s+([-\d.]+)\)\s*scale\(([\d.]+)\)"\s*>'
                  r"(.*?)</g>", svg, re.S)
    if not g:
        raise ValueError("Die Gruppe mit der Ente steht nicht wie erwartet in der Datei.")
    aus = []
    for stueck in re.findall(r"<(path|circle)\b([^>]*)/?>", g.group(4)):
        art, attr = stueck
        farbe = (re.search(r'fill="([^"]+)"', attr) or [None, "#000000"])[1]
        if art == "path":
            d = re.search(r'\sd="([^"]+)"', attr).group(1)
            aus.append((farbe, pfad_zu_punkten(d)))
        else:
            cx = float(re.search(r'cx="([-\d.]+)"', attr).group(1))
            cy = float(re.search(r'cy="([-\d.]+)"', attr).group(1))
            r = float(re.search(r'r="([-\d.]+)"', attr).group(1))
            aus.append((farbe, kreis_zu_punkten(cx, cy, r)))
    return aus


# ────────────────────────────────── zeichnen ────────────────────────────────

def rgb(farbe: str) -> tuple[int, int, int]:
    """`#RRGGBB` als drei Zahlen."""
    return tuple(int(farbe[i:i + 2], 16) for i in (1, 3, 5))


def misch(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    """Zwischen zwei Farben: bei 0 ganz `a`, bei 1 ganz `b`."""
    return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))


def zeichne() -> Image.Image:
    svg = QUELLE.read_text(encoding="utf-8")
    kachel = (re.search(r'<rect[^>]*fill="(#[0-9A-Fa-f]{6})"', svg) or [None, "#FFFFFF"])[1]
    ente = formen(svg)
    # Koerper, Schnabel, Auge - auf diese Reihenfolge stuetzt sich alles Weitere. Kommt die
    # Marke einmal anders daher, soll das auffallen und nicht ein falsches Symbol ergeben.
    if len(ente) != 3:
        raise ValueError(f"Erwartet sind Koerper, Schnabel und Auge - gefunden: {len(ente)} Formen.")
    koerper, schnabel = ente[0][0], ente[1][0]
    # Die Ente steht hell auf dunklem Grund: Koerper und Kachel tauschen die Farbe, und das
    # Auge, das im Favicon die Kachel durchscheinen liess, wird damit dunkel.
    tausch = {koerper.upper(): kachel, kachel.upper(): koerper}
    ente.insert(1, (FLUEGEL_FARBE, pfad_zu_punkten(FLUEGEL)))

    kante = KANTE * UEBER
    bild = Image.new("RGB", (kante, kante))
    stift = ImageDraw.Draw(bild)

    for y in range(kante):
        stift.line([(0, y), (kante, y)], fill=misch(GRUND_OBEN, GRUND_UNTEN, y / (kante - 1)))

    # Die Sonne als Ringe von aussen nach innen - PIL kennt keinen Verlauf im Kreis.
    sx, sy, sr = (w * UEBER for w in SONNE)
    for i in range(SONNE_RINGE):
        t = i / SONNE_RINGE
        r = sr * (1 - t)
        stift.ellipse([sx - r, sy - r, sx + r, sy + r], fill=misch(rgb(schnabel), SONNE_MITTE, t))

    vx, vy, s = ENTE
    for farbe, zuege in ente:
        for zug in zuege:
            if len(zug) < 3:
                continue
            stift.polygon(
                [((vx + s * px) * UEBER, (vy + s * py) * UEBER) for px, py in zug],
                fill=tausch.get(farbe.upper(), farbe),
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
