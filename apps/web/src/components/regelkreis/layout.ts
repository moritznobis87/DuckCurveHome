/**
 * Wo die Kästchen der Regelkreis-Karte liegen, und wie die Leitungen laufen.
 *
 * **Warum die Koordinaten hier stehen und nicht im Kern.** Was mit was verbunden ist, ist eine
 * Aussage über das Haus und steht in `hems_core.regelkreis.struktur`. Wo ein Kästchen liegt, ist
 * eine Frage der Zeichnung. Die Trennung hat einen Preis: wer im Kern einen Block ergänzt, muss
 * ihm hier einen Platz geben. Damit das nicht still schiefgeht, zeichnet die Karte jeden Block
 * ohne Platz unten in einer Reihe „ohne Platz" und sagt es.
 *
 * **Die Karte ist kreuzungsfrei geroutet**, bis auf eine Stelle: die Entnahme des Heizkreises
 * steigt senkrecht in den Puffer und schneidet dabei die Rückführung des Beobachters. Dort ist
 * ein Sprungbogen gezeichnet, wie in jedem Schaltplan.
 *
 * **Wiederholte Knoten.** Die Außentemperatur wirkt an vier Stellen, die Strahlung an zwei, die
 * Raumwärme des Ofens an einer weit von ihm entfernten. In der Topologie ist jede davon ein
 * Knoten; hier bekommt sie mehrere Rechtecke, denn eine Leitung quer über das Bild wäre
 * unleserlicher als derselbe Name zweimal. Jedes Rechteck ist anklickbar und führt zum selben
 * Block.
 */

export type Rechteck = { x: number; y: number; w: number; h: number };

export const KARTE = { breite: 1400, hoehe: 1300 };

/** Die Ebenen zum Hineinzoomen: Sichtfeld und Mindestbreite im Bild. */
export const SICHT: Record<string, { label: string; box: [number, number, number, number] }> = {
  alles: { label: "Alles", box: [0, 0, 1400, 1300] },
  e4: { label: "E4 Ökonomie", box: [0, 20, 1400, 340] },
  e3: { label: "E3+E2 Erzeuger", box: [0, 330, 1400, 420] },
  e1: { label: "E1 Vorlauf", box: [0, 700, 1400, 320] },
  e0: { label: "E0 Räume", box: [0, 960, 1400, 340] },
};

/** Hauptrechteck je Block, dazu die Wiederholungen. */
export const PLATZ: Record<string, { rect: Rechteck; wdh?: Rechteck[] }> = {
  // ----------------------------------------------------------------- Ebene 4
  preis: { rect: { x: 28, y: 62, w: 118, h: 40 } },
  pv_ist: { rect: { x: 160, y: 62, w: 118, h: 40 } },
  speicher: { rect: { x: 292, y: 62, w: 118, h: 40 } },
  pelletpreis: { rect: { x: 424, y: 62, w: 118, h: 40 } },
  strahlung: {
    rect: { x: 556, y: 62, w: 118, h: 40 },
    wdh: [{ x: 594, y: 996, w: 112, h: 34 }],
  },
  aussen: {
    rect: { x: 688, y: 62, w: 118, h: 40 },
    wdh: [
      { x: 330, y: 366, w: 140, h: 34 },
      { x: 28, y: 736, w: 118, h: 34 },
      { x: 470, y: 996, w: 112, h: 34 },
    ],
  },
  kosten_wp: { rect: { x: 28, y: 150, w: 168, h: 84 } },
  kosten_ofen: { rect: { x: 216, y: 150, w: 160, h: 84 } },
  pv: { rect: { x: 396, y: 150, w: 150, h: 84 } },
  bedarf: { rect: { x: 566, y: 150, w: 170, h: 84 } },
  komfort: { rect: { x: 756, y: 150, w: 172, h: 84 } },
  fahrplan: { rect: { x: 1000, y: 150, w: 280, h: 170 } },
  // ------------------------------------------------------------ Ebene 3 und 2
  abtauung: { rect: { x: 330, y: 408, w: 140, h: 34 } },
  cop: { rect: { x: 486, y: 360, w: 184, h: 100 } },
  warmwasser: { rect: { x: 700, y: 408, w: 150, h: 34 } },
  aufstellraum: { rect: { x: 872, y: 408, w: 132, h: 34 } },
  summe_soc: { rect: { x: 57, y: 511, w: 34, h: 34 } },
  puffer_regler: { rect: { x: 112, y: 486, w: 162, h: 84 } },
  zuordnung: { rect: { x: 302, y: 486, w: 160, h: 84 } },
  wp: { rect: { x: 486, y: 486, w: 184, h: 84 } },
  ofen: {
    rect: { x: 486, y: 612, w: 184, h: 84 },
    wdh: [{ x: 970, y: 996, w: 140, h: 34 }],
  },
  summe_waerme: { rect: { x: 683, y: 511, w: 34, h: 34 } },
  puffer: { rect: { x: 752, y: 458, w: 196, h: 122 } },
  beobachter: { rect: { x: 988, y: 486, w: 184, h: 84 } },
  // ----------------------------------------------------------------- Ebene 1
  kennlinie: { rect: { x: 28, y: 796, w: 172, h: 84 } },
  leitventil: { rect: { x: 228, y: 796, w: 172, h: 84 } },
  summe_vl: { rect: { x: 421, y: 821, w: 34, h: 34 } },
  vl_regler: { rect: { x: 476, y: 796, w: 160, h: 84 } },
  heizkreis: { rect: { x: 664, y: 796, w: 190, h: 84 } },
  vl_fuehler: { rect: { x: 900, y: 872, w: 160, h: 44 } },
  // ----------------------------------------------------------------- Ebene 0
  intern: { rect: { x: 718, y: 996, w: 112, h: 34 } },
  fenster: { rect: { x: 842, y: 996, w: 112, h: 34 } },
  summe_raum: { rect: { x: 57, y: 1111, w: 34, h: 34 } },
  raum_regler: { rect: { x: 112, y: 1086, w: 170, h: 84 } },
  ventil: { rect: { x: 310, y: 1086, w: 160, h: 84 } },
  raum: { rect: { x: 560, y: 1068, w: 220, h: 120 } },
  raum_fuehler: { rect: { x: 560, y: 1216, w: 160, h: 44 } },
  weitere_raeume: { rect: { x: 900, y: 1086, w: 200, h: 120 } },
};

