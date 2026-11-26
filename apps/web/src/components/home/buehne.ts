import type { Sonnenlauf } from "./ambiente";

/**
 * Die Rechnung der Bühne: wo die Sonne steht, wo die Sachen stehen und wie breit ein Band ist.
 *
 * Gezeichnet wird in `Buehne.tsx` und in der App in `Buehnenbild.swift`; gerechnet wird hier und
 * im Kit in `Startbuehne.swift`, mit denselben Prüfwerten in beiden Tests.
 */

/** Ab dieser Leistung fließt etwas; darunter ist ein Band nur eine gestrichelte Linie. */
export const FLUSS_AB_KW = 0.05;

/**
 * Wie breit ein Band bei dieser Leistung ist, in Pixeln.
 *
 * **Mit der Wurzel, nicht geradeaus, und höchstens 16 Pixel.** Bis zum 25.11.2026 wuchs das Band
 * mit 4,5 Pixeln je Kilowatt bis 30 Pixel. Im Haus zieht die Wärmepumpe über 8 kW: Kabel und Rohr
 * füllten den ganzen Boden unter dem Haus, und das Kabel ragte in den Mast (Bild des Hausherrn vom
 * 25.11.2026). Mit der Wurzel bleibt ein Kilowatt gut von vier zu unterscheiden, und neun sind
 * immer noch ein Band und kein Balken.
 */
export function bandbreite(kw: number): number {
  return Math.min(16, 4 + 4 * Math.sqrt(Math.max(0, kw)));
}

/**
 * Wie weit die runde Kappe eines Bandes über sein Ende hinausragt: die halbe Breite. Ein Kabel,
 * das an einer Sache beginnt, setzt um so viel tiefer an, damit die Kappe sie nicht überdeckt.
 */
export function bandkappe(kw: number): number {
  return kw < FLUSS_AB_KW ? 1 : bandbreite(kw) / 2;
}

/**
 * Wie weit die Sonne auf ihrem Bogen ist: 0 beim Aufgang, 1 beim Untergang. `null` heißt: sie
 * steht nicht am Himmel oder der Fahrplan kennt den Tag nicht.
 */
export function sonnenanteil(lauf: Sonnenlauf | null, nowMs: number): number | null {
  if (!lauf || lauf.bis <= lauf.von || nowMs < lauf.von || nowMs > lauf.bis) return null;
  return (nowMs - lauf.von) / (lauf.bis - lauf.von);
}

/**
 * Bei dieser Erzeugung steht die Sonne in voller Kraft im Bild.
 *
 * Eine feste Zahl wie bei den Bändern: die Oberfläche kennt die Größe der Anlage nicht. Acht
 * Kilowatt sind ein voller Sommermittag dieses Hauses; ein klarer Wintermittag bleibt darunter
 * und soll im Bild auch so aussehen.
 */
export const VOLLE_SONNE_KW = 8;

/**
 * Wie kräftig die Sonne wirkt, von 0 bis 1.
 *
 * Mit der Wurzel der Erzeugung, wie die Breite der Bänder: ein halbes Kilowatt ist ein Viertel
 * der Kraft und zwei Kilowatt die Hälfte. Geradeaus wäre die Sonne an jedem Wintertag ein Punkt.
 */
export function sonnenkraft(kw: number): number {
  return Math.min(1, Math.sqrt(Math.max(0, kw) / VOLLE_SONNE_KW));
}

/** Wie die Sonne gezeichnet wird. Alle Längen in Pixeln, alle Deckungen von 0 bis 1. */
export interface Sonnenbild {
  /** Die Scheibe: ihr Halbmesser und wie viel Bernstein auf dem blassen Grund liegt. */
  radius: number;
  deckung: number;
  /** Wie weit die Scheibe leuchtet. */
  glanz: number;
  /** Der weiche Schein um die Scheibe: sein Halbmesser und seine Deckung in der Mitte. */
  schein: number;
  scheinDeckung: number;
  /** Der Strahlenkranz: Länge der langen Strahlen und ihre Deckung. Bei 0 gibt es keinen. */
  strahl: number;
  strahlDeckung: number;
  /** Wie deckend der Lichtkegel zum Dach ist, als Anteil seiner vollen Deckung. */
  kegel: number;
  /** Wie stark der warme Schein des Himmels in der Ecke ist. */
  himmel: number;
}

