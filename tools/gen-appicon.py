#!/usr/bin/env python3
"""Die Symbole: App-Symbol, Touch-Icon und Favicon, aus einer Quelle gezeichnet.

    tools/gen-appicon.py            # schreiben
    tools/gen-appicon.py --pruefen  # nur pruefen, ob alles zur Quelle passt

**Eine Quelle.** `apps/web/public/favicon.svg` ist das Symbol; dort steht auch, warum es so
aussieht. Aus ihr entstehen hier:

- `AppIcon.png` (1024) fuer die iOS-App,
- `apple-touch-icon.png` (180) fuer den Home-Bildschirm, das Manifest und die Mitteilungen
  des Dashboards,
- `favicon.ico` (16, 32, 48) fuer Browser, die kein SVG als Favicon nehmen.

Die drei wurden frueher von Hand ausgeleitet, und nur das App-Symbol hatte einen Generator.
Seit das Symbol eine Sonne, einen Verlauf und einen Fluegel hat, waere jede Aenderung an drei
Stellen nachzuziehen gewesen - also zieht sie jetzt dieses Werkzeug nach, und `--pruefen`
haelt in der CI alle drei gegen die Quelle.

**Warum nicht die Entenkurve.** Hier stand sie einmal: die Lastkurve als Linie, darunter
Balken. Auf dem Startbildschirm ist ein Symbol 60 Punkte gross, und dann sind die Balken weg
und die Kurve ein Kringel - ein Diagramm ist kein Zeichen.

**Was die Fassungen unterscheidet, ist allein die Rundung.** Das App-Symbol und das
Touch-Icon gehen eckig und deckend bis an den Rand: iOS legt seine eigene Maske darueber, und
eine mitgezeichnete Rundung ergaebe einen Saum. Das Favicon behaelt die runden Ecken der
Quelle, denn im Tab rundet niemand nach.

**Warum ein eigener Leser und kein SVG-Programm.** Die CI prueft auf einem Linux-Laeufer, auf
dem nur Pillow liegt, und Pillow liest kein SVG. Der Leser kennt darum genau das, was in der
Quelle steht, und weist alles andere zurueck - ein Bild, in dem still etwas fehlt, waere
schlimmer als ein Abbruch.
"""

from __future__ import annotations

import argparse
import io
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

WURZEL = Path(__file__).resolve().parent.parent
OEFFENTLICH = WURZEL / "apps" / "web" / "public"
QUELLE = OEFFENTLICH / "favicon.svg"
APPICON = (
    WURZEL / "apps" / "ios" / "DuckCurveHome" / "Ressourcen"
    / "Assets.xcassets" / "AppIcon.appiconset"
)
KANTE_APP = 1024
KANTE_TOUCH = 180
# Von gross nach klein: die erste Stufe ist das Bild, an das Pillow die anderen haengt.
KANTEN_ICO = (48, 32, 16)
# Gezeichnet wird auf 4096 und dann verkleinert: PIL kann Polygone nicht glaetten, das
# Verkleinern schon.
KANTE_GROSS = 4096
# PIL kennt keinen Verlauf im Kreis - die Sonne entsteht aus so vielen Ringen.
SONNE_RINGE = 64

Farbe = tuple[int, int, int]
Zuege = list[list[tuple[float, float]]]

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


@dataclass
class Symbol:
    """Was in der Quelle steht, in ihren eigenen Koordinaten."""

    kante: float
    rundung: float
    grund: tuple[Farbe, Farbe]            # oben, unten
    sonne: tuple[float, float, float]     # Mitte x, Mitte y, Halbmesser
    sonne_farben: tuple[Farbe, Farbe]     # Mitte, Rand
    lage: tuple[float, float, float]      # Verschiebung x, y und Massstab der Ente
    ente: list[tuple[Farbe, Zuege]]       # von unten nach oben


def rgb(farbe: str) -> Farbe:
    """`#RRGGBB` als drei Zahlen."""
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", farbe):
        raise ValueError(f"Keine Farbe der Form #RRGGBB: {farbe}")
    return tuple(int(farbe[i:i + 2], 16) for i in (1, 3, 5))


def attribut(attr: str, name: str) -> str:
    m = re.search(rf'(?:^|\s){name}="([^"]*)"', attr)
    if not m:
        raise ValueError(f"Das Attribut {name} fehlt in: <{attr.strip()}>")
    return m.group(1)