export type Punkt = [number, number];

/**
 * Die Leitungen, nach „von→nach" der Topologie. Ein Weg, der hier fehlt, wird als gerade
 * Verbindung gezeichnet - sichtbar, aber eben nicht geroutet.
 */
export const WEGE: Record<string, { p: Punkt[]; bogen?: Punkt }> = {
  "preis→kosten_wp": { p: [[87, 102], [87, 122], [60, 122], [60, 150]] },
  "pv_ist→kosten_wp": { p: [[219, 102], [219, 130], [112, 130], [112, 150]] },
  "speicher→kosten_wp": { p: [[351, 102], [351, 138], [170, 138], [170, 150]] },
  "pelletpreis→kosten_ofen": { p: [[483, 102], [483, 114], [360, 114], [360, 150]] },
  "strahlung→pv": { p: [[615, 102], [615, 110], [430, 110], [430, 150]] },
  "aussen→bedarf": { p: [[747, 102], [747, 118], [700, 118], [700, 150]] },
  "pv→bedarf": { p: [[546, 192], [566, 192]] },
  "kosten_wp→fahrplan": { p: [[112, 234], [112, 294], [1000, 294]] },
  "kosten_ofen→fahrplan": { p: [[296, 234], [296, 282], [1000, 282]] },
  "pv→fahrplan": { p: [[471, 234], [471, 270], [1000, 270]] },
  "bedarf→fahrplan": { p: [[651, 234], [651, 258], [1000, 258]] },
  "komfort→fahrplan": { p: [[842, 234], [842, 246], [1000, 246]] },
  // Der Führungsgrößen-Bus: einmal aus dem Fahrplan heraus, dann am linken Rand hinunter.
  "fahrplan→summe_soc": { p: [[1140, 320], [1140, 338], [14, 338], [14, 528], [57, 528]] },
  "fahrplan→kennlinie": { p: [[14, 560], [14, 838], [28, 838]] },
  "fahrplan→summe_raum": { p: [[14, 860], [14, 1128], [57, 1128]] },
  "fahrplan→zuordnung": { p: [[320, 338], [320, 486]] },
  "aussen→cop": { p: [[470, 383], [486, 383]] },
  "aussen→kennlinie": { p: [[87, 770], [87, 796]] },
  "aussen→raum": { p: [[526, 1030], [526, 1040], [580, 1040], [580, 1068]] },
  "strahlung→raum": { p: [[650, 1030], [650, 1046], [620, 1046], [620, 1068]] },
  "abtauung→wp": { p: [[400, 442], [400, 468], [520, 468], [520, 486]] },
  "cop→wp": { p: [[600, 460], [600, 486]] },
  "bedarf→puffer_regler": { p: [[620, 234], [620, 330], [193, 330], [193, 486]] },
  "summe_soc→puffer_regler": { p: [[91, 528], [112, 528]] },
  "puffer_regler→zuordnung": { p: [[274, 528], [302, 528]] },
  "zuordnung→wp": { p: [[462, 528], [486, 528]] },
  "zuordnung→ofen": { p: [[462, 528], [474, 528], [474, 654], [486, 654]] },
  "wp→summe_waerme": { p: [[670, 528], [683, 528]] },
  "ofen→summe_waerme": { p: [[670, 654], [700, 654], [700, 545]] },
  "summe_waerme→puffer": { p: [[717, 528], [752, 528]] },
  "warmwasser→puffer": { p: [[765, 442], [765, 450], [800, 450], [800, 458]] },
  "aufstellraum→puffer": { p: [[938, 442], [938, 450], [920, 450], [920, 458]] },
  // Die Entnahme steigt senkrecht in den Puffer - und springt über die Rückführung.
  "heizkreis→puffer": { p: [[800, 796], [800, 580]], bogen: [800, 716] },
  "puffer→beobachter": { p: [[948, 528], [988, 528]] },
  "beobachter→summe_soc": { p: [[1172, 528], [1300, 528], [1300, 716], [74, 716], [74, 545]] },
  "kennlinie→leitventil": { p: [[200, 838], [228, 838]] },
  "leitventil→summe_vl": { p: [[400, 838], [421, 838]] },
  "summe_vl→vl_regler": { p: [[455, 838], [476, 838]] },
  "vl_regler→heizkreis": { p: [[636, 838], [664, 838]] },
  "heizkreis→vl_fuehler": { p: [[854, 838], [1090, 838], [1090, 950], [1060, 950]] },
  "vl_fuehler→summe_vl": { p: [[900, 950], [438, 950], [438, 855]] },
  "heizkreis→ventil": { p: [[854, 838], [884, 838], [884, 912], [420, 912], [420, 1086]] },
  "heizkreis→weitere_raeume": { p: [[884, 838], [955, 838], [955, 1086]] },
  "heizkreis→cop": { p: [] },
  "cop→kosten_wp": { p: [] },
  "raum_regler→leitventil": { p: [[296, 1128], [296, 880]] },
  "weitere_raeume→leitventil": { p: [[900, 1146], [840, 1146]] },
  "summe_raum→raum_regler": { p: [[91, 1128], [112, 1128]] },
  "raum_regler→ventil": { p: [[282, 1128], [310, 1128]] },
  "ventil→raum": { p: [[470, 1128], [560, 1128]] },
  "intern→raum": { p: [[774, 1030], [774, 1052], [660, 1052], [660, 1068]] },
  "fenster→raum": { p: [[898, 1030], [898, 1058], [700, 1058], [700, 1068]] },
  "ofen→raum": { p: [[1040, 1030], [1040, 1064], [740, 1064], [740, 1068]] },
  "raum→raum_fuehler": { p: [[700, 1188], [700, 1216]] },
  "raum_fuehler→summe_raum": { p: [[560, 1238], [74, 1238], [74, 1145]] },
};