/**
 * So deckend liegt das blasse Weiß unter dem Bernstein der Scheibe. Eine schwache Sonne wird
 * damit hell und fahl wie hinter Dunst; nur mit dem dunklen Himmel gemischt wurde sie oliv.
 */
export const SCHEIBE_BLASS = 0.6;
/** Ab diesem Anteil der Kraft trägt die Sonne Strahlen. */
export const STRAHLEN_AB = 0.3;
/** So viele Strahlen hat der Kranz; jeder zweite ist kürzer. */
export const STRAHLEN = 12;

/**
 * Die Sonne nach ihrer Erzeugung: bei wenig klein und blass, bei viel groß und strahlend
 * (Hausherr am 26.11.2026). Vorher war sie immer gleich groß, und ein trüber Morgen mit
 * 0,1 kW sah aus wie ein Sommermittag.
 */
export function sonnenbild(kw: number, schmal: boolean): Sonnenbild {
  const k = sonnenkraft(kw);
  const zwischen = (wenig: number, viel: number) => wenig + (viel - wenig) * k;
  const radius = schmal ? zwischen(6, 18) : zwischen(7, 22);
  const kranz = Math.max(0, (k - STRAHLEN_AB) / (1 - STRAHLEN_AB));
  return {
    radius,
    deckung: zwischen(0.45, 1),
    glanz: zwischen(0, 22),
    schein: radius * zwischen(2.4, schmal ? 5.2 : 6),
    scheinDeckung: zwischen(0.14, 0.6),
    strahl: kranz * (schmal ? 12 : 16),
    strahlDeckung: kranz * 0.85,
    kegel: zwischen(0.4, 1),
    himmel: zwischen(0.06, 0.26),
  };
}

export interface Buehnenmass {
  /** Das Telefon: Wallbox und Wärmepumpe stehen dann als Kacheln unter der Bühne. */
  schmal: boolean;
  /** Die Höhe des Bodens und die Mitte des Hauses. */
  boden: number;
  mitte: number;
  hausHalb: number;
  hausHoch: number;
  dach: number;
  ueber: number;
  /** Der Sonnenbogen: Abstand vom Rand und die beiden Halbachsen. */
  bogenRand: number;
  rx: number;
  ry: number;
  netzX: number;
  wallboxX: number;
  speicherX: number;
  pumpeX: number;
  /** So tief liegen Kabel und Rohr unter der Erde. */
  tief: number;
  /** Die Grundlinie der Zahlen über den Sachen. */
  schildY: number;
}

/** Die Maße der Bühne aus ihrer Breite und Höhe. Unter 520 Pixeln ist sie schmal. */
export function buehnenmass(breite: number, hoehe: number): Buehnenmass {
  const schmal = breite < 520;
  const boden = hoehe - (schmal ? 54 : 60);
  const bogenRand = schmal ? 22 : 36;
  return {
    schmal,
    boden,
    mitte: breite / 2,
    hausHalb: schmal ? 60 : Math.min(88, breite * 0.105),
    hausHoch: schmal ? 76 : 84,
    dach: schmal ? 50 : 62,
    ueber: schmal ? 13 : 18,
    bogenRand,
    rx: (breite - 2 * bogenRand) / 2,
    ry: boden - (schmal ? 64 : 40),
    netzX: schmal ? 40 : Math.max(70, breite * 0.1),
    wallboxX: breite * 0.285,
    speicherX: schmal ? breite - 42 : breite * 0.715,
    pumpeX: breite * 0.89,
    tief: boden + (schmal ? 26 : 30),
    schildY: boden - 96,
  };
}

/** Wo die Sonne auf dem Bogen steht. */
export function sonnenort(m: Buehnenmass, anteil: number): { x: number; y: number } {
  const a = Math.PI * Math.max(0, Math.min(1, anteil));
  return { x: m.mitte - m.rx * Math.cos(a), y: m.boden - m.ry * Math.sin(a) };
}
