/**
 * Rechnen fuer das Hausmodell, ohne three.js: Waende aus Raeumen, Luecken, Versatz, Projektion.
 *
 * Hier steht, was sich pruefen laesst, ohne einen Bildschirm zu haben. Die Szene (`HouseScene`)
 * macht daraus Geometrie; dieses Modul kennt nur Zahlen.
 */
import type { HouseDeck, HouseRoom, HouseWallLine } from "@/lib/api/models";

export type Seite = "n" | "s" | "o" | "w";
export const SEITEN: Seite[] = ["n", "s", "w", "o"];
export type Intervall = [number, number];

export interface Wandstueck {
  /** Nord-Sued-Wand (feste x) oder Ost-West-Wand (feste z). */
  senkrecht: boolean;
  konst: number;
  a: number;
  b: number;
  aussen: boolean;
}

/** Ueberlappende oder anstossende Intervalle zu einem zusammenfassen. */
export function vereinigt(iv: Intervall[]): Intervall[] {
  const s = [...iv].sort((p, q) => p[0] - q[0]);
  const aus: Intervall[] = [];
  for (const [a, b] of s) {
    const letzt = aus[aus.length - 1];
    if (letzt && a <= letzt[1] + 0.02) letzt[1] = Math.max(letzt[1], b);
    else aus.push([a, b]);
  }
  return aus;
}

/** Intervalle abzueglich der Luecken darin: aus einer Wand werden Wandstuecke zwischen den Tueren. */
export function ohneLuecken(iv: Intervall[], luecken: Intervall[]): Intervall[] {
  const aus: Intervall[] = [];
  for (const [a, b] of iv) {
    let cursor = a;
    const passend = luecken.filter((l) => l[1] > a + 0.02 && l[0] < b - 0.02).sort((p, q) => p[0] - q[0]);
    for (const [la, lb] of passend) {
      if (la > cursor + 0.02) aus.push([cursor, la]);
      cursor = Math.max(cursor, lb);
    }
    if (b > cursor + 0.02) aus.push([cursor, b]);
  }
  return aus;
}

/** Liegt eine Raumkante auf der Aussenhaut? Dann ist die Wand hoeher und heller. */
export function istAussen(huelle: number[][], raum: HouseRoom, seite: Seite): boolean {
  const n = huelle.length;
  for (let i = 0; i < n; i++) {
    const p = huelle[i]!;
    const q = huelle[(i + 1) % n]!;
    const [ax, az] = [p[0] ?? 0, p[1] ?? 0];
    const [bx, bz] = [q[0] ?? 0, q[1] ?? 0];
    if (seite === "n" || seite === "s") {
      const z = seite === "n" ? raum.z0 : raum.z1;
      if (Math.abs(az - z) > 0.05 || Math.abs(bz - z) > 0.05) continue;
      if (Math.min(ax, bx) < raum.x1 - 0.2 && Math.max(ax, bx) > raum.x0 + 0.2) return true;
    } else {
      const x = seite === "w" ? raum.x0 : raum.x1;
      if (Math.abs(ax - x) > 0.05 || Math.abs(bx - x) > 0.05) continue;
      if (Math.min(az, bz) < raum.z1 - 0.2 && Math.max(az, bz) > raum.z0 + 0.2) return true;
    }
  }
  return false;
}

/**
 * Alle Wandstuecke eines Decks: Raumkanten und Zusatzwaende, je Wandlinie vereinigt, ohne die
 * Tuerluecken. Eine Wand, die zwei Raeume teilen, steht so nur einmal im Glas.
 */
export function wandstuecke(deck: HouseDeck): Wandstueck[] {
  const reg = new Map<string, { senkrecht: boolean; konst: number; aussen: boolean; iv: Intervall[] }>();
  const melden = (senkrecht: boolean, konst: number, von: number, bis: number, aussen: boolean) => {
    const key = `${senkrecht ? "x" : "z"}:${konst.toFixed(2)}:${aussen ? "a" : "i"}`;
    const eintrag = reg.get(key) ?? { senkrecht, konst, aussen, iv: [] };
    eintrag.iv.push([Math.min(von, bis), Math.max(von, bis)]);
    reg.set(key, eintrag);
  };
  for (const raum of deck.rooms) {
    for (const seite of SEITEN) {
      if ((raum.no_walls ?? "").includes(seite)) continue;
      const senkrecht = seite === "w" || seite === "o";
      const konst = senkrecht ? (seite === "w" ? raum.x0 : raum.x1) : seite === "n" ? raum.z0 : raum.z1;
      melden(senkrecht, konst, senkrecht ? raum.z0 : raum.x0, senkrecht ? raum.z1 : raum.x1, istAussen(deck.shell, raum, seite));
    }
  }
  for (const w of deck.walls ?? []) melden(w.x != null, w.x != null ? w.x : (w.z ?? 0), w.a, w.b, false);
  const aus: Wandstueck[] = [];
  for (const w of reg.values()) {
    const luecken: Intervall[] = (deck.gaps ?? [])
      .filter((l) => (w.senkrecht ? l.x != null && Math.abs(l.x - w.konst) < 0.06 : l.z != null && Math.abs(l.z - w.konst) < 0.06))
      .map((l) => [l.a, l.b]);
    for (const [a, b] of ohneLuecken(vereinigt(w.iv), luecken)) aus.push({ senkrecht: w.senkrecht, konst: w.konst, a, b, aussen: w.aussen });
  }
  return aus;
}

