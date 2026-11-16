#!/usr/bin/env python3
"""Das App-Symbol aus der Marke erzeugen.

**Warum erzeugt und nicht als Datei abgelegt.** Ein PNG im Repository ist ein Binärklumpen ohne
Herkunft: niemand sieht, woraus es entstanden ist, und wenn die Marke sich ändert, merkt es keiner.
Dieses Werkzeug zeichnet dasselbe, was `apps/web/public/brand/duck-curve-mark.svg` zeigt - die
Entenkurve über ihren Lastbalken -, auf ein Quadrat und in die Farben aus `tokens.css`.

    tools/gen-appicon.py
    tools/gen-appicon.py --pruefen

**Das Quadrat ist die eigentliche Arbeit.** Die Marke ist 1800 auf 1000 breit und lebt davon, daß
die Kurve Platz nach rechts hat. Auf einem Quadrat wird daraus ein Gedränge, wenn man sie nur
skaliert. Gezeichnet wird darum der Teil, der die Marke ausmacht: der Bauch der Kurve und die
Spitze am Abend, mit den Balken darunter - und ohne das lange Auslaufen nach rechts.

Apple braucht genau ein Bild: 1024 auf 1024, ohne Alphakanal, ohne eigene Rundung (die legt das
System darüber). Alle übrigen Größen rechnet Xcode selbst.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

WURZEL = Path(__file__).resolve().parent.parent
ZIEL = (
    WURZEL / "apps" / "ios" / "DuckCurveHome" / "Ressourcen" / "Assets.xcassets"
    / "AppIcon.appiconset"
)

KANTE = 1024

# Die Farben aus apps/web/src/styles/tokens.css.
PETROL = (0x0F, 0x2E, 0x3D)
DEEP = (0x08, 0x24, 0x31)
AMBER = (0xF2, 0xA9, 0x00)
MIST = (0x7F, 0xA3, 0xB3)

# Die Kurve aus duck-curve-mark.svg, im Koordinatensystem der Marke (0..560 in x, 0..270 in y).
# Jede Zeile ist eine kubische Bezier: zwei Griffe und ein Ziel. Der Anfang steht darüber.
KURVE_START = (48.0, 171.0)
KURVE = [
    ((104.0, 118.0), (146.0, 181.0), (206.0, 183.0)),
    ((300.0, 186.0), (316.0, 112.0), (369.0, 37.0)),
    ((395.0, 0.0), (437.0, 7.0), (447.0, 42.0)),
]

# Die Lastbalken darunter: (x, obere Kante). Nur die, die unter dem gezeichneten Stück liegen.
BALKEN = [
    (54, 202), (76, 196), (98, 195), (120, 198), (142, 204), (164, 211),
    (186, 216), (208, 218), (230, 216), (252, 211), (274, 201), (296, 188),
    (318, 171), (340, 151), (362, 130), (384, 113), (406, 101), (428, 111),
    (450, 124),
]
BALKEN_UNTEN = 270


def bezier(p0, p1, p2, p3, schritte=120):
    """Punkte auf einer kubischen Bezier-Kurve."""
    aus = []
    for i in range(schritte + 1):
        t = i / schritte
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        aus.append((x, y))
    return aus


def dichter(punkte, abstand=0.35):
    """Die Stützpunkte so verdichten, dass zwei benachbarte Kreise sich überlappen."""
    aus = [punkte[0]]
    for a, b in zip(punkte, punkte[1:]):
        laenge = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        n = max(1, int(laenge / abstand))
        for i in range(1, n + 1):
            t = i / n
            aus.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return aus


def zeichne() -> Image.Image:
    # Vierfach gezeichnet und dann verkleinert: PIL kennt keine Kantenglättung für Linien, und
    # eine Kurve mit harten Rändern sieht auf einem Retina-Bildschirm nach Pixelbrei aus.
    gross = KANTE * 4
    bild = Image.new("RGB", (gross, gross), PETROL)
    stift = ImageDraw.Draw(bild)

    # Ein ruhiger Verlauf nach unten, wie `--bg-gradient`. Zeilenweise, das genügt für zwei Töne.
    for y in range(gross):
        t = y / gross
        farbe = tuple(int(DEEP[k] + (PETROL[k] - DEEP[k]) * (1 - t * 0.55)) for k in range(3))
        stift.line([(0, y), (gross, y)], fill=farbe)

    # Das gezeichnete Stück der Marke: x von 40 bis 460, y von 0 bis 270.
    links, rechts, oben, unten = 40.0, 460.0, -6.0, 270.0
    breite = rechts - links
    hoehe = unten - oben
    # Auf 86 Prozent der Breite, mittig. Die Marke ist breiter als hoch, auf einem Quadrat bleibt
    # also oben und unten Luft - das ist der Grund, warum hier nach der Breite skaliert wird und
    # nicht nach der groesseren der beiden Kanten: sonst sitzt sie verloren in der Mitte.
    maß = gross * 0.86 / breite
    dx = (gross - breite * maß) / 2 - links * maß
    dy = (gross - hoehe * maß) / 2 - oben * maß

    def auf(p):
        return (p[0] * maß + dx, p[1] * maß + dy)

    # Die Balken zuerst, sie liegen hinter der Kurve.
    # Dicker als in der Vorlage: auf dem Startbildschirm ist ein Symbol 60 Punkte gross, und ein
    # Balken von fuenf Einheiten waere dort ein Drittel Pixel breit - er verschwaende zu Dunst.
    balkenbreite = max(2, int(8 * maß))
    for x, o in BALKEN:
        a = auf((x, o))
        b = auf((x, BALKEN_UNTEN))
        stift.line([a, b], fill=MIST, width=balkenbreite)

    # Die Kurve darüber.
    punkte = [KURVE_START]
    stelle = KURVE_START
    for g1, g2, ziel in KURVE:
        punkte.extend(bezier(stelle, g1, g2, ziel)[1:])
        stelle = ziel
    # **Als Punktspur und nicht als Linienzug.** `ImageDraw.line` mit `joint="curve"` setzt an
    # jeder Ecke ein eigenes Polygon; wo zwei davon in flachem Winkel aufeinandertreffen, bleibt
    # ein Zacken stehen. Über eine Kurve aus dreihundert Stützpunkten ergibt das einen Rand wie
    # eine Raupe - sichtbar auch nach dem Verkleinern. Ein Kreis je Stützpunkt hat diese Ecken
    # nicht, und bei dieser Dichte überlappen sie sich zu einem glatten Band mit runden Enden.
    r = max(2, 7.5 * maß)
    for p in dichter(punkte):
        m = auf(p)
        stift.ellipse([m[0] - r, m[1] - r, m[0] + r, m[1] + r], fill=AMBER)

    return bild.resize((KANTE, KANTE), Image.LANCZOS)


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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pruefen", action="store_true", help="nur pruefen, ob es da ist")
    args = ap.parse_args()

    png = ZIEL / "AppIcon.png"
    if args.pruefen:
        if not png.exists():
            print(f"{png.relative_to(WURZEL)} fehlt. Erzeugen mit: tools/gen-appicon.py", file=sys.stderr)
            return 1
        print(f"{png.relative_to(WURZEL)} ist da.")
        return 0

    ZIEL.mkdir(parents=True, exist_ok=True)
    zeichne().save(png, "PNG")
    (ZIEL / "Contents.json").write_text(CONTENTS, encoding="utf-8")
    (ZIEL.parent / "Contents.json").write_text(ASSETS_CONTENTS, encoding="utf-8")
    print(f"{png.relative_to(WURZEL)}: {KANTE}×{KANTE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