/** Beschriftungen, die nicht am Kästchen, sondern an der Leitung stehen. */
export const BESCHRIFTUNG: { x: number; y: number; text: string; anker?: "start" | "middle" | "end" }[] = [
  { x: 520, y: 331, text: "Führungsgrößen: wSOC(t) · Fahrplan Ofen · Freigabefenster · wi", anker: "middle" },
  { x: 680, y: 710, text: "SOCth, Q̇ab — Rückführung des Beobachters", anker: "middle" },
  { x: 302, y: 1000, text: "hi aller Räume", anker: "start" },
  { x: 430, y: 906, text: "TVL in die Heizkreise", anker: "start" },
  { x: 806, y: 640, text: "Q̇HK (Entnahme)", anker: "start" },
  { x: 320, y: 1232, text: "Ti — Rückführung", anker: "middle" },
];

/** Die Ebenenaufschriften. */
export const EBENEN: { x: number; y: number; text: string }[] = [
  { x: 28, y: 44, text: "EBENE 4 · ÖKONOMISCHE FÜHRUNG — TAKT 15 MIN, HORIZONT 48 H" },
  { x: 28, y: 380, text: "EBENE 3 + 2 ·" },
  { x: 28, y: 394, text: "SPEICHER UND ERZEUGER" },
  { x: 28, y: 786, text: "EBENE 1 · VORLAUFTEMPERATUR UND VERTEILUNG" },
  { x: 28, y: 1062, text: "EBENE 0 · EINZELRAUMREGELUNG — 10 KREISE" },
];

/** Wo Blöcke landen, für die es keinen Platz gibt: eine Reihe unter der Karte. */
export function notplatz(i: number): Rechteck {
  return { x: 28 + (i % 7) * 196, y: 1272 + Math.floor(i / 7) * 56, w: 180, h: 44 };
}