def verlauf(svg: str, art: str, name: str, erwartet: dict[str, str]) -> tuple[Farbe, Farbe]:
    """Die zwei Farben eines Verlaufs, Anfang und Ende.

    `erwartet` sind die Attribute, die der Verlauf ausser seinem Namen haben muss - und keine
    weiteren. Gezeichnet wird hier nur senkrecht und nur rund um die Mitte; ein Verlauf, der
    anders liefe, saehe im Browser anders aus als in den erzeugten Bildern.
    """
    m = re.search(rf'<{art}\b([^>]*)>(.*?)</{art}>', svg, re.S)
    if not m or attribut(m.group(1), "id") != name:
        raise ValueError(f"Der Verlauf {name} ({art}) steht nicht wie erwartet in der Datei.")
    gefunden = dict(re.findall(r'([\w-]+)="([^"]*)"', m.group(1)))
    if gefunden != {"id": name, **erwartet}:
        raise ValueError(f"Der Verlauf {name} hat andere Attribute als erwartet: {gefunden}")
    stufen = re.findall(r'<stop\s+offset="([^"]+)"\s+stop-color="([^"]+)"\s*/>', m.group(2))
    if [o for o, _ in stufen] != ["0", "1"]:
        raise ValueError(f"Der Verlauf {name} braucht genau zwei Stufen, bei 0 und bei 1.")
    return rgb(stufen[0][1]), rgb(stufen[1][1])


def lies(svg: str) -> Symbol:
    """Die Quelle lesen - mit engem Blick, siehe Kopf der Datei."""
    # Kommentare raus - darin stehen Formen als Prosa.
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S)

    sicht = [float(t) for t in attribut(re.search(r"<svg\b([^>]*)>", svg).group(1), "viewBox").split()]
    if sicht[:2] != [0.0, 0.0] or sicht[2] != sicht[3]:
        raise ValueError(f"Erwartet ist ein quadratischer viewBox ab 0 0 - gefunden: {sicht}")
    kante = sicht[2]

    g = re.search(r'<g transform="translate\(([-\d.]+)\s+([-\d.]+)\)\s*scale\(([\d.]+)\)"\s*>'
                  r"(.*?)</g>", svg, re.S)
    if not g:
        raise ValueError("Die Gruppe mit der Ente steht nicht wie erwartet in der Datei.")
    drumherum = svg[:g.start()] + svg[g.end():]

    # Alles, was ausserhalb der Ente stehen darf, und in dieser Reihenfolge. Ein Element
    # mehr waere eines, das hier nicht gezeichnet wuerde.
    marken = re.findall(r"<([A-Za-z]+)\b", drumherum)
    soll = ["svg", "defs", "linearGradient", "stop", "stop", "radialGradient", "stop", "stop",
            "rect", "circle"]
    if marken != soll:
        raise ValueError(f"Um die Ente herum steht anderes als erwartet: {marken}")
    fremd = set(re.findall(r"<([A-Za-z]+)\b", g.group(4))) - {"path", "circle"}
    if fremd:
        raise ValueError(f"In der Ente stehen Elemente, die hier keiner zeichnet: {sorted(fremd)}")

    grund = verlauf(svg, "linearGradient", "grund", {"x1": "0", "y1": "0", "x2": "0", "y2": "1"})
    sonne_farben = verlauf(svg, "radialGradient", "sonne", {})

    kachel = re.search(r"<rect\b([^>]*)/>", drumherum).group(1)
    if (float(attribut(kachel, "width")), float(attribut(kachel, "height"))) != (kante, kante):
        raise ValueError("Die Kachel fuellt den viewBox nicht.")
    if attribut(kachel, "fill") != "url(#grund)":
        raise ValueError("Die Kachel traegt nicht den Verlauf grund.")

    scheibe = re.search(r"<circle\b([^>]*)/>", drumherum).group(1)
    if attribut(scheibe, "fill") != "url(#sonne)":
        raise ValueError("Der Kreis ausserhalb der Ente traegt nicht den Verlauf sonne.")

    ente: list[tuple[Farbe, Zuege]] = []
    for art, attr in re.findall(r"<(path|circle)\b([^>]*)/>", g.group(4)):
        farbe = rgb(attribut(attr, "fill"))
        if art == "path":
            ente.append((farbe, pfad_zu_punkten(attribut(attr, "d"))))
        else:
            ente.append((farbe, kreis_zu_punkten(
                float(attribut(attr, "cx")), float(attribut(attr, "cy")), float(attribut(attr, "r")),
            )))
    if not ente:
        raise ValueError("Die Gruppe mit der Ente ist leer.")

    return Symbol(
        kante=kante,
        rundung=float(attribut(kachel, "rx")),
        grund=grund,
        sonne=(float(attribut(scheibe, "cx")), float(attribut(scheibe, "cy")),
               float(attribut(scheibe, "r"))),
        sonne_farben=sonne_farben,
        lage=(float(g.group(1)), float(g.group(2)), float(g.group(3))),
        ente=ente,
    )


