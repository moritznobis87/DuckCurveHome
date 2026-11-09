/**
 * Die Geometrie der Tagesuhr: reine Funktionen, keine Zeichnung.
 *
 * Getrennt von der Komponente, weil hier die Fehler sitzen, die man einem Bild nicht ansieht:
 * ein Ring, der um eine Viertelstunde verdreht ist, sieht genauso plausibel aus wie ein richtiger.
 * Deshalb stehen diese Funktionen für sich und haben eigene Prüfungen.
 *
 * **Der Winkel ist der Anteil am Tag, nicht die Uhrzeit.** Mitternacht steht oben, der Tag läuft
 * im Uhrzeigersinn einmal herum - auch an den beiden Umstellungstagen, die 23 oder 25 Stunden
 * haben. Aus der Uhrzeit gerechnet bliebe dort eine Stunde offen oder läge doppelt.
 */

export type Lauf<T> = { von: number; bis: number; wert: T };

/** Wo im Tag ein Zeitpunkt liegt, als Zahl von 0 (Beginn) bis 1 (Ende), auf diesen Bereich begrenzt. */
export function anteil(tMs: number, vonMs: number, bisMs: number): number {
  if (bisMs <= vonMs) return 0;
  return Math.min(1, Math.max(0, (tMs - vonMs) / (bisMs - vonMs)));
}

/** Ein Punkt auf dem Kreis. Anteil 0 liegt oben, es geht im Uhrzeigersinn. */
export function punkt(cx: number, cy: number, r: number, a: number): [number, number] {
  const w = a * 2 * Math.PI - Math.PI / 2;
  return [cx + r * Math.cos(w), cy + r * Math.sin(w)];
}

function f(x: number): string {
  return x.toFixed(2);
}

/**
 * Ein Stück Ring zwischen zwei Radien und zwei Tagesanteilen, als SVG-Pfad.
 *
 * Ein voller Ring (Anteile 0 bis 1) wird in zwei Hälften gezeichnet: ein einzelner Bogen von
 * einem Punkt zu demselben Punkt hat für SVG die Länge null und verschwindet.
 */
export function ringstueck(cx: number, cy: number, r0: number, r1: number, a0: number, a1: number): string {
  const spanne = a1 - a0;
  if (spanne <= 0) return "";
  if (spanne >= 0.9999) {
    const mitte = a0 + spanne / 2;
    return `${ringstueck(cx, cy, r0, r1, a0, mitte)} ${ringstueck(cx, cy, r0, r1, mitte, a0 + 0.9999)}`;
  }
  const gross = spanne > 0.5 ? 1 : 0;
  const [x0, y0] = punkt(cx, cy, r1, a0);
  const [x1, y1] = punkt(cx, cy, r1, a1);
  const [x2, y2] = punkt(cx, cy, r0, a1);
  const [x3, y3] = punkt(cx, cy, r0, a0);
  return `M${f(x0)} ${f(y0)} A${r1} ${r1} 0 ${gross} 1 ${f(x1)} ${f(y1)} L${f(x2)} ${f(y2)} A${r0} ${r0} 0 ${gross} 0 ${f(x3)} ${f(y3)} Z`;
}

/**
 * Aufeinanderfolgende Bilder mit gleichem Wert zu Läufen zusammenfassen.
 *
 * Ein Lauf endet nicht nur, wenn der Wert wechselt, sondern auch, wenn die Zeit springt: fehlt
 * ein Bild, ist das eine Lücke in der Erfassung, und der Ring soll dort offen bleiben. Würde nur
 * der Wert verglichen, liefe ein Lauf über einen Ausfall hinweg - der Ring zeigte eine Stunde
 * Betrieb, von der niemand etwas weiß.
 *
 * `null` und `undefined` ergeben keinen Lauf. Jeder Lauf reicht vom Beginn seines ersten Bildes
 * bis zum Ende seines letzten, also einen Schritt über dessen Zeitstempel hinaus.
 */
export function laeufe<T>(werte: readonly (T | null | undefined)[], zeiten: readonly number[], schrittMs: number): Lauf<T>[] {
  const out: Lauf<T>[] = [];
  let offen: Lauf<T> | null = null;
  for (let i = 0; i < werte.length; i += 1) {
    const w = werte[i];
    const t = zeiten[i];
    if (t === undefined) break;
    const anschluss = offen !== null && t - offen.bis < schrittMs * 0.5;
    if (w === null || w === undefined) {
      offen = null;
      continue;
    }
    if (offen !== null && anschluss && offen.wert === w) {
      offen.bis = t + schrittMs;
    } else {
      offen = { von: t, bis: t + schrittMs, wert: w };
      out.push(offen);
    }
  }
  return out;
}

/**
 * Einen Wert in eine von `n` Stufen einordnen, 0 bis n-1.
 *
 * Stufen statt eines stufenlosen Verlaufs: fünf unterscheidbare Helligkeiten liest das Auge
 * sicherer als 288 fast gleiche, und gleiche Nachbarn lassen sich zu einem Bogen verbinden.
 * Liegen alle Werte gleich, ist die Spanne null; dann bekommt alles die mittlere Stufe, statt
 * durch null zu teilen.
 */
export function stufe(wert: number, min: number, max: number, n: number): number {
  if (!(max > min)) return Math.floor((n - 1) / 2);
  const s = Math.floor(((wert - min) / (max - min)) * n);
  return Math.min(n - 1, Math.max(0, s));
}

/** Das Bild, dessen Zeit einem Tagesanteil am nächsten liegt. -1 ohne Bilder. */
export function indexBei(a: number, zeiten: readonly number[], vonMs: number, bisMs: number): number {
  if (zeiten.length === 0) return -1;
  const ziel = vonMs + a * (bisMs - vonMs);
  let beste = 0;
  let abstand = Infinity;
  zeiten.forEach((t, i) => {
    const d = Math.abs(t - ziel);
    if (d < abstand) {
      abstand = d;
      beste = i;
    }
  });
  return beste;
}

/**
 * Der Tagesanteil unter einem Zeiger, aus Bildschirmpunkten relativ zur Mitte der Uhr.
 *
 * `dx` nach rechts, `dy` nach unten, wie auf dem Bildschirm. Oben ist 0, rechts ein Viertel.
 */
export function anteilAus(dx: number, dy: number): number {
  const w = Math.atan2(dy, dx) + Math.PI / 2;
  const a = w / (2 * Math.PI);
  return a < 0 ? a + 1 : a;
}