/** Ein Vieleck um `d` nach aussen versetzt (gegen den Uhrzeigersinn in x/z gegeben). */
export function versetzt(punkte: number[][], d: number): [number, number][] {
  const n = punkte.length;
  const aus: [number, number][] = [];
  for (let i = 0; i < n; i++) {
    const p = punkte[i]!;
    const q = punkte[(i + 1) % n]!;
    const o = punkte[(i - 1 + n) % n]!;
    const e1 = [p[0]! - o[0]!, p[1]! - o[1]!];
    const e2 = [q[0]! - p[0]!, q[1]! - p[1]!];
    const l1 = Math.hypot(e1[0]!, e1[1]!) || 1;
    const l2 = Math.hypot(e2[0]!, e2[1]!) || 1;
    const n1 = [e1[1]! / l1, -e1[0]! / l1];
    const n2 = [e2[1]! / l2, -e2[0]! / l2];
    aus.push([p[0]! + d * (n1[0]! + n2[0]!), p[1]! + d * (n1[1]! + n2[1]!)]);
  }
  return aus;
}

/** Die Umgrenzung einer Punktmenge in x/z. */
export function umgrenzung(punkte: number[][]): { x0: number; x1: number; z0: number; z1: number } {
  const xs = punkte.map((p) => p[0] ?? 0);
  const zs = punkte.map((p) => p[1] ?? 0);
  return { x0: Math.min(...xs), x1: Math.max(...xs), z0: Math.min(...zs), z1: Math.max(...zs) };
}

// ------------------------------------------------------------------ Kavalierprojektion

/** Senkrechte Kanten laufen schraeg nach rechts oben: so zeigen Waende und Moebel zwei Seiten,
 *  und der Grundriss bleibt massstaeblich und rechtwinklig. */
export const K_X = 0.34;
export const K_Y = 0.58;

/** Bildschirmkoordinaten (rechts, oben) eines Punkts bei Drehung `th` des Grundrisses. */
export function bildschirm(x: number, y: number, z: number, th: number): { sx: number; su: number } {
  const c = Math.cos(th);
  const s = Math.sin(th);
  return { sx: x * c - z * s + K_X * y, su: -(x * s + z * c) + K_Y * y };
}

/** Richtung des Sehstrahls im gedrehten Grundriss, zum Betrachter hin, als Einheitsvektor. */
export function strahl(th: number): [number, number, number] {
  const c = Math.cos(th);
  const s = Math.sin(th);
  const v: [number, number, number] = [-K_X * c + K_Y * s, 1, K_X * s + K_Y * c];
  const l = Math.hypot(...v);
  return [v[0] / l, v[1] / l, v[2] / l];
}

// ------------------------------------------------------------------ Temperaturfarbe

/** Farbstopps der Raumboeden, von kalt nach warm, in Grad und als RGB. */
export const TEMP_STOPS: [number, [number, number, number]][] = [
  [15, [0x25, 0x50, 0x6a]],
  [19, [0x3d, 0x7a, 0x9c]],
  [21, [0x6a, 0xb6, 0xc8]],
  [22.5, [0xc8, 0x90, 0x2f]],
  [24, [0xf2, 0xb1, 0x34]],
  [26, [0xff, 0x7a, 0x45]],
];

/** Die Farbe eines Bodens als 0xRRGGBB. */
export function tempFarbe(t: number): number {
  const erster = TEMP_STOPS[0]!;
  const letzter = TEMP_STOPS[TEMP_STOPS.length - 1]!;
  const hex = (c: [number, number, number]) => (c[0] << 16) | (c[1] << 8) | c[2];
  if (t <= erster[0]) return hex(erster[1]);
  if (t >= letzter[0]) return hex(letzter[1]);
  for (let i = 1; i < TEMP_STOPS.length; i++) {
    const [t1, b] = TEMP_STOPS[i]!;
    if (t <= t1) {
      const [t0, a] = TEMP_STOPS[i - 1]!;
      const f = (t - t0) / (t1 - t0);
      return hex([0, 1, 2].map((k) => Math.round(a[k]! + (b[k]! - a[k]!) * f)) as [number, number, number]);
    }
  }
  return hex(letzter[1]);
}

/** Die Wandlinie einer Oeffnung als Lage im Raum: feste Koordinate und Laufrichtung. */
export function wandlinie(o: HouseWallLine): { senkrecht: boolean; konst: number } {
  return o.x != null ? { senkrecht: true, konst: o.x } : { senkrecht: false, konst: o.z ?? 0 };
}
