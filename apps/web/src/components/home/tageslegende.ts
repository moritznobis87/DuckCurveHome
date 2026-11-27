import type { Tag } from "./tage";

/**
 * Die Legende unter der Tageskurve: was sie nennt und wie die Marke davor aussieht.
 *
 * **Sie nennt, was im Bild steht, und zeichnet es so, wie es dort steht.** Der Hausherr am
 * 27.11.2026 mit einem Bild der App, Reiter „Morgen“, um 12:34 Uhr: „Die Legenden-Erklärung
 * passt überhaupt nicht zu der Grafik.“ Im Bild standen zwei gestrichelte Linien und eine
 * durchgezogene. In der Legende standen fünf Einträge mit durchgezogenem Strich, zwei davon,
 * Strompreis und Preistief, für etwas, das gar nicht im Bild war: Die Preise für morgen
 * veröffentlicht die Börse erst gegen 13 Uhr.
 *
 * Darum hängen drei Einträge am Inhalt: die erwartete Wärmepumpe, der Strompreis und das
 * Preistief. Sonne, Prognose und Haus bleiben am Tag: sie gehören zu jedem Tag, und ohne sie
 * stünde an einem Tag ohne Messwerte ein leeres Bild ohne ein Wort, was dort stehen würde.
 * Dass die Preise für morgen erst gegen 13 Uhr kommen, sagen die Zahlen des Tages über der Kurve
 * (`tage.ts`, `kennzahlen`); die Legende wiederholt es nicht.
 *
 * Gerechnet wird hier und im Kit in `Kurvenlegende.swift`, mit denselben Fällen in beiden Tests.
 */
export type Legendenreihe = "sonne" | "sonneErwartet" | "schatten" | "haus" | "waermepumpe" | "waermepumpeErwartet" | "strompreis" | "preistief";

/** Wie die Marke vor dem Wort aussieht: eine Fläche, ein Strich oder ein gestrichelter Strich. */
export type Legendenform = "flaeche" | "linie" | "gestrichelt";

export interface Legendeneintrag {
  reihe: Legendenreihe;
  wort: string;
  form: Legendenform;
}

/** Was das Bild gerade enthält, soweit die Legende danach fragt. */
export interface Kurveninhalt {
  /** Der Tag im Hintergrund mit seiner Sonne, etwa „heute 10,8 kWh“. Null, wenn es keinen gibt. */
  schattenwort: string | null;
  /** Die gemessene Wärmepumpe als eigene Linie. Das Dashboard zeichnet sie nicht, die App schon. */
  waermepumpeGemessen: boolean;
  /** Der Strom, den die Wärmepumpe morgen brauchen wird. */
  waermepumpeErwartet: boolean;
  /** Preise, die schon galten, und Preise, die noch kommen. */
  preisGemessen: boolean;
  preisErwartet: boolean;
  /** Mindestens ein Preisfenster liegt als Band im Bild. */
  baender: boolean;
}

export function tageslegende(tag: Tag, inhalt: Kurveninhalt): Legendeneintrag[] {
  const aus: Legendeneintrag[] = [];
  if (tag !== "morgen") aus.push({ reihe: "sonne", wort: "Sonne", form: "flaeche" });
  if (tag !== "gestern") aus.push({ reihe: "sonneErwartet", wort: tag === "morgen" ? "Sonne erwartet" : "Prognose", form: "gestrichelt" });
  // Der Tag im Hintergrund ist gemessen, also durchgezogen: gestrichelt ist nur, was noch keiner gemessen hat.
  if (inhalt.schattenwort) aus.push({ reihe: "schatten", wort: inhalt.schattenwort, form: "linie" });
  if (tag !== "morgen") aus.push({ reihe: "haus", wort: "Haus", form: "linie" });
  if (tag !== "morgen" && inhalt.waermepumpeGemessen) aus.push({ reihe: "waermepumpe", wort: "Wärmepumpe", form: "linie" });
  if (tag === "morgen" && inhalt.waermepumpeErwartet) aus.push({ reihe: "waermepumpeErwartet", wort: "Wärmepumpe", form: "gestrichelt" });
  // Der Preis ist durchgezogen, sobald ein Stück von ihm schon gegolten hat.
  if (inhalt.preisGemessen || inhalt.preisErwartet) aus.push({ reihe: "strompreis", wort: "Strompreis", form: inhalt.preisGemessen ? "linie" : "gestrichelt" });
  if (inhalt.baender) aus.push({ reihe: "preistief", wort: "Preistief", form: "flaeche" });
  return aus;
}
