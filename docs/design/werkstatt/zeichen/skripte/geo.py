"""Geometrie fuer die Entwuerfe: Zahlen kurz schreiben, Kreise, Kapseln, Umrisse von Strichen, Zahnrad.

Alles gibt SVG-Pfadangaben zurueck, die gen-zeichen.py und SvgPfad.swift lesen koennen
(M, L, H, V, C, A, Z). Umlaufsinn: im Uhrzeigersinn auf dem Schirm ist "aussen", gegen den
Uhrzeigersinn ist ein Loch. So entsteht das Loch mit der Fuellregel nonzero, die SVG und SwiftUI
beide als Vorgabe haben, ohne ein fill-rule-Attribut.
"""
import math


def z(x: float) -> str:
    s = f"{x:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def p(x, y) -> str:
    return f"{z(x)} {z(y)}"


class Zug:
    """Ein geschlossener Zug aus Linien und Kreisboegen, umkehrbar."""

    def __init__(self, start):
        self.start = start
        self.teile = []  # ('L', (x, y)) oder ('A', r, sweep, (x, y))

    def linie(self, x, y):
        self.teile.append(("L", (x, y)))
        return self

    def bogen(self, r, sweep, x, y, gross=0):
        self.teile.append(("A", r, sweep, (x, y), gross))
        return self

    def umgekehrt(self):
        punkte = [self.start] + [t[1] if t[0] == "L" else t[3] for t in self.teile]
        neu = Zug(punkte[-1])
        for i in range(len(self.teile) - 1, -1, -1):
            t = self.teile[i]
            ziel = punkte[i]
            if t[0] == "L":
                neu.linie(*ziel)
            else:
                neu.bogen(t[1], 1 - t[2], ziel[0], ziel[1], t[4])
        return neu

    def d(self):
        aus = "M" + p(*self.start)
        for t in self.teile:
            if t[0] == "L":
                aus += "L" + p(*t[1])
            else:
                aus += f"A{z(t[1])} {z(t[1])} 0 {t[4]} {t[2]} {p(*t[3])}"
        return aus + "Z"


def kreis(cx, cy, r, loch=False) -> str:
    s = 0 if loch else 1
    return (
        f"M{p(cx, cy - r)}A{z(r)} {z(r)} 0 1 {s} {p(cx, cy + r)}"
        f"A{z(r)} {z(r)} 0 1 {s} {p(cx, cy - r)}Z"
    )


def _einheit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dy)
    return dx / l, dy / l


def strichumriss(punkte, h, loch=False) -> str:
    """Der Umriss eines Linienzugs mit runden Enden und runden Ecken, halbe Breite h."""
    n = len(punkte)
    richt = [_einheit(punkte[i], punkte[i + 1]) for i in range(n - 1)]
    norm = [(-d[1], d[0]) for d in richt]  # rechte Hand in Laufrichtung (y nach unten)
    # vorwaerts auf der linken Seite (-n), Kappe, zurueck auf der rechten (+n), Kappe: Uhrzeigersinn
    a = punkte[0]
    zug = Zug((a[0] - norm[0][0] * h, a[1] - norm[0][1] * h))
    for i in range(1, n - 1):
        v = punkte[i]
        n1, n2 = norm[i - 1], norm[i]
        kreuz = richt[i - 1][0] * richt[i][1] - richt[i - 1][1] * richt[i][0]
        if kreuz > 1e-9:  # biegt nach rechts ab: links ist aussen, Bogen
            zug.linie(v[0] - n1[0] * h, v[1] - n1[1] * h)
            zug.bogen(h, 1, v[0] - n2[0] * h, v[1] - n2[1] * h)
        else:  # links ist innen: Schnittpunkt
            f = h / (1 + n1[0] * n2[0] + n1[1] * n2[1])
            zug.linie(v[0] - (n1[0] + n2[0]) * f, v[1] - (n1[1] + n2[1]) * f)
    e = punkte[-1]
    nl = norm[-1]
    zug.linie(e[0] - nl[0] * h, e[1] - nl[1] * h)
    zug.bogen(h, 1, e[0] + nl[0] * h, e[1] + nl[1] * h)
    for i in range(n - 2, 0, -1):
        v = punkte[i]
        n1, n2 = norm[i - 1], norm[i]
        kreuz = richt[i - 1][0] * richt[i][1] - richt[i - 1][1] * richt[i][0]
        if kreuz > 1e-9:  # rechts ist innen
            f = h / (1 + n1[0] * n2[0] + n1[1] * n2[1])
            zug.linie(v[0] + (n1[0] + n2[0]) * f, v[1] + (n1[1] + n2[1]) * f)
        else:
            zug.linie(v[0] + n2[0] * h, v[1] + n2[1] * h)
            zug.bogen(h, 1, v[0] + n1[0] * h, v[1] + n1[1] * h)
    n0 = norm[0]
    zug.linie(a[0] + n0[0] * h, a[1] + n0[1] * h)
    zug.bogen(h, 1, a[0] - n0[0] * h, a[1] - n0[1] * h)
    if loch:
        zug = zug.umgekehrt()
    return zug.d()


def kapsel(x1, y1, x2, y2, h, loch=False) -> str:
    return strichumriss([(x1, y1), (x2, y2)], h, loch)