# ────────────────────────────────── zeichnen ────────────────────────────────

def misch(a: Farbe, b: Farbe, t: float) -> Farbe:
    """Zwischen zwei Farben: bei 0 ganz `a`, bei 1 ganz `b`."""
    return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))


def zeichne(s: Symbol) -> Image.Image:
    """Das ganze Symbol, uebergross, eckig und deckend."""
    px = KANTE_GROSS
    m = px / s.kante
    bild = Image.new("RGB", (px, px))
    stift = ImageDraw.Draw(bild)

    oben, unten = s.grund
    for y in range(px):
        stift.line([(0, y), (px, y)], fill=misch(oben, unten, y / (px - 1)))

    # Die Sonne als Ringe von aussen nach innen.
    sx, sy, sr = (w * m for w in s.sonne)
    mitte, rand = s.sonne_farben
    for i in range(SONNE_RINGE):
        t = i / SONNE_RINGE
        r = sr * (1 - t)
        stift.ellipse([sx - r, sy - r, sx + r, sy + r], fill=misch(rand, mitte, t))

    vx, vy, ms = s.lage
    for farbe, zuege in s.ente:
        for zug in zuege:
            if len(zug) < 3:
                continue
            stift.polygon([((vx + ms * x) * m, (vy + ms * y) * m) for x, y in zug], fill=farbe)
    return bild


def gerundet(bild: Image.Image, s: Symbol) -> Image.Image:
    """Dasselbe Bild mit den runden Ecken der Quelle, ausserhalb durchsichtig."""
    px = bild.size[0]
    maske = Image.new("L", bild.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle(
        [0, 0, px - 1, px - 1], radius=s.rundung * px / s.kante, fill=255,
    )
    aus = bild.convert("RGBA")
    aus.putalpha(maske)
    return aus


def klein(bild: Image.Image, kante: int) -> Image.Image:
    return bild.resize((kante, kante), Image.LANCZOS)


def als_png(bild: Image.Image) -> bytes:
    puffer = io.BytesIO()
    bild.save(puffer, "PNG", optimize=True)
    return puffer.getvalue()


def als_ico(stufen: list[Image.Image]) -> bytes:
    """Mehrere Groessen in einer Datei. Jede Stufe ist selbst verkleinert: liesse man Pillow
    aus der groessten die kleineren rechnen, kaeme die bei 16 Pixeln aus zweiter Hand."""
    puffer = io.BytesIO()
    stufen[0].save(puffer, "ICO", sizes=[b.size for b in stufen], append_images=stufen[1:])
    return puffer.getvalue()


def dateien() -> dict[Path, bytes]:
    """Alles, was aus der Quelle entsteht: Pfad und Inhalt."""
    symbol = lies(QUELLE.read_text(encoding="utf-8"))
    gross = zeichne(symbol)
    rund = gerundet(gross, symbol)
    return {
        APPICON / "AppIcon.png": als_png(klein(gross, KANTE_APP)),
        APPICON / "Contents.json": CONTENTS.encode("utf-8"),
        APPICON.parent / "Contents.json": ASSETS_CONTENTS.encode("utf-8"),
        OEFFENTLICH / "apple-touch-icon.png": als_png(klein(gross, KANTE_TOUCH)),
        OEFFENTLICH / "favicon.ico": als_ico([klein(rund, k) for k in KANTEN_ICO]),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pruefen", action="store_true", help="nur pruefen, nichts schreiben")
    args = ap.parse_args()

    soll = dateien()

    if args.pruefen:
        veraltet = [pfad for pfad, roh in soll.items()
                    if not pfad.exists() or pfad.read_bytes() != roh]
        for pfad in veraltet:
            print(f"{pfad.relative_to(WURZEL)} passt nicht zu {QUELLE.name} - neu erzeugen mit "
                  f"tools/gen-appicon.py", file=sys.stderr)
        if veraltet:
            return 1
        print(f"{len(soll)} Dateien sind auf dem Stand von {QUELLE.name}.")
        return 0

    for pfad, roh in soll.items():
        pfad.parent.mkdir(parents=True, exist_ok=True)
        pfad.write_bytes(roh)
        print(f"{pfad.relative_to(WURZEL)} geschrieben ({len(roh)} Bytes).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
