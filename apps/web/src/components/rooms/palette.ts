/**
 * Die Farbskala der Raumabweichung - eine Stelle, von der die Kacheln, die Tagesmatrix und die
 * Legende lesen.
 *
 * **Zweiseitig, weil die Größe zweiseitig ist.** Zu kalt und zu warm sind nicht zwei Grade
 * desselben, sondern zwei Richtungen; eine Skala von hell nach dunkel könnte das nicht zeigen.
 * Null ist eine eigene, gedeckte Stufe und keine Lücke: „am Ziel" ist das Ergebnis, auf das
 * es hinausläuft, und soll als solches zu sehen sein.
 */
export type Stufe = { readonly von: number; readonly bis: number; readonly farbe: string; readonly marke: string };

export const STUFEN = [
  { von: -Infinity, bis: -1.5, farbe: "var(--dev-cold-2)", marke: "−1,5" },
  { von: -1.5, bis: -0.5, farbe: "var(--dev-cold-1)", marke: "−0,5" },
  { von: -0.5, bis: 0.5, farbe: "var(--dev-null)", marke: "0" },
  { von: 0.5, bis: 1.5, farbe: "var(--dev-warm-1)", marke: "+0,5" },
  { von: 1.5, bis: Infinity, farbe: "var(--dev-warm-2)", marke: "+1,5" },
] as const satisfies readonly Stufe[];

/** Die Farbe zu einer Abweichung in Kelvin. `null` hat keine Farbe, sondern einen eigenen Zustand. */
export function farbe(k: number): string {
  return (STUFEN.find((s) => k >= s.von && k < s.bis) ?? STUFEN[2]).farbe;
}

/** Die Füllung für ein Feld ohne Messwert: schraffiert, nicht grau.
 *
 *  Grau wäre eine sechste Stufe derselben Skala und würde als Messwert gelesen. Eine Schraffur
 *  gehört sichtbar nicht dazu - und genau das ist die Aussage. */
export const KEIN_WERT =
  "repeating-linear-gradient(135deg, rgba(255,255,255,.10) 0 3px, transparent 3px 6px)";

/** Ein Fenster, das noch nicht an der Reihe war.
 *
 *  **Nicht dieselbe Schraffur wie ein fehlender Messwert.** Beide Felder sind leer, aber aus
 *  verschiedenen Gründen: Der Nachmittag ist noch nicht gewesen, der stumme Fühler schon. Sie
 *  gleich zu zeichnen hieße, eine halbe Seite Schraffur zu zeigen und darin die paar Felder zu
 *  verstecken, auf die es ankommt. */
export const NOCH_NICHT = "rgba(255,255,255,.035)";

/** Ab welcher Abweichung ein Raum als „unter Sollwert" gilt. Darunter ist es Messrauschen:
 *  Contromes Fühler lösen 0,1 K auf, und eine Fußbodenheizung pendelt immer etwas. */
export const BAND_K = 0.5;

const nf1 = new Intl.NumberFormat("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 });

/** Eine Zahl mit einer Nachkommastelle, deutsch und ohne Einheit.
 *
 *  Die große Zahl in der Kachel hat ihr „°C" als eigenes, kleineres Element daneben; sie braucht
 *  eine Zahl, keinen fertigen Satz. Die Einheit aus einem formatierten Text wieder herauszuschneiden
 *  hieße, auf das Leerzeichen zu bauen, das darin steht. */
export function zahl1(n: number): string {
  return nf1.format(n);
}

/** Eine Temperaturdifferenz mit Vorzeichen, deutsch. */
export function kelvin(k: number): string {
  return `${k > 0 ? "+" : "\u2212"}${nf1.format(Math.abs(k))}\u202fK`;
}

/** Eine Abweichung als Text: „am Ziel" innerhalb des Bandes, sonst mit Vorzeichen.
 *
 *  Nicht „auf Soll": Geregelt wird auf Sollwert plus Offset, und der Sollwert allein ist eine
 *  Zahl, auf die niemand regelt. */
export function abweichungText(k: number | null | undefined): string {
  if (k == null) return "kein Messwert";
  if (Math.abs(k) <= BAND_K) return "am Ziel";
  return kelvin(k);
}

/** Wie weit die Heizkreise offen sind - für einen Augenblick, nicht für einen Zeitraum.
 *
 *  Die Antriebe kennen kein Dazwischen, der Anteil entsteht aus der Zahl der Kreise. In einem
 *  Augenblick ist er deshalb immer ein glatter Bruch, und „1 von 4 offen" sagt mehr als „25 %". */
export function ventilText(anteil: number | null | undefined, kreise: number): string {
  if (anteil == null) return "kein Messwert";
  if (anteil <= 0) return "zu";
  if (kreise <= 0) return anteilText(anteil);
  const offen = anteil * kreise;
  if (Math.abs(offen - Math.round(offen)) > 0.01) return anteilText(anteil);
  return `${Math.round(offen)} von ${kreise} offen`;
}

/** Derselbe Anteil über einen Zeitraum, und da ist er kein Bruch mehr.
 *
 *  Über eine Viertelstunde gemittelt heißt 0,57 weder „0,57 Kreise" noch „57 % offen" an einem
 *  Ventil, das nur auf und zu kennt, sondern: so viel von allem, was offen sein könnte, war offen.
 *  Der Prozentsatz ist dafür die einzige ehrliche Form. */
export function anteilText(anteil: number | null | undefined): string {
  if (anteil == null) return "kein Messwert";
  if (anteil <= 0) return "zu";
  return `${new Intl.NumberFormat("de-DE", { maximumFractionDigits: 0 }).format(anteil * 100)}\u202f%`;
}