def kreuzumriss(cx, cy, arm, h, loch=False) -> str:
    """Ein liegendes Kreuz (x) aus zwei Strichen der halben Breite h, Armlaenge arm ab Mitte."""
    w = math.sqrt(0.5)
    zug = None
    # vier Arme, im Uhrzeigersinn: oben rechts, unten rechts, unten links, oben links
    for k in range(4):
        wink = -math.pi / 4 + k * math.pi / 2
        dx, dy = math.cos(wink), math.sin(wink)
        nx, ny = -dy, dx
        ex, ey = cx + dx * arm, cy + dy * arm
        # innerer Eckpunkt vor diesem Arm (zwischen vorigem Arm und diesem)
        iw = wink - math.pi / 4
        ix, iy = cx + math.cos(iw) * h / w, cy + math.sin(iw) * h / w
        if zug is None:
            zug = Zug((ix, iy))
        else:
            zug.linie(ix, iy)
        zug.linie(ex - nx * h, ey - ny * h)
        zug.bogen(h, 1, ex + nx * h, ey + ny * h)
    if loch:
        zug = zug.umgekehrt()
    return zug.d()


def zahnrad(n, ra, rf, at_grad, ar_grad, cx=12.0, cy=12.0, dreh_grad=None) -> str:
    """Zahnkontur: n Zaehne, Kopfkreis ra, Fusskreis rf, halber Winkel am Kopf und im Grund."""
    teilung = 2 * math.pi / n
    at, ar = math.radians(at_grad), math.radians(ar_grad)
    dreh = -math.pi / 2 if dreh_grad is None else math.radians(dreh_grad)

    def pk(r, w):
        return cx + r * math.cos(w), cy + r * math.sin(w)

    aus = ""
    for k in range(n):
        phi = dreh + k * teilung
        a = pk(ra, phi - at)
        b = pk(ra, phi + at)
        c = pk(rf, phi + teilung / 2 - ar)
        e = pk(rf, phi + teilung / 2 + ar)
        aus += ("M" if k == 0 else "L") + p(*a)
        aus += f"A{z(ra)} {z(ra)} 0 0 1 {p(*b)}"
        aus += "L" + p(*c)
        aus += f"A{z(rf)} {z(rf)} 0 0 1 {p(*e)}"
    return aus + "Z"


def schluessel_maul(hx, hy, R, w, g, L, d0) -> str:
    """Maulschluessel, schraeg von unten links nach oben rechts. Kopfkreis R um (hx, hy),
    Maul der halben Weite w, Griff der halben Breite g und Laenge L, Maulgrund bei d0."""
    s2 = math.sqrt(0.5)
    ax, ay = s2, -s2
    bx, by = s2, s2

    def P(s, t):
        return hx + ax * s + bx * t, hy + ay * s + by * t

    s1 = math.sqrt(R * R - w * w)
    sg = math.sqrt(R * R - g * g)
    zug = Zug(P(s1, -w))
    zug.bogen(R, 0, *P(-sg, -g))
    zug.linie(*P(-L, -g))
    zug.bogen(g, 0, *P(-L, g))
    zug.linie(*P(-sg, g))
    zug.bogen(R, 0, *P(s1, w))
    zug.linie(*P(d0, w))
    zug.bogen(w, 1, *P(d0, -w))
    return zug.d()


def euro_umriss(cx, cy, r, h, theta_grad, dy, hb, xl, xr, loch=False) -> str:
    """Der Umriss des Eurozeichens als eine geschlossene Form: Bogen der halben Breite h um
    (cx, cy) mit Radius r, offen um +-theta, dazu zwei Balken der halben Breite hb bei cy -+ dy
    von xl bis xr (Mitten der runden Enden)."""
    th = math.radians(theta_grad)
    Ro, Ri = r + h, r - h

    def xo(y):  # linker Schnitt des Aussenkreises mit der Hoehe y
        return cx - math.sqrt(Ro * Ro - (y - cy) ** 2)

    def xi(y):
        return cx - math.sqrt(Ri * Ri - (y - cy) ** 2)

    y1, y2 = cy - dy, cy + dy
    zug = Zug((cx + Ro * math.cos(th), cy + Ro * math.sin(th)))  # unteres Ende, aussen
    # Aussenkreis im Uhrzeigersinn: unten herum nach links, dort die Balken
    zug.bogen(Ro, 1, xo(y2 + hb), y2 + hb)
    zug.linie(xl, y2 + hb).bogen(hb, 1, xl, y2 - hb).linie(xo(y2 - hb), y2 - hb)
    zug.bogen(Ro, 1, xo(y1 + hb), y1 + hb)
    zug.linie(xl, y1 + hb).bogen(hb, 1, xl, y1 - hb).linie(xo(y1 - hb), y1 - hb)
    zug.bogen(Ro, 1, cx + Ro * math.cos(th), cy - Ro * math.sin(th))
    # Kappe am oberen Ende, dann der Innenkreis zurueck
    zug.bogen(h, 1, cx + Ri * math.cos(th), cy - Ri * math.sin(th))
    zug.bogen(Ri, 0, xi(y1 - hb), y1 - hb)
    zug.linie(xr, y1 - hb).bogen(hb, 1, xr, y1 + hb).linie(xi(y1 + hb), y1 + hb)
    zug.bogen(Ri, 0, xi(y2 - hb), y2 - hb)
    zug.linie(xr, y2 - hb).bogen(hb, 1, xr, y2 + hb).linie(xi(y2 + hb), y2 + hb)
    zug.bogen(Ri, 0, cx + Ri * math.cos(th), cy + Ri * math.sin(th))
    zug.bogen(h, 1, cx + Ro * math.cos(th), cy + Ro * math.sin(th))
    if loch:
        zug = zug.umgekehrt()
    return zug.d()
